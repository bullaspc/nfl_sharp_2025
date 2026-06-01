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

# ── 2. Render the report ──────────────────────────────────────────────────────
cat("Rendering NFL Sharp 2025 report...\n")
cat("This will download ~2025 season play-by-play data on first run (~150MB).\n\n")

rmarkdown::render(
  input       = "nfl_sharp_2025.Rmd",
  output_file = "output/nfl_sharp_2025.html",
  envir       = new.env(parent = globalenv()),
  quiet       = FALSE
)

cat("\n✅ Report rendered: output/nfl_sharp_2025.html\n")
