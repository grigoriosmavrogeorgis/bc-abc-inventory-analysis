# ABC Inventory Analysis Tests

Object IDs 50000-50099, a block of its own so the app can share a sandbox with other GMSOFT test apps.

| Codeunit | Covers |
|---|---|
| 50000 "GSO ABC Analysis Tests" | Revenue calculation, class D, exclusions, apply to items and SKUs, history, counting policy, statistics |
| 50001 "GSO ABC Model Tests" | Usage Value and GMROII, thresholds and periods of every model, blocked and non-inventory items, setup defaults, apply for every model, history deletion |
| 50002 "GSO ABC Scheduled Run Tests" | RecalculateAllModels, the job queue codeunit, the job queue helper, upgrade tag registration, telemetry procedures |
| 50003 "GSO ABC Report Tests" | The dataset of all six reports, read from the XML output |
| 50004 "GSO ABC Page Tests" | Worksheet, parameter dialog, statistics factbox, Excel export, setup page, history pages, counting policy pages, item and SKU pages |
| 50010 "GSO ABC Test Library" | Shared test data helpers (not a test codeunit) |
| 50011 "GSO ABC Test Subscribers" | Manually bound subscribers that stop Excel downloads and task scheduling during tests |

Every test codeunit posts in a year of its own (2095 to 2099) and every test on a day of its own, so the
standard demo data and the entries of other tests never fall inside the analysis window.

Not covered: the install and upgrade triggers. They only run when the app is installed or upgraded and
cannot be called from a test. The procedures they call are covered in 50001 and 50002.
