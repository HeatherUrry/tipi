# Rebuild the static website in docs/ from the app in app/.
# Run from the tipi_app folder:  Rscript build.R
#
# shinylive bundles the WebAssembly build of R and every R package the app
# needs into docs/, so students' browsers download everything from your host
# and never contact any other server.

stopifnot(file.exists("app/app.R"))
source("tests/test_scoring.R")          # refuse to build if a scoring check fails

unlink("docs", recursive = TRUE)
shinylive::export(
  appdir = "app",
  destdir = "docs",
  wasm_packages = TRUE,
  template_params = list(
    title = "Your TIPI personality profile",
    include_in_head = '<meta name="robots" content="noindex">'
  )
)
# Drop Shinylive's optional code-editor page; students only need the app.
unlink("docs/edit", recursive = TRUE)
# Tell GitHub Pages to serve files as-is (no Jekyll processing).
file.create("docs/.nojekyll")
cat("\nBuilt docs/ (", round(sum(file.size(list.files("docs", recursive = TRUE,
    full.names = TRUE))) / 1e6, 1), "MB ). Preview with:\n",
    "  Rscript -e \"httpuv::runStaticServer('docs', port = 7451)\"\n", sep = "")
