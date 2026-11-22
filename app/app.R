# TIPI personality profile: a Shiny app meant to be exported with Shinylive so
# that all R code runs inside each student's own web browser.
#
# PRIVACY: this app has no server-side code, writes no files, sets no cookies,
# uses no browser storage, and sends nothing anywhere. Responses exist only in
# the open browser tab and disappear when it is closed or reloaded.

library(shiny)
source("tipi_scoring.R")
source("tipi_plots.R")
NORMS <- load_norms("norms.csv")

# Who serves the web page, for the privacy notice. Change this if you host the
# exported site somewhere other than GitHub Pages.
HOST_NAME <- "GitHub Pages (a service of GitHub, Inc.)"

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
      h1("Your Big Five personality profile"),
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
        "another gender or prefer not to say, your percentiles are the average of the female ",
        "and male norms. If you prefer not to give your age, you're compared with people aged 15–30.")
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
        h2(id = "res-h", "3. Your results"),
        uiOutput("group_text"),
        div(class = "radar-box", plotOutput("radar", height = "auto")),
        p(class = "help small center",
          "Each point shows your percentile. The dashed ring is the 50th percentile ",
          "(the comparison group's average); the outer edge is 100."),
        h3("Where you fall on each trait"),
        plotOutput("strips", height = "auto"),
        uiOutput("table"),
        p(class = "help small",
          "You can change any answer above and your results will update."),
        tags$details(
          tags$summary("How to read these results"),
          tags$ul(
            tags$li(strong("A percentile"), " is the estimated percentage of the comparison ",
                    "group who scored lower than you. The 50th percentile is average."),
            tags$li(strong("Low, Medium low, Medium high, and High"), " split the range at the ",
                    "16th, 50th, and 84th percentiles (one standard deviation below the ",
                    "average, the average, and one standard deviation above it)."),
            tags$li(strong("Higher isn't better."), " Each trait has advantages and ",
                    "disadvantages at both ends."),
            tags$li(strong("This is a quick snapshot."), " The TIPI uses only two items per ",
                    "trait, so your scores could shift a bit if you took it again."),
            tags$li(strong("Percentiles are estimates."), " They're calculated from the ",
                    "comparison group's average and standard deviation, assuming scores follow ",
                    "a bell curve. That's least accurate at the extremes, so treat percentiles ",
                    "below the 5th or above the 95th as approximate."),
            tags$li(strong("About the norms."), " The comparison data come from about 278,000 ",
                    "people aged 15 and older who took the TIPI online. In the full online ",
                    "sample, 54% lived in the United States and about three-quarters ",
                    "identified as White, so the norms may fit some groups better than others.")
          )
        ),
        div(class = "actions",
            actionButton("reset", "Clear my answers and start over", class = "btn-default"))
      )
    ),
    tags$footer(p("Nothing you enter on this page is saved or sent anywhere."))
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

  observeEvent(input$go, {
    miss <- c(if (!nzchar(input$age)) "your age",
              if (!nzchar(input$gender)) "your gender",
              if (length(missing_items()))
                paste0(if (length(missing_items()) > 1) "items " else "item ",
                       paste(missing_items(), collapse = ", ")))
    session$sendCustomMessage("mark_missing", list(
      items  = as.list(paste0("item", missing_items())),
      fields = as.list(c(if (!nzchar(input$age)) "age", if (!nzchar(input$gender)) "gender"))
    ))
    if (length(miss)) {
      problems(paste0("Please answer ", paste(miss, collapse = " and "), "."))
      return()
    }
    problems(NULL)
    shown(TRUE)
    session$sendCustomMessage("scroll_to", "results")
  })

  output$problems <- renderUI({
    req(problems())
    div(class = "alert-box", role = "alert", problems())
  })

  results <- reactive({
    req(shown(), complete())
    tipi_profile(as.integer(answers()), input$gender, input$age, NORMS)
  })

  output$show_results <- reactive(shown() && complete())
  outputOptions(output, "show_results", suspendWhenHidden = FALSE)

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

  output$radar <- renderPlot(
    plot_radar(results()),
    height = function() {
      w <- session$clientData$output_radar_width
      if (is.null(w) || w < 50) 400 else round(min(w * if (w < 480) 0.7 else 0.8, 480))
    },
    res = 96, alt = function() paste("Spider chart.", alt_text())
  )

  output$strips <- renderPlot(
    plot_strips(results()),
    height = function() {
      w <- session$clientData$output_strips_width
      if (!is.null(w) && w < 480) 400 else 420
    },
    res = 96, alt = function() paste("Percentile strips.", alt_text())
  )

  output$table <- renderUI({
    r <- results()
    m <- TRAIT_MEANING[match(r$trait, TRAIT_MEANING$trait), ]
    tags$table(
      class = "res-table",
      tags$caption(class = "sr-only", "Your scores and percentiles"),
      tags$thead(tags$tr(
        tags$th(scope = "col", "Trait"),
        tags$th(scope = "col", class = "num", "Your score", tags$br(), tags$small("(1–7)")),
        tags$th(scope = "col", class = "num", "Group average"),
        tags$th(scope = "col", class = "num", "Percentile"),
        tags$th(scope = "col", class = "band-col", "Range")
      )),
      tags$tbody(lapply(seq_len(nrow(r)), function(i) {
        tags$tr(
          tags$th(scope = "row", r$trait[i],
                  tags$div(class = "meaning",
                           paste0("Higher: ", m$high[i], ". Lower: ", m$low[i], "."))),
          tags$td(class = "num", formatC(r$score[i], format = "f", digits = 1)),
          tags$td(class = "num", formatC(r$group_mean[i], format = "f", digits = 2)),
          tags$td(class = "num strong", format_percentile(r$percentile[i])),
          tags$td(class = "band-col", r$band[i])
        )
      }))
    )
  })

  observeEvent(input$reset, {
    for (i in 1:10) updateRadioButtons(session, paste0("q", i), selected = character(0))
    updateSelectInput(session, "age", selected = "")
    updateSelectInput(session, "gender", selected = "")
    problems(NULL)
    shown(FALSE)
    session$sendCustomMessage("scroll_to", "top")
  })
}

shinyApp(ui, server)
