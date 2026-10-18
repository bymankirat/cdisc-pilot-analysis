# The same analysis datasets queried with SQL (DuckDB, in memory). One of these queries is also used by the QC step.

# shared_home = FALSE: newer duckdb versions otherwise ask to create ~/.duckdb on first use
con <- tryCatch(DBI::dbConnect(duckdb::duckdb(shared_home = FALSE)), error = function(e) DBI::dbConnect(duckdb::duckdb()))
DBI::dbWriteTable(con, "adsl", plain(adsl %>% select(USUBJID, TRT01P, TRT01A, SAFFL, ITTFL, AGE, AGEGR1, SEX, RACE,
                                                     TRTSDT, TRTEDT, TRTDURD, EOSSTT, DCSREAS)), overwrite = TRUE)
DBI::dbWriteTable(con, "adae", plain(adae %>% select(USUBJID, TRTA, AEBODSYS, AEDECOD, AESEV, AESER, AREL,
                                                     TRTEMFL, ASTDT, ASTDY)), overwrite = TRUE)
DBI::dbWriteTable(con, "adtte", plain(adtte %>% select(USUBJID, TRT01A, AVAL, CNSR)), overwrite = TRUE)

sql_queries <- list(
  list(title = "Safety population by arm",
       why = "Head count, age and time on treatment in one pass.",
       sql = "SELECT TRT01A AS arm,
       COUNT(*) AS subjects,
       ROUND(AVG(AGE), 1) AS mean_age,
       ROUND(AVG(TRTDURD), 1) AS mean_days_on_treatment
FROM adsl
WHERE SAFFL = 'Y'
GROUP BY TRT01A
ORDER BY arm"),
  list(title = "Subjects with a treatment-emergent adverse event",
       why = "A LEFT JOIN keeps subjects with no events in the denominator. The QC step checks this against R.",
       sql = "SELECT a.TRT01A AS arm,
       COUNT(DISTINCT e.USUBJID) AS with_teae,
       COUNT(DISTINCT a.USUBJID) AS safety_n,
       ROUND(100.0 * COUNT(DISTINCT e.USUBJID) / COUNT(DISTINCT a.USUBJID), 1) AS pct
FROM adsl a
LEFT JOIN adae e ON a.USUBJID = e.USUBJID AND e.TRTEMFL = 'Y'
WHERE a.SAFFL = 'Y'
GROUP BY a.TRT01A
ORDER BY arm"),
  list(title = "Ten most common adverse events",
       why = "Counts subjects, not events: one person with the same rash three times counts once.",
       sql = "SELECT AEDECOD AS preferred_term,
       COUNT(DISTINCT USUBJID) AS subjects
FROM adae
WHERE TRTEMFL = 'Y'
GROUP BY AEDECOD
ORDER BY subjects DESC, preferred_term
LIMIT 10"),
  list(title = "Why subjects left the study",
       why = "Grouped disposition by randomised arm, the source of the disposition table.",
       sql = "SELECT TRT01P AS arm,
       COALESCE(DCSREAS, 'COMPLETED') AS reason,
       COUNT(*) AS subjects
FROM adsl
WHERE ITTFL = 'Y' AND EOSSTT IS NOT NULL
GROUP BY 1, 2
ORDER BY arm, subjects DESC"),
  list(title = "First adverse event for each subject",
       why = "A window function (ROW_NUMBER) picks one row per subject, the SQL version of group_by + slice.",
       sql = "SELECT USUBJID, arm, AEDECOD AS first_event, ASTDY AS study_day
FROM (
  SELECT USUBJID, TRTA AS arm, AEDECOD, ASTDY,
         ROW_NUMBER() OVER (PARTITION BY USUBJID ORDER BY ASTDT, AEDECOD) AS rn
  FROM adae
  WHERE TRTEMFL = 'Y'
)
WHERE rn = 1
ORDER BY study_day, USUBJID
LIMIT 10"),
  list(title = "Dermatologic events in the time-to-event dataset",
       why = "Event counts and median day of the event, a quick check on the Kaplan-Meier input.",
       sql = "SELECT TRT01A AS arm,
       COUNT(*) AS subjects,
       COUNT(*) FILTER (WHERE CNSR = 0) AS events,
       MEDIAN(AVAL) FILTER (WHERE CNSR = 0) AS median_day_of_event
FROM adtte
GROUP BY TRT01A
ORDER BY arm")
)

as_rows <- function(r) {
  m <- as.matrix(data.frame(lapply(r, function(x) ifelse(is.na(x), "", as.character(x))), check.names = FALSE))
  unname(lapply(seq_len(nrow(m)), function(i) unname(m[i, ])))
}
sql_teae <- NULL
for (i in seq_along(sql_queries)) {
  r <- DBI::dbGetQuery(con, sql_queries[[i]]$sql)
  if (i == 2) sql_teae <- r
  sql_queries[[i]]$cols <- names(r)
  sql_queries[[i]]$rows <- as_rows(r)
}
DBI::dbDisconnect(con, shutdown = TRUE)

message("SQL: ", length(sql_queries), " queries run in DuckDB")
