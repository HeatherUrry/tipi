# One-page PDF of a student's results, drawn with base R graphics.
# Called by the app's download button. The file is created inside the
# student's browser and handed straight to them; nothing is saved or sent.

write_results_pdf <- function(file, prof, group_text, date = Sys.Date(), ocean_note = NULL) {
  # WinAnsi encoding covers the en dash, middle dot, and curly apostrophe used here.
  grDevices::pdf(file, width = 8.5, height = 11, family = "Helvetica",
                 encoding = "WinAnsi.enc", title = "My TIPI results")
  on.exit(grDevices::dev.off(), add = TRUE)

  graphics::par(oma = c(0.5, 0.6, 0.5, 0.6))
  graphics::layout(matrix(1:5, ncol = 1), heights = c(1.05, 3.6, 2.85, 1.55, 1.55))

  # 1. Header
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new(); graphics::plot.window(c(0, 1), c(0, 1))
  graphics::text(0, 0.86, "My Big Five personality profile", adj = c(0, 0.5),
                 font = 2, cex = 2, col = INK)
  graphics::text(0, 0.56, paste0("Ten-Item Personality Inventory (TIPI)  ·  ",
                                 format(date, "%B %d, %Y")),
                 adj = c(0, 0.5), cex = 1.05, col = MUTED)
  graphics::text(0, 0.24, paste0("Compared with ", group_text, "."),
                 adj = c(0, 0.5), cex = 0.95, col = INK)

  # 2. Spider chart  3. Percentile strips (same drawings as on screen)
  plot_radar(prof)
  plot_strips(prof)

  # 4. Table
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new(); graphics::plot.window(c(0, 1), c(0, 1))
  cols  <- c(0, 0.36, 0.53, 0.72, 0.84)
  heads <- c("Trait", "Your score (1–7)", "Group average", "Percentile", "Range")
  y0 <- 0.93; dy <- 0.155
  graphics::text(cols, y0, heads, adj = c(0, 0.5), font = 2, cex = 0.9, col = MUTED)
  graphics::segments(0, y0 - dy / 2, 1, y0 - dy / 2, col = GRID)
  for (i in seq_len(nrow(prof))) {
    y <- y0 - i * dy
    graphics::text(cols, y,
                   c(prof$trait[i], formatC(prof$score[i], format = "f", digits = 1),
                     formatC(prof$group_mean[i], format = "f", digits = 2),
                     format_percentile(prof$percentile[i]), prof$band[i]),
                   adj = c(0, 0.5), cex = 0.95, col = INK, font = c(2, 1, 1, 2, 1))
  }

  # 5. Notes and sources
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new(); graphics::plot.window(c(0, 1), c(0, 1))
  paras <- c(
    ocean_note,
    paste("A percentile is the estimated percentage of the comparison group who scored below you",
          "(people with exactly your score count as half). The 50th is average. Percentiles assume a",
          "bell-shaped distribution, so results near the ends of the 1–7 scale are approximate. With",
          "two items per trait, the TIPI is a quick snapshot, not a precise measurement. Higher isn't",
          "better: each trait has advantages and disadvantages at both ends."),
    paste("TIPI: Gosling, Rentfrow, & Swann (2003), Journal of Research in Personality, 37(6),",
          "504–528. Norms: Gosling, Rentfrow, & Potter (2014), unpublished data. Made at",
          "heatherurry.io/tipi — nothing you entered was saved or sent.")
  )
  # Wrap each paragraph to the page width, measured on this device.
  wrap_to_width <- function(txt, cex) {
    words <- strsplit(txt, " ")[[1]]; out <- character(0); line <- ""
    for (w in words) {
      cand <- if (nzchar(line)) paste(line, w) else w
      if (graphics::strwidth(cand, "user", cex = cex) > 1 && nzchar(line)) {
        out <- c(out, line); line <- w
      } else line <- cand
    }
    c(out, line)
  }
  cex_notes <- 0.76
  lines <- unlist(lapply(paras, wrap_to_width, cex = cex_notes))
  graphics::text(0, seq(0.95, 0.05, length.out = length(lines)), lines,
                 adj = c(0, 0.5), cex = cex_notes, col = MUTED)
}
