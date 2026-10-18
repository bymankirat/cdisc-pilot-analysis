# ADAE (adverse events), ADVS (vital signs) and ADLB (laboratory) for the safety population.

saf <- adsl %>% filter(SAFFL == "Y") %>% select(STUDYID, USUBJID, TRT01A, TRTSDT, TRTEDT, AGE, SEX)

# ---- ADAE ------------------------------------------------------------------------------------------------------
ae <- convert_blanks_to_na(pharmaversesdtm::ae)
adae <- ae %>%
  inner_join(saf, by = c("STUDYID", "USUBJID")) %>%
  derive_vars_dt(dtc = AESTDTC, new_vars_prefix = "AST", highest_imputation = "M", date_imputation = "first") %>%
  derive_vars_dt(dtc = AEENDTC, new_vars_prefix = "AEN") %>%
  mutate(
    TRTA = TRT01A,
    TRTEMFL = flag_teae(ASTDT, TRTSDT, TRTEDT, window = 30),
    ASTDY = as.numeric(ASTDT - TRTSDT) + 1,
    AREL = if_else(AEREL %in% c("POSSIBLE", "PROBABLE"), "RELATED", "NOT RELATED"),
    DERMFL = if_else(AEBODSYS %in% "SKIN AND SUBCUTANEOUS TISSUE DISORDERS" | str_detect(AEDECOD, "^APPLICATION SITE"), "Y", NA_character_)
  )

# ---- ADVS: mean of repeated measurements per visit, change from baseline -----------------------------------------
vs_params <- c(SYSBP = "Systolic blood pressure (mmHg)", DIABP = "Diastolic blood pressure (mmHg)",
               PULSE = "Pulse rate (beats/min)", WEIGHT = "Weight (kg)")
vs0 <- vs %>%
  filter(VSTESTCD %in% names(vs_params), !is.na(VSSTRESN)) %>%
  inner_join(saf %>% select(USUBJID, TRT01A), by = "USUBJID")
vs_base <- vs0 %>%
  filter(VSBLFL %in% "Y") %>%
  group_by(USUBJID, VSTESTCD) %>%
  summarise(BASE = mean(VSSTRESN), .groups = "drop")
advs <- vs0 %>%
  filter(str_detect(VISIT, "^WEEK")) %>%
  group_by(USUBJID, TRT01A, VSTESTCD, VISIT, VISITNUM) %>%
  summarise(AVAL = mean(VSSTRESN), .groups = "drop") %>%
  inner_join(vs_base, by = c("USUBJID", "VSTESTCD")) %>%
  mutate(PARAMCD = VSTESTCD, PARAM = unname(vs_params[VSTESTCD]), AVISIT = str_to_title(VISIT),
         AVISITN = as.numeric(str_extract(VISIT, "[0-9]+")), CHG = AVAL - BASE)

# ---- ADLB: reference-range category at baseline and worst after baseline ------------------------------------------
lb_tests <- c(ALT = "Alanine aminotransferase", AST = "Aspartate aminotransferase", BILI = "Bilirubin",
              CREAT = "Creatinine", GLUC = "Glucose", CHOL = "Cholesterol", HGB = "Haemoglobin", WBC = "Leukocytes")
lb <- convert_blanks_to_na(pharmaversesdtm::lb)
adlb <- lb %>%
  filter(LBTESTCD %in% names(lb_tests), !is.na(LBSTRESN)) %>%
  inner_join(saf %>% select(USUBJID, TRT01A), by = "USUBJID") %>%
  mutate(PARAMCD = LBTESTCD, ANRIND = range_ind(LBSTRESN, LBSTNRLO, LBSTNRHI),
         ABLFL = if_else(LBBLFL %in% "Y", "Y", NA_character_), POST = str_detect(VISIT, "^WEEK"))
lb_shift <- adlb %>%
  group_by(USUBJID, TRT01A, PARAMCD) %>%
  summarise(BNRIND = first(ANRIND[ABLFL %in% "Y"]), WORST = worst_ind(ANRIND[POST]), .groups = "drop") %>%
  filter(!is.na(BNRIND), !is.na(WORST))

message("ADAE: ", nrow(adae), " records (", sum(adae$TRTEMFL %in% "Y"), " treatment-emergent); ADVS: ", nrow(advs),
        " visit means; ADLB: ", nrow(adlb), " results")
