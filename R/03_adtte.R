# ADTTE: time to first treatment-emergent dermatologic event (skin disorders or application-site reactions).
# Start = first dose; censored at last dose + 30 days (the same window used for "treatment-emergent").
# A few subjects have no exposure end date in EX: they are censored at their end-of-study date instead.

first_derm <- adae %>%
  filter(TRTEMFL %in% "Y", DERMFL %in% "Y", !is.na(ASTDT)) %>%
  group_by(USUBJID) %>%
  summarise(EVNTDT = min(ASTDT), EVNTDESC = first(AEDECOD[ASTDT == min(ASTDT)]), .groups = "drop")

adtte <- adsl %>%
  filter(SAFFL == "Y") %>%
  select(STUDYID, USUBJID, TRT01A, TRTSDT, TRTEDT, EOSDT, AGE, SEX) %>%
  left_join(first_derm, by = "USUBJID") %>%
  mutate(STARTDT = TRTSDT,
         CNSDT = coalesce(TRTEDT + 30, EOSDT, TRTSDT),
         CNSDTDSC = case_when(!is.na(TRTEDT) ~ "LAST DOSE + 30 DAYS", !is.na(EOSDT) ~ "END OF STUDY (NO LAST DOSE DATE)",
                              TRUE ~ "FIRST DOSE (NO LATER DATE)"))
adtte <- bind_cols(adtte, tte(adtte$STARTDT, adtte$EVNTDT, adtte$CNSDT)) %>%
  mutate(PARAMCD = "TTDE", PARAM = "Time to first dermatologic event (days)",
         TRTP = factor(TRT01A, levels = ARMS))

message("ADTTE: ", nrow(adtte), " subjects, ", sum(adtte$CNSR == 0), " with an event")
