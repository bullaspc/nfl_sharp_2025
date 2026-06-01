# Trades & Free Agents Database Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create two manually maintained CSVs (`data/trades.csv`, `data/free_agents.csv`) and render them as styled `gt` tables inside each team's section of the R Markdown report.

**Architecture:** CSV files live in `data/` and are loaded in the `setup` chunk via `tryCatch` (report renders fine if files are missing/empty). Inside the existing `for (tm in all_teams)` loop the report injects a Trades table and a Free Agents table after the draft class block, each only appearing when that team has rows.

**Tech Stack:** R, tidyverse (`read_csv`), `gt`, `gtExtras`, `nflreadr::clean_team_abbrs`, R Markdown

---

## File Map

| Action | Path | Purpose |
|---|---|---|
| Create | `data/trades.csv` | Manually maintained trades log |
| Create | `data/free_agents.csv` | Manually maintained FA signings log |
| Modify | `nfl_sharp_2025.Rmd:119` | Add CSV loading after `draft_2025` block |
| Modify | `nfl_sharp_2025.Rmd:889` | Add Trades + FA table blocks inside team loop |

---

### Task 1: Create `data/` directory and CSV skeletons

**Files:**
- Create: `data/trades.csv`
- Create: `data/free_agents.csv`

- [ ] **Step 1: Create `data/trades.csv` with header row only**

```
player,position,age,from_team,to_team,date,draft_comp,off_snap_pct,route_participation,targets,receptions,rec_yards,rec_tds,carries,rush_yards,rush_tds
```

Save this as `data/trades.csv`. No data rows yet — header only.

- [ ] **Step 2: Create `data/free_agents.csv` with header row only**

```
player,position,age,from_team,to_team,date,contract_years,contract_aav,contract_total,off_snap_pct,route_participation,targets,receptions,rec_yards,rec_tds,carries,rush_yards,rush_tds
```

Save this as `data/free_agents.csv`. Header only.

- [ ] **Step 3: Verify both files exist**

```bash
ls -la data/
head -1 data/trades.csv
head -1 data/free_agents.csv
```

Expected: both files present, each with exactly one line (the header).

- [ ] **Step 4: Commit**

```bash
git add data/trades.csv data/free_agents.csv
git commit -m "Add empty trades and free_agents CSV skeletons"
```

---

### Task 2: Load CSVs in the setup chunk

**Files:**
- Modify: `nfl_sharp_2025.Rmd:119-120` (after the `draft_2025` block, before the `# Team logos/colors` comment)

- [ ] **Step 1: Insert loading code**

Open `nfl_sharp_2025.Rmd`. After line 119 (the closing `)`  of the `draft_2025` tryCatch block) and before line 121 (`# Team logos/colors`), insert:

```r
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

```

- [ ] **Step 2: Verify the report still renders with empty CSVs**

```r
rmarkdown::render(
  "nfl_sharp_2025.Rmd",
  output_file = "nfl_sharp_2025.html",
  envir = new.env(parent = globalenv()),
  quiet = TRUE
)
```

Expected: renders without error. No trades/FA tables appear yet (files are empty).

- [ ] **Step 3: Commit**

```bash
git add nfl_sharp_2025.Rmd
git commit -m "Load trades and free_agents CSVs in setup chunk"
```

---

### Task 3: Add sample data rows for testing

**Files:**
- Modify: `data/trades.csv`
- Modify: `data/free_agents.csv`

- [ ] **Step 1: Add one test row to `data/trades.csv`**

Append this row (edit the file directly):

```
Davante Adams,WR,32,LV,NYJ,2025-03-15,2025 2nd,87,82,89,59,714,4,0,0,0
```

- [ ] **Step 2: Add one test row to `data/free_agents.csv`**

Append this row:

```
Saquon Barkley,RB,27,NYG,PHI,2025-03-12,3,11.0,33.0,72,41,0,52,1312,11,0,0
```

Note: `route_participation`, `targets`, `receptions`, `rec_yards`, `rec_tds` are 0 for this RB — not NA — so they display as 0 rather than `—`. This is intentional for testing; use NA for truly missing data.

- [ ] **Step 3: Verify CSVs load correctly in R**

```r
library(tidyverse)
library(nflreadr)
trades <- read_csv("data/trades.csv", show_col_types = FALSE) |>
  mutate(to_team = clean_team_abbrs(to_team), from_team = clean_team_abbrs(from_team))
free_agents <- read_csv("data/free_agents.csv", show_col_types = FALSE) |>
  mutate(to_team = clean_team_abbrs(to_team), from_team = clean_team_abbrs(from_team))
glimpse(trades)
glimpse(free_agents)
```

Expected: 1-row tibbles with correct column types. No errors.

---

### Task 4: Add Trades and Free Agents tables to the team loop

**Files:**
- Modify: `nfl_sharp_2025.Rmd:889` (inside the `for (tm in all_teams)` loop, after the draft class block, before `cat("\n\n")`)

- [ ] **Step 1: Insert the Trades table block**

In `nfl_sharp_2025.Rmd`, find this line (around line 889):

```r
  cat("\n\n")
}
```

Insert the following BEFORE that `cat("\n\n")` line:

```r
  # Trades table
  if (!is.null(trades)) {
    tm_trades <- trades |> filter(to_team == tm | from_team == tm)
    if (nrow(tm_trades) > 0) {
      cat("\n\n**Trades**\n\n")
      hide_receiving <- all(is.na(tm_trades$targets))
      hide_rushing   <- all(is.na(tm_trades$carries))
      tbl <- tm_trades |>
        mutate(direction = if_else(to_team == tm, "IN", "OUT")) |>
        select(direction, player, position, age, from_team, to_team,
               draft_comp, off_snap_pct, route_participation,
               targets, receptions, rec_yards, rec_tds,
               carries, rush_yards, rush_tds) |>
        gt() |>
        cols_label(
          direction          = "",
          player             = "Player",
          position           = "Pos",
          age                = "Age",
          from_team          = "From",
          to_team            = "To",
          draft_comp         = "Draft Comp",
          off_snap_pct       = "Snap%",
          route_participation = "Route%",
          targets            = "Tgt",
          receptions         = "Rec",
          rec_yards          = "RecYds",
          rec_tds            = "RecTD",
          carries            = "Car",
          rush_yards         = "RuYds",
          rush_tds           = "RuTD"
        ) |>
        cols_align(align = "center",
                   columns = c(direction, position, age, from_team, to_team,
                                off_snap_pct, route_participation,
                                targets, receptions, rec_yards, rec_tds,
                                carries, rush_yards, rush_tds)) |>
        cols_align(align = "left", columns = c(player, draft_comp)) |>
        fmt_missing(columns = everything(), missing_text = "—") |>
        gt_color_rows(off_snap_pct,
          palette = c(muted, accent),
          domain  = c(0, 100)
        ) |>
        tab_style(
          style = cell_text(color = green_c, weight = "bold"),
          locations = cells_body(columns = direction, rows = direction == "IN")
        ) |>
        tab_style(
          style = cell_text(color = red_c, weight = "bold"),
          locations = cells_body(columns = direction, rows = direction == "OUT")
        ) |>
        tab_options(
          table.background.color         = panel,
          column_labels.background.color = grid,
          row.striping.background_color  = bg,
          table.font.color               = text_c,
          table.font.size                = px(11),
          table.width                    = pct(85)
        )
      if (hide_receiving) tbl <- tbl |> cols_hide(c(route_participation, targets, receptions, rec_yards, rec_tds))
      if (hide_rushing)   tbl <- tbl |> cols_hide(c(carries, rush_yards, rush_tds))
      print(tbl)
    }
  }

  # Free Agents table
  if (!is.null(free_agents)) {
    tm_fa <- free_agents |> filter(to_team == tm)
    if (nrow(tm_fa) > 0) {
      cat("\n\n**Free Agent Signings**\n\n")
      hide_receiving <- all(is.na(tm_fa$targets))
      hide_rushing   <- all(is.na(tm_fa$carries))
      tbl <- tm_fa |>
        select(player, position, age, from_team,
               contract_years, contract_aav, contract_total,
               off_snap_pct, route_participation,
               targets, receptions, rec_yards, rec_tds,
               carries, rush_yards, rush_tds) |>
        gt() |>
        cols_label(
          player              = "Player",
          position            = "Pos",
          age                 = "Age",
          from_team           = "From",
          contract_years      = "Yrs",
          contract_aav        = "AAV ($M)",
          contract_total      = "Total ($M)",
          off_snap_pct        = "Snap%",
          route_participation = "Route%",
          targets             = "Tgt",
          receptions          = "Rec",
          rec_yards           = "RecYds",
          rec_tds             = "RecTD",
          carries             = "Car",
          rush_yards          = "RuYds",
          rush_tds            = "RuTD"
        ) |>
        cols_align(align = "center",
                   columns = c(position, age, from_team, contract_years,
                                contract_aav, contract_total, off_snap_pct,
                                route_participation, targets, receptions,
                                rec_yards, rec_tds, carries, rush_yards, rush_tds)) |>
        cols_align(align = "left", columns = player) |>
        fmt_missing(columns = everything(), missing_text = "—") |>
        fmt_currency(columns = c(contract_aav, contract_total),
                     currency = "USD", decimals = 1, suffixing = FALSE) |>
        gt_color_rows(off_snap_pct,
          palette = c(muted, accent),
          domain  = c(0, 100)
        ) |>
        tab_options(
          table.background.color         = panel,
          column_labels.background.color = grid,
          row.striping.background_color  = bg,
          table.font.color               = text_c,
          table.font.size                = px(11),
          table.width                    = pct(85)
        )
      if (hide_receiving) tbl <- tbl |> cols_hide(c(route_participation, targets, receptions, rec_yards, rec_tds))
      if (hide_rushing)   tbl <- tbl |> cols_hide(c(carries, rush_yards, rush_tds))
      print(tbl)
    }
  }
```

- [ ] **Step 2: Render the report**

```r
rmarkdown::render(
  "nfl_sharp_2025.Rmd",
  output_file = "nfl_sharp_2025.html",
  envir = new.env(parent = globalenv()),
  quiet = TRUE
)
```

Expected: renders without error.

- [ ] **Step 3: Visually verify tables appear**

Open `nfl_sharp_2025.html` in a browser. Navigate to the NYJ section — confirm a **Trades** table appears with Adams (direction IN, green). Navigate to the PHI section — confirm a **Free Agent Signings** table appears with Barkley.

- [ ] **Step 4: Commit**

```bash
git add nfl_sharp_2025.Rmd
git commit -m "Add Trades and Free Agent Signings tables to team sections"
```

---

### Task 5: Remove test data, final render, and deploy

**Files:**
- Modify: `data/trades.csv` (remove test row)
- Modify: `data/free_agents.csv` (remove test row)
- Modify: `nfl_sharp_2025.html` (re-render)
- Modify: `docs/index.html` (deploy)

- [ ] **Step 1: Remove the test data rows**

Edit `data/trades.csv` back to header-only:

```
player,position,age,from_team,to_team,date,draft_comp,off_snap_pct,route_participation,targets,receptions,rec_yards,rec_tds,carries,rush_yards,rush_tds
```

Edit `data/free_agents.csv` back to header-only:

```
player,position,age,from_team,to_team,date,contract_years,contract_aav,contract_total,off_snap_pct,route_participation,targets,receptions,rec_yards,rec_tds,carries,rush_yards,rush_tds
```

- [ ] **Step 2: Final render**

```r
rmarkdown::render(
  "nfl_sharp_2025.Rmd",
  output_file = "nfl_sharp_2025.html",
  envir = new.env(parent = globalenv()),
  quiet = TRUE
)
```

Expected: renders without error. No Trades or FA tables appear (empty CSVs).

- [ ] **Step 3: Copy to docs/ for GitHub Pages**

```bash
cp nfl_sharp_2025.html docs/index.html
```

- [ ] **Step 4: Commit and push**

```bash
git add data/trades.csv data/free_agents.csv nfl_sharp_2025.html docs/index.html
git commit -m "Deploy trades/FA table feature with empty CSV stubs"
git push sharp_2025 master
```
