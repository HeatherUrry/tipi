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

// Clear the highlight as soon as something is answered.
$(document).on("change", ".tipi-item input", function () {
  $(this).closest(".tipi-item").removeClass("missing")
    .find(".shiny-input-radiogroup").removeAttr("aria-invalid");
});
$(document).on("change", "#age, #gender", function () {
  $(this).removeAttr("aria-invalid").closest(".form-group").removeClass("field-missing");
});
