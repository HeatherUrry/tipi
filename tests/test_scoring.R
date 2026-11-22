# Checks for app/tipi_scoring.R. Run from the tipi_app folder:
#   Rscript tests/test_scoring.R
source("app/tipi_scoring.R")
norms <- load_norms("app/norms.csv")
ok <- function(cond, msg) { if (!isTRUE(cond)) stop("FAILED: ", msg, call. = FALSE); cat("ok -", msg, "\n") }

# ---- Norms table -------------------------------------------------------------
# Golden values extracted from the text of TIPInormsMALE.pdf and
# TIPInormsFEMALE.pdf (independently of app/norms.csv), in the column order
# Extraversion, Agreeableness, Conscientiousness, Emotional Stability, Openness.
golden <- utils::read.csv(text = "sex,age_group,stat,n,E,A,C,ES,O
male,15-20,mean,54973,3.79,4.47,4.41,4.61,5.43
male,15-20,sd,54973,1.55,1.22,1.39,1.47,1.17
male,21-30,mean,40737,3.73,4.5,4.57,4.64,5.49
male,21-30,sd,40737,1.54,1.2,1.39,1.46,1.13
male,31-40,mean,14752,3.81,4.55,4.77,4.63,5.49
male,31-40,sd,14752,1.54,1.21,1.35,1.42,1.12
male,41-50,mean,7668,3.85,4.7,4.96,4.72,5.41
male,41-50,sd,7668,1.54,1.18,1.35,1.39,1.17
male,51-60,mean,3532,3.87,4.89,5.11,4.8,5.39
male,51-60,sd,3532,1.54,1.18,1.31,1.38,1.2
male,61+,mean,905,3.85,4.95,5.26,4.92,5.37
male,61+,sd,905,1.49,1.17,1.3,1.34,1.26
female,15-20,mean,79648,4.06,4.73,4.52,4.07,5.58
female,15-20,sd,79648,1.58,1.22,1.42,1.46,1.1
female,21-30,mean,46530,4.07,4.88,4.78,4.09,5.55
female,21-30,sd,46530,1.61,1.19,1.41,1.45,1.12
female,31-40,mean,15412,4.17,5.04,4.97,4.25,5.49
female,31-40,sd,15412,1.64,1.19,1.41,1.45,1.18
female,41-50,mean,8823,4.2,5.28,5.18,4.49,5.46
female,41-50,sd,8823,1.64,1.17,1.36,1.45,1.2
female,51-60,mean,4135,4.18,5.43,5.35,4.66,5.42
female,51-60,sd,4135,1.6,1.14,1.31,1.44,1.25
female,61+,mean,885,4.21,5.5,5.39,4.84,5.39
female,61+,sd,885,1.62,1.15,1.36,1.4,1.27", stringsAsFactors = FALSE)
names(golden)[5:9] <- TRAITS
mismatch <- 0
for (i in seq_len(nrow(golden))) for (t in TRAITS) {
  row <- norms[norms$sex == golden$sex[i] & norms$age_group == golden$age_group[i] & norms$trait == t, ]
  val <- if (golden$stat[i] == "mean") row$mean else row$sd
  if (nrow(row) != 1 || !isTRUE(all.equal(val, golden[[t]][i])) || row$n != golden$n[i]) mismatch <- mismatch + 1
}
ok(nrow(norms) == 60 && mismatch == 0, "all 120 norm means/SDs and 12 n's match the PDFs")
ok(sum(unique(norms[c("sex", "age_group", "n")])$n) == 278000, "total norm n = 278,000")

# ---- Scoring key -------------------------------------------------------------
ok(all(score_tipi(c(7, 1, 7, 1, 7, 1, 7, 1, 7, 1)) == 7), "max pattern scores 7 on every trait")
ok(all(score_tipi(c(1, 7, 1, 7, 1, 7, 1, 7, 1, 7)) == 1), "min pattern scores 1 on every trait")
ok(all(score_tipi(rep(4, 10)) == 4), "all-4 responses score 4")
ok(identical(unname(score_tipi(c(7, 4, 4, 4, 4, 4, 4, 4, 4, 4))), c(5.5, 4, 4, 4, 4)),
   "item 1 feeds Extraversion only")
ok(identical(unname(score_tipi(c(4, 4, 4, 4, 4, 4, 4, 4, 4, 7))), c(4, 4, 4, 4, 2.5)),
   "item 10 is reversed and feeds Openness only")
ok(inherits(try(score_tipi(c(rep(4, 9), NA)), silent = TRUE), "try-error"), "missing item is rejected")
ok(inherits(try(score_tipi(c(rep(4, 9), 8)), silent = TRUE), "try-error"), "out-of-range item is rejected")

# Independent re-implementation of excelscoreTIPI.xls (Sheet1 formulas):
# reversed items via LOOKUP 1..7 -> 7..1, then (item + reversed item) / 2.
excel_score <- function(b) {        # b[1..10] = cells B16..B25
  rev <- function(x) c(7, 6, 5, 4, 3, 2, 1)[x]
  c(Extraversion          = (b[1] + rev(b[6])) / 2,   # A34 = B16 + A28(rev B21)
    Agreeableness         = (rev(b[2]) + b[7]) / 2,   # A35 = A29(rev B17) + B22
    Conscientiousness     = (b[3] + rev(b[8])) / 2,   # A36 = B18 + A30(rev B23)
    `Emotional Stability` = (rev(b[4]) + b[9]) / 2,   # A37 = A31(rev B19) + B24
    Openness              = (b[5] + rev(b[10])) / 2)  # A38 = B20 + A32(rev B25)
}
set.seed(1)
resp <- matrix(sample(1:7, 10 * 20000, replace = TRUE), ncol = 10)
same <- apply(resp, 1, function(r) isTRUE(all.equal(score_tipi(r), excel_score(r))))
ok(all(same), "matches the Excel scorer on 20,000 random response sets")

# ---- Percentiles ---------------------------------------------------------------
fem <- norms[norms$sex == "female" & norms$age_group == "15-20" & norms$trait == "Emotional Stability", ]
pf <- percentile(5.5, "Emotional Stability", comparison_group("female", "15-20", norms), norms)
pm <- percentile(5.5, "Emotional Stability", comparison_group("male",   "15-20", norms), norms)
pn <- percentile(5.5, "Emotional Stability", comparison_group("none",   "15-20", norms), norms)
po <- percentile(5.5, "Emotional Stability", comparison_group("other",  "15-20", norms), norms)
ok(abs(pf - 100 * pnorm((5.5 - fem$mean) / fem$sd)) < 1e-9, "single group = pnorm z-score")
ok(round(pf, 1) == 83.6 && round(pm, 1) == 72.8, "worked example: ES 5.5 -> 83.6 (F), 72.8 (M)")
ok(abs(pn - (pf + pm) / 2) < 1e-9 && pn == po, "gender not given / other = average of F and M percentiles")

g <- comparison_group("female", "none", norms)
ok(setequal(g$age_group, COLLEGE_AGE) && abs(sum(g$w) - 1) < 1e-12, "age not given = 15-30 groups, weights sum to 1")
ok(abs(g$w[g$age_group == "15-20"] - 79648 / (79648 + 46530)) < 1e-12, "age groups weighted by n")
g2 <- comparison_group("none", "none", norms)
ok(nrow(g2) == 4 && abs(sum(g2$w) - 1) < 1e-12 && abs(sum(g2$w[g2$sex == "male"]) - 0.5) < 1e-12,
   "neither given = 4 groups, sexes weighted equally")

GENDERS <- c("female", "male", "other", "none"); AGES <- c(AGE_GROUPS, "none")
for (gen in GENDERS) for (age in AGES) for (t in TRAITS) {
  gg <- comparison_group(gen, age, norms)
  ps <- sapply(seq(1, 7, by = 0.5), function(s) percentile(s, t, gg, norms))
  if (any(diff(ps) <= 0) || any(ps <= 0 | ps >= 100)) stop("FAILED: monotonic percentiles for ", gen, " ", age, " ", t)
}
ok(TRUE, "percentiles strictly increase with score for every group and trait")
ok(abs(percentile(fem$mean, "Emotional Stability", comparison_group("female", "15-20", norms), norms) - 50) < 1e-9,
   "score at group mean = 50th percentile")

# Group averages and descriptions
ok(abs(group_mean("Openness", comparison_group("female", "61+", norms), norms) - 5.39) < 1e-12,
   "group average for a single group = its mean")
ok(abs(group_mean("Openness", comparison_group("none", "61+", norms), norms) - (5.39 + 5.37) / 2) < 1e-12,
   "group average with gender averaged = mean of the F and M means")
ok(grepl("based on 885 people", group_description("female", "61+", norms)) &&
   grepl("based on 1,790 people", group_description("other", "61+", norms)) &&
   grepl("aged 15–30", group_description("male", "none", norms)) &&
   grepl("based on 221,888 people", group_description("none", "none", norms)),
   "group descriptions report the right ages and n")

# ---- Bands and displayed percentiles ------------------------------------------
# Excel scorer logic: band by raw score vs mean -/+ 1 SD of the norm group.
excel_band <- function(s, m, sd) {
  if (s < m - sd) "Low" else if (s < m) "Medium low" else if (s < m + sd) "Medium high" else "High"
}
disagree <- 0
for (i in seq_len(nrow(norms))) for (s in seq(1, 7, by = 0.5)) {
  p <- 100 * pnorm(s, norms$mean[i], norms$sd[i])
  if (band_label(p) != excel_band(s, norms$mean[i], norms$sd[i])) disagree <- disagree + 1
}
ok(disagree == 0, "bands match the Excel scorer's mean -/+ 1 SD rule for all 780 single-group cases")

ok(identical(band_label(c(10, 15.86, 15.88, 49.9, 50, 84.1, 84.2, 99)),
             c("Low", "Low", "Medium low", "Medium low", "Medium high", "Medium high", "High", "High")),
   "band cutoffs at 15.87 / 50 / 84.13")
ok(identical(format_percentile(c(0.4, 1, 2.5, 11, 12, 13, 21, 22, 23, 50.4, 99.4, 99.6)),
             c("below 1st", "1st", "3rd", "11th", "12th", "13th", "21st", "22nd", "23rd", "50th", "99th", "above 99th")),
   "percentile labels (round half up)")
ok(identical(format_percentile(c(15.7, 15.9, 49.7, 50, 84.05, 84.2)),
             c("15th", "16th", "49th", "50th", "83rd", "84th")),
   "displayed percentile never contradicts its band near the cutoffs")

shown_lo <- c(Low = 0, `Medium low` = 16, `Medium high` = 50, High = 84)
shown_hi <- c(Low = 15, `Medium low` = 49, `Medium high` = 83, High = 100)
bad <- 0
for (gen in GENDERS) for (age in AGES) for (t in TRAITS) for (s in seq(1, 7, by = 0.5)) {
  p <- percentile(s, t, comparison_group(gen, age, norms), norms)
  d <- display_percentile(p); b <- band_label(p)
  if (d < shown_lo[[b]] || d > shown_hi[[b]] || abs(d - p) > 1) bad <- bad + 1
}
ok(bad == 0, "all 1,820 reachable results: shown percentile within 1 point and consistent with band")

prof <- tipi_profile(c(5, 2, 6, 3, 7, 4, 6, 2, 5, 1), "female", "15-20", norms)
ok(identical(prof$trait, TRAITS) && all(prof$score == c(4.5, 6, 6, 5, 7)), "tipi_profile scores")
ok(identical(prof$band, c("Medium high", "High", "High", "Medium high", "High")) &&
   identical(format_percentile(prof$percentile), c("61st", "85th", "85th", "74th", "90th")),
   "tipi_profile percentiles and bands (worked example)")
cat("\nAll checks passed.\n")
