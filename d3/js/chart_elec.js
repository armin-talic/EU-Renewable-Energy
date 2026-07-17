/* Electricity Generation by Source
   Normalized stacked area, 2000-2024. Shows the EU-27 aggregate, or the
   selected country when one is picked on the map. */
APP.charts.push((function () {
  const { C } = APP;

  // legend order (top to bottom); stacking is the reverse, so Solar sits at the bottom
  const SOURCES = [
    { key: "coal_electricity", name: "Coal", color: "#354A40" },
    { key: "oil_electricity", name: "Oil", color: "#7A2E2B" },
    { key: "gas_electricity", name: "Gas", color: C.red },
    { key: "nuclear_electricity", name: "Nuclear", color: C.nuclear },
    { key: "hydro_electricity", name: "Hydro", color: C.green },
    { key: "biofuel_electricity", name: "Biofuel", color: C.muted },
    { key: "wind_electricity", name: "Wind", color: C.blue },
    { key: "solar_electricity", name: "Solar", color: C.yellow },
  ];
  const KEYS = SOURCES.map(s => s.key);
  const stackKeys = [...KEYS].reverse();
  const byKey = new Map(SOURCES.map(s => [s.key, s]));

  const W = 1020, H = 480;
  const M = { top: 14, right: 20, bottom: 36, left: 64 };

  function build(iso) {
    return APP.sumByYear(APP.scopeRows(iso), KEYS)
      .map(o => ({ ...o, total: d3.sum(KEYS, k => o[k] || 0) }))
      .filter(o => o.total > 0);
  }

  function init() {
    APP.legend("#elec-legend", SOURCES);
  }

  function update(iso) {
    const data = build(iso);
    const svg = APP.makeSvg("#elec", W, H);
    if (!data.length) {
      svg.append("text").attr("x", W / 2).attr("y", H / 2)
        .attr("text-anchor", "middle").attr("fill", C.muted)
        .style("font-size", "14px").style("font-style", "italic")
        .text("No electricity data for this country");
      return;
    }

    const x = d3.scaleLinear().domain([2000, 2025]).range([M.left, W - M.right]);
    const y = d3.scaleLinear().domain([0, 1]).range([H - M.bottom, M.top]);

    const series = d3.stack().keys(stackKeys).offset(d3.stackOffsetExpand)
      .value((d, k) => d[k] || 0)(data);

    const area = d3.area().x(d => x(d.data.year)).y0(d => y(d[0])).y1(d => y(d[1]));

    svg.append("g").selectAll("path")
      .data(series).join("path")
      .attr("d", area)
      .attr("fill", d => byKey.get(d.key).color)
      .attr("stroke", C.bg).attr("stroke-width", 0.4);

    APP.styleAxis(svg.append("g")
      .attr("transform", `translate(0,${H - M.bottom})`)
      .call(d3.axisBottom(x).tickValues(d3.range(2000, 2026, 5)).tickFormat(d3.format("d")).tickSize(4)));
    APP.styleAxis(svg.append("g")
      .attr("transform", `translate(${M.left},0)`)
      .call(d3.axisLeft(y).ticks(5, ".0%").tickSize(4)));

    svg.append("text")
      .attr("transform", `translate(${M.left - 44},${(M.top + H - M.bottom) / 2}) rotate(-90)`)
      .attr("text-anchor", "middle")
      .attr("fill", C.light).style("font-size", "12px").style("font-weight", "bold")
      .text("Share of Electricity");

    APP.hoverStrip(svg, {
      x, margin: M, width: W, height: H, data,
      html: rec => `
        <div class="tt-title">${APP.scopeLabel()} &middot; ${rec.year}</div>
        ${[...SOURCES].reverse()
          .filter(s => (rec[s.key] || 0) > 0)
          .map(s => `<div class="tt-row"><span><span class="sw" style="background:${s.color}"></span>${s.name}</span><span class="val">${(rec[s.key] / rec.total * 100).toFixed(1)}%</span></div>`)
          .join("")}
        <div class="tt-row" style="margin-top:4px;border-top:1px solid ${C.axis};padding-top:4px"><span>Total</span><span class="val">${APP.fmtTWh(rec.total)} TWh</span></div>`,
    });
  }

  return { init, update };
})());
