# Convert the R/V Sharp underway PAR logs to a 1-minute product.
#
# The PAR channel is logged by Biospherical's LoggerLight software rather than
# by the ship's underway system, so it arrives separately and in its own format
# -- but it is filed as one more instrument under the cruise
# (input/<cruise>/raw/par/raw/BSI*.csv), beside the ship's own logs.
#
# This script is standalone because the PAR data arrives on its own schedule,
# often after the rest of the cruise has been processed. It is written in the
# idiom of convert_sharp_underway.Rmd (same env vars, same input layout, same
# qc()/product()/iso_offset() helpers, same 1-minute averaging as the notebook's
# other continuous scalars) so the "PAR" section below can be lifted into the
# notebook as a chunk once the two are processed together.
#
# Usage:
#   SHARP_CRUISE=hrs2601 Rscript process_par.R
#
# Environment:
#   SHARP_CRUISE   cruise to process (default hrs2606, as in the notebook)
#   SHARP_PAR_ROOT directory of BSI*.csv logs
#                  (default input/<cruise>/raw/par/raw)
#   SHARP_PLOTS    1 to draw the QC plots (default off)
#   SHARP_JOIN     1 to join onto output/<cruise>_underway_noPAR.csv and write
#                  output/<cruise>_underway.csv (default off)

Sys.setenv(TZ = 'GMT')

library(here)
library(dplyr)
library(ggplot2)
library(lubridate)
library(readr)
library(stringr)

# helpers

# Which cruise to process; selects the PAR logs and prefixes the output. Same
# variable and same default as the notebook, so a shell that knits one can run
# the other without changing anything.
cruise <- tolower(Sys.getenv("SHARP_CRUISE", unset = "hrs2606"))

# PAR is filed as one more instrument under the cruise, beside gps01 and
# rmyoung, even though Biospherical's logger wrote it rather than the ship's
# underway system. So `cruise` picks these logs the same way it picks the
# notebook's: mislabelling the output would mean reading from another cruise's
# directory, which is not something a default can do by accident. That is why
# SHARP_CRUISE is defaulted here and the BSI filenames -- which carry a date and
# no cruise number -- do not need to be cross-checked the way the ship's are.
par_root <- Sys.getenv("SHARP_PAR_ROOT",
                       unset = here("input", cruise, "raw", "par", "raw"))

if (!dir.exists(par_root)) {
  stop("PAR log directory not found: ", par_root,
       "\nUnpack ", cruise, "'s BSI*.csv logs there, or set SHARP_PAR_ROOT to ",
       "their location.")
}

par_paths <- dir(par_root, pattern = "^BSI.*\\.csv$", full.names = TRUE)

if (length(par_paths) == 0) {
  stop("no BSI*.csv files found under: ", par_root,
       "\nHas ", cruise, "'s PAR data arrived yet?")
}

make_plots <- identical(Sys.getenv("SHARP_PLOTS", unset = "0"), "1")

qc <- function(expr) {
  if (!make_plots) return(invisible(NULL))
  x <- expr
  if (inherits(x, "ggplot")) print(x)
  invisible(x)
}

out_dir <- here("output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

product <- function(what) file.path(out_dir, paste0(cruise, "_", what, ".csv"))

# The published files timestamp every row as UTC with an explicit offset.
iso_offset <- function(x) paste0(format(x, "%Y-%m-%d %H:%M:%S"), "+00:00")

# PAR

# A LoggerLight file is an 8-line header block, a column header, then 5-second
# samples:
#
#   LoggerLight version 1.3.1, 4/23/2026 14:57:02, interval  5sec, Warning: ...
#   System S/N: QSR - S/N 10367, calibrated: 1/1/2022. Tag ,"2"
#   ScaleFactor,604.71,,,,,,
#   Offset+FO,0.193502,,,,,,
#   Units,Einsteins/m2/s,,,,,,
#   Immersion,n/a,,,,,,
#   Cal Date,1/1/2022,,,,,,
#   Tag Address,2,,,,,,
#   Time,QSR - S/N 10367,Minimum,Maximum,StDev,Integral,#Averaged,
#   4/23/2026 14:57:05,1.234567E-03,...
#
# ScaleFactor and Offset+FO are reported for provenance; LoggerLight has already
# applied them, which is why the Units line reads Einsteins and not counts. Do
# not apply them again.
#
# The header is fixed-height in every HRS2601 file, but it is located by finding
# the "Time," line rather than by skipping 8 lines (as parse_par.py did), so a
# logger writing a longer or shorter preamble on a later cruise still parses.

PAR_HEADER_RE <- "^Time,"

# The Units line contains a superscript 2 (Einsteins/m^2/s), which is a single
# byte in the logger's cp1252 output and invalid UTF-8. Read as cp1252 so the
# line does not come back mangled or abort the read.
read_par_file <- function(path) {
  lines <- read_lines(path, locale = locale(encoding = "cp1252"),
                      progress = FALSE)

  hdr_i <- which(str_detect(lines, PAR_HEADER_RE))[1]
  if (is.na(hdr_i)) {
    stop("no column header (a line starting \"Time,\") in: ", basename(path))
  }

  meta   <- lines[seq_len(hdr_i - 1)]
  fields <- str_split_fixed(lines[hdr_i], stringr::fixed(","), 8)

  # Field 2 of the header names the probe -- "QSR - S/N 10367" on HRS2601. It is
  # read rather than hardcoded so a cruise that ships a different probe does not
  # silently produce an all-NA column.
  sensor <- fields[2]

  # Pull a value out of the "Key,value,,,,,," metadata lines.
  meta_value <- function(key) {
    hit <- str_subset(meta, paste0("^", key, ","))
    if (length(hit) == 0) return(NA_character_)
    str_trim(str_split_fixed(hit[1], stringr::fixed(","), 3)[2])
  }

  # Samples are the 8-field lines. LoggerLight also writes bare 2-field status
  # messages into the data block ("All statistics reset.", "Program closed
  # normally.", "Sampling resumed after manual pause"), which carry a timestamp
  # and prose where the reading should be. parse_par.py let those through, and
  # pandas turned each into a row whose PAR value was the message text; here
  # they are dropped and counted.
  body <- lines[-seq_len(hdr_i)]
  body <- body[str_trim(body) != ""]

  m    <- str_split_fixed(body, stringr::fixed(","), 8)
  time <- str_trim(m[, 1])
  # Field 2 is the reading. Anything non-numeric there is a status message.
  value <- suppressWarnings(as.numeric(m[, 2]))
  is_sample <- !is.na(value)

  tibble(
    file        = basename(path),
    sensor      = sensor,
    scale_factor = meta_value("ScaleFactor"),
    units       = meta_value("Units"),
    cal_date    = meta_value("Cal Date"),
    n_messages  = sum(!is_sample),
    time        = time[is_sample],
    par_native  = value[is_sample]
  )
}

par_raw <- bind_rows(lapply(par_paths, read_par_file))

# One probe per cruise. Two would mean logs from different deployments (or
# different cruises) mixed together in par_root, and averaging across them would
# be meaningless.
sensors <- unique(par_raw$sensor)
if (length(sensors) > 1) {
  stop("more than one PAR probe among the logs under ", par_root, ": ",
       paste(sensors, collapse = ", "),
       "\nSeparate the deployments and run them one at a time.")
}

# Calibration and scaling are what turn the counts into the published number, so
# a change in either mid-cruise silently changes the units of half the product.
if (length(unique(par_raw$scale_factor)) > 1) {
  warning("ScaleFactor is not the same in every log: ",
          paste(unique(par_raw$scale_factor), collapse = ", "))
}
if (length(unique(par_raw$cal_date)) > 1) {
  warning("Cal Date is not the same in every log: ",
          paste(unique(par_raw$cal_date), collapse = ", "))
}

# The conversion below is a unit change, not a calculation, and it is only valid
# because the logger says it is emitting Einsteins. Refuse to guess if it says
# anything else. Match loosely: the superscript 2 does not survive every
# encoding, and "Einsteins/m2/s" and "Einsteins/m^2/s" are the same units.
units_native <- unique(par_raw$units)
if (!all(str_detect(units_native, regex("einstein", ignore_case = TRUE)))) {
  stop("PAR logs are not in Einsteins -- the Units line reads: ",
       paste(units_native, collapse = ", "),
       "\nThe umol/m2/s conversion below assumes Einsteins/m2/s.")
}

message(length(par_paths), " PAR logs, probe ", sensors,
        ", ScaleFactor ", unique(par_raw$scale_factor),
        ", calibrated ", unique(par_raw$cal_date))
# n_messages is a per-file count carried on every one of that file's rows, so it
# has to be de-duplicated before it is summed.
n_dropped <- par_raw |> distinct(file, n_messages) |> pull(n_messages) |> sum()

message(n_dropped, " logger status messages dropped; ",
        nrow(par_raw), " samples read")

# LoggerLight timestamps are M/D/YYYY H:M:S with no zero padding and no zone.
#
# The zone is the load-bearing assumption here: nothing in the file says UTC, and
# a logger left on ship-local time would put every reading four hours off the
# underway spine -- an error that would survive the join looking perfectly
# plausible. parse_par.py assumed UTC (utc=True), and the diel cycle in the
# HRS2601 logs confirms it: PAR peaks near 16:30-17:00 in logger time, which is
# solar noon in UTC at the shelf-break longitude (12:00 + 70 deg / 15 = ~16:40),
# not the ~12:40 a logger on EDT would show. The par_diel QC plot below is what
# rechecks this for a new cruise.
par_all <- par_raw |>
  mutate(
    datetimeISO = time,
    datetime    = as.POSIXct(time, tz = "GMT", format = "%m/%d/%Y %H:%M:%S"),
    # Einsteins (= mol photons) to umol, the conventional PAR unit.
    par_umol_m2_s = par_native * 1e6
  ) |>
  filter(!is.na(datetime)) |>
  arrange(datetime) |>
  select(file, datetimeISO, datetime, par_native, par_umol_m2_s)

if (nrow(par_all) == 0) stop("no PAR samples parsed -- check the Time format")

message("PAR spans ", format(min(par_all$datetime)), " to ",
        format(max(par_all$datetime)), " UTC")

# plot raw data
qc(ggplot(par_all, aes(x = datetime, y = par_umol_m2_s))+geom_point()+labs(y = "PAR, umol/m2/s"))

# The timezone check described above, drawn: PAR against hour of day. The
# daylight lobe must be centered near 16-17 UTC. Centered near 12-13 instead
# means the logger clock is on ship-local time and the UTC assumption is wrong.
qc(ggplot(par_all, aes(x = hour(datetime) + minute(datetime)/60, y = par_umol_m2_s))+
     geom_point(alpha = 0.1)+
     geom_vline(xintercept = 16.7, color = "blue3")+
     labs(x = "hour of day, logger clock", y = "PAR, umol/m2/s",
          title = "diel cycle (blue = solar noon in UTC at ~70W)"))

# calculate 1-minute average of PAR
#
# PAR is a continuous scalar, so it is averaged over the minute like chl,
# turbidity and T/C/S in the notebook -- not subsampled with snap_to_minute()
# like the instantaneous channels (position, attitude, course).
#
# This is a deliberate departure from parse_par.py, which merged on an exact
# timestamp match and so kept only samples that happened to land on the :00
# second. The logger's 5-second cadence is not phase-locked to the minute and
# re-phases after every "All statistics reset", so that match dropped most
# minutes to NA. Averaging uses all ~12 samples in the minute and fills every
# minute the logger was running.
par_1min <- par_all |>
  group_by(datetime = floor_date(datetime, unit = "minutes")) |>
  summarize(par_umol_m2_s = mean(par_umol_m2_s),
            n_samples     = n(),
            .groups = "drop")

# ~12 samples per minute at the 5-second logging interval. Short minutes are the
# ones bracketing a logger restart, and are expected; they are counted, not
# dropped, because a mean of even one sample is still that minute's PAR.
qc(ggplot(par_1min, aes(x = n_samples))+geom_bar()+labs(x = "samples per minute"))
message(sum(par_1min$n_samples < 6), " of ", nrow(par_1min),
        " minutes built from fewer than 6 samples (restarts and log boundaries)")

# The logger is stopped and restarted through the cruise, so the 1-minute series
# has real holes in it. Report them rather than pad them: a minute with no PAR
# must reach the product as NA, which the join below does by leaving it out.
gaps <- par_1min |>
  mutate(gap_min = as.numeric(difftime(datetime, lag(datetime), units = "mins"))) |>
  filter(gap_min > 1)

message(nrow(gaps), " gaps in the 1-minute PAR series",
        if (nrow(gaps) > 0) paste0(" (longest ", round(max(gaps$gap_min)), " min)") else "")
if (nrow(gaps) > 0) print(gaps |> select(resumes_at = datetime, gap_min))

qc(ggplot(par_1min, aes(x = datetime, y = par_umol_m2_s))+geom_point()+labs(y = "PAR, umol/m2/s"))

# write the 1-minute PAR file
par_out <- par_1min |>
  mutate(date = iso_offset(datetime)) |>
  select(date, par_umol_m2_s)

write_csv(par_out, product("par_1min"))
message("wrote ", product("par_1min"), " (", nrow(par_out), " minutes)")

# join onto the underway product

# What the notebook will do with par_1min once this is a chunk in it: a
# left_join onto the underway spine, exactly as the fluorometer and TSG are
# joined. Kept behind SHARP_JOIN because the notebook's product has to exist
# first, and because this script's own job is the PAR file above.
if (identical(Sys.getenv("SHARP_JOIN", unset = "0"), "1")) {
  underway_path <- product("underway_noPAR")

  if (!file.exists(underway_path)) {
    stop("SHARP_JOIN=1 but the underway product is not there: ", underway_path,
         "\nKnit convert_sharp_underway.Rmd for ", cruise, " first.")
  }

  # Every column is read as text and written back untouched: this script adds a
  # column to someone else's product, and must not rewrite the rest of it.
  # Guessed types would not be neutral here -- readr parses the notebook's
  # `date` ("2026-07-09 21:13:00+00:00") and `datetimeISO`
  # ("2026-07-09T21:13:00.291129Z") into POSIXct, and write_csv then renders
  # them back in its own ISO8601 style, silently reformatting `date` and
  # truncating datetimeISO's microseconds. `datetime` below is derived for the
  # join only and dropped before writing.
  underway <- read_csv(underway_path, col_types = cols(.default = col_character())) |>
    mutate(datetime = as.POSIXct(date, tz = "GMT",
                                 format = "%Y-%m-%d %H:%M:%S"))

  if (all(is.na(underway$datetime))) {
    stop("could not parse the `date` column of ", underway_path,
         " as \"%Y-%m-%d %H:%M:%S\" -- first value: ", underway$date[1])
  }

  underway_par <- underway |>
    left_join(par_1min |> select(datetime, par_umol_m2_s), by = "datetime") |>
    select(-datetime)

  # The PAR logger runs on its own schedule -- typically starting before the
  # cruise and stopping partway through it -- so minutes of the spine with no
  # PAR are normal. A spine with NO PAR at all is not: that is the signature of
  # a timezone or cruise mismatch, where the two series simply never overlap.
  n_missing <- sum(is.na(underway_par$par_umol_m2_s))
  if (n_missing == nrow(underway_par)) {
    stop("the join produced no PAR at all: the underway spine (",
         format(min(underway$datetime)), " to ", format(max(underway$datetime)),
         ") and the PAR logs (", format(min(par_all$datetime)), " to ",
         format(max(par_all$datetime)), ") do not overlap.",
         "\nAre both from ", cruise, "?")
  }
  message(n_missing, " of ", nrow(underway_par),
          " underway minutes have no PAR")

  write_csv(underway_par, product("underway"))
  message("wrote ", product("underway"))
}
