/* Coal vs. Renewables (Electricity Generation)
   Absolute TWh, 2000-2024, for the EU-27 aggregate or the selected country.
   The ribbon between the lines is green where renewables lead, dark red where
   coal leads, with the crossover point interpolated exactly. */
APP.charts.push((function () {
  const { C } = APP;

  const COL = { Coal: C.darkRed, Renewables: C.brightGreen };
  const KEYS = ["coal_electricity", "renewables_electricity"];

  const W = 1020, H = 480;
  const M = { top: 14, right: 20, bottom: 36, left: 68 };

  function build(iso) {
    return APP.sumByYear(APP.scopeRows(iso), KEYS)
      .map(o => ({ x: o.year, a: o.coal_electricity || 0, b: o.renewables_electricity || 0 }))
      .filter(d => d.a > 0 || d.b > 0);
  }

  function init() {
    APP.legend("#coalren-legend",
      Object.entries(COL).map(([name, color]) => ({ name, color })), { line: true });
  }

  /* One-line verdict on when renewables overtook coal for the current scope.
     Uses the year of the final upward crossing (renewables above coal through
     the end of the series). */
  function crossoverText(data) {
    if (!data.length) return "";
    const first = data[0], last = data[data.length - 1];
    if (last.b <= last.a) {
      return `Renewables have <b>not yet overtaken coal</b> here: ${APP.fmtTWh(last.a)} vs ${APP.fmtTWh(last.b)} TWh in ${last.x}.`;
    }
    let j = null;
    for (let i = 1; i < data.length; i++) {
      if (data[i - 1].b <= data[i - 1].a && data[i].b > data[i].a) j = i;
    }
    if (j === null) {
      return `Renewables have out-generated coal throughout ${first.x}-${last.x}.`;
    }
    const ratio = last.a > 0
      ? `and now generate <b>${(last.b / last.a).toFixed(1)}x</b> as much`
      : `and coal has since fallen to zero`;
    return `Renewables overtook coal in <b>${data[j].x}</b> ${ratio}.`;
  }

  function update(iso) {
    const data = build(iso);
    d3.select("#coalren-cross").html(crossoverText(data));
    const svg = APP.makeSvg("#coalren", W, H);
    if (!data.length) {
      svg.append("text").attr("x", W / 2).attr("y", H / 2)
        .attr("text-anchor", "middle").attr("fill", C.muted)
        .style("font-size", "14px").style("font-style", "italic")
        .text("No electricity data for this country");
      return;
    }

    const x = d3.scaleLinear().domain([2000, 2025]).range([M.left, W - M.right]);
    const hi = d3.max(data, d => Math.max(d.a, d.b));
    const y = d3.scaleLinear().domain([0, hi * 1.06]).nice().range([H - M.bottom, M.top]);

    const area = d3.area()
      .x(d => x(d.x))
      .y0(d => y(Math.min(d.a, d.b)))
      .y1(d => y(Math.max(d.a, d.b)));
    svg.append("g").selectAll("path")
      .data(APP.ribbonSegments(data)).join("path")
      .attr("d", d => area(d.points))
      .attr("fill", d => d.above === "a" ? C.darkRed : C.brightGreen)
      .attr("fill-opacity", 0.22);

    const line = key => d3.line().x(d => x(d.x)).y(d => y(d[key]));
    svg.append("path").datum(data).attr("d", line("a"))
      .attr("fill", "none").attr("stroke", COL.Coal).attr("stroke-width", 2.2);
    svg.append("path").datum(data).attr("d", line("b"))
      .attr("fill", "none").attr("stroke", COL.Renewables).attr("stroke-width", 2.2);

    APP.styleAxis(svg.append("g")
      .attr("transform", `translate(0,${H - M.bottom})`)
      .call(d3.axisBottom(x).tickValues(d3.range(2000, 2026, 5)).tickFormat(d3.format("d")).tickSize(4)));
    APP.styleAxis(svg.append("g")
      .attr("transform", `translate(${M.left},0)`)
      .call(d3.axisLeft(y).ticks(6).tickSize(4)));

    svg.append("text")
      .attr("transform", `translate(${M.left - 48},${(M.top + H - M.bottom) / 2}) rotate(-90)`)
      .attr("text-anchor", "middle")
      .attr("fill", C.light).style("font-size", "12px").style("font-weight", "bold")
      .text("Generation (TWh)");

    APP.hoverStrip(svg, {
      x, margin: M, width: W, height: H, data,
      html: rec => `
        <div class="tt-title">${APP.scopeLabel()} &middot; ${rec.x}</div>
        <div class="tt-row"><span><span class="sw" style="background:${COL.Renewables}"></span>Renewables</span><span class="val">${APP.fmtTWh(rec.b)} TWh</span></div>
        <div class="tt-row"><span><span class="sw" style="background:${COL.Coal}"></span>Coal</span><span class="val">${APP.fmtTWh(rec.a)} TWh</span></div>`,
    });
  }

  return { init, update };
})());
