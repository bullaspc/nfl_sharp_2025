# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Report

```r
# Install dependencies and render the full site:
source("render.R")
```

This writes `docs/index.html` (league overview) plus one file per team at `docs/teams/{TEAM}.html` (32 files) — `docs/` is the GitHub Pages source for this repo, so `source("render.R")` alone produces a deploy-ready tree with no manual copy step. The first run downloads ~150MB of 2025 season data from nflverse, which is cached locally afterward.

The site also re-renders automatically every day at 10:00 UTC via
`.github/workflows/render.yml` (manual runs: Actions → render-site → Run
workflow), which commits the refreshed `docs/` back to `master`.

To render a single page without the full script:
```r
report_env <- new.env(parent = globalenv())
source("_common.R", local = report_env)
rmarkdown::render("nfl_sharp_league.Rmd", output_file = "index.html", output_dir = "docs", envir = report_env)
rmarkdown::render("nfl_sharp_team.Rmd", output_file = "KC.html", output_dir = "docs/teams", envir = report_env, params = list(team = "KC"))
```

## Architecture

The report is split into three R Markdown/R files that share one data-loading pass:

- **`_common.R`** — sourced once (by `render.R`, into a shared environment reused across all 33 `rmarkdown::render()` calls). Owns package loading, data loading (`load_pbp(2025)` → `plays` → `reg`/`post`; optional `ngs_pass`/`ngs_rush`/`ngs_rec`/`player_stats`/`ftn`/`snaps`/`snap_summary` (2022–2024 snap counts) via `tryCatch`; `draft_2025`; `trades`/`free_agents`/`coaching_staff` from `data/*.csv`; `teams`), the league-wide summary objects reused by both doc types (`epa_off`, `epa_def`, `edpr`, `third_def`, `qb_base`, `rec_base`, `rush_base`, `all_teams`), the parameterized ggplot2 theme `theme_sharp(colors = ...)`, and `team_colors_for()` for team-branded accent colors. Also builds the team-page schedule table from data already loaded: `schedules_2025` (`load_schedules(2025)`) → `game_team_stats_2025` (per-game, per-team offense/defense EPA-per-play and early-down, i.e. 1st/2nd down, success rate, computed from `reg`) → `season_2025_games` (long-format, one row per team per played game, joined with `game_team_stats_2025`, carrying opponent/home-away/score/W-L-T result). Also builds three team-level summaries for the team-page league-rank table: `drive_stats` (per-drive play count and total yards gained, from `reg` grouped by `game_id`/`posteam`/`drive`) → `explosive_drives` (share of each team's drives with ≥3 plays and ≥30 total yards); `rush_off`/`pass_off` (team-level EPA-per-play and success rate split by rush vs. pass, from `reg`). Also builds `team_coaches` (each team's current head coach, derived from `schedules_2025`'s `home_coach`/`away_coach` columns by taking the most recent played game per team — nflverse has no coordinator-level dataset, so `coaching_staff` from `data/coaches.csv` tracks coordinators/other staff by hand instead, same pattern as `trades`/`free_agents`). Also loads `rosters_2025` (`load_rosters(2025)`, optional via `tryCatch`) → `current_roster_ids` (distinct team + PFR player ID pairs), joined onto `snap_summary` as an `on_roster` flag (matched on PFR player ID, since `load_snap_counts()` and `load_rosters()` share that ID system but not player-name formatting) for the team-page snap-count table's "on roster now" column.
- **`nfl_sharp_league.Rmd`** — the league overview page (light theme, `docs/index.html`): a team-index grid linking to every team page, then the four league-wide sections (Offense/Defense/QB/Skill Positions). Consumes the summary objects from `_common.R` rather than recomputing them.
- **`nfl_sharp_team.Rmd`** — a `params$team`-driven single-team page (light/team-branded theme, rendered once per team into `docs/teams/{TEAM}.html`). Body is the former per-team loop content: a Coaching Staff table (head coach from `team_coaches`, plus any coordinators/staff for that team from `coaching_staff`), pass-rate-by-down-and-distance chart, draft class, trades, and free agent signings tables, a League Ranking Metrics table (each team's value and 1–32 rank, color-scaled green-to-red via `gt_color_rows`, for explosive drive %, rush/pass success rate, and rush/pass EPA/play, sourced from `explosive_drives`/`rush_off`/`pass_off` in `_common.R`), a 2025 season schedule & results table (`season_2025_games` filtered to `tm`, with per-game offense/defense EPA-per-play and early-down success rate), and snap counts (2022–2024 share tables plus an "On Roster Now" column sourced from `snap_summary$on_roster`).

**Conditional chunks:** Chunks that depend on optional data use `eval=!is.null(ngs_pass)` and guard their body with `if (!is.null(...))` — this is intentional so the report renders even when NGS/FTN data is unavailable mid-season.

**Theme:** `theme_sharp(base_size, colors)` in `_common.R` takes a `colors` list (`bg`/`panel`/`grid`/`text`/`muted`/`accent`/`accent2`/`green`/`red`). `palette_dark` (unused by the current pages but kept available) and `palette_light` (both the league page and the team page base) live in `_common.R`; `team_colors_for(team_abbr, teams)` returns a team-branded variant of `palette_light` with `accent`/`accent2` swapped to that team's own colors. Each Rmd's setup chunk unpacks its chosen palette into flat locals (`bg`, `panel`, `accent`, etc.) since the ported plotting/`gt` code references those bare names directly — this is intentional to keep the plotting code unchanged across doc types. CSS mirrors this split: `styles_base.css` (structural, shared) + `styles_dark_vars.css` or `styles_light_vars.css` (`:root` color vars only) via a `css: [vars, base]` list in each Rmd's YAML. Team pages additionally inject an inline `<style>` overriding `--accent`/`--accent2` with that team's colors so page chrome (h2, TOC, title border) matches the charts.

**Team page rendering:** `nfl_sharp_team.Rmd` is knit once per team abbreviation via `params = list(team = tm)`, reusing the same `envir` across all 32 calls (populated once from `_common.R`) rather than reloading data 32 times. Any edits to the per-team body chunk must preserve `print(p)` — required because `p` is an assigned ggplot object inside a `results='asis'` chunk.

## Key Metrics

- **EPA/play** — Expected Points Added per play (gold standard efficiency)
- **EDPR** — Early Down Pass Rate (pass rate on 1st & 2nd down; Warren Sharp signature metric)
- **Success Rate** — % of plays with positive EPA
- **CPOE** — Completion % Over Expected (QB accuracy adjusted for difficulty)
- **QB qualifier** — minimum 150 attempts; receiver qualifier — minimum 50 targets; rusher qualifier — minimum 60 carries

## Requirements

- R >= 4.1.0
- Packages: `nflreadr`, `nflfastR`, `tidyverse`, `ggrepel`, `gt`, `gtExtras`, `scales`, `glue`, `rmarkdown`, `knitr`
- Internet connection for first data download; ~500MB disk space for cache
