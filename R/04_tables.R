# Tables, listings and figures (as data for the report): populations, demographics, disposition, adverse events,
# vital signs, laboratory shifts and time to first dermatologic event.

arm_n <- function(d) sapply(ARMS, function(a) sum(d$TRT01A == a, na.rm = TRUE))   # as treated
arm_np <- function(d) sapply(ARMS, function(a) sum(d$TRT01P == a, na.rm = TRUE))  # as randomised
safety <- adsl %>% filter(SAFFL == "Y")
N_saf <- arm_n(safety)

# ---- populations ------------------------------------------------------------------------------------------------
pops <- list(
  screened = nrow(adsl),
  screen_failures = sum(adsl$ITTFL == "N"),
  randomised = as.list(arm_np(adsl %>% filter(ITTFL == "Y"))),
  safety = as.list(N_saf),
  completed = as.list(arm_np(adsl %>% filter(ITTFL == "Y", EOSSTT %in% "COMPLETED"))),
  switched = sum(safety$TRT01P != safety$TRT01A, na.rm = TRUE),
  no_last_dose = sum(safety$SAFFL == "Y" & is.na(safety$TRTEDT))
)

# ---- demographics (safety population) ----------------------------------------------------------------------------
# Upper-case CDISC terms to readable labels ("BLACK OR AFRICAN AMERICAN" -> "Black or African American")
nice_label <- function(x) {
  x <- str_to_sentence(tolower(x))
  for (w in c("African American", "American Indian", "Alaska Native", "Native Hawaiian", "Pacific Islander", "Asian",
              "Hispanic", "Latino")) x <- gsub(w, w, x, ignore.case = TRUE)
  x
}
cont_rows <- function(var, label, digits = 1) {
  f <- function(x) {
    x <- x[!is.na(x)]
    c(sprintf("%d", length(x)), sprintf(paste0("%.", digits, "f (%.", digits + 1, "f)"), mean(x), sd(x)),
      sprintf(paste0("%.", digits, "f"), median(x)), sprintf(paste0("%.", digits, "f, %.", digits, "f"), min(x), max(x)))
  }
  stats <- c("n", "Mean (SD)", "Median", "Min, Max")
  cols <- c(lapply(ARMS, function(a) f(safety[[var]][safety$TRT01A == a])), list(f(safety[[var]])))
  lapply(seq_along(stats), function(i) list(section = label, stat = stats[i],
    values = c(setNames(lapply(cols[seq_along(ARMS)], `[`, i), ARMS), list(Total = cols[[length(cols)]][i]))))
}
cat_rows <- function(var, label, levels = NULL, relabel = NULL) {
  lv <- if (is.null(levels)) sort(unique(na.omit(safety[[var]]))) else levels
  lapply(lv, function(l) {
    v <- lapply(ARMS, function(a) { d <- safety[safety$TRT01A == a, ]; n_pct(sum(d[[var]] %in% l), nrow(d)) })
    shown <- if (!is.null(relabel) && l %in% names(relabel)) relabel[[l]] else nice_label(l)
    list(section = label, stat = shown, values = c(setNames(v, ARMS),
      list(Total = n_pct(sum(safety[[var]] %in% l), nrow(safety)))))
  })
}
demog <- c(cont_rows("AGE", "Age (years)"), cat_rows("AGEGR1", "Age group", c("<65", "65-80", ">80")),
           cat_rows("SEX", "Sex", c("F", "M"), c(F = "Female", M = "Male")),cat_rows("RACE", "Race"), cat_rows("ETHNIC", "Ethnicity"),
           cont_rows("WEIGHTBL", "Baseline weight (kg)"), cont_rows("BMIBL", "Baseline BMI (kg/m²)"))

# ---- disposition (randomised, by planned arm) -------------------------------------------------------------------
rand <- adsl %>% filter(ITTFL == "Y")
disposition <- rand %>%
  mutate(STATUS = coalesce(if_else(EOSSTT == "COMPLETED", "Completed", str_to_sentence(tolower(DCSREAS))), "Ongoing")) %>%
  count(ARM = TRT01P, STATUS) %>%
  group_by(ARM) %>% mutate(pct = round(100 * n / sum(n), 1)) %>% ungroup()

# ---- adverse events -----------------------------------------------------------------------------------------------
teae <- adae %>% filter(TRTEMFL %in% "Y")
subj_pct <- function(d, cond_rows = NULL) {
  sapply(ARMS, function(a) {
    s <- unique(d$USUBJID[d$TRTA == a]); round(100 * length(s) / N_saf[[a]], 1)
  })
}
subj_n <- function(d) sapply(ARMS, function(a) length(unique(d$USUBJID[d$TRTA == a])))
ae_overview <- lapply(list(
  list("Any treatment-emergent adverse event", teae),
  list("Related (possible or probable)", teae %>% filter(AREL == "RELATED")),
  list("Severe", teae %>% filter(AESEV %in% "SEVERE")),
  list("Serious", teae %>% filter(AESER %in% "Y")),
  # AEACN is not filled in this study, so withdrawal comes from the disposition record (DS) instead
  list("Left the study because of an adverse event", safety %>% filter(DCSREAS %in% "ADVERSE EVENT") %>% transmute(USUBJID, TRTA = TRT01A)),
  list("Dermatologic (skin or application site)", teae %>% filter(DERMFL %in% "Y"))
), function(x) list(label = x[[1]], n = as.list(subj_n(x[[2]])), pct = as.list(subj_pct(x[[2]]))))

soc_pt <- teae %>%
  distinct(USUBJID, TRTA, AEBODSYS, AEDECOD) %>%
  count(AEBODSYS, AEDECOD, TRTA) %>%
  tidyr::complete(tidyr::nesting(AEBODSYS, AEDECOD), TRTA = ARMS, fill = list(n = 0)) %>%
  mutate(pct = round(100 * n / N_saf[TRTA], 1))
soc_tot <- teae %>% distinct(USUBJID, TRTA, AEBODSYS) %>% count(AEBODSYS, TRTA) %>%
  tidyr::complete(AEBODSYS, TRTA = ARMS, fill = list(n = 0)) %>% mutate(pct = round(100 * n / N_saf[TRTA], 1))
ae_soc <- lapply(split(soc_tot, soc_tot$AEBODSYS), function(s) {
  pts <- soc_pt %>% filter(AEBODSYS == s$AEBODSYS[1])
  pt_list <- lapply(split(pts, pts$AEDECOD), function(p) list(pt = p$AEDECOD[1],
    n = as.list(setNames(p$n, p$TRTA)[ARMS]), pct = as.list(setNames(p$pct, p$TRTA)[ARMS])))
  pt_list <- pt_list[order(-sapply(pt_list, function(p) sum(unlist(p$n))))]
  list(soc = s$AEBODSYS[1], n = as.list(setNames(s$n, s$TRTA)[ARMS]), pct = as.list(setNames(s$pct, s$TRTA)[ARMS]),
       pts = unname(pt_list))
})
ae_soc <- unname(ae_soc[order(-sapply(ae_soc, function(s) sum(unlist(s$n))))])

# ---- vital signs: mean change from baseline -------------------------------------------------------------------
vs_summary <- advs %>%
  group_by(PARAMCD, PARAM, TRT01A, AVISITN) %>%
  summarise(n = n(), mean = mean(CHG), se = sd(CHG) / sqrt(n()), .groups = "drop") %>%
  filter(n >= 3) %>%
  mutate(across(c(mean, se), ~ round(.x, 2)))

# ---- laboratory shift tables -------------------------------------------------------------------------------------
cats <- c("LOW", "NORMAL", "HIGH")
lab_shift <- lapply(names(lb_tests), function(tc) {
  d <- lb_shift %>% filter(PARAMCD == tc)
  list(test = tc, label = unname(lb_tests[tc]), arms = lapply(setNames(ARMS, ARMS), function(a) {
    x <- d %>% filter(TRT01A == a)
    lapply(setNames(cats, cats), function(b) as.list(sapply(cats, function(w) sum(x$BNRIND == b & x$WORST == w))))
  }))
})

# ---- time to first dermatologic event ----------------------------------------------------------------------------
fit <- survival::survfit(survival::Surv(AVAL, 1 - CNSR) ~ TRTP, data = adtte, conf.type = "log-log")
sf <- summary(fit, censored = TRUE)
strata <- sub("^TRTP=", "", as.character(sf$strata))
km <- lapply(ARMS, function(a) {
  i <- strata == a
  list(arm = a, time = c(0, sf$time[i]), surv = round(c(1, sf$surv[i]), 4),
       lower = round(c(1, sf$lower[i]), 4), upper = round(c(1, sf$upper[i]), 4),
       nrisk = c(N_saf[[a]], sf$n.risk[i]), event = c(0, sf$n.event[i]), censor = c(0, sf$n.censor[i]))
})
lr <- survival::survdiff(survival::Surv(AVAL, 1 - CNSR) ~ TRTP, data = adtte)
cox <- summary(survival::coxph(survival::Surv(AVAL, 1 - CNSR) ~ TRTP, data = adtte))
hr <- lapply(seq_len(nrow(cox$conf.int)), function(i) list(
  arm = sub("^TRTP", "", rownames(cox$conf.int)[i]), hr = round(cox$conf.int[i, 1], 2),
  lo = round(cox$conf.int[i, 3], 2), hi = round(cox$conf.int[i, 4], 2), p = signif(cox$coefficients[i, 5], 3)))
tte_res <- list(km = km, logrank_p = signif(1 - pchisq(lr$chisq, length(lr$n) - 1), 3), hr = hr,
                events = as.list(sapply(ARMS, function(a) sum(adtte$CNSR[adtte$TRT01A == a] == 0))),
                median = as.list(sapply(ARMS, function(a) { m <- summary(fit)$table[paste0("TRTP=", a), "median"]; if (is.na(m)) NA else m })))

message("Tables done: ", length(demog), " demographic rows, ", length(ae_soc), " body systems")
