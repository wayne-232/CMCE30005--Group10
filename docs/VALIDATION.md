# Validation record

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
