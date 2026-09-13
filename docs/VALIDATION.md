# Validation record

Tests and both report formats rerun on 13 September 2026 after editing the text.
The analysis still uses the supplied two-file snapshot.

- `Rscript tests/test_analysis.R`: 52 checks passed. Every Rmd chunk executed
  under both SME definitions. Independent base-R sums matched city, precinct
  and industry counts. Tests cover missing and zero baselines, small-baseline
  display rules, absent group-years, duplicate keys and source classifications.
- HTML and GitHub Markdown rendered successfully for both definitions with
  warnings treated as errors. The delivered main reports use Small + Medium.
- Source-file MD5 checksums were unchanged during the tests. The manifests in
  `outputs/tables/` record the exact inputs.
- All six charts were inspected as PNGs on 11 September. Plot code is unchanged
  in this text revision. Browser access to the local HTML was blocked, so its
  interactive controls remain unverified.
- Source text and documentation were checked for English wording. Repeated
  explanations and references to internal chat discussions were removed.

Environment: R 4.5.3 and Pandoc 3.8. Full package versions are printed at the end
of the report. Dependencies are documented but not pinned in a lockfile.

These checks cover this snapshot only. Forecast models remain untested, and the
SME scope decision and team review are still pending.
