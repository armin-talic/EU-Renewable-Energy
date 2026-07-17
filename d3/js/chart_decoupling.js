/* Efficiency & Decoupling
   GDP versus primary energy use, indexed to 2000 = 100, for the EU-27
   aggregate or the selected country. OWID's GDP series stops in 2022, so the
   chart ends there. The y domain is fitted per scope: national GDP indices
   range far wider than the EU aggregate (Ireland and Romania more than double). */
APP.charts.push((function () {
  const { C } = APP;

  const COL = { "Energy Use": C.yellow, "GDP": C.blue };
  const KEYS = ["gdp", "primary_energy_consumption"];

  const W = 1020, H = 510;
  const M = { top: 18, right: 74, bottom: 40, left: 68 };

  function build(iso) {
    // only years where a country reports both figures contribute, so the
    // aggregate index is never distorted by a half-reported country
    const src = APP.scopeRows(iso)
      .filter(d => d.gdp != null && d.primary_energy_consumption != null);
    const series = APP.sumByYear(src, KEYS)
      .filter(o => o.gdp > 0 && o.primary_energy_consumption > 0);
    const base = series.find(o => o.year === 2000);
    if (!base) return [];
    return series.map(o => ({
      x: o.year,
      gdp: o.gdp / base.gdp * 100,
      energy: o.primary_energy_consumption / base.primary_energy_consumption * 100,
    }));
  }

  function init() {
    APP.legend("#dec-legend",
      [{ name: "Energy Use", color: COL["Energy Use"] }, { name: "GDP", color: COL.GDP }],
      { line: true });
  }

  function update(iso) {
    const data = build(iso);
    const svg = APP.makeSvg("#dec", W, H);
    const gapBox = d3.select("#dec-gap");

    if (!data.length) {
      gapBox.text("");
      svg.append("text").attr("x", W / 2).attr("y", H / 2)
        .attr("text-anchor", "middle").attr("fill", C.muted)
        .style("font-size", "14px").style("font-style", "italic")
        .text("No GDP data for this country");
      return;
    }

    const last = data[data.length - 1];
    const gap = last.gdp - last.energy;
    gapBox.html(`${APP.scopeLabel()}: GDP <span class="gap-val">${last.gdp >= 100 ? "+" : ""}${(last.gdp - 100).toFixed(1)}%</span>,
      energy use <span class="gap-val">${last.energy >= 100 ? "+" : ""}${(last.energy - 100).toFixed(1)}%</span>
      by ${last.x}, a gap of <span class="gap-val">${gap >= 0 ? "+" : ""}${gap.toFixed(1)} pts</span>.`);

    const x = d3.scaleLinear().domain([2000, last.x]).range([M.left, W - M.right]);

    // fit the domain to the data, but always keep the 100 baseline in view
    const vals = data.flatMap(d => [d.gdp, d.energy]).concat([100]);
    let [lo, hi] = d3.extent(vals);
    const pad = Math.max((hi - lo) * 0.12, 4);
    const y = d3.scaleLinear().domain([lo - pad, hi + pad]).nice().range([H - M.bottom, M.top]);

    svg.append("path").datum(data)
      .attr("d", d3.area().x(d => x(d.x)).y0(d => y(d.energy)).y1(d => y(d.gdp)))
      .attr("fill", C.brightGreen).attr("fill-opacity", 0.2);

    svg.append("line")
      .attr("x1", M.left).attr("x2", W - M.right)
      .attr("y1", y(100)).attr("y2", y(100))
      .attr("stroke", C.muted).attr("stroke-dasharray", "5,5");

    const line = key => d3.line().x(d => x(d.x)).y(d => y(d[key]));
    svg.append("path").datum(data).attr("d", line("gdp"))
      .attr("fill", "none").attr("stroke", COL.GDP).attr("stroke-width", 2.2);
    svg.append("path").datum(data).attr("d", line("energy"))
      .attr("fill", "none").attr("stroke", COL["Energy Use"]).attr("stroke-width", 2.2);

    [["gdp", COL.GDP], ["energy", COL["Energy Use"]]].forEach(([key, color]) => {
      svg.append("circle")
        .attr("cx", x(last.x)).attr("cy", y(last[key])).attr("r", 4.5).attr("fill", color);
      svg.append("text")
        .attr("x", x(last.x) + 10).attr("y", y(last[key]) + 4)
        .attr("fill", color).style("font-size", "13px").style("font-weight", "bold")
        .text(last[key].toFixed(1));
    });

    APP.styleAxis(svg.append("g")
      .attr("transform", `translate(0,${H - M.bottom})`)
      .call(d3.axisBottom(x).tickValues(d3.range(2000, last.x + 1, 5)).tickFormat(d3.format("d")).tickSize(4)));
    APP.styleAxis(svg.append("g")
      .attr("transform", `translate(${M.left},0)`)
      .call(d3.axisLeft(y).ticks(6).tickSize(4)));

    svg.append("text")
      .attr("transform", `translate(${M.left - 46},${(M.top + H - M.bottom) / 2}) rotate(-90)`)
      .attr("text-anchor", "middle")
      .attr("fill", C.light).style("font-size", "12px").style("font-weight", "bold")
      .text("Index (2000 = 100)");

    APP.hoverStrip(svg, {
      x, margin: M, width: W, height: H, data,
      html: rec => `
        <div class="tt-title">${APP.scopeLabel()} &middot; ${rec.x}</div>
        <div class="tt-row"><span><span class="sw" style="background:${COL.GDP}"></span>GDP</span><span class="val">${rec.gdp.toFixed(1)}</span></div>
        <div class="tt-row"><span><span class="sw" style="background:${COL["Energy Use"]}"></span>Energy Use</span><span class="val">${rec.energy.toFixed(1)}</span></div>
        <div class="tt-row" style="margin-top:4px;border-top:1px solid ${C.axis};padding-top:4px"><span>Gap</span><span class="val">${(rec.gdp - rec.energy) >= 0 ? "+" : ""}${(rec.gdp - rec.energy).toFixed(1)} pts</span></div>`,
    });
  }

  return { init, update };
})());
