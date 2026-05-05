# =============================================================================
# NFL Player Geographic Origin Analysis
# EDA Starter Script — Option A: cfbfastR athlete_id ⟶ nflreadr espn_id
#
# Goal: Identify under-recruited geographic hotspots by mapping where
#       NFL players come from, per capita, broken out by position group.
#
# Data sources:
#   1. cfbfastR       — HS recruiting data w/ city/state/lat/long
#   2. nflreadr       — NFL player rosters and career data
#   3. tidycensus     — US Census state population (per-capita denominator)
#
# Author: Jake Hiltscher
# =============================================================================


# -----------------------------------------------------------------------------
# 0. SETUP — Packages & API Key
# -----------------------------------------------------------------------------

# Install any missing packages
pkgs <- c(
  "cfbfastR",    # HS recruiting data
  "nflreadr",    # NFL rosters and player metadata
  "tidyverse",   # dplyr, ggplot2, purrr, etc.
  "tidycensus",  # US Census population data
  "janitor",     # clean_names() and tabyl()
  "glue",        # string interpolation
  "fuzzyjoin",   # fallback fuzzy name join (Phase 3 supplement)
  "sf",          # spatial features for mapping
  "tigris"       # US state/county shapefiles for choropleth maps
)

installed <- rownames(installed.packages())
to_install <- pkgs[!pkgs %in% installed]
if (length(to_install) > 0) install.packages(to_install)

library(cfbfastR)
library(nflreadr)
library(tidyverse)
library(tidycensus)
library(janitor)
library(glue)
library(sf)
library(tigris)

setwd("C:/Users/D00542417/vsc/fun/recruiting")

# ---- API Keys ---------------------------------------------------------------
# Confirm cfbfastR key is loaded
stopifnot(
  "CFBD_API_KEY not found in environment. See .Renviron setup above." =
    nchar(Sys.getenv("CFBD_API_KEY")) > 0
)


# =============================================================================
# PHASE 1: Build the Recruiting Corpus
# =============================================================================
# Pull all HS recruiting data from cfbfastR for a 10+ year window.
# Each row = one recruit; key columns for us:
#   athlete_id, name, position, stars, rating, city, state_province,
#   hometown_info_latitude, hometown_info_longitude, hometown_info_fips_code

RECRUIT_YEARS <- 2013:2023   # adjust window as needed


# The API rate-limits; Sys.sleep() is a polite buffer.
recruits_raw <- map_dfr(RECRUIT_YEARS, function(yr) {
  Sys.sleep(0.5)
  cfbd_recruiting_player(yr, recruit_type = "HighSchool")
}) |>
  clean_names()

# ---- 1a. Quick data quality check -------------------------------------------
glimpse(recruits_raw)

# Key columns that must exist for this analysis
required_recruit_cols <- c(
  "athlete_id", "name", "position", "stars", "rating",
  "city", "state_province",
  "hometown_info_latitude", "hometown_info_longitude"
)

missing_cols <- setdiff(required_recruit_cols, names(recruits_raw))
if (length(missing_cols) > 0) {
  warning(glue("Missing expected columns: {paste(missing_cols, collapse = ', ')}"))
}

# ---- 1b. Missing value audit ------------------------------------------------
recruits_raw |>
  summarise(across(all_of(required_recruit_cols), ~ mean(is.na(.)) * 100)) |>
  pivot_longer(everything(), names_to = "column", values_to = "pct_missing") |>
  arrange(desc(pct_missing)) |>
  print()

# ---- 1c. Distribution snapshots ---------------------------------------------

# Volume by year
recruits_raw |>
  count(year) |>
  print()

# Volume by state (top 20)
recruits_raw |>
  count(state_province, sort = TRUE, name = "n_recruits") |>
  slice_head(n = 20) |>
  print()

# Position distribution
recruits_raw |>
  count(position, sort = TRUE) |>
  print()

# Star distribution
recruits_raw |>
  count(stars) |>
  mutate(pct = n / sum(n) * 100) |>
  print()

# ---- 1d. Standardize position groups ----------------------------------------
# cfbfastR positions are granular (e.g., "PRO", "ILB", "OT").
# Map them to broader groups for the position x geography analysis.
position_group_map <- tribble(
  ~position,  ~position_group,
  # Offense — skill
  "QB",       "QB",
  "PRO",      "QB",    # pro-style QB label used in some years
  "DUAL",     "QB",    # dual-threat QB label
  "RB",       "RB",
  "ATH",      "ATH",
  "WR",       "WR",
  "TE",       "TE",
  "APB",      "RB",    # all-purpose back
  # Offense — line
  "OT",       "OL",
  "OG",       "OL",
  "C",        "OL",
  "OL",       "OL",
  # Defense — line
  "DT",       "DL",
  "DE",       "DL",
  "WDE",      "DL",
  "SDE",      "DL",
  "DL",       "DL",
  # Defense — LB
  "ILB",      "LB",
  "OLB",      "LB",
  "LB",       "LB",
  # Defense — secondary
  "CB",       "DB",
  "S",        "DB",
  "SAF",      "DB",
  "DB",       "DB",
  "FS",       "DB",
  "SS",       "DB",
  # Special teams
  "K",        "ST",
  "P",        "ST",
  "LS",       "ST",
  "KR",       "ST",
  "PR",       "ST"
)

recruits <- recruits_raw |>
  left_join(position_group_map, by = "position") |>
  mutate(
    position_group = coalesce(position_group, "OTHER"),
    # Ensure athlete_id is character for consistent joining later
    athlete_id = as.character(athlete_id)
  )


# =============================================================================
# PHASE 2: Build the NFL Player Corpus
# =============================================================================
# nflreadr::load_players() — player-level metadata; espn_id is the join key.
# nflreadr::load_rosters() — season-level rosters; useful for career length.
# nflreadr::load_draft_picks() — confirms "made it" to NFL (draft is not enough;
#                                 use rookie_season from load_players() instead).

message("Pulling NFL player data from nflreadr...")

nfl_players_raw <- nflreadr::load_players() |>
  clean_names()

glimpse(nfl_players_raw)

# ---- 2a. Filter to players who actually played (not just drafted) ------------
# rookie_season being non-NA means they appeared on a real roster.
nfl_players <- nfl_players_raw |>
  filter(
    !is.na(rookie_season),      # appeared in an NFL season
    !is.na(espn_id)             # has an ESPN ID we can join on
  ) |>
  mutate(espn_id = as.character(espn_id)) |>
  select(
    espn_id,
    nfl_display_name  = display_name,
    nfl_position      = position,
    nfl_position_group = position_group,
    college_name,
    college_conference,
    rookie_season,
    last_season,
    draft_round
  )

# ---- 2b. Quick look at position breakdown -----------------------------------
nfl_players |>
  count(nfl_position_group, sort = TRUE) |>
  print()


# =============================================================================
# PHASE 3: Join — Recruit ⟶ NFL Player
# =============================================================================
# Primary join: cfbfastR athlete_id == nflreadr espn_id
# Both columns standardized to character in Phase 1 & 2.

message("Joining recruiting data to NFL player data...")

recruits_joined <- recruits |>
  left_join(
    nfl_players,
    by = c("athlete_id" = "espn_id")
  ) |>
  mutate(
    made_nfl = !is.na(rookie_season)
  )

# ---- 3a. Join quality check -------------------------------------------------
join_summary <- recruits_joined |>
  summarise(
    total_recruits    = n(),
    matched_nfl       = sum(made_nfl),
    match_rate_pct    = round(mean(made_nfl) * 100, 2),
    unmatched         = sum(!made_nfl)
  )

print(join_summary)

# Break down match rate by star rating — expect higher stars = higher match rate
recruits_joined |>
  group_by(stars) |>
  summarise(
    n          = n(),
    made_nfl   = sum(made_nfl),
    match_rate = round(mean(made_nfl) * 100, 2)
  ) |>
  arrange(desc(stars)) |>
  print()

# ---- 3b. Save the joined dataset --------------------------------------------
# Cache this so you don't have to re-pull the API every session.
saveRDS(recruits_joined, "recruits_joined.rds")
# To reload: recruits_joined <- readRDS("recruits_joined.rds")


# =============================================================================
# PHASE 4: Census Population — Per-Capita Denominator
# =============================================================================
# We want NFL players per capita by state.
# Using ACS 5-year 2022 estimates (most current stable release).
# Variable B01003_001 = Total Population.

message("Pulling Census state population data...")

state_pop <- get_acs(
  geography = "state",
  variables = "B01003_001",
  year      = 2022,
  survey    = "acs5"
) |>
  clean_names() |>
  select(state = name, population = estimate)

# Sanity check
state_pop |> arrange(desc(population)) |> slice_head(n = 10) |> print()

# Change state to abbrevations
state_pop <- state_pop |>
  mutate(state = state.abb[match(state, state.name)])

# =============================================================================
# PHASE 5: State-Level Scoring
# =============================================================================
# Count NFL players by state of origin (from recruiting data) and
# calculate per-capita rates.

# ---- 5a. Overall NFL players by state of origin -----------------------------
state_nfl_overall <- recruits_joined |>
  filter(made_nfl, !is.na(state_province)) |>
  count(state_province, name = "nfl_players") |>
  left_join(state_pop, by = c("state_province" = "state")) |>
  filter(!is.na(population)) |>
  mutate(
    nfl_per_1m    = round(nfl_players / population * 1e6, 2),
    nfl_per_100k  = round(nfl_players / population * 1e5, 2)
  ) |>
  arrange(desc(nfl_per_1m))

message("Top 15 states by NFL players per 1M residents:")
state_nfl_overall |> slice_head(n = 15) |> print()

# ---- 5b. NFL players by state AND position group ----------------------------
state_nfl_by_position <- recruits_joined |>
  filter(made_nfl, !is.na(state_province), !is.na(position_group)) |>
  count(state_province, position_group, name = "nfl_players") |>
  left_join(state_pop, by = c("state_province" = "state")) |>
  filter(!is.na(population)) |>
  mutate(
    nfl_per_1m   = round(nfl_players / population * 1e6, 2),
    nfl_per_100k = round(nfl_players / population * 1e5, 2)
  )

# ---- 5c. Answer your three research questions -------------------------------

# Q1: Do skill positions (WR, RB, ATH) come out of California?
q1 <- state_nfl_by_position |>
  filter(position_group %in% c("WR", "RB", "ATH")) |>
  group_by(state_province) |>
  summarise(
    nfl_players  = sum(nfl_players),
    population   = first(population),
    nfl_per_1m   = round(sum(nfl_players) / first(population) * 1e6, 2)
  ) |>
  arrange(desc(nfl_per_1m))

message("\nQ1 — Skill positions (WR/RB/ATH) by state, per 1M residents:")
q1 |> slice_head(n = 15) |> print()

# Q2: Do DL/OL come out of Texas?
q2 <- state_nfl_by_position |>
  filter(position_group %in% c("DL", "OL")) |>
  group_by(state_province) |>
  summarise(
    nfl_players  = sum(nfl_players),
    population   = first(population),
    nfl_per_1m   = round(sum(nfl_players) / first(population) * 1e6, 2)
  ) |>
  arrange(desc(nfl_per_1m))

message("\nQ2 — Linemen (DL/OL) by state, per 1M residents:")
q2 |> slice_head(n = 15) |> print()

# Q3: Do QBs come out of Utah, Ohio, or Georgia?
q3 <- state_nfl_by_position |>
  filter(position_group == "QB") |>
  arrange(desc(nfl_per_1m))

message("\nQ3 — QBs by state, per 1M residents:")
q3 |> slice_head(n = 20) |> print()

# Spotlight your three states
q3 |>
  filter(state_province %in% c("Utah", "Ohio", "Georgia")) |>
  print()


# =============================================================================
# PHASE 6: EDA Visualizations
# =============================================================================

# ---- 6a. Recruiting volume by state (raw count) -----------------------------
recruits_joined |>
  filter(!is.na(state_province)) |>
  count(state_province, sort = TRUE) |>
  slice_head(n = 20) |>
  mutate(state_province = fct_reorder(state_province, n)) |>
  ggplot(aes(x = n, y = state_province)) +
  geom_col(fill = "#2563EB") +
  labs(
    title    = "Recruiting Volume by State (FBS, 2010–2023)",
    subtitle = "Total HS recruits per state — raw count, no per-capita adjustment",
    x = "Number of Recruits", y = NULL
  ) +
  theme_minimal(base_size = 12)

ggsave("plot_01_recruiting_volume_by_state.png", width = 9, height = 6, dpi = 150)

# ---- 6b. NFL conversion rate by state (top 20 states by total recruits) -----
top_recruit_states <- recruits_joined |>
  filter(!is.na(state_province)) |>
  count(state_province, sort = TRUE) |>
  slice_head(n = 20) |>
  pull(state_province)

recruits_joined |>
  filter(state_province %in% top_recruit_states) |>
  group_by(state_province) |>
  summarise(
    n_recruits   = n(),
    n_nfl        = sum(made_nfl),
    conversion   = mean(made_nfl) * 100
  ) |>
  mutate(state_province = fct_reorder(state_province, conversion)) |>
  ggplot(aes(x = conversion, y = state_province)) +
  geom_col(fill = "#16A34A") +
  geom_text(aes(label = glue("{round(conversion, 1)}%")),
            hjust = -0.1, size = 3.2) +
  labs(
    title    = "NFL Conversion Rate by State",
    subtitle = "% of FBS recruits who appeared in at least one NFL season | Top 20 states by recruiting volume",
    x = "% Who Reached NFL", y = NULL
  ) +
  xlim(0, max(recruits_joined |>
                filter(state_province %in% top_recruit_states) |>
                group_by(state_province) |>
                summarise(conv = mean(made_nfl) * 100) |>
                pull(conv)) + 3) +
  theme_minimal(base_size = 12)

ggsave("plot_02_nfl_conversion_by_state.png", width = 9, height = 6, dpi = 150)

# ---- 6c. Per-capita NFL production — overall --------------------------------
state_nfl_overall |>
  slice_head(n = 20) |>
  mutate(state_province = fct_reorder(state_province, nfl_per_1m)) |>
  ggplot(aes(x = nfl_per_1m, y = state_province)) +
  geom_col(fill = "#DC2626") +
  labs(
    title    = "NFL Player Production Per Capita by State",
    subtitle = "NFL players per 1,000,000 residents | Based on HS recruiting origin state",
    x = "NFL Players per 1M Residents", y = NULL
  ) +
  theme_minimal(base_size = 12)

ggsave("plot_03_nfl_per_capita_by_state.png", width = 9, height = 6, dpi = 150)

# ---- 6d. Position group heatmap: state × position --------------------------
# Subset to top states and main position groups
heatmap_states <- state_nfl_overall |> slice_head(n = 20) |> pull(state_province)
heatmap_positions <- c("QB", "WR", "RB", "TE", "OL", "DL", "LB", "DB", "ATH")

state_nfl_by_position |>
  filter(
    state_province %in% heatmap_states,
    position_group %in% heatmap_positions
  ) |>
  # Normalize within each position group for fair comparison across states
  group_by(position_group) |>
  mutate(
    scaled_per_1m = scale(nfl_per_1m)[, 1]
  ) |>
  ungroup() |>
  ggplot(aes(x = position_group, y = state_province, fill = scaled_per_1m)) +
  geom_tile(color = "white", linewidth = 0.4) +
  scale_fill_gradient2(
    low      = "#1E40AF",
    mid      = "white",
    high     = "#B91C1C",
    midpoint = 0,
    name     = "Z-score\n(per 1M)"
  ) +
  labs(
    title    = "State × Position Group NFL Production (Standardized)",
    subtitle = "Red = above average for that position | Blue = below average | Top 20 states by total NFL output",
    x = "Position Group", y = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid = element_blank())

ggsave("plot_04_state_position_heatmap.png", width = 10, height = 7, dpi = 150)

# ---- 6e. Choropleth — NFL per capita by state (requires tigris + sf) --------
options(tigris_use_cache = TRUE)
states_sf <- tigris::states(cb = TRUE, resolution = "20m") |>
  clean_names() |>
  filter(!stusps %in% c("AK", "HI", "PR", "VI", "GU", "MP", "AS")) |>
  left_join(state_nfl_overall, by = c("stusps" = "state_province"))

ggplot(states_sf) +
  geom_sf(aes(fill = nfl_per_1m), color = "white", linewidth = 0.3) +
  scale_fill_gradient(
    low      = "#FEF9C3",
    high     = "#B91C1C",
    na.value = "grey80",
    name     = "NFL players\nper 1M"
  ) +
  labs(
    title    = "NFL Player Origins Per Capita — Contiguous US",
    subtitle = "Based on HS recruiting state, 2013–2023 recruits"
  ) +
  theme_void(base_size = 12) +
  theme(legend.position = "right")

ggsave("plot_05_choropleth_nfl_per_capita.png", width = 12, height = 7, dpi = 150)


# =============================================================================
# PHASE 7: Export Summary Tables
# =============================================================================

write_csv(state_nfl_overall,       "table_state_nfl_overall.csv")
write_csv(state_nfl_by_position,   "table_state_nfl_by_position.csv")
write_csv(recruits_joined |>
            filter(made_nfl),                "table_recruits_who_made_nfl.csv")

message("All outputs written. EDA complete.")
