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
source("tipi_text.R")     # wording and page sections shared with the lightweight page
NORMS <- load_norms("norms.csv")

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
    tags$link(rel = "stylesheet", href = "styles.css"),
    tags$script(src = "app.js")
  ),
  div(
    class = "wrap", id = "top",
    header_ui(),
    privacy_ui(),

    tags$section(
      class = "card", `aria-labelledby` = "about-h",
      h2(id = "about-h", "1. About you"),
      p(class = "help", "These two answers only choose which group you're compared with."),
      div(class = "two-col",
        selectInput("age", "Your age", width = "100%", selectize = FALSE, choices = AGE_CHOICES),
        selectInput("gender", "Your gender", width = "100%", selectize = FALSE,
                    choices = GENDER_CHOICES)
      ),
      about_you_help_ui()
    ),

    tags$section(
      class = "card", `aria-labelledby` = "q-h",
      h2(id = "q-h", "2. The questionnaire"),
      instructions_ui(),
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
          chart_caption_ui(),
          h3("Where you fall on each trait"),
          plotOutput("strips", height = "auto"),
          uiOutput("table"),
          meanings_ui(),
          div(class = "save",
              downloadButton("save_pdf", "Save or print my results (PDF)",
                             class = "btn-primary", icon = NULL),
              p(id = "save-status", class = "save-status", role = "status", `aria-live` = "polite"),
              p(class = "help small",
                "The PDF is created on your device and goes straight to you; nothing is uploaded.")),
          p(class = "help small",
            "You can change any answer above and your results will update."),
          how_to_read_ui()
        ),
        div(class = "actions",
            actionButton("reset", "Clear my answers and start over", class = "btn-default"))
      )
    ),
    about_tipi_ui(),
    footer_ui()
  )
)

server <- function(input, output, session) {
  shown <- reactiveVal(FALSE)
  tried <- reactiveVal(FALSE)   # clicked "See my results" with something missing

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
      tried(TRUE)
      return()
    }
    tried(FALSE)
    shown(TRUE)
    session$sendCustomMessage("scroll_to", "results")
  })

  # The "Please answer..." message updates as answers come in and disappears
  # once everything is answered.
  output$problems <- renderUI({
    req(tried(), !complete())
    div(class = "alert-box", role = "status", current_message())
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
      write_results_pdf(file, results(), group_description(input$gender, input$age, NORMS),
                        ocean_note = OCEAN_NOTE, disclaimer = DISCLAIMER)
    },
    contentType = "application/pdf"
  )

  observeEvent(input$reset, {
    for (i in 1:10) updateRadioButtons(session, paste0("q", i), selected = character(0))
    updateSelectInput(session, "age", selected = "")
    updateSelectInput(session, "gender", selected = "")
    tried(FALSE)
    shown(FALSE)
    session$sendCustomMessage("mark_missing", list(items = list(), fields = list()))
    session$sendCustomMessage("scroll_to", "top")
  })
}

shinyApp(ui, server)
