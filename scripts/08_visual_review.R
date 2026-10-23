# Report figures built from the same checked SME counts as the analysis.
# Run from the repository root: Rscript scripts/08_visual_review.R
# This script writes new review outputs; it never changes raw data.

visual_required_packages <- function() {
  packages <- c("dplyr", "tidyr", "readr", "ggplot2", "scales", "ragg", "jsonlite")
  absent <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent)) stop("Missing packages: ", paste(absent, collapse = ", "))
}

visual_tables <- function(root = ".") {
  source(file.path(root, "scripts/07_peer_comparison_review.R"), local = TRUE)
  counts <- peer_read_counts(file.path(root,
    "data/business-establishments-and-jobs-data-by-business-size-and-anzsic.csv"))
  screened <- peer_screen(counts) |> dplyr::filter(persistent_decline %in% TRUE) |>
    dplyr::arrange(dplyr::desc(shortfall), precinct, industry) |>
    dplyr::mutate(case_rank = dplyr::row_number(), label = paste(precinct, industry))
  selected <- readr::read_csv(file.path(root,
    "outputs/tables/final/deeper_review/peer_comparisons.csv"), show_col_types = FALSE) |>
    dplyr::filter(start_year == 2022L) |>
    dplyr::select(precinct, industry, selected_rank = case_rank, selected_label = label)
  all_peers <- peer_compare(counts, screened, 2022L, 2024L) |>
    dplyr::left_join(screened |> dplyr::select(precinct, industry, n_2019, shortfall),
                    by = c("precinct", "industry")) |>
    dplyr::left_join(selected, by = c("precinct", "industry")) |>
    dplyr::mutate(highlight = !is.na(selected_rank),
                  # Retain matched-peer diagnostics; they are not silently substituted.
                  peer_gap_difference_pp = growth_gap_pp - matched_growth_gap_pp,
                  coverage_sensitive = sign(growth_gap_pp) != sign(matched_growth_gap_pp))
  if (nrow(all_peers) != 64L || sum(all_peers$highlight) != 5L)
    stop("Priority screen changed; review the chart and report.")
  recent <- all_peers |> dplyr::filter(highlight) |> dplyr::arrange(selected_rank)
  history <- readr::read_csv(file.path(root,
    "outputs/tables/final/deeper_review/peer_comparisons.csv"), show_col_types = FALSE) |>
    dplyr::filter(start_year %in% c(2017L, 2022L))
  city <- counts |> dplyr::filter(year %in% c(2019L, 2022L, 2024L)) |>
    dplyr::group_by(year) |>
    dplyr::summarise(establishments = sum(establishments), .groups = "drop")
  precinct <- readr::read_csv(file.path(root,
    "outputs/tables/final/descriptive/precinct_changes.csv"), show_col_types = FALSE) |>
    dplyr::filter(start_year %in% c(2019L, 2022L), end_year == 2024L)

  # Keep the complete 13 x 19 grid. An absent record stays unknown, not zero.
  heat <- tidyr::expand_grid(precinct = sort(unique(counts$precinct)),
                             industry = sort(unique(counts$industry))) |>
    dplyr::left_join(counts |> dplyr::filter(year == 2022L) |>
      dplyr::select(precinct, industry, n_2022 = establishments),
      by = c("precinct", "industry")) |>
    dplyr::left_join(counts |> dplyr::filter(year == 2024L) |>
      dplyr::select(precinct, industry, n_2024 = establishments),
      by = c("precinct", "industry")) |>
    dplyr::mutate(change = n_2024 - n_2022,
      growth_pct = peer_rate(n_2022, n_2024),
      display_status = dplyr::case_when(
        is.na(n_2022) | is.na(n_2024) ~ "Unknown in at least one year",
        n_2022 < 20 ~ "Starting count below 20",
        TRUE ~ "Percentage displayed"),
      display_growth_pct = ifelse(display_status == "Percentage displayed", growth_pct, NA_real_))
  list(priority_map = all_peers, recent_peer = recent, pre_recent_peer = history,
       city_recovery = city, precinct_changes = precinct, industry_heatmap = heat)
}

visual_grob_labels <- function(grob) {
  # Text grobs are the rendered label objects, including axes and legends.
  # Preserve repetitions: the word budget counts every displayed occurrence.
  here <- if (inherits(grob, "text")) as.character(grob$label) else character()
  nested <- c(if (!is.null(grob$grobs)) grob$grobs else list(),
              if (!is.null(grob$children)) as.list(grob$children) else list())
  c(here, unlist(lapply(nested, visual_grob_labels), use.names = FALSE))
}

visual_figures <- function(tables, folder, text_folder = NULL) {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  teal <- "#147D83"; terra <- "#B65B43"; ink <- "#263238"; grey <- "#B9BEC0"
  base <- ggplot2::theme_minimal(base_size = 12, base_family = "Arial") +
    ggplot2::theme(text = ggplot2::element_text(colour = ink),
      plot.title = ggplot2::element_text(size = 17, face = "bold", margin = ggplot2::margin(b = 7)),
      plot.subtitle = ggplot2::element_text(size = 11, margin = ggplot2::margin(b = 12)),
      plot.caption = ggplot2::element_text(size = 9, hjust = 0, margin = ggplot2::margin(t = 12)),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "#E8EBEC", linewidth = .35),
      axis.title = ggplot2::element_text(size = 11),
      axis.text = ggplot2::element_text(colour = ink),
      legend.position = "top", legend.title = ggplot2::element_blank(),
      plot.title.position = "plot", plot.caption.position = "plot",
      plot.margin = ggplot2::margin(13, 16, 13, 13))
  figure_text <- list()
  save <- function(name, plot, width, height) {
    # Use the same font-aware device for text measurement as PNG rendering.
    ragg::agg_capture(width = width, height = height, units = "in", res = 300)
    labels <- visual_grob_labels(ggplot2::ggplotGrob(plot))
    grDevices::dev.off()
    words <- unlist(strsplit(paste(labels, collapse = " "), "[[:space:]]+"))
    words <- words[nzchar(words)]
    figure_text[[name]] <<- list(labels = labels, whitespace_token_count = length(words))
    ggplot2::ggsave(file.path(folder, paste0(name, ".png")), plot,
      device = ragg::agg_png, width = width, height = height, units = "in", dpi = 300,
      bg = "white")
  }
  source_note <- "Source: City of Melbourne CLUE. Small and Medium establishments (1–199 jobs)."

  city <- tables$city_recovery
  segments <- data.frame(x = c(2019, 2022), xend = c(2022, 2024),
    y = city$establishments[1:2], yend = city$establishments[2:3],
    direction = c("Decline", "Recovery"))
  city_plot <- ggplot2::ggplot(city, ggplot2::aes(year, establishments)) +
    ggplot2::geom_hline(yintercept = 15506, colour = grey, linetype = "dashed", linewidth = .5) +
    ggplot2::geom_segment(data = segments,
      ggplot2::aes(x = x, y = y, xend = xend, yend = yend, colour = direction),
      inherit.aes = FALSE, linewidth = 1.4, show.legend = FALSE) +
    ggplot2::geom_point(size = 4, colour = ink) +
    ggplot2::geom_text(ggplot2::aes(label = scales::comma(establishments)),
      vjust = -1, size = 4.4, fontface = "bold", family = "Arial") +
    ggplot2::annotate("text", x = 2020.35, y = 13630, label = "−2,935", colour = terra,
      family = "Arial", fontface = "bold", size = 4.7) +
    ggplot2::annotate("text", x = 2023.05, y = 12440, label = "+483", colour = teal,
      family = "Arial", fontface = "bold", size = 4.7) +
    ggplot2::scale_colour_manual(values = c(Decline = terra, Recovery = teal)) +
    ggplot2::scale_x_continuous(breaks = c(2019, 2022, 2024), limits = c(2018.7, 2024.3)) +
    ggplot2::scale_y_continuous(breaks = seq(12000, 16000, 1000), labels = scales::comma,
      limits = c(12000, 16100)) +
    ggplot2::labs(title = "Recovery has replaced one-sixth of the earlier loss",
      subtitle = "City-wide SME establishments | 2019, 2022 and 2024",
      x = NULL, y = "SME establishments", caption = source_note) + base +
    ggplot2::theme(panel.grid.major.x = ggplot2::element_blank())
  save("city_recovery", city_plot, 9.4, 4.65)

  # Label positions are explicit so the five selected cases remain legible in print.
  highlights <- tables$priority_map |> dplyr::filter(highlight) |>
    dplyr::arrange(selected_rank) |>
    dplyr::mutate(label_x = c(362, 285, 252, 130, 127),
      label_y = c(-19, 21, -6, -39, -17),
      direct_label = c("CBD professional services", "CBD finance", "CBD administrative services",
                       "CBD construction", "Southbank hospitality"),
      relative = ifelse(growth_gap_pp < 0, "Below peers", "Above peers"))
  bubble <- ggplot2::ggplot(tables$priority_map,
      ggplot2::aes(shortfall, growth_gap_pp)) +
    ggplot2::geom_hline(yintercept = 0, colour = "#869195", linewidth = .55) +
    ggplot2::geom_point(ggplot2::aes(size = n_end), shape = 21,
      fill = "#C9CDCE", colour = "white", stroke = .3, alpha = .65) +
    ggplot2::geom_point(data = tables$priority_map |> dplyr::filter(coverage_sensitive),
      ggplot2::aes(size = n_end), shape = 21, fill = "white", colour = "#7C8588", stroke = .7,
      show.legend = FALSE) +
    ggplot2::geom_point(data = highlights, ggplot2::aes(size = n_end, fill = relative),
      shape = 21, colour = "white", stroke = .8) +
    ggplot2::geom_segment(data = highlights,
      ggplot2::aes(xend = label_x,
        yend = label_y + ifelse(label_y < growth_gap_pp, 3, -3)),
      colour = "#7C8588", linewidth = .35) +
    ggplot2::geom_text(data = highlights, ggplot2::aes(x = label_x, y = label_y,
      label = direct_label, colour = relative), family = "Arial", fontface = "bold", size = 3.65) +
    ggplot2::scale_fill_manual(values = c("Below peers" = terra, "Above peers" = teal), guide = "none") +
    ggplot2::scale_colour_manual(values = c("Below peers" = terra, "Above peers" = teal), guide = "none") +
    ggplot2::scale_size_area(max_size = 15, breaks = c(100, 500, 1000),
      name = "2024 SME count", labels = scales::comma) +
    ggplot2::scale_x_continuous(breaks = seq(0, 500, 100), limits = c(-10, 520)) +
    ggplot2::scale_y_continuous(breaks = seq(-75, 50, 25), limits = c(-80, 52)) +
    ggplot2::labs(title = "Historical losses and peer comparisons point to different priorities",
      subtitle = "64 groups below both 2019 and 2022 counts | Five report cases highlighted",
      x = "Establishments below the 2019 count",
      y = "2022–2024 growth relative to peers (percentage points)",
      caption = paste(source_note,
        "Peers: the same industry outside each precinct. Below zero = slower growth than peers.",
        "Hollow marker: peer coverage changes the comparison.", sep = "\n")) +
    base + ggplot2::theme(legend.title = ggplot2::element_text(size = 10),
      legend.position = "top", legend.justification = "left")
  save("priority_bubble", bubble, 10, 5.55)

  recent <- tables$recent_peer |>
    dplyr::mutate(label = factor(selected_label, levels = rev(selected_label)))
  dots <- recent |> tidyr::pivot_longer(c(local_growth_pct, peer_growth_pct),
    names_to = "series", values_to = "rate") |>
    dplyr::mutate(series = factor(series, levels = c("local_growth_pct", "peer_growth_pct"),
      labels = c("Selected group", "Same industry elsewhere")))
  peers <- ggplot2::ggplot(recent, ggplot2::aes(y = label)) +
    ggplot2::geom_vline(xintercept = 0, colour = "#9DA9B0", linewidth = .5) +
    ggplot2::geom_segment(ggplot2::aes(x = local_growth_pct, xend = peer_growth_pct, yend = label),
      colour = "#CCD1D3", linewidth = 1) +
    ggplot2::geom_point(data = dots, ggplot2::aes(x = rate, colour = series, shape = series), size = 3.6) +
    ggplot2::geom_text(data = dots, ggplot2::aes(x = rate, label = sprintf("%+.1f%%", rate),
      colour = series, vjust = ifelse(series == "Selected group", 1.9, -1)),
      family = "Arial", size = 3.6, show.legend = FALSE) +
    ggplot2::scale_colour_manual(values = c(terra, teal)) +
    ggplot2::scale_shape_manual(values = c(16, 17)) +
    ggplot2::scale_x_continuous(limits = c(-18, 18), breaks = seq(-15, 15, 5)) +
    ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = .65)) +
    ggplot2::labs(title = "Three selected groups declined while their peers grew",
      subtitle = "SME establishment growth | 2022–2024", x = "Change in SME establishments (%)", y = NULL,
      caption = paste(source_note, "Each reference excludes the selected precinct.", sep = "\n")) + base +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())
  save("recent_peer_comparison", peers, 10, 5.35)

  hist <- tables$pre_recent_peer |> dplyr::mutate(
    period = factor(paste(start_year, end_year, sep = "–"), levels = c("2017–2019", "2022–2024")),
    label = factor(label, levels = rev(unique(label))))
  pre_recent <- ggplot2::ggplot(hist, ggplot2::aes(growth_gap_pp, label)) +
    ggplot2::geom_vline(xintercept = 0, colour = "#8998A3", linetype = "dashed") +
    ggplot2::geom_segment(ggplot2::aes(x = 0, xend = growth_gap_pp, yend = label), colour = "#C7D0D6") +
    ggplot2::geom_point(ggplot2::aes(colour = growth_gap_pp < 0), size = 3.3) +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%+.1f", growth_gap_pp),
      hjust = ifelse(growth_gap_pp < 0, 1.35, -.35)), family = "Arial", size = 3.6) +
    ggplot2::facet_wrap(~period) +
    ggplot2::scale_colour_manual(values = c(teal, terra), guide = "none") +
    ggplot2::scale_x_continuous(limits = c(-38, 38), breaks = c(-30, 0, 30)) +
    ggplot2::labs(title = "Similar recent weakness can follow different earlier paths",
      subtitle = "Local growth minus same-industry growth outside the precinct",
      x = "Growth difference (percentage points)", y = NULL,
      caption = paste(source_note, "Two equal-length comparison windows.", sep = "\n")) + base +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank(), strip.text = ggplot2::element_text(face = "bold"))
  save("pre_recent_comparison", pre_recent, 10, 5.15)

  precinct <- tables$precinct_changes |>
    dplyr::mutate(period = factor(paste(start_year, end_year, sep = "–"),
      levels = c("2019–2024", "2022–2024")),
      precinct = factor(precinct, levels = rev(sort(unique(precinct)))))
  precinct_plot <- ggplot2::ggplot(precinct, ggplot2::aes(pct_change_display, precinct)) +
    ggplot2::geom_vline(xintercept = 0, colour = "#8998A3", linewidth = .5) +
    ggplot2::geom_segment(data = precinct |> dplyr::filter(!is.na(pct_change_display)),
      ggplot2::aes(x = 0, xend = pct_change_display, yend = precinct), colour = "#C7D0D6", linewidth = .8) +
    ggplot2::geom_point(data = precinct |> dplyr::filter(!is.na(pct_change_display)),
      ggplot2::aes(colour = pct_change_display >= 0), size = 2.8) +
    ggplot2::geom_text(data = precinct |> dplyr::filter(!is.na(pct_change_display)),
      ggplot2::aes(label = sprintf("%+.1f%%", pct_change_display),
        hjust = ifelse(pct_change_display < 0, 1.25, -.25)), family = "Arial", size = 3.35) +
    ggplot2::geom_text(data = precinct |> dplyr::filter(is.na(pct_change_display)),
      ggplot2::aes(x = 0), label = "base <100", colour = "#7B8386", family = "Arial", size = 3) +
    ggplot2::scale_colour_manual(values = c(terra, teal), guide = "none") +
    ggplot2::facet_wrap(~period) +
    ggplot2::scale_y_discrete(drop = FALSE) +
    ggplot2::scale_x_continuous(limits = c(-29, 29), breaks = c(-20, 0, 20)) +
    ggplot2::labs(title = "Eight precincts grew recently; all remain below 2019",
      subtitle = "SME establishment change by precinct", x = "Change (%)", y = NULL,
      caption = paste(source_note, "Percentages withheld where the starting precinct count is below 100.", sep = "\n")) + base +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank(), strip.text = ggplot2::element_text(face = "bold"))
  save("precinct_changes", precinct_plot, 10, 6.7)

  # Division labels follow the source's 19 ANZSIC divisions; shorter display
  # names keep the entire matrix readable without changing category membership.
  industries <- c("Agriculture, Forestry and Fishing", "Mining", "Manufacturing",
    "Electricity, Gas, Water and Waste Services", "Construction", "Wholesale Trade",
    "Retail Trade", "Accommodation and Food Services", "Transport, Postal and Warehousing",
    "Information Media and Telecommunications", "Financial and Insurance Services",
    "Rental, Hiring and Real Estate Services", "Professional, Scientific and Technical Services",
    "Administrative and Support Services", "Public Administration and Safety",
    "Education and Training", "Health Care and Social Assistance", "Arts and Recreation Services", "Other Services")
  short <- c("Agriculture", "Mining", "Manufacturing", "Utilities", "Construction", "Wholesale",
    "Retail", "Hospitality", "Transport", "Information/media", "Finance/insurance", "Rental/property",
    "Professional", "Administrative", "Public administration", "Education", "Health care", "Arts/recreation", "Other services")
  heat <- tables$industry_heatmap |> dplyr::mutate(
    industry_label = factor(industry, levels = industries, labels = short),
    precinct = factor(precinct, levels = rev(sort(unique(precinct)))),
    cell_label = dplyr::case_when(display_status == "Unknown in at least one year" ~ "×",
      display_status == "Starting count below 20" ~ "·", TRUE ~ sprintf("%+.0f", growth_pct)),
    text_colour = ifelse(!is.na(display_growth_pct) & abs(display_growth_pct) > 20, "white", ink))
  hm <- ggplot2::ggplot(heat, ggplot2::aes(industry_label, precinct)) +
    ggplot2::geom_tile(ggplot2::aes(fill = display_growth_pct), colour = "white", linewidth = .7) +
    ggplot2::geom_text(ggplot2::aes(label = cell_label, colour = text_colour), family = "Arial", size = 3.2) +
    ggplot2::scale_colour_identity() +
    ggplot2::scale_fill_gradient2(low = terra, mid = "#FAFAF8", high = teal, midpoint = 0,
      limits = c(-30, 30), oob = scales::squish, na.value = "#ECEEED", breaks = c(-30,-15,0,15,30),
      labels = c("≤−30%", "−15%", "0%", "+15%", "≥+30%")) +
    ggplot2::labs(title = "Recovery varies within industries as well as across precincts",
      subtitle = "SME establishment change, 2022–2024 (%) | All 13 precincts and 19 industry divisions",
      x = NULL, y = NULL,
      caption = paste(source_note,
        "Cell labels show rounded percentages. × = unknown in at least one year; · = starting count below 20 (percentage withheld).",
        "Colour scale is capped at ±30%; labels retain the full value. The display threshold does not alter the analysis sample.", sep = "\n")) +
    base + ggplot2::theme(panel.grid = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(angle = 55, hjust = 1, size = 10.5),
      axis.text.y = ggplot2::element_text(size = 11), legend.position = "top",
      legend.key.width = grid::unit(1.5, "cm"), legend.key.height = grid::unit(.3, "cm"),
      plot.margin = ggplot2::margin(13, 15, 13, 13))
  save("industry_heatmap", hm, 12, 6.35)
  if (!is.null(text_folder)) {
    dir.create(text_folder, recursive = TRUE, showWarnings = FALSE)
    jsonlite::write_json(list(
      method = "All rendered text grob labels, preserving repetitions; tokens split on whitespace, including numbers and standalone symbols.",
      total_whitespace_tokens = sum(vapply(figure_text, function(x) x$whitespace_token_count, integer(1))),
      figures = figure_text), file.path(text_folder, "figure_text_counts.json"),
      pretty = TRUE, auto_unbox = TRUE)
  }
  invisible(NULL)
}

run_visual_review <- function(root = ".", make_figures = TRUE) {
  visual_required_packages()
  raw <- file.path(root, "data/business-establishments-and-jobs-data-by-business-size-and-anzsic.csv")
  before <- unname(tools::md5sum(raw))
  tables <- visual_tables(root)
  folder <- file.path(root, "outputs/tables/final/visual_review")
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  for (name in names(tables)) readr::write_csv(tables[[name]], file.path(folder, paste0(name, ".csv")), na = "NA")
  summary <- list(source_md5 = before, priority_groups = nrow(tables$priority_map),
    highlighted_cases = sum(tables$priority_map$highlight),
    heatmap_cells = nrow(tables$industry_heatmap),
    heatmap_status = as.list(table(tables$industry_heatmap$display_status)),
    peer_comparisons_with_unmatched_cells = sum(tables$priority_map$peer_cells_either_year != tables$priority_map$peer_matched_cells),
    coverage_sensitive_comparisons = sum(tables$priority_map$coverage_sensitive),
    max_absolute_matched_peer_gap_difference_pp = max(abs(tables$priority_map$peer_gap_difference_pp)),
    figure_note = "The bubble area represents 2024 count. Peer gap is descriptive, not a causal effect.")
  jsonlite::write_json(summary, file.path(folder, "visual_summary.json"), pretty = TRUE, auto_unbox = TRUE)
  if (make_figures) visual_figures(tables, file.path(root, "outputs/figures/final/visual_review"),
                                  text_folder = folder)
  if (!identical(before, unname(tools::md5sum(raw)))) stop("Raw data changed.")
  invisible(tables)
}

if (sys.nframe() == 0L) {
  script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  root <- normalizePath(file.path(dirname(script), ".."))
  options(warn = 2)
  run_visual_review(root)
  cat("PASS: six visual-review figures and their source tables exported.\n")
}
