# Validation record

## Final analysis — 21 October 2026

`Rscript scripts/run_final_analysis.R` completed locally. It ran 56 original
checks and 65 final-analysis checks (121 in total), then rendered both analysis documents to HTML and
GitHub Markdown with warnings treated as errors.

The new checks independently reproduce source totals and the no-change MAE,
test exact two-year joins, verify identical model samples and time boundaries,
and confirm that changing held-out outcomes does not change predictions.
They also cover benchmark denominators, missing cells, scope sensitivity,
non-negative forecasts and error-share calculations. Additional checks reproduce
the 64-group descriptive screen and the five-case selection, including missing
comparisons, small-baseline flags and deterministic ordering.

Both raw CSV checksums remained unchanged. Full logs, input and result
checksums, package versions and session information are in
`outputs/tables/final/validation/`. The rendered analysis contains seven figures,
including the new five-case comparison. Figure layouts were visually inspected.
The analysis runner performs no Git operations, shared-document edits or LMS
submission. Its run-status record describes the calculation run, not subsequent
repository publication.

These tests establish that the implemented workflow runs and follows its
stated rules. They do not establish policy effectiveness, causal effects,
future forecast reliability or reproduction of the unavailable original
presentation model code.

## Earlier descriptive validation — 17 September 2026

Tests and both report formats rerun on 17 September 2026 after revising the
README, data packaging and report figures.
The analysis still uses the supplied two-file snapshot.

- `Rscript tests/test_analysis.R`: 56 checks passed. Every Rmd chunk executed
  under both SME definitions. Independent base-R sums matched city, precinct
  and industry counts. Tests cover missing and zero baselines, small-baseline
  display rules, absent group-years, duplicate keys and source classifications.
- HTML and GitHub Markdown rendered successfully for both definitions with
  warnings treated as errors. The delivered main reports use Small + Medium.
- Source-file MD5 checksums were unchanged during the tests. The manifests in
  `outputs/tables/` record the exact inputs.
- The three README figures were inspected as PNGs on 17 September: city trend,
  precinct comparison and the new industry summary. The four remaining figures
  are unchanged from the earlier visual review. Local HTML interactive controls
  have not been rechecked in this revision.
- The five-section README body is approximately 1,000 words. It presents the
  interim report ahead of the supporting code and technical documentation.
- The original data symlinks were replaced with regular CSV files. File sizes
  and MD5 checksums match the earlier manifest. LMS attachment names and displayed
  sizes were checked; a fresh LMS download was blocked by Chrome, so exact byte
  equality with a newly downloaded LMS copy was not verified.
- New checks confirm that the short industry chart adds to the city change and
  that the precinct percentage chart is sorted by percentage rather than count.
- Source text and documentation were checked for English wording. Repeated
  explanations and references to internal chat discussions were removed.

Environment: R 4.5.3 and Pandoc 3.8. Full package versions are printed at the end
of the report. Dependencies are documented but not pinned in a lockfile.

These checks cover this snapshot only. Forecast models remain untested, and the
SME scope decision and team review are still pending.
