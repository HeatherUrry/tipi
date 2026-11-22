# Rebuild the static website in docs/ from the app in app/.
# Run from the tipi_app folder:  Rscript build.R
#
# shinylive bundles the WebAssembly build of R and every R package the app
# needs into docs/, so students' browsers download everything from your host
# and never contact any other server.

stopifnot(file.exists("app/app.R"))
source("tests/test_scoring.R")          # refuse to build if a scoring check fails

# Note shown under Shinylive's spinner while R loads in the browser. It is
# removed as soon as the app appears (the app's "See my results" button,
# id "go", exists). Inline only: it loads nothing from anywhere.
loading_note <- '
<div id="tipi-loading" role="status" aria-live="polite">Site loading&hellip; it&rsquo;ll take 20&ndash;30 seconds the first time.</div>
<style>
  #tipi-loading { position: fixed; left: 0; right: 0; top: calc(50% + 56px); padding: 0 16px;
    text-align: center; font: 17px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif;
    color: #5b6475; pointer-events: none; z-index: 10; }
</style>
<script>
  (function () {
    var note = document.getElementById("tipi-loading"), started = Date.now();
    var timer = setInterval(function () {
      var f = document.querySelector("#root iframe"), ready = false;
      try { ready = !!(f && f.contentDocument && f.contentDocument.getElementById("go")); }
      catch (e) { ready = !!f; }
      if (ready) { note.remove(); clearInterval(timer); return; }
      if (Date.now() - started > 90000) {
        note.textContent = "Still loading\\u2026 if nothing appears soon, try reloading the page.";
      }
    }, 300);
  })();
</script>'

unlink("docs", recursive = TRUE)
shinylive::export(
  appdir = "app",
  destdir = "docs",
  wasm_packages = TRUE,
  template_params = list(
    title = "Your TIPI personality profile",
    include_in_head = '<meta name="robots" content="noindex">',
    include_after_body = loading_note
  )
)
# Drop Shinylive's optional code-editor page; students only need the app.
unlink("docs/edit", recursive = TRUE)
# Tell GitHub Pages to serve files as-is (no Jekyll processing).
file.create("docs/.nojekyll")
cat("\nBuilt docs/ (", round(sum(file.size(list.files("docs", recursive = TRUE,
    full.names = TRUE))) / 1e6, 1), "MB ). Preview with:\n",
    "  Rscript -e \"httpuv::runStaticServer('docs', port = 7451)\"\n", sep = "")
