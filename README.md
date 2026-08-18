# NES-LTER R/V Sharp underway data processing

Converts the raw underway instrument logs from an R/V Hugh R. Sharp cruise into
the published 1-minute CSV product. Written for **HRS2601**; defaults to
**HRS2606**. Set the `cruise` parameter to process a different cruise.

Everything happens in one notebook: `convert_sharp_underway.Rmd`. It also
processes the PAR channel, which the ship logs separately and which usually
arrives later; when those logs are not there yet the notebook still produces its
`noPAR` product and skips PAR (see "PAR" below).

## What you need

- **R** 4.1 or newer (the code uses the native `|>` pipe and `\(x)` lambdas). Developed on 4.5.3.
- **RStudio** (any recent version).
- **The raw logs.** They are not in this repository — they are too big.

## 1. Install the R packages

Open RStudio and run this once in the Console:

```r
install.packages(c("here", "dplyr", "purrr", "ggplot2", "lubridate",
                   "readr", "tidyr", "stringr", "rmarkdown", "knitr"))
```

## 2. Open the project

Open `sharp_underway_processing.Rproj` — **not** the `.Rmd` file on its own.

This matters. The `.Rproj` file is what the `here` package uses to find the
project root, and every path in the notebook is built relative to that root.
If you open the `.Rmd` by double-clicking it, `here()` may anchor somewhere
else and files will land in the wrong place.

## 3. Where the raw data goes

One directory per cruise under `input/`, each holding one directory per
instrument, each holding a `raw` subdirectory of daily log files:

```
input/
├── hrs2601/
│   └── raw/
│       ├── gps01/raw/       # GPS — $GPGGA position fixes
│       ├── flnturt/raw/     # FLNTU fluorometer — chlorophyll + turbidity (tab-delimited)
│       ├── sbe4501/raw/     # SBE45 thermosalinograph — temp, conductivity, salinity
│       ├── pos/raw/         # POS MV — $PASHR attitude, $INVTG course + speed
│       ├── rmyoung/raw/     # RM Young met — wind, air temp, humidity, pressure
│       └── par/raw/         # Biospherical PAR — BSI*.csv (see "PAR" below)
└── hrs2606/
    └── raw/
        └── ...
```

Cruises accumulate side by side. Adding one is dropping a directory in and
setting the `cruise` parameter to its name — there is nothing to edit. (All the
notebook's settings are parameters you set at knit time; see "Run it" below.)

The `cruise` parameter selects the directory, so it cannot be out of step with
the logs it processes. If the notebook cannot find them it stops immediately with
the path it tried, so a typo is easy to spot.

**If the logs are too big to keep in the project**, leave them where they are and
set the `raw_root` parameter to one cruise's `raw` directory in the
Knit-with-Parameters dialog (see "Run it" below). On Windows, use forward
slashes. Note this overrides the cruise directory, so `cruise` must be set to
match — see "Which cruise these logs are" below.

### Optional: the cruise event log

If you have the cruise's R2R event log, put it in the cruise's own directory
beside `raw/` — for HRS2606, that is `input/hrs2606/`. The notebook picks up any
file there whose name matches `*EVENTLOG*.csv`, so the datestamped R2R name
(`R2R_ELOG_HRS2606HS_FINAL_EVENTLOG_20260427_160219.csv`) can be dropped in
as-is. Because the directory is named for the cruise, one cruise's event log
cannot end up overlaid on another's track by accident.

It is only used to overlay station positions on the QC track plots, so it is not
read at all unless the `plots` parameter is on (see below). The notebook prints a
message and carries on without it, and the CSV products are identical either way.

## 4. Run it

With the project open, open `convert_sharp_underway.Rmd` and either:

- **Knit** (the Knit button, or Ctrl/Cmd-Shift-K) to run the whole thing with the
  default settings and get an HTML report; or
- **Knit with Parameters…** (the small ▾ arrow beside the Knit button) to open a
  dialog and change any setting for this one run — pick a cruise, tick the QC
  plots, and so on — with nothing to edit; or
- run the chunks top to bottom (the green ▶ button on each chunk) if you want
  to look at each step as it goes.

The chunks depend on each other in order, so if you run them individually,
start from the top.

A default run takes about half a minute — reading the raw logs is the slow part.

### Settings

Each setting is a **parameter**. Change one for a single run in the
Knit-with-Parameters dialog (the ▾ beside Knit), or change its default for good
in the `params:` block at the top of `convert_sharp_underway.Rmd`. No environment
variables, no `.Renviron`, no restarting R.

| Parameter | Default | What it does |
|-----------|---------|--------------|
| `cruise` | `hrs2606` | Which cruise to process: selects `input/<cruise>/` (its raw logs and event log), and prefixes every output file |
| `raw_root` | blank → `input/<cruise>/raw` | Where that cruise's raw instrument logs are; blank uses the default |
| `plots` | off | on draws the QC plots (33 of them, or 35 with an event log) into the knitted report |
| `intermediates` | off | on writes the nine intermediate CSVs alongside the product |
| `zlr` | `0` | Anemometer zero-line reference, in degrees — see "true wind" below |

The QC plots are the bulk of the runtime — turning them on takes the run from
about 30 seconds to about two minutes. Nothing written to `output/` depends on
them, so a run with plots off produces byte-for-byte identical CSVs.

### Which cruise these logs are

The `cruise` parameter picks the input directory, so asking for one cruise while
reading another's logs is not something that happens by accident. What the notebook still
checks for is misfiling — another cruise's logs sitting in this cruise's
directory. The ship names every file for the cruise it recorded
(`HS2606EM_gps01-2026-07-09`), so the notebook takes that number back out of the
filenames and requires the whole directory to agree on one. **Two different
numbers in one directory stops the run.**

The number the ship writes is not always the cruise's own. **HRS2601's logs are
all labelled `HS2501`** — the previous year's number, which the ship's logger was
never updated from. That is a mislabel rather than mixed data, so it warns and
proceeds, treating `input/hrs2601/` as authoritative. Expect one warning when
processing HRS2601; if you see it for any other cruise, check the directory.

PAR sits out of this check: Biospherical's logger names its files for the date
only (`BSI20260423_145702.csv`), so there is no cruise number in them to check.

If you override `raw_root`, it points somewhere outside `input/<cruise>/` and the
directory no longer implies the cruise — so set `cruise` to match what you are
pointing at.

## 5. What comes out

By default, one CSV in `output/` (the directory is created if it isn't there):

| File | What |
|------|------|
| `<cruise>_underway.csv` | **The product** — the underway spine with the PAR channel joined on. Written when the PAR logs are present |
| `<cruise>_underway_noPAR.csv` | The same 1-minute product without PAR — position, chl, turbidity, T/C/S, attitude, course, speed, and met (wind both relative and true). Always written; it is the deliverable until PAR arrives |
| `<cruise>_par_1min.csv` | 1-minute PAR — `date` and `par_umol_m2_s`. Written when the PAR logs are present |

The cruise prefix comes from the `cruise` parameter (`hrs2606` by default). `noPAR` means
the PAR channel is not included — it is logged separately and joined on last (see
section 6 below). A knit run before the PAR logs arrive writes only the `noPAR`
product; re-knitting once they have adds `<cruise>_underway.csv` and
`<cruise>_par_1min.csv`.

With the `intermediates` parameter on, nine more files are written next to it. None of
them are published; they exist for QC, and so that the products which predate the
met work stay reproducible (`noMet` means the meteorological channels are not
joined on yet).

| File | What |
|------|------|
| `<cruise>_underway_noMet_noPAR.csv` | The product, before the met join |
| `<cruise>_underway_noMet_noPAR_pash.csv` | Same, before the course/speed join |
| `<cruise>_underway_noMet_noPAR_noPOS.csv` | Same, before any POS MV data is joined |
| `<cruise>_ISO_underway_noMet_noPAR_noPOS.csv` | As above, keeping the raw ISO sample timestamps |
| `<cruise>_gps_1minute.csv` | 1-minute GPS positions |
| `<cruise>_met_1min.csv` | 1-minute met, standalone (covers more minutes than the underway spine — see below) |
| `<cruise>_pash.csv` | All parsed `$PASHR` attitude sentences, full rate |
| `<cruise>_vtg.csv` | All parsed `$INVTG` course/speed sentences, full rate |
| `<cruise>_vtg_1min.csv` | 1-minute course and speed |

## 6. PAR

PAR is logged by Biospherical's LoggerLight software rather than by the ship's
underway system, so it arrives separately, in its own format, and usually after
the rest of the cruise has already been processed. The `PAR` section of the
notebook reads it, averages it onto the same 1-minute grid as the other channels,
and joins it onto the underway spine — no separate step to run.

Its logs are filed as one more instrument under the cruise:
`input/<cruise>/raw/par/raw/BSI*.csv`. Because the notebook produces its `noPAR`
product first, a knit before those logs arrive still succeeds: it prints a message
that PAR is missing and writes `<cruise>_underway_noPAR.csv` only. Drop the
`BSI*.csv` logs in and re-knit to add the PAR files below.

| Parameter | Default | What it does |
|-----------|---------|--------------|
| `par_root` | blank → `input/<cruise>/raw/par/raw` | Where the `BSI*.csv` logs are; blank uses the default |

`cruise` and `plots` are the same parameters the rest of the notebook uses — see
the run table above. The PAR QC plots (including `par_diel`) are drawn with
`plots` on, like every other plot.

| File | What |
|------|------|
| `<cruise>_par_1min.csv` | 1-minute PAR — `date` and `par_umol_m2_s` |
| `<cruise>_underway.csv` | The product — the underway table with a `par_umol_m2_s` column joined on. Every other column is exactly the `noPAR` product's |

Notes:

- **Units.** The product is always µmol/m²/s, the conventional PAR unit, but the
  logger's native unit varies by cruise: HRS2601 reports Einsteins/m²/s (mol
  photons, ×10⁶ to µmol), HRS2606 reports µmol/m²/s directly (×1). The notebook
  reads the file's own `Units` line and picks the multiplier from it; a cruise in
  neither unit stops the run rather than guessing. `ScaleFactor` and `Offset+FO`
  in the file header are provenance — LoggerLight has already applied them.
- **The logger clock is assumed to be UTC.** Nothing in the file says so. The
  HRS2601 logs confirm it: PAR peaks near 16:30–17:00 in logger time, which is
  solar noon in UTC at the shelf-break longitude, not the ~12:40 a logger on
  local time would show. The `par_diel` QC plot (with `plots` on) is what
  rechecks this for a new cruise — the daylight lobe should straddle the blue
  line.
- **PAR does not cover the whole cruise.** The logger is started and stopped
  independently of the underway system, so minutes with no PAR are normal and
  reach the product as `NA`. On HRS2601 the logger started about 27 hours into
  the cruise, so 68% of the underway minutes have PAR. The notebook prints every
  gap it finds.
- **A cruise with no overlap at all stops the join**, rather than writing a
  column of `NA` — that is the signature of a cruise or timezone mismatch.
- PAR is averaged over each minute, like chl and T/C/S, not sampled
  instantaneously like position and attitude.

## Notes on the processing

- **Everything is UTC.** The notebook sets `TZ=GMT` in its first chunk.
- **Position is instantaneous; the environmental channels are averaged.** Each
  1-minute row takes the first GPS fix in that minute, and joins the *mean* of
  the fluorometer and thermosalinograph samples over that minute.
- **The 1-minute grid tolerates clock drift.** Instruments do not reliably log
  a sample exactly on the minute boundary, so `snap_to_minute()` takes the first
  sample within each minute rather than requiring `second == 0`. Samples more
  than 30 seconds past the boundary are dropped rather than carried forward.
- **The first minute is dropped.** Logging starts mid-minute, so averaging that
  minute would average a partial window.

## Notes on the met data

The RM Young logs three sentences at 1 Hz: `$WIMW1` and `$WIMW2` (wind direction
and speed, one per sensor) and `$WIXDR` (air temperature, relative humidity,
barometric pressure). All of them are averaged onto the same 1-minute grid as the
other channels.

- **Wind is published twice: as measured, and corrected.** What the anemometers
  report is relative to the ship — the sentences carry an `R` reference field, so
  the direction is a bearing off the bow and the speed is apparent wind, both of
  them contaminated by the ship's own motion. Those columns are published as
  `wind{1,2}_rel_dir_deg` and `wind{1,2}_speed_kt`, named `rel` to keep that hard
  to miss. Alongside them, `wind{1,2}_true_dir_deg` and `wind{1,2}_true_speed_kt`
  give the true wind: the ship's motion subtracted back out, so the direction is
  referenced to true north and the speed is relative to the fixed earth. All
  speeds are in knots; all directions are meteorological, i.e. the direction the
  wind blows **from**.
- **Both wind sensors are kept.** Neither is designated primary here, so both are
  published, relative and true.
- **Wind direction is vector-averaged.** A bearing cannot be averaged as a scalar
  — the mean of 359° and 1° is 180°, not 0° — so each sample is resolved into a
  vector, the vectors are averaged, and the bearing is taken back out. Wind speed
  is the plain scalar mean, which is the usual met convention.
- **The met sentences are checksummed.** A serial dropout mid-sentence still
  parses into plausible-looking numbers, so any sentence whose NMEA checksum does
  not verify is dropped. (On HRS2606, none were: 0 of 846,606.)
- **The sensor can log slightly negative bearings.** `-00` and `-01` mean just to
  port of the bow; they are wrapped back into [0, 360).
- **`<cruise>_met_1min.csv` covers more minutes than the underway product.** The
  met sensor logs on the dock before the GPS starts, so the standalone file has a
  dockside head on it (with air temperatures to match — 36 °C in the sun). Those
  minutes are not in the underway product: the join keeps only minutes on the GPS
  spine.

## Notes on the true wind

A ship steaming at 10 knots feels a 10-knot headwind that isn't there. True wind
is what an observer standing still would have measured: the apparent wind vector
with the ship's own velocity vector subtracted back out.

`R/tw.R` is the COAPS/FSU SAMOS `truewind` algorithm
(Shawn R. Smith and Mark A. Bourassa, `samos@coaps.fsu.edu`), the standard
implementation for this correction, vendored into this repository as an R
translation of the reference Python implementation and under its own copyright
and license — see `THIRD-PARTY-NOTICES.md`. The notebook calls its `truew()`
once per minute per sensor. The translation was checked against that Python
across 12,023 cases — random inputs, missing values, out-of-range values, calm,
and the exact boundaries — and agrees to within floating-point noise (worst
disagreement 3 × 10⁻¹³ degrees).

Four inputs go in, all of them already in the product: `heading` (where the bow
points, true north), `course_true_deg` (where the ship actually travels over the
ground), `sog_kts` (speed over the ground), and the sensor's relative wind. Because all
four are published, a downstream user can reproduce or redo this correction from
the CSV alone — which is why `course_true_deg` is published even though it tracks
`heading` closely. The two are not the same variable, and the difference between
them is the crab angle the ship carries under wind and current.

Things worth knowing before you use these columns:

- **The zero-line reference is an assumption.** True wind depends on where each
  anemometer's zero line points relative to the bow. We assume it *is* the bow
  (`zlr = 0`), which is the normal meaning of the `R` reference field in `$WIMW`,
  but **this has not been confirmed with the R/V Sharp.** If the ship reports an
  offset, set the `zlr` parameter to it and re-run. Be aware that a wrong `zlr` rotates
  every true wind direction by exactly that many degrees while barely touching the
  speeds, so it does not announce itself in the output.
- **North is 360, not 0.** When the wind is blowing from due north the direction
  is reported as `360.0`. That is the WMO convention and `truew()` does it
  deliberately; `0` is reserved for calm, where direction is undefined.
- **Heading must be true, not magnetic.** `heading_type` records which it is. On
  the rare row where the POS MV reports a magnetic heading, true wind is left
  empty rather than computed from it.
- **The two sensors disagree slightly more in true direction than in relative
  direction, and that is expected.** Converting to true wind rescales the wind
  vector by roughly (apparent speed ÷ true speed), so a fixed disagreement between
  the two sensors is amplified when the ship steams into the wind and damped when
  it runs with it. On HRS2606 the median amplification is 1.00, matching that
  ratio almost exactly. Speed, which is not rescaled this way, agrees *more*
  closely in true coordinates (0.33 kt) than in relative (0.36 kt).
- **Correcting a 1-minute average is not the same as averaging 1-second
  corrections.** The wind here is vector-averaged over the minute before the
  correction is applied, and heading, course, and speed are each the first sample
  in the minute rather than an average. During a hard turn those are not quite the
  same thing. On a steady course the difference is negligible; it is worth
  remembering when reading wind through a station turn.
