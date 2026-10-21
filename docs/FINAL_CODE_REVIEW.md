# Final analysis: team review guide

## Start here

Open `analysis/02_final_analysis.html` to see the findings, charts and methods
without reading code. Its R Markdown source rebuilds the analysis from the
original CSV. `analysis/01_descriptive_analytics.html` contains the underlying
data-quality checks and comparisons under both SME definitions.

This code update and its supporting results are for group review. The existing
interim report is preserved in the README. The final group report still needs
to incorporate the agreed results.

## What changed

### Revision following the final-presentation feedback

The readable report now leads with the descriptive evidence. It states the
presentation's focused research question, explains both datasets and the SME
population, and follows city totals through industries to five named cases.
Detailed prediction methods and the industry-mix comparison are in appendices.

The 64-group screen is reproduced exactly: a 2024 count below 2019 and a further
decline from 2022 to 2024. There are 206 complete groups and 11 incomplete groups.
Of the 64 screened groups, 53 have fewer than 100 establishments at the start of
at least one comparison. These groups still belong in a count-based screen;
the percentage-display rule must not silently redefine the list.

Five cases are selected mechanically by the largest absolute 2019-2024 gaps
within that screen. All are in the CBD: professional services, finance,
administrative support, health care and construction. They account for a gap
of 904 and a further loss of 107 after 2022. Health care's recent loss is only
three, so the text distinguishes a historical gap from a strong urgency signal.

Policy timelines, trial designs and programme evaluation are outside scope.
Model validation stays in the report because it is needed to support the
forecast comparison. No predictive implementation or score changed in this
feedback revision.

### Earlier coding update

1. The October descriptive work is now a reusable script in this repository.
   It reports city, precinct and industry changes, contribution concentration,
   coverage and a rest-of-city industry-mix comparison.
2. The predictive analysis is implemented in R. It compares no change, OLS,
   a pruned regression tree and gradient boosting on the same observations.
3. Tests check source totals, missing-cell treatment, exact two-year joins,
   identical evaluation samples and temporal leakage.
4. Every model prediction, score, chosen setting and excluded cell is exported.
   A single command runs the tests and rebuilds both reports.

The presentation's original modelling code was not available. This is an
independent rebuild, not a claim to recover its implementation. The no-change
MAE rounds to the same 5.13. Scores for the fitted models differ slightly.
Use the rebuilt tables consistently if the group adopts this version.

## How the prediction works

One observation is a precinct-industry group at a starting year. The outcome
is the change in its SME count two years later. A count of 100 rising to 108
means a target of +8. No change predicts 0 change, or a future count of 100.

The fitted models use the starting count, its log transform, the previous
two-year change, precinct and industry. The sample uses even years. Exact
year joins prevent a missing observation from being replaced with the wrong lag.
Cells with absent required counts stay unknown and are excluded transparently.

Four expanding-window validation periods end in 2016, 2018, 2020 and 2022.
For each period, training outcomes must already be observable at its start.
The mean of the four MAEs chooses settings before the 2022-2024 evaluation.
An added non-employing scope check keeps each model family's configuration fixed.

The method is a retrospective backtest on the supplied data vintage. It does
not reproduce the information available to the City on each historical date.
We do not claim that one historical evaluation proves future reliability.

## What the results support

- City SME counts rose by 483 after 2022, offsetting 16.5% of the 2019-2022 loss.
- The CBD accounts for 65.0% of the remaining shortfall and 50.7% of the recent
  city net gain. Hospitality contributes 44.3% of that net gain across industries.
  Precinct and industry shares overlap and must not be added.
- No change has the lowest validation MAE and the lowest final-test MAE.
  It is a useful benchmark; it does not show that all groups are unchanged.
- Many small groups change little, while larger groups account for much of the
  error. The baseline's error in groups with at least 100 establishments is much
  larger than its overall average.
- Observed shortfall and recent direction identify groups for investigation.
  The code does not estimate which policy will work or the optimal funding amount.

## Decisions for the group

1. Adopt this reproducible model version, or supply the original model source
   so that any differences can be explained before submission.
2. Keep Small + Medium (1-199 jobs) as the main population. Non-employing
   establishments remain a separate sensitivity analysis.
3. Choose the findings that belong in the final report. Keep the industry-mix
   comparison secondary unless it helps answer a specific business question.
4. Use “lowest MAE among the models tested” rather than “the model proves
   businesses will stay unchanged.”

## File map

- `scripts/descriptive_followup.R`: observed patterns and transparent review lists.
- `scripts/predictive_models.R`: panel, time splits, fitting and error analysis.
- `scripts/run_final_analysis.R`: tests and report rendering.
- `tests/test_analysis.R`: original data-audit checks under both scopes.
- `tests/test_final_analysis.R`: additional descriptive and model checks.
- `outputs/tables/final/descriptive/`: findings, comparisons and five chart PNGs.
- `outputs/tables/final/predictive/`: models, scores, coverage and diagnostics.
- `outputs/tables/final/scope_sensitivity/`: alternative-population check.
- `outputs/tables/final/validation/`: test log, checksums and package versions.

Use `Rscript scripts/install_dependencies.R` once if packages are missing, then
`Rscript scripts/run_final_analysis.R` from the repository root.
The optional `.r-library/` holds local dependencies and is excluded from Git.
Package versions are recorded, not locked; rerun tests when the environment changes.
