# =============================================================================
# NFL Sharp 2025 — Shared data prep, theme, and helpers
# Sourced once by render.R into a shared environment, then reused across the
# league page render and all 32 team page renders (avoids reloading pbp /
# recomputing league-wide summaries 33 times).
# =============================================================================

# ── Packages ──────────────────────────────────────────────────────────────────
suppressPackageStartupMessages({
  library(nflreadr)
  library(nflfastR)
  library(tidyverse)
  library(ggrepel)
  library(gt)
  library(gtExtras)
  library(scales)
  library(glue)
})

# ── Color Palettes ───────────────────────────────────────────────────────────
palette_dark <- list(
  bg      = "#0d0d0d",
  panel   = "#141414",
  grid    = "#1e1e1e",
  text    = "#e8e8e8",
  muted   = "#666666",
  accent  = "#00d4ff",
  accent2 = "#ff6b35",
  green   = "#00e676",
  red     = "#ff1744"
)

palette_light <- list(
  bg      = "#ffffff",
  panel   = "#f5f5f5",
  grid    = "#e2e2e2",
  text    = "#111111",
  muted   = "#6b6b6b",
  accent  = "#0072ce",
  accent2 = "#d64545",
  green   = "#1b9e5a",
  red     = "#d32f2f"
)

# ── ggplot2 theme (parameterized: dark / light / team-branded) ───────────────
theme_sharp <- function(base_size = 11, colors = palette_dark) {
  theme_minimal(base_size = base_size) +
  theme(
    plot.background    = element_rect(fill = colors$bg,    color = NA),
    panel.background   = element_rect(fill = colors$panel, color = NA),
    panel.grid.major   = element_line(color = colors$grid, linewidth = 0.4),
    panel.grid.minor   = element_blank(),
    axis.text          = element_text(color = colors$muted, size = 8),
    axis.title         = element_text(color = colors$text, size = 9, face = "bold"),
    plot.title         = element_text(color = colors$text, size = 14, face = "bold", margin = margin(b = 4)),
    plot.subtitle      = element_text(color = colors$muted,  size = 9,  margin = margin(b = 12)),
    plot.caption       = element_text(color = colors$muted,  size = 7,  hjust = 1),
    legend.background  = element_rect(fill = colors$panel, color = NA),
    legend.text        = element_text(color = colors$muted, size = 8),
    legend.title       = element_text(color = colors$text, size = 8),
    strip.text         = element_text(color = colors$text, size = 9, face = "bold"),
    strip.background   = element_rect(fill = colors$grid, color = NA),
    plot.margin        = margin(12, 16, 12, 12)
  )
}

# ── Team-branded color mapping ────────────────────────────────────────────────
# Returns a colors-list shaped like `base`, with accent/accent2 swapped for the
# team's own colors. green/red stay fixed at `base`'s semantic values — several
# teams are themselves red- or green-branded, so letting team color override
# "good/bad" signal color would make charts ambiguous.
team_colors_for <- function(team_abbr, teams_df, base = palette_light) {
  tm_row <- teams_df |> filter(team_abbr == !!team_abbr)

  accent  <- if (nrow(tm_row) > 0 && !is.na(tm_row$team_color[1]))  tm_row$team_color[1]  else base$accent
  accent2 <- if (nrow(tm_row) > 0 && !is.na(tm_row$team_color2[1])) tm_row$team_color2[1] else base$accent2

  # Basic contrast safety: if the team's primary color is too light to read
  # against a white page (e.g. used for h2/TOC text via CSS vars), fall back
  # to a fixed, readable accent rather than doing full WCAG contrast math.
  luminance <- function(hex) {
    rgb <- grDevices::col2rgb(hex)
    (0.299 * rgb[1, ] + 0.587 * rgb[2, ] + 0.114 * rgb[3, ]) / 255
  }
  if (luminance(accent) > 0.75) accent <- palette_dark$accent2

  modifyList(base, list(accent = accent, accent2 = accent2))
}

theme_set(theme_sharp(colors = palette_dark))

# ── Load Data ─────────────────────────────────────────────────────────────────
message("Loading 2025 play-by-play data...")
pbp_raw <- load_pbp(2025)

# All plays: regular season + playoffs
plays <- pbp_raw |>
  filter(
    play_type %in% c("pass", "run"),
    !is.na(epa),
    !is.na(posteam)
  )

# NGS data
ngs_pass <- tryCatch(
  load_nextgen_stats(seasons = 2025, stat_type = "passing"),
  error = function(e) NULL
)
ngs_rush <- tryCatch(
  load_nextgen_stats(seasons = 2025, stat_type = "rushing"),
  error = function(e) NULL
)
ngs_rec <- tryCatch(
  load_nextgen_stats(seasons = 2025, stat_type = "receiving"),
  error = function(e) NULL
)

# Player stats
player_stats <- tryCatch(
  load_player_stats(seasons = 2025),
  error = function(e) NULL
)

# FTN charting (play action, coverage, etc.)
ftn <- tryCatch(
  load_ftn_charting(seasons = 2025),
  error = function(e) NULL
)

# 2025 Draft picks
draft_2025 <- tryCatch(
  load_draft_picks(seasons = 2026) |>
    mutate(team = clean_team_abbrs(team)) |>
    select(team, round, pick, position, full_name = pfr_player_name, college) |>
    filter(!is.na(full_name)),
  error = function(e) NULL
)

# Trades & free agent signings
trades <- tryCatch(
  read_csv("data/trades.csv", show_col_types = FALSE) |>
    mutate(
      to_team   = clean_team_abbrs(to_team),
      from_team = clean_team_abbrs(from_team)
    ),
  error = function(e) NULL
)

free_agents <- tryCatch(
  read_csv("data/free_agents.csv", show_col_types = FALSE) |>
    mutate(
      to_team   = clean_team_abbrs(to_team),
      from_team = clean_team_abbrs(from_team)
    ),
  error = function(e) NULL
)

# 2024 (last season) schedule, results, and per-game team EPA/success rate
# for the team-page "Season Schedule & Results" table.
message("Loading 2024 play-by-play and schedule data (last season)...")
pbp_2024_raw <- tryCatch(load_pbp(2024), error = function(e) NULL)

plays_2024 <- if (!is.null(pbp_2024_raw)) {
  pbp_2024_raw |>
    filter(
      season_type == "REG",
      play_type %in% c("pass", "run"),
      !is.na(epa),
      !is.na(posteam)
    )
} else NULL

schedules_2024 <- tryCatch(load_schedules(2024), error = function(e) NULL)

# Per-game, per-team offense/defense EPA-per-play and early-down (1st/2nd)
# success rate, one row per team per game.
game_team_stats_2024 <- if (!is.null(plays_2024)) {
  off <- plays_2024 |>
    group_by(game_id, team = posteam) |>
    summarise(
      off_epa_play = mean(epa),
      off_edsr     = mean(success[down %in% c(1, 2)], na.rm = TRUE),
      .groups = "drop"
    )
  def <- plays_2024 |>
    group_by(game_id, team = defteam) |>
    summarise(
      def_epa_play = mean(epa),
      def_edsr     = mean(success[down %in% c(1, 2)], na.rm = TRUE),
      .groups = "drop"
    )
  full_join(off, def, by = c("game_id", "team"))
} else NULL

# Long-format 2024 schedule: one row per team per played game, with the
# opponent, home/away, final score, and W/L/T result from that team's side.
season_2024_games <- if (!is.null(schedules_2024) && !is.null(game_team_stats_2024)) {
  reg_2024 <- schedules_2024 |> filter(game_type == "REG")

  home <- reg_2024 |>
    transmute(game_id, week, gameday, team = home_team, opponent = away_team,
              is_home = TRUE, team_score = home_score, opp_score = away_score)
  away <- reg_2024 |>
    transmute(game_id, week, gameday, team = away_team, opponent = home_team,
              is_home = FALSE, team_score = away_score, opp_score = home_score)

  bind_rows(home, away) |>
    filter(!is.na(team_score), !is.na(opp_score)) |>
    mutate(
      result = case_when(
        team_score > opp_score ~ "W",
        team_score < opp_score ~ "L",
        TRUE ~ "T"
      )
    ) |>
    left_join(game_team_stats_2024, by = c("game_id", "team")) |>
    arrange(team, week)
} else NULL

# Snap counts (2022–2024) for team-page snap share tables
snaps <- tryCatch(
  load_snap_counts(seasons = 2022:2024),
  error = function(e) NULL
)

# Per player/team/season snap share. A player's season share is
# sum(player snaps) / sum(team snaps in games the player appeared in);
# per-game team totals are recovered as player_snaps / player_pct.
snap_summary <- if (!is.null(snaps)) {
  season_share <- function(snap_n, pct) {
    ok <- !is.na(pct) & pct > 0 & !is.na(snap_n)
    if (!any(ok)) return(NA_real_)
    sum(snap_n[ok]) / sum(snap_n[ok] / pct[ok])
  }
  snaps |>
    filter(game_type == "REG") |>
    mutate(team = clean_team_abbrs(team)) |>
    group_by(player, position, team, season) |>
    summarise(
      games   = n(),
      off_pct = season_share(offense_snaps, offense_pct),
      def_pct = season_share(defense_snaps, defense_pct),
      .groups = "drop"
    )
} else NULL

# Team logos/colors
teams <- load_teams()

# Helper: join team colors
add_team_colors <- function(df, team_col = "team") {
  df |> left_join(
    teams |> select(team_abbr, team_color, team_color2, team_logo_espn),
    by = setNames("team_abbr", team_col)
  )
}

# Reg season only filter
reg  <- plays |> filter(season_type == "REG")
post <- plays |> filter(season_type == "POST")

all_teams <- sort(unique(reg$posteam))

message("Data loaded. Building league-wide summaries...")

# ── League-wide summaries ─────────────────────────────────────────────────────
# Computed once here so both the league page and every team page (for league
# rank lookups) can reference them without recomputation.

epa_off <- reg |>
  group_by(posteam) |>
  summarise(
    epa_per_play  = mean(epa),
    success_rate  = mean(success, na.rm = TRUE),
    n_plays       = n(),
    .groups = "drop"
  ) |>
  rename(team = posteam) |>
  add_team_colors()

edpr <- reg |>
  filter(down %in% c(1, 2)) |>
  group_by(posteam) |>
  summarise(
    EDPR       = mean(pass == 1),
    edpr_epa   = mean(epa[pass == 1], na.rm = TRUE),
    n          = n(),
    .groups    = "drop"
  ) |>
  rename(team = posteam) |>
  add_team_colors() |>
  arrange(desc(EDPR))

epa_def <- reg |>
  group_by(defteam) |>
  summarise(
    epa_allowed     = mean(epa),
    success_allowed = mean(success, na.rm = TRUE),
    pass_epa_all    = mean(epa[pass == 1], na.rm = TRUE),
    run_epa_all     = mean(epa[rush == 1], na.rm = TRUE),
    n_plays         = n(),
    .groups         = "drop"
  ) |>
  rename(team = defteam) |>
  add_team_colors()

third_def <- reg |>
  filter(down == 3) |>
  group_by(defteam) |>
  summarise(
    conv_allowed = mean(first_down == 1, na.rm = TRUE),
    epa_3rd      = mean(epa),
    n            = n(),
    .groups      = "drop"
  ) |>
  rename(team = defteam) |>
  add_team_colors() |>
  arrange(conv_allowed)

qb_base <- reg |>
  filter(pass == 1, !is.na(passer_id), !is.na(cpoe)) |>
  group_by(passer_id, passer, posteam) |>
  summarise(
    attempts    = n(),
    cpoe        = mean(cpoe, na.rm = TRUE),
    epa_att     = mean(epa),
    air_yds     = mean(air_yards, na.rm = TRUE),
    .groups     = "drop"
  ) |>
  filter(attempts >= 150) |>
  rename(team = posteam) |>
  add_team_colors()

rec_base <- reg |>
  filter(pass == 1, !is.na(receiver_id), !is.na(receiver)) |>
  group_by(receiver_id, receiver, posteam) |>
  summarise(
    targets    = n(),
    catches    = sum(complete_pass, na.rm = TRUE),
    catch_pct  = mean(complete_pass, na.rm = TRUE),
    yac        = mean(yards_after_catch, na.rm = TRUE),
    air_yds    = mean(air_yards, na.rm = TRUE),
    epa_target = mean(epa),
    cpoe_avg   = mean(cpoe, na.rm = TRUE),
    .groups    = "drop"
  ) |>
  filter(targets >= 50) |>
  rename(team = posteam) |>
  add_team_colors()

team_targets <- reg |>
  filter(pass == 1, !is.na(posteam)) |>
  count(posteam, name = "team_total_targets")

rec_base <- rec_base |>
  left_join(team_targets, by = c("team" = "posteam")) |>
  mutate(target_share = targets / team_total_targets)

rush_base <- reg |>
  filter(rush == 1, !is.na(rusher_id), !is.na(rusher)) |>
  group_by(rusher_id, rusher, posteam) |>
  summarise(
    carries    = n(),
    epa_carry  = mean(epa),
    success_rt = mean(success, na.rm = TRUE),
    ypc        = mean(yards_gained, na.rm = TRUE),
    .groups    = "drop"
  ) |>
  filter(carries >= 60) |>
  rename(team = posteam) |>
  add_team_colors()

message("Shared data ready.")
