# NFL Sharp 2025 — Analysis Report

Warren Sharp-style NFL analysis for the 2025 season (regular season + playoffs),
built with R, nflfastR, nflreadr, and Next Gen Stats.

---

## Report Sections

| Section | Metrics |
|---|---|
| **Offense Tendencies** | EPA/play, Success Rate, EDPR, Run/Pass splits by down & distance, Play-Action rate & lift |
| **Defense Tendencies** | EPA allowed, Success rate allowed, Pass vs Run defense, 3rd down stop rate |
| **QB Profiles** | CPOE, EPA/attempt, Air yards, NGS time-to-throw & aggressiveness |
| **Skill Positions** | Receiver target share, YAC, EPA/target, NGS separation; Rusher EPA/carry |
| **Team Pages** | One page per team (own colors, white background): pass rate by down & distance, draft class, trades, free agent signings, snap counts (2022–2024) |

---

## Setup & Run

```r
# From the project directory:
source("render.R")
```

This will:
1. Install all required packages (nflreadr, nflfastR, gt, gtExtras, ggrepel, etc.)
2. Download 2025 season play-by-play data from nflverse (~150MB, cached after first run)
3. Render `docs/index.html` (league overview) and `docs/teams/{TEAM}.html` for all 32 teams — `docs/` is served directly by GitHub Pages, no manual copy step needed

---

## Data Sources

| Source | Access | Used for |
|---|---|---|
| **nflfastR PBP** | Free | EPA, CPOE, success rate, all play-by-play |
| **NFL Next Gen Stats** | Free (via nflverse) | Time to throw, aggressiveness, separation |
| **FTN Charting** | Free (via nflverse) | Play-action, coverage tags |
| **nflverse teams** | Free | Logos, colors |

---

## Key Metrics Explained

- **EPA/play** — Expected Points Added per play. The gold standard efficiency metric.
- **EDPR** — Early Down Pass Rate (Warren Sharp's signature). Pass rate on 1st & 2nd down.
- **Success Rate** — % of plays with positive EPA. Measures consistency.
- **CPOE** — Completion % Over Expected. True QB accuracy adjusted for difficulty.
- **Air Yards** — Depth of target on pass plays. Proxy for QB aggressiveness.
- **YAC** — Yards After Catch. Reflects receiver ability and scheme design.

---

## Requirements

- R >= 4.1.0
- Internet connection (first run downloads data)
- ~500MB disk space for cached data

---

## Automatic Updates

The site re-renders automatically every day at **10:00 UTC** via
[`.github/workflows/render.yml`](.github/workflows/render.yml). The workflow
pulls the latest nflverse data, renders all 33 pages, and commits the refreshed
`docs/` back to `master` (logged as `chore: scheduled site render …`). Because
gt generates non-deterministic element IDs and pages embed a render timestamp,
every successful run produces a changed `docs/` and commits it; the no-change
guard in the workflow is a safety valve only, not a typical outcome.

Manual trigger: **Actions → render-site → Run workflow** in the GitHub UI, or:

```bash
gh workflow run render-site --repo bullaspc/nfl_sharp_2025
```

---

## Project Structure

```
nfl_sharp_2025/
├── _common.R               # Shared data load, palettes, theme_sharp(), league summaries
├── nfl_sharp_league.Rmd    # League overview page (light theme)
├── nfl_sharp_team.Rmd      # Per-team page template (params$team, light/team-branded theme)
├── styles_base.css         # Structural CSS shared by both page types
├── styles_dark_vars.css    # Dark color variables (unused by current pages, kept available)
├── styles_light_vars.css   # Light color variables (league + team pages)
├── render.R                # Install packages + render league page + 32 team pages
├── README.md                # This file
└── docs/                    # Generated site (GitHub Pages source)
    ├── index.html            # League overview
    └── teams/
        ├── ARI.html
        └── ...                # One file per team
```
