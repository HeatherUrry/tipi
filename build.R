# Rebuild the static website in docs/ from the app in app/.
# Run from the tipi_app folder:
#   & "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" build.R
#
# shinylive bundles the WebAssembly build of R and the R packages the app
# needs into docs/, so the page itself requests files only from your host.
# (Browsers may still make their own background requests, e.g., safe-browsing
# checks; those aren't part of the page.)

stopifnot(file.exists("app/app.R"))
source("tests/test_scoring.R")          # refuse to build if a scoring check fails

# Shown under Shinylive's spinner while R loads in the browser, so students
# see the privacy notice even before the app appears. Removed as soon as the
# app is ready (its "See my results" button, id "go", exists). Also gives the
# app's frame a title for screen readers. Inline only: it loads nothing.
loading_note <- '
<div id="tipi-loading" role="status" aria-live="polite">
  <p class="tl-main">Site loading&hellip; it&rsquo;ll take 20&ndash;30 seconds the first time.</p>
  <p class="tl-privacy">Your answers will stay on your device and are never saved or sent.
  This page&rsquo;s host, GitHub Pages, automatically records the IP address of every device
  that loads it, for security purposes. By using this app, you consent to this.</p>
</div>
<style>
  #tipi-loading { position: fixed; left: 0; right: 0; top: calc(50% + 56px); padding: 0 16px;
    text-align: center; font: 17px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif;
    color: #5b6475; pointer-events: none; z-index: 10; }
  #tipi-loading p { margin: 0 auto 10px; max-width: 34em; }
  #tipi-loading .tl-privacy { font-size: 14px; }
</style>
<script>
  (function () {
    var note = document.getElementById("tipi-loading"), started = Date.now();
    var timer = setInterval(function () {
      var f = document.querySelector("#root iframe"), ready = false;
      if (f && !f.title) f.title = "TIPI personality profile app";
      try { ready = !!(f && f.contentDocument && f.contentDocument.getElementById("go")); }
      catch (e) { ready = !!f; }
      if (ready) { note.remove(); clearInterval(timer); return; }
      if (Date.now() - started > 90000) {
        note.querySelector(".tl-main").textContent =
          "Still loading\\u2026 if nothing appears soon, try reloading the page.";
      }
    }, 300);
  })();
</script>'

# Export into a temporary folder first, so a failed export never leaves the
# site without a docs/ folder.
tmp <- "docs_new"
unlink(tmp, recursive = TRUE)
shinylive::export(
  appdir = "app",
  destdir = tmp,
  wasm_packages = TRUE,
  template_params = list(
    title = "Your TIPI personality profile",
    include_in_head = '<meta name="robots" content="noindex">',
    include_after_body = loading_note
  )
)

# Guard: every R package the app uses must be base R or bundled in the
# export. Otherwise Shinylive would quietly download it from repo.r-wasm.org
# in each student's browser, which would contact a third-party server.
deps <- unique(renv::dependencies("app", quiet = TRUE, progress = FALSE)$Package)
base_pkgs <- rownames(utils::installed.packages(priority = "base"))
lib_files <- jsonlite::fromJSON(file.path(tmp, "shinylive/webr/library.js.metadata"))$files$filename
bundled <- unique(vapply(strsplit(sub("^/", "", lib_files), "/"), `[`, "", 1))
extra <- readRDS(file.path(tmp, "shinylive/webr/packages/metadata.rds"))
bundled <- c(bundled, vapply(extra, function(e) e$name, ""))
not_bundled <- setdiff(deps, c(base_pkgs, bundled))
if (length(not_bundled)) {
  unlink(tmp, recursive = TRUE)
  stop("These packages would be downloaded from a third-party server at run time: ",
       paste(not_bundled, collapse = ", "), call. = FALSE)
}

# Drop Shinylive's optional code-editor page; students only need the app.
unlink(file.path(tmp, "edit"), recursive = TRUE)
# Tell GitHub Pages to serve files as-is (no Jekyll processing).
file.create(file.path(tmp, ".nojekyll"))

# Replace the contents of docs/ (copying rather than renaming the folder,
# which Windows refuses while a local preview server has docs/ open).
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
    full.names = TRUE))) / 1e6, 1), "MB). App packages: ", paste(deps, collapse = ", "),
    " (all base R or bundled).\nPreview with:\n",
    "  Rscript -e \"httpuv::runStaticServer('docs', port = 7451)\"\n", sep = "")
