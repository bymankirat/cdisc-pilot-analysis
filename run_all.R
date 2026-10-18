# Runs the whole analysis: SDTM -> ADaM -> tables and figures -> SQL -> independent QC -> report data.
# In RStudio: open this file and click Source. From a terminal: Rscript run_all.R

PROJECT_DIR <- tryCatch(dirname(rstudioapi::getSourceEditorContext()$path), error = function(e) "")
if (!nzchar(PROJECT_DIR)) {
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  PROJECT_DIR <- if (length(arg)) dirname(normalizePath(sub("^--file=", "", arg[1]))) else getwd()
}
PROJECT_DIR <- normalizePath(PROJECT_DIR)
if (!file.exists(file.path(PROJECT_DIR, "R", "01_adsl.R"))) stop("Could not find the project folder. setwd() to it first.")

needed <- c("admiral", "pharmaversesdtm", "dplyr", "tidyr", "stringr", "survival", "duckdb", "DBI", "diffdf",
            "jsonlite", "testthat")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Install these packages first, then run again:\n  install.packages(c(",
       paste0('"', missing, '"', collapse = ", "), "))", call. = FALSE)
}
if (!requireNamespace("pharmaverseadam", quietly = TRUE)) {
  message("Optional: install.packages(\"pharmaverseadam\") to compare ADSL with the pharmaverse reference datasets.")
}

suppressPackageStartupMessages({
  library(admiral); library(dplyr); library(tidyr); library(stringr)
})

t0 <- Sys.time()
for (f in c("functions.R", "01_adsl.R", "02_adae_advs_adlb.R", "03_adtte.R", "04_tables.R", "05_sql.R",
            "06_qc.R", "07_export.R")) {
  message("\n== ", f)
  source(file.path(PROJECT_DIR, "R", f), local = globalenv())
}
message("\nDone in ", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), " s. Open docs/index.html")
