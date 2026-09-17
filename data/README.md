# Project data

Both raw CSVs are included in this folder, unchanged from the group's existing
course snapshot. Download the repository ZIP or clone the repository to obtain
the data and code together. The larger file may not display a preview on GitHub.

## Files and provenance

- [business-establishments-and-jobs-data-by-business-size-and-anzsic.csv](business-establishments-and-jobs-data-by-business-size-and-anzsic.csv)
  contains 13,353 rows and 6 columns (946,127 bytes).
  [LMS attachment](https://canvas.lms.unimelb.edu.au/courses/251386/files/28229148):
  Modules → Project Data Set 3: Business Establishment Melbourne.
- [business-establishments-with-address-and-industry-classification.csv](business-establishments-with-address-and-industry-classification.csv)
  contains 413,550 rows and 12 columns (79,271,999 bytes, 75.6 MiB).
  [LMS attachment](https://canvas.lms.unimelb.edu.au/courses/251386/files/28229149):
  the same project module.

The LMS filenames and displayed sizes were checked on 17 September 2026.
A fresh download was blocked by the browser, so the upload uses the existing
local copies used in the validated analysis. A byte-for-byte comparison with a
fresh LMS download was not possible. Their MD5 checksums match the previously
recorded [source manifest](../outputs/tables/employing_only/file_manifest.csv):

- Aggregated file: `092490f73fa22c83c82d95d1ccd7e010`
- Address file: `84f61da018f6d302999bb447e4036708`

## Attribution and use

Data publisher: City of Melbourne, Census of Land Use and Employment (CLUE).
The published [aggregated dataset](https://discover.data.vic.gov.au/dataset/business-establishments-and-jobs-data-by-business-size-and-anzsic-in-small-areas)
and [address dataset](https://discover.data.vic.gov.au/dataset/business-establishments-location-and-industry-classification)
provide the source definitions and licence information. Both datasets are
published under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/).
No endorsement by the City of Melbourne is implied.

Keep these files unchanged. Cleaning and sample selection take place in R.
Do not substitute a newer download without checking its coverage and rerunning
the analysis. Some public metadata describe an older date range; the supplied
files used here cover 2002–2024.
