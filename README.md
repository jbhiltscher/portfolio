# NFL Player Geographic Origin Analysis

> Identify under-recruited geographic hotspots by mapping where NFL players come from — per capita — broken out by position group.

This EDA project joins high school recruiting data with NFL career records and US Census population figures to answer a core question for coaching staffs and analysts: **which states produce the most NFL talent relative to their population, and does that vary by position?**

---

## What It Does

- Pulls 10+ years of FBS recruiting data via the [cfbfastR](https://cfbfastr.sportsdataverse.org/) API
- Matches recruits to confirmed NFL players using `cfbfastR` `athlete_id` → `nflreadr` `espn_id`
- Normalizes output against US Census state populations for per-capita comparisons
- Produces five publication-ready plots and three summary CSV tables
- Answers targeted research questions on skill position, lineman, and QB hotspots

---

## Key Outputs

| File | Description |
|---|---|
| `plot_01_recruiting_volume_by_state.png` | Raw FBS recruit counts by state (top 20) |
| `plot_02_nfl_conversion_by_state.png` | % of recruits who reached the NFL, by state |
| `plot_03_nfl_per_capita_by_state.png` | NFL players per 1M residents (top 20) |
| `plot_04_state_position_heatmap.png` | Standardized production heatmap: state × position group |
| `plot_05_choropleth_nfl_per_capita.png` | Choropleth map of per-capita production, contiguous US |
| `table_state_nfl_overall.csv` | State-level NFL player counts and per-capita rates |
| `table_state_nfl_by_position.csv` | Same, broken out by position group |
| `table_recruits_who_made_nfl.csv` | Full record of matched recruits who reached the NFL |

---

## Prerequisites

- **R** ≥ 4.1.0 (native pipe `|>` is used throughout)
- Two free API keys (see [Setup](#setup))

### R Packages

All packages are auto-installed by the script if missing. They are:

| Package | Purpose |
|---|---|
| `cfbfastR` | HS recruiting data |
| `nflreadr` | NFL rosters and player metadata |
| `tidyverse` | Data wrangling and plotting |
| `tidycensus` | US Census population figures |
| `janitor` | Column name cleaning |
| `glue` | String interpolation |
| `fuzzyjoin` | Supplemental fuzzy name join |
| `sf` | Spatial features |
| `tigris` | US state shapefiles for choropleth |

---

## Setup

### 1. Get API Keys

**College Football Data API** (used by cfbfastR)
- Register free at <https://collegefootballdata.com/key>

**US Census Bureau API** (used by tidycensus)
- Register free at <https://api.census.gov/data/key_signup.html>

### 2. Store Keys in `.Renviron`

Add both keys to your `.Renviron` file (run `usethis::edit_r_environ()` to open it):

```
CFBD_API_KEY=your_cfbd_key_here
CENSUS_API_KEY=your_census_key_here
```

Restart R after saving. Alternatively, register the Census key interactively once:

```r
tidycensus::census_api_key("your_key_here", install = TRUE)
```

### 3. Set Working Directory

Update the `setwd()` call near the top of `nfl_per_capita.R` to your local project path:

```r
setwd("path/to/your/recruiting/folder")
```

---

## Usage

Source the entire script in one go:

```r
source("nfl_per_capita.R")
```

Or run it interactively phase by phase in RStudio — each phase is clearly delimited with a header comment:

| Phase | What It Does |
|---|---|
| **Phase 1** | Pull and clean FBS recruiting corpus (2013–2023) |
| **Phase 2** | Pull NFL player roster and career data |
| **Phase 3** | Join recruits → NFL players; compute `made_nfl` flag |
| **Phase 4** | Pull Census state populations for per-capita denominator |
| **Phase 5** | State-level scoring, overall and by position group |
| **Phase 6** | Generate and save all five plots |
| **Phase 7** | Export summary CSV tables |

### Adjusting the Recruiting Window

Change the year range at the top of Phase 1:

```r
RECRUIT_YEARS <- 2013:2023   # adjust as needed
```

> **Note:** The API is rate-limited. A `Sys.sleep(0.5)` buffer is included per year. Wide windows (e.g., 2002–2023) will take several minutes to pull.

### Caching the Joined Dataset

After Phase 3 completes, the joined dataset is saved locally so you can skip the API pulls on subsequent sessions:

```r
# Saved automatically after Phase 3:
saveRDS(recruits_joined, "recruits_joined.rds")

# Reload without re-pulling:
recruits_joined <- readRDS("recruits_joined.rds")
```

---

## Research Questions Answered

The script is structured around three specific hypotheses (Phase 5c):

```r
# Q1: Do WR/RB/ATH skill positions come from California?
# Q2: Do DL/OL linemen come from Texas?
# Q3: Do QBs come from Utah, Ohio, or Georgia?
```

Each produces a ranked per-capita table. Results from the 2013–2023 window show Louisiana leads overall per-capita production (17.45/1M), Georgia dominates for skill positions and QBs, and Mississippi leads for defensive linemen — challenging several common recruiting assumptions.

---

## Project Structure

```
recruiting/
├── nfl_per_capita.R                  # Main analysis script
├── recruits_joined.rds               # Cached joined dataset (generated)
├── table_state_nfl_overall.csv       # Output: overall state rankings
├── table_state_nfl_by_position.csv   # Output: state × position rankings
├── table_recruits_who_made_nfl.csv   # Output: matched NFL players
├── plot_01_recruiting_volume_by_state.png
├── plot_02_nfl_conversion_by_state.png
├── plot_03_nfl_per_capita_by_state.png
├── plot_04_state_position_heatmap.png
└── plot_05_choropleth_nfl_per_capita.png
```

---

## Known Limitations

- **Join method:** `athlete_id` (cfbfastR) = `espn_id` (nflreadr) is imperfect. Some NFL players without a matching ESPN ID will be missed.
- **Definition of "made NFL":** Requires a non-`NA` `rookie_season` in nflreadr — i.e., the player appeared on a real roster. Draft picks who never played are excluded by design.
- **Population denominator:** Uses ACS 2022 5-year estimates for all years. States with significant population shifts over the analysis window may show slight distortion.
- **Recent recruits:** Players from 2020–2023 cohorts may not yet have had time to reach the NFL, which can understate production for recent years.

---

## Maintainer

**Jake** — questions, issues, and PRs welcome.
