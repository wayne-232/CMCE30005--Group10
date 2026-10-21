# Post-hoc diagnostic: why did the fitted models lose to the no-change benchmark?
#
# The 2022-24 test models were trained on every two-year window up to 2022,
# including the two pandemic windows (2018-20 and 2020-22), when the average
# group lost establishments. This script refits each family's locked
# configuration with and without those two windows and compares 2022-24 errors.
#
# This is a diagnostic only. It looks at the held-out period, so it must NOT be
# used to choose a model; the main analysis and its selection are unchanged.
# Run from the repository root after scripts/run_final_analysis.R:
#   Rscript scripts/model_diagnostic_pandemic.R

suppressPackageStartupMessages(library(dplyr))
if (!file.exists("scripts/predictive_models.R")) stop("Run from the repository root.")
source("scripts/predictive_models.R")

data_path <- "data/business-establishments-and-jobs-data-by-business-size-and-anzsic.csv"
out_dir <- "outputs/tables/final/insights"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

counts <- pred_read_counts(data_path)$counts
panel <- pred_build_panel(counts)
split <- pred_split(panel, 2022L)
configs <- readr::read_csv("outputs/tables/final/predictive/family_best_configurations.csv",
                           show_col_types = FALSE)

window_means <- split$train |>
  group_by(target_year) |>
  summarise(training_cells = n(), mean_change_per_group = mean(target_change), .groups = "drop")

score <- function(train, label) {
  bind_rows(lapply(seq_len(nrow(configs)), function(i)
    pred_fit_predict(train, split$test, configs[i, ]))) |>
    group_by(model) |>
    summarise(test_cells = n(), mae = mean(absolute_error), bias = mean(error),
              predicted_net_change = sum(predicted_change),
              actual_net_change = sum(actual_change), .groups = "drop") |>
    mutate(training_windows = label, .before = 1)
}

diagnostic <- bind_rows(
  score(split$train, "All windows to 2022 (as in main analysis)"),
  score(filter(split$train, target_year <= 2018L), "Excluding pandemic windows (2018-20, 2020-22)"))

stopifnot(abs(diagnostic$mae[diagnostic$model == "No change"][1] - 5.1256) < 1e-3)
readr::write_csv(window_means, file.path(out_dir, "training_window_mean_change.csv"))
readr::write_csv(diagnostic, file.path(out_dir, "pandemic_window_diagnostic.csv"))
print(as.data.frame(diagnostic))
cat("PASS: pandemic-window diagnostic written to", out_dir, "\n")
