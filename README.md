# CDISC pilot trial: SDTM to ADaM to safety tables, with independent QC

A safety reanalysis of the CDISC pilot study (CDISCPILOT01), a 26-week placebo-controlled trial of a xanomeline skin
patch in mild to moderate Alzheimer's disease. The data are public and were released by CDISC for training.

I built this to work the way a statistical programmer in a pharma company or CRO works: raw SDTM in, ADaM datasets
out to a written spec, tables and figures from the ADaM, and a second independent program that has to agree with the first.

**Interactive report:** https://bymankirat.github.io/cdisc-pilot-analysis/

## What's in it

| Step | Script | What it does |
|---|---|---|
| ADSL | `R/01_adsl.R` | One row per subject: first/last dose, treatment duration, safety and ITT flags, age groups, disposition, baseline weight/BMI. Built with `{admiral}`. |
| ADAE, ADVS, ADLB | `R/02_adae_advs_adlb.R` | Adverse events with date imputation and a treatment-emergent flag; vital-sign change from baseline; lab results against reference ranges. |
| ADTTE | `R/03_adtte.R` | Time to first dermatologic event (skin disorders or application-site reactions), censored 30 days after the last dose. |
| Tables and figures | `R/04_tables.R` | Demographics, disposition, AE overview, AEs by body system and preferred term, vital signs over time, lab shift tables, Kaplan–Meier, log-rank and Cox model. |
| SQL | `R/05_sql.R` | The ADaM datasets in DuckDB, queried with joins, grouping and a window function. |
| QC | `R/06_qc.R` | An independent base-R rebuild of key ADSL and ADAE variables from SDTM, compared with `{diffdf}`; structural checks; `{testthat}` unit tests; comparison with the pharmaverse reference ADSL. |
| Export | `R/07_export.R` | ADaM datasets as CSV in `adam/` and the report data in `docs/results.js`. |

Variable-level derivations are in `specs/` (ADSL, ADAE, ADTTE).

## Main findings

- Most subjects on xanomeline stopped early, mainly because of adverse events. Placebo subjects mostly completed.
- Skin and application-site reactions (pruritus, erythema, dermatitis at the patch site) account for most of the difference between arms.
- In the time-to-event analysis, a first skin event comes sooner and more often on either dose than on placebo (Cox hazard ratios and log-rank test in the report).

Exact numbers are in the report and are regenerated on every run.

## Run it

R 4.3 or newer.

```r
install.packages(c("admiral", "pharmaversesdtm", "pharmaverseadam", "dplyr", "tidyr", "stringr",
                   "survival", "duckdb", "DBI", "diffdf", "jsonlite", "testthat"))
```

Then open `run_all.R` in RStudio and click **Source**, or run `Rscript run_all.R`. It takes under a minute and
rewrites `docs/results.js`, `adam/*.csv` and `qc/diffdf_adsl.txt`. Open `docs/index.html` to see the report.

## Limits

This is a training reanalysis, not the sponsor's analysis. It covers safety only; the efficacy endpoints (ADAS-Cog,
CIBIC+) are not included. Some choices, such as the 30-day treatment-emergent window and the dermatologic event
definition, are mine and are written down in the specs.

## Data

CDISC SDTM/ADaM Pilot Project data, as distributed in the `pharmaversesdtm` R package (Apache 2.0). No personal data.

Mankirat Singh · MSc Bioinformatics and Computational Biology, University College Cork
