# Everything the lightweight page needs, precomputed by R from the same
# scoring code the Shinylive app uses (app/tipi_scoring.R):
#   * the scoring key and display order,
#   * for every comparison group (gender x age option) and every trait, the
#     percentile, displayed label, and band for each possible score
#     (1, 1.5, ..., 7), plus the group average and the group description.
# The browser only adds up two item answers per trait and looks results up.
# Requires app/tipi_scoring.R.

LITE_GENDERS <- c("female", "male", "other", "none")
LITE_AGES    <- c(AGE_GROUPS, "none")
LITE_SCORES  <- seq(1, 7, by = 0.5)

lite_data <- function(norms) {
  groups <- list()
  for (g in LITE_GENDERS) for (a in LITE_AGES) {
    cg <- comparison_group(g, a, norms)
    traits <- lapply(TRAITS, function(t) {
      p <- vapply(LITE_SCORES, function(s) percentile(s, t, cg, norms), numeric(1))
      list(pct = round(p, 4), label = format_percentile(p), band = band_label(p),
           mean = formatC(group_mean(t, cg, norms), format = "f", digits = 2))
    })
    names(traits) <- TRAITS
    groups[[paste(g, a, sep = "|")]] <- list(description = group_description(g, a, norms),
                                              traits = traits)
  }
  list(
    traits = TRAITS,
    scores = LITE_SCORES,
    key    = lapply(seq_len(nrow(TIPI_KEY)), function(i)
      list(trait = TIPI_KEY$trait[i], item = TIPI_KEY$item[i], item_rev = TIPI_KEY$item_rev[i])),
    band_cuts = BAND_CUTS,
    bands     = BANDS,
    groups    = groups
  )
}

# Look up one result the way the browser does (used by the tests).
lite_lookup <- function(data, responses, gender, age) {
  r <- as.numeric(responses)
  sc <- vapply(data$key, function(k) (r[k$item] + 8 - r[k$item_rev]) / 2, numeric(1))
  names(sc) <- vapply(data$key, `[[`, "", "trait")
  grp <- data$groups[[paste(gender, age, sep = "|")]]
  do.call(rbind, lapply(data$traits, function(t) {
    i <- (sc[[t]] - 1) * 2 + 1
    tr <- grp$traits[[t]]
    data.frame(trait = t, score = sc[[t]], group_mean = tr$mean, percentile = tr$pct[i],
               label = tr$label[i], band = tr$band[i], stringsAsFactors = FALSE)
  }))
}
