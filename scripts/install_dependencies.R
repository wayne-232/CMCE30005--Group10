# Install only missing dependencies into a project-local library.
# Run once from the repository root: Rscript scripts/install_dependencies.R
# Analysis scripts never install packages or download updated source data.
if (!file.exists("scripts/analysis_helpers.R")) stop("Run from the repository root.")
dir.create(".r-library", showWarnings = FALSE)
.libPaths(c(normalizePath(".r-library"), .libPaths()))
packages <- c("tidyverse", "scales", "knitr", "rmarkdown", "jsonlite", "rpart", "gbm")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  install.packages(missing, lib = ".r-library", repos = "https://cloud.r-project.org")
}
if (!all(vapply(packages, requireNamespace, logical(1), quietly = TRUE))) {
  stop("Some dependencies could not be installed. Review the installation messages.")
}
cat("Dependencies available. Pandoc is also needed to render reports; RStudio includes it.\n")
