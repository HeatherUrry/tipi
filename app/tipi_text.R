# Shared wording and page sections for both versions of the TIPI app:
#   * the Shinylive app (app.R), where R runs in the browser, and
#   * the lightweight page (build_lite.R), where R precomputes everything.
# Keeping the text here means the two versions can't drift apart.
# Uses htmltools only (no Shiny), so it works in plain R too.
# Requires TRAITS from tipi_scoring.R.

# Who serves the web pages, for the privacy notice. Change this (and the
# loading text in build.R) if you host the site somewhere other than GitHub Pages.
HOST_NAME <- "GitHub Pages (a service of GitHub, Inc.)"

# Sources. Links open in a new tab and send no referrer.
TIPI_PAGE <- "https://gosling.psy.utexas.edu/scales-weve-developed/ten-item-personality-measure-tipi/"
TIPI_NOTE <- paste0(TIPI_PAGE, "a-note-on-alpha-reliability-and-factor-structure-in-the-tipi/")
TIPI_DOI  <- "https://doi.org/10.1016/S0092-6566(03)00046-1"
REPO_URL  <- "https://github.com/HeatherUrry/tipi"

DISCLAIMER <- paste0("This app was created independently and isn’t affiliated with or ",
                     "endorsed by the TIPI’s authors.")

# GitHub mark (Octicons "mark-github", MIT license), inline so the page
# requests nothing from GitHub unless the link is clicked.
GITHUB_ICON <- htmltools::HTML('<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>')

ANCHORS <- c("Disagree strongly", "Disagree moderately", "Disagree a little",
             "Neither agree nor disagree", "Agree a little", "Agree moderately",
             "Agree strongly")

AGE_CHOICES <- c("Choose one" = "", "15–20" = "15-20", "21–30" = "21-30",
                 "31–40" = "31-40", "41–50" = "41-50", "51–60" = "51-60",
                 "61 or older" = "61+", "Prefer not to say" = "none")
GENDER_CHOICES <- c("Choose one" = "", "Female" = "female", "Male" = "male",
                    "Nonbinary or another gender" = "other", "Prefer not to say" = "none")

# What high and low scores mean, in the TIPI's own words (matched by name,
# then put in display order).
TRAIT_MEANING <- data.frame(
  trait = c("Extraversion", "Agreeableness", "Conscientiousness",
            "Emotional Stability", "Openness to Experiences"),
  high  = c("extraverted, enthusiastic", "sympathetic, warm", "dependable, self-disciplined",
            "calm, emotionally stable", "open to new experiences, complex"),
  low   = c("reserved, quiet", "critical, quarrelsome", "disorganized, careless",
            "anxious, easily upset", "conventional, uncreative")
)
TRAIT_MEANING <- TRAIT_MEANING[match(TRAITS, TRAIT_MEANING$trait), ]
stopifnot(identical(TRAIT_MEANING$trait, TRAITS))

# Shown with the results (and in the PDF): why the order is OCEAN and why
# Emotional Stability sits where Neuroticism usually goes.
OCEAN_NOTE <- paste0(
  "Traits are shown in OCEAN order. The TIPI measures Emotional Stability, the reverse ",
  "of Neuroticism (the N in OCEAN), so it appears in N’s place: a high Emotional ",
  "Stability score corresponds to low Neuroticism.")

# A link that opens in a new tab and tells screen-reader users so.
ext_link <- function(href, ..., class = NULL) {
  htmltools::tags$a(
    href = href, target = "_blank", rel = "noopener noreferrer", class = class, ...,
    htmltools::tags$span(class = "sr-only", " (opens in a new tab)", .noWS = "before"),
    .noWS = c("after", "before-end"))
}

# "a", "a and b", "a, b, and c"
join_and <- function(x) {
  n <- length(x)
  if (n <= 1) return(paste(x))
  if (n == 2) return(paste(x[1], "and", x[2]))
  paste0(paste(x[-n], collapse = ", "), ", and ", x[n])
}

# e.g. "Please choose your age and gender, and answer items 3 and 7."
missing_message <- function(age_missing, gender_missing, items) {
  fields <- c(if (age_missing) "age", if (gender_missing) "gender")
  parts <- c(if (length(fields)) paste("choose your", join_and(fields)),
             if (length(items)) paste(if (length(items) > 1) "answer items" else "answer item",
                                      join_and(items)))
  if (!length(parts)) return(NULL)
  paste0("Please ", paste(parts, collapse = ", and "), ".")
}

# ---- Page sections -----------------------------------------------------------
tags <- htmltools::tags

header_ui <- function() {
  tags$header(
    tags$p(class = "eyebrow", "Ten-Item Personality Inventory (TIPI)"),
    tags$h1(id = "page-title", tabindex = "-1", "Your Big Five personality profile"),
    tags$p(class = "lede",
      "Rate yourself on 10 short descriptions (about 2 minutes) to see where you fall ",
      "on five broad personality traits compared with a large group of other people."))
}

privacy_ui <- function() {
  tags$section(
    class = "card privacy", `aria-labelledby` = "privacy-h",
    tags$h2(id = "privacy-h", "Your privacy"),
    tags$ul(
      tags$li(tags$strong("Your answers are never saved or sent anywhere."),
              " All calculations happen inside your own web browser. Your answers, ",
              "age range, and gender never leave your device, and they're erased when ",
              "you close or reload this page."),
      tags$li("This app doesn't ask for your name, email, or student ID, and it doesn't ",
              "use cookies, tracking, or analytics."),
      tags$li(paste0("This web page is delivered by ", HOST_NAME, ", which automatically ",
                     "records the IP address of every device that loads it, for security ",
                     "purposes. That record doesn't include anything you enter in this app.")),
      tags$li(tags$strong("By using this app, you consent to this."))))
}

about_you_help_ui <- function() {
  tags$p(class = "help small",
    "The published TIPI norms are split into female and male groups only. If you choose ",
    "another gender or prefer not to say, each of your percentiles is the average of your ",
    "percentile against the female norms and your percentile against the male norms. If ",
    "you prefer not to give your age, you're compared with people aged 15–30.")
}

instructions_ui <- function() {
  htmltools::tagList(
    tags$p("Here are a number of personality traits that may or may not apply to you. ",
      "Please select a number for each statement to indicate the extent to which you ",
      "agree or disagree with that statement. You should rate the extent to which the ",
      "pair of traits applies to you, even if one characteristic applies more strongly ",
      "than the other."),
    tags$ol(class = "legend", `aria-label` = "Rating scale",
            lapply(1:7, function(k) tags$li(tags$b(k), ANCHORS[k]))),
    tags$p(class = "stem", "I see myself as:"))
}

chart_caption_ui <- function() {
  htmltools::tagList(
    tags$p(class = "help small center",
      "Each point shows your percentile. The dashed ring is the 50th percentile ",
      "(the comparison group's average); the outer edge is 100."),
    tags$p(class = "ocean-note", OCEAN_NOTE))
}

meanings_ui <- function() {
  tags$dl(class = "meanings", lapply(seq_len(nrow(TRAIT_MEANING)), function(i) {
    htmltools::tagList(
      tags$dt(TRAIT_MEANING$trait[i]),
      tags$dd(paste0("Higher scores: ", TRAIT_MEANING$high[i],
                     ". Lower scores: ", TRAIT_MEANING$low[i], ".")))
  }))
}

how_to_read_ui <- function() {
  tags$details(
    tags$summary("How to read these results"),
    tags$ul(
      tags$li(tags$strong("A percentile"), " is the estimated percentage of the comparison ",
              "group who scored below you, with people who gave exactly your score ",
              "counted as half below and half above. The 50th percentile is average."),
      tags$li(tags$strong("Low"), " (15th percentile or below), ", tags$strong("Medium low"),
              " (16th–49th), ", tags$strong("Medium high"), " (50th–83rd), and ",
              tags$strong("High"), " (84th or above) split the range at one standard ",
              "deviation below the average, the average, and one standard deviation above it."),
      tags$li(tags$strong("Higher isn't better."), " Each trait has advantages and ",
              "disadvantages at both ends."),
      tags$li(tags$strong("This is a quick snapshot."), " The TIPI uses only two items per ",
              "trait, so your scores could shift a bit if you took it again. For more on ",
              "the TIPI’s reliability, see Sam Gosling’s ",
              ext_link(TIPI_NOTE, "note on alpha reliability and factor structure"), "."),
      tags$li(tags$strong("Percentiles are estimates."), " They're calculated from the ",
              "comparison group's average and standard deviation, assuming scores follow ",
              "a bell curve. That's least accurate for scores near the ends of the 1–7 ",
              "scale, so treat very high and very low results as approximate."),
      tags$li(tags$strong("About the norms."), " The comparison data come from about 278,000 ",
              "people aged 15 and older who took the TIPI online (Gosling et al., 2014; ",
              "see About the TIPI below). In the full online sample, more than half lived ",
              "in the United States and nearly three-quarters identified as White, so the ",
              "norms may fit some groups better than others.")))
}

about_tipi_ui <- function() {
  tags$section(
    class = "card about", `aria-labelledby` = "about-tipi-h",
    tags$h2(id = "about-tipi-h", "About the TIPI"),
    tags$p("The Ten-Item Personality Inventory was developed by Samuel Gosling, Jason Rentfrow, ",
           "and William Swann (2003). To learn more about it, visit ",
           ext_link(TIPI_PAGE, "Sam Gosling’s TIPI page"), "."),
    tags$p(class = "disclaimer", DISCLAIMER),
    tags$h3("References"),
    tags$ul(
      class = "refs",
      tags$li("Gosling, S. D., Rentfrow, P. J., & Swann, W. B., Jr. (2003). A very brief ",
              "measure of the Big-Five personality domains. ",
              tags$em("Journal of Research in Personality, 37", .noWS = "after"), "(6), 504–528. ",
              ext_link(TIPI_DOI, TIPI_DOI)),
      tags$li("Gosling, S. D., Rentfrow, P. J., & Potter, J. (2014). ",
              tags$em("Norms for the Ten Item Personality Inventory", .noWS = "after"),
              " [Unpublished data].")))
}

footer_ui <- function() {
  tags$footer(
    tags$p("Nothing you enter on this page is saved or sent anywhere."),
    tags$p(class = "credits",
      "Created by Heather Urry using Claude Opus 5.5.",
      tags$span(class = "sep", `aria-hidden` = "true", "·"),
      ext_link(REPO_URL, GITHUB_ICON, "Source code on GitHub", class = "gh")))
}
