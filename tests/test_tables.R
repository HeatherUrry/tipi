# Checks the BUILT lookup tables (data.js) that the web page actually uses,
# cell by cell, against an independent calculation written here from the
# published specification (not from R/tipi_scoring.R) and the norm values
# extracted from the PDFs (tests/golden_norms.csv). Covers every comparison
# group x trait x possible score, so every possible answer set is covered:
# each trait's result depends only on its own two items (checked below).
#
# Run from the tipi_app folder after building:  Rscript tests/test_tables.R
# (build.R runs it on the freshly built tables before publishing them).
if (!exists("DATA_JS")) DATA_JS <- "docs/data.js"
ok <- function(cond, msg) { if (!isTRUE(cond)) stop("FAILED: ", msg, call. = FALSE); cat("ok -", msg, "\n") }

# ---- Read data.js exactly as the browser gets it --------------------------------
txt  <- paste(readLines(DATA_JS, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
json <- sub("^[\\s\\S]*?window\\.TIPI_DATA = ", "", txt, perl = TRUE)
json <- sub(";\\s*$", "", json)
D <- jsonlite::fromJSON(json, simplifyVector = TRUE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE)

# ---- The published specification, written out independently ---------------------
# tipi.pdf: Extraversion 1, 6R; Agreeableness 2R, 7; Conscientiousness 3, 8R;
# Emotional Stability 4R, 9; Openness to Experiences 5, 10R. Reversed = 8 - x.
SPEC_KEY <- list(Extraversion = c(1, 6), Agreeableness = c(7, 2), Conscientiousness = c(3, 8),
                 "Emotional Stability" = c(9, 4), "Openness to Experiences" = c(5, 10))
OCEAN <- c("Openness to Experiences", "Conscientiousness", "Extraversion", "Agreeableness",
           "Emotional Stability")
ok(identical(D$traits, OCEAN), "display order is OCEAN with Emotional Stability in N's place")
key_ok <- all(vapply(D$key, function(k)
  identical(as.numeric(c(k$item, k$item_rev)), as.numeric(SPEC_KEY[[k$trait]])), logical(1)))
items_used <- sort(as.numeric(unlist(lapply(D$key, function(k) c(k$item, k$item_rev)))))
ok(key_ok && length(D$key) == 5 && identical(items_used, as.numeric(1:10)),
   "scoring key matches tipi.pdf; each of the 10 items feeds exactly one trait")

# Every (item, reversed item) answer pair gives the right score and table index.
pairs_ok <- TRUE
for (a in 1:7) for (b in 1:7) {
  s <- (a + (8 - b)) / 2                      # mean of item and reversed item
  idx <- (s - 1) * 2 + 1                      # position in the 13 scores 1, 1.5, ..., 7
  if (!isTRUE(all.equal(D$scores[idx], s))) pairs_ok <- FALSE
}
ok(pairs_ok && identical(D$scores, seq(1, 7, by = 0.5)),
   "all 49 answer pairs map to the right score (1, 1.5, ..., 7)")

gold <- utils::read.csv("tests/golden_norms.csv", check.names = FALSE, stringsAsFactors = FALSE)
norm_rows <- function(sex, age, trait) {
  m <- gold[gold$sex == sex & gold$age_group == age & gold$stat == "mean", ]
  s <- gold[gold$sex == sex & gold$age_group == age & gold$stat == "sd", ]
  c(mean = m[[trait]], sd = s[[trait]], n = m$n)
}
# Comparison group: female or male = that sex; otherwise female and male weighted
# equally. Age band = that band; "none" = 15-20 and 21-30, weighted by n within sex.
components <- function(gender, age) {
  sexes <- if (gender %in% c("female", "male")) gender else c("female", "male")
  ages  <- if (age == "none") c("15-20", "21-30") else age
  out <- list()
  for (sx in sexes) {
    ns <- vapply(ages, function(a) norm_rows(sx, a, "Extraversion")[["n"]], numeric(1))
    for (j in seq_along(ages)) out[[length(out) + 1]] <-
      list(sex = sx, age = ages[j], w = ns[j] / sum(ns) / length(sexes), n = ns[j])
  }
  out
}
spec_pct <- function(score, trait, comps) {
  100 * sum(vapply(comps, function(cmp) {
    r <- norm_rows(cmp$sex, cmp$age, trait); cmp$w * pnorm((score - r[["mean"]]) / r[["sd"]])
  }, numeric(1)))
}
spec_mean <- function(trait, comps)
  sum(vapply(comps, function(cmp) cmp$w * norm_rows(cmp$sex, cmp$age, trait)[["mean"]], numeric(1)))
CUTS <- 100 * pnorm(c(-1, 0, 1))              # mean -/+ 1 SD
spec_band <- function(p) if (p < CUTS[1]) "Low" else if (p < CUTS[2]) "Medium low" else
                         if (p < CUTS[3]) "Medium high" else "High"
spec_label <- function(p) {
  if (p < 1) return("below 1st")
  if (p >= 99.5) return("above 99th")
  r <- floor(p + 0.5)                         # round half up, then stay inside the band's range
  r <- switch(spec_band(p), "Low" = min(r, 15), "Medium low" = min(max(r, 16), 49),
              "Medium high" = min(max(r, 50), 83), "High" = max(r, 84))
  suf <- if (r %% 100 %in% 11:13) "th" else c("th", "st", "nd", "rd", rep("th", 6))[r %% 10 + 1]
  paste0(r, suf)
}
spec_desc <- function(gender, age, comps) {
  who <- switch(gender, female = "female participants", male = "male participants", "participants")
  ages <- if (age == "none") "aged 15–30" else if (age == "61+") "aged 61 and older" else
    paste("aged", sub("-", "–", age))
  extra <- if (gender %in% c("female", "male")) "" else
    paste0(" (each percentile is the average of your percentile against the female norms",
           " and your percentile against the male norms)")
  paste0(who, " ", ages, extra, ", based on ",
         format(sum(vapply(comps, `[[`, numeric(1), "n")), big.mark = ","), " people")
}

# ---- Compare every cell -------------------------------------------------------------
genders <- c("female", "male", "other", "none")
ages    <- c("15-20", "21-30", "31-40", "41-50", "51-60", "61+", "none")
cells <- 0; bad <- character(0)
for (g in genders) for (a in ages) {
  grp <- D$groups[[paste(g, a, sep = "|")]]
  comps <- components(g, a)
  if (is.null(grp) || !identical(grp$description, spec_desc(g, a, comps)))
    bad <- c(bad, paste("description", g, a))
  for (t in OCEAN) {
    tr <- grp$traits[[t]]
    if (!identical(tr$mean, formatC(spec_mean(t, comps), format = "f", digits = 2)))
      bad <- c(bad, paste("mean", g, a, t))
    for (i in seq_along(D$scores)) {
      p <- spec_pct(D$scores[i], t, comps)
      cells <- cells + 1
      if (abs(tr$pct[i] - p) > 1e-4 || !identical(tr$label[i], spec_label(p)) ||
          !identical(tr$band[i], spec_band(p)))
        bad <- c(bad, sprintf("%s %s %s score %.1f: got %s/%s/%s, expected %.4f/%s/%s", g, a, t,
                              D$scores[i], tr$pct[i], tr$label[i], tr$band[i], p, spec_label(p), spec_band(p)))
    }
  }
}
if (length(bad)) cat(head(bad, 10), sep = "\n")
ok(length(bad) == 0 && cells == 1820 && length(D$groups) == 28,
   sprintf("all %d cells (28 groups x 5 traits x 13 scores), group averages, and descriptions match", cells))
cat("\nAll table checks passed.\n")
