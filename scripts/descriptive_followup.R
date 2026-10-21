# Descriptive follow-up for the final report.
# Source this file to define functions only. Nothing is read or written on source().
# Main population: Small and Medium business establishments (1-199 jobs).
# Counts describe establishments, not unique firms or individual openings/closures.

followup_ratio <- function(numerator, denominator) {
  if (length(numerator) != length(denominator)) stop("Ratio inputs must have equal lengths.")
  answer <- rep(NA_real_, length(numerator))
  valid <- is.finite(numerator) & is.finite(denominator) & denominator > 0
  answer[valid] <- 100 * numerator[valid] / denominator[valid]
  answer
}

# Full joins keep an absent source combination unknown. Do not fill it with zero.
followup_compare <- function(counts, groups, start, end) {
  if (end - start < 2) stop("Comparisons must be at least two years apart.")
  if (!all(c(start, end) %in% counts$year)) stop("Comparison year absent.")
  b <- counts |>
    dplyr::filter(year == start) |>
    dplyr::select(dplyr::all_of(groups), n_start = establishments)
  e <- counts |>
    dplyr::filter(year == end) |>
    dplyr::select(dplyr::all_of(groups), n_end = establishments)
  dplyr::full_join(b, e, by = groups) |>
    dplyr::mutate(start_year = start, end_year = end,
      comparison_status = dplyr::case_when(
        is.na(n_start) ~ "Start-year source cell absent",
        is.na(n_end) ~ "End-year source cell absent",
        TRUE ~ "Observed in both years"),
      change = n_end - n_start,
      pct_change = followup_ratio(change, n_start),
      small_baseline = !is.na(n_start) & n_start < 100,
      pct_change_display = dplyr::if_else(small_baseline, NA_real_, pct_change))
}

# Descriptive industry-mix comparison. The precinct is excluded from its own
# reference group. This is an observed comparison, not a forecast or policy effect.
# Expected end count = local start * outside-industry end / outside-industry start.
# We sum expected and observed counts over exactly the same eligible local cells.
followup_benchmark <- function(cell_changes, industry_yearly, minimum_outside_start = 1) {
  if (length(minimum_outside_start) != 1L || !is.finite(minimum_outside_start) ||
      minimum_outside_start < 1) stop("Reference threshold must be at least one.")
  start_totals <- industry_yearly |>
    dplyr::rename(start_year = year, city_industry_start = establishments)
  end_totals <- industry_yearly |>
    dplyr::rename(end_year = year, city_industry_end = establishments)
  detail <- cell_changes |>
    dplyr::left_join(start_totals, by = c("start_year", "industry")) |>
    dplyr::left_join(end_totals, by = c("end_year", "industry")) |>
    dplyr::mutate(
      outside_start = city_industry_start - n_start,
      outside_end = city_industry_end - n_end,
      eligible = !is.na(change) & n_start > 0 & !is.na(outside_start) &
        outside_start >= minimum_outside_start & !is.na(outside_end) & outside_end >= 0,
      outside_industry_growth_pct = dplyr::if_else(eligible,
        followup_ratio(outside_end - outside_start, outside_start), NA_real_),
      expected_end = dplyr::if_else(eligible,
        n_start * outside_end / outside_start, NA_real_),
      observed_minus_expected = n_end - expected_end,
      minimum_outside_start = minimum_outside_start)
  summary <- detail |>
    dplyr::group_by(start_year, end_year, precinct, minimum_outside_start) |>
    dplyr::summarise(eligible_cells = sum(eligible), source_cells_either_year = dplyr::n(),
      source_start_total = sum(n_start, na.rm = TRUE),
      source_end_total = sum(n_end, na.rm = TRUE),
      compared_start_total = if (any(eligible)) sum(n_start[eligible]) else NA_real_,
      compared_end_total = if (any(eligible)) sum(n_end[eligible]) else NA_real_,
      expected_end_total = if (any(eligible)) sum(expected_end[eligible]) else NA_real_,
      observed_minus_expected = if (any(eligible)) sum(observed_minus_expected[eligible]) else NA_real_,
      .groups = "drop") |>
    dplyr::mutate(
      start_coverage_pct = followup_ratio(compared_start_total, source_start_total),
      end_coverage_pct = followup_ratio(compared_end_total, source_end_total),
      actual_growth_pct = followup_ratio(compared_end_total - compared_start_total, compared_start_total),
      expected_growth_pct = followup_ratio(expected_end_total - compared_start_total, compared_start_total),
      growth_difference_pp = actual_growth_pct - expected_growth_pct,
      high_coverage_both_years = !is.na(start_coverage_pct) & !is.na(end_coverage_pct) &
        start_coverage_pct >= 95 & end_coverage_pct >= 95,
      baseline_at_least_100 = !is.na(compared_start_total) & compared_start_total >= 100)
  list(detail = detail, summary = summary)
}

# A review list based on two observed facts, without a weighted or invented score.
# The percentage display threshold avoids ranking very small areas by volatile rates.
followup_priorities <- function(precinct_yearly) {
  wide <- precinct_yearly |>
    dplyr::filter(year %in% c(2019L, 2022L, 2024L)) |>
    tidyr::pivot_wider(names_from = year, values_from = establishments, names_prefix = "n_")
  wide |>
    dplyr::mutate(
      gap_count = n_2024 - n_2019,
      shortfall_count = pmax(n_2019 - n_2024, 0),
      gap_pct = followup_ratio(gap_count, n_2019),
      recent_change = n_2024 - n_2022,
      recent_pct = followup_ratio(recent_change, n_2022),
      gap_pct_display = dplyr::if_else(n_2019 >= 100, gap_pct, NA_real_),
      recent_pct_display = dplyr::if_else(n_2022 >= 100, recent_pct, NA_real_),
      small_baseline_warning = n_2019 < 100 | n_2022 < 100,
      # Keep the count-based screen separate from the percentage-display rule.
      # A small group can meet both decline conditions without a useful rate ranking.
      persistent_decline = dplyr::case_when(
        is.na(gap_count) | is.na(recent_change) ~ NA,
        TRUE ~ gap_count < 0 & recent_change < 0),
      review_category = dplyr::case_when(
        is.na(gap_count) | is.na(recent_change) ~ "Incomplete comparison",
        small_baseline_warning ~ "Small baseline: use counts",
        gap_count < 0 & recent_change < 0 ~ "Below 2019 and still decreasing",
        gap_count < 0 & recent_change == 0 ~ "Below 2019 and unchanged",
        gap_count < 0 & recent_change > 0 ~ "Below 2019 and increasing",
        TRUE ~ "At or above 2019"),
      context_check = dplyr::if_else(precinct %in% c("West Melbourne (Industrial)",
        "North Melbourne", "Parkville"),
        "Check land-use and major-site changes before attributing causes", ""),
      absolute_shortfall_rank = dplyr::min_rank(dplyr::desc(shortfall_count)),
      percentage_gap_rank = dplyr::min_rank(gap_pct_display),
      recent_change_rank = dplyr::min_rank(recent_change)) |>
    dplyr::arrange(dplyr::desc(shortfall_count), precinct)
}

# Select cases reproducibly, before writing their interpretation. Rank only the
# groups meeting both observed-decline conditions. Alphabetical ties are stable.
# The rank measures absolute historical shortfall, not policy benefit or urgency.
followup_case_studies <- function(review, number = 5L) {
  if (length(number) != 1L || !is.finite(number) || number < 1 || number != floor(number))
    stop("Case count must be a positive whole number.")
  review |>
    dplyr::filter(persistent_decline %in% TRUE) |>
    dplyr::arrange(dplyr::desc(shortfall_count), precinct, industry) |>
    dplyr::slice_head(n = number) |>
    dplyr::mutate(case_rank = dplyr::row_number())
}

followup_figures <- function(tables, output_dir) {
  navy <- "#253F57"
  teal <- "#187F86"
  orange <- "#B94E32"
  style <- ggplot2::theme_minimal(base_size = 12, base_family = "sans") +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", colour = navy, size = 17),
      plot.subtitle = ggplot2::element_text(colour = "#475569", size = 11),
      plot.caption = ggplot2::element_text(colour = "#586675", hjust = 0),
      plot.margin = ggplot2::margin(16, 24, 14, 14), legend.position = "none")
  caption <- "Source: City of Melbourne CLUE. Small and Medium businesses (1-199 jobs)."
  selected <- tables$city_yearly |>
    dplyr::filter(year %in% c(2019L, 2022L, 2024L))
  city <- ggplot2::ggplot(selected, ggplot2::aes(year, establishments)) +
    ggplot2::geom_line(linewidth = 1.3, colour = teal) +
    ggplot2::geom_point(size = 4, colour = teal) +
    ggplot2::geom_text(ggplot2::aes(label = scales::comma(establishments)),
      vjust = -1, fontface = "bold", colour = navy, size = 5) +
    ggplot2::scale_x_continuous(breaks = c(2019, 2022, 2024), limits = c(2018.6, 2024.4)) +
    ggplot2::scale_y_continuous(labels = scales::label_comma(),
      limits = c(0, max(selected$establishments) * 1.17)) +
    ggplot2::labs(title = "SME counts rose after 2022, with a substantial gap remaining",
      subtitle = "Selected census years. The line joins the three observed totals.",
      x = NULL, y = "SME establishments", caption = caption) + style

  precinct_order <- tables$review_priorities$precinct
  precinct_data <- tables$review_priorities |>
    dplyr::select(precinct, gap_count, recent_change) |>
    tidyr::pivot_longer(c(gap_count, recent_change), names_to = "period", values_to = "change") |>
    dplyr::mutate(precinct = factor(precinct, levels = rev(precinct_order)),
      period = factor(period, levels = c("gap_count", "recent_change"),
        labels = c("2019 to 2024", "2022 to 2024")))
  precinct <- ggplot2::ggplot(precinct_data, ggplot2::aes(change, precinct)) +
    ggplot2::geom_vline(xintercept = 0, colour = "#A3AFBA", linewidth = .4) +
    ggplot2::geom_col(ggplot2::aes(fill = change >= 0), width = .66) +
    ggplot2::geom_text(ggplot2::aes(label = scales::comma(change),
      hjust = ifelse(change < 0, 1.15, -.15)), size = 3.3) +
    ggplot2::facet_wrap(~period, scales = "free_x") +
    ggplot2::scale_fill_manual(values = c("FALSE" = orange, "TRUE" = teal)) +
    ggplot2::scale_x_continuous(labels = scales::label_comma(), expand = ggplot2::expansion(mult = .22)) +
    ggplot2::labs(title = "The CBD accounts for the largest remaining shortfall",
      subtitle = "Absolute count changes keep large and small precincts in context.",
      x = "Change in SME establishments", y = NULL, caption = caption) + style

  industry_data <- tables$industry_recent_contributions |>
    dplyr::mutate(industry = factor(industry, levels = industry[order(change)]))
  industry <- ggplot2::ggplot(industry_data, ggplot2::aes(change, industry)) +
    ggplot2::geom_vline(xintercept = 0, colour = "#A3AFBA", linewidth = .4) +
    ggplot2::geom_col(ggplot2::aes(fill = change >= 0), width = .65) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%+g", change),
      hjust = ifelse(change < 0, 1.15, -.15)), size = 3.4) +
    ggplot2::scale_fill_manual(values = c("FALSE" = orange, "TRUE" = teal)) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = .2)) +
    ggplot2::labs(title = "Hospitality contributed the largest recent gain",
      subtitle = "2022 to 2024. Industry gains and losses add to the city net change.",
      x = "Change in SME establishments", y = NULL, caption = caption) + style

  benchmark_data <- tables$benchmark_summary |>
    dplyr::filter(start_year == 2022L, high_coverage_both_years, baseline_at_least_100) |>
    dplyr::mutate(precinct = stats::reorder(precinct, growth_difference_pp))
  benchmark <- ggplot2::ggplot(benchmark_data, ggplot2::aes(growth_difference_pp, precinct)) +
    ggplot2::geom_vline(xintercept = 0, colour = "#8C99A6", linetype = "dashed") +
    ggplot2::geom_segment(ggplot2::aes(x = 0, xend = growth_difference_pp, yend = precinct),
      colour = "#B7C7D3", linewidth = 1.2) +
    ggplot2::geom_point(ggplot2::aes(colour = growth_difference_pp >= 0), size = 3.5) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%+.1f", growth_difference_pp),
      hjust = ifelse(growth_difference_pp < 0, 1.4, -.4)), size = 3.4) +
    ggplot2::scale_colour_manual(values = c("FALSE" = orange, "TRUE" = teal)) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = .25)) +
    ggplot2::labs(title = "Recent growth differs from the industry-mix comparison",
      subtitle = "Each precinct is compared with the same industries elsewhere in the city.",
      x = "Actual growth minus comparison growth (percentage points)", y = NULL,
      caption = paste0(caption, "\nDescriptive comparison, 2022-2024. At least 95% count coverage and 100 baseline establishments.")) + style
  cases_data <- tables$case_studies |>
    dplyr::mutate(label = paste0(case_rank, ". ", gsub(", ", ",\n", industry)),
      label = factor(label, levels = rev(label))) |>
    dplyr::select(label, gap_count, recent_change) |>
    tidyr::pivot_longer(c(gap_count, recent_change), names_to = "period", values_to = "change") |>
    dplyr::mutate(period = factor(period, levels = c("gap_count", "recent_change"),
      labels = c("Gap from 2019 (2019 to 2024)", "Recent change (2022 to 2024)")))
  cases_chart <- ggplot2::ggplot(cases_data, ggplot2::aes(change, label)) +
    ggplot2::geom_vline(xintercept = 0, colour = "#A3AFBA", linewidth = .4) +
    ggplot2::geom_col(fill = orange, width = .55) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%+g", change)), hjust = 1.2, size = 4) +
    ggplot2::facet_wrap(~period, scales = "free_x") +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(.22, .06))) +
    ggplot2::labs(title = "The five largest shortfalls among still-declining groups are in the CBD",
      subtitle = "Ranked by the 2019-2024 count gap. Each panel has its own horizontal scale.",
      x = "Change in SME establishments", y = NULL, caption = paste0(caption,
        "\nScreen: below 2019 in 2024 and decreasing from 2022 to 2024. This is a count-based review list.")) +
    style
  charts <- list(city_recovery = city, precinct_changes = precinct,
    industry_recent_change = industry, industry_mix_comparison = benchmark,
    priority_cases = cases_chart)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  for (name in names(charts)) ggplot2::ggsave(file.path(output_dir, paste0(name, ".png")),
    charts[[name]], width = 11.5, height = if (name == "city_recovery") 6.4 else 8,
    units = "in", dpi = 180, bg = "white")
  charts
}

run_followup <- function(data_path, output_dir, make_figures = TRUE) {
  packages <- c("dplyr", "readr", "tidyr", "jsonlite")
  if (make_figures) packages <- c(packages, "ggplot2", "scales")
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Install required packages: ", paste(missing, collapse = ", "))
  if (!file.exists(data_path)) stop("Aggregate source CSV not found: ", data_path)
  source_md5 <- unname(tools::md5sum(data_path))
  raw <- readr::read_csv(data_path, show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character(),
      `Census year` = readr::col_integer(), `Total establishments` = readr::col_double(),
      `Total jobs` = readr::col_double()))
  if (nrow(readr::problems(raw))) stop("Source contains parsing problems.")
  required <- c("Census year", "CLUE small area", "ANZSIC indusrty", "Business size",
    "Total establishments", "Total jobs")
  if (!all(required %in% names(raw))) stop("Required source columns missing.")
  data <- dplyr::rename(raw, year = `Census year`, precinct = `CLUE small area`,
    industry = `ANZSIC indusrty`, size = `Business size`,
    establishments = `Total establishments`, jobs = `Total jobs`)
  key <- data[c("year", "precinct", "industry", "size")]
  if (anyNA(key) || anyDuplicated(key)) stop("Missing or duplicate source keys.")
  if (anyNA(data$establishments) || any(!is.finite(data$establishments) |
      data$establishments < 0 | data$establishments != floor(data$establishments)))
    stop("Establishment counts must be complete non-negative whole numbers.")
  sme <- data |>
    dplyr::filter(size %in% c("Small business", "Medium business"), year >= 2002L, year <= 2024L)
  cells <- sme |>
    dplyr::group_by(year, precinct, industry) |>
    dplyr::summarise(establishments = sum(establishments), .groups = "drop")
  city <- cells |>
    dplyr::group_by(year) |>
    dplyr::summarise(establishments = sum(establishments), .groups = "drop")
  industry_yearly <- cells |>
    dplyr::group_by(year, industry) |>
    dplyr::summarise(establishments = sum(establishments), .groups = "drop")
  precinct_yearly <- cells |>
    dplyr::group_by(year, precinct) |>
    dplyr::summarise(establishments = sum(establishments), .groups = "drop")
  # 2017-2019 gives pre-pandemic context. These differences do not isolate causes.
  periods <- list(c(2019L, 2024L), c(2022L, 2024L), c(2017L, 2019L))
  compare_periods <- function(x, groups) dplyr::bind_rows(lapply(periods,
    function(p) followup_compare(x, groups, p[1], p[2])))
  cell_changes <- compare_periods(cells, c("precinct", "industry"))
  industry_changes <- compare_periods(industry_yearly, "industry") |>
    dplyr::group_by(start_year, end_year) |>
    # A negative city net change is a valid denominator for contributions to loss.
    # This differs from a growth rate, which needs a positive starting count.
    dplyr::mutate(share_of_city_net_change_pct =
      if (sum(change) != 0) 100 * change / sum(change) else NA_real_) |>
    dplyr::ungroup()
  # Contributions to a positive city gain can exceed 100% when losses offset gains.
  # Gross positive gains provide an additional denominator for concentration.
  recent <- industry_changes |>
    dplyr::filter(start_year == 2022L) |>
    dplyr::mutate(share_of_gross_industry_gain_pct = dplyr::if_else(change > 0,
      followup_ratio(change, rep(sum(change[change > 0]), dplyr::n())), NA_real_)) |>
    dplyr::arrange(dplyr::desc(change))
  coverage <- cell_changes |>
    dplyr::group_by(start_year, end_year, precinct) |>
    dplyr::summarise(source_cells_either_year = dplyr::n(),
      matched_cells = sum(!is.na(change)), cells_missing_one_year = sum(is.na(change)),
      source_start_total = sum(n_start, na.rm = TRUE), source_end_total = sum(n_end, na.rm = TRUE),
      matched_start_total = sum(n_start[!is.na(change)]), matched_end_total = sum(n_end[!is.na(change)]),
      .groups = "drop") |>
    dplyr::mutate(matched_start_coverage_pct = followup_ratio(matched_start_total, source_start_total),
      matched_end_coverage_pct = followup_ratio(matched_end_total, source_end_total))
  benchmark <- followup_benchmark(cell_changes, industry_yearly)
  sensitivity <- followup_benchmark(cell_changes, industry_yearly, 100)
  reconciliation <- cell_changes |>
    dplyr::group_by(start_year, end_year) |>
    dplyr::summarise(matched_change = sum(change, na.rm = TRUE),
      end_only_observed_count = sum(n_end[is.na(n_start)], na.rm = TRUE),
      start_only_observed_count = sum(n_start[is.na(n_end)], na.rm = TRUE),
      source_total_change = sum(n_end, na.rm = TRUE) - sum(n_start, na.rm = TRUE),
      .groups = "drop") |>
    dplyr::mutate(reconciliation_difference = matched_change + end_only_observed_count -
      start_only_observed_count - source_total_change)
  stopifnot(all(reconciliation$reconciliation_difference == 0))
  priorities <- followup_priorities(precinct_yearly)
  # Apply the same transparent comparisons at the precinct-industry level.
  # No weighted score is imposed: reviewers can compare scale, proportion and
  # recent direction. Absent 2019/2022/2024 cells remain incomplete.
  cell_priorities <- followup_priorities(cells) |>
    dplyr::mutate(absolute_shortfall_rank = dplyr::min_rank(dplyr::desc(shortfall_count)),
      percentage_gap_rank = dplyr::min_rank(gap_pct_display))
  cases <- followup_case_studies(cell_priorities)
  screen_summary <- cell_priorities |>
    dplyr::summarise(groups_in_any_reference_year = dplyr::n(),
      complete_three_year_groups = sum(!is.na(persistent_decline)),
      incomplete_groups = sum(is.na(persistent_decline)),
      groups_meeting_screen = sum(persistent_decline, na.rm = TRUE),
      screened_with_both_baselines_at_least_100 =
        sum(persistent_decline & !small_baseline_warning, na.rm = TRUE),
      screened_with_small_baseline = sum(persistent_decline & small_baseline_warning, na.rm = TRUE))
  tables <- list(city_yearly = city, precinct_yearly = precinct_yearly,
    industry_yearly = industry_yearly, precinct_changes = compare_periods(precinct_yearly, "precinct"),
    industry_changes = industry_changes, industry_recent_contributions = recent,
    precinct_industry_changes = cell_changes, comparison_coverage = coverage,
    unmatched_cells = dplyr::filter(cell_changes, is.na(change)),
    benchmark_details = benchmark$detail, benchmark_summary = benchmark$summary,
    benchmark_minimum_outside_100 = sensitivity$summary,
    period_reconciliation = reconciliation, review_priorities = priorities,
    precinct_industry_review = cell_priorities,
    persistent_decline_groups = dplyr::filter(cell_priorities, persistent_decline %in% TRUE),
    priority_screen_summary = screen_summary, case_studies = cases)
  get_count <- function(year) city$establishments[match(year, city$year)]
  cbd <- priorities[priorities$precinct == "Melbourne (CBD)", ]
  hospitality <- recent[recent$industry == "Accommodation and Food Services", ]
  metrics <- list(scope = "Small and Medium business establishments (1-199 jobs)",
    source_filename = basename(data_path), source_md5 = source_md5,
    source_rows = nrow(raw), selected_source_rows = nrow(sme),
    source_columns = ncol(raw), source_years = dplyr::n_distinct(data$year),
    precincts = dplyr::n_distinct(sme$precinct), industries = dplyr::n_distinct(sme$industry),
    missing_job_rows = sum(is.na(data$jobs)),
    missing_job_pct = 100 * mean(is.na(data$jobs)),
    case_shortfall = sum(cases$shortfall_count), case_recent_loss = -sum(cases$recent_change),
    city_counts = dplyr::filter(city, year %in% c(2019L, 2022L, 2024L)),
    city_recent_gain = get_count(2024) - get_count(2022),
    city_remaining_shortfall = get_count(2019) - get_count(2024),
    city_gap_pct = followup_ratio(get_count(2024) - get_count(2019), get_count(2019)),
    city_recent_pct = followup_ratio(get_count(2024) - get_count(2022), get_count(2022)),
    share_of_2019_to_2022_loss_offset_pct = followup_ratio(
      get_count(2024) - get_count(2022), get_count(2019) - get_count(2022)),
    precincts_below_2019 = sum(priorities$gap_count < 0),
    precincts_increasing_since_2022 = sum(priorities$recent_change > 0),
    cbd_shortfall = cbd$shortfall_count, cbd_recent_gain = cbd$recent_change,
    cbd_share_of_remaining_city_shortfall_pct = followup_ratio(cbd$shortfall_count,
      get_count(2019) - get_count(2024)),
    cbd_share_of_recent_city_gain_pct = followup_ratio(cbd$recent_change,
      get_count(2024) - get_count(2022)),
    hospitality_recent_gain = hospitality$change,
    hospitality_share_of_city_net_gain_pct = hospitality$share_of_city_net_change_pct,
    gross_industry_gains = sum(recent$change[recent$change > 0]),
    gross_industry_losses = sum(recent$change[recent$change < 0]),
    notes = c("Changes are net establishment counts, not individual openings or closures.",
      "Absent precinct-industry cells stay unknown. Coverage is exported.",
      "The industry-mix comparison is descriptive and uses observed rest-of-city totals.",
      "The 100-establishment and 95% coverage thresholds are review choices, not publisher rules.",
      "Priority categories summarise observed gaps and recent changes. They do not predict policy benefits."))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  for (name in names(tables)) readr::write_csv(tables[[name]], file.path(output_dir,
    paste0(name, ".csv")), na = "NA")
  jsonlite::write_json(metrics, file.path(output_dir, "descriptive_metrics.json"),
    pretty = TRUE, auto_unbox = TRUE, na = "null", digits = NA)
  figures <- if (make_figures) followup_figures(tables, file.path(output_dir, "figures")) else list()
  if (!identical(source_md5, unname(tools::md5sum(data_path)))) stop("Raw source checksum changed.")
  invisible(list(tables = tables, metrics = metrics, figures = figures))
}

# CLI defaults are relative to this script, so the working directory can differ.
if (sys.nframe() == 0L) {
  script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  script_dir <- dirname(normalizePath(sub("^--file=", "", script_arg)))
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 2L) stop("Usage: Rscript descriptive_followup.R [source.csv] [output-folder]")
  data_path <- if (length(args)) args[1] else file.path(script_dir, "../data",
    "business-establishments-and-jobs-data-by-business-size-and-anzsic.csv")
  output_dir <- if (length(args) > 1L) args[2] else file.path(script_dir, "../outputs/tables/final/descriptive")
  run_followup(data_path, output_dir)
  cat("Descriptive follow-up saved to", normalizePath(output_dir), "\n")
}
