# Small, reusable checks and calculations for the CLUE report.
# Written by Group 10 and reviewed with AI tools. See docs/AI_ASSISTANCE.md.
# These functions do not read, change or save the source data.

assert_true <- function(condition, explanation) {
  if (!isTRUE(condition)) stop(explanation, call. = FALSE)
}

require_columns <- function(data, required, label) {
  missing <- setdiff(required, names(data))
  assert_true(length(missing) == 0,
              paste(label, "is missing columns:", paste(missing, collapse = ", ")))
}

check_key <- function(data, columns, label) {
  require_columns(data, columns, label)
  keys <- data[, columns, drop = FALSE]
  assert_true(!anyNA(keys), paste(label, "has missing values in its grouping key."))
  assert_true(anyDuplicated(keys) == 0,
              paste(label, "has duplicate grouping keys. Investigate before summing."))
}

# A missing or zero starting count has no defined percentage change.
# Return NA when the percentage cannot be calculated.
pct_change <- function(latest, baseline) {
  assert_true(length(latest) == length(baseline), "Change inputs must have equal length.")
  answer <- rep(NA_real_, length(baseline))
  valid <- is.finite(latest) & is.finite(baseline) & baseline > 0
  answer[valid] <- 100 * (latest[valid] - baseline[valid]) / baseline[valid]
  answer
}

missing_audit <- function(data, dataset) {
  tibble::tibble(
    dataset = dataset,
    variable = names(data),
    rows_checked = nrow(data),
    missing_count = vapply(data, function(x) sum(is.na(x)), integer(1)),
    # Blank strings can survive an import. Report them separately from NA.
    blank_string_count = vapply(data, function(x) {
      if (is.character(x)) sum(!is.na(x) & trimws(x) == "") else 0L
    }, integer(1))
  ) |>
    dplyr::mutate(missing_percent = 100 * missing_count / rows_checked)
}

# Summing counts is appropriate within a year. Never add years together and
# describe the result as a number of unique businesses.
sum_establishments <- function(data, groups = character()) {
  require_columns(data, c("census_year", groups, "total_establishments"), "Count data")
  assert_true(!anyNA(data$total_establishments), "Missing establishment counts need review.")
  assert_true(all(is.finite(data$total_establishments) & data$total_establishments >= 0 &
                    data$total_establishments == floor(data$total_establishments)),
              "Establishment counts must be non-negative whole numbers.")
  data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c("census_year", groups)))) |>
    dplyr::summarise(establishments = sum(total_establishments), .groups = "drop")
}

# Compare the same population at three dates. An absent source group stays NA.
# There is no evidence here that every omitted precinct-industry cell is zero.
compare_years <- function(counts, groups = character(),
                          years = c(2019L, 2022L, 2024L), min_base = 100L) {
  assert_true(length(years) == 3 && all(diff(years) >= 2),
              "Choose three increasing comparison years at least two years apart.")
  assert_true(length(min_base) == 1 && is.finite(min_base) && min_base >= 1,
              "The small-baseline threshold must be at least one.")
  require_columns(counts, c("census_year", groups, "establishments"), "Yearly counts")
  check_key(counts, c("census_year", groups), "Yearly counts")
  assert_true(all(years %in% counts$census_year), "A comparison year is missing from the file.")
  assert_true(all(is.na(counts$establishments) |
                    (is.finite(counts$establishments) & counts$establishments >= 0)),
              "Yearly counts must be non-negative or explicitly unavailable.")
  result <- counts |>
    dplyr::filter(census_year %in% years) |>
    dplyr::mutate(period = factor(census_year, levels = years,
                                  labels = c("pre", "recovery_start", "latest"))) |>
    dplyr::select(dplyr::all_of(groups), period, establishments) |>
    tidyr::pivot_wider(names_from = period, values_from = establishments,
                       names_prefix = "n_", names_expand = TRUE)
  result |>
    dplyr::mutate(
      gap_count = n_latest - n_pre,
      gap_pct = pct_change(n_latest, n_pre),
      recovery_count = n_latest - n_recovery_start,
      recovery_pct = pct_change(n_latest, n_recovery_start),
      small_pre_base = !is.na(n_pre) & n_pre < min_base,
      small_recovery_base = !is.na(n_recovery_start) & n_recovery_start < min_base,
      # Display rules do not change raw counts or exclude these areas from totals.
      gap_pct_display = dplyr::if_else(small_pre_base, NA_real_, gap_pct),
      recovery_pct_display = dplyr::if_else(small_recovery_base, NA_real_, recovery_pct),
      recovery_status = dplyr::case_when(
        is.na(n_pre) | is.na(n_recovery_start) | is.na(n_latest) ~ "Not comparable",
        n_latest >= n_pre ~ paste("At or above", years[1]),
        recovery_count > 0 ~ paste0("Below ", years[1], "; increasing since ", years[2]),
        recovery_count == 0 ~ paste0("Below ", years[1], "; unchanged since ", years[2]),
        TRUE ~ paste0("Below ", years[1], "; decreasing since ", years[2])
      )
    )
}

# Missing industry information is not automatically called a vacancy.
# Positive codes are described as industry-coded records, not proof that a
# business was independently checked on the exact census-year date.
classify_locations <- function(data) {
  require_columns(data, c("industry_anzsic4_code", "industry_anzsic4_description"),
                  "Address-level data")
  data |>
    dplyr::mutate(
      record_type = dplyr::case_when(
        is.na(industry_anzsic4_code) | is.na(industry_anzsic4_description) |
          trimws(industry_anzsic4_description) == "" ~ "Needs review",
        industry_anzsic4_code == 0 & industry_anzsic4_description == "Vacant Space" ~
          "Vacant Space",
        industry_anzsic4_code > 0 & industry_anzsic4_code < 9900 &
          !industry_anzsic4_description %in%
            c("Vacant Space", "Residential", "Common area", "Open space") ~
          "Industry-coded establishment",
        TRUE ~ "Needs review"
      )
    )
}

# Format calculated results for tables and text.
fmt_count <- function(x) scales::comma(x, accuracy = 1)
fmt_pct <- function(x) ifelse(is.na(x), "not reported", sprintf("%+.1f%%", x))
fmt_change <- function(x) ifelse(is.na(x), "not available",
                                paste0(ifelse(x > 0, "+", ""), fmt_count(x)))
