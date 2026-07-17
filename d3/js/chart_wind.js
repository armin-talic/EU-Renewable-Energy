/* Wind Energy Producers (2024) - all EU-27 members.
   The EU adaptation of the global top-10 wind farm chart: one turbine per
   member state, tower height = TWh generated. Cross-country ranking, so the
   filter highlights the selected country and dims the rest. */
APP.charts.push((function () {
  const { C, rows } = APP;

  const W = 1020, H = 540;
  const M = { top: 34, right: 16, bottom: 96, left: 52 };

  const LIT = { blade: C.light, tower: C.muted, label: C.light };
  const DIM = { blade: "#354A40", tower: "#2A3D34", label: "#5B6E63" };

  let turbines = null;

  function init() {
    // generation is 2025 data; the share of primary energy is only reported
    // through 2024, so the tooltip labels it as such
    const share24 = new Map(rows.filter(d => d.year === 2024).map(d => [d.iso, d.wind_share_energy]));
    const data = rows
      .filter(d => d.year === 2025 && d.wind_electricity != null)
      .map(d => ({ iso: d.iso, country: d.country, val: d.wind_electricity, share: share24.get(d.iso) }))
      .sort((a, b) => b.val - a.val);

    const svg = APP.makeSvg("#wind", W, H);

    const x = d3.scalePoint()
      .domain(data.map(d => d.iso))
      .range([M.left, W - M.right])
      .padding(0.6);
    const maxVal = d3.max(data, d => d.val);
    const y = d3.scaleLinear().domain([0, maxVal * 1.13]).range([H - M.bottom, M.top]);

    // blade geometry, in pixels (mirrors the R version's data-unit proportions)
    const yBlade = y(0) - y(maxVal * 0.08);
    const xBlade = x.step() * 0.35;

    APP.styleAxis(svg.append("g")
      .attr("transform", `translate(${M.left},0)`)
      .call(d3.axisLeft(y).ticks(6).tickSize(4)));

    svg.append("text")
      .attr("transform", `translate(${M.left - 38},${(M.top + H - M.bottom) / 2}) rotate(-90)`)
      .attr("text-anchor", "middle")
      .attr("fill", C.light).style("font-size", "12px").style("font-weight", "bold")
      .text("Generation (TWh)");

    // the ground line
    svg.append("line")
      .attr("x1", M.left).attr("x2", W - M.right)
      .attr("y1", y(0)).attr("y2", y(0))
      .attr("stroke", C.brightGreen).attr("stroke-width", 2.5);

    turbines = svg.append("g").selectAll("g.pick")
      .data(data).join("g")
      .attr("class", "pick")
      .on("click", (event, d) => APP.toggle(d.iso))
      .on("mousemove", (event, d) => {
        APP.showTooltip(event, `
          <div class="tt-title">${d.country}</div>
          <div class="tt-row"><span>Wind generation</span><span class="val">${APP.fmt1(d.val)} TWh</span></div>
          <div class="tt-row"><span>EU rank</span><span class="val">#${data.indexOf(d) + 1} of ${data.length}</span></div>
          <div class="tt-row"><span>Share of EU wind</span><span class="val">${(d.val / d3.sum(data, v => v.val) * 100).toFixed(1)}%</span></div>
          <div class="tt-row"><span>Of ${d.country}'s primary energy (2024)</span><span class="val">${d.share != null ? d.share.toFixed(1) + "%" : "n/a"}</span></div>`);
      })
      .on("mouseleave", APP.hideTooltip);

    // generous hit area: turbines are thin lines
    turbines.append("rect")
      .attr("x", d => x(d.iso) - x.step() / 2).attr("y", M.top)
      .attr("width", x.step()).attr("height", H - M.bottom - M.top)
      .attr("fill", "transparent");

    turbines.append("line").attr("class", "tower")
      .attr("x1", d => x(d.iso)).attr("x2", d => x(d.iso))
      .attr("y1", y(0)).attr("y2", d => y(d.val))
      .attr("stroke-width", 4);

    // three blades from the hub
    turbines.append("line").attr("class", "blade")
      .attr("x1", d => x(d.iso)).attr("y1", d => y(d.val))
      .attr("x2", d => x(d.iso)).attr("y2", d => y(d.val) - yBlade)
      .attr("stroke-width", 1.6);
    turbines.append("line").attr("class", "blade")
      .attr("x1", d => x(d.iso)).attr("y1", d => y(d.val))
      .attr("x2", d => x(d.iso) + xBlade).attr("y2", d => y(d.val) + yBlade * 0.6)
      .attr("stroke-width", 1.6);
    turbines.append("line").attr("class", "blade")
      .attr("x1", d => x(d.iso)).attr("y1", d => y(d.val))
      .attr("x2", d => x(d.iso) - xBlade).attr("y2", d => y(d.val) + yBlade * 0.6)
      .attr("stroke-width", 1.6);

    turbines.append("circle")
      .attr("cx", d => x(d.iso)).attr("cy", d => y(d.val)).attr("r", 1.8)
      .attr("fill", C.bg);

    turbines.append("text").attr("class", "val")
      .attr("x", d => x(d.iso)).attr("y", d => y(d.val) - yBlade - 8)
      .attr("text-anchor", "middle")
      .style("font-size", "10px").style("font-weight", "bold")
      .text(d => APP.fmt1(d.val));

    turbines.append("text").attr("class", "name")
      .attr("transform", d => `translate(${x(d.iso)},${y(0) + 12}) rotate(-45)`)
      .attr("text-anchor", "end")
      .style("font-size", "10.5px").style("font-weight", "bold")
      .text(d => d.country);
  }

  function update(iso) {
    if (!turbines) return;
    const style = d => (!iso || d.iso === iso) ? LIT : DIM;
    turbines.select(".tower").attr("stroke", d => style(d).tower);
    turbines.selectAll(".blade").attr("stroke", function () {
      return style(d3.select(this.parentNode).datum()).blade;
    });
    turbines.select("text.val").attr("fill", d => style(d).label);
    turbines.select("text.name")
      .attr("fill", d => d.iso === iso ? C.yellow : style(d).label);
  }

  return { init, update };
})());
