# Notes for interviews

Read this before you talk about the project. Every interviewer for a statistical programmer, clinical data or
biostatistics role will ask some of these.

## The standards in one minute

- **SDTM** (Study Data Tabulation Model): how raw trial data are organised for the regulator. One dataset per topic,
  called a domain: DM (demographics), EX (exposure, i.e. dosing), DS (disposition), AE (adverse events),
  VS (vital signs), LB (laboratory). It records what happened. It does not derive anything.
- **ADaM** (Analysis Data Model): datasets built from SDTM that are ready for analysis. Every variable has a written
  derivation, and every table should be producible with simple filtering and counting.
  - ADSL: one row per subject. Every other ADaM dataset merges from it.
  - BDS structure (ADVS, ADLB): one row per subject, parameter and visit, with AVAL, BASE and CHG.
  - OCCDS structure (ADAE): one row per event.
  - ADTTE: one row per subject and parameter, with AVAL (time) and CNSR (0 = event, 1 = censored).
- **TLFs**: tables, listings and figures, the outputs that go into the clinical study report.
- **Define-XML**: machine-readable metadata describing the datasets. My `specs/*.csv` are the human-readable
  version of the same idea.

## Derivations you should be able to explain

- **TRTSDT / TRTEDT.** First and last dose from EX, only counting valid doses (dose above zero, or zero for placebo).
  Partial times are imputed: start of day for the first dose, end of day for the last.
- **SAFFL.** Safety population: took at least one dose. **ITTFL**: randomised (not a screen failure).
- **Treatment-emergent.** Started on or after the first dose and up to 30 days after the last. The window is a
  choice made in the statistical analysis plan; 30 days is common, not universal.
- **Date imputation.** An AE recorded as "2014-03" gets 1 March. Imputing to the first is conservative here because it
  makes an event more likely to count as treatment-emergent.
- **Counting subjects, not events.** AE tables count each subject once per row. The denominator is the safety
  population of the arm (N in the column header), not the number with events.
- **Shift tables.** Baseline category against the worst post-baseline category. "Worst" is defined in the spec
  (HIGH above LOW here; for some tests a sponsor would prefer separate low and high tables).
- **Time to event.** Day 1 is the first dose. Without an event, the subject is censored at the end of the
  treatment-emergent window.

## Statistics in the report

- **Kaplan–Meier** estimates the probability of staying event-free over time while allowing for censoring.
- **Log-rank test** asks whether the curves differ overall.
- **Cox model** gives a hazard ratio for each dose against placebo. It assumes proportional hazards; you could check
  that with `cox.zph()` and mention it if asked about limits.
- High dropout on xanomeline matters: subjects who stop treatment early are censored early, so the event-free curves
  for the active arms rest on fewer people after a few months (see the numbers at risk).

## Why the QC section matters

In pharma, a dataset is not final until a second programmer has rebuilt it independently and the two versions match.
I wrote the second version in base R, without admiral or dplyr, so a bug in one approach is unlikely to be repeated
in the other. `diffdf` compares the two by subject. The structural checks catch impossible data (first dose after last
dose, an AE subject who isn't in the safety population). The unit tests pin down each small function.

If the comparison with the pharmaverse reference ADSL is below 100% for a variable, be ready to explain why
(different handling of screen failures, a different imputation rule). Being able to explain a difference is worth
more than a perfect number.

## Questions you might get

- *What's the difference between SDTM and ADaM?* SDTM records, ADaM analyses. ADaM is traceable back to SDTM.
- *Why one row per subject in ADSL?* So every analysis dataset can merge population flags and treatment from one place.
- *How do you handle a partial date?* Follow the SAP. Here: impute missing day or month to the first; leave missing years missing.
- *What if production and QC disagree?* Find the subjects, read both derivations against the spec, decide which is
  right, and if the spec is ambiguous, raise it with the lead statistician rather than guessing.
- *SAS or R?* Most legacy code is SAS, and the industry is moving to R (the FDA has accepted R-based submissions,
  and pharmaverse is backed by Roche, GSK, Novartis and others). I learned the standards in R; the logic carries over.

## What to do next with it

- Add the efficacy side: ADAS-Cog change from baseline with an ANCOVA (ADQSADAS in pharmaverseadam).
- Produce the tables as RTF/PDF with `{rtables}` or `{gtsummary}`, the format reviewers expect.
- Write a short Define-XML with `{metacore}` and `{xportr}`.
