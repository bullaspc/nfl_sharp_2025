#!/usr/bin/env Rscript
# =============================================================================
# NFL Sharp 2025 — Setup & Render Script
# Run this file to install dependencies and render the HTML report
# =============================================================================

# ── 1. Install required packages ─────────────────────────────────────────────
cat("Checking and installing required packages...\n")

pkgs <- c(
  "nflreadr",   # nflverse data loader (primary)
  "nflfastR",   # play-by-play engine
  "tidyverse",  # data wrangling + ggplot2
  "ggrepel",    # non-overlapping labels
  "gt",         # HTML tables
  "gtExtras",   # gt add-ons (logos, color scales)
  "scales",     # axis formatting
  "glue",       # string interpolation
  "rmarkdown",  # render to HTML
  "knitr"       # knitr engine
)

# Install from nflverse r-universe first (always latest nflverse pkgs)
install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(glue::glue("  Installing {pkg}...\n"))
    install.packages(
      pkg,
      repos = c(
        "https://nflverse.r-universe.dev",
        "https://cloud.r-project.org"
      ),
      quiet = TRUE
    )
  } else {
    cat(glue::glue("  {pkg} already installed\n"))
  }
}

invisible(lapply(pkgs, install_if_missing))
cat("All packages ready.\n\n")

# ── 2. Load shared data once ─────────────────────────────────────────────────
cat("Loading shared data...\n")
cat("This will download ~2025 season play-by-play data on first run (~150MB).\n\n")

report_env <- new.env(parent = globalenv())
source("_common.R", local = report_env)

# ── 3. Render the league page + one page per team into docs/ ────────────────
dir.create("docs/teams", recursive = TRUE, showWarnings = FALSE)

cat("\nRendering league overview...\n")
rmarkdown::render(
  input       = "nfl_sharp_league.Rmd",
  output_file = "index.html",
  output_dir  = "docs",
  envir       = report_env,
  quiet       = FALSE
)

all_teams <- report_env$all_teams
cat(glue::glue("\nRendering {length(all_teams)} team pages...\n\n"))

for (i in seq_along(all_teams)) {
  tm <- all_teams[i]
  cat(glue::glue("[{i}/{length(all_teams)}] Rendering {tm}...\n"))
  rmarkdown::render(
    input       = "nfl_sharp_team.Rmd",
    output_file = paste0(tm, ".html"),
    output_dir  = "docs/teams",
    envir       = report_env,
    params      = list(team = tm),
    quiet       = TRUE
  )
}

cat(glue::glue(
  "\n✅ Report rendered: docs/index.html + {length(all_teams)} team pages under docs/teams/\n"
))
