---
name: trades-freeagents-database
description: CSV-based trades and free agent database integrated into the NFL Sharp 2025 team report
metadata:
  type: project
---

# Trades & Free Agents Database

## Overview

Two manually maintained CSV files (`data/trades.csv`, `data/free_agents.csv`) that are loaded into the R Markdown report and rendered as styled `gt` tables inside each team's section.

## File Structure

```
data/
  trades.csv
  free_agents.csv
```

### `data/trades.csv`

| Column | Type | Description |
|---|---|---|
| player | character | Full player name |
| position | character | Position abbreviation (QB, WR, RB, TE, OL, DL, LB, CB, S) |
| age | integer | Age at time of trade |
| from_team | character | Sending team (nflverse abbr, e.g. LV) |
| to_team | character | Receiving team (nflverse abbr) |
| date | date (YYYY-MM-DD) | Date of trade |
| draft_comp | character | Draft picks exchanged (e.g. "2025 2nd, 2026 4th"); empty string if none |
| off_snap_pct | integer | Prior season offensive snap % (0–100) |
| route_participation | integer | Prior season route participation % (0–100; NA for non-receivers) |
| targets | integer | Prior season targets (NA for non-receivers) |
| receptions | integer | Prior season receptions (NA for non-receivers) |
| rec_yards | integer | Prior season receiving yards |
| rec_tds | integer | Prior season receiving TDs |
| carries | integer | Prior season rush attempts (NA for non-rushers) |
| rush_yards | integer | Prior season rush yards |
| rush_tds | integer | Prior season rush TDs |

### `data/free_agents.csv`

All columns from `trades.csv` except `draft_comp`, plus:

| Column | Type | Description |
|---|---|---|
| contract_years | integer | Contract length in years |
| contract_aav | numeric | Average annual value ($M) |
| contract_total | numeric | Total contract value ($M) |

## Rmd Integration

### Setup chunk

Both CSVs are loaded in the `setup` chunk with `tryCatch` so the report renders even when files are empty or absent:

```r
trades <- tryCatch(
  read_csv("data/trades.csv", show_col_types = FALSE) |>
    mutate(to_team = clean_team_abbrs(to_team),
           from_team = clean_team_abbrs(from_team)),
  error = function(e) NULL
)

free_agents <- tryCatch(
  read_csv("data/free_agents.csv", show_col_types = FALSE) |>
    mutate(to_team = clean_team_abbrs(to_team),
           from_team = clean_team_abbrs(from_team)),
  error = function(e) NULL
)
```

### Team loop

Inside the existing `for (tm in all_teams)` loop, after the draft class table block, inject two conditional blocks:

1. **Trades table** — filter `trades` where `to_team == tm` OR `from_team == tm`; show if `nrow > 0`
2. **Free Agents table** — filter `free_agents` where `to_team == tm`; show if `nrow > 0`

Each table is styled with the existing dark theme (`panel`, `grid`, `bg`, `text_c`, `accent`) and `gt_color_rows` on `off_snap_pct` to give a visual snap-usage signal.

**Trades table columns shown:** Player, Pos, Age, From, To, Draft Comp, Snap%, Routes%, Targets, Rec, Yards, TDs, Carries, Rush Yds, Rush TDs

**FA table columns shown:** Player, Pos, Age, From, Yrs, AAV, Total, Snap%, Routes%, Targets, Rec, Yards, TDs, Carries, Rush Yds, Rush TDs

### Column visibility

- `route_participation`, `targets`, `receptions`, `rec_yards`, `rec_tds` — hidden for pure rushers (RB with 0 targets) via `cols_hide()` only if all values in the filtered table are NA
- `carries`, `rush_yards`, `rush_tds` — hidden if all NA in the filtered table

## Data Entry

- Files are maintained manually in any spreadsheet editor or text editor
- Team abbreviations must match nflverse convention (`clean_team_abbrs()` handles common variants)
- Stats represent the prior season (2024) for 2025 offseason moves
- Empty CSVs (header row only) are valid — tables simply won't appear

## Error Handling

- Missing file → `tryCatch` returns `NULL` → table blocks are skipped silently
- Empty file (header only) → `nrow == 0` → table blocks are skipped
- NA values in numeric stat columns render as `—` via `fmt_missing()`
