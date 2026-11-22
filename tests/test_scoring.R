# Checks for app/tipi_scoring.R. Run from the tipi_app folder:
#   Rscript tests/test_scoring.R
source("app/tipi_scoring.R")
norms <- load_norms("app/norms.csv")
ok <- function(cond, msg) { if (!isTRUE(cond)) stop("FAILED: ", msg, call. = FALSE); cat("ok -", msg, "\n") }

# ---- Norms table ----
ok(nrow(norms) == 2 * 6 * 5, "norms has 60 rows (2 sexes x 6 ages x 5 traits)")
ok(all(norms$sd > 0) && all(norms$mean >= 1 & norms$mean <= 7), "means within 1-7, SDs positive")
ok(sum(unique(norms[c("sex", "age_group", "n")])$n) == 278000, "total norm n = 278,000")

# ---- Scoring key ----
ok(all(score_tipi(c(7, 1, 7, 1, 7, 1, 7, 1, 7, 1)) == 7), "max pattern scores 7 on every trait")
ok(all(score_tipi(c(1, 7, 1, 7, 1, 7, 1, 7, 1, 7)) == 1), "min pattern scores 1 on every trait")
ok(all(score_tipi(rep(4, 10)) == 4), "all-4 responses score 4")
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

# ---- Percentiles ----
fem <- norms[norms$sex == "female" & norms$age_group == "15-20" & norms$trait == "Emotional Stability", ]
mal <- norms[norms$sex == "male"   & norms$age_group == "15-20" & norms$trait == "Emotional Stability", ]
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

for (gen in c("female", "male", "none")) for (age in c(AGE_GROUPS, "none")) {
  gg <- comparison_group(gen, age, norms)
  ps <- sapply(seq(1, 7, by = 0.5), function(s) percentile(s, "Openness", gg, norms))
  if (any(diff(ps) <= 0) || any(ps <= 0 | ps >= 100)) stop("FAILED: monotonic percentiles for ", gen, " ", age)
}
ok(TRUE, "percentiles strictly increase with score for every comparison group")
ok(abs(percentile(fem$mean, "Emotional Stability", comparison_group("female", "15-20", norms), norms) - 50) < 1e-9,
   "score at group mean = 50th percentile")

# ---- Bands and labels ----
ok(identical(band_label(c(10, 15.86, 15.88, 49.9, 50, 84.1, 84.2, 99)),
             c("Low", "Low", "Medium low", "Medium low", "Medium high", "Medium high", "High", "High")),
   "band cutoffs at 15.87 / 50 / 84.13 (mean -/+ 1 SD, like the Excel scorer)")
ok(identical(format_percentile(c(0.4, 1, 2.5, 11, 12, 13, 21, 22, 23, 50.4, 99.4, 99.6)),
             c("below 1st", "1st", "2nd", "11th", "12th", "13th", "21st", "22nd", "23rd", "50th", "99th", "above 99th")),
   "percentile labels")
prof <- tipi_profile(c(5, 2, 6, 3, 7, 4, 6, 2, 5, 1), "female", "15-20", norms)
ok(identical(prof$trait, TRAITS) && all(prof$score == c(4.5, 6, 6, 5, 7)), "tipi_profile scores")
cat(group_description("none", "none", norms), "\n")
cat("\nAll checks passed.\n")
