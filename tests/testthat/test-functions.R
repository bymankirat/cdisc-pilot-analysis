source(file.path("..", "..", "R", "functions.R"))

test_that("age groups follow the pilot cut-offs", {
  expect_equal(agegr1(c(50, 64, 65, 80, 81, NA)), c("<65", "<65", "65-80", "65-80", ">80", NA))
})

test_that("treatment-emergent window includes first dose and last dose + 30 days", {
  s <- as.Date("2014-01-10"); e <- as.Date("2014-03-01")
  d <- as.Date(c("2014-01-09", "2014-01-10", "2014-03-31", "2014-04-01", NA))
  expect_equal(flag_teae(d, s, e), c(NA, "Y", "Y", NA, NA))
  expect_equal(flag_teae(as.Date("2015-01-01"), s, as.Date(NA)), "Y")
})

test_that("reference-range indicator handles missing limits", {
  expect_equal(range_ind(c(1, 5, 10, NA, 3), c(2, 2, 2, 2, NA), c(8, 8, 8, 8, NA)),
               c("LOW", "NORMAL", "HIGH", NA, "NORMAL"))
})

test_that("worst category puts HIGH above LOW above NORMAL", {
  expect_equal(worst_ind(c("NORMAL", "LOW")), "LOW")
  expect_equal(worst_ind(c("LOW", "HIGH", NA)), "HIGH")
  expect_equal(worst_ind(c(NA, NA)), NA_character_)
})

test_that("time to event uses day 1 for first dose and censors after the window", {
  start <- as.Date(c("2014-01-01", "2014-01-01", "2014-01-01"))
  ev <- as.Date(c("2014-01-10", NA, "2014-05-01"))
  cn <- as.Date(c("2014-03-01", "2014-03-01", "2014-03-01"))
  r <- tte(start, ev, cn)
  expect_equal(r$AVAL, c(10, 60, 60))
  expect_equal(r$CNSR, c(0L, 1L, 1L))
})

test_that("partial dates are imputed to the first", {
  expect_equal(impute_first(c("2014-03", "2014", "2014-03-15", "", NA)),
               as.Date(c("2014-03-01", "2014-01-01", "2014-03-15", NA, NA)))
})

test_that("n (%) text", {
  expect_equal(n_pct(3, 12), "3 (25.0%)")
  expect_equal(n_pct(0, 0), "0")
})
