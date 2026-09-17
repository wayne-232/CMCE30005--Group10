# Rebuild both reader-facing reports from the same R Markdown source.
# AI-assisted code: OpenAI Codex (2026). See docs/AI_ASSISTANCE.md.
# Run from the repository root: Rscript scripts/render_reports.R
# Optional alternative: Rscript scripts/render_reports.R --include-non-employing
# Each run replaces the main reports with the selected scope. Do not mix exports
# from different scope folders when copying results into the group submission.

args <- commandArgs(trailingOnly = TRUE)
if (any(!args %in% "--include-non-employing")) {
  stop("The only supported option is --include-non-employing.", call. = FALSE)
}
if (!file.exists("analysis/01_descriptive_analytics.Rmd")) {
  stop("Run this script from the repository root.", call. = FALSE)
}
if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  stop("Install rmarkdown first. See scripts/scripts_00_packages.R.", call. = FALSE)
}
if (!rmarkdown::pandoc_available()) stop("Pandoc is required; RStudio includes it.")
params <- list(include_non_employing = "--include-non-employing" %in% args,
               data_dir = "", export_tables = TRUE)
# Stop on warnings so they can be checked before submission.
options(warn = 2)
for (format in c("html_document", "github_document")) {
  rmarkdown::render("analysis/01_descriptive_analytics.Rmd",
                    output_format = format, params = params,
                    envir = new.env(parent = globalenv()), quiet = TRUE)
}
cat("Built HTML and GitHub Markdown. include_non_employing =",
    params$include_non_employing, "\n")
