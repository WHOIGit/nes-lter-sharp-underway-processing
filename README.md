# NES-LTER R/V Sharp underway data processing

Converts the raw underway instrument logs from an R/V Hugh R. Sharp cruise into
the published 1-minute CSV product. Written for **HRS2601**; defaults to
**HRS2606**. Set `SHARP_CRUISE` to process a different cruise.

Everything happens in one notebook: `convert_sharp_underway.Rmd`.

## What you need

- **R** 4.1 or newer (the code uses the native `|>` pipe and `\(x)` lambdas). Developed on 4.5.3.
- **RStudio** (any recent version).
- **The raw logs.** They are not in this repository — they are too big. Get the
  `sharp_raw` directory from Jade Futrelle (jfutrelle@whoi.edu) and unpack it
  somewhere on your machine. See "Where the raw data goes" below.

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

The raw logs are one directory per instrument, each containing a `raw`
subdirectory of daily log files:

```
sharp_raw/
├── gps01/raw/       # GPS — $GPGGA position fixes
├── flnturt/raw/     # FLNTU fluorometer — chlorophyll + turbidity (tab-delimited)
├── sbe4501/raw/     # SBE45 thermosalinograph — temp, conductivity, salinity
├── pos/raw/         # POS MV — $PASHR attitude, $INVTG course + speed
└── rmyoung/raw/     # RM Young met — wind, air temp, humidity, pressure
```

You have two options:

**Option A — put the data inside the project (simplest).**
Unpack the logs so the tree above sits at `input/sharp_raw/` inside this
project directory. Nothing else to configure.

**Option B — leave the data where it is, and point at it.**
Set the `SHARP_RAW_ROOT` environment variable to the `sharp_raw` directory.
The easiest way is to create a file named `.Renviron` in the project root
containing one line:

```
SHARP_RAW_ROOT=/absolute/path/to/sharp_raw
```

Then restart R (Session → Restart R). On Windows, use forward slashes:
`SHARP_RAW_ROOT=C:/Users/you/data/sharp_raw`.

If the notebook cannot find the raw logs it stops immediately with a message
telling you which path it tried, so a typo here is easy to spot.

### Optional: the cruise event log

If you have the cruise's R2R event log, put it at `input/<CRUISE>/` inside the
project — for HRS2606, that is `input/HRS2606/`. The notebook picks up any file
in that directory whose name matches `*EVENTLOG*.csv`, so the datestamped R2R
name (`R2R_ELOG_HRS2606HS_FINAL_EVENTLOG_20260427_160219.csv`) can be dropped in
as-is. Because the directory is named for the cruise, one cruise's event log
cannot end up overlaid on another's track by accident.

It is only used to overlay station positions on the QC track plots, so it is not
read at all unless `SHARP_PLOTS=1` (see below). The notebook prints a message and
carries on without it, and the CSV products are identical either way.

## 4. Run it

With the project open, open `convert_sharp_underway.Rmd` and either:

- **Knit** (the Knit button, or Ctrl/Cmd-Shift-K) to run the whole thing and
  get an HTML report; or
- run the chunks top to bottom (the green ▶ button on each chunk) if you want
  to look at each step as it goes.

The chunks depend on each other in order, so if you run them individually,
start from the top.

A default run takes about half a minute — reading the raw logs is the slow part.

### Settings

Set any of these in `.Renviron` (see Option B above) and restart R, or edit the
corresponding line in the notebook's helpers chunk.

| Variable | Default | What it does |
|----------|---------|--------------|
| `SHARP_CRUISE` | `hrs2606` | Names the cruise: prefixes every output file, and selects `input/<CRUISE>/` as the event log directory |
| `SHARP_RAW_ROOT` | `input/sharp_raw` | Where the raw instrument logs are |
| `SHARP_PLOTS` | off (`0`) | `1` draws the QC plots (33 of them, or 35 with an event log) into the knitted report |
| `SHARP_INTERMEDIATES` | off (`0`) | `1` writes the nine intermediate CSVs alongside the product |
| `SHARP_ZLR` | `0` | Anemometer zero-line reference, in degrees — see "true wind" below |

The QC plots are the bulk of the runtime — turning them on takes the run from
about 30 seconds to about two minutes. Nothing written to `output/` depends on
them, so a run with plots off produces byte-for-byte identical CSVs.

**`SHARP_CRUISE` and `SHARP_RAW_ROOT` are independent**, so it is possible to ask
for one cruise while pointing at another's logs — which would silently mislabel
every output file. The notebook cross-checks them: the raw log filenames carry
the cruise number (`HS2606EM_gps01-2026-07-09`), and if none of them match the
cruise you asked for, it stops before doing any work. If only some match, it
warns that logs from more than one cruise may be mixed together under the raw
root.

## 5. What comes out

By default, one CSV in `output/` (the directory is created if it isn't there):

| File | What |
|------|------|
| `<cruise>_underway_noPAR.csv` | **The product** — 1-minute position, chl, turbidity, T/C/S, attitude, course, speed, and met (wind both relative and true) |

The cruise prefix comes from `SHARP_CRUISE` (`hrs2606` if unset). `noPAR` means
the PAR channel is not included.

With `SHARP_INTERMEDIATES=1`, nine more files are written next to it. None of
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

The arithmetic is not ours. `R/tw.R` is the COAPS/FSU SAMOS `truewind` algorithm
(Shawn R. Smith and Mark A. Bourassa, `samos@coaps.fsu.edu`), the standard
implementation for this correction, vendored into this repository unmodified and
under its own copyright and license. The notebook calls its `truew()` once per
minute per sensor. The R file is a translation of the reference Python
implementation; it was checked against that Python across 12,023 cases — random
inputs, missing values, out-of-range values, calm, and the exact boundaries — and
agrees to within floating-point noise (worst disagreement 3 × 10⁻¹³ degrees).

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
  offset, set `SHARP_ZLR` to it and re-run. Be aware that a wrong `zlr` rotates
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
