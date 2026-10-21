# Rebuilt predictive analysis for the Group 10 final report.
# This is a new, reproducible implementation. It does not reproduce or inherit
# the unpublished model results quoted in the earlier presentation.
#
# Question: can a model predict a precinct-industry group's two-year change in
# SME establishments more accurately than assuming its count stays unchanged?
# Run from the repository root:
#   Rscript scripts/predictive_models.R
# Source this file to use its functions without running the analysis.

pred_assert <- function(condition, message) {
  if (!isTRUE(condition)) stop(message, call. = FALSE)
}

pred_dependencies <- function() {
  # A local library can be used without changing a team member's system library.
  if (dir.exists(".r-library")) .libPaths(c(normalizePath(".r-library"), .libPaths()))
  packages <- c("dplyr", "tidyr", "readr", "rpart", "gbm", "jsonlite")
  absent <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  pred_assert(length(absent) == 0,
              paste("Install these packages before running:", paste(absent, collapse = ", ")))
}

pred_read_counts <- function(data_path, include_non_employing = FALSE) {
  pred_assert(is.logical(include_non_employing) && length(include_non_employing) == 1L &&
                !is.na(include_non_employing), "include_non_employing must be TRUE or FALSE.")
  source <- readr::read_csv(data_path, show_col_types = FALSE, progress = FALSE,
    col_types = readr::cols(.default = readr::col_character(),
      `Census year` = readr::col_integer(), `Total establishments` = readr::col_double(),
      `Total jobs` = readr::col_double()))
  pred_assert(nrow(readr::problems(source)) == 0L, "The aggregate CSV contains parsing problems.")
  required <- c("Census year", "CLUE small area", "ANZSIC indusrty", "Business size",
                "Total establishments", "Total jobs")
  pred_assert(all(required %in% names(source)), "The aggregate CSV has unexpected columns.")
  names(source)[match(required, names(source))] <-
    c("census_year", "precinct", "industry", "business_size", "establishments", "jobs")
  keys <- source[c("census_year", "precinct", "industry", "business_size")]
  pred_assert(!anyNA(keys) && !anyDuplicated(keys), "Source grouping keys are missing or duplicated.")
  pred_assert(all(source$business_size %in% c("Small business", "Medium business",
                "Large business", "Non employing")), "An unfamiliar business-size category needs review.")
  pred_assert(all(is.finite(source$establishments) & source$establishments >= 0 &
                    source$establishments == floor(source$establishments)),
              "Establishment counts must be complete, non-negative whole numbers.")
  categories <- c("Small business", "Medium business")
  if (include_non_employing) categories <- c(categories, "Non employing")
  selected <- source |>
    dplyr::filter(business_size %in% categories, census_year >= 2002L, census_year <= 2024L)
  # Sum the published rows in the selected size categories. An omitted size row
  # is not independently classified as zero. Record component coverage so that
  # this aggregation choice remains visible to the reviewer.
  counts <- selected |>
    dplyr::group_by(census_year, precinct, industry) |>
    dplyr::summarise(count = sum(establishments),
                     published_size_rows = dplyr::n(),
                     size_components = paste(sort(business_size), collapse = "; "),
                     .groups = "drop") |>
    dplyr::arrange(census_year, precinct, industry)
  list(counts = counts, source_rows = nrow(source), selected_rows = nrow(selected),
       missing_jobs_retained = sum(is.na(selected$jobs)), categories = categories)
}

pred_build_panel <- function(counts) {
  required <- c("census_year", "precinct", "industry", "count")
  pred_assert(all(required %in% names(counts)), "Counts lack required columns.")
  pred_assert(!anyDuplicated(counts[c("census_year", "precinct", "industry")]),
              "Counts must have one row per year, precinct and industry.")
  pred_assert(!anyNA(counts[required]) &&
                all(is.finite(counts$count) & counts$count >= 0), "Invalid grouped counts.")
  even <- counts |>
    dplyr::filter(census_year %% 2L == 0L) |>
    dplyr::select(dplyr::all_of(required))
  # The complete grid is an audit frame only. Missing cells remain NA throughout.
  # Exact year keys avoid treating an older observation as a two-year lag.
  panel <- tidyr::expand_grid(
    origin_year = seq(min(even$census_year), max(even$census_year) - 2L, by = 2L),
    precinct = sort(unique(even$precinct)), industry = sort(unique(even$industry))) |>
    dplyr::left_join(dplyr::rename(even, origin_year = census_year, current_count = count),
                     by = c("origin_year", "precinct", "industry")) |>
    dplyr::left_join(even |>
                       dplyr::transmute(origin_year = census_year + 2L,
                                        precinct, industry, previous_count = count),
                     by = c("origin_year", "precinct", "industry")) |>
    dplyr::left_join(even |>
                       dplyr::transmute(origin_year = census_year - 2L,
                                        precinct, industry, future_count = count),
                     by = c("origin_year", "precinct", "industry")) |>
    dplyr::mutate(
      target_year = origin_year + 2L,
      previous_year = origin_year - 2L,
      log_current_count = log1p(current_count),
      previous_change = current_count - previous_count,
      target_change = future_count - current_count,
      # These flags overlap; the explanation below uses a mutually exclusive order.
      missing_origin = is.na(current_count),
      missing_previous = is.na(previous_count),
      missing_target = is.na(future_count),
      eligible = !missing_origin & !missing_previous & !missing_target,
      exclusion_reason = dplyr::case_when(
        missing_origin ~ "No published origin-year cell",
        missing_previous ~ "No published exact two-year lag",
        missing_target ~ "No published target-year cell",
        TRUE ~ "Included"))
  panel
}

pred_grid <- function() {
  dplyr::bind_rows(
    data.frame(model = "No change", config_id = "no_change", cp = NA_real_,
               minbucket = NA_integer_, depth = NA_integer_, trees = NA_integer_,
               shrinkage = NA_real_),
    data.frame(model = "OLS", config_id = "ols", cp = NA_real_,
               minbucket = NA_integer_, depth = NA_integer_, trees = NA_integer_,
               shrinkage = NA_real_),
    tidyr::expand_grid(cp = c(0.001, 0.01, 0.05), minbucket = c(5L, 10L)) |>
      dplyr::mutate(model = "Pruned tree",
                     config_id = paste0("tree_cp", cp, "_bucket", minbucket),
                     depth = NA_integer_, trees = NA_integer_, shrinkage = NA_real_),
    tidyr::expand_grid(depth = c(1L, 2L), trees = c(100L, 300L)) |>
      dplyr::mutate(model = "Gradient boosting",
                     config_id = paste0("gbm_depth", depth, "_trees", trees),
                     cp = NA_real_, minbucket = NA_integer_, shrinkage = 0.03)) |>
    dplyr::mutate(complexity_order = dplyr::row_number())
}

pred_split <- function(panel, origin_year) {
  train <- panel |>
    dplyr::filter(eligible, .data$target_year <= .env$origin_year)
  candidates <- panel |>
    dplyr::filter(.data$origin_year == .env$origin_year)
  # All models use the same evaluation rows. Unseen categories cannot be assigned
  # an OLS coefficient, so exclude them consistently and report the exclusion.
  candidates <- candidates |>
    dplyr::mutate(
      known_precinct = precinct %in% train$precinct,
      known_industry = industry %in% train$industry,
      comparison_eligible = eligible & known_precinct & known_industry,
      exclusion_reason = dplyr::case_when(
        !eligible ~ exclusion_reason,
        !known_precinct ~ "Precinct not represented in training",
        !known_industry ~ "Industry not represented in training",
        TRUE ~ "Included"))
  test <- dplyr::filter(candidates, comparison_eligible)
  pred_assert(nrow(train) > 0 && nrow(test) > 0, "The time split has no training or test rows.")
  pred_assert(max(train$target_year) <= origin_year &&
                all(test$origin_year == origin_year) &&
                all(test$target_year == origin_year + 2L), "A time split leaked future outcomes.")
  list(train = train, test = test, candidates = candidates)
}

pred_fit_predict <- function(train, test, config, seed = 20261020L) {
  features <- c("current_count", "log_current_count", "previous_change", "precinct", "industry")
  # Select columns explicitly: future_count, target_year and current test outcomes
  # can never enter a model matrix by accident.
  training <- as.data.frame(train[c(features, "target_change")])
  testing <- as.data.frame(test[features])
  for (variable in c("precinct", "industry")) {
    levels <- sort(unique(training[[variable]]))
    training[[variable]] <- factor(training[[variable]], levels = levels)
    testing[[variable]] <- factor(testing[[variable]], levels = levels)
  }
  pred_assert(!anyNA(training) && !anyNA(testing), "A model input is missing or has an unseen category.")
  formula <- target_change ~ current_count + log_current_count + previous_change + precinct + industry
  model <- config$model[[1]]
  set.seed(seed)
  if (model == "No change") {
    raw_prediction <- rep(0, nrow(test))
    model_detail <- "Predicts a two-year count change of zero; no fitted coefficients."
  } else if (model == "OLS") {
    fit <- stats::lm(formula, data = training)
    raw_prediction <- as.numeric(stats::predict(fit, newdata = testing))
    model_detail <- paste("OLS coefficients:", fit$rank)
  } else if (model == "Pruned tree") {
    full_tree <- rpart::rpart(formula, data = training, method = "anova",
                              control = rpart::rpart.control(
                                cp = 0, minbucket = config$minbucket[[1]],
                                minsplit = 2L * config$minbucket[[1]],
                                maxdepth = 10L, xval = 0L))
    fit <- rpart::prune(full_tree, cp = config$cp[[1]])
    raw_prediction <- as.numeric(stats::predict(fit, newdata = testing))
    model_detail <- paste("Terminal nodes:", sum(fit$frame$var == "<leaf>"))
  } else if (model == "Gradient boosting") {
    fit <- gbm::gbm(formula, data = training, distribution = "gaussian",
                    n.trees = config$trees[[1]], interaction.depth = config$depth[[1]],
                    shrinkage = config$shrinkage[[1]], n.minobsinnode = 10L,
                    # Full-sample boosting removes random subsampling variation.
                    bag.fraction = 1, train.fraction = 1, cv.folds = 0,
                    keep.data = FALSE, verbose = FALSE)
    raw_prediction <- as.numeric(stats::predict(fit, newdata = testing,
                                                n.trees = config$trees[[1]], type = "response"))
    model_detail <- paste(config$trees[[1]], "trees; interaction depth", config$depth[[1]])
  } else stop("Unknown model family: ", model, call. = FALSE)
  pred_assert(length(raw_prediction) == nrow(test) && all(is.finite(raw_prediction)),
              "The model returned an invalid prediction.")
  # A forecast cannot remove more establishments than are present. Apply the
  # same non-negative-count constraint to every model, without rounding counts.
  prediction <- pmax(raw_prediction, -test$current_count)
  dplyr::transmute(test,
    precinct, industry, origin_year, target_year, current_count, previous_count,
    previous_change, actual_change = target_change, actual_count = future_count,
    model = model, config_id = config$config_id[[1]],
    raw_predicted_change = raw_prediction, predicted_change = prediction,
    predicted_count = current_count + prediction,
    clipped = prediction != raw_prediction,
    error = prediction - target_change, absolute_error = abs(error), squared_error = error^2,
    train_first_origin = min(train$origin_year), train_last_origin = max(train$origin_year),
    train_last_target = max(train$target_year), training_rows = nrow(train),
    model_detail = model_detail)
}

pred_metrics <- function(predictions, grouping = c("stage", "model", "config_id", "origin_year", "target_year")) {
  predictions |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grouping))) |>
    dplyr::summarise(n = dplyr::n(), mae = mean(absolute_error),
                     rmse = sqrt(mean(squared_error)), bias = mean(error),
                     median_absolute_error = stats::median(absolute_error),
                     actual_total_change = sum(actual_change),
                     predicted_total_change = sum(predicted_change),
                     clipped_predictions = sum(clipped), .groups = "drop")
}

pred_coverage <- function(split, stage) {
  candidates <- split$candidates
  dplyr::summarise(candidates,
    stage = stage, origin_year = min(origin_year), target_year = min(target_year),
    possible_precinct_industry_cells = dplyr::n(),
    published_origin_cells = sum(!is.na(current_count)),
    matched_origin_target_cells = sum(!is.na(current_count) & !is.na(future_count)),
    comparison_cells = sum(comparison_eligible),
    share_of_published_origin_cells = comparison_cells / published_origin_cells,
    origin_establishments_in_published_cells = sum(current_count, na.rm = TRUE),
    origin_establishments_in_comparison = sum(current_count[comparison_eligible]),
    share_of_origin_establishments = origin_establishments_in_comparison /
      origin_establishments_in_published_cells,
    target_establishments_in_published_cells = sum(future_count, na.rm = TRUE),
    target_establishments_in_comparison = sum(future_count[comparison_eligible]),
    share_of_target_establishments = target_establishments_in_comparison /
      target_establishments_in_published_cells)
}

pred_baseline_comparison <- function(predictions) {
  baseline <- predictions |>
    dplyr::filter(model == "No change") |>
    dplyr::select(stage, origin_year, target_year, precinct, industry,
                   baseline_absolute_error = absolute_error)
  pred_assert(!anyDuplicated(baseline[c("stage", "origin_year", "precinct", "industry")]),
              "Baseline predictions are duplicated.")
  predictions |>
    dplyr::left_join(baseline,
                     by = c("stage", "origin_year", "target_year", "precinct", "industry")) |>
    dplyr::group_by(stage, model, config_id, origin_year, target_year) |>
    dplyr::summarise(n = dplyr::n(), mae = mean(absolute_error),
                     baseline_mae = mean(baseline_absolute_error),
                     mae_difference_from_baseline = mae - baseline_mae,
                     skill_vs_no_change = ifelse(baseline_mae > 0, 1 - mae / baseline_mae, NA_real_),
                     cells_better = sum(absolute_error < baseline_absolute_error - 1e-9),
                     cells_tied = sum(abs(absolute_error - baseline_absolute_error) <= 1e-9),
                     cells_worse = sum(absolute_error > baseline_absolute_error + 1e-9),
                     .groups = "drop")
}

pred_diagnostics <- function(predictions) {
  banded <- predictions |>
    dplyr::mutate(origin_size_band = cut(current_count, breaks = c(-Inf, 19, 99, Inf),
                                       labels = c("0-19", "20-99", "100+")))
  subgroup <- dplyr::bind_rows(lapply(c("precinct", "industry", "origin_size_band"), function(variable) {
    x <- banded
    x$group <- as.character(x[[variable]])
    pred_metrics(x, c("stage", "model", "config_id", "group")) |>
      dplyr::mutate(grouping = variable, .before = group)
  }))
  concentration <- predictions |>
    dplyr::group_by(stage, model, config_id) |>
    dplyr::arrange(dplyr::desc(absolute_error), .by_group = TRUE) |>
    dplyr::mutate(error_rank = dplyr::row_number(),
                    error_share = if (sum(absolute_error) > 0)
                      absolute_error / sum(absolute_error) else rep(0, dplyr::n()),
                    cumulative_error_share = cumsum(error_share)) |>
    dplyr::ungroup()
  concentration_summary <- concentration |>
    dplyr::group_by(stage, model, config_id) |>
    dplyr::summarise(n = dplyr::n(),
                     top_10_cells_error_share = sum(error_share[error_rank <= 10L]),
                     top_10_percent_cells_error_share = sum(error_share[error_rank <= ceiling(n * 0.1)]),
                     origin_count_under_20_share = mean(current_count < 20),
                     actual_change_within_5_share = mean(abs(actual_change) <= 5),
                     actual_zero_change_share = mean(actual_change == 0), .groups = "drop")
  list(subgroups = subgroup, error_concentration = concentration,
       error_concentration_summary = concentration_summary)
}

run_predictive <- function(data_path, output_dir, include_non_employing = FALSE,
                           validation_origins = c(2014L, 2016L, 2018L, 2020L),
                           heldout_origin = 2022L) {
  pred_dependencies()
  pred_assert(length(heldout_origin) == 1L && length(validation_origins) > 0L &&
                all(validation_origins %% 2L == 0L) && heldout_origin %% 2L == 0L &&
                all(validation_origins + 2L <= heldout_origin) &&
                !anyDuplicated(validation_origins), "Invalid validation/test timeline.")
  input_checksum <- unname(tools::md5sum(data_path))
  data <- pred_read_counts(data_path, include_non_employing)
  panel <- pred_build_panel(data$counts)
  configs <- pred_grid()
  folds <- lapply(validation_origins, function(year) pred_split(panel, year))
  validation <- dplyr::bind_rows(lapply(seq_along(folds), function(fold) {
    dplyr::bind_rows(lapply(seq_len(nrow(configs)), function(i) {
      pred_fit_predict(folds[[fold]]$train, folds[[fold]]$test, configs[i, ])
    }))
  })) |>
    dplyr::mutate(stage = "Rolling validation", .before = 1)
  validation_metrics <- pred_metrics(validation)
  # Each historical period receives equal weight, so a period with a few more
  # published cells does not silently dominate the model choice.
  leaderboard <- validation_metrics |>
    dplyr::group_by(model, config_id) |>
    dplyr::summarise(validation_mean_fold_mae = mean(mae),
                     validation_mean_fold_rmse = mean(rmse),
                     validation_mean_fold_bias = mean(bias), validation_folds = dplyr::n(),
                     .groups = "drop") |>
    dplyr::left_join(configs, by = c("model", "config_id")) |>
    dplyr::arrange(validation_mean_fold_mae, complexity_order)
  # Select one configuration per family and one overall winner before looking
  # at 2022-24 outcomes. Exact MAE ties go to the earlier, simpler configuration.
  family_best <- leaderboard |>
    dplyr::group_by(model) |>
    dplyr::slice_head(n = 1L) |>
    dplyr::ungroup()
  selected <- dplyr::slice_head(leaderboard, n = 1L)
  test_split <- pred_split(panel, heldout_origin)
  test_predictions <- dplyr::bind_rows(lapply(seq_len(nrow(family_best)), function(i) {
    pred_fit_predict(test_split$train, test_split$test, family_best[i, ])
  })) |>
    dplyr::mutate(stage = "Held-out test", .before = 1)
  test_metrics <- pred_metrics(test_predictions) |>
    dplyr::mutate(selected_before_test = config_id == selected$config_id[[1]]) |>
    dplyr::arrange(mae)
  chosen_validation <- dplyr::filter(validation, config_id %in% family_best$config_id)
  comparison_predictions <- dplyr::bind_rows(chosen_validation, test_predictions)
  baseline_comparison <- pred_baseline_comparison(comparison_predictions)
  coverage <- dplyr::bind_rows(
    lapply(folds, pred_coverage, stage = "Rolling validation"),
    list(pred_coverage(test_split, "Held-out test")))
  exclusions <- dplyr::bind_rows(
    lapply(folds, function(x) dplyr::mutate(x$candidates, stage = "Rolling validation")),
    list(dplyr::mutate(test_split$candidates, stage = "Held-out test"))) |>
    dplyr::select(stage, origin_year, target_year, precinct, industry, current_count,
                   previous_count, future_count, missing_origin, missing_previous,
                   missing_target, known_precinct, known_industry, comparison_eligible,
                   exclusion_reason)
  diagnostics <- pred_diagnostics(test_predictions)
  # The baseline can also be scored without a lag feature. Show this broader
  # population separately so its extra cells cannot change the fair model comparison.
  broad_baseline <- panel |>
    dplyr::filter(origin_year == heldout_origin, !missing_origin, !missing_target) |>
    dplyr::summarise(origin_year = heldout_origin, target_year = heldout_origin + 2L,
      matched_cells = dplyr::n(), mae = mean(abs(target_change)),
      rmse = sqrt(mean(target_change^2)), actual_total_change = sum(target_change))
  metadata <- list(
    analysis_status = "Rebuilt implementation; previous presentation results are not reproduced claims",
    scope = if (include_non_employing) "Small + Medium + Non employing" else "Small + Medium (1-199 jobs)",
    source_file = basename(data_path), source_md5 = input_checksum,
    source_rows = data$source_rows, selected_source_rows = data$selected_rows,
    rows_with_missing_jobs_retained = data$missing_jobs_retained,
    target = "Published SME count at t+2 minus published SME count at t, by precinct and industry",
    time_sampling = "Even years; exact t-2, t and t+2 joins. No annual entry/exit estimates.",
    missing_cells = "Absent precinct-industry-year cells remain NA and are excluded from matched comparisons.",
    size_components = "Counts sum available source rows in the selected business-size categories; component coverage is exported.",
    validation_origins = validation_origins, heldout_origin = heldout_origin,
    selection_rule = "Lowest unweighted mean of historical fold MAEs; exact ties favour simpler configuration.",
    selected_model = selected$model[[1]], selected_config_id = selected$config_id[[1]],
    selected_validation_mae = selected$validation_mean_fold_mae[[1]],
    selected_test_mae = test_metrics$mae[test_metrics$selected_before_test],
    lowest_test_mae_model = test_metrics$model[[1]],
    test_interpretation = "Test results evaluate a locked historical choice; the lowest test MAE does not retune that choice.",
    error_units = "Establishments per precinct-industry cell; all cells have equal weight. Bias = predicted minus actual.",
    limitations = c("Retrospective backtest on one supplied data vintage; historical release revisions are unavailable.",
                    "A repeated precinct-industry panel is not a collection of independent businesses.",
                    "No-change does not predict individual survival, gross entries/exits or COVID effects.",
                    "The historical evaluation period was already discussed in the presentation; this is a retrospective reconstruction, not a new prospective test.",
                    "One held-out two-year period is not proof of reliable performance in all future periods.",
                    "No confidence intervals or statistical significance claims are implied by MAE rankings."))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  tables <- c(list(model_grid = configs, published_counts = data$counts,
                    panel_audit = panel, validation_predictions = validation,
                    validation_metrics = validation_metrics, validation_leaderboard = leaderboard,
                    family_best_configurations = family_best, selected_configuration = selected,
                    test_predictions = test_predictions, test_metrics = test_metrics,
                    baseline_comparison = baseline_comparison, comparison_coverage = coverage,
                    comparison_exclusions = exclusions,
                    no_change_all_matched_pairs = broad_baseline), diagnostics)
  for (name in names(tables)) readr::write_csv(tables[[name]], file.path(output_dir, paste0(name, ".csv")))
  jsonlite::write_json(metadata, file.path(output_dir, "metadata.json"), pretty = TRUE,
                       auto_unbox = TRUE, na = "null", digits = NA)
  writeLines(capture.output(utils::sessionInfo()), file.path(output_dir, "session_info.txt"))
  pred_assert(identical(input_checksum, unname(tools::md5sum(data_path))), "The source file changed while running.")
  invisible(c(tables, list(metadata = metadata, panel = panel)))
}

pred_evaluate_sensitivity <- function(data_path, main_result, output_dir) {
  # Add Non employing only as a scope check. Keep each family's main-analysis
  # configuration fixed; never choose a new setting using held-out outcomes.
  pred_dependencies()
  data <- pred_read_counts(data_path, include_non_employing = TRUE)
  panel <- pred_build_panel(data$counts)
  split <- pred_split(panel, main_result$metadata$heldout_origin)
  configs <- main_result$family_best_configurations
  predictions <- dplyr::bind_rows(lapply(seq_len(nrow(configs)), function(i)
    pred_fit_predict(split$train, split$test, configs[i, ]))) |>
    dplyr::mutate(stage = "Non-employing sensitivity", .before = 1)
  # A second table restricts both definitions to identical precinct-industry keys.
  common_keys <- main_result$test_predictions |>
    dplyr::distinct(origin_year, precinct, industry)
  common_predictions <- dplyr::semi_join(predictions, common_keys,
                                         by = c("origin_year", "precinct", "industry"))
  main_common <- dplyr::semi_join(main_result$test_predictions,
                                  dplyr::distinct(common_predictions, origin_year, precinct, industry),
                                  by = c("origin_year", "precinct", "industry")) |>
    dplyr::filter(config_id %in% configs$config_id)
  tables <- list(sensitivity_predictions = predictions,
                 sensitivity_metrics = pred_metrics(predictions),
                 common_cell_scope_comparison = dplyr::bind_rows(
                   pred_metrics(main_common), pred_metrics(common_predictions)),
                 sensitivity_coverage = pred_coverage(split, "Non-employing sensitivity"),
                 sensitivity_fixed_configurations = configs)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  for (name in names(tables)) readr::write_csv(tables[[name]], file.path(output_dir, paste0(name, ".csv")))
  invisible(tables)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 2L) stop("Usage: Rscript predictive_models.R [source.csv] [output-folder]")
  source_path <- if (length(args) >= 1L) args[[1]] else
    "data/business-establishments-and-jobs-data-by-business-size-and-anzsic.csv"
  destination <- if (length(args) >= 2L) args[[2]] else "outputs/tables/final/predictive"
  result <- run_predictive(source_path, destination)
  print(result$test_metrics)
  cat("Selected before test:", result$metadata$selected_model, "\nSaved to:", destination, "\n")
}
