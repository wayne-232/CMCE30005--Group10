# Independent checks for the final descriptive and predictive modules.
# Run from the repository root: Rscript tests/test_final_analysis.R
# Tests write into R's temporary directory, never into the raw-data folder.
options(warn = 2)
if (!file.exists("scripts/predictive_models.R")) stop("Run from the repository root.")
if (dir.exists(".r-library")) .libPaths(c(normalizePath(".r-library"), .libPaths()))
source("scripts/descriptive_followup.R")
source("scripts/predictive_models.R")
pred_dependencies()
checks <- 0L
check <- function(condition, label) {
  if (!isTRUE(condition)) stop(paste("FAIL:", label), call. = FALSE)
  checks <<- checks + 1L
}
close_to <- function(x, y) isTRUE(all.equal(as.numeric(x), as.numeric(y), tolerance = 1e-10))
expect_error <- function(expression, pattern, label) {
  e <- tryCatch({ force(expression); NULL }, error = identity)
  check(inherits(e, "error") && grepl(pattern, conditionMessage(e)), label)
}
input <- "data/business-establishments-and-jobs-data-by-business-size-and-anzsic.csv"
raw_hash <- tools::md5sum(input)
raw <- read.csv(input, check.names = FALSE, na.strings = c("", "NA"),
                fileEncoding = "UTF-8-BOM")
selected_raw <- raw[raw$`Business size` %in% c("Small business", "Medium business"), ]
independent_city <- tapply(selected_raw$`Total establishments`, selected_raw$`Census year`, sum)

# Descriptive arithmetic, missing cells and denominator rules.
check(close_to(followup_ratio(c(-10, 2), c(100, 0)), c(-10, NA)), "undefined zero baseline")
expect_error(followup_ratio(1, c(1, 2)), "equal lengths", "ratio inputs cannot recycle")
fixture <- data.frame(year = c(2019L, 2024L, 2024L), precinct = c("A", "A", "B"),
                      establishments = c(100, 110, 5))
compared <- followup_compare(fixture, "precinct", 2019L, 2024L)
check(compared$change[compared$precinct == "A"] == 10, "matched cell difference")
check(is.na(compared$change[compared$precinct == "B"]), "absent start remains unknown")
expect_error(followup_compare(fixture, "precinct", 2023L, 2024L), "two years", "reject annual comparison")
bench_fixture <- data.frame(precinct = c("A", "B"), industry = "X",
  start_year = 2019L, end_year = 2024L, n_start = c(100, 200),
  n_end = c(110, 240), change = c(10, 40))
industry_fixture <- data.frame(year = c(2019L, 2024L), industry = "X",
                                establishments = c(300, 350))
bench <- followup_benchmark(bench_fixture, industry_fixture)
check(close_to(bench$detail$expected_end, c(120, 220)), "own precinct excluded from reference")
check(close_to(bench$detail$observed_minus_expected, c(-10, 20)), "matched benchmark residual")
strict_bench <- followup_benchmark(bench_fixture, industry_fixture, 201)
check(all(!strict_bench$detail$eligible) &&
        all(is.na(strict_bench$summary$expected_end_total)), "empty benchmark is NA, never zero")
desc <- run_followup(input, tempfile("descriptive-tests-"), make_figures = FALSE)
check(close_to(desc$tables$city_yearly$establishments, independent_city), "independent city totals")
check(close_to(independent_city[c("2019", "2022", "2024")], c(15506, 12571, 13054)),
      "headline counts for the supplied snapshot")
check(desc$metrics$city_recent_gain == 483 && desc$metrics$city_remaining_shortfall == 2452,
      "recent increase and remaining gap")
check(desc$metrics$cbd_shortfall == 1594 && desc$metrics$hospitality_recent_gain == 214,
      "contribution headlines")
check(sum(desc$tables$industry_recent_contributions$change) == 483, "industry gains reconcile")
check(sum(desc$tables$review_priorities$recent_change) == 483, "precinct gains reconcile")
check(all(desc$tables$period_reconciliation$reconciliation_difference == 0),
      "unmatched cells bridge matched changes to published totals")
check(all(is.na(desc$tables$unmatched_cells$change)), "unmatched changes not invented")
check(is.na(desc$tables$review_priorities$gap_pct_display[
  desc$tables$review_priorities$precinct == "South Yarra"]), "small-baseline display")
check(all(desc$tables$industry_changes |>
  dplyr::group_by(start_year) |>
  dplyr::summarise(s = sum(share_of_city_net_change_pct)) |>
  dplyr::pull(s) |> round(8) == 100), "signed industry contributions reconcile")

# Reproduce the presentation's 64-group screen without letting the percentage
# display threshold silently remove small groups from a count-based rule.
review <- desc$tables$precinct_industry_review
independent_screen <- with(review, !is.na(gap_count) & !is.na(recent_change) &
  gap_count < 0 & recent_change < 0)
check(sum(independent_screen) == 64L, "64 groups meet both observed decline conditions")
check(identical(which(review$persistent_decline %in% TRUE), which(independent_screen)),
  "screen flag agrees with independent arithmetic")
check(sum(!is.na(review$persistent_decline)) == 206L &&
  sum(is.na(review$persistent_decline)) == 11L, "screen includes only complete three-year groups")
check(nrow(desc$tables$persistent_decline_groups) == 64L,
  "full screened list exports all 64 groups")
check(desc$tables$priority_screen_summary$screened_with_small_baseline == 53L,
  "small groups remain in the count screen with a warning")
cases <- desc$tables$case_studies
check(nrow(cases) == 5L && all(cases$precinct == "Melbourne (CBD)"),
  "five largest screened gaps are in the CBD")
check(close_to(cases$shortfall_count, c(450, 185, 162, 62, 45)),
  "case selection is ranked by the observed absolute gap")
check(sum(cases$shortfall_count) == 904 && sum(cases$recent_change) == -107,
  "five-case totals reconcile")
check(identical(cases, followup_case_studies(review[nrow(review):1, ])),
  "case ranking does not depend on input order")
tie_fixture <- review[rep(which(independent_screen)[1], 3), ]
tie_fixture$industry <- c("Z", "A", "M")
check(identical(followup_case_studies(tie_fixture, 2)$industry, c("A", "M")),
  "ties use deterministic alphabetical order")
expect_error(followup_case_studies(review, 0), "positive whole", "invalid case count rejected")

# Panel construction must use exact years, not the previous surviving row.
counts_fixture <- data.frame(census_year = c(2002L, 2006L, 2008L),
  precinct = "A", industry = "X", count = c(10, 15, 18))
panel_fixture <- pred_build_panel(counts_fixture)
p2006 <- panel_fixture[panel_fixture$origin_year == 2006L, ]
check(is.na(p2006$previous_count) && !p2006$eligible, "missing 2004 is not replaced by 2002")
check(p2006$target_change == 3, "target aligns with exact t+2")
expect_error(pred_build_panel(rbind(counts_fixture, counts_fixture[1, ])), "one row", "duplicate panel key")
expect_error(pred_read_counts(input, NA), "TRUE or FALSE", "scope parameter checked")

# Execute the complete models. No-change is evaluated on the SAME sample as OLS/tree/boosting.
model <- run_predictive(input, tempfile("predictive-tests-"))
test <- model$test_predictions
check(nrow(test) == 4L * 207L, "four models and 207 common evaluation cells")
check(all(table(test$model) == 207L), "same evaluation sample for all models")
check(all(test$train_last_target <= test$origin_year), "all training outcomes precede evaluation target")
check(all(test$target_year - test$origin_year == 2L), "two-year prediction horizon")
check(all(test$predicted_count >= 0), "future predicted counts cannot be negative")
check(all(test$predicted_change[test$model == "No change"] == 0), "baseline predicts zero change")
baseline <- test[test$model == "No change", ]
check(close_to(model$test_metrics$mae[model$test_metrics$model == "No change"],
               mean(abs(baseline$actual_change))), "MAE independently recalculated")
check(close_to(model$test_metrics$rmse[model$test_metrics$model == "No change"],
               sqrt(mean(baseline$actual_change^2))), "RMSE independently recalculated")
check(close_to(model$test_metrics$bias[model$test_metrics$model == "No change"],
               -mean(baseline$actual_change)), "bias sign is predicted minus actual")
check(all(test$current_count + test$actual_change == test$actual_count), "change target reconciles")
check(model$selected_configuration$config_id ==
        model$validation_leaderboard$config_id[1], "choice comes from validation, not test")
check(all(model$validation_leaderboard$validation_folds == 4), "four historical folds per setting")
check(all(model$comparison_coverage$comparison_cells <=
            model$comparison_coverage$published_origin_cells), "coverage has the correct denominator")
for (name in unique(test$model)) {
  p <- test[test$model == name, ]
  score <- model$test_metrics[model$test_metrics$model == name, ]
  check(close_to(score$mae, mean(abs(p$predicted_change - p$actual_change))),
        paste(name, "independent MAE"))
  shares <- model$error_concentration$error_share[model$error_concentration$model == name]
  check(close_to(sum(shares), 1), paste(name, "error shares sum to one"))
}

# A base-R aggregation independently reproduces the no-change comparison sample.
independent_counts <- aggregate(selected_raw$`Total establishments`,
  list(year = selected_raw$`Census year`, precinct = selected_raw$`CLUE small area`,
       industry = selected_raw$`ANZSIC indusrty`), sum)
wide <- reshape(independent_counts[independent_counts$year %in% c(2020, 2022, 2024), ],
  idvar = c("precinct", "industry"), timevar = "year", direction = "wide")
wide <- wide[complete.cases(wide), ]
check(nrow(wide) == nrow(baseline), "independent common sample")
check(close_to(mean(abs(wide$x.2024 - wide$x.2022)), mean(baseline$absolute_error)),
      "independent baseline error from source")

# Leakage test: alter every test outcome, keeping all information at origin fixed.
# All four predictions must stay identical. This also checks explicit feature selection.
original_split <- pred_split(model$panel, 2022L)
altered_panel <- model$panel
heldout_rows <- altered_panel$origin_year == 2022L
altered_panel$future_count[heldout_rows] <- altered_panel$future_count[heldout_rows] + 999
altered_panel$target_change[heldout_rows] <- altered_panel$target_change[heldout_rows] + 999
altered_split <- pred_split(altered_panel, 2022L)
check(identical(original_split$train, altered_split$train), "test outcomes do not alter training")
for (i in seq_len(nrow(model$family_best_configurations))) {
  config <- model$family_best_configurations[i, ]
  changed <- pred_fit_predict(altered_split$train, altered_split$test, config)
  original <- test[test$config_id == config$config_id, ]
  check(close_to(changed$predicted_change, original$predicted_change),
        paste(config$model, "ignores hidden test outcomes"))
}
sens <- pred_evaluate_sensitivity(input, model, tempfile("sensitivity-tests-"))
check(setequal(sens$sensitivity_fixed_configurations$config_id,
  model$family_best_configurations$config_id), "sensitivity keeps every family's settings fixed")
check(all(sens$sensitivity_predictions$train_last_target <=
  sens$sensitivity_predictions$origin_year), "sensitivity timing")
check(length(unique(sens$common_cell_scope_comparison$n)) == 1,
      "scope comparison uses identical keys")
check(identical(raw_hash, tools::md5sum(input)), "raw source checksum unchanged")
cat("PASS:", checks, "final-analysis checks; models fitted, temporal leakage tests passed.\n")
