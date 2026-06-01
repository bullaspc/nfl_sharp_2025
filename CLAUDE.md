# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Report

```r
# Install dependencies and render the HTML report:
source("render.R")
```

Output is written to `output/nfl_sharp_2025.html`. The first run downloads ~150MB of 2025 season data from nflverse, which is cached locally afterward.

To render without the setup script:
```r
rmarkdown::render("nfl_sharp_2025.Rmd", output_file = "output/nfl_sharp_2025.html")
```

## Architecture

This is a single-file R Markdown report (`nfl_sharp_2025.Rmd`) that loads data, computes all metrics inline, and renders to a self-contained HTML document with a custom dark theme (`styles.css`).

**Data flow in `setup` chunk:**
1. `load_pbp(2025)` — primary play-by-play data filtered to `pass`/`run` play types with valid EPA
2. `reg` / `post` — split of `plays` into regular season vs. playoffs; most analysis uses `reg`
3. Optional sources loaded with `tryCatch` (return `NULL` if unavailable): `ngs_pass`, `ngs_rush`, `ngs_rec` (Next Gen Stats), `player_stats`, `ftn` (FTN charting for play-action)
4. `teams` — logo/color metadata; `add_team_colors()` helper joins this onto any data frame with a team column

**Conditional chunks:** Chunks that depend on optional data use `eval=!is.null(ngs_pass)` and guard their body with `if (!is.null(...))` — this is intentional so the report renders even when NGS/FTN data is unavailable mid-season.

**Theme:** `theme_sharp()` is a ggplot2 theme defined in setup and set as the global default via `theme_set()`. Dark palette constants (`bg`, `panel`, `grid`, `text_c`, `muted`, `accent`, `accent2`, `green_c`, `red_c`) are defined once in setup and reused in both ggplot2 and `gt` table styling.

**Team summaries loop:** The final section iterates over all 32 teams (`all_teams`) and dynamically generates a `##` heading and chart per team using `results='asis'` and `cat(glue(...))` — any edits there must preserve `print(p)` inside the loop since ggplot objects inside loops require explicit printing.

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
