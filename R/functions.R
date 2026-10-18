# Small, testable building blocks used by the derivations (unit-tested in tests/testthat).

ARMS <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")

# Age groups used in the CDISC pilot tables
agegr1 <- function(age) {
  dplyr::case_when(
    is.na(age) ~ NA_character_,
    age < 65 ~ "<65",
    age <= 80 ~ "65-80",
    TRUE ~ ">80"
  )
}

# Treatment-emergent: started on or after the first dose and no later than `window` days after the last dose
flag_teae <- function(astdt, trtsdt, trtedt, window = 30) {
  ok <- !is.na(astdt) & !is.na(trtsdt) & astdt >= trtsdt & (is.na(trtedt) | astdt <= trtedt + window)
  ifelse(ok, "Y", NA_character_)
}

# Reference-range indicator from a value and its limits
range_ind <- function(value, low, high) {
  dplyr::case_when(
    is.na(value) ~ NA_character_,
    !is.na(low) & value < low ~ "LOW",
    !is.na(high) & value > high ~ "HIGH",
    TRUE ~ "NORMAL"
  )
}

# Worst post-baseline category for a subject: HIGH beats LOW beats NORMAL
worst_ind <- function(ind) {
  ind <- ind[!is.na(ind)]
  if (!length(ind)) return(NA_character_)
  if ("HIGH" %in% ind) return("HIGH")
  if ("LOW" %in% ind) return("LOW")
  "NORMAL"
}

# Time to first event (days, start day = 1) with censoring
tte <- function(start, event, censor) {
  has_event <- !is.na(event) & !is.na(censor) & event <= censor
  end <- dplyr::if_else(has_event, event, censor)
  data.frame(AVAL = as.numeric(end - start) + 1, CNSR = ifelse(has_event, 0L, 1L))
}

# "n (x.x%)" text
n_pct <- function(n, N) ifelse(N > 0, sprintf("%d (%.1f%%)", n, 100 * n / N), "0")

# Blank strings to NA (base-R version, used by the independent QC so it does not depend on admiral)
blank_na <- function(x) { x[!is.na(x) & trimws(x) == ""] <- NA; x }

# Partial ISO date to Date, imputing a missing day or month as the first ("2014-03" -> 2014-03-01)
impute_first <- function(dtc) {
  d <- substr(blank_na(dtc), 1, 10)
  d <- ifelse(nchar(d) == 4, paste0(d, "-01-01"), ifelse(nchar(d) == 7, paste0(d, "-01"), d))
  as.Date(d, format = "%Y-%m-%d")
}

# Same values, treating two NAs as equal
same_value <- function(a, b) (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)

# Plain data frame: drops labels and other attributes so comparisons and database writes only see values
plain <- function(d) {
  d <- as.data.frame(d)
  d[] <- lapply(d, function(x) if (inherits(x, "Date")) structure(as.numeric(x), class = "Date") else as.vector(x))
  d
}
