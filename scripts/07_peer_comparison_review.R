# Compare the five final-report cases with the same industries elsewhere.
# Run from the repository root: Rscript scripts/07_peer_comparison_review.R
# Sourcing this file defines functions only. Raw data are never overwritten.

peer_required_packages <- function(make_figures = TRUE) {
  packages <- c("dplyr", "tidyr", "readr", "jsonlite")
  if (make_figures) packages <- c(packages, "ggplot2")
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Missing packages: ", paste(missing, collapse = ", "))
}

peer_read_counts <- function(path) {
  raw <- readr::read_csv(path, show_col_types = FALSE, col_types = readr::cols(
    .default = readr::col_character(), `Census year` = readr::col_integer(),
    `Total establishments` = readr::col_double(), `Total jobs` = readr::col_double()))
  if (nrow(readr::problems(raw))) stop("Source parsing problems need review.")
  keys <- c("Census year", "CLUE small area", "ANZSIC indusrty", "Business size")
  if (!all(c(keys, "Total establishments") %in% names(raw))) stop("Missing source columns.")
  if (anyNA(raw[keys]) || anyDuplicated(raw[keys])) stop("Missing or duplicate source keys.")
  n <- raw$`Total establishments`
  if (anyNA(n) || any(!is.finite(n) | n < 0 | n != floor(n))) stop("Invalid establishment count.")
  raw |>
    dplyr::filter(`Business size` %in% c("Small business", "Medium business")) |>
    dplyr::transmute(year = `Census year`, precinct = `CLUE small area`,
      industry = `ANZSIC indusrty`, establishments = `Total establishments`) |>
    dplyr::group_by(year, precinct, industry) |>
    dplyr::summarise(establishments = sum(establishments), .groups = "drop")
}

peer_rate <- function(start, end) {
  if (length(start) != length(end)) stop("Unequal rate input lengths.")
  out <- rep(NA_real_, length(start))
  valid <- is.finite(start) & is.finite(end) & start > 0
  out[valid] <- 100 * (end[valid] / start[valid] - 1)
  out
}

# A full join exposes absent precinct-industry-year combinations as unknown.
# Published peer totals are reported alongside the coverage of peers observed in
# both years. A separate matched-peer rate tests sensitivity to that composition.
peer_compare <- function(counts, cases, start, end, extra_exclusions = character()) {
  if (end - start < 2) stop("Comparisons must be at least two years apart.")
  if (!all(c(start, end) %in% counts$year)) stop("Comparison year absent.")
  a <- counts |> dplyr::filter(year == start) |>
    dplyr::select(precinct, industry, n_start = establishments)
  b <- counts |> dplyr::filter(year == end) |>
    dplyr::select(precinct, industry, n_end = establishments)
  joined <- dplyr::full_join(a, b, by = c("precinct", "industry"))
  dplyr::bind_rows(lapply(seq_len(nrow(cases)), function(i) {
    case <- cases[i, ]
    local <- joined |> dplyr::filter(precinct == case$precinct, industry == case$industry)
    if (nrow(local) > 1L) stop("Duplicate comparison key.")
    local_start <- if (nrow(local)) local$n_start else NA_real_
    local_end <- if (nrow(local)) local$n_end else NA_real_
    peers <- joined |> dplyr::filter(industry == case$industry,
      !precinct %in% c(case$precinct, extra_exclusions))
    observed_sum <- function(x) if (any(!is.na(x))) sum(x, na.rm = TRUE) else NA_real_
    p_start <- observed_sum(peers$n_start)
    p_end <- observed_sum(peers$n_end)
    matched <- !is.na(peers$n_start) & !is.na(peers$n_end)
    m_start <- if (any(matched)) sum(peers$n_start[matched]) else NA_real_
    m_end <- if (any(matched)) sum(peers$n_end[matched]) else NA_real_
    local_rate <- peer_rate(local_start, local_end)
    reference_rate <- peer_rate(p_start, p_end)
    benchmark <- if (is.finite(local_start) && local_start > 0 &&
      is.finite(reference_rate)) local_start * (1 + reference_rate / 100) else NA_real_
    data.frame(case_rank = case$case_rank, label = case$label,
      precinct = case$precinct, industry = case$industry,
      start_year = start, end_year = end, n_start = local_start, n_end = local_end,
      local_growth_pct = local_rate, peer_start = p_start, peer_end = p_end,
      peer_growth_pct = reference_rate, growth_gap_pp = local_rate - reference_rate,
      benchmark_end = benchmark, observed_minus_benchmark = local_end - benchmark,
      peer_cells_either_year = nrow(peers), peer_matched_cells = sum(matched),
      peer_matched_start = m_start, peer_matched_end = m_end,
      peer_start_coverage_pct = if (is.finite(p_start) && p_start > 0) 100 * m_start / p_start else NA_real_,
      peer_end_coverage_pct = if (is.finite(p_end) && p_end > 0) 100 * m_end / p_end else NA_real_,
      matched_peer_growth_pct = peer_rate(m_start, m_end),
      matched_growth_gap_pp = local_rate - peer_rate(m_start, m_end),
      extra_exclusions = paste(extra_exclusions, collapse = "; "),
      stringsAsFactors = FALSE)
  }))
}

peer_screen <- function(counts, baseline = 2019L) {
  required_years <- c(baseline, 2022L, 2024L)
  if (!all(required_years %in% counts$year)) stop("Screen year absent.")
  w <- counts |> dplyr::filter(year %in% required_years) |>
    tidyr::pivot_wider(names_from = year, values_from = establishments, names_prefix = "n_")
  w$baseline_year <- baseline
  w$n_baseline <- w[[paste0("n_", baseline)]]
  w$shortfall <- w$n_baseline - w$n_2024
  w$recent_change <- w$n_2024 - w$n_2022
  w$recent_pct <- peer_rate(w$n_2022, w$n_2024)
  w$complete <- !is.na(w$n_baseline) & !is.na(w$n_2022) & !is.na(w$n_2024)
  w$persistent_decline <- ifelse(w$complete, w$shortfall > 0 & w$recent_change < 0, NA)
  w
}

peer_select <- function(screen, threshold = 2) {
  if (length(threshold) != 1L || !is.finite(threshold) || threshold < 0)
    stop("Threshold must be a finite non-negative number.")
  eligible <- screen |> dplyr::filter(persistent_decline %in% TRUE) |>
    dplyr::arrange(dplyr::desc(shortfall), precinct, industry)
  scale <- eligible |> dplyr::filter(!is.na(recent_pct), recent_pct <= -threshold) |>
    dplyr::slice_head(n = 4L) |> dplyr::mutate(case_role = "Scale")
  contrast <- eligible |> dplyr::filter(precinct != "Melbourne (CBD)",
    industry == "Accommodation and Food Services") |>
    dplyr::slice_head(n = 1L) |> dplyr::mutate(case_role = "Contrast")
  # The hospitality contrast is deliberately selected independently of the
  # recent percentage cutoff. Report this separate purpose rather than imply
  # all five cases emerge from one ranking.
  dplyr::bind_rows(scale, contrast) |>
    dplyr::mutate(threshold_pct = threshold, case_rank = dplyr::row_number()) |>
    dplyr::select(baseline_year, threshold_pct, case_role, case_rank,
      precinct, industry, n_baseline, n_2022, n_2024, shortfall, recent_change, recent_pct)
}

peer_make_figures <- function(tables, folder) {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  navy <- "#23445A"; teal <- "#187F86"; orange <- "#B6533B"
  style <- ggplot2::theme_minimal(base_size = 12) + ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major.y = ggplot2::element_blank(),
    plot.title = ggplot2::element_text(face = "bold", colour = navy, size = 16),
    plot.subtitle = ggplot2::element_text(size = 11),
    plot.caption = ggplot2::element_text(hjust = 0, size = 9),
    legend.position = "top", legend.title = ggplot2::element_blank(),
    plot.margin = ggplot2::margin(12, 22, 12, 12))
  recent <- tables$peer_comparisons |> dplyr::filter(start_year == 2022L) |>
    dplyr::mutate(label = factor(label, levels = rev(label)))
  dots <- recent |> tidyr::pivot_longer(c(local_growth_pct, peer_growth_pct),
    names_to = "series", values_to = "rate") |>
    dplyr::mutate(series = factor(series, levels = c("local_growth_pct", "peer_growth_pct"),
      labels = c("Selected group", "Same industry elsewhere")))
  plot <- ggplot2::ggplot(recent, ggplot2::aes(y = label)) +
    ggplot2::geom_vline(xintercept = 0, colour = "#9DA9B0", linewidth = .4) +
    ggplot2::geom_segment(ggplot2::aes(x = local_growth_pct, xend = peer_growth_pct,
      yend = label), colour = "#BFC8CE", linewidth = 1.2) +
    ggplot2::geom_point(data = dots, ggplot2::aes(x = rate, colour = series, shape = series), size = 3.6) +
    ggplot2::geom_text(data = dots, ggplot2::aes(x = rate,
      label = sprintf("%+.1f%%", rate), colour = series,
      vjust = ifelse(series == "Selected group", 1.9, -1)), size = 3.6, show.legend = FALSE) +
    ggplot2::scale_colour_manual(values = c(orange, teal)) +
    ggplot2::scale_shape_manual(values = c(16, 17)) +
    ggplot2::scale_x_continuous(limits = c(-18, 18), breaks = seq(-15, 15, 5)) +
    ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = .65)) +
    ggplot2::labs(title = "Three selected groups declined while their peers grew",
      subtitle = "SME establishment growth, 2022 to 2024. Each reference excludes the selected precinct.",
      x = "Change in SME establishments (%)", y = NULL,
      caption = "Source: City of Melbourne CLUE. Small and Medium categories (1-199 jobs).\nPublished same-industry totals outside each focal precinct; descriptive comparison.") + style
  ggplot2::ggsave(file.path(folder, "recent_peer_comparison.png"), plot, width = 10, height = 5.5, dpi = 220)

  two <- tables$peer_comparisons |> dplyr::filter(start_year %in% c(2017L, 2022L)) |>
    dplyr::mutate(period = factor(paste(start_year, end_year, sep = " to "),
      levels = c("2017 to 2019", "2022 to 2024")),
      label = factor(label, levels = rev(unique(tables$peer_comparisons$label))))
  context <- ggplot2::ggplot(two, ggplot2::aes(growth_gap_pp, label)) +
    ggplot2::geom_vline(xintercept = 0, colour = "#8998A3", linetype = "dashed") +
    ggplot2::geom_segment(ggplot2::aes(x = 0, xend = growth_gap_pp, yend = label),
      colour = "#C7D0D6", linewidth = 1) +
    ggplot2::geom_point(ggplot2::aes(colour = growth_gap_pp < 0), size = 3.3) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%+.1f", growth_gap_pp),
      hjust = ifelse(growth_gap_pp < 0, 1.35, -.35)), size = 3.6) +
    ggplot2::facet_wrap(~period) +
    ggplot2::scale_colour_manual(values = c(teal, orange), guide = "none") +
    ggplot2::scale_x_continuous(limits = c(-38, 38), breaks = c(-30, 0, 30)) +
    ggplot2::labs(title = "Relative weakness has different histories",
      subtitle = "Local growth minus growth in the same industry elsewhere. Negative values indicate slower growth.",
      x = "Growth difference (percentage points)", y = NULL,
      caption = "Source: City of Melbourne CLUE. SME establishments. Two equal-length comparison windows.\nEach comparison uses the same industry outside the selected precinct.") + style
  ggplot2::ggsave(file.path(folder, "pre_recent_comparison.png"), context, width = 10, height = 5.2, dpi = 220)

  history <- tables$full_two_year_history |>
    dplyr::mutate(segment = ifelse(end_year <= 2019, "Before 2020", "Since 2020"))
  historical <- ggplot2::ggplot(history, ggplot2::aes(end_year, growth_gap_pp)) +
    ggplot2::geom_hline(yintercept = 0, colour = "#9DA9B0", linetype = "dashed") +
    ggplot2::geom_line(ggplot2::aes(group = segment), colour = navy, linewidth = .7) +
    ggplot2::geom_point(colour = navy, size = 1.8) +
    ggplot2::facet_wrap(~label, ncol = 2) +
    ggplot2::scale_x_continuous(breaks = c(2005, 2011, 2019, 2024)) +
    ggplot2::labs(title = "Relative growth varies across two-year windows",
      subtitle = "Eight two-year windows from 2003-2005 to 2017-2019, followed by 2020-2022 and 2022-2024.",
      x = "End year of two-year comparison", y = "Local minus peer growth (percentage points)",
      caption = "Source: City of Melbourne CLUE. Small and Medium establishments.\nThe series are descriptive; repeated group observations are not independent.") + style
  ggplot2::ggsave(file.path(folder, "full_two_year_history.png"), historical, width = 10, height = 8, dpi = 220)
  invisible(c("recent_peer_comparison.png", "pre_recent_comparison.png", "full_two_year_history.png"))
}

run_peer_review <- function(root = ".", make_figures = TRUE) {
  peer_required_packages(make_figures)
  data_path <- file.path(root, "data/business-establishments-and-jobs-data-by-business-size-and-anzsic.csv")
  original_hash <- unname(tools::md5sum(data_path))
  counts <- peer_read_counts(data_path)
  screens <- lapply(c(2018L, 2019L), function(year) peer_screen(counts, year))
  selected <- peer_select(screens[[2]], 2)
  # Explicit labels are joined to their keys; changed selection cannot silently
  # inherit the wrong case name if the input data are replaced in the future.
  expected_cases <- data.frame(
    precinct = c(rep("Melbourne (CBD)", 4), "Southbank"),
    industry = c("Professional, Scientific and Technical Services",
      "Financial and Insurance Services", "Administrative and Support Services",
      "Construction", "Accommodation and Food Services"),
    label = c("CBD professional services", "CBD finance and insurance",
      "CBD administrative services", "CBD construction", "Southbank hospitality"))
  cases <- selected |> dplyr::select(case_rank, precinct, industry) |>
    dplyr::left_join(expected_cases, by = c("precinct", "industry"))
  if (nrow(cases) != 5L || anyNA(cases$label)) stop("Case selection changed; review labels and report.")
  periods <- list(c(2017L, 2019L), c(2019L, 2024L), c(2022L, 2024L))
  comparisons <- dplyr::bind_rows(lapply(periods, function(p) peer_compare(counts, cases, p[1], p[2])))
  # Odd-year pre-periods retain the chosen 2017-2019 reference window. We also
  # export the even-year scheme so a single choice of survey-cycle alignment
  # cannot be mistaken for evidence of a permanent local trend.
  history <- dplyr::bind_rows(lapply(c(seq(2003L, 2017L, 2L), 2020L, 2022L),
    function(y) peer_compare(counts, cases, y, y + 2L)))
  even_history <- dplyr::bind_rows(lapply(seq(2002L, 2022L, 2L),
    function(y) peer_compare(counts, cases, y, y + 2L)))
  history_summary <- history |> dplyr::filter(end_year <= 2019L) |>
    dplyr::group_by(case_rank, label, precinct, industry) |>
    dplyr::summarise(pre_windows = sum(!is.na(growth_gap_pp)),
      pre_windows_below_peers = sum(growth_gap_pp < 0, na.rm = TRUE),
      minimum_gap_pp = min(growth_gap_pp, na.rm = TRUE),
      maximum_gap_pp = max(growth_gap_pp, na.rm = TRUE), .groups = "drop")
  sensitivity <- dplyr::bind_rows(lapply(screens, function(s)
    dplyr::bind_rows(lapply(c(0, 1, 2, 3, 5), function(t) peer_select(s, t)))))
  baseline <- dplyr::bind_rows(lapply(screens, function(s) {
    dplyr::left_join(cases, s, by = c("precinct", "industry")) |>
      dplyr::select(case_rank, label, precinct, industry, baseline_year,
        n_baseline, n_2022, n_2024, shortfall, recent_change, recent_pct, persistent_decline) |>
      dplyr::mutate(baseline_change_pct = peer_rate(n_baseline, n_2024))
  }))
  baseline_selection <- sensitivity |> dplyr::filter(threshold_pct == 2)
  southbank <- cases |> dplyr::filter(precinct == "Southbank")
  hospitality <- dplyr::bind_rows(
    peer_compare(counts, southbank, 2022, 2024) |> dplyr::mutate(reference = "Other precincts"),
    peer_compare(counts, southbank, 2022, 2024, "Melbourne (CBD)") |>
      dplyr::mutate(reference = "Other precincts excluding CBD"))
  key <- function(x) paste(x$precinct, x$industry, sep = " | ")
  original_scale <- selected |> dplyr::filter(case_role == "Scale")
  stability <- sensitivity |> dplyr::filter(case_role == "Scale") |>
    dplyr::group_by(baseline_year, threshold_pct) |>
    dplyr::summarise(selected_scale_cases = dplyr::n(),
      original_scale_cases_retained = sum(paste(precinct, industry, sep = " | ") %in% key(original_scale)),
      same_scale_set_as_2019_two_percent = setequal(paste(precinct, industry, sep = " | "), key(original_scale)),
      .groups = "drop")
  tables <- list(peer_comparisons = comparisons, selected_cases = selected,
    threshold_sensitivity = sensitivity, threshold_stability = stability,
    baseline_sensitivity = baseline, baseline_case_selection = baseline_selection,
    full_two_year_history = history, alternate_even_year_history = even_history,
    history_summary = history_summary, hospitality_reference_sensitivity = hospitality)
  summary <- list(source_file = basename(data_path), source_md5 = original_hash,
    scope = "Small and Medium establishments, 1-199 jobs",
    selected_case_shortfall_2019 = sum(selected$shortfall),
    selected_case_recent_change = sum(selected$recent_change),
    recent_cases_below_peers = sum(comparisons$growth_gap_pp[comparisons$start_year == 2022] < 0),
    recent_comparisons = comparisons |>
      dplyr::filter(start_year == 2022) |>
      dplyr::select(label, n_start, n_end, local_growth_pct, peer_growth_pct,
        growth_gap_pp, benchmark_end, observed_minus_benchmark, matched_peer_growth_pct),
    threshold_stability = stability,
    baseline_case_selection = baseline_selection |>
      dplyr::select(baseline_year, case_role, case_rank, precinct, industry),
    history_summary = history_summary,
    note = "Comparisons are descriptive. The reference is observed industry growth outside the selected precinct, not a causal counterfactual or future forecast.")
  out <- file.path(root, "outputs/tables/final/deeper_review")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  for (name in names(tables)) readr::write_csv(tables[[name]], file.path(out, paste0(name, ".csv")), na = "NA")
  jsonlite::write_json(summary, file.path(out, "results_summary.json"), pretty = TRUE,
    auto_unbox = TRUE, na = "null", digits = NA)
  writeLines(capture.output(sessionInfo()), file.path(out, "session_info.txt"))
  if (make_figures) peer_make_figures(tables, file.path(root, "outputs/figures/final/deeper_review"))
  if (!identical(original_hash, unname(tools::md5sum(data_path)))) stop("Raw source changed.")
  invisible(list(tables = tables, summary = summary))
}

if (sys.nframe() == 0L) {
  script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  root <- normalizePath(file.path(dirname(script), ".."))
  if (length(commandArgs(trailingOnly = TRUE))) stop("This script takes no arguments.")
  options(warn = 2)
  result <- run_peer_review(root)
  cat("PASS: peer comparisons, history, threshold and baseline checks exported.\n")
  print(result$tables$threshold_stability)
}
