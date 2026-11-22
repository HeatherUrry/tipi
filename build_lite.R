# Build the lightweight page into docs/lite/ (served at .../tipi/lite/).
# Run from the tipi_app folder (build.R also runs this at the end):
#   & "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" build_lite.R
#
# R does all the computing here, ahead of time: every percentile, band, and
# group average comes from app/tipi_scoring.R (the same code the Shinylive app
# runs), and every piece of wording comes from app/tipi_text.R. The browser
# only adds up item answers, looks results up, and draws the charts
# (lite/lite.js). No R runs in the browser, so the page loads in about a
# second. Nothing is saved or sent anywhere, and the page loads nothing from
# any other server.

source("app/tipi_scoring.R")
source("app/tipi_text.R")
source("lite/lite_data.R")
norms <- load_norms("app/norms.csv")
out <- "docs/lite"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
unlink(list.files(out, full.names = TRUE), recursive = TRUE)

# ---- Data ----------------------------------------------------------------------
data <- lite_data(norms)
json <- jsonlite::toJSON(data, auto_unbox = TRUE, digits = NA)
writeLines(c("// Precomputed by build_lite.R from app/tipi_scoring.R and app/norms.csv. Do not edit.",
             paste0("window.TIPI_DATA = ", json, ";")),
           file.path(out, "data.js"), useBytes = TRUE)

# ---- Page ------------------------------------------------------------------------
item_ui <- function(i) {
  tags$div(
    class = "tipi-item", id = paste0("item", i),
    tags$div(
      class = "form-group shiny-input-radiogroup", id = paste0("q", i), role = "radiogroup",
      `aria-labelledby` = paste0("q", i, "-label"),
      tags$div(class = "control-label", id = paste0("q", i, "-label"), paste0(i, ". ", TIPI_ITEMS[i])),
      tags$div(class = "shiny-options-group", lapply(1:7, function(k) {
        tags$label(class = "radio-inline",
          tags$input(type = "radio", name = paste0("q", i), value = k),
          tags$span(tags$span(class = "dot", title = ANCHORS[k], k,
                              tags$span(class = "sr-only", paste0(", ", ANCHORS[k])))))
      }))),
    tags$div(class = "ends", `aria-hidden` = "true",
             tags$span("Disagree strongly"), tags$span("Agree strongly")))
}

select_ui <- function(id, label, choices) {
  tags$div(class = "form-group",
    tags$label(class = "control-label", `for` = id, label),
    tags$select(id = id, class = "form-control",
      lapply(seq_along(choices), function(k) tags$option(value = choices[[k]], names(choices)[k]))))
}

body <- tags$div(
  class = "wrap", id = "top",
  tags$p(class = "print-only print-head", id = "print-head"),
  header_ui(),
  privacy_ui(),
  tags$section(
    class = "card no-print", `aria-labelledby` = "about-h",
    tags$h2(id = "about-h", "1. About you"),
    tags$p(class = "help", "These two answers only choose which group you're compared with."),
    tags$div(class = "two-col",
      select_ui("age", "Your age", AGE_CHOICES),
      select_ui("gender", "Your gender", GENDER_CHOICES)),
    about_you_help_ui()),
  tags$section(
    class = "card no-print", `aria-labelledby` = "q-h",
    tags$h2(id = "q-h", "2. The questionnaire"),
    instructions_ui(),
    lapply(1:10, item_ui),
    tags$div(class = "actions",
      tags$button(type = "button", id = "go", class = "btn btn-primary btn-lg", "See my results"),
      tags$div(id = "problems"))),
  tags$section(
    class = "card results", id = "results", `aria-labelledby` = "res-h", hidden = NA,
    tags$h2(id = "res-h", tabindex = "-1", "3. Your results"),
    tags$div(id = "incomplete"),
    tags$div(
      id = "results-body",
      tags$p(class = "group", id = "group-text"),
      tags$div(class = "radar-box", id = "radar"),
      chart_caption_ui(),
      tags$h3("Where you fall on each trait"),
      tags$div(id = "strips"),
      tags$div(id = "table"),
      meanings_ui(),
      tags$div(class = "save no-print",
        tags$button(type = "button", id = "print", class = "btn btn-primary",
                    "Print or save my results (PDF)"),
        tags$p(class = "help small",
          "Your browser\u2019s print window lets you print the results or save them as a PDF. ",
          "Nothing is uploaded.")),
      tags$p(class = "help small no-print",
        "You can change any answer above and your results will update."),
      how_to_read_ui()),
    tags$div(class = "actions no-print",
      tags$button(type = "button", id = "reset", class = "btn btn-default",
                  "Clear my answers and start over"))),
  about_tipi_ui(),
  footer_ui())

page <- c(
  "<!doctype html>",
  "<html lang=\"en\">",
  "<head>",
  "<meta charset=\"utf-8\">",
  "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
  "<title>Your TIPI personality profile</title>",
  "<link rel=\"stylesheet\" href=\"lite.css\">",
  "<link rel=\"stylesheet\" href=\"styles.css\">",
  "</head>",
  "<body>",
  as.character(body),
  "<script src=\"data.js\"></script>",
  "<script src=\"lite.js\"></script>",
  "</body>",
  "</html>")
writeLines(enc2utf8(page), file.path(out, "index.html"), useBytes = TRUE)

# Styles: the app's own stylesheet plus a small base/print sheet (the app gets
# its base styles from Shiny's Bootstrap, which this page doesn't load).
stopifnot(file.copy("app/www/styles.css", file.path(out, "styles.css"), overwrite = TRUE),
          file.copy("lite/lite.css", file.path(out, "lite.css"), overwrite = TRUE),
          file.copy("lite/lite.js", file.path(out, "lite.js"), overwrite = TRUE))

# Guard: the page must not reference any other server (only links people click).
html <- paste(readLines(file.path(out, "index.html"), warn = FALSE), collapse = "\n")
refs <- regmatches(html, gregexpr("(src|href)=\"[^\"]+\"", html))[[1]]
external_loads <- grep("^src=\"(https?:)?//", refs, value = TRUE)
css_js <- paste(unlist(lapply(file.path(out, c("lite.css", "styles.css", "lite.js")),
                              readLines, warn = FALSE)), collapse = "\n")
if (length(external_loads) || grepl("url\\(\\s*['\"]?(https?:)?//|@import|fetch\\(|XMLHttpRequest|sendBeacon|WebSocket",
                                   css_js)) {
  stop("The lightweight page would load or send something to another server.", call. = FALSE)
}

cat("Built ", out, "/ (", round(sum(file.size(list.files(out, full.names = TRUE))) / 1000), " KB)\n",
    sep = "")
