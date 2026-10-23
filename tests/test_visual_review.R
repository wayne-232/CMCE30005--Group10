# Independent checks on the visual-review exports and their display rules.
# Run from the repository root: Rscript tests/test_visual_review.R

source("scripts/08_visual_review.R")
source("scripts/07_peer_comparison_review.R")
visual_required_packages()
raw_path <- "data/business-establishments-and-jobs-data-by-business-size-and-anzsic.csv"
original_hash <- unname(tools::md5sum(raw_path))
t <- visual_tables(".")
checks <- 0L
check <- function(ok, message) {
  if (!isTRUE(ok)) stop(message)
  checks <<- checks + 1L
}
same <- function(a, b, tolerance = 1e-8) isTRUE(all.equal(a, b, tolerance = tolerance,
                                                       check.attributes = FALSE))
key <- function(x) paste(x$precinct, x$industry, sep = "|")
counts <- peer_read_counts(raw_path)
screen <- peer_screen(counts) |> dplyr::filter(persistent_decline %in% TRUE)
check(nrow(t$priority_map) == 64L, "Expected 64 screened groups")
check(setequal(key(t$priority_map), key(screen)), "Bubble membership differs from screen")
check(!anyDuplicated(key(t$priority_map)), "Duplicate priority keys")
check(sum(t$priority_map$highlight) == 5L, "Expected five highlighted cases")
check(all(t$priority_map$shortfall > 0), "Priority x must be a positive shortfall")
check(all(t$priority_map$n_end < t$priority_map$n_start), "Every screened group must decline recently")
check(same(t$priority_map$shortfall, t$priority_map$n_2019 - t$priority_map$n_end), "Shortfall arithmetic")
check(same(t$priority_map$growth_gap_pp,
           t$priority_map$local_growth_pct - t$priority_map$peer_growth_pct), "Peer-gap arithmetic")
check(all(is.finite(t$priority_map$growth_gap_pp)), "Unknown peer gap cannot be plotted")
check(min(t$priority_map$growth_gap_pp) > -80 && max(t$priority_map$growth_gap_pp) < 52,
      "Bubble limits would hide data")
check(sum(t$priority_map$growth_gap_pp > 0) == 3L, "Unexpected groups above peers")
check(all(t$priority_map$n_end > 0), "Zero-sized bubbles need an explicit display rule")

# Independently sum all other precincts, never including the focal group.
for (i in seq_len(nrow(t$priority_map))) {
  r <- t$priority_map[i, ]
  elsewhere <- counts |> dplyr::filter(industry == r$industry, precinct != r$precinct)
  a <- sum(elsewhere$establishments[elsewhere$year == 2022])
  b <- sum(elsewhere$establishments[elsewhere$year == 2024])
  check(same(r$peer_start, a) && same(r$peer_end, b), paste("Peer totals:", key(r)))
}
expected <- c(-6.056156, 6.684009, 3.456790, -27.402402, -13.702140)
check(same(t$recent_peer$growth_gap_pp, expected, 1e-6), "Five case peer gaps changed")
check(sum(t$priority_map$coverage_sensitive) == 1L &&
      t$priority_map$industry[t$priority_map$coverage_sensitive] == "Mining",
      "Coverage-sensitive point needs review")
check(!any(t$recent_peer$coverage_sensitive), "Highlighted case directions sensitive to coverage")
check(sum(t$recent_peer$shortfall) == 876, "Five-case historical shortfall")
check(sum(t$recent_peer$n_end - t$recent_peer$n_start) == -114, "Five-case recent loss")
check(same(t$city_recovery$establishments, c(15506, 12571, 13054)), "City totals")
check(t$city_recovery$establishments[3] - t$city_recovery$establishments[2] == 483,
      "City recovery")

heat <- t$industry_heatmap
check(nrow(heat) == 13L * 19L, "Heatmap grid is not 13 by 19")
check(!anyDuplicated(key(heat)), "Duplicate heatmap keys")
check(length(unique(heat$precinct)) == 13L && length(unique(heat$industry)) == 19L,
      "Missing heatmap categories")
check(sum(heat$display_status == "Percentage displayed") == 91L, "Expected 91 coloured cells")
check(sum(heat$display_status == "Starting count below 20") == 117L, "Expected 117 small-base cells")
check(sum(heat$display_status == "Unknown in at least one year") == 39L, "Expected 39 unavailable cells")
check(all(is.na(heat$display_growth_pct[heat$display_status != "Percentage displayed"])),
      "Unknown/small-base percentages leaked into colour scale")
check(all(heat$n_2022[heat$display_status == "Percentage displayed"] >= 20), "Small-base display rule")
check(all(is.na(heat$change[is.na(heat$n_2022) | is.na(heat$n_2024)])), "Missing values replaced with zero")
check(same(heat$growth_pct, peer_rate(heat$n_2022, heat$n_2024)), "Heatmap growth arithmetic")
check(!any(heat$n_2022 == 0, na.rm = TRUE), "Zero-base groups need explicit testing")
check(same(sum(heat$n_2022, na.rm = TRUE), 12571) &&
      same(sum(heat$n_2024, na.rm = TRUE), 13054), "Heatmap source totals")
check(all(t$precinct_changes$small_baseline == is.na(t$precinct_changes$pct_change_display)),
      "Precinct small-base rule")
check(nrow(t$precinct_changes) == 26L &&
      setequal(t$precinct_changes$start_year, c(2019L, 2022L)) &&
      all(t$precinct_changes$end_year == 2024L), "Precinct chart comparison periods")
check(identical(original_hash, unname(tools::md5sum(raw_path))), "Raw data changed")
cat(sprintf("PASS: %d visual-review checks.\n", checks))
