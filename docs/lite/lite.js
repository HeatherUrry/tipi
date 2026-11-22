// Lightweight TIPI page. All numbers were precomputed in R (build_lite.R ->
// data.js); this script only adds up item answers, looks results up, and draws
// the charts. It sends nothing anywhere and stores nothing (no cookies, no
// local or session storage). Answers disappear when the page is closed or
// reloaded.
(function () {
  "use strict";
  var D = window.TIPI_DATA;
  var C = { accent: "#1F5F99", ink: "#1D2433", muted: "#5B6475", grid: "#9AA4B2",
            bands: ["#EEF1F5", "#DCE2EA", "#DCE2EA", "#EEF1F5"] };
  var FONT = 'system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';
  // Same label splits as the R charts (app/tipi_plots.R)
  var NARROW_SIDE = { "Extraversion": ["Extra-", "version"], "Agreeableness": ["Agree-", "ableness"],
    "Conscientiousness": ["Conscien-", "tiousness"], "Emotional Stability": ["Emotional", "Stability"],
    "Openness to Experiences": ["Openness to", "Experiences"] };
  var TWO_LINE = { "Openness to Experiences": ["Openness to", "Experiences"],
    "Emotional Stability": ["Emotional", "Stability"] };
  var SVGNS = "http://www.w3.org/2000/svg";
  var state = { tried: false, shown: false, rows: null };
  function $(id) { return document.getElementById(id); }

  // ---- Answers and messages ---------------------------------------------------
  function answers() {
    var a = [];
    for (var i = 1; i <= 10; i++) {
      var c = document.querySelector('input[name="q' + i + '"]:checked');
      a.push(c ? Number(c.value) : null);
    }
    return a;
  }
  function missingItems() {
    return answers().map(function (v, i) { return v === null ? i + 1 : 0; }).filter(Boolean);
  }
  function complete() {
    return missingItems().length === 0 && $("age").value !== "" && $("gender").value !== "";
  }
  function joinAnd(x) {
    if (x.length <= 1) return x.join("");
    if (x.length === 2) return x[0] + " and " + x[1];
    return x.slice(0, -1).join(", ") + ", and " + x[x.length - 1];
  }
  function currentMessage() {   // same wording as missing_message() in app/tipi_text.R
    var fields = [], items = missingItems(), parts = [];
    if ($("age").value === "") fields.push("age");
    if ($("gender").value === "") fields.push("gender");
    if (fields.length) parts.push("choose your " + joinAnd(fields));
    if (items.length) parts.push((items.length > 1 ? "answer items " : "answer item ") + joinAnd(items.map(String)));
    return parts.length ? "Please " + parts.join(", and ") + "." : "";
  }
  function setBox(id, text, role) {
    var box = $(id);
    box.textContent = "";
    if (!text) return;
    var d = document.createElement("div");
    d.className = "alert-box";
    d.setAttribute("role", role);
    d.textContent = text;
    box.appendChild(d);
  }
  function markMissing() {
    document.querySelectorAll(".tipi-item").forEach(function (el) {
      el.classList.remove("missing");
      el.querySelector('[role="radiogroup"]').removeAttribute("aria-invalid");
    });
    ["age", "gender"].forEach(function (id) {
      $(id).removeAttribute("aria-invalid");
      $(id).closest(".form-group").classList.remove("field-missing");
    });
    var first = null;
    ["age", "gender"].forEach(function (id) {
      if ($(id).value === "") {
        $(id).setAttribute("aria-invalid", "true");
        $(id).closest(".form-group").classList.add("field-missing");
        first = first || $(id);
      }
    });
    missingItems().forEach(function (n) {
      var item = $("item" + n);
      item.classList.add("missing");
      item.querySelector('[role="radiogroup"]').setAttribute("aria-invalid", "true");
      first = first || item.querySelector("input");
    });
    if (first) {
      first.closest(".form-group, .tipi-item").scrollIntoView({ behavior: "smooth", block: "center" });
      first.focus({ preventScroll: true });
    }
  }

  // ---- Results (lookups into R's tables) -------------------------------------------
  function results() {
    var r = answers(), grp = D.groups[$("gender").value + "|" + $("age").value], score = {};
    D.key.forEach(function (k) { score[k.trait] = (r[k.item - 1] + 8 - r[k.item_rev - 1]) / 2; });
    return { description: grp.description, rows: D.traits.map(function (t) {
      var i = Math.round((score[t] - 1) * 2), tr = grp.traits[t];
      return { trait: t, score: score[t], mean: tr.mean, pct: tr.pct[i], label: tr.label[i], band: tr.band[i] };
    }) };
  }

  // ---- Drawing helpers -----------------------------------------------------------
  var ctx = document.createElement("canvas").getContext("2d");
  function textWidth(s, px, bold) {
    ctx.font = (bold ? "700 " : "400 ") + px + "px " + FONT;
    return ctx.measureText(s).width;
  }
  function svgEl(name, attrs, parent) {
    var e = document.createElementNS(SVGNS, name);
    Object.keys(attrs).forEach(function (k) { e.setAttribute(k, attrs[k]); });
    if (parent) parent.appendChild(e);
    return e;
  }
  function svgText(parent, x, y, s, size, fill, anchor, bold) {
    var t = svgEl("text", { x: x, y: y, "font-size": size, "font-weight": bold ? 700 : 400,
      "font-family": FONT, fill: fill, "text-anchor": anchor, "dominant-baseline": "central" }, parent);
    t.textContent = s;
    return t;
  }
  function newSvg(box, W, H, label) {
    box.textContent = "";
    var svg = svgEl("svg", { width: W, height: H, viewBox: "0 0 " + W + " " + H, role: "img",
                             "aria-label": label }, box);
    return svg;
  }
  function altText(kind, rows) {
    return kind + " Your percentiles: " + rows.map(function (r) { return r.trait + " " + r.label; }).join("; ") + ".";
  }

  // ---- Spider chart ----------------------------------------------------------------
  // Same design as plot_radar() in app/tipi_plots.R: 0 at the centre, 100 at
  // the rim, dashed ring at the 50th percentile, labels sized to fit.
  function labelLines(trait, pos, narrow) {
    var sp = trait.indexOf(" ");
    var split = sp > 0 ? [trait.slice(0, sp), trait.slice(sp + 1)] : [trait];
    if (narrow) {
      if (pos === "side" && NARROW_SIDE[trait]) return NARROW_SIDE[trait];
      return TWO_LINE[trait] || split;
    }
    return pos === "side" ? split : [trait];
  }
  function drawRadar(box, rows, Wfull) {
    var W = Math.min(Wfull, 600), k = rows.length, pad = 4, narrow = W < 432;
    var ang = rows.map(function (_, i) { return Math.PI / 2 - 2 * Math.PI * i / k; });
    var pos = ang.map(function (a) { return Math.sin(a) > 0.9 ? "top" : Math.sin(a) < -0.5 ? "bottom" : "side"; });
    var lines = rows.map(function (r, i) { return labelLines(r.trait, pos[i], narrow); });
    var bottoms = pos.map(function (p, i) { return p === "bottom" ? i : -1; }).filter(function (i) { return i >= 0; });
    var best = null, fallback = null;
    for (var fs = narrow ? 13 : 15; fs >= 10 && !best; fs -= 0.5) {
      var L = rows.map(function (r, i) {
        return Math.max.apply(null, lines[i].concat([r.label]).map(function (s) { return textWidth(s, fs, true); }));
      });
      [0, 0.15, 0.3, 0.45].some(function (lean) {
        var h = pos.map(function (p, i) {
          var c = Math.cos(ang[i]);
          return p === "top" ? 0.5 : p === "side" ? (c > 0 ? 0 : 1) : (c > 0 ? 0.5 - lean : 0.5 + lean);
        });
        var Rmax = Math.min(W * 0.36, 230), Rmin = 0;
        rows.forEach(function (_, i) {
          var c = 1.1 * Math.cos(ang[i]);
          if (c > 1e-9) Rmax = Math.min(Rmax, (W / 2 - pad - (1 - h[i]) * L[i]) / c);
          else if (c < -1e-9) Rmax = Math.min(Rmax, (W / 2 - pad - h[i] * L[i]) / -c);
          else if (L[i] > W - 2 * pad) Rmax = 0;
        });
        if (bottoms.length === 2) {   // keep the two bottom labels apart
          var l = Math.cos(ang[bottoms[0]]) < 0 ? bottoms[0] : bottoms[1], rr = l === bottoms[0] ? bottoms[1] : bottoms[0];
          var sep = 1.1 * (Math.cos(ang[rr]) - Math.cos(ang[l]));
          Rmin = ((1 - h[l]) * L[l] + h[rr] * L[rr] + 12) / sep;
        }
        var cand = { fs: fs, L: L, h: h, R: Rmax };
        if (Rmax >= Rmin && (!fallback || Rmax > fallback.R)) fallback = cand;
        if (Rmax >= Rmin && Rmax >= 0.25 * W) { best = cand; return true; }
        return false;
      });
    }
    var lay = best || fallback || { fs: 10, h: pos.map(function () { return 0.5; }), R: W * 0.2 };
    fs = lay.fs; var R = Math.max(lay.R, 30), lh = fs * 1.3, cx = W / 2;
    var nTop = lines[pos.indexOf("top")].length + 1;
    var cy = pad + nTop * lh + 1.1 * R;
    // label line centres
    var place = rows.map(function (r, i) {
      var ax = cx + 1.1 * R * Math.cos(ang[i]), ay = cy - 1.1 * R * Math.sin(ang[i]);
      var n = lines[i].length, ys;
      if (pos[i] === "top") { var top = ay - (n + 1) * lh; ys = []; for (var j = 0; j <= n; j++) ys.push(top + (j + 0.5) * lh); }
      else if (pos[i] === "side") { ys = []; for (var j2 = 0; j2 < n; j2++) ys.push(ay - (n - j2 - 0.5) * lh); ys.push(ay + 0.5 * lh); }
      else { var t0 = ay - 0.15 * lh; ys = []; for (var j3 = 0; j3 <= n; j3++) ys.push(t0 + (j3 + 0.5) * lh); }
      return { ax: ax, ys: ys };
    });
    var H = Math.ceil(Math.max(cy + R, Math.max.apply(null, place.map(function (p) { return p.ys[p.ys.length - 1]; })) + lh / 2) + pad);
    var svg = newSvg(box, W, H, altText("Spider chart.", rows));
    function poly(r) {
      return ang.map(function (a) { return (cx + r * R * Math.cos(a)) + "," + (cy - r * R * Math.sin(a)); }).join(" ");
    }
    [0.25, 0.75, 1].forEach(function (r) { svgEl("polygon", { points: poly(r), fill: "none", stroke: C.grid, "stroke-width": 1 }, svg); });
    ang.forEach(function (a) { svgEl("line", { x1: cx, y1: cy, x2: cx + R * Math.cos(a), y2: cy - R * Math.sin(a), stroke: C.grid, "stroke-width": 1 }, svg); });
    svgEl("polygon", { points: poly(0.5), fill: "none", stroke: C.muted, "stroke-width": 1.6, "stroke-dasharray": "5 4" }, svg);
    // ring labels just outside each ring's edge, between the first two spokes
    var mid = (ang[0] + ang[1]) / 2;
    (narrow ? [0.5, 1] : [0.25, 0.5, 0.75, 1]).forEach(function (r) {
      var d = (r * Math.cos(Math.PI / k) + 0.07) * R;
      svgText(svg, cx + d * Math.cos(mid), cy - d * Math.sin(mid), String(r * 100), 0.72 * fs, C.muted, "middle", false);
    });
    var pts = rows.map(function (r, i) {
      var v = Math.min(Math.max(r.pct, 0.5), 100) / 100;
      return [cx + v * R * Math.cos(ang[i]), cy - v * R * Math.sin(ang[i])];
    });
    svgEl("polygon", { points: pts.map(function (p) { return p.join(","); }).join(" "),
      fill: C.accent, "fill-opacity": 0.22, stroke: C.accent, "stroke-width": 3, "stroke-linejoin": "round" }, svg);
    pts.forEach(function (p) { svgEl("circle", { cx: p[0], cy: p[1], r: 5.5, fill: C.accent, stroke: "#fff", "stroke-width": 1.5 }, svg); });
    rows.forEach(function (r, i) {
      var h = lay.h[i], x = place[i].ax;
      // hadj like R's adj: 0 = text extends right of x, 1 = extends left, 0.5 = centred
      var widest = Math.max.apply(null, lines[i].concat([r.label]).map(function (s) { return textWidth(s, fs, true); }));
      var anchor = "middle", xs = x + (0.5 - h) * widest;
      if (h === 0) { anchor = "start"; xs = x; } else if (h === 1) { anchor = "end"; xs = x; }
      lines[i].forEach(function (ln, j) { svgText(svg, xs, place[i].ys[j], ln, fs, C.ink, anchor, true); });
      svgText(svg, xs, place[i].ys[lines[i].length], r.label, fs, C.accent, anchor, true);
    });
  }

  // ---- Percentile strips -----------------------------------------------------------
  // Same design as plot_strips() in app/tipi_plots.R.
  function drawStrips(box, rows, W) {
    var fs = W < 480 ? 13 : 15, suffix = " percentile";
    function fits(f, suf) {
      return rows.every(function (r) { return textWidth(r.trait, f, true) + textWidth(r.label + suf, 0.95 * f, true) + 14 <= W; });
    }
    if (!fits(fs, suffix)) suffix = "";
    while (!fits(fs, suffix) && fs > 10) fs -= 0.5;
    var rowH = fs * 1.3 + 34, barH = 16, edges = [0].concat(D.band_cuts, [100]);
    var H = Math.ceil(rows.length * rowH + 44);
    var svg = newSvg(box, W, H, altText("Percentile strips.", rows));
    function X(p) { return p / 100 * W; }
    rows.forEach(function (r, i) {
      var top = i * rowH, ty = top + fs * 0.7, by = top + fs * 1.3 + 10;
      for (var b = 0; b < 4; b++) {
        svgEl("rect", { x: X(edges[b]), y: by, width: X(edges[b + 1]) - X(edges[b]), height: barH, fill: C.bands[b] }, svg);
      }
      [D.band_cuts[0], D.band_cuts[2]].forEach(function (c) {
        svgEl("line", { x1: X(c), y1: by, x2: X(c), y2: by + barH, stroke: C.muted, "stroke-width": 1 }, svg);
      });
      svgEl("line", { x1: X(50), y1: by - 3, x2: X(50), y2: by + barH + 3, stroke: C.muted, "stroke-width": 1, "stroke-dasharray": "3 3" }, svg);
      svgText(svg, 0, ty, r.trait, fs, C.ink, "start", true);
      svgText(svg, W, ty, r.label + suffix, 0.95 * fs, C.accent, "end", true);
      svgEl("circle", { cx: X(Math.min(Math.max(r.pct, 1), 99)), cy: by + barH / 2, r: 8.5, fill: C.accent, stroke: "#fff", "stroke-width": 1.5 }, svg);
    });
    var yb = rows.length * rowH + 10;
    D.bands.forEach(function (name, b) { svgText(svg, X((edges[b] + edges[b + 1]) / 2), yb, name, 0.82 * fs, C.muted, "middle", false); });
    svgText(svg, 0, yb + 22, "0", 0.75 * fs, C.muted, "start", false);
    svgText(svg, X(50), yb + 22, "50", 0.75 * fs, C.muted, "middle", false);
    svgText(svg, W, yb + 22, "100", 0.75 * fs, C.muted, "end", false);
  }

  // ---- Results table -----------------------------------------------------------------
  function drawTable(box, rows) {
    box.textContent = "";
    var t = document.createElement("table");
    t.className = "res-table";
    t.innerHTML = '<caption class="sr-only">Your scores and percentiles</caption>' +
      '<thead><tr><th scope="col">Trait</th><th scope="col" class="num">Your score<br><small>(1–7)</small></th>' +
      '<th scope="col" class="num avg-col">Group average</th><th scope="col" class="num">Percentile</th>' +
      '<th scope="col">Range</th></tr></thead><tbody></tbody>';
    var body = t.querySelector("tbody");
    rows.forEach(function (r) {
      var tr = document.createElement("tr");
      [["th", r.trait, ""], ["td", r.score.toFixed(1), "num"], ["td", r.mean, "num avg-col"],
       ["td", r.label, "num strong"], ["td", r.band, "band"]].forEach(function (c) {
        var cell = document.createElement(c[0]);
        if (c[0] === "th") cell.setAttribute("scope", "row");
        if (c[2]) cell.className = c[2];
        cell.textContent = c[1];
        tr.appendChild(cell);
      });
      body.appendChild(tr);
    });
    box.appendChild(t);
  }

  // ---- Rendering and state -------------------------------------------------------------
  function drawCharts(width) {
    if (!state.rows) return;
    drawRadar($("radar"), state.rows, width || $("radar").clientWidth || 600);
    drawStrips($("strips"), state.rows, width || $("strips").clientWidth || 600);
  }
  function render() {
    var res = results();
    state.rows = res.rows;
    var g = $("group-text");
    g.textContent = "You're compared with ";
    var s = document.createElement("strong");
    s.textContent = res.description;
    g.appendChild(s);
    g.appendChild(document.createTextNode("."));
    drawCharts();
    drawTable($("table"), res.rows);
  }
  function refresh() {
    if (state.tried) setBox("problems", complete() ? "" : currentMessage(), "status");
    if (!state.shown) return;
    if (complete()) {
      setBox("incomplete", "", "alert");
      $("results-body").hidden = false;
      render();
    } else {
      $("results-body").hidden = true;
      setBox("incomplete", "Your results are hidden because something is now unanswered. " + currentMessage(), "alert");
    }
  }

  document.addEventListener("change", function (e) {
    var item = e.target.closest && e.target.closest(".tipi-item");
    if (item) {
      item.classList.remove("missing");
      item.querySelector('[role="radiogroup"]').removeAttribute("aria-invalid");
    }
    if (e.target.id === "age" || e.target.id === "gender") {
      e.target.removeAttribute("aria-invalid");
      e.target.closest(".form-group").classList.remove("field-missing");
    }
    refresh();
  });

  $("go").addEventListener("click", function () {
    markMissing();
    if (!complete()) {
      state.tried = true;
      setBox("problems", currentMessage(), "status");
      return;
    }
    state.tried = false;
    setBox("problems", "", "status");
    state.shown = true;
    $("results").hidden = false;
    refresh();
    setTimeout(function () {
      $("results").scrollIntoView({ behavior: "smooth", block: "start" });
      $("res-h").focus({ preventScroll: true });
    }, 50);
  });

  $("reset").addEventListener("click", function () {
    document.querySelectorAll('.tipi-item input[type="radio"]').forEach(function (r) { r.checked = false; });
    $("age").value = "";
    $("gender").value = "";
    state.tried = false;
    state.shown = false;
    state.rows = null;
    setBox("problems", "", "status");
    setBox("incomplete", "", "alert");
    document.querySelectorAll(".missing").forEach(function (el) { el.classList.remove("missing"); });
    document.querySelectorAll(".field-missing").forEach(function (el) { el.classList.remove("field-missing"); });
    document.querySelectorAll('[aria-invalid]').forEach(function (el) { el.removeAttribute("aria-invalid"); });
    $("results").hidden = true;
    $("top").scrollIntoView({ behavior: "smooth", block: "start" });
    $("page-title").focus({ preventScroll: true });
  });

  // Print / save as PDF: the browser's own print window (works on phones too,
  // since this page isn't inside a frame). Charts are redrawn at a fixed width
  // for the page and restored afterwards.
  var openedDetails = [];
  function beforePrint() {
    var d = new Date();
    $("print-head").textContent = "Ten-Item Personality Inventory (TIPI) · " +
      d.toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" });
    openedDetails = Array.prototype.filter.call(document.querySelectorAll("details"), function (x) { return !x.open; });
    openedDetails.forEach(function (x) { x.open = true; });
    drawCharts(620);
  }
  function afterPrint() {
    openedDetails.forEach(function (x) { x.open = false; });
    openedDetails = [];
    drawCharts();
  }
  window.addEventListener("beforeprint", beforePrint);
  window.addEventListener("afterprint", afterPrint);
  $("print").addEventListener("click", function () { window.print(); });

  // Redraw the charts when the available width changes (rotation, resizing).
  var lastWidth = 0, pending = false;
  new ResizeObserver(function () {
    var w = $("radar").clientWidth;
    if (!state.rows || w === lastWidth || pending) return;
    pending = true;
    requestAnimationFrame(function () { pending = false; lastWidth = $("radar").clientWidth; drawCharts(); });
  }).observe($("results"));
})();
