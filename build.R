# Build the TIPI web page into docs/ (GitHub Pages serves it at
# https://heatherurry.io/tipi/). Run from the tipi_app folder:
#   & "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" build.R
#
# R does all the computing here, ahead of time: every percentile, band, and
# group average comes from R/tipi_scoring.R and the norms in data/norms.csv, and
# all wording comes from R/tipi_text.R. The browser only adds up item answers,
# looks results up, and draws the charts (web/app.js). Nothing is saved or
# sent anywhere, and the page loads nothing from any other server.

stopifnot(file.exists("R/tipi_scoring.R"))
source("tests/test_scoring.R")            # stop if a scoring check fails

source("R/tipi_scoring.R")
source("R/tipi_text.R")
source("R/tables.R")
norms <- load_norms("data/norms.csv")

# Build into a temporary folder; docs/ is only replaced if everything passes.
tmp <- "docs_new"
unlink(tmp, recursive = TRUE)
dir.create(tmp)

# ---- Lookup tables --------------------------------------------------------------
json <- jsonlite::toJSON(tipi_tables(norms), auto_unbox = TRUE, digits = NA)
writeLines(c("// Precomputed by build.R from R/tipi_scoring.R and data/norms.csv. Do not edit.",
             paste0("window.TIPI_DATA = ", json, ";")),
           file.path(tmp, "data.js"), useBytes = TRUE)
# Check every cell of the built file against an independent calculation.
DATA_JS <- file.path(tmp, "data.js")
source("tests/test_tables.R")

# ---- Page -------------------------------------------------------------------------
item_ui <- function(i) {
  tags$div(
    class = "tipi-item", id = paste0("item", i),
    tags$div(
      class = "form-group shiny-input-radiogroup", id = paste0("q", i), role = "radiogroup",
      `aria-labelledby` = paste0("q", i, "-label"),
      tags$div(class = "control-label", id = paste0("q", i, "-label"), paste0(i, ". ", TIPI_ITEMS[i])),
      tags$div(class = "shiny-options-group", lapply(1:7, function(k) {
        tags$label(class = "radio-inline",
          tags$input(type = "radio", name = paste0("q", i), value = k, autocomplete = "off"),
          tags$span(tags$span(class = "dot", title = ANCHORS[k], k,
                              tags$span(class = "sr-only", paste0(", ", ANCHORS[k])))))
      }))),
    tags$div(class = "ends", `aria-hidden` = "true",
             tags$span("Disagree strongly"), tags$span("Agree strongly")))
}

select_ui <- function(id, label, choices) {
  tags$div(class = "form-group",
    tags$label(class = "control-label", `for` = id, label),
    tags$select(id = id, class = "form-control", autocomplete = "off",
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
      tags$div(class = "strips-block",
        tags$h3("Where you fall on each trait"),
        tags$div(id = "strips")),
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
  "<link rel=\"stylesheet\" href=\"base.css\">",
  "<link rel=\"stylesheet\" href=\"styles.css\">",
  "<link rel=\"stylesheet\" href=\"print.css\" media=\"print\">",
  "</head>",
  "<body>",
  as.character(body),
  "<script src=\"data.js\"></script>",
  "<script src=\"app.js\"></script>",
  "</body>",
  "</html>")
writeLines(enc2utf8(page), file.path(tmp, "index.html"), useBytes = TRUE)
for (f in c("app.js", "base.css", "styles.css", "print.css")) {
  stopifnot(file.copy(file.path("web", f), file.path(tmp, f)))
}

# ---- The retired Shinylive version ------------------------------------------------
# /tipi/lite/ (where this page used to live) forwards to /tipi/.
dir.create(file.path(tmp, "lite"))
writeLines(c(
  "<!doctype html>", "<html lang=\"en\">", "<head>", "<meta charset=\"utf-8\">",
  "<meta name=\"robots\" content=\"noindex\">",
  "<meta http-equiv=\"refresh\" content=\"0; url=../\">",
  "<link rel=\"canonical\" href=\"https://heatherurry.io/tipi/\">",
  "<title>TIPI personality profile</title>", "</head>",
  "<body><p>This page has moved to <a href=\"../\">heatherurry.io/tipi</a>.</p></body>", "</html>"),
  file.path(tmp, "lite", "index.html"))
# Browsers that opened the old Shinylive version registered its service worker
# (shinylive-sw.js). This replacement removes itself (and Shinylive's own,
# empty cache), so nothing lingers.
writeLines(c(
  "// The Shinylive version of this page was retired. Browsers that registered its",
  "// service worker download this replacement, which removes itself.",
  "self.addEventListener('install', function () { self.skipWaiting(); });",
  "self.addEventListener('activate', function (event) {",
  "  event.waitUntil(",
  "    caches.keys()",
  "      .then(function (keys) { return Promise.all(keys.filter(function (k) {",
  "        return k.indexOf('shinylive') !== -1; }).map(function (k) { return caches.delete(k); })); })",
  "      .then(function () { return self.registration.unregister(); }));",
  "});"),
  file.path(tmp, "shinylive-sw.js"))
invisible(file.create(file.path(tmp, ".nojekyll")))   # GitHub Pages: serve files as-is

# ---- Guard: the page must not load or send anything to another server ---------------
html <- paste(readLines(file.path(tmp, "index.html"), warn = FALSE), collapse = "\n")
loads <- c(regmatches(html, gregexpr("<(script|img|iframe|source|audio|video)[^>]+src=\"(https?:)?//[^\"]+\"", html))[[1]],
           regmatches(html, gregexpr("<link[^>]+href=\"(https?:)?//[^\"]+\"", html))[[1]])
css_js <- paste(unlist(lapply(file.path(tmp, c("base.css", "styles.css", "print.css", "app.js")),
                              readLines, warn = FALSE)), collapse = "\n")
if (length(loads) || grepl("url\\(\\s*['\"]?(https?:)?//|@import|fetch\\(|XMLHttpRequest|sendBeacon|WebSocket|localStorage|sessionStorage|indexedDB|document\\.cookie",
                          css_js)) {
  unlink(tmp, recursive = TRUE)
  stop("The page would load, send, or store something it shouldn't: ",
       paste(loads, collapse = ", "), call. = FALSE)
}

# ---- Publish: replace the contents of docs/ -----------------------------------------
# (copying rather than renaming the folder, which Windows refuses while a
# local preview server has docs/ open)
dir.create("docs", showWarnings = FALSE)
unlink(list.files("docs", all.files = TRUE, full.names = TRUE, no.. = TRUE), recursive = TRUE)
copied <- file.copy(list.files(tmp, all.files = TRUE, full.names = TRUE, no.. = TRUE),
                    "docs", recursive = TRUE)
if (!all(copied)) {
  stop("Couldn't replace some files in docs/. If a local preview server is running, ",
       "stop it (it keeps files open), then run build.R again.", call. = FALSE)
}
unlink(tmp, recursive = TRUE)
cat("\nBuilt docs/ (", round(sum(file.size(list.files("docs", recursive = TRUE,
    full.names = TRUE))) / 1000), " KB).\nPreview with:\n",
    "  Rscript -e \"httpuv::runStaticServer('docs', port = 7451)\"   then open http://localhost:7451\n",
    "Browser check of the page's scoring code: open tests/browser-check.html\n", sep = "")
