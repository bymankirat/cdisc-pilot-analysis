# Independent QC (double programming). In pharma, a second programmer rebuilds key variables from the raw SDTM
# without looking at the production code, and the two versions must match. Here the second version is written in
# base R (no admiral, no dplyr) and compared with the production datasets.

QC_DIR <- file.path(PROJECT_DIR, "qc")
dir.create(QC_DIR, showWarnings = FALSE)

# ---- 1. ADSL rebuilt from SDTM ------------------------------------------------------------------------------------
q_dm <- as.data.frame(pharmaversesdtm::dm)
q_ex <- as.data.frame(pharmaversesdtm::ex)
q_dm$ARMCD <- blank_na(q_dm$ARMCD)

q_valid <- with(q_ex, EXDOSE > 0 | (EXDOSE == 0 & grepl("PLACEBO", EXTRT)))
q_valid[is.na(q_valid)] <- FALSE
q_st <- as.Date(substr(blank_na(q_ex$EXSTDTC), 1, 10), format = "%Y-%m-%d")
q_en <- as.Date(substr(blank_na(q_ex$EXENDTC), 1, 10), format = "%Y-%m-%d")
by_subject <- function(dates, keep, fun) {
  ok <- keep & !is.na(dates)
  r <- tapply(as.numeric(dates[ok]), q_ex$USUBJID[ok], fun)
  structure(as.numeric(r), names = names(r), class = "Date")
}
q_sdt <- by_subject(q_st, q_valid, min)
q_edt <- by_subject(q_en, q_valid, max)

qc_adsl <- data.frame(USUBJID = q_dm$USUBJID, stringsAsFactors = FALSE)
qc_adsl$TRTSDT <- q_sdt[q_dm$USUBJID]
qc_adsl$TRTEDT <- q_edt[q_dm$USUBJID]
qc_adsl$TRTDURD <- as.numeric(qc_adsl$TRTEDT - qc_adsl$TRTSDT) + 1
qc_adsl$SAFFL <- ifelse(q_dm$USUBJID %in% q_ex$USUBJID[q_valid], "Y", "N")
qc_adsl$ITTFL <- ifelse(!is.na(q_dm$ARMCD) & !(q_dm$ARMCD %in% c("Scrnfail", "NOTASSGN")), "Y", "N")
qc_adsl$AGEGR1 <- ifelse(is.na(q_dm$AGE), NA, ifelse(q_dm$AGE < 65, "<65", ifelse(q_dm$AGE <= 80, "65-80", ">80")))
qc_adsl <- plain(qc_adsl)
rownames(qc_adsl) <- NULL

prod_adsl <- plain(adsl[, names(qc_adsl)])
m <- match(prod_adsl$USUBJID, qc_adsl$USUBJID)
qc_adsl_vars <- lapply(setdiff(names(qc_adsl), "USUBJID"), function(v) {
  s <- same_value(prod_adsl[[v]], qc_adsl[[v]][m])
  list(dataset = "ADSL", variable = v, compared = length(s), mismatches = sum(!s),
       example = if (any(!s)) prod_adsl$USUBJID[!s][1] else NA)
})

diffdf_issues <- NA
if (requireNamespace("diffdf", quietly = TRUE)) {
  dd <- diffdf::diffdf(prod_adsl, qc_adsl, keys = "USUBJID", suppress_warnings = TRUE)
  writeLines(capture.output(print(dd)), file.path(QC_DIR, "diffdf_adsl.txt"))
  diffdf_issues <- diffdf::diffdf_has_issues(dd)
}

# ---- 2. Treatment-emergent adverse events rebuilt from SDTM --------------------------------------------------------
q_ae <- as.data.frame(pharmaversesdtm::ae)
q_saf <- qc_adsl[qc_adsl$SAFFL == "Y", c("USUBJID", "TRTSDT", "TRTEDT")]
q_saf$ARM <- q_dm$ACTARM[match(q_saf$USUBJID, q_dm$USUBJID)]
q_ae <- merge(q_ae, q_saf, by = "USUBJID")
q_ae$ASTDT <- impute_first(q_ae$AESTDTC)
q_teae <- q_ae[!is.na(q_ae$ASTDT) & q_ae$ASTDT >= q_ae$TRTSDT &
               (is.na(q_ae$TRTEDT) | q_ae$ASTDT <= q_ae$TRTEDT + 30), ]

qc_teae <- lapply(ARMS, function(a) {
  prod_n <- length(unique(teae$USUBJID[teae$TRTA == a]))
  qc_n <- length(unique(q_teae$USUBJID[q_teae$ARM == a]))
  sql_n <- sql_teae$with_teae[sql_teae$arm == a]
  list(arm = a, production = prod_n, qc = qc_n, sql = if (length(sql_n)) as.integer(sql_n) else NA,
       records_production = sum(teae$TRTA == a), records_qc = sum(q_teae$ARM == a))
})

# every preferred term x arm cell of the AE table
p_pt <- teae %>% distinct(USUBJID, TRTA, AEDECOD) %>% count(AEDECOD, TRTA, name = "prod")
q_pt <- unique(q_teae[, c("USUBJID", "ARM", "AEDECOD")])
q_pt <- as.data.frame(table(AEDECOD = q_pt$AEDECOD, TRTA = q_pt$ARM), stringsAsFactors = FALSE)
q_pt <- q_pt[q_pt$Freq > 0, ]
pt_cmp <- merge(as.data.frame(p_pt), setNames(q_pt, c("AEDECOD", "TRTA", "qc")), all = TRUE)
pt_cmp$prod[is.na(pt_cmp$prod)] <- 0
pt_cmp$qc[is.na(pt_cmp$qc)] <- 0
qc_pt <- list(cells = nrow(pt_cmp), mismatches = sum(pt_cmp$prod != pt_cmp$qc))

# ---- 3. Rules every analysis dataset must follow --------------------------------------------------------------------
check <- function(name, ok) list(check = name, pass = isTRUE(ok))
qc_checks <- list(
  check("ADSL has one row per subject", !anyDuplicated(adsl$USUBJID)),
  check("Every safety subject has a first dose date", all(!is.na(adsl$TRTSDT[adsl$SAFFL == "Y"]))),
  check("Every ADTTE subject has a time and a censoring date", all(!is.na(adtte$AVAL) & !is.na(adtte$CNSDT))),
  check("First dose is never after last dose", all(adsl$TRTSDT <= adsl$TRTEDT, na.rm = TRUE)),
  check("Everyone in the safety population was randomised", all(adsl$ITTFL[adsl$SAFFL == "Y"] == "Y")),
  check("Every ADAE subject is in the safety population", all(adae$USUBJID %in% adsl$USUBJID[adsl$SAFFL == "Y"])),
  check("No treatment-emergent event starts before the first dose", all(teae$ASTDT >= teae$TRTSDT)),
  check("ADTTE times are positive", all(adtte$AVAL > 0, na.rm = TRUE)),
  check("ADTTE censoring flag is 0 or 1", all(adtte$CNSR %in% c(0L, 1L))),
  check("ADTTE has one row per safety subject", nrow(adtte) == sum(adsl$SAFFL == "Y") && !anyDuplicated(adtte$USUBJID)),
  check("Vital-sign change equals value minus baseline", isTRUE(all.equal(advs$CHG, advs$AVAL - advs$BASE)))
)

# ---- 4. Unit tests --------------------------------------------------------------------------------------------------
qc_tests <- NULL
if (requireNamespace("testthat", quietly = TRUE)) {
  tr <- as.data.frame(testthat::test_dir(file.path(PROJECT_DIR, "tests", "testthat"), reporter = "silent",
                                         stop_on_failure = FALSE))
  qc_tests <- lapply(seq_len(nrow(tr)), function(i) list(test = tr$test[i], expectations = tr$nb[i],
    passed = tr$passed[i], failed = tr$failed[i] + as.integer(isTRUE(tr$error[i]))))
}

# ---- 5. Comparison with the reference ADaM published by pharmaverse (optional) --------------------------------------
qc_reference <- NULL
if (requireNamespace("pharmaverseadam", quietly = TRUE)) {
  ref <- plain(pharmaverseadam::adsl)
  vars <- intersect(c("TRTSDT", "TRTEDT", "TRTDURD", "SAFFL", "EOSSTT"), names(ref))
  mm <- match(prod_adsl$USUBJID, ref$USUBJID)
  mine <- plain(adsl)
  qc_reference <- lapply(vars, function(v) {
    s <- same_value(mine[[v]], ref[[v]][mm])
    list(variable = v, compared = sum(!is.na(mm)), agree_pct = round(100 * mean(s[!is.na(mm)]), 1))
  })
}

# ---- 6. Things in the data worth knowing (not errors) -----------------------------------------------------------------
no_end <- adsl$USUBJID[adsl$SAFFL == "Y" & is.na(adsl$TRTEDT)]
switched <- adsl %>% filter(SAFFL == "Y", TRT01P != TRT01A) %>% count(TRT01P, TRT01A)
qc_notes <- list()
if (length(no_end)) qc_notes[[length(qc_notes) + 1]] <- paste0(length(no_end), " treated subject", if (length(no_end) > 1) "s have" else " has",
  " no exposure end date in EX (", paste(no_end, collapse = ", "), "). Their treatment-emergent window is left open and ADTTE censors them at end of study.")
if (nrow(switched)) qc_notes[[length(qc_notes) + 1]] <- paste0(sum(switched$n), " subjects received a different treatment from the one they were randomised to (",
  paste0(switched$n, " ", switched$TRT01P, " -> ", switched$TRT01A, collapse = "; "), "). Disposition uses the randomised arm; safety tables use the treatment received.")

qc <- list(notes = qc_notes, adsl_vars = qc_adsl_vars, diffdf_issues = diffdf_issues, teae = qc_teae, pt = qc_pt,
           checks = qc_checks, tests = qc_tests, reference = qc_reference)

n_bad <- sum(sapply(qc_adsl_vars, `[[`, "mismatches")) + qc_pt$mismatches + sum(!sapply(qc_checks, `[[`, "pass"))
message("QC: ", if (n_bad == 0) "production and independent versions agree" else paste(n_bad, "issues, see the report"))
