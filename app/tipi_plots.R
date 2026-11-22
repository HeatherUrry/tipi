# Base-R charts for the TIPI app (base graphics keep the browser download small).

ACCENT    <- "#1F5F99"
INK       <- "#1D2433"
MUTED     <- "#5B6475"
GRID      <- "#9AA4B2"
BAND_COLS <- c("#EEF1F5", "#DCE2EA", "#DCE2EA", "#EEF1F5")

# Two-line versions of trait names for narrow screens. Side labels on the
# spider chart need the most horizontal room, so long single words are
# hyphenated there.
NARROW_LABELS <- c(
  Extraversion = "Extra-\nversion", Agreeableness = "Agree-\nableness",
  Conscientiousness = "Conscien-\ntiousness", `Emotional Stability` = "Emotional\nStability",
  Openness = "Openness", Neuroticism = "Neuroti-\ncism"
)

# Spider (radar) chart of percentiles. 0 at the centre, 100 at the rim,
# dashed ring = 50th percentile (the comparison group's average).
# The plot area widens automatically so trait names never get clipped.
plot_radar <- function(prof) {
  k   <- nrow(prof)
  ang <- pi / 2 - 2 * pi * (seq_len(k) - 1) / k        # first trait at top, clockwise
  v   <- pmin(pmax(prof$percentile, 0.5), 100) / 100
  pct <- format_percentile(prof$percentile)

  op <- par(mar = c(0, 0, 0, 0), xpd = NA, family = "sans")
  on.exit(par(op))
  plot.new()

  # Label layout. Labels sit at radius 1.1: the top one centred above its
  # spoke, the upper side ones pointing outward, the bottom ones hanging
  # below their spoke. Pick the largest text size (and how far the bottom
  # labels lean outward) that keeps the web reasonably big, measuring text
  # on the actual graphics device so it works on any screen.
  W     <- par("pin")[1]                               # plot width, inches
  r_lab <- 1.1
  lx    <- r_lab * cos(ang)
  ly    <- r_lab * sin(ang)
  pos   <- ifelse(sin(ang) > 0.9, "top", ifelse(sin(ang) < -0.5, "bottom", "side"))
  # On narrow screens, put trait names on two lines: two-word names split at
  # the space; long side labels are hyphenated (they limit the web's size).
  labs  <- prof$trait
  if (W < 4.5) {
    side_lab <- NARROW_LABELS[labs]
    labs <- ifelse(pos == "side" & !is.na(side_lab), side_lab, sub(" ", "\n", labs))
  }
  labs  <- unname(labs)
  nl    <- lengths(regmatches(labs, gregexpr("\n", labs))) + 1
  layout_for <- function(cex, lean) {
    Lin  <- pmax(strwidth(labs, units = "inches", cex = cex, font = 2),
                 strwidth(pct,        units = "inches", cex = cex, font = 2))
    hadj <- ifelse(pos == "top", 0.5,
            ifelse(pos == "side", ifelse(cos(ang) > 0, 0, 1),
                   ifelse(cos(ang) > 0, 0.5 - lean, 0.5 + lean)))
    # half-width X so every label's left and right edges fit inside [-X, X]
    need_r <- ifelse(lx > 0, lx / pmax(1 - 2 * (1 - hadj) * Lin / W, 0.05), 0)
    need_l <- ifelse(lx < 0, -lx / pmax(1 - 2 * hadj * Lin / W, 0.05), 0)
    X <- max(1.12, need_r, need_l) + 0.03
    Lu <- Lin * 2 * X / W                              # label widths in user units
    b  <- which(pos == "bottom")
    gap <- if (length(b) == 2) {
      r <- b[lx[b] > 0]; l <- b[lx[b] < 0]
      (lx[r] - hadj[r] * Lu[r]) - (lx[l] + (1 - hadj[l]) * Lu[l])
    } else Inf
    list(cex = cex, hadj = hadj, X = X, gap = gap, ok = gap > 0.12)
  }
  # For each text size, take the layout that shrinks the web least; among
  # equals, the least lean that still leaves clear space between the two
  # bottom labels. Use the largest text size that keeps X <= 1.8; else the
  # smallest X found.
  best <- NULL
  for (cex in seq(1, 0.66, by = -0.04)) {
    cands <- Filter(function(z) z$ok, lapply(c(0, 0.15, 0.3, 0.45),
                                             function(l) layout_for(cex, l)))
    if (!length(cands)) next
    Xs   <- vapply(cands, `[[`, numeric(1), "X")
    gaps <- vapply(cands, `[[`, numeric(1), "gap")
    tied <- which(Xs <= min(Xs) + 1e-6)
    roomy <- tied[gaps[tied] >= 0.3]
    pick <- cands[[if (length(roomy)) roomy[1] else tied[which.max(gaps[tied])]]]
    if (is.null(best) || pick$X < best$X - 1e-6) best <- pick
    if (best$X <= 1.8) break
  }
  cex <- best$cex; hadj <- best$hadj; X <- best$X

  # Line height from the font size (strheight() under-reports in the browser
  # build of R on high-density screens).
  lh_in <- 1.3 * cex * par("ps") / 72
  lh    <- lh_in * 2 * X / W                           # one text line, user units
  # vertical placement of the name block (nl lines) and the percentile line
  name_top <- ifelse(pos == "top", r_lab + (nl + 1) * lh,
              ifelse(pos == "side", ly + nl * lh, ly + 0.15 * lh))
  y_name   <- name_top - nl * lh / 2
  y_pct    <- name_top - nl * lh - lh / 2
  plot.window(xlim = c(-X, X),
              ylim = c(min(y_pct) - 0.6 * lh, max(name_top) + 0.1 * lh), asp = 1)

  for (r in c(0.25, 0.75, 1)) polygon(r * cos(ang), r * sin(ang), border = GRID, lwd = 1)
  segments(0, 0, cos(ang), sin(ang), col = GRID)
  polygon(0.5 * cos(ang), 0.5 * sin(ang), border = MUTED, lty = 2, lwd = 1.6)

  # Ring labels in the gap between the first two spokes. Each ring is a
  # pentagon, so along that line its edge is at r * cos(pi / k), not r; put
  # each label just outside its own ring's edge. Narrow screens show 50 and
  # 100 only, so the small labels don't crowd each other.
  a  <- (ang[1] + ang[2]) / 2
  rr <- if (W < 4.5) c(0.5, 1) else c(0.25, 0.5, 0.75, 1)
  d  <- rr * cos(pi / k) + 0.07
  text(d * cos(a), d * sin(a), format(rr * 100), col = MUTED, cex = 0.72 * cex)

  polygon(v * cos(ang), v * sin(ang), col = adjustcolor(ACCENT, 0.22), border = ACCENT, lwd = 3)
  points(v * cos(ang), v * sin(ang), pch = 21, bg = ACCENT, col = "white", cex = 1.7, lwd = 1.5)

  # trait name (line 1) and percentile (line 2) just outside the rim
  for (i in seq_len(k)) {
    text(lx[i], y_name[i], labs[i], adj = c(hadj[i], 0.5), font = 2, col = INK, cex = cex)
    text(lx[i], y_pct[i], pct[i], adj = c(hadj[i], 0.5), font = 2, col = ACCENT, cex = cex)
  }
}

# One horizontal 0-100 strip per trait, shaded into the four bands used by the
# Excel scorer (Low / Medium low / Medium high / High), with your marker.
plot_strips <- function(prof) {
  k <- nrow(prof); y <- rev(seq_len(k))
  edges <- c(0, BAND_CUTS, 100)

  op <- par(mar = c(2.6, 0.6, 0.4, 0.6), xpd = NA, family = "sans")
  on.exit(par(op))
  plot.new()
  W <- par("pin")[1]
  cex <- if (W < 5) 0.85 else 1
  plot.window(xlim = c(0, 100), ylim = c(0.55, k + 0.55), xaxs = "i")

  # Trait name (left) and percentile (right) share a line. On narrow screens
  # drop the word "percentile", then shrink the text, until every pair fits.
  pct <- format_percentile(prof$percentile)
  fits <- function(lab, cex) {
    all(strwidth(prof$trait, "inches", cex = cex, font = 2) +
        strwidth(lab, "inches", cex = 0.95 * cex, font = 2) + 0.15 <= W)
  }
  lab <- paste(pct, "percentile")
  if (!fits(lab, cex)) lab <- pct
  while (!fits(lab, cex) && cex > 0.65) cex <- cex - 0.05

  h <- 0.13
  for (i in seq_len(k)) {
    rect(edges[-5], y[i] - h, edges[-1], y[i] + h, col = BAND_COLS, border = NA)
    # band boundaries (16th and 84th) as ticks; dashed line at the 50th
    segments(BAND_CUTS[c(1, 3)], y[i] - h, BAND_CUTS[c(1, 3)], y[i] + h, col = MUTED, lwd = 1)
    segments(50, y[i] - h - 0.04, 50, y[i] + h + 0.04, col = MUTED, lty = 2)
    text(0, y[i] + 0.34, prof$trait[i], adj = c(0, 0.5), font = 2, col = INK, cex = cex)
    text(100, y[i] + 0.34, lab[i], adj = c(1, 0.5), col = ACCENT, font = 2, cex = 0.95 * cex)
    points(min(max(prof$percentile[i], 1), 99), y[i], pch = 21, bg = ACCENT, col = "white",
           cex = 2.1, lwd = 1.5)
  }
  mids <- (edges[-5] + edges[-1]) / 2
  text(mids, 0.42, BANDS, col = MUTED, cex = 0.82 * cex)
  text(0,   0.12, "0",   col = MUTED, cex = 0.75 * cex, adj = c(0, 0.5))
  text(50,  0.12, "50",  col = MUTED, cex = 0.75 * cex, adj = c(0.5, 0.5))
  text(100, 0.12, "100", col = MUTED, cex = 0.75 * cex, adj = c(1, 0.5))
}
