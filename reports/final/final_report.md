# Melbourne SME Establishments and Recovery

Final Report | Group 10 | CMCE30005 Business Analytics Challenge

Yixi Wang | Wayne Cao | Angelyne Leang | Megan Suprapto  
23 October 2026

## 1 Introduction

Melbourne’s small and medium-sized enterprises (SMEs) have regained establishments since 2022, yet some precinct–industry groups continue to shrink. The Lord Mayor needs to identify where business support deserves attention. City-wide growth alone offers little guidance when local industries are moving in different directions.

The City’s Economic Development Strategy 2031 links reduced office attendance and visitor activity to disrupted demand (City of Melbourne, 2021, pp. 12–14). Using Census of Land Use and Employment (CLUE) data, we examine five groups with persistent losses and compare their recovery with industry peers.

## 2 Problem Definition and Objectives

Which precinct–industry groups in Melbourne show persistent SME establishment shortfalls, and how can their historical and recent recovery patterns inform priorities for further investigation and potential support?

We measure losses against 2019 and recovery since 2022, selecting cases by the scale and persistence of decline. Same-industry comparisons distinguish local underperformance from wider sector weakness. Forecast tests assess whether historical counts can guide future priorities.

| Dimension | Scope |
| --- | --- |
| Population | Small (1–19 jobs) and Medium (20–199 jobs). Non-employing and Large excluded. |
| Coverage | 13 CLUE small areas and 19 ANZSIC divisions, 2002–2024. |
| Comparisons | 2019 baseline; 2022–2024 recovery. No annual growth or entry/exit rates. |
| Outcome | Establishment counts. Firm survival, employment growth and causal effects outside scope. |

Table 1. Scope of the analysis. One firm can operate at multiple locations.

## 3 Data Description

The aggregated CLUE file contains 13,353 rows and six variables: year, precinct, industry, business size, establishment count and job count (City of Melbourne, n.d.-a). Each row is a year–precinct–industry–size combination. Selecting Small and Medium retains 8,800 rows. The address file has 413,550 records but no size field, so it supports all-size checks (City of Melbourne, n.d.-b).

We checked types, missingness, duplicate keys and invalid counts. Establishment counts are complete. Jobs are missing in 4,252 rows (31.8%), all containing at most two establishments, consistent with confidentiality suppression. Retaining these rows, including 1,932 SME rows, preserves establishment coverage without job imputation.

The address file includes 68,299 Vacant Space observations across all years. These are a recorded category, not missing values. We retain them in source data but exclude them when checking operating-establishment totals. The aggregated SME file has no vacancy category.

Group totals reconcile to city totals. Unpublished cells remain unknown: 206 groups have complete counts for 2019, 2022 and 2024; 11 are incomplete. Appendix B shows precinct and industry detail.

## 4 Methodology and Analytical Approach

R and R Markdown reproduce the checks, tables and ggplot2 figures. We compare 2019–2024 shortfalls and 2022–2024 recovery. CLUE surveys properties at least once every two years, supporting multi-year comparisons (City of Melbourne, n.d.-c). Predictive observations use even-year origins, 2004–2022, creating non-overlapping two-year windows.

We screen for 2024 counts below both 2019 and 2022, then select the four largest historical shortfalls among groups declining at least 2% after 2022. Adding the non-CBD hospitality group with the largest shortfall among continuing declines provides a contrast within a recovering industry.

Peers are the same industry outside each case’s precinct. Starting count multiplied by one plus peer growth gives a benchmark; its gap from the observed count measures relative performance. Earlier comparisons, alternative decline cutoffs and a 2018 baseline test the findings.

Models predict two-year changes using current count, log(1 + count), previous two-year change, precinct and industry. Multiple linear regression (OLS) provides an interpretable starting point; a pruned regression tree allows thresholds and interactions; gradient boosting tests more flexible relationships. No-change carries forward the latest count, predicting zero change (Hyndman & Athanasopoulos, 2021).

Four expanding-window folds predict 2016, 2018, 2020 and 2022 using outcomes available at each origin. We select configurations by average validation mean absolute error (MAE). Root mean squared error (RMSE) gives larger errors more weight. The separate 2022–2024 test uses 207 common groups, covering over 99.9% of city counts. Checks by group size and city total assess practical usefulness.

## 5 Analysis and Results

### 5.1 Recovery has replaced only a small part of the loss

SME establishments fell from 15,506 in 2019 to 12,571 in 2022, then rose to 13,054 in 2024. The gain of 483 (+3.8%) recovered 16.5% of the earlier loss. The remaining shortfall is 2,452 establishments, or 15.8% of the 2019 count.

![city recovery](figures/city_recovery.png)

Figure 1. City-wide SME establishments, 2019–2024.

### 5.2 Recovery differs across precincts

All 13 precincts remain below 2019; eight grew after 2022. The CBD added 245 establishments, half the recent city gain, but holds 1,594 of the 2,452 remaining shortfall. East Melbourne has the largest percentage gap (20.0%). The CBD therefore dominates the scale of loss without having the steepest proportional decline.

Applying outside-CBD industry growth rates to its 2019 counts gives a 2024 benchmark of 7,663, against 7,485 observed. About 89% of its historical fall matches the decline implied by those rates. Much of the CBD’s shortfall thus reflects weakness shared by its industries elsewhere.

### 5.3 Hospitality growth coexists with continuing service-sector losses

Professional services and retail account for 1,057 lost establishments since 2019. After 2022, professional services lost another 26 while retail gained 76. Professional services, finance and administration together represent 48% of the city’s historical net loss, making service-sector recovery central to closing the gap.

Hospitality supplied 214 establishments, or 44% of the recent net gain. Across industries, gains of 601 were offset by losses of 118. The recovery therefore depends heavily on expansion in a few sectors while others continue to contract.

### 5.4 Five groups for closer attention

The screen identifies 64 groups with historical shortfalls and recent declines; 53 had fewer than 100 establishments in at least one baseline year. The five cases account for 876 lost establishments since 2019, or 35.7% of the city’s remaining shortfall (Table 2).

These cases lost another 114 establishments after 2022 while all other groups gained a net 597. Continuing losses amid city-wide growth strengthen their priority for investigation.

![priority bubble](figures/priority_bubble.png)

Figure 2. The 64 screened groups. Bubble area represents 2024 SME counts.

Professional services, construction and Southbank hospitality show weaker recovery than their industry peers (Figure 3).

| Group | 2019 | 2022 | 2024 | 2019–24 change | 2022–24 change |
| --- | --- | --- | --- | --- | --- |
| CBD professional services | 1,788 | 1,383 | 1,338 | -450 | -45 |
| CBD finance and insurance | 719 | 554 | 534 | -185 | -20 |
| CBD administrative services | 381 | 243 | 219 | -162 | -24 |
| CBD construction | 141 | 111 | 96 | -45 | -15 |
| Southbank hospitality | 236 | 212 | 202 | -34 | -10 |

Table 2. SME counts. Hospitality refers to Accommodation and Food Services.

![recent peer comparison](figures/recent_peer_comparison.png)

Figure 3. Local and same-industry peer growth, 2022–2024.

CBD professional services has the largest shortfall: 450 establishments, including 428 Small establishments. Its recent decline of 3.3% contrasts with peer growth of 2.8%. CBD construction fell 13.5% while peers grew 13.9%; its entire historical shortfall of 45 is in the Small category. Matching peer growth would leave these groups roughly 84 and 30 establishments above their observed counts, respectively.

Southbank hospitality fell 4.7% while peers grew 9.0%. Excluding the CBD still leaves peer growth of 4.7%, so the contrast extends beyond one large precinct. Its benchmark is 231 establishments, 29 above the observed 202. Local trading conditions deserve attention within an otherwise recovering industry.

CBD finance and administration fell 3.6% and 9.9%, while peers fell faster: 10.3% and 13.3%. Their losses matter, but the wider sector decline changes the diagnosis. Finance’s Small category lost 204 establishments from 2019 while Medium gained 19, directing attention to smaller operators within that sector.

### 5.5 Earlier comparisons put recent weakness in context

CBD professional services already lagged peers in 2017–2019: it fell 3.5% while peers grew 2.9%. Underperformance was visible before the pandemic. Southbank hospitality grew 14.6% against peers’ 3.2% before the pandemic, then declined as peers recovered. These cases suggest different questions: recurring location pressures versus a reversal in local trading conditions (Figure A1).

### 5.6 Testing the case selection

The four core cases remain at 1%, 2% and 3% decline cutoffs. A 2018 baseline retains CBD professional services, finance and administration; North Melbourne professional services and Docklands hospitality replace construction and Southbank. The first three are consistent priorities across baselines. Construction and Southbank remain useful peer contrasts, with selection more dependent on the starting year.

### 5.7 Predictive models do not improve on the benchmark

No-change has the lowest mean validation MAE. The tree and OLS have slightly lower validation RMSE, but no-change performs best on both measures in the separate 2022–2024 test (Table 3).

| Model | Validation MAE | Validation RMSE | Test MAE | Test RMSE |
| --- | --- | --- | --- | --- |
| No change | 6.95 | 20.04 | 5.13 | 15.45 |
| Pruned tree | 7.44 | 19.46 | 5.77 | 20.91 |
| Gradient boosting | 7.30 | 20.73 | 5.85 | 22.22 |
| OLS | 7.42 | 19.88 | 6.17 | 20.22 |

Table 3. Prediction errors in establishments per group. Lower values are better.

Around 80% of test groups changed by five or fewer establishments, favouring the no-change benchmark. Its MAE rises from 5.13 overall to 24.25 among the 24 groups starting with at least 100 establishments, although it still beats the fitted models. The CBD contributes 91% of its squared error.

The test sample gained 481 establishments. No-change predicted zero; fitted models predicted losses of 193–418. Low average group error therefore did not translate into a useful forecast of city recovery. Observed shortfalls and peer comparisons provide the stronger basis for our shortlist.

MAE weights every group equally. Reporting errors for large groups and city totals exposes weaknesses that the overall average conceals.

## 6 Key Findings and Recommendations

### 6.1 Key findings

CBD professional services combines scale with repeated underperformance against peers. Construction and Southbank hospitality also lag recovering industries. Finance and administration share wider sector decline, calling for attention across precincts.

### 6.2 Recommendations

Give small CBD professional-services practices first priority for targeted business advice and client-networking support (City of Melbourne, 2021, pp. 18–21). They account for 428 of the group’s 450-establishment shortfall, and the group remains selected under both baselines.

For CBD construction, explore procurement connections and advice on accessing project opportunities for small contractors. Their continuing decline, alongside peer growth, supports a local focus on access to work.

For Southbank hospitality, consider precinct promotion or activation tied to local trading conditions (City of Melbourne, 2021, pp. 18–21). Its decline while hospitality expands elsewhere gives a clear reason to investigate local demand before selecting an activity.

For finance and administration, coordinate business advice through industry bodies across precincts. Faster declines among peers suggest that CBD-only promotion would address too narrow a part of the problem.

## 7 Limitations and Future Work

### 7.1 Limitations

CLUE counts locations, not firms. Changes combine openings, closures, relocations and size-category movements, so they cannot identify firm survival. Unpublished cells remain unknown, and the survey cycle limits annual comparisons. Peer benchmarks establish relative performance; identifying its causes requires additional evidence.

### 7.2 Future work

Further research should explain why the locally weak groups diverge from recovering peers. For Southbank hospitality, compare pedestrian activity and, where available, spending with recovering precincts to assess whether weaker demand accompanies establishment losses. For CBD construction, examine project approvals and procurement opportunities alongside contractor counts. Interviews with small professional-services practices would distinguish client-demand pressures from rent costs or relocation decisions. These findings would help choose support that addresses the pressures businesses actually face.

For forecasting, test whether demand indicators improve two-year predictions using the same time-ordered validation and no-change benchmark. Only information available at the prediction date should enter each model. Assess large-group errors and city-wide growth alongside MAE, since the current benchmark missed the rebound. Later CLUE releases would provide a fresh test and show whether the five cases still warrant attention.

## 8 References and Supporting Material

City of Melbourne. (n.d.-a). Business establishments and jobs data by business size and ANZSIC in small areas [Data set]. DataVic. Course-supplied snapshot, 2002–2024. [Aggregated dataset and category definitions](https://discover.data.vic.gov.au/dataset/business-establishments-and-jobs-data-by-business-size-and-anzsic-in-small-areas)

City of Melbourne. (n.d.-b). Business establishments location and industry classification [Data set]. DataVic. Course-supplied snapshot, 2002–2024. [Address dataset](https://discover.data.vic.gov.au/dataset/business-establishments-location-and-industry-classification)

City of Melbourne. (n.d.-c). CLUE definitions. Sections 12 and 34. [CLUE definitions](https://www.melbourne.vic.gov.au/media/1159/download?inline)

[City of Melbourne. (2021). Economic Development Strategy 2031.](https://mvga-prod-files.s3.ap-southeast-4.amazonaws.com/public/SiteCollectionDocuments/economic-development-strategy-2031.pdf)

Hyndman, R. J., & Athanasopoulos, G. (2021). Forecasting: Principles and Practice (3rd ed.). OTexts. Chapter 5. [Forecasting benchmarks and evaluation](https://otexts.com/fpp3/toolbox.html)

[OpenAI. (2026). Codex [AI coding assistant].](https://chatgpt.com/codex)

### Project repository

[Group 10 data, reproducible R code and supporting outputs](https://github.com/wayne-232/CMCE30005--Group10)

Figures and tables are Group 10 calculations from the supplied CLUE files. Supporting code, screening results and model outputs accompany the report.

### Appendix A Historical context and sensitivity checks

![pre recent comparison](figures/pre_recent_comparison.png)

Figure A1. Peer-relative growth before and after the pandemic. Negative values indicate slower local growth.

Table A1. Checks on the interpretation and case selection.

| Check | Result |
| --- | --- |
| Recent-decline cutoff | The four core cases remain at 1%, 2% and 3%; membership changes at 0% and 5%. |
| 2018 historical baseline | Three of five cases remain. Southbank’s historical hospitality gap falls from 14.4% to 1.9%. |
| Hospitality peers without the CBD | Peer growth remains positive at 4.7%, against Southbank’s 4.7% decline. |
| Matched construction peers | Restricting peers to precincts observed at both endpoints changes growth from 13.9% to 13.3%; interpretation is unchanged. |
| Non-employing establishments | Including this category preserves all precinct and industry directions for 2019–2024; three recent directions change. |

### Appendix B Precinct and industry detail

![precinct changes](figures/precinct_changes.png)

Figure B1. Historical gaps and recent growth by precinct.

### Appendix B Precinct and industry detail (continued)

![industry heatmap](figures/industry_heatmap.png)

Figure B2. Recent SME growth across precincts and industries.

### AI acknowledgement

Codex (OpenAI, 2026) assisted with code review, brainstorming and editing for this final report. Group 10 takes full responsibility for the submitted content. Code-development assistance is recorded in the project repository.
