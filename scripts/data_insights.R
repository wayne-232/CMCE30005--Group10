# Data insights for the final report (Wayne: data description and descriptive results).
# Drafted with Anthropic Claude (2026). See docs/AI_ASSISTANCE.md.
# Adds four views that answer the tutor feedback on the interim report and final
# presentation:
#   1. Which SMEs make up the remaining gap? (Small 1-19 jobs vs Medium 20-199 jobs)
#   2. What does the data look like? (distribution of precinct-industry group sizes)
#   3. Does "Vacant Space" carry information? (share of address-file records)
#   4. For the five review cases, did jobs fall with establishments? (contraction vs consolidation)
#
# Run from the repository root:  Rscript scripts/data_insights.R
# Reads the two supplied CSVs, never modifies them, and writes to
# outputs/tables/final/insights/. Main population: Small + Medium (1-199 jobs).

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(ggplot2); library(scales)
})
if (!file.exists("scripts/analysis_helpers.R")) stop("Run from the repository root.")

agg_path <- "data/business-establishments-and-jobs-data-by-business-size-and-anzsic.csv"
addr_path <- "data/business-establishments-with-address-and-industry-classification.csv"
out_dir <- "outputs/tables/final/insights"
fig_dir <- file.path(out_dir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
hash_before <- tools::md5sum(c(agg_path, addr_path))

check <- function(ok, what) if (!isTRUE(ok)) stop("FAIL: ", what) else invisible(TRUE)
pct <- function(new, old) ifelse(is.finite(old) & old > 0, 100 * (new - old) / old, NA_real_)
key_years <- c(2019L, 2022L, 2024L)

# ---------------------------------------------------------------------------
# Load the aggregated file (positional names: the source header has a BOM and a
# misspelt "indusrty" column).
raw <- read_csv(agg_path, show_col_types = FALSE,
                col_types = cols(.default = col_character()))
names(raw) <- c("year", "precinct", "industry", "size", "establishments", "jobs")
raw <- raw |>
  mutate(year = as.integer(year), establishments = as.numeric(establishments),
         jobs = as.numeric(jobs))
check(nrow(raw) == 13353L, "aggregated file has 13,353 rows")

sme <- raw |>
  filter(size %in% c("Small business", "Medium business"), year >= 2002L, year <= 2024L) |>
  mutate(size = factor(size, levels = c("Small business", "Medium business"),
                       labels = c("Small (1-19 jobs)", "Medium (20-199 jobs)")))

# ---------------------------------------------------------------------------
# 1. Size-class split of the SME total
size_yearly <- sme |>
  group_by(year, size) |>
  summarise(establishments = sum(establishments), .groups = "drop") |>
  group_by(size) |>
  mutate(index_2019 = 100 * establishments / establishments[year == 2019L]) |>
  ungroup()

city_check <- size_yearly |> group_by(year) |> summarise(total = sum(establishments))
check(city_check$total[city_check$year == 2019L] == 15506, "2019 SME total reconciles")
check(city_check$total[city_check$year == 2024L] == 13054, "2024 SME total reconciles")

size_comparison <- sme |>
  filter(year %in% key_years) |>
  mutate(area = if_else(precinct == "Melbourne (CBD)", "Melbourne (CBD)", "Rest of city")) |>
  bind_rows(mutate(filter(sme, year %in% key_years), area = "City of Melbourne")) |>
  group_by(area, size, year) |>
  summarise(establishments = sum(establishments), .groups = "drop") |>
  pivot_wider(names_from = year, values_from = establishments, names_prefix = "n_") |>
  mutate(gap_2019_2024 = n_2024 - n_2019, pct_gap = pct(n_2024, n_2019),
         recent_2022_2024 = n_2024 - n_2022, pct_recent = pct(n_2024, n_2022)) |>
  group_by(area) |>
  mutate(share_of_area_gap = 100 * gap_2019_2024 / sum(gap_2019_2024)) |>
  ungroup()

# Jobs are suppressed only in cells with 1-2 establishments, so reported jobs
# cover about 99% of SME establishments. We use them as a supporting indicator.
jobs_coverage <- sme |>
  group_by(year) |>
  # Compute row-level summaries before `establishments` is overwritten by its total.
  summarise(establishments_with_jobs = sum(establishments[!is.na(jobs)]),
            suppressed_rows = sum(is.na(jobs)),
            max_establishments_in_suppressed_row = suppressWarnings(max(establishments[is.na(jobs)])),
            reported_jobs = sum(jobs, na.rm = TRUE),
            establishments = sum(establishments), .groups = "drop") |>
  mutate(coverage_pct = 100 * establishments_with_jobs / establishments,
         jobs_per_reported_establishment = reported_jobs / establishments_with_jobs)
check(all(jobs_coverage$max_establishments_in_suppressed_row <= 2),
      "suppressed job cells contain at most two establishments")

# ---------------------------------------------------------------------------
# 2. Distribution of precinct-industry group sizes (2024)
groups <- sme |>
  group_by(year, precinct, industry) |>
  summarise(suppressed_rows = sum(is.na(jobs)), jobs = sum(jobs, na.rm = TRUE),
            establishments = sum(establishments), .groups = "drop")
g24 <- filter(groups, year == 2024L)
size_bands <- g24 |>
  mutate(band = cut(establishments, c(0, 9, 19, 49, 99, 499, Inf),
    labels = c("1-9", "10-19", "20-49", "50-99", "100-499", "500+"))) |>
  group_by(band) |>
  summarise(groups = n(), establishments = sum(establishments), .groups = "drop") |>
  mutate(share_groups_pct = 100 * groups / sum(groups),
         share_establishments_pct = 100 * establishments / sum(establishments))
distribution_summary <- tibble(
  year = 2024L, groups = nrow(g24), median = median(g24$establishments),
  p25 = quantile(g24$establishments, .25), p75 = quantile(g24$establishments, .75),
  p90 = quantile(g24$establishments, .90), max = max(g24$establishments),
  groups_under_20_pct = 100 * mean(g24$establishments < 20),
  groups_100_plus = sum(g24$establishments >= 100),
  share_in_100_plus_pct = 100 * sum(g24$establishments[g24$establishments >= 100]) / sum(g24$establishments),
  share_in_top10_pct = 100 * sum(sort(g24$establishments, decreasing = TRUE)[1:10]) / sum(g24$establishments))

# Survey-cycle footprint: if a precinct is re-surveyed only every second year,
# its published total repeats the previous year's value. This is the empirical
# reason for comparing years at least two apart and modelling two-year steps.
survey_cycle <- sme |>
  group_by(precinct, year) |>
  summarise(establishments = sum(establishments), .groups = "drop") |>
  arrange(precinct, year) |>
  group_by(precinct) |>
  mutate(same_as_previous = establishments == lag(establishments),
         same_as_two_before = same_as_previous & lag(same_as_previous)) |>
  summarise(year_pairs = sum(!is.na(same_as_previous)),
            unchanged_from_previous_year = sum(same_as_previous, na.rm = TRUE),
            three_identical_years_in_a_row = sum(same_as_two_before, na.rm = TRUE),
            .groups = "drop") |>
  mutate(unchanged_pct = 100 * unchanged_from_previous_year / year_pairs)

# ---------------------------------------------------------------------------
# 3. Persistence of shortfalls across groups (complete in 2019, 2022 and 2024)
wide <- groups |>
  filter(year %in% key_years) |>
  select(precinct, industry, year, establishments) |>
  pivot_wider(names_from = year, values_from = establishments, names_prefix = "n_") |>
  filter(!is.na(n_2019), !is.na(n_2022), !is.na(n_2024)) |>
  mutate(persistent = n_2024 < n_2019 & n_2024 < n_2022)
check(nrow(wide) == 206L, "206 complete precinct-industry groups")
check(sum(wide$persistent) == 64L, "64 persistent-decline groups (matches main screen)")
below_2022 <- filter(wide, n_2022 < n_2019)
persistence <- tibble(
  complete_groups = nrow(wide),
  below_2019_in_2022 = nrow(below_2022),
  back_at_or_above_2019_by_2024 = sum(below_2022$n_2024 >= below_2022$n_2019),
  rose_2022_2024 = sum(below_2022$n_2024 > below_2022$n_2022),
  fell_2022_2024 = sum(below_2022$n_2024 < below_2022$n_2022),
  below_2019_in_2024 = sum(wide$n_2024 < wide$n_2019),
  persistent_groups = sum(wide$persistent),
  persistent_gap = sum(wide$n_2024[wide$persistent] - wide$n_2019[wide$persistent]),
  persistent_recent = sum(wide$n_2024[wide$persistent] - wide$n_2022[wide$persistent]),
  other_groups_recent = sum(wide$n_2024[!wide$persistent] - wide$n_2022[!wide$persistent]),
  city_gap = 13054 - 15506, city_recent = 13054 - 12571) |>
  mutate(persistent_share_of_city_gap_pct = 100 * persistent_gap / city_gap,
         two_year_cycles_to_close_at_recent_pace = -city_gap / city_recent)

# ---------------------------------------------------------------------------
# 4. Case profiles: establishments by size, and reported jobs, 2019-2024
cases <- tribble(
  ~case_role, ~precinct, ~industry,
  "Review case", "Melbourne (CBD)", "Professional, Scientific and Technical Services",
  "Review case", "Melbourne (CBD)", "Financial and Insurance Services",
  "Review case", "Melbourne (CBD)", "Administrative and Support Services",
  "Review case", "Melbourne (CBD)", "Construction",
  "Review case", "Southbank", "Accommodation and Food Services",
  "Monitor", "Melbourne (CBD)", "Health Care and Social Assistance",
  "Comparison", "Docklands", "Accommodation and Food Services",
  "Comparison", "Melbourne (CBD)", "Accommodation and Food Services",
  "Comparison", "North Melbourne", "Professional, Scientific and Technical Services")

case_cells <- sme |> filter(year %in% key_years) |> semi_join(cases, by = c("precinct", "industry"))
check(sum(is.na(case_cells$jobs)) == 0, "no suppressed job cells in the case groups")
case_size <- case_cells |>
  group_by(precinct, industry, size, year) |>
  summarise(n = sum(establishments), .groups = "drop") |>
  pivot_wider(names_from = c(size, year), values_from = n)
names(case_size) <- c("precinct", "industry",
  sub("Small \\(1-19 jobs\\)", "small", sub("Medium \\(20-199 jobs\\)", "medium",
    names(case_size)[-(1:2)])))
case_profiles <- case_cells |>
  group_by(precinct, industry, year) |>
  summarise(est = sum(establishments), jobs = sum(jobs), .groups = "drop") |>
  pivot_wider(names_from = year, values_from = c(est, jobs)) |>
  left_join(case_size, by = c("precinct", "industry")) |>
  right_join(cases, by = c("precinct", "industry")) |>
  mutate(est_gap = est_2024 - est_2019, est_gap_pct = pct(est_2024, est_2019),
         est_recent = est_2024 - est_2022, est_recent_pct = pct(est_2024, est_2022),
         jobs_change_pct = pct(jobs_2024, jobs_2019),
         jobs_per_est_2019 = jobs_2019 / est_2019, jobs_per_est_2024 = jobs_2024 / est_2024,
         small_gap = `small_2024` - `small_2019`, medium_gap = `medium_2024` - `medium_2019`,
         small_recent = `small_2024` - `small_2022`, medium_recent = `medium_2024` - `medium_2022`,
         small_share_of_gap_pct = ifelse(est_gap < 0, 100 * small_gap / est_gap, NA_real_)) |>
  select(case_role, precinct, industry, starts_with("est_"), starts_with("jobs"),
         starts_with("small"), starts_with("medium"))
check(sum(case_profiles$est_gap[case_profiles$case_role == "Review case"]) == -876,
      "five review cases total gap")

# ---------------------------------------------------------------------------
# 5. Vacant Space in the address file (all business sizes; records, not floor area)
addr <- read_csv(addr_path, show_col_types = FALSE,
  col_select = c(census_year, clue_small_area, industry_anzsic4_code, industry_anzsic4_description))
check(nrow(addr) == 413550L, "address file has 413,550 records")
check(all(addr$industry_anzsic4_code[addr$industry_anzsic4_description == "Vacant Space"] == 0),
      "Vacant Space uses dummy industry code 0")
vac <- addr |> mutate(vacant = industry_anzsic4_description == "Vacant Space")
check(sum(vac$vacant) == 68299L, "68,299 Vacant Space records")
vacancy_city <- vac |>
  group_by(year = census_year) |>
  summarise(records = n(), vacant = sum(vacant), .groups = "drop") |>
  mutate(area = "City of Melbourne")
vacancy_precinct <- vac |>
  group_by(year = census_year, area = clue_small_area) |>
  summarise(records = n(), vacant = sum(vacant), .groups = "drop")
vacancy_yearly <- bind_rows(vacancy_city, vacancy_precinct) |>
  mutate(vacant_share_pct = 100 * vacant / records)
vacancy_comparison <- vacancy_yearly |>
  filter(year %in% key_years) |>
  select(area, year, vacant, vacant_share_pct) |>
  pivot_wider(names_from = year, values_from = c(vacant, vacant_share_pct)) |>
  arrange(desc(vacant_2024))

# ---------------------------------------------------------------------------
# Export tables
write_csv(size_yearly, file.path(out_dir, "size_class_yearly.csv"))
write_csv(size_comparison, file.path(out_dir, "size_class_comparison.csv"))
write_csv(jobs_coverage, file.path(out_dir, "jobs_coverage.csv"))
write_csv(size_bands, file.path(out_dir, "group_size_bands_2024.csv"))
write_csv(distribution_summary, file.path(out_dir, "group_size_summary_2024.csv"))
write_csv(persistence, file.path(out_dir, "shortfall_persistence.csv"))
write_csv(survey_cycle, file.path(out_dir, "survey_cycle_repeats.csv"))
write_csv(case_profiles, file.path(out_dir, "case_profiles.csv"))
write_csv(vacancy_yearly, file.path(out_dir, "vacancy_yearly.csv"))
write_csv(vacancy_comparison, file.path(out_dir, "vacancy_comparison.csv"))

# ---------------------------------------------------------------------------
# Figures (house style matches scripts/descriptive_followup.R)
navy <- "#253F57"; teal <- "#187F86"; orange <- "#B94E32"; grey <- "#8A97A3"
style <- theme_minimal(base_size = 12, base_family = "sans") +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", colour = navy, size = 16),
        plot.subtitle = element_text(colour = "#475569", size = 11),
        plot.caption = element_text(colour = "#586675", hjust = 0, size = 9),
        plot.margin = margin(14, 22, 12, 12), legend.position = "top", plot.title.position = "plot", plot.caption.position = "plot",
        legend.title = element_blank())
cap <- "Source: City of Melbourne CLUE (supplied 2002-2024 snapshot). Group 10 calculations."
save <- function(plot, name, w = 9, h = 5.2) {
  ggsave(file.path(fig_dir, name), plot, width = w, height = h, dpi = 200, bg = "white")
}

# Figure: small vs medium, indexed to 2019 = 100 (one axis, common base)
lab <- size_yearly |> filter(year == 2024L)
p1 <- ggplot(size_yearly, aes(year, index_2019, colour = size)) +
  geom_hline(yintercept = 100, colour = grey, linewidth = .4, linetype = "dashed") +
  geom_vline(xintercept = c(2019, 2022), colour = "#D5DBE0", linewidth = .4) +
  geom_line(linewidth = 1.1) + geom_point(data = filter(size_yearly, year %in% key_years), size = 2.6) +
  geom_text(data = lab, aes(label = sprintf("%s\n%s in 2024", sub(" \\(.*", "", size),
                                            comma(establishments))),
            hjust = -0.08, size = 3.4, lineheight = .9, show.legend = FALSE) +
  scale_colour_manual(values = c(orange, teal)) +
  scale_x_continuous(breaks = c(2002, 2007, 2012, 2017, 2019, 2022, 2024),
                     expand = expansion(mult = c(.02, .16))) +
  labs(title = "The remaining SME gap is a small-business gap",
       subtitle = "SME establishments indexed to 2019 = 100. Medium firms are back to 2019; small firms remain 19% below.",
       x = NULL, y = "Index (2019 = 100)", caption = cap) + style +
  theme(legend.position = "none")
save(p1, "size_class_index.png")

# Figure: distribution of group sizes (log scale)
p2 <- ggplot(g24, aes(establishments)) +
  geom_histogram(bins = 24, fill = teal, colour = "white", linewidth = .3) +
  geom_vline(xintercept = median(g24$establishments), colour = orange, linewidth = .7) +
  annotate("text", x = median(g24$establishments) * 1.15, y = Inf, vjust = 1.6, hjust = 0,
           label = sprintf("Median group: %.0f establishments", median(g24$establishments)),
           colour = orange, size = 3.6) +
  scale_x_log10(labels = comma, breaks = c(1, 3, 10, 30, 100, 300, 1000)) +
  labs(title = "Most precinct-industry groups are small; a few are very large",
       subtitle = sprintf("2024 SME establishments per group (log scale). %d groups of 100+ hold %.0f%% of all SME establishments.",
                          distribution_summary$groups_100_plus, distribution_summary$share_in_100_plus_pct),
       x = "SME establishments in the group (log scale)", y = "Number of groups", caption = cap) + style
save(p2, "group_size_distribution.png", h = 4.6)

# Figure: Vacant Space share of address-file records
vac_plot <- vacancy_yearly |>
  filter(area %in% c("City of Melbourne", "Melbourne (CBD)", "Docklands", "Southbank")) |>
  mutate(area = factor(area, levels = c("Docklands", "Southbank", "Melbourne (CBD)", "City of Melbourne")))
vac_lab <- filter(vac_plot, year == 2024L) |>
  mutate(label_y = vacant_share_pct + c("Docklands" = 0, "Southbank" = -1.3,
    "Melbourne (CBD)" = -1.4, "City of Melbourne" = 1.4)[as.character(area)])
p3 <- ggplot(vac_plot, aes(year, vacant_share_pct, colour = area)) +
  geom_vline(xintercept = c(2019, 2022), colour = "#D5DBE0", linewidth = .4) +
  geom_line(aes(linewidth = area == "City of Melbourne")) +
  geom_text(data = vac_lab, aes(y = label_y, label = sprintf("%s %.0f%%", area, vacant_share_pct)),
            hjust = -0.06, size = 3.3, show.legend = FALSE) +
  scale_linewidth_manual(values = c(.8, 1.5), guide = "none") +
  scale_colour_manual(values = c(grey, "#C08A2E", orange, navy)) +
  scale_x_continuous(breaks = c(2002, 2007, 2012, 2017, 2019, 2022, 2024),
                     expand = expansion(mult = c(.02, .26))) +
  scale_y_continuous(labels = function(x) paste0(x, "%"), limits = c(0, NA)) +
  labs(title = "Vacant Space records almost doubled after 2019 and have barely receded",
       subtitle = "Share of address-file records classified as Vacant Space (all business sizes; a record is a space, not floor area).",
       x = NULL, y = "Vacant Space share of records", caption = cap) + style +
  theme(legend.position = "none")
save(p3, "vacancy_share.png")

# Figure: establishments vs jobs, 2019-2024, for review cases and comparisons
short <- c("Professional, Scientific and Technical Services" = "Professional services",
           "Financial and Insurance Services" = "Finance & insurance",
           "Administrative and Support Services" = "Admin & support",
           "Construction" = "Construction",
           "Accommodation and Food Services" = "Hospitality",
           "Health Care and Social Assistance" = "Health care")
pl <- case_profiles |>
  filter(!(case_role == "Comparison" & precinct == "North Melbourne")) |>
  mutate(label = paste0(sub("Melbourne \\(CBD\\)", "CBD", precinct), " ", short[industry],
                        ifelse(case_role == "Review case", "", paste0(" (", tolower(case_role), ")")))) |>
  select(label, case_role, est_gap_pct, jobs_change_pct) |>
  pivot_longer(c(est_gap_pct, jobs_change_pct), names_to = "measure", values_to = "change") |>
  mutate(measure = factor(measure, c("est_gap_pct", "jobs_change_pct"),
                          c("Establishments", "Reported jobs")))
ord <- pl |> filter(measure == "Establishments") |> arrange(case_role != "Review case", change) |> pull(label)
pl$label <- factor(pl$label, levels = rev(ord))
p4 <- ggplot(pl, aes(change, label, fill = measure, group = forcats::fct_rev(measure))) +
  geom_vline(xintercept = 0, colour = grey, linewidth = .4) +
  geom_col(position = position_dodge(width = .72), width = .66) +
  geom_text(aes(label = sprintf("%+.0f%%", change), hjust = ifelse(change < 0, 1.12, -.12)),
            position = position_dodge(width = .72), size = 3.1, colour = "#333F4B") +
  scale_fill_manual(values = c(orange, teal)) +
  scale_x_continuous(labels = function(x) paste0(x, "%"), expand = expansion(mult = .16)) +
  labs(title = "Fewer workplaces does not always mean fewer jobs",
       subtitle = "Change 2019-2024. Jobs held up where small firms consolidated; both fell where activity contracted.",
       x = "Change, 2019 to 2024", y = NULL, caption = cap) + style
save(p4, "cases_establishments_vs_jobs.png", h = 5.4)

check(identical(unname(tools::md5sum(c(agg_path, addr_path))), unname(hash_before)),
      "source files unchanged")
cat("PASS: data insights written to", out_dir, "\n")
