# TIPI personality profile: a Shiny app meant to be exported with Shinylive so
# that all R code runs inside each student's own web browser.
#
# PRIVACY: this app has no server-side code and sends nothing anywhere. It
# stores no answers: no cookies, no local or session storage, no files kept.
# (The Shinylive runtime itself creates an empty browser database and cache
# that never hold user data.) Responses exist only in the open browser tab
# and disappear when it is closed or reloaded. The PDF download is created
# inside the browser and handed straight to the student.

library(shiny)
source("tipi_scoring.R")
source("tipi_plots.R")
source("tipi_pdf.R")
NORMS <- load_norms("norms.csv")

# Who serves the web page, for the privacy notice. Change this if you host the
# exported site somewhere other than GitHub Pages.
HOST_NAME <- "GitHub Pages (a service of GitHub, Inc.)"

# Sources. The links open in a new tab and send no referrer; clicking one
# leaves this app, which still sends nothing.
TIPI_PAGE <- "https://gosling.psy.utexas.edu/scales-weve-developed/ten-item-personality-measure-tipi/"
TIPI_DOI  <- "https://doi.org/10.1016/S0092-6566(03)00046-1"
REPO_URL  <- "https://github.com/HeatherUrry/tipi"

# GitHub mark (Octicons "mark-github", MIT license), inline so the page
# requests nothing from GitHub unless the link is clicked.
GITHUB_ICON <- HTML('<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>')

ANCHORS <- c("Disagree strongly", "Disagree moderately", "Disagree a little",
             "Neither agree nor disagree", "Agree a little", "Agree moderately",
             "Agree strongly")

TRAIT_MEANING <- data.frame(
  trait = TRAITS,
  high  = c("extraverted, enthusiastic", "sympathetic, warm", "dependable, self-disciplined",
            "calm, emotionally stable", "open to new experiences, complex"),
  low   = c("reserved, quiet", "critical, quarrelsome", "disorganized, careless",
            "anxious, easily upset", "conventional, uncreative")
)

# A link that opens in a new tab and tells screen-reader users so.
ext_link <- function(href, ..., class = NULL) {
  tags$a(href = href, target = "_blank", rel = "noopener noreferrer", class = class, ...,
         tags$span(class = "sr-only", " (opens in a new tab)"), .noWS = "after")
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

item_input <- function(i) {
  div(
    class = "tipi-item", id = paste0("item", i),
    radioButtons(
      paste0("q", i),
      label = paste0(i, ". ", TIPI_ITEMS[i]),
      choiceNames = lapply(1:7, function(k) {
        tags$span(class = "dot", title = ANCHORS[k], k,
                  tags$span(class = "sr-only", paste0(", ", ANCHORS[k])))
      }),
      choiceValues = as.character(1:7),
      selected = character(0),
      inline = TRUE
    ),
    div(class = "ends", `aria-hidden` = "true",
        span("Disagree strongly"), span("Agree strongly"))
  )
}

ui <- fluidPage(
  title = "Your TIPI personality profile",
  lang = "en",
  tags$head(
    tags$meta(name = "robots", content = "noindex"),
    tags$link(rel = "stylesheet", href = "styles.css"),
    tags$script(src = "app.js")
  ),
  div(
    class = "wrap", id = "top",
    tags$header(
      p(class = "eyebrow", "Ten-Item Personality Inventory (TIPI)"),
      h1(id = "page-title", tabindex = "-1", "Your Big Five personality profile"),
      p(class = "lede",
        "Rate yourself on 10 short descriptions (about 2 minutes) to see where you fall ",
        "on five broad personality traits compared with a large group of other people.")
    ),

    tags$section(
      class = "card privacy", `aria-labelledby` = "privacy-h",
      h2(id = "privacy-h", "Your privacy"),
      tags$ul(
        tags$li(strong("Your answers are never saved or sent anywhere."),
                " All calculations happen inside your own web browser. Your answers, ",
                "age range, and gender never leave your device, and they're erased when ",
                "you close or reload this page."),
        tags$li("This app doesn't ask for your name, email, or student ID, and it doesn't ",
                "use cookies, tracking, or analytics."),
        tags$li(paste0("This web page is delivered by ", HOST_NAME, ", which automatically ",
                       "records the IP address of every device that loads it, for security ",
                       "purposes. That record doesn't include anything you enter in this app.")),
        tags$li(strong("By using this app, you consent to this."))
      )
    ),

    tags$section(
      class = "card", `aria-labelledby` = "about-h",
      h2(id = "about-h", "1. About you"),
      p(class = "help", "These two answers only choose which group you're compared with."),
      div(class = "two-col",
        selectInput("age", "Your age", width = "100%", selectize = FALSE,
          choices = c("Choose one" = "", "15–20" = "15-20", "21–30" = "21-30",
                      "31–40" = "31-40", "41–50" = "41-50", "51–60" = "51-60",
                      "61 or older" = "61+", "Prefer not to say" = "none")),
        selectInput("gender", "Your gender", width = "100%", selectize = FALSE,
          choices = c("Choose one" = "", "Female" = "female", "Male" = "male",
                      "Nonbinary or another gender" = "other",
                      "Prefer not to say" = "none"))
      ),
      p(class = "help small",
        "The published TIPI norms are split into female and male groups only. If you choose ",
        "another gender or prefer not to say, each of your percentiles is the average of your ",
        "percentile against the female norms and your percentile against the male norms. If ",
        "you prefer not to give your age, you're compared with people aged 15–30.")
    ),

    tags$section(
      class = "card", `aria-labelledby` = "q-h",
      h2(id = "q-h", "2. The questionnaire"),
      p("Here are a number of personality traits that may or may not apply to you. ",
        "Please select a number for each statement to indicate the extent to which you ",
        "agree or disagree with that statement. You should rate the extent to which the ",
        "pair of traits applies to you, even if one characteristic applies more strongly ",
        "than the other."),
      tags$ol(class = "legend", `aria-label` = "Rating scale",
              lapply(1:7, function(k) tags$li(tags$b(k), ANCHORS[k]))),
      p(class = "stem", "I see myself as:"),
      lapply(1:10, item_input),
      div(class = "actions",
          actionButton("go", "See my results", class = "btn-primary btn-lg"),
          uiOutput("problems", inline = FALSE))
    ),

    conditionalPanel(
      "output.show_results",
      tags$section(
        class = "card results", id = "results", `aria-labelledby` = "res-h",
        h2(id = "res-h", tabindex = "-1", "3. Your results"),
        uiOutput("incomplete"),
        conditionalPanel(
          "output.results_ready",
          uiOutput("group_text"),
          div(class = "radar-box", plotOutput("radar", height = "auto")),
          p(class = "help small center",
            "Each point shows your percentile. The dashed ring is the 50th percentile ",
            "(the comparison group's average); the outer edge is 100."),
          h3("Where you fall on each trait"),
          plotOutput("strips", height = "auto"),
          uiOutput("table"),
          tags$dl(class = "meanings", lapply(seq_len(nrow(TRAIT_MEANING)), function(i) {
            tagList(tags$dt(TRAIT_MEANING$trait[i]),
                    tags$dd(paste0("Higher scores: ", TRAIT_MEANING$high[i],
                                   ". Lower scores: ", TRAIT_MEANING$low[i], ".")))
          })),
          div(class = "save",
              downloadButton("save_pdf", "Save or print my results (PDF)",
                             class = "btn-primary", icon = NULL),
              p(class = "help small",
                "The PDF is created on your device and goes straight to you; nothing is uploaded.")),
          p(class = "help small",
            "You can change any answer above and your results will update."),
          tags$details(
            tags$summary("How to read these results"),
            tags$ul(
              tags$li(strong("A percentile"), " is the estimated percentage of the comparison ",
                      "group who scored below you, with people who gave exactly your score ",
                      "counted as half below and half above. The 50th percentile is average."),
              tags$li(strong("Low"), " (15th percentile or below), ", strong("Medium low"),
                      " (16th–49th), ", strong("Medium high"), " (50th–83rd), and ",
                      strong("High"), " (84th or above) split the range at one standard ",
                      "deviation below the average, the average, and one standard deviation above it."),
              tags$li(strong("Higher isn't better."), " Each trait has advantages and ",
                      "disadvantages at both ends."),
              tags$li(strong("This is a quick snapshot."), " The TIPI uses only two items per ",
                      "trait, so your scores could shift a bit if you took it again."),
              tags$li(strong("Percentiles are estimates."), " They're calculated from the ",
                      "comparison group's average and standard deviation, assuming scores follow ",
                      "a bell curve. That's least accurate for scores near the ends of the 1–7 ",
                      "scale, so treat very high and very low results as approximate."),
              tags$li(strong("About the norms."), " The comparison data come from about 278,000 ",
                      "people aged 15 and older who took the TIPI online (Gosling et al., 2014; ",
                      "see About the TIPI below). In the full online sample, more than half lived ",
                      "in the United States and nearly three-quarters identified as White, so the ",
                      "norms may fit some groups better than others.")
            )
          )
        ),
        div(class = "actions",
            actionButton("reset", "Clear my answers and start over", class = "btn-default"))
      )
    ),
    tags$section(
      class = "card about", `aria-labelledby` = "about-tipi-h",
      h2(id = "about-tipi-h", "About the TIPI"),
      p("The Ten-Item Personality Inventory was developed by Samuel Gosling, Jason Rentfrow, ",
        "and William Swann (2003). To learn more about it, visit ",
        ext_link(TIPI_PAGE, "Sam Gosling’s TIPI page"), "."),
      h3("References"),
      tags$ul(
        class = "refs",
        tags$li("Gosling, S. D., Rentfrow, P. J., & Swann, W. B., Jr. (2003). A very brief ",
                "measure of the Big-Five personality domains. ",
                tags$em("Journal of Research in Personality, 37", .noWS = "after"), "(6), 504–528. ",
                ext_link(TIPI_DOI, TIPI_DOI)),
        tags$li("Gosling, S. D., Rentfrow, P. J., & Potter, J. (2014). ",
                tags$em("Norms for the Ten Item Personality Inventory", .noWS = "after"),
                " [Unpublished data].")
      )
    ),
    tags$footer(
      p("Nothing you enter on this page is saved or sent anywhere."),
      p(class = "credits",
        "Created by Heather Urry using Claude Opus 5.5.",
        tags$span(class = "sep", `aria-hidden` = "true", "·"),
        ext_link(REPO_URL, GITHUB_ICON, "Source code on GitHub", class = "gh"))
    )
  )
)

server <- function(input, output, session) {
  shown    <- reactiveVal(FALSE)
  problems <- reactiveVal(NULL)

  answers <- reactive({
    vapply(1:10, function(i) {
      v <- input[[paste0("q", i)]]
      if (is.null(v) || !nzchar(v)) NA_character_ else v
    }, character(1))
  })
  missing_items <- reactive(which(is.na(answers())))
  complete <- reactive({
    length(missing_items()) == 0 && nzchar(input$age) && nzchar(input$gender)
  })
  current_message <- reactive({
    missing_message(!nzchar(input$age), !nzchar(input$gender), missing_items())
  })

  observeEvent(input$go, {
    session$sendCustomMessage("mark_missing", list(
      items  = as.list(paste0("item", missing_items())),
      fields = as.list(c(if (!nzchar(input$age)) "age", if (!nzchar(input$gender)) "gender"))
    ))
    if (!complete()) {
      problems(current_message())
      return()
    }
    problems(NULL)
    shown(TRUE)
    session$sendCustomMessage("scroll_to", "results")
  })

  # Once everything is answered, the "Please answer..." message goes away.
  observe({ if (complete()) problems(NULL) })

  output$problems <- renderUI({
    req(problems())
    div(class = "alert-box", role = "alert", problems())
  })

  results <- reactive({
    req(shown(), complete())
    tipi_profile(as.integer(answers()), input$gender, input$age, NORMS)
  })

  output$show_results  <- reactive(shown())
  output$results_ready <- reactive(shown() && complete())
  outputOptions(output, "show_results", suspendWhenHidden = FALSE)
  outputOptions(output, "results_ready", suspendWhenHidden = FALSE)

  # If a student clears an answer after seeing results, say why they vanished.
  output$incomplete <- renderUI({
    req(shown(), !complete())
    div(class = "alert-box", role = "alert",
        "Your results are hidden because something is now unanswered. ", current_message())
  })

  output$group_text <- renderUI({
    req(results())
    p(class = "group", "You're compared with ",
      strong(group_description(input$gender, input$age, NORMS), .noWS = "after"), ".")
  })

  alt_text <- reactive({
    r <- results()
    paste0("Your percentiles: ",
           paste0(r$trait, " ", format_percentile(r$percentile), collapse = "; "), ".")
  })

  # execOnResize = TRUE: redraw (not just rescale) when the width changes, so
  # the label layout is recomputed after a phone is rotated or a window resized.
  output$radar <- renderPlot(
    plot_radar(results()),
    height = function() {
      w <- session$clientData$output_radar_width
      if (is.null(w) || w < 50) 400 else round(min(w * if (w < 480) 0.9 else 0.8, 480))
    },
    res = 96, execOnResize = TRUE, alt = function() paste("Spider chart.", alt_text())
  )

  output$strips <- renderPlot(
    plot_strips(results()),
    height = function() {
      w <- session$clientData$output_strips_width
      if (!is.null(w) && w < 480) 400 else 420
    },
    res = 96, execOnResize = TRUE, alt = function() paste("Percentile strips.", alt_text())
  )

  output$table <- renderUI({
    r <- results()
    tags$table(
      class = "res-table",
      tags$caption(class = "sr-only", "Your scores and percentiles"),
      tags$thead(tags$tr(
        tags$th(scope = "col", "Trait"),
        tags$th(scope = "col", class = "num", "Your score", tags$br(), tags$small("(1–7)")),
        tags$th(scope = "col", class = "num avg-col", "Group average"),
        tags$th(scope = "col", class = "num", "Percentile"),
        tags$th(scope = "col", "Range")
      )),
      tags$tbody(lapply(seq_len(nrow(r)), function(i) {
        tags$tr(
          tags$th(scope = "row", r$trait[i]),
          tags$td(class = "num", formatC(r$score[i], format = "f", digits = 1)),
          tags$td(class = "num avg-col", formatC(r$group_mean[i], format = "f", digits = 2)),
          tags$td(class = "num strong", format_percentile(r$percentile[i])),
          tags$td(class = "band", r$band[i])
        )
      }))
    )
  })

  output$save_pdf <- downloadHandler(
    filename = function() "my-tipi-results.pdf",
    content = function(file) {
      write_results_pdf(file, results(), group_description(input$gender, input$age, NORMS))
    },
    contentType = "application/pdf"
  )

  observeEvent(input$reset, {
    for (i in 1:10) updateRadioButtons(session, paste0("q", i), selected = character(0))
    updateSelectInput(session, "age", selected = "")
    updateSelectInput(session, "gender", selected = "")
    problems(NULL)
    shown(FALSE)
    session$sendCustomMessage("mark_missing", list(items = list(), fields = list()))
    session$sendCustomMessage("scroll_to", "top")
  })
}

shinyApp(ui, server)
