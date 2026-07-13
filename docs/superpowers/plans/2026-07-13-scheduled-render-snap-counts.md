# Scheduled Auto-Render + Snap Counts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-render the static site daily via GitHub Actions, and add 2022–2024 snap-count tables (offense + defense snap share) to every team page.

**Architecture:** The existing R Markdown static site is unchanged in structure. A new workflow renders it on a cron and commits `docs/` back to the repo (GitHub Pages source). Snap data joins the existing shared-data pass in `_common.R` and is consumed by a new conditional chunk in `nfl_sharp_team.Rmd`, following the repo's existing `tryCatch → NULL → eval-guard` pattern for optional data.

**Tech Stack:** R Markdown, nflreadr (`load_snap_counts`), gt, GitHub Actions with `r-lib/actions`.

**Spec:** `docs/superpowers/specs/2026-07-13-scheduled-render-snap-counts-design.md`

## Global Constraints

- No Shiny; the site stays a static R Markdown render into `docs/`.
- `render.R` remains the single entry point; local `source("render.R")` behavior must not change.
- Snap-count seasons: exactly 2022–2024; offense and defense only (no special teams).
- Qualifier: player shown only if snap share ≥ 25% in at least one of the three seasons for that team.
- Players are attributed to the team they played the snaps for (no roster remapping).
- Optional-data pattern: load with `tryCatch(..., error = function(e) NULL)`, guard chunks with `eval=` + `if (!is.null(...))`.
- Missing seasons display as "—" (via `fmt_missing`), never 0.
- `offense_pct`/`defense_pct` from nflreadr are fractions in [0, 1] (verified against 2024 data).
- Repo facts: remote is `https://github.com/bullaspc/nfl_sharp_2025.git`, working branch `master`. There is no test framework; verification = running R snippets and rendering pages.
- The working tree has unrelated uncommitted changes (`CLAUDE.md`, `README.md`, `data/trades.csv`, `docs/index.html`, rendered team pages). Every commit step must `git add` explicit paths only — never `git add -A` or `git add .`.

---

### Task 1: DESCRIPTION manifest + GitHub Actions render workflow

**Files:**
- Create: `DESCRIPTION`
- Create: `.github/workflows/render.yml`

**Interfaces:**
- Consumes: `render.R` (existing entry point, unchanged).
- Produces: a workflow named `render-site` that later tasks don't depend on at code level; Task 4 documents it.

- [ ] **Step 1: Create `DESCRIPTION`**

This is a dependency manifest for `r-lib/actions/setup-r-dependencies` (which installs and caches the listed packages on the runner), not an installable package. The `Imports` list mirrors the `pkgs` vector in `render.R`.

```dcf
Package: nflsharp
Type: Package
Title: NFL Sharp 2025 Static Report
Version: 1.0.0
Description: Dependency manifest for the scheduled GitHub Actions render
    of the NFL Sharp 2025 static site. Not an installable package.
Encoding: UTF-8
Imports:
    nflreadr,
    nflfastR,
    tidyverse,
    ggrepel,
    gt,
    gtExtras,
    scales,
    glue,
    rmarkdown,
    knitr
```

- [ ] **Step 2: Verify `DESCRIPTION` parses**

Run: `Rscript -e 'print(read.dcf("DESCRIPTION")[, "Imports"])'`
Expected: prints the Imports field listing all ten packages, no error.

- [ ] **Step 3: Create `.github/workflows/render.yml`**

Triggers: daily at 10:00 UTC (~6 AM ET, after the nflverse nightly refresh), manual dispatch, and pushes to `master` that touch source files (`docs/**` is ignored so the workflow's own output commit can't retrigger a build).

```yaml
name: render-site

on:
  schedule:
    - cron: "0 10 * * *"
  workflow_dispatch:
  push:
    branches: [master]
    paths-ignore:
      - "docs/**"

permissions:
  contents: write

jobs:
  render:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: r-lib/actions/setup-pandoc@v2

      - uses: r-lib/actions/setup-r@v2
        with:
          use-public-rspm: true
          extra-repositories: "https://nflverse.r-universe.dev"

      - uses: r-lib/actions/setup-r-dependencies@v2
        with:
          cache-version: 1

      - name: Render site
        run: Rscript render.R

      - name: Commit and push docs if changed
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add docs/
          if git diff --cached --quiet; then
            echo "No changes to deploy."
          else
            git commit -m "chore: scheduled site render $(date -u +%Y-%m-%d)"
            git push
          fi
```

- [ ] **Step 4: Verify the YAML parses**

Run: `Rscript -e 'str(yaml::read_yaml(".github/workflows/render.yml"), max.level = 2)'`
Expected: a named list with `name`, `TRUE` (YAML parses the `on` key as a boolean — this is normal and harmless), `permissions`, `jobs`; no parse error. (If the `yaml` package is missing, `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/render.yml'))"` is an equivalent check.)

- [ ] **Step 5: Commit**

```bash
git add DESCRIPTION .github/workflows/render.yml
git commit -m "ci: add daily scheduled render workflow + package manifest"
```

**Note:** end-to-end CI verification (a real `workflow_dispatch` run) can only happen after this is pushed to GitHub; that is Task 4's final step, not this task's.

---

### Task 2: Load snap counts and build `snap_summary` in `_common.R`

**Files:**
- Modify: `_common.R` (insert after the `free_agents` block, i.e. after line 156, before the `# Team logos/colors` section)

**Interfaces:**
- Consumes: `nflreadr::load_snap_counts()`, `clean_team_abbrs()` (already attached via `library(nflreadr)`).
- Produces: `snaps` (raw tibble or NULL) and `snap_summary` (tibble or NULL) in the shared environment. `snap_summary` columns: `player` (chr), `position` (chr), `team` (chr, cleaned abbr), `season` (int), `games` (int), `off_pct` (dbl fraction in [0,1] or NA), `def_pct` (dbl fraction or NA). Task 3 consumes `snap_summary` by exactly these names.

- [ ] **Step 1: Add the snap-count block to `_common.R`**

Insert after the `free_agents <- tryCatch(...)` block:

```r
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
```

- [ ] **Step 2: Verify `snap_summary` against known values**

Run:

```bash
Rscript -e '
suppressPackageStartupMessages(library(tidyverse)); library(nflreadr)
snaps <- load_snap_counts(seasons = 2022:2024)
season_share <- function(snap_n, pct) {
  ok <- !is.na(pct) & pct > 0 & !is.na(snap_n)
  if (!any(ok)) return(NA_real_)
  sum(snap_n[ok]) / sum(snap_n[ok] / pct[ok])
}
snap_summary <- snaps |>
  filter(game_type == "REG") |>
  mutate(team = clean_team_abbrs(team)) |>
  group_by(player, position, team, season) |>
  summarise(games = n(),
            off_pct = season_share(offense_snaps, offense_pct),
            def_pct = season_share(defense_snaps, defense_pct),
            .groups = "drop")
stopifnot(all(snap_summary$off_pct <= 1, na.rm = TRUE))
stopifnot(all(snap_summary$def_pct <= 1, na.rm = TRUE))
mahomes <- snap_summary |> filter(player == "Patrick Mahomes", season == 2024)
print(mahomes)
stopifnot(nrow(mahomes) == 1, mahomes$team == "KC", mahomes$off_pct > 0.9)
cat("snap_summary OK\n")
'
```

Expected: prints Mahomes' 2024 KC row with `off_pct` > 0.9 and `snap_summary OK`. (This mirrors the `_common.R` code standalone so the check doesn't need the ~150MB pbp download.)

- [ ] **Step 3: Verify `_common.R` itself still sources cleanly**

Run: `Rscript -e 'report_env <- new.env(parent = globalenv()); source("_common.R", local = report_env); stopifnot(!is.null(report_env$snap_summary)); cat(nrow(report_env$snap_summary), "snap_summary rows\n")'`
Expected: the usual loading messages, then a row count (tens of thousands). Uses the local nflverse cache; no error.

- [ ] **Step 4: Commit**

```bash
git add _common.R
git commit -m "feat: load 2022-2024 snap counts and build snap_summary in shared data pass"
```

---

### Task 3: Snap-count tables on team pages

**Files:**
- Modify: `nfl_sharp_team.Rmd` (add a new chunk after the closing ``` of the `team-summary` chunk, before the final `---` separator)

**Interfaces:**
- Consumes: `snap_summary` from Task 2 (columns `player`, `position`, `team`, `season`, `off_pct`, `def_pct`); flat palette locals from the setup chunk (`panel`, `grid`, `bg`, `text_c`); `tm` (team abbr).
- Produces: a "Snap Counts (2022–2024)" section with two gt tables on every team page.

- [ ] **Step 1: Add the snap-counts chunk to `nfl_sharp_team.Rmd`**

Insert after the `team-summary` chunk (after its closing ```` ``` ````, before the `---` line near the end of the file):

````markdown
```{r snap-counts, results='asis', eval=exists("snap_summary") && !is.null(snap_summary)}
if (!is.null(snap_summary)) {
  snap_seasons <- c("2022", "2023", "2024")

  snap_wide <- function(pct_col) {
    wide <- snap_summary |>
      filter(team == tm, !is.na(.data[[pct_col]])) |>
      select(player, position, season, pct = all_of(pct_col)) |>
      pivot_wider(names_from = season, values_from = pct)
    for (s in snap_seasons) if (!s %in% names(wide)) wide[[s]] <- NA_real_
    wide |>
      filter(pmax(`2022`, `2023`, `2024`, na.rm = TRUE) >= 0.25) |>
      arrange(desc(`2024`), desc(`2023`), desc(`2022`)) |>
      select(player, position, all_of(snap_seasons))
  }

  snap_gt <- function(df) {
    df |>
      gt() |>
      cols_label(player = "Player", position = "Pos") |>
      cols_align(align = "left",   columns = player) |>
      cols_align(align = "center", columns = c(position, all_of(snap_seasons))) |>
      fmt_percent(columns = all_of(snap_seasons), decimals = 0) |>
      fmt_missing(columns = everything(), missing_text = "—") |>
      tab_options(
        table.background.color         = panel,
        column_labels.background.color = grid,
        row.striping.background_color  = bg,
        table.font.color               = text_c,
        table.font.size                = px(11),
        table.width                    = pct(60)
      )
  }

  cat("\n\n## Snap Counts (2022–2024)\n\n")
  cat("Share of team snaps in games played, ", tm,
      " snaps only. Players with ≥ 25% share in at least one season.\n\n", sep = "")

  off_df <- snap_wide("off_pct")
  if (nrow(off_df) > 0) {
    cat("\n\n**Offense**\n\n")
    print(snap_gt(off_df))
  }

  def_df <- snap_wide("def_pct")
  if (nrow(def_df) > 0) {
    cat("\n\n**Defense**\n\n")
    print(snap_gt(def_df))
  }
}
```
````

Notes for the implementer:
- `results='asis'` + `print(...)` on gt objects matches the existing draft/trades/FA table pattern in this file; keep the `print()` calls.
- `pmax(..., na.rm = TRUE)` never sees an all-NA row because each row exists only if at least one season had a non-NA share.
- The `##` heading (not `**bold**`) is deliberate: `toc_depth: 2` puts the section in the page TOC.

- [ ] **Step 2: Render one team page and inspect**

```bash
Rscript -e '
report_env <- new.env(parent = globalenv())
source("_common.R", local = report_env)
rmarkdown::render("nfl_sharp_team.Rmd", output_file = "KC.html",
                  output_dir = "docs/teams", envir = report_env,
                  params = list(team = "KC"), quiet = TRUE)
cat("rendered\n")
'
grep -c "Snap Counts" docs/teams/KC.html
```

Expected: `rendered`, then a count ≥ 1. Open `docs/teams/KC.html` and confirm: "Snap Counts (2022–2024)" appears in the TOC; Offense table has Patrick Mahomes near the top with high percentages; Defense table lists KC defenders; missing seasons show "—".

- [ ] **Step 3: Spot-check one value against raw data**

Run:

```bash
Rscript -e '
library(nflreadr); suppressPackageStartupMessages(library(tidyverse))
load_snap_counts(2024) |>
  filter(player == "Patrick Mahomes", game_type == "REG") |>
  summarise(share = sum(offense_snaps) / sum(offense_snaps / offense_pct)) |>
  print()
'
```

Expected: a share matching the 2024 value shown for Mahomes in `docs/teams/KC.html` (rounded to whole percent).

- [ ] **Step 4: Commit**

```bash
git add nfl_sharp_team.Rmd docs/teams/KC.html
git commit -m "feat: add 2022-2024 snap count tables to team pages"
```

---

### Task 4: Full render, docs, and CI activation

**Files:**
- Modify: `CLAUDE.md` (Architecture + Key Metrics sections)
- Modify: `README.md` (mention scheduled rendering + snap counts)
- Modify: `docs/**` (regenerated output)

**Interfaces:**
- Consumes: everything above.
- Produces: a deploy-ready `docs/` tree and an active scheduled workflow on GitHub.

- [ ] **Step 1: Full site render**

Run: `Rscript render.R`
Expected: league page + 32 team pages render without error; each `docs/teams/*.html` contains a Snap Counts section (`grep -L "Snap Counts" docs/teams/*.html` prints nothing).

- [ ] **Step 2: Update `CLAUDE.md`**

In the `_common.R` bullet of the Architecture section, extend the optional-data list: change `optional `ngs_pass`/`ngs_rush`/`ngs_rec`/`player_stats`/`ftn` via `tryCatch`` to also name `snaps`/`snap_summary` (2022–2024 snap counts). Add one sentence at the end of the "Running the Report" section:

```markdown
The site also re-renders automatically every day at 10:00 UTC via
`.github/workflows/render.yml` (manual runs: Actions → render-site → Run
workflow), which commits the refreshed `docs/` back to `master`.
```

- [ ] **Step 3: Update `README.md`**

Add a short "Automatic updates" subsection stating the same: daily 10:00 UTC render via GitHub Actions, output committed to `docs/`, manual trigger available; and mention the new per-team Snap Counts (2022–2024) section. (README has unrelated uncommitted edits — append/insert without reverting them.)

- [ ] **Step 4: Commit rendered site + docs**

```bash
git add docs/index.html docs/teams/ CLAUDE.md README.md
git commit -m "feat: deploy snap counts sections; document scheduled rendering"
```

- [ ] **Step 5: Push and trigger a CI run**

The remote is named `maaster` (sic). Push, then trigger the workflow and watch it:

```bash
git push maaster master
gh workflow run render-site --repo bullaspc/nfl_sharp_2025
gh run watch --repo bullaspc/nfl_sharp_2025 --exit-status
```

Expected: the run completes green; if the render produced no data changes it logs "No changes to deploy.", otherwise a `chore: scheduled site render …` commit appears on `master`. If GitHub Pages is configured to serve `docs/` from `master`, the site updates a few minutes later.

**Note:** if `gh` is not authenticated, ask the user to run `gh auth login` (or trigger the run from the GitHub Actions UI) rather than skipping verification.
