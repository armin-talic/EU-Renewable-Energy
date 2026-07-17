/* Shared state, data unpacking, helpers.
   The map is the dashboard's filter: exactly one country can be selected, or
   none, in which case every chart falls back to the EU-27 aggregate.
   Each chart file registers itself in APP.charts as { init(), update(iso) }
   where iso is the selected country code or null for EU-27. */
window.APP = (function () {

  // Design system (mirrors the R script)
  const C = {
    bg: "#22332B", bgDeep: "#1E2D26", mapLow: "#2A3D34",
    yellow: "#E1D566", green: "#558C77", brightGreen: "#7AC994",
    red: "#C25953", darkRed: "#7A2E2B", blue: "#628395", nuclear: "#8C7A6B",
    light: "#F4F1EA", muted: "#A4B5AC", axis: "#354A40",
    dim: "#354A40", dimDeep: "#2A3D34",
  };

  // ---- unpack the compact data ----
  const raw = window.ENERGY_RAW;
  const rows = raw.rows.map(r => {
    const o = {};
    raw.columns.forEach((c, i) => { o[c] = r[i]; });
    return o;
  });
  const byIso = d3.group(rows, d => d.iso);
  byIso.forEach(list => list.sort((a, b) => a.year - b.year));
  const isoName = new Map();
  rows.forEach(r => { if (!isoName.has(r.iso)) isoName.set(r.iso, r.country); });

  // ---- 2024 snapshot (Malta falls back to its latest year with data) ----
  const snapshot = [];
  byIso.forEach((list) => {
    let rec = list.find(d => d.year === 2024 && d.primary_energy_consumption != null);
    if (!rec) rec = [...list].reverse().find(d => d.primary_energy_consumption != null);
    if (rec) snapshot.push({ ...rec, fallback: rec.year !== 2024 });
  });
  snapshot.sort((a, b) => b.primary_energy_consumption - a.primary_energy_consumption);
  snapshot.forEach((d, i) => {
    d.rank = i + 1;
    d.display = d.fallback ? d.country + "*" : d.country;
  });
  const snapByIso = new Map(snapshot.map(d => [d.iso, d]));

  const totalEU = d3.sum(snapshot, d => d.primary_energy_consumption);
  const top5Pct = d3.sum(snapshot.slice(0, 5), d => d.primary_energy_consumption) / totalEU * 100;

  // ---- selection state ----
  let selected = null;          // iso code, or null for the EU-27 aggregate
  const charts = [];

  function scopeLabel() {
    return selected ? isoName.get(selected) : "EU-27";
  }

  function toggle(iso) {
    selected = (selected === iso) ? null : iso;
    update();
  }

  function clear() {
    selected = null;
    update();
  }

  function buildSidebar() {
    const names = [...isoName.entries()]
      .map(([iso, name]) => ({ iso, name }))
      .sort((a, b) => a.name.localeCompare(b.name));
    d3.select("#country-list").selectAll("div.side-item")
      .data(names).join("div")
      .attr("class", "side-item")
      .text(d => d.name)
      .on("click", (event, d) => toggle(d.iso));
    d3.select("#side-eu").on("click", clear);
  }

  function renderFilterState() {
    d3.select("#side-eu").classed("active", !selected);
    d3.select("#country-list").selectAll("div.side-item")
      .classed("active", d => d.iso === selected);
  }

  function update() {
    renderFilterState();
    d3.selectAll(".scope")
      .text(`(${scopeLabel()})`)
      .classed("active", !!selected);
    charts.forEach(ch => ch.update(selected));
  }

  /* Rows for the current scope: every EU-27 row (aggregate) or one country's. */
  function scopeRows(iso) {
    return iso ? (byIso.get(iso) || []) : rows;
  }

  /* Sum the given columns per year over a row set. Years where every column is
     empty are dropped, so partial country coverage does not draw a zero cliff. */
  function sumByYear(list, keys) {
    const out = [];
    for (let yr = 2000; yr <= 2025; yr++) {
      const recs = list.filter(d => d.year === yr);
      if (!recs.length) continue;
      const o = { year: yr };
      let any = false;
      keys.forEach(k => {
        const vals = recs.filter(d => d[k] != null);
        o[k] = d3.sum(vals, d => d[k]);
        if (vals.length) any = true;
      });
      if (any) out.push(o);
    }
    return out;
  }

  // ---- formatting helpers ----
  const fmtComma = d3.format(",.0f");
  const fmt1 = d3.format(",.1f");
  const fmtK = v => `${Math.round(v / 1000)} K`;
  const fmtPct = v => `${Math.round(v)}%`;
  const fmtTWh = v => (v >= 100 ? fmtComma(v) : fmt1(v));

  // ---- tooltip ----
  const tt = d3.select("#tooltip");
  function showTooltip(event, html) {
    tt.html(html).style("opacity", 1);
    const node = tt.node();
    const w = node.offsetWidth, h = node.offsetHeight;
    let x = event.clientX + 14, y = event.clientY + 12;
    if (x + w > window.innerWidth - 8) x = event.clientX - w - 14;
    if (y + h > window.innerHeight - 8) y = event.clientY - h - 12;
    tt.style("left", x + "px").style("top", y + "px");
  }
  function hideTooltip() { tt.style("opacity", 0); }

  // ---- shared svg scaffolding ----
  function makeSvg(sel, width, height) {
    const host = d3.select(sel);
    host.selectAll("svg").remove();
    return host.append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)
      .attr("preserveAspectRatio", "xMidYMid meet");
  }

  function styleAxis(g, { muted = false } = {}) {
    g.selectAll("text").attr("fill", muted ? C.muted : C.light).style("font-size", "11px");
    g.selectAll("line").attr("stroke", C.axis);
    g.select(".domain").attr("stroke", C.axis);
    return g;
  }

  function legend(sel, items, { line = false } = {}) {
    const box = d3.select(sel);
    box.selectAll("*").remove();
    items.forEach(it => {
      const item = box.append("div").attr("class", "legend-item");
      item.append("div")
        .attr("class", line ? "legend-line" : "legend-swatch")
        .style("background", it.color);
      item.append("div").attr("class", "legend-name").text(it.name);
    });
  }

  /* Split two series into contiguous ribbon segments, inserting the exact
     crossing points, so each segment can be filled by whichever is on top.
     data: [{x, a, b}] -> [{above: "a"|"b", points: [{x, a, b}, ...]}] */
  function ribbonSegments(data) {
    const segs = [];
    let cur = null;
    const side = d => (d.a >= d.b ? "a" : "b");
    for (let i = 0; i < data.length; i++) {
      const d = data[i];
      if (!cur) { cur = { above: side(d), points: [d] }; continue; }
      if (side(d) === cur.above) {
        cur.points.push(d);
      } else {
        const p = data[i - 1];
        const denom = (d.a - d.b) - (p.a - p.b);
        const t = denom === 0 ? 0.5 : (0 - (p.a - p.b)) / denom;
        const cross = { x: p.x + t * (d.x - p.x), a: p.a + t * (d.a - p.a) };
        cross.b = cross.a;
        cur.points.push(cross);
        segs.push(cur);
        cur = { above: side(d), points: [cross, d] };
      }
    }
    if (cur) segs.push(cur);
    return segs;
  }

  /* Shared hover strip: reports the year under the cursor. */
  function hoverStrip(svg, { x, margin, width, height, data, html }) {
    svg.append("rect")
      .attr("x", margin.left).attr("y", margin.top)
      .attr("width", Math.max(1, width - margin.right - margin.left))
      .attr("height", Math.max(1, height - margin.top - margin.bottom))
      .attr("fill", "transparent")
      .on("mousemove", function (event) {
        const [mx] = d3.pointer(event, this);
        const yr = Math.round(x.invert(mx));
        const rec = data.find(d => (d.year ?? d.x) === yr);
        if (!rec) return hideTooltip();
        showTooltip(event, html(rec));
      })
      .on("mouseleave", hideTooltip);
  }

  function start() {
    d3.select("#top5-pct").text(top5Pct.toFixed(1));
    buildSidebar();
    charts.forEach(ch => ch.init());
    update();
  }

  return {
    C, rows, byIso, isoName, snapshot, snapByIso, totalEU,
    charts, toggle, clear, start, scopeLabel, scopeRows, sumByYear,
    selected: () => selected,
    isSelected: iso => selected === iso,
    fmtComma, fmt1, fmtK, fmtPct, fmtTWh,
    showTooltip, hideTooltip, makeSvg, styleAxis, legend, ribbonSegments, hoverStrip,
  };
})();
