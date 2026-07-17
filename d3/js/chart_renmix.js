/* Renewable Energy Share of Primary Energy (2024)
   Horizontal stacked bars for all EU-27 (Malta has no data), sorted by total.
   This chart is a cross-country ranking, so the filter highlights rather than
   subsets: the selected country stays lit and the rest dim back. */
APP.charts.push((function () {
  const { C, rows, fmtPct } = APP;

  const SERIES = [
    { key: "solar", name: "Solar", color: C.yellow },
    { key: "wind", name: "Wind", color: C.blue },
    { key: "hydro", name: "Hydro", color: C.green },
    { key: "bio", name: "Biofuels", color: C.muted },
    { key: "other", name: "Other Renewables", color: C.brightGreen },
  ];

  let rowsG = null;

  function init() {
    const data = rows
      .filter(d => d.year === 2024 &&
        d.renewables_share_energy != null &&
        d.solar_share_energy != null &&
        d.wind_share_energy != null)
      .map(d => {
        const solar = d.solar_share_energy;
        const wind = d.wind_share_energy;
        const hydro = d.hydro_share_energy ?? 0;
        const bio = d.biofuel_share_energy ?? 0;
        return {
          iso: d.iso,
          country: d.country,
          total: d.renewables_share_energy,
          solar, wind, hydro, bio,
          // residual: geothermal, wave/tidal and anything else not broken out;
          // computed against the reported total so the parts always add up
          other: Math.max(0, d.renewables_share_energy - solar - wind - hydro - bio),
        };
      })
      .sort((a, b) => b.total - a.total);

    const W = 1080;
    const M = { top: 16, right: 78, bottom: 54, left: 112 };
    const rowH = 34;
    const H = M.top + M.bottom + rowH * data.length;

    APP.legend("#renmix-legend", [...SERIES].reverse());

    const svg = APP.makeSvg("#renmix", W, H);

    const x = d3.scaleLinear()
      .domain([0, d3.max(data, d => d.total) * 1.07])
      .range([M.left, W - M.right]);
    const y = d3.scaleBand()
      .domain(data.map(d => d.iso))
      .range([M.top, H - M.bottom])
      .paddingInner(0.32);

    rowsG = svg.append("g").selectAll("g.pick")
      .data(data).join("g")
      .attr("class", "pick")
      .on("click", (event, d) => APP.toggle(d.iso))
      .on("mousemove", (event, d) => {
        APP.showTooltip(event, `
          <div class="tt-title">${d.country}</div>
          ${SERIES.map(s => `<div class="tt-row"><span><span class="sw" style="background:${s.color}"></span>${s.name}</span><span class="val">${d[s.key].toFixed(1)}%</span></div>`).join("")}
          <div class="tt-row" style="margin-top:4px;border-top:1px solid ${C.axis};padding-top:4px"><span>Total renewables</span><span class="val">${d.total.toFixed(1)}%</span></div>`);
      })
      .on("mouseleave", APP.hideTooltip);

    rowsG.each(function (d) {
      const g = d3.select(this);
      let x0 = 0;
      SERIES.forEach(s => {
        g.append("rect")
          .attr("class", "seg")
          .attr("x", x(x0)).attr("y", y(d.iso))
          .attr("width", Math.max(0, x(x0 + d[s.key]) - x(x0)))
          .attr("height", y.bandwidth())
          .attr("fill", s.color);
        x0 += d[s.key];
      });
    });

    rowsG.append("text")
      .attr("class", "rm-name")
      .attr("x", M.left - 10).attr("y", d => y(d.iso) + y.bandwidth() / 2 + 4)
      .attr("text-anchor", "end")
      .attr("fill", C.light).style("font-size", "12px").style("font-weight", "bold")
      .text(d => d.country);

    rowsG.append("text")
      .attr("class", "rm-val")
      .attr("x", d => x(d.total) + 9)
      .attr("y", d => y(d.iso) + y.bandwidth() / 2 + 4)
      .attr("fill", C.light).style("font-size", "12.5px").style("font-weight", "bold")
      .text(d => fmtPct(d.total));

    const ticks = x.ticks(6);
    svg.append("g").selectAll("text")
      .data(ticks).join("text")
      .attr("x", d => x(d)).attr("y", H - M.bottom + 20)
      .attr("text-anchor", "middle")
      .attr("fill", C.muted).style("font-size", "12px")
      .text(d => d);
    svg.append("text")
      .attr("x", (M.left + W - M.right) / 2).attr("y", H - 12)
      .attr("text-anchor", "middle")
      .attr("fill", C.light).style("font-size", "13px").style("font-weight", "bold")
      .text("% of Total Primary Energy");
  }

  function update(iso) {
    if (!rowsG) return;
    const dim = d => iso && d.iso !== iso;
    rowsG.selectAll("rect.seg").attr("fill-opacity", function () {
      return dim(d3.select(this.parentNode).datum()) ? 0.3 : 0.95;
    });
    rowsG.select(".rm-name").attr("fill", d => d.iso === iso ? C.yellow : (dim(d) ? C.muted : C.light));
    rowsG.select(".rm-val").attr("fill", d => dim(d) ? C.muted : C.light);
  }

  return { init, update };
})());
