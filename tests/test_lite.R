# Checks that the lightweight page's precomputed tables reproduce the
# Shinylive app's results exactly. Run from the tipi_app folder:
#   Rscript tests/test_lite.R
source("app/tipi_scoring.R")
source("lite/lite_data.R")
norms <- load_norms("app/norms.csv")
ok <- function(cond, msg) { if (!isTRUE(cond)) stop("FAILED: ", msg, call. = FALSE); cat("ok -", msg, "\n") }

data <- lite_data(norms)
ok(length(data$groups) == length(LITE_GENDERS) * length(LITE_AGES) &&
   all(vapply(data$groups, function(g) identical(names(g$traits), TRAITS), logical(1))) &&
   all(vapply(data$groups, function(g) all(vapply(g$traits, function(t) length(t$pct) == 13 &&
       length(t$label) == 13 && length(t$band) == 13, logical(1))), logical(1))),
   "tables cover every gender x age option, trait, and score")

# Round-trip through JSON exactly as the page receives it.
json <- jsonlite::toJSON(data, auto_unbox = TRUE, digits = NA)
back <- jsonlite::fromJSON(json, simplifyVector = TRUE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE)
ok(identical(back$traits, TRAITS) && length(back$key) == 5, "JSON keeps the trait order and scoring key")

set.seed(2)
bad <- 0
for (k in 1:3000) {
  resp <- sample(1:7, 10, replace = TRUE)
  gen  <- sample(LITE_GENDERS, 1); age <- sample(LITE_AGES, 1)
  want <- tipi_profile(resp, gen, age, norms)
  got  <- lite_lookup(back, resp, gen, age)
  same <- identical(got$trait, want$trait) && all(got$score == want$score) &&
          identical(got$label, format_percentile(want$percentile)) &&
          identical(got$band, want$band) &&
          identical(got$group_mean, formatC(want$group_mean, format = "f", digits = 2)) &&
          all(abs(got$percentile - want$percentile) < 1e-4)
  if (!same) bad <- bad + 1
}
ok(bad == 0, "lookups match the app's results for 3,000 random answer sets and groups")
ok(identical(back$groups[["none|none"]]$description, group_description("none", "none", norms)),
   "group descriptions come from the same R function")
cat("\nAll lightweight-page checks passed.\n")
