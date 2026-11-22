# Scoring and norm comparison for the Ten-Item Personality Inventory (TIPI).
# Sourced by app.R and by tests/test_scoring.R.
# Nothing in this file saves, sends, or stores any data.

TRAITS <- c("Extraversion", "Agreeableness", "Conscientiousness",
            "Emotional Stability", "Openness")

# Item wording, in order, from tipi.pdf ("I see myself as: ...").
TIPI_ITEMS <- c(
  "Extraverted, enthusiastic.",
  "Critical, quarrelsome.",
  "Dependable, self-disciplined.",
  "Anxious, easily upset.",
  "Open to new experiences, complex.",
  "Reserved, quiet.",
  "Sympathetic, warm.",
  "Disorganized, careless.",
  "Calm, emotionally stable.",
  "Conventional, uncreative."
)

# Scoring key from tipi.pdf ("R" = reverse-scored as 8 - response):
#   Extraversion 1, 6R | Agreeableness 2R, 7 | Conscientiousness 3, 8R |
#   Emotional Stability 4R, 9 | Openness 5, 10R
# Each trait score is the mean of its two items (range 1 to 7).
TIPI_KEY <- data.frame(
  trait    = TRAITS,
  item     = c(1, 7, 3, 9, 5),
  item_rev = c(6, 2, 8, 4, 10)
)

score_tipi <- function(responses) {
  r <- suppressWarnings(as.numeric(responses))
  if (length(r) != 10 || anyNA(r) || any(!r %in% 1:7)) {
    stop("score_tipi() needs 10 responses, each a whole number from 1 to 7.")
  }
  stats::setNames((r[TIPI_KEY$item] + (8 - r[TIPI_KEY$item_rev])) / 2, TRAITS)
}

# ---- Norms -----------------------------------------------------------------

AGE_GROUPS  <- c("15-20", "21-30", "31-40", "41-50", "51-60", "61+")
COLLEGE_AGE <- c("15-20", "21-30")   # used when age is not given

# norms.csv mirrors the layout of TIPInormsFEMALE.pdf / TIPInormsMALE.pdf:
# one "mean" row and one "sd" row per sex x age group. Returns long format:
# one row per sex x age group x trait.
load_norms <- function(path = "norms.csv") {
  w <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  stopifnot(all(c("sex", "age_group", "stat", "n", TRAITS) %in% names(w)))
  m <- w[w$stat == "mean", ]
  s <- w[w$stat == "sd", ]
  stopifnot(identical(m$sex, s$sex), identical(m$age_group, s$age_group))
  do.call(rbind, lapply(TRAITS, function(t) {
    data.frame(sex = m$sex, age_group = m$age_group, trait = t,
               mean = m[[t]], sd = s[[t]], n = m$n)
  }))
}

# The comparison group is a set of norm groups ("components") with weights
# that sum to 1:
#   * Female or male: that sex only.
#   * Any other answer: female and male norms weighted equally, i.e., the
#     percentile is the average of the female and male percentiles.
#   * Age range given: that age group only.
#   * Age not given: the 15-20 and 21-30 groups, weighted by sample size.
comparison_group <- function(gender, age_group, norms) {
  sexes <- if (gender %in% c("female", "male")) gender else c("female", "male")
  ages  <- if (age_group %in% AGE_GROUPS) age_group else COLLEGE_AGE
  g <- unique(norms[norms$sex %in% sexes & norms$age_group %in% ages,
                    c("sex", "age_group", "n")])
  g$w <- stats::ave(g$n, g$sex, FUN = function(n) n / sum(n)) / length(sexes)
  rownames(g) <- NULL
  g
}

# Percentile = estimated % of the comparison group scoring below `score`,
# assuming normally distributed scores within each norm group.
percentile <- function(score, trait, group, norms) {
  nm <- merge(group, norms[norms$trait == trait, c("sex", "age_group", "mean", "sd")])
  100 * sum(nm$w * stats::pnorm(score, nm$mean, nm$sd))
}

# Mean of the comparison group (weighted across components).
group_mean <- function(trait, group, norms) {
  nm <- merge(group, norms[norms$trait == trait, c("sex", "age_group", "mean")])
  sum(nm$w * nm$mean)
}

# Same bands as the Excel scorer: mean -/+ 1 SD, i.e., the 16th and 84th
# percentiles of a normal distribution.
BAND_CUTS <- 100 * stats::pnorm(c(-1, 0, 1))   # 15.87, 50, 84.13
BANDS <- c("Low", "Medium low", "Medium high", "High")

band_label <- function(p) {
  as.character(cut(p, c(-Inf, BAND_CUTS, Inf), labels = BANDS, right = FALSE))
}

tipi_profile <- function(responses, gender, age_group, norms) {
  s <- score_tipi(responses)
  g <- comparison_group(gender, age_group, norms)
  p <- vapply(TRAITS, function(t) percentile(s[[t]], t, g, norms), numeric(1))
  data.frame(
    trait      = TRAITS,
    score      = unname(s),
    group_mean = vapply(TRAITS, function(t) group_mean(t, g, norms), numeric(1),
                        USE.NAMES = FALSE),
    percentile = unname(p),
    band       = band_label(unname(p)),
    stringsAsFactors = FALSE
  )
}

# ---- Labels ----------------------------------------------------------------

ordinal <- function(x) {
  x <- as.integer(x)
  suffix <- ifelse(x %% 100 %in% 11:13, "th",
                   c("th", "st", "nd", "rd", rep("th", 6))[x %% 10 + 1])
  paste0(x, suffix)
}

format_percentile <- function(p) {
  ifelse(p < 1, "below 1st", ifelse(p >= 99.5, "above 99th", ordinal(round(p))))
}

age_text <- function(age_group) {
  if (identical(age_group, "61+")) return("aged 61 and older")
  if (age_group %in% AGE_GROUPS) return(paste("aged", sub("-", "–", age_group)))
  "aged 15–30"
}

group_description <- function(gender, age_group, norms) {
  g <- comparison_group(gender, age_group, norms)
  who <- switch(gender, female = "female participants", male = "male participants",
                "participants")
  extra <- if (gender %in% c("female", "male")) "" else
    " (your percentile is the average of the female and male norms)"
  paste0(who, " ", age_text(age_group), extra,
         ", based on ", format(sum(g$n), big.mark = ","), " people")
}
