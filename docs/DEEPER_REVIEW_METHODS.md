# Peer comparison supplement

This supplement adds context to the five final-report cases without changing
the research question or fitting another predictive model. The main report
can use the recent peer comparison and two-window chart; the remaining tables
are checks for the appendix and review.

## Run

From the repository root:

```sh
Rscript tests/test_peer_comparison_review.R
Rscript scripts/07_peer_comparison_review.R
Rscript -e 'rmarkdown::render("analysis/03_peer_comparison_review.Rmd", output_format="all")'
```

Sourcing `scripts/07_peer_comparison_review.R` defines functions without
executing the analysis. `run_peer_review(root = ".", make_figures = TRUE)`
returns a list containing `tables` and `summary`. Repeated runs overwrite only
the supplement's generated files. No package installation, source-data edits,
network calls, shared-document changes or GitHub operations are performed.

## Source and unit

The input is the existing aggregated CLUE CSV in `data/`. Small and Medium
categories are summed by year, precinct and ANZSIC division. Source keys and
establishment counts must be valid and complete. Missing employment values
are irrelevant to this calculation and are not imputed.

The address-level file is not needed for this supplement. Its Vacant Space
records are not part of the aggregated establishment totals. The analysis
does not track individual businesses, tenancies or property occupancy.

## Reference calculation

For focal precinct p and industry i over years a and b:

- Local growth = 100 × (local count b / local count a − 1).
- Peer growth = 100 × (industry count b outside p / industry count a outside p − 1).
- Growth difference = local growth − peer growth, in percentage points.
- Benchmark end count = local count a × (1 + peer growth / 100).
- Observed minus benchmark = local count b − benchmark end count.

The benchmark is a descriptive reference, not a causal counterfactual or a
prediction. Pooling peer counts weights each establishment equally. The focal
precinct never contributes to its own reference. Negative residuals indicate
fewer establishments than under the observed peer growth rate; they cannot be
attributed to COVID, a local policy, or any single business condition.

An absent source cell remains unknown. Published peer totals sum the observed
cells in each year. Every comparison also reports the count coverage of peer
precincts observed in both years and their matched-peer growth. Construction's
recent published peer rate is 13.89%; its matched-peer rate is 13.33% because a
Parkville cell with one establishment is present only in 2024. Both give the
same directional conclusion. No absent cell is filled with zero.

## Periods

The main comparisons are 2017–2019, 2019–2024 and 2022–2024. The first and last
have equal two-year lengths; the five-year historical comparison is labelled
separately. No annual growth rates are calculated.

Historical context uses eight non-overlapping windows from 2003–2005 through
2017–2019, then 2020–2022 and 2022–2024. A separate export uses even-year windows
from 2002–2004 through 2022–2024. Professional services underperformed peers in
three of the eight odd-year pre-periods and five of the eight even-year
pre-periods. Its 2017–2019 and 2022–2024 relative weakness is therefore not
evidence of an uninterrupted historical decline. Repeated observations are
not independent, and no significance or structural-break test is claimed.

## Case selection and sensitivity

The four scale cases are the largest 2019–2024 shortfalls among groups still
declining by at least 2% in 2022–2024. The hospitality contrast is selected
separately as the largest non-CBD hospitality shortfall among continuing
declines. It is not selected using the 2% cutoff. Ties are resolved by precinct
and industry name to keep selection deterministic.

The four scale cases remain at 1%, 2% and 3% cutoffs. At 0%, health care replaces
construction; at 5%, only two original scale cases remain. The cutoff is a
practical selection rule, not a statistical threshold.

Repeating selection with 2018 changes two of the five cases: North Melbourne
professional services replaces CBD construction, and Docklands hospitality
replaces Southbank hospitality. The original first three CBD cases remain.
Southbank's 2024 hospitality count is 1.94% below 2018 and 14.41% below 2019.
Its recent peer underperformance is still present when the CBD is also
excluded from its hospitality reference (+4.70% peers versus −4.72% locally).

## Outputs

All tables are under `outputs/tables/final/deeper_review/`:

| File | Purpose |
|---|---|
| `peer_comparisons.csv` | Five cases × three periods, counts, rates, residuals and peer coverage |
| `selected_cases.csv` | Original four scale cases and separate hospitality contrast |
| `threshold_sensitivity.csv` | Full rosters for five cutoffs and two baseline years |
| `threshold_stability.csv` | Original scale-case retention at each cutoff and baseline |
| `baseline_sensitivity.csv` | Fixed original five cases compared with 2018 and 2019 |
| `baseline_case_selection.csv` | Explicit 2018 and 2019 rosters at the 2% cutoff |
| `full_two_year_history.csv` | Odd-year pre-periods through 2019 and two recent windows |
| `alternate_even_year_history.csv` | Alternate even-year comparison scheme |
| `history_summary.csv` | Eight odd-year pre-period comparisons per original case |
| `hospitality_reference_sensitivity.csv` | Southbank references with and without the CBD |
| `results_summary.json` | Concise machine-readable findings and source checksum |
| `test_results.json` | Independent validation status and individual checks |
| `session_info.txt` | R version and package environment |

Three PNGs are under `outputs/figures/final/deeper_review/`:
`recent_peer_comparison.png`, `pre_recent_comparison.png`, and
`full_two_year_history.png`. The narrative and commented code are in
`analysis/03_peer_comparison_review.Rmd` and its rendered HTML/Markdown.

## Interpretation to preserve

Three recent local-versus-peer divergences are evident. The two remaining
cases matter because of their historical scale, not because they performed
worse than peers recently. The five-case 2019 shortfall of 876 already includes
the recent net loss of 114. Neither the gap nor the selection rank establishes
causation or proves the benefit of a proposed intervention.
