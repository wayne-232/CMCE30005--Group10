# Run from the repository root: Rscript tests/test_analysis.R
# No testthat dependency. Test calculations, failure cases and both SME scopes.
# The integration checks independently sum the raw file using base R.

options(warn = 2)
if (!file.exists("scripts/analysis_helpers.R")) stop("Run from the repository root.")
suppressPackageStartupMessages(library(tidyverse))
source("scripts/analysis_helpers.R")
checks <- 0L
check <- function(condition, label) {
  if (!isTRUE(condition)) stop(paste("FAIL:", label), call. = FALSE)
  checks <<- checks + 1L
}
expect_error <- function(expression, pattern, label) {
  error <- tryCatch({ force(expression); NULL }, error = identity)
  check(inherits(error, "error") && grepl(pattern, conditionMessage(error)), label)
}

# Missing and zero are different; a zero denominator has no defined change.
check(identical(pct_change(c(110, 0, 10, NA, 0), c(100, 10, 0, 10, 0)),
                c(10, -100, NA_real_, NA_real_, NA_real_)), "percentage denominators")
expect_error(pct_change(1, c(1, 2)), "equal length", "input lengths checked")
audit <- missing_audit(data.frame(a = c(NA, 0), b = c("", "x")), "fixture")
check(identical(unname(audit$missing_count), c(1L, 0L)), "missing counts")
check(identical(unname(audit$blank_string_count), c(0L, 1L)), "blanks separately counted")
check(identical(unname(audit$missing_percent), c(50, 0)), "missing denominator")

duplicates <- tibble(census_year = c(2024L, 2024L), total_establishments = c(1, 2))
expect_error(check_key(duplicates, "census_year", "Fixture"), "duplicate",
             "non-identical rows can still have duplicate keys")
expect_error(check_key(tibble(census_year = NA), "census_year", "Fixture"),
             "missing", "missing keys rejected")
for (bad in list(NA_real_, -1, 1.5, Inf)) {
  expect_error(sum_establishments(tibble(census_year = 2024L, total_establishments = bad)),
               "counts", "invalid establishment count rejected")
}
fixture_locations <- tibble(
  industry_anzsic4_code = c(0L, 111L, NA_integer_, 0L, 9900L, 100L),
  industry_anzsic4_description = c("Vacant Space", "Agriculture", "Vacant Space",
                                  "Other", "Common area", ""))
check(identical(classify_locations(fixture_locations)$record_type,
                c("Vacant Space", "Industry-coded establishment", rep("Needs review", 4))),
      "vacancy requires explicit classification, not just missing information")

counts <- tibble(census_year = rep(c(2019L, 2022L, 2024L), 4),
                 area = rep(c("A", "B", "C", "D"), each = 3),
                 establishments = c(100, 80, 90, 99, 100, 110, 0, 0, 10, 200, 190, 195))
# Remove D's 2022 row: an absent source combination must stay unknown.
counts <- filter(counts, !(area == "D" & census_year == 2022L))
comparison <- compare_years(counts, "area")
check(comparison$gap_pct[comparison$area == "A"] == -10, "2019 baseline")
check(comparison$recovery_pct[comparison$area == "A"] == 12.5, "2022 baseline")
check(comparison$recovery_status[comparison$area == "A"] ==
        "Below 2019; increasing since 2022", "partial recovery recognised")
check(is.na(comparison$gap_pct_display[comparison$area == "B"]) &&
        !is.na(comparison$recovery_pct_display[comparison$area == "B"]),
      "display threshold applied to each denominator")
check(is.na(comparison$gap_pct[comparison$area == "C"]), "zero base not infinite")
check(is.na(comparison$n_recovery_start[comparison$area == "D"]) &&
        is.na(comparison$recovery_count[comparison$area == "D"]), "absent cells not zero-filled")
check(comparison$recovery_status[comparison$area == "D"] == "Not comparable",
      "incomplete comparisons identified")
expect_error(compare_years(counts, "area", c(2019, 2020, 2024)), "two years",
             "annual comparisons rejected")
expect_error(compare_years(counts, "area", min_base = 0), "threshold", "invalid threshold")
expect_error(compare_years(bind_rows(counts, counts[1, ]), "area"), "duplicate",
             "duplicate comparisons rejected")
expect_error(compare_years(filter(counts, census_year != 2024L), "area"),
             "year is missing", "absent comparison year rejected")
shifted <- mutate(counts, census_year = census_year - 10L)
check(grepl("2009", compare_years(shifted, "area", c(2009, 2012, 2014))$recovery_status[1]),
      "status labels follow selected years")

# Execute every report chunk under both definitions in isolated environments.
# Use a temporary graphics device so the tests do not create Rplots.pdf.
input_paths <- file.path("data", c(
  "business-establishments-and-jobs-data-by-business-size-and-anzsic.csv",
  "business-establishments-with-address-and-industry-classification.csv"))
check(all(file.exists(input_paths)), "both source files available")
before <- tools::md5sum(input_paths)
raw <- read.csv(input_paths[1], check.names = FALSE, na.strings = c("", "NA"))
script_path <- tempfile(fileext = ".R")
invisible(knitr::purl("analysis/01_descriptive_analytics.Rmd", script_path,
                      documentation = 0, quiet = TRUE))
# purl writes YAML defaults as its first expression. Remove ONLY that assignment
# so each test uses its supplied parameters, as rmarkdown::render() would.
report_expressions <- parse(script_path)
check(identical(report_expressions[[1]][[1]], as.name("<-")) &&
        identical(report_expressions[[1]][[2]], as.name("params")),
      "recognised generated YAML parameter assignment")
report_expressions <- report_expressions[-1]
plot_path <- tempfile(fileext = ".pdf")
grDevices::pdf(plot_path)
scopes <- list()
for (include in c(FALSE, TRUE)) {
  env <- new.env(parent = globalenv())
  env$params <- list(include_non_employing = include, data_dir = "", export_tables = FALSE)
  invisible(capture.output(for (expression in report_expressions) eval(expression, envir = env)))
  categories <- c("Small business", "Medium business")
  if (include) categories <- c("Non employing", categories)
  selected <- raw[raw$`Business size` %in% categories &
                    raw$`Census year` >= 2002 & raw$`Census year` <= 2024, ]
  check(nrow(selected) == nrow(env$sme), "independent sample row count")
  check(sum(is.na(env$sme$total_jobs)) == sum(is.na(selected$`Total jobs`)),
        "rows with missing jobs remain in sample")
  # Match by labels rather than relying on row order.
  for (level in c("city", "precinct", "industry")) {
    groups <- list(census_year = selected$`Census year`)
    if (level == "precinct") groups$precinct <- selected$`CLUE small area`
    if (level == "industry") groups$industry <- selected$`ANZSIC indusrty`
    expected <- stats::aggregate(selected$`Total establishments`, groups, sum)
    actual <- get(paste0(level, "_yearly"), env)
    joined <- merge(expected, actual, by = names(groups), all = TRUE)
    check(nrow(joined) == nrow(expected) && !anyNA(joined) &&
            all(joined$x == joined$establishments), paste("independent sums:", level, include))
  }
  years <- c(2019L, 2022L, 2024L)
  expected <- vapply(years, function(year)
    sum(selected$`Total establishments`[selected$`Census year` == year]), numeric(1))
  check(identical(as.numeric(env$city_comparison[1, c("n_pre", "n_recovery_start", "n_latest")]),
                  expected), "three comparison totals")
  check(isTRUE(all.equal(env$city_comparison$gap_pct,
                         100 * (expected[3] - expected[1]) / expected[1])), "independent gap")
  check(isTRUE(all.equal(env$city_comparison$recovery_pct,
                         100 * (expected[3] - expected[2]) / expected[2])), "independent recent change")
  check(all(env$reconciliation$address_records == env$reconciliation$vacant_records +
              env$reconciliation$industry_coded_records), "address split reconciles")
  check(all(env$aggregate_missing$rows_checked == nrow(raw)), "full-file missing denominator")
  check(all(env$vacancy_missing$rows_checked == nrow(env$location_vacant)),
        "vacant subset denominator")
  check(all(abs(tapply(env$industry_yearly$establishments,
                       env$industry_yearly$census_year, sum) - env$city_yearly$establishments) < 1e-9),
        "industry shares use city population")
  scopes[[as.character(include)]] <- env$city_yearly
  cat("Validated full report chunks for include_non_employing =", include, "\n")
}
invisible(grDevices::dev.off())
non_employing <- raw[raw$`Business size` == "Non employing", ]
expected_extra <- tapply(non_employing$`Total establishments`, non_employing$`Census year`, sum)
check(all(scopes$`TRUE`$establishments - scopes$`FALSE`$establishments == expected_extra),
      "scope difference equals non-employing establishments")
check(identical(before, tools::md5sum(input_paths)), "raw CSV checksums unchanged")
cat("PASS:", checks, "checks; both SME definitions; raw files unchanged.\n")
