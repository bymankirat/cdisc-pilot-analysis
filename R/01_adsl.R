# ADSL: one row per subject (CDISC ADaM subject-level dataset), built from SDTM DM, EX and DS with {admiral}.

dm <- convert_blanks_to_na(pharmaversesdtm::dm)
ds <- convert_blanks_to_na(pharmaversesdtm::ds)
ex <- convert_blanks_to_na(pharmaversesdtm::ex)

# Exposure start and end as datetimes (time imputed: start of day for start, end of day for end)
ex_ext <- ex %>%
  derive_vars_dtm(dtc = EXSTDTC, new_vars_prefix = "EXST") %>%
  derive_vars_dtm(dtc = EXENDTC, new_vars_prefix = "EXEN", time_imputation = "last")

valid_dose <- rlang::expr((EXDOSE > 0 | (EXDOSE == 0 & str_detect(EXTRT, "PLACEBO"))))

adsl <- dm %>%
  mutate(TRT01P = ARM, TRT01A = ACTARM) %>%
  # first and last dose
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (!!valid_dose) & !is.na(EXSTDTM),
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    order = exprs(EXSTDTM, EXSEQ), mode = "first",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (!!valid_dose) & !is.na(EXENDTM),
    new_vars = exprs(TRTEDTM = EXENDTM, TRTETMF = EXENTMF),
    order = exprs(EXENDTM, EXSEQ), mode = "last",
    by_vars = exprs(STUDYID, USUBJID)
  ) %>%
  derive_vars_dtm_to_dt(source_vars = exprs(TRTSDTM, TRTEDTM)) %>%
  mutate(TRTDURD = as.numeric(TRTEDT - TRTSDT) + 1) %>%
  # safety population: received at least one dose
  derive_var_merged_exist_flag(
    dataset_add = ex,
    by_vars = exprs(STUDYID, USUBJID),
    new_var = SAFFL,
    condition = !!valid_dose,
    false_value = "N",
    missing_value = "N"
  ) %>%
  mutate(
    ITTFL = if_else(!is.na(ARMCD) & !ARMCD %in% c("Scrnfail", "NOTASSGN"), "Y", "N"),
    AGEGR1 = agegr1(AGE)
  )

# End-of-study status and reason from DS
disp <- ds %>%
  filter(DSCAT == "DISPOSITION EVENT") %>%
  arrange(USUBJID, DSSEQ) %>%
  group_by(USUBJID) %>%
  slice_tail(n = 1) %>%
  ungroup() %>%
  transmute(
    USUBJID,
    EOSSTT = case_when(DSDECOD == "COMPLETED" ~ "COMPLETED",
                       DSDECOD == "SCREEN FAILURE" ~ NA_character_,
                       TRUE ~ "DISCONTINUED"),
    DCSREAS = if_else(EOSSTT == "DISCONTINUED", DSDECOD, NA_character_),
    EOSDT = as.Date(substr(DSSTDTC, 1, 10))
  )
adsl <- adsl %>% left_join(disp, by = "USUBJID")

# Baseline height, weight and BMI from VS (records flagged as baseline)
vs <- convert_blanks_to_na(pharmaversesdtm::vs)
bl_vs <- vs %>%
  filter(VSTESTCD %in% c("HEIGHT", "WEIGHT"), !is.na(VSSTRESN)) %>%
  group_by(USUBJID, VSTESTCD) %>%
  summarise(v = if (any(VSBLFL %in% "Y")) mean(VSSTRESN[VSBLFL %in% "Y"]) else first(VSSTRESN), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = VSTESTCD, values_from = v)
adsl <- adsl %>%
  left_join(bl_vs %>% transmute(USUBJID, HEIGHTBL = HEIGHT, WEIGHTBL = WEIGHT), by = "USUBJID") %>%
  mutate(BMIBL = round(WEIGHTBL / (HEIGHTBL / 100)^2, 1))

message("ADSL: ", nrow(adsl), " subjects, ", sum(adsl$SAFFL == "Y"), " in the safety population")
