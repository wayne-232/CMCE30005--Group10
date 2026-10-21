# ============================================================
# CMCE30005 Business Analytics Challenge
# Script: scripts_00_packages.R
# Purpose: Load the packages used in the Group 10 CLUE analysis
# Author: Group 10
# Dependency installation is a separate step; report rendering never installs.
# ============================================================

# Install these packages once if they are not already available:
# Rscript scripts/install_dependencies.R
# R >= 4.1, dplyr >= 1.1.0 and Pandoc are required. RStudio includes Pandoc.

if (dir.exists(".r-library")) .libPaths(c(normalizePath(".r-library"), .libPaths()))

library(tidyverse) # Data preparation and charts
library(scales)    # Number and percentage labels
library(knitr)     # Tables in the rendered report
library(rmarkdown) # R Markdown rendering
library(jsonlite)  # Machine-readable run settings and findings
library(rpart)     # Regression tree
library(gbm)       # Gradient boosting; used alongside the no-change benchmark
