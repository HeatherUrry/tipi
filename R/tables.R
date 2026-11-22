# The lookup tables the web page uses, precomputed by R from the scoring code
# in R/tipi_scoring.R:
#   * the scoring key and display order,
#   * for every comparison group (gender x age option) and every trait, the
#     percentile, displayed label, and band for each possible score
#     (1, 1.5, ..., 7), plus the group average and the group description.
# The browser only adds up two item answers per trait and looks results up.
# Requires R/tipi_scoring.R.

TABLE_GENDERS <- c("female", "male", "other", "none")
TABLE_AGES    <- c(AGE_GROUPS, "none")
TABLE_SCORES  <- seq(1, 7, by = 0.5)

tipi_tables <- function(norms) {
  groups <- list()
  for (g in TABLE_GENDERS) for (a in TABLE_AGES) {
    cg <- comparison_group(g, a, norms)
    traits <- lapply(TRAITS, function(t) {
      p <- vapply(TABLE_SCORES, function(s) percentile(s, t, cg, norms), numeric(1))
      list(pct = round(p, 4), label = format_percentile(p), band = band_label(p),
           mean = formatC(group_mean(t, cg, norms), format = "f", digits = 2))
    })
    names(traits) <- TRAITS
    groups[[paste(g, a, sep = "|")]] <- list(description = group_description(g, a, norms),
                                              traits = traits)
  }
  list(
    traits = TRAITS,
    scores = TABLE_SCORES,
    key    = lapply(seq_len(nrow(TIPI_KEY)), function(i)
      list(trait = TIPI_KEY$trait[i], item = TIPI_KEY$item[i], item_rev = TIPI_KEY$item_rev[i])),
    band_cuts = BAND_CUTS,
    bands     = BANDS,
    groups    = groups
  )
}
