# Team review guide

## Where to start

For the final analysis, start with [the October code review guide](FINAL_CODE_REVIEW.md)
and `analysis/02_final_analysis.html`. The remainder of this guide records the
earlier descriptive-analysis review. Models have now been fitted in the separate
final-analysis module; group approval is still required.

The root README now holds the final project report; the September interim
report is in the Git history. Both original CSVs are included in data/. The
longer analysis and the documents here are supporting material.

Read Sections 1, 3-6 and 8 of the report for scope, results and next steps.
Section 2 explains the data decisions. The HTML version lets you hide the code.
This is a supporting analysis document, not the written submission.

Main figures use the selected SME categories. The earlier presentation included
all-size totals, which should not be labelled SME totals. The size table shows
which categories are included.

## Scope decision

Should SMEs include CLUE's separate Non employing category? The current default
uses Small business plus Medium business (1–199 jobs at an establishment).
Section 7 compares both definitions. Confirm the definition before copying
figures into the group report.

## Vacant Space and missing data

Vacant Space is retained in the raw data and audit. It is excluded only from the
address-file establishment count check. A vacant location can have complete
fields, so a low missing-value rate does not determine whether it belongs in
that count. Full-file and vacant-subset audits use different denominators.

This selection cannot correct survey lag or identify all businesses that closed
between visits. It does not change historical records or the SME sample, which
comes from the aggregated file. Missing jobs remain NA and do not cause known
establishment counts to be dropped.

## Reading recovery figures

- **2024 minus 2019:** the remaining gap from the pre-COVID count.
- **2024 minus 2022:** recent increase or decrease.
- An area can improve recently and still remain below 2019.
- These are net establishment changes, not numbers of firm closures.
- Starting counts below 100 are shown as counts only in percentage comparisons.
  This is our display rule; all precincts remain in city totals.

## Before submission

1. Confirm that the RQ and SME definition agree.
2. Select the precinct and industry comparisons that best answer the RQ.
3. Report both the remaining gap and recent change, with the correct baselines.
4. Check local context before explaining causes or recommending support.
5. Keep proposed models labelled as planned until they are fitted and tested.
6. Review sources, contributions and the AI assistance acknowledgement.

For a disputed number, record the section, population and years. Trace it to an
exported table, amend the source if needed, and rerun the tests and report.
