# Write the analysis datasets as CSV and the results for the interactive report (docs/results.js).

ADAM_DIR <- file.path(PROJECT_DIR, "adam")
dir.create(ADAM_DIR, showWarnings = FALSE)
for (nm in c("adsl", "adae", "advs", "adtte")) {
  utils::write.csv(plain(get(nm)), file.path(ADAM_DIR, paste0(nm, ".csv")), row.names = FALSE, na = "")
}
utils::write.csv(plain(lb_shift), file.path(ADAM_DIR, "adlb_shift.csv"), row.names = FALSE, na = "")

read_spec <- function(f) {
  s <- utils::read.csv(f, stringsAsFactors = FALSE, check.names = FALSE)
  unname(lapply(seq_len(nrow(s)), function(i) as.list(s[i, ])))
}
spec_files <- list.files(file.path(PROJECT_DIR, "specs"), pattern = "_spec\\.csv$", full.names = TRUE)
specs <- setNames(lapply(spec_files, read_spec), toupper(sub("_spec\\.csv$", "", basename(spec_files))))

pkg_ver <- function(p) if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else NA
pkgs <- c("admiral", "pharmaversesdtm", "pharmaverseadam", "dplyr", "tidyr", "stringr", "survival", "duckdb",
          "DBI", "diffdf", "testthat", "jsonlite")

TRIAL <- list(
  meta = list(demo = FALSE, generated = format(Sys.time(), "%Y-%m-%d %H:%M"), r = R.version.string,
              packages = as.list(sapply(pkgs, pkg_ver)), study = unique(adsl$STUDYID)[1]),
  sdtm = as.list(sapply(list(DM = dm, EX = ex, DS = ds, AE = ae, VS = vs, LB = lb), nrow)),
  adam = list(ADSL = nrow(adsl), ADAE = nrow(adae), ADVS = nrow(advs), ADLB = nrow(adlb), ADTTE = nrow(adtte)),
  arms = ARMS,
  pops = pops,
  demog = demog,
  disposition = disposition,
  ae_overview = ae_overview,
  ae_soc = ae_soc,
  vs = vs_summary,
  vs_params = as.list(vs_params),
  lab_shift = lab_shift,
  tte = tte_res,
  sql = sql_queries,
  qc = qc,
  specs = specs
)

json <- jsonlite::toJSON(TRIAL, auto_unbox = TRUE, na = "null", null = "null", digits = NA, pretty = FALSE)
out <- file.path(PROJECT_DIR, "docs", "results.js")
writeLines(paste0("window.TRIAL = ", json, ";"), out, useBytes = TRUE)
message("Report data written: ", out, " (", round(file.size(out) / 1024), " KB)")
