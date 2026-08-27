# CMCE30005 Business Analytics Challenge

## Group 10 — Melbourne Business Establishments

**Subject:** CMCE30005 Business Analytics Challenge, Semester 2, 2026<br>
**University:** University of Melbourne<br>
**Team members:** Angelyne Leang, Wayne Cao, Yixi Wang, Megan Suprapto

---

## Business problem

The Lord Mayor of Melbourne needs to understand how business establishment
patterns have changed across Melbourne precincts and industries, particularly
around COVID-19. The project examines which areas and business-size groups have
recovered, which remain below their pre-COVID baseline, and where business
support may be most useful.

**Research question:** How have small and medium-sized business establishment
patterns evolved across Melbourne precincts and industries from 2002 to 2024,
particularly around COVID-19?

The analysis is descriptive and does not claim that COVID-19 caused every
observed change.

---

## Dataset

**Source:** City of Melbourne Open Data, Census of Land Use and Employment
(CLUE)<br>
**Coverage:** 2002–2024, covering 13 CLUE small areas

### Data files

| File | Description | Local size |
|---|---|---:|
| `business-establishments-with-address-and-industry-classification.csv` | Location-level records with address, detailed industry and coordinates | 76 MB |
| `business-establishments-and-jobs-data-by-business-size-and-anzsic.csv` | Aggregated establishment and job counts by year, precinct, industry and business size | 924 KB |

The repository `.gitignore` excludes CSV files. To reproduce the analysis,
create a `data/` folder in the repository root and place both supplied CSV files
inside it. Raw data should not be edited directly.

---

## Repository structure

```text
.
├── README.md
├── data/                              # Local raw data; excluded from Git
├── scripts/
│   └── scripts_00_packages.R          # Project package setup
└── analysis/
    ├── 01_descriptive_analytics.Rmd   # Reproducible analysis source
    ├── 01_descriptive_analytics.md    # GitHub-readable rendered report
    └── 01_descriptive_analytics_files/
        └── figure-gfm/                # Figures used by the Markdown report
```

---

## Descriptive analytics

The first-stage analysis covers:

- data import, cleaning and validation;
- identification of numerical and categorical variables;
- overall and grouped summary statistics;
- city-wide establishment trends;
- precinct comparisons using 2019 and 2024;
- establishment changes by business size and industry; and
- limitations arising from the CLUE survey cycle and suppressed job values.

View the rendered report:
[Descriptive analytics](analysis/01_descriptive_analytics.md)

---

## How to reproduce the report

1. Open the project `.Rproj` file in RStudio.
2. Put both supplied CSV files in `data/`.
3. Install the packages listed in `scripts/scripts_00_packages.R` if required.
4. Open `analysis/01_descriptive_analytics.Rmd` and select **Knit**.

The report uses relative paths and does not require computer-specific file
locations.

---

*Last updated: 27 August 2026*
