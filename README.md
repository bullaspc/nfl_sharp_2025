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
| **Team Summaries** | Per-team pass rate by down & distance with key stat header (all 32 teams) |

---

## Setup & Run

```r
# From the project directory:
source("render.R")
```

This will:
1. Install all required packages (nflreadr, nflfastR, gt, gtExtras, ggrepel, etc.)
2. Download 2025 season play-by-play data from nflverse (~150MB, cached after first run)
3. Render `output/nfl_sharp_2025.html`

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

## Project Structure

```
nfl_sharp_2025/
├── nfl_sharp_2025.Rmd   # Main analysis + report
├── styles.css           # Dark theme CSS
├── render.R             # Install packages + render
├── README.md            # This file
└── output/
    └── nfl_sharp_2025.html   # Generated report
```
