# Independent checks for the final-report peer comparison supplement.
# Run from the repository root: Rscript tests/test_peer_comparison_review.R
# These tests recompute the key quantities directly from the raw CSV using
# base R. They do not compare one exported table with another exported table.

options(warn = 2)
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
ROOT <- normalizePath(file.path(dirname(script), ".."))
source(file.path(ROOT, "scripts/07_peer_comparison_review.R"))
peer_required_packages(FALSE)
passed <- character()
check <- function(condition, label) {
  if (!isTRUE(condition)) stop("FAIL: ", label)
  passed <<- c(passed, label)
}
near <- function(x, y, tolerance = 1e-8) {
  isTRUE(all.equal(as.numeric(x), as.numeric(y), tolerance = tolerance))
}
fails <- function(expr) inherits(tryCatch(force(expr), error = identity), "error")
source_environment <- new.env()
source_output <- capture.output(source(file.path(ROOT,
  "scripts/07_peer_comparison_review.R"), local = source_environment))
check(length(source_output) == 0L && all(vapply(as.list(source_environment), is.function, logical(1))),
  "Sourcing the module defines functions without running the analysis")

SOURCE <- file.path(ROOT, "data/business-establishments-and-jobs-data-by-business-size-and-anzsic.csv")
original_hash <- unname(tools::md5sum(SOURCE))
raw <- read.csv(SOURCE, check.names = FALSE, stringsAsFactors = FALSE)
sme <- raw[raw$`Business size` %in% c("Small business", "Medium business"), ]
check(!anyNA(sme$`Total establishments`), "Raw SME counts are complete")
independent_counts <- aggregate(sme$`Total establishments`, list(
  year = sme$`Census year`, precinct = sme$`CLUE small area`,
  industry = sme$`ANZSIC indusrty`), sum)
names(independent_counts)[4] <- "establishments"

# Run in an isolated temporary root. The input is copied, and test products do
# not replace the report outputs or change the original supplied data.
test_root <- tempfile("peer-review-test-")
dir.create(file.path(test_root, "data"), recursive = TRUE)
stopifnot(file.copy(SOURCE, file.path(test_root, "data", basename(SOURCE))))
result <- run_peer_review(test_root, make_figures = FALSE)
table <- result$tables$peer_comparisons
check(nrow(table) == 15L, "Five cases are compared over three defined periods")
check(!anyNA(table[c("n_start", "n_end", "local_growth_pct", "peer_growth_pct")]),
  "All selected local cells are observed")
for (i in seq_len(nrow(table))) {
  row <- table[i, ]
  raw_total <- function(year, local = TRUE) {
    take <- sme$`Census year` == year & sme$`ANZSIC indusrty` == row$industry &
      if (local) sme$`CLUE small area` == row$precinct else sme$`CLUE small area` != row$precinct
    sum(sme$`Total establishments`[take])
  }
  local_a <- raw_total(row$start_year); local_b <- raw_total(row$end_year)
  peer_a <- raw_total(row$start_year, FALSE); peer_b <- raw_total(row$end_year, FALSE)
  check(near(c(row$n_start, row$n_end, row$peer_start, row$peer_end),
    c(local_a, local_b, peer_a, peer_b)), paste("Raw totals match comparison", i))
  check(near(row$local_growth_pct, 100 * (local_b / local_a - 1)) &&
    near(row$peer_growth_pct, 100 * (peer_b / peer_a - 1)) &&
    near(row$observed_minus_benchmark, local_b - local_a * peer_b / peer_a),
    paste("Independent growth and benchmark arithmetic", i))
}

recent <- table[table$start_year == 2022, ]
check(near(recent$local_growth_pct, 100 * (c(1338, 534, 219, 96, 202) /
  c(1383, 554, 243, 111, 212) - 1)), "Recent local rates reproduce raw five-case counts")
check(near(recent$peer_growth_pct, 100 * (c(697, 122, 117, 205, 2717) /
  c(678, 136, 135, 180, 2493) - 1)), "Leave-one-precinct-out peer rates reproduce raw counts")
check(sum(recent$growth_gap_pp < 0) == 3L, "Three cases grew more slowly than peers")
check(near(sum(result$tables$selected_cases$shortfall), 876), "Five historical shortfalls total 876")
check(near(sum(result$tables$selected_cases$recent_change), -114), "Five recent changes total minus 114")
check(near(recent$matched_peer_growth_pct[4], 100 * (204 / 180 - 1)),
  "Construction matched-peer sensitivity excludes the unmatched Parkville cell")
check(all((recent$growth_gap_pp < 0) == (recent$matched_growth_gap_pp < 0)),
  "Matched-peer comparison preserves all five direction conclusions")

# Independently rebuild the selection rule, including its separate hospitality
# contrast. Baseline-year sensitivity must be allowed to change the roster.
independent_selection <- function(year, cutoff) {
  part <- function(y) {
    z <- independent_counts[independent_counts$year == y, c("precinct", "industry", "establishments")]
    names(z)[3] <- paste0("n", y)
    z
  }
  z <- merge(merge(part(year), part(2022), all = TRUE), part(2024), all = TRUE)
  z$gap <- z[[paste0("n", year)]] - z$n2024
  z$rate <- 100 * (z$n2024 / z$n2022 - 1)
  z <- z[!is.na(z$gap) & !is.na(z$rate) & z$gap > 0 & z$rate < 0, ]
  z <- z[order(-z$gap, z$precinct, z$industry), ]
  a <- head(z[z$rate <= -cutoff, ], 4)
  b <- head(z[z$precinct != "Melbourne (CBD)" & z$industry == "Accommodation and Food Services", ], 1)
  rbind(a, b)
}
keys <- function(x) paste(x$precinct, x$industry, sep = " | ")
sensitivity <- result$tables$threshold_sensitivity
for (year in c(2018, 2019)) for (cutoff in c(0, 1, 2, 3, 5)) {
  actual <- sensitivity[sensitivity$baseline_year == year & sensitivity$threshold_pct == cutoff, ]
  expected <- independent_selection(year, cutoff)
  check(identical(keys(actual), keys(expected)), paste("Independent case ranking", year, cutoff))
}
stability <- result$tables$threshold_stability
check(all(stability$same_scale_set_as_2019_two_percent[
  stability$baseline_year == 2019 & stability$threshold_pct %in% 1:3]),
  "The original four scale cases remain at cutoffs 1, 2 and 3 percent")
alternate <- independent_selection(2018, 2)
check(sum(keys(alternate) %in% keys(result$tables$selected_cases)) == 3L,
  "Only three of five selected cases survive the 2018-baseline reranking")
check(alternate$precinct[4] == "North Melbourne" && alternate$precinct[5] == "Docklands",
  "2018 baseline substitutes North Melbourne professional services and Docklands hospitality")

# Recalculate every historical comparison without the module's helper.
hist <- result$tables$full_two_year_history
independent_gap <- function(row) {
  get <- function(y, local) sum(independent_counts$establishments[
    independent_counts$year == y & independent_counts$industry == row$industry &
    if (local) independent_counts$precinct == row$precinct else independent_counts$precinct != row$precinct])
  100 * (get(row$end_year, TRUE) / get(row$start_year, TRUE) -
    get(row$end_year, FALSE) / get(row$start_year, FALSE))
}
check(near(hist$growth_gap_pp, vapply(seq_len(nrow(hist)),
  function(i) independent_gap(hist[i, ]), numeric(1))), "All primary history windows match independent arithmetic")
professional_pre <- hist[hist$case_rank == 1 & hist$end_year <= 2019, ]
check(nrow(professional_pre) == 8L && sum(professional_pre$growth_gap_pp < 0) == 3L,
  "Professional services underperformed in three of eight odd-year pre-periods")
even <- result$tables$alternate_even_year_history
check(sum(even$growth_gap_pp[even$case_rank == 1 & even$end_year <= 2018] < 0) == 5L,
  "Alternate even-year history gives five of eight earlier underperformances")
check(hist$growth_gap_pp[hist$case_rank == 1 & hist$start_year == 2020] > 0,
  "Professional services outperformed peers in 2020-2022")
ref <- result$tables$hospitality_reference_sensitivity
check(near(ref$peer_growth_pct, 100 * (c(2717, 980) / c(2493, 936) - 1)),
  "Southbank comparison is not driven solely by the CBD reference")

# Edge cases: absence is unknown; it must never turn into an invented zero.
fixture <- data.frame(year = c(2022, 2024, 2022, 2024),
  precinct = c("A", "A", "B", "C"), industry = "I", establishments = c(10, 9, 5, 7))
fixture_case <- data.frame(case_rank = 1L, label = "A", precinct = "A", industry = "I")
edge <- peer_compare(fixture, fixture_case, 2022, 2024)
check(is.na(edge$matched_peer_growth_pct) && edge$peer_matched_cells == 0L,
  "Disjoint peer observations are exposed rather than filled with zero")
fixture_case$precinct <- "B"
edge <- peer_compare(fixture, fixture_case, 2022, 2024)
check(is.na(edge$n_end) && is.na(edge$local_growth_pct), "Absent local end-year cell remains unknown")
check(all(is.na(peer_rate(c(0, NA_real_), c(1, 2)))), "Zero or unknown baseline has no percentage growth")
check(fails(peer_compare(fixture, fixture_case, 2022, 2023)), "Annual comparisons are rejected")
check(fails(peer_select(peer_screen(independent_counts), -1)), "Invalid negative cutoff is rejected")
check(identical(original_hash, unname(tools::md5sum(SOURCE))), "Original source checksum is unchanged")

output <- file.path(ROOT, "outputs/tables/final/deeper_review")
dir.create(output, recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(list(status = "PASS", checks = length(passed), source_md5 = original_hash,
  checks_passed = passed), file.path(output, "test_results.json"), pretty = TRUE, auto_unbox = TRUE)
cat("PASS:", length(passed), "peer-comparison checks. Raw input unchanged.\n")
