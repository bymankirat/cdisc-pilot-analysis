# How to run this on your Mac

1. Unzip `cdisc-pilot-analysis.zip` in your home folder, so you have `/Users/mankiratsingh/cdisc-pilot-analysis`.

2. Open RStudio and paste this in the Console once (it takes a few minutes):

   ```r
   install.packages(c("admiral", "pharmaversesdtm", "pharmaverseadam", "dplyr", "tidyr", "stringr",
                      "survival", "duckdb", "DBI", "diffdf", "jsonlite", "testthat", "rstudioapi"))
   ```

3. In RStudio: File → Open File → `cdisc-pilot-analysis/run_all.R` → click **Source** (top right of the script).

   You should see one line per step, ending with something like:

   ```
   ADSL: 306 subjects, 254 in the safety population
   ...
   QC: production and independent versions agree
   Report data written: .../docs/results.js (60 KB)
   Done in 25 s. Open docs/index.html
   ```

4. Look at the report. In Terminal:

   ```
   open ~/cdisc-pilot-analysis/docs/index.html
   ```

   The yellow "Demo numbers" banner should be gone. If it's still there, the run didn't finish: copy the red error
   from the RStudio Console and send it to me.

5. If QC says there are issues, don't hide them. Open the QC section of the report and `qc/diffdf_adsl.txt` to see
   which subjects differ. Finding and explaining a difference is exactly what the job is.

## Put it on GitHub

```
cd ~/cdisc-pilot-analysis
git init
git add .
git commit -m "CDISC pilot: SDTM to ADaM, safety TLFs, survival, SQL and independent QC in R"
git branch -M main
git remote add origin https://github.com/bymankirat/cdisc-pilot-analysis.git
git push -u origin main
```

Create the empty repository on github.com first (no README). Then Settings → Pages → Deploy from branch → `main`,
folder `/docs`. The report will be at https://bymankirat.github.io/cdisc-pilot-analysis/ after a minute or two.

Everything here is public CDISC training data, so the whole folder, including `adam/`, is fine to upload.
