# Rebuild the complete local final-report analysis. No GitHub operations.
# Run from the repository root: Rscript scripts/run_final_analysis.R
if (!file.exists("analysis/02_final_analysis.Rmd")) stop("Run from the repository root.")
if (length(commandArgs(trailingOnly = TRUE))) stop("This script takes no arguments.")
ROOT <- normalizePath(".")
if (dir.exists(".r-library")) {
  local_library <- normalizePath(".r-library")
  .libPaths(c(local_library, .libPaths()))
  # Test scripts run in clean child R sessions using the same local dependencies.
  Sys.setenv(R_LIBS_USER = paste(c(local_library, Sys.getenv("R_LIBS_USER")), collapse = .Platform$path.sep))
}
required <- c("tidyverse", "scales", "knitr", "rmarkdown", "jsonlite", "rpart", "gbm", "ragg")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Run scripts/install_dependencies.R first. Missing: ", paste(missing, collapse = ", "))
if (!rmarkdown::pandoc_available()) stop("Pandoc is required; RStudio includes it.")
options(warn = 2)
sources <- file.path("data", c(
  "business-establishments-and-jobs-data-by-business-size-and-anzsic.csv",
  "business-establishments-with-address-and-industry-classification.csv"))
before <- tools::md5sum(sources)
audit_dir <- "outputs/tables/final/validation"
dir.create(audit_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(c(paste("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "In progress. Completion is recorded only after tests, rendering and checksums succeed."),
  file.path(audit_dir, "run_status.txt"))
log <- character()
for (test in c("tests/test_analysis.R", "tests/test_final_analysis.R",
               "tests/test_peer_comparison_review.R")) {
  cat("Running", test, "\n")
  result <- system2(file.path(R.home("bin"), "Rscript"), shQuote(test), stdout = TRUE, stderr = TRUE)
  status <- attr(result, "status")
  log <- c(log, paste("COMMAND:", test), result, "")
  writeLines(log, file.path(audit_dir, "test_log.txt"))
  if (!is.null(status) && status != 0L) stop("Tests failed. See ", audit_dir, "/test_log.txt")
  cat(grep("^PASS:", result, value = TRUE), "\n")
}
for (report in c("01_descriptive_analytics", "02_final_analysis",
                 "03_peer_comparison_review")) {
  for (format in c("html_document", "github_document")) {
    cat("Rendering", report, format, "\n")
    rmarkdown::render(file.path("analysis", paste0(report, ".Rmd")),
      output_format = format, envir = new.env(parent = globalenv()), quiet = TRUE)
  }
}
# Final-report figures and tables that sit outside the R Markdown reports.
# The diagnostic reads the predictive outputs written while rendering above.
for (script in c("scripts/data_insights.R", "scripts/model_diagnostic_pandemic.R",
                 "scripts/08_visual_review.R", "tests/test_visual_review.R")) {
  cat("Running", script, "\n")
  result <- system2(file.path(R.home("bin"), "Rscript"), shQuote(script), stdout = TRUE, stderr = TRUE)
  status <- attr(result, "status")
  log <- c(log, paste("COMMAND:", script), result, "")
  writeLines(log, file.path(audit_dir, "test_log.txt"))
  if (!is.null(status) && status != 0L) stop(script, " failed. See ", audit_dir, "/test_log.txt")
  cat(grep("^PASS:", result, value = TRUE), "\n")
}
if (!identical(before, tools::md5sum(sources))) stop("A raw input changed during the run.")
versions <- data.frame(package = required,
  version = vapply(required, function(x) as.character(utils::packageVersion(x)), character(1)))
readr::write_csv(versions, file.path(audit_dir, "package_versions.csv"))
readr::write_csv(data.frame(file = basename(sources), md5 = unname(before),
  bytes = unname(file.info(sources)$size)), file.path(audit_dir, "source_manifest.csv"))
writeLines(capture.output(sessionInfo()), file.path(audit_dir, "session_info.txt"))
implementation <- c(list.files("scripts", pattern = "\\.R$", full.names = TRUE),
  list.files("tests", pattern = "\\.R$", full.names = TRUE),
  list.files("analysis", pattern = "\\.Rmd$", full.names = TRUE))
readr::write_csv(data.frame(file = implementation,
  md5 = unname(tools::md5sum(implementation))), file.path(audit_dir, "implementation_manifest.csv"))
# The manifest binds reviewed result files to inputs and implementation. It is
# not a model-selection input and contains no raw address records.
tracked_results <- list.files("outputs/tables/final", pattern = "\\.(csv|json)$",
                               recursive = TRUE, full.names = TRUE)
tracked_results <- setdiff(tracked_results, file.path(audit_dir, "result_manifest.csv"))
readr::write_csv(data.frame(file = tracked_results,
  md5 = unname(tools::md5sum(tracked_results))), file.path(audit_dir, "result_manifest.csv"))
writeLines(c(paste("Completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "Tests passed; HTML and Markdown reports rendered with warnings treated as errors.",
  "Both raw CSV checksums unchanged.", "No Git commit, push or upload performed."),
  file.path(audit_dir, "run_status.txt"))
cat("Complete. Open analysis/02_final_analysis.html and analysis/03_peer_comparison_review.html for review. No GitHub upload performed.\n")
