// Small UI helpers. Nothing here stores or sends data.
$(document).on("shiny:connected", function () {
  // Scroll to a section and move keyboard/screen-reader focus to its heading:
  // "results" -> the results heading, "top" -> the page title.
  Shiny.addCustomMessageHandler("scroll_to", function (id) {
    setTimeout(function () {
      var el = document.getElementById(id);
      if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
      var target = document.getElementById(id === "results" ? "res-h" : "page-title");
      if (target) target.focus({ preventScroll: true });
    }, 150);
  });

  // Highlight unanswered items/fields, mark them invalid for screen readers,
  // and move focus to the first one.
  Shiny.addCustomMessageHandler("mark_missing", function (msg) {
    $(".tipi-item").removeClass("missing").find(".shiny-input-radiogroup").removeAttr("aria-invalid");
    $(".field-missing").removeClass("field-missing");
    $("#age, #gender").removeAttr("aria-invalid");
    var items = msg.items || [], fields = msg.fields || [];
    items.forEach(function (id) {
      $("#" + id).addClass("missing").find(".shiny-input-radiogroup").attr("aria-invalid", "true");
    });
    fields.forEach(function (id) {
      $("#" + id).attr("aria-invalid", "true").closest(".form-group").addClass("field-missing");
    });
    var first = fields.length ? document.getElementById(fields[0]) :
                items.length ? document.querySelector("#" + items[0] + " input") : null;
    if (first) {
      first.closest(".form-group, .tipi-item").scrollIntoView({ behavior: "smooth", block: "center" });
      first.focus({ preventScroll: true });
    }
  });
});

// PDF download. Shiny's download link points at a URL that only exists inside
// this browser (Shinylive's service worker answers it by running R). Chrome
// doesn't send link-triggered downloads through the service worker, so it
// would ask the web host instead and fail. Fetch the file ourselves (fetch
// does go through the service worker), then save it from a local blob URL.
// Nothing leaves the device. Capture phase so this runs before Shiny's own
// handlers.
document.addEventListener("click", function (e) {
  var a = e.target.closest && e.target.closest("a.shiny-download-link");
  if (!a) return;
  e.preventDefault();
  e.stopPropagation();
  if (a.classList.contains("disabled") || !a.getAttribute("href") || a.dataset.busy) return;
  a.dataset.busy = "1";
  a.setAttribute("aria-busy", "true");
  var status = document.getElementById("save-status");
  if (status) status.textContent = "Creating your PDF…";
  // Give up after 30 s rather than leaving the button busy forever.
  var ctrl = window.AbortController ? new AbortController() : null;
  var timer = ctrl ? setTimeout(function () { ctrl.abort(); }, 30000) : null;
  fetch(a.href, ctrl ? { signal: ctrl.signal } : {})
    .then(function (resp) {
      if (!resp.ok) throw new Error("HTTP " + resp.status);
      var cd = resp.headers.get("content-disposition") || "";
      var m = cd.match(/filename="?([^";]+)"?/);
      return resp.blob().then(function (blob) {
        return { blob: blob, name: m ? m[1] : "my-tipi-results.pdf" };
      });
    })
    .then(function (file) {
      var url = URL.createObjectURL(new Blob([file.blob], { type: "application/pdf" }));
      var tmp = document.createElement("a");
      tmp.href = url;
      tmp.download = file.name;
      document.body.appendChild(tmp);
      tmp.click();
      tmp.remove();
      setTimeout(function () { URL.revokeObjectURL(url); }, 60000);
      if (status) status.textContent = "Your PDF is ready (" + file.name + ").";
    })
    .catch(function () {
      if (status) status.textContent =
        "Sorry, the PDF couldn’t be created. Please try again, or take a screenshot of your results.";
    })
    .then(function () {
      if (timer) clearTimeout(timer);
      delete a.dataset.busy;
      a.removeAttribute("aria-busy");
    });
}, true);

// A "Your PDF is ready" message refers to the answers at that moment; clear it
// when anything changes or the form is cleared.
function clearSaveStatus() {
  var s = document.getElementById("save-status");
  if (s) s.textContent = "";
}
$(document).on("change", ".tipi-item input, #age, #gender", clearSaveStatus);
$(document).on("click", "#reset", clearSaveStatus);

// Clear the highlight as soon as something is answered.
$(document).on("change", ".tipi-item input", function () {
  $(this).closest(".tipi-item").removeClass("missing")
    .find(".shiny-input-radiogroup").removeAttr("aria-invalid");
});
$(document).on("change", "#age, #gender", function () {
  $(this).removeAttr("aria-invalid").closest(".form-group").removeClass("field-missing");
});
