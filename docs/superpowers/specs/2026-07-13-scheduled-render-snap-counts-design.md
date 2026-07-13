# Scheduled Auto-Render + Snap Counts — Design

**Date:** 2026-07-13
**Status:** Approved

## Goal

Two independent features:

1. The site re-renders and deploys automatically on a schedule (no manual `source("render.R")` + push).
2. Each team page gains a "Snap Counts (2022–2024)" section showing per-player snap-share history.

## Decision: GitHub Actions cron, not Shiny

The original request was "convert to Shiny for scheduled updates," but GitHub Pages cannot host a Shiny app, and the actual goal (automatic refresh) is fully served by re-rendering the existing static R Markdown site on a schedule. Decision: keep the static site and structure unchanged; add a scheduled GitHub Actions workflow. No Shiny rewrite.

## Feature 1: Scheduled render via GitHub Actions

New file `.github/workflows/render.yml`.

**Triggers**
- `schedule`: daily cron at `0 10 * * *` (10:00 UTC ≈ 6 AM ET, after the nflverse nightly data refresh).
- `workflow_dispatch`: manual rebuilds from the GitHub UI.
- `push` to the default branch, ignoring paths that don't affect output (e.g. `docs/**` itself), so code changes deploy immediately without re-trigger loops.

**Job steps**
1. Checkout with `contents: write` permission.
2. `r-lib/actions/setup-r` (with RSPM binaries) + `r-lib/actions/setup-pandoc`.
3. `r-lib/actions/setup-r-dependencies` — installs and caches the package library. Requires a minimal `DESCRIPTION` file at the repo root listing the packages currently in `render.R`'s `pkgs` vector under `Imports`, with `Remotes`/repos pointing at the nflverse r-universe for nflreadr/nflfastR.
4. `Rscript render.R`.
5. Commit `docs/` and push, only if rendered output changed (guard with `git diff --quiet` or equivalent auto-commit action). Commit author: a bot identity; message includes the date.

**Notes**
- The nflverse data (~150MB) is re-downloaded each run; acceptable at daily frequency, no data cache in v1.
- `render.R` stays the single entry point — local workflow unchanged.
- Pages continues to serve from `docs/` on the default branch.

## Feature 2: Snap counts on team pages

**Data (`_common.R`)**
- Load `nflreadr::load_snap_counts(2022:2024)` inside the same `tryCatch(..., error = function(e) NULL)` pattern used for NGS/FTN data → `snaps`.
- Build `snap_summary` once, league-wide: group by `player`, `position`, `team`, `season`; compute games played and snap-weighted mean `offense_pct` and `defense_pct` (weight by `offense_snaps`/`defense_snaps` game totals). Team abbreviations normalized via `nflreadr::clean_team_abbrs()` to match `params$team` values.

**Presentation (`nfl_sharp_team.Rmd`)**
- New section "Snap Counts (2022–2024)" after the existing draft/trades/FA tables.
- Two gt tables styled like the existing team-page tables:
  - **Offense**: Player, Pos, 2022 %, 2023 %, 2024 % (offensive snap share), sorted by 2024 desc (NAs last).
  - **Defense**: same shape for defensive snap share.
- **Qualifier:** player appears only if snap share ≥ 25% in at least one of the three seasons for that team (keeps tables to core contributors).
- **Team attribution:** players are listed under the team they played the snaps for, not the current 2025 roster (approved explicitly).
- Chunk guarded with `eval=!is.null(snaps)` and an `if (!is.null(snaps))` body, matching the existing conditional-chunk convention, so pages render if snap data is unavailable.
- Missing seasons render as em-dash/NA, not 0.

## Out of scope

- Shiny app or any server-hosted interactivity.
- Mapping historical snaps onto current 2025 rosters.
- Special-teams snap counts.
- Caching nflverse data between CI runs.

## Testing

- Local: `source("render.R")` renders league page + 32 team pages without errors; spot-check a team page (e.g. KC) for correct snap % values against nflverse raw data.
- CI: trigger `workflow_dispatch` once after merge; confirm the run completes, commits refreshed `docs/`, and Pages updates.
