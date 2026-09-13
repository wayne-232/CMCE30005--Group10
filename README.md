# CMCE30005 Business Analytics Challenge

## Group 10 — Melbourne Business Establishments

**Subject:** CMCE30005 Business Analytics Challenge, Semester 2, 2026<br>
**University:** University of Melbourne<br>
**Team members:** Angelyne Leang, Wayne Cao, Yixi Wang, Megan Suprapto

## Business problem and scope

This project helps the City of Melbourne identify where SME support may be needed.

**Research question:** How have small and medium-sized business establishment
patterns evolved across Melbourne precincts and industries from 2002 to 2024?

We track the full period and compare 2024 with both 2019 and 2022. These show the
remaining pre-COVID gap and recent change. Counts cannot establish individual
firm closures or the causal effect of COVID-19.

**Working SME definition:** Small business plus Medium business, or 1–199 jobs
at an establishment. The group still needs to decide whether to include the
separate Non employing category. The report compares both definitions. Size
refers to the location, not necessarily the whole company.

## Start here

- [Report on GitHub](analysis/01_descriptive_analytics.md)
- [HTML report](analysis/01_descriptive_analytics.html) — download and open in a
  browser; code can be expanded.
- [R Markdown source](analysis/01_descriptive_analytics.Rmd) — requires `scripts/`.
- [Team review guide](docs/TEAM_REVIEW.md)

## Data

Source: City of Melbourne, Census of Land Use and Employment (CLUE).
The supplied snapshot covers 2002–2024 and 13 precincts. It contains:

- `business-establishments-and-jobs-data-by-business-size-and-anzsic.csv`
  — 13,353 rows, 6 columns, about 924 KB. Published counts by year, precinct,
  industry division and business size. This is the main SME source.
- `business-establishments-with-address-and-industry-classification.csv`
  — 413,550 rows, 12 columns, about 76 MB. Address-level classifications used
  for data checks and an all-size count comparison. It cannot identify SMEs
  because it has no size variable.

Use the **supplied course snapshot**, not a newer download. Create `data/` in the
repository root and place both files there, keeping their original names.
Raw CSVs are excluded from Git and must not be edited. The report records file
sizes and MD5 checksums so teammates can check they used the same snapshot.

Published [aggregate metadata](https://discover.data.vic.gov.au/dataset/business-establishments-and-jobs-data-by-business-size-and-anzsic-in-small-areas)
and [address metadata](https://discover.data.vic.gov.au/dataset/business-establishments-location-and-industry-classification)
provide definitions. CLUE recommends comparisons at least two years apart;
annual lines provide context, not annual entry/exit or growth rates.

## Data decisions

- Audit both full files before filtering. Retain establishment counts when jobs
  are missing; leave missing jobs as NA.
- Preserve Vacant Space in the raw data and separate it for the address-count
  check. This does not correct survey lag.
- Use the aggregated file for SME results and sum its establishment counts.
- Retain all precincts in counts. Withhold displayed percentages with starting
  counts below 100; export rates with small-baseline flags.
- Leave absent precinct-industry combinations unavailable, rather than setting
  them to zero. Section 2 of the report explains each decision.

## Repository structure

```text
.
├── README.md
├── data/                              # Supplied raw CSVs; local only
├── scripts/
│   ├── scripts_00_packages.R           # One-time installation guidance
│   ├── analysis_helpers.R             # Shared checks and calculations
│   └── render_reports.R               # Build HTML and Markdown
├── analysis/
│   ├── 01_descriptive_analytics.Rmd    # Main source, English notes and code
│   ├── 01_descriptive_analytics.md     # Readable on GitHub
│   ├── 01_descriptive_analytics.html   # Browser copy with folding code
│   └── 01_descriptive_analytics_files/ # Charts for the Markdown report
├── tests/
│   └── test_analysis.R                # Unit and full-data checks
├── outputs/tables/                    # Aggregate results, by selected scope
└── docs/
    ├── TEAM_REVIEW.md                 # Review questions
    ├── VALIDATION.md                  # Test record
    └── AI_ASSISTANCE.md               # Assistance acknowledgement
```

## Reproduce the analysis

1. Open the repository's `.Rproj` in RStudio. Alternatively, set the terminal's
   working directory to the repository root.
2. Put both supplied CSVs in `data/`.
3. Install dependencies once in the R console:

   ```r
   install.packages(c("tidyverse", "scales", "knitr", "rmarkdown"))
   ```

4. Run these commands from the repository root in a terminal:

   ```sh
   Rscript tests/test_analysis.R
   Rscript scripts/render_reports.R
   ```

R 4.1 or later is needed for the native pipe; dplyr 1.1.0 or later is needed
for checked join relationships. Pandoc is required for rendering and is included
with RStudio. Exact versions used are printed in the report's `sessionInfo()`.
No packages are installed and no data are downloaded while knitting.

In RStudio, opening the Rmd and selecting **Knit** also produces the HTML report.
For the alternative main definition, run:

```sh
Rscript scripts/render_reports.R --include-non-employing
```

That command **replaces both main reports** with the alternative scope. Rerun
without the flag to restore the working default. Each scope writes tables to a
separate folder, and both reports include a comparison of the two definitions.
Do not combine numbers from different scopes in a single slide.

Tests run every report chunk under both definitions and compare counts with
independent base-R sums. They also check invalid inputs, missing data and
percentage denominators. Rendering stops on warnings. See the
[validation record](docs/VALIDATION.md) for results and limitations.

## Current progress and next phase

Completed: source checks, missing-value audit, sample definition, long-run city,
precinct and industry trends, 2019/2022/2024 comparisons and scope sensitivity.

Planned: test two-year precinct-count forecasts against a no-change baseline,
training on earlier dates and testing on later dates. Use count patterns to
shortlist areas for consultation, then assess intervention costs and effectiveness.
These models and policy recommendations have not yet been evaluated. Vacancy
rates, firm survival and employment growth are outside this analysis.

See [AI assistance and review responsibilities](docs/AI_ASSISTANCE.md).
