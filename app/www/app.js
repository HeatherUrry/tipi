// Small UI helpers. Nothing here stores or sends data.
$(document).on("shiny:connected", function () {
  Shiny.addCustomMessageHandler("scroll_to", function (id) {
    setTimeout(function () {
      var el = document.getElementById(id);
      if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
    }, 150);
  });

  // Highlight unanswered items/fields; jump to the first one.
  Shiny.addCustomMessageHandler("mark_missing", function (msg) {
    $(".tipi-item").removeClass("missing");
    $(".field-missing").removeClass("field-missing");
    var items = msg.items || [], fields = msg.fields || [];
    items.forEach(function (id) { $("#" + id).addClass("missing"); });
    fields.forEach(function (id) { $("#" + id).closest(".form-group").addClass("field-missing"); });
    var first = fields.length ? document.getElementById(fields[0]) :
                items.length ? document.getElementById(items[0]) : null;
    if (first) first.scrollIntoView({ behavior: "smooth", block: "center" });
  });
});

// Clear the highlight as soon as something is answered.
$(document).on("change", ".tipi-item input", function () {
  $(this).closest(".tipi-item").removeClass("missing");
});
$(document).on("change", "#age, #gender", function () {
  $(this).closest(".form-group").removeClass("field-missing");
});
