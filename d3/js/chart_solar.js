/* Solar Energy Producers (2024) - all EU-27 members.
   The EU adaptation of the global top-10 solar bubble grid: bubbles laid out
   in rank order, area proportional to TWh. Cross-country ranking, so the
   filter highlights the selected country and dims the rest. */
APP.charts.push((function () {
  const { C, rows } = APP;

  const COLS = 9, ROW_H = 128;
  const W = 1020;
  const M = { top: 14, right: 12, bottom: 10, left: 12 };
  const H = M.top + M.bottom + ROW_H * Math.ceil(27 / COLS);

  let bubbles = null;

  function init() {
    // generation is 2025 data; the share of primary energy is only reported
    // through 2024, so the tooltip labels it as such
    const share24 = new Map(rows.filter(d => d.year === 2024).map(d => [d.iso, d.solar_share_energy]));
    const data = rows
      .filter(d => d.year === 2025 && d.solar_electricity != null)
      .map(d => ({ iso: d.iso, country: d.country, val: d.solar_electricity, share: share24.get(d.iso) }))
      .sort((a, b) => b.val - a.val);
    data.forEach((d, i) => {
      d.rank = i + 1;
      d.col = i % COLS;
      d.row = Math.floor(i / COLS);
    });

    const svg = APP.makeSvg("#solar", W, H);

    const colW = (W - M.left - M.right) / COLS;
    const r = d3.scaleSqrt().domain([0, d3.max(data, d => d.val)]).range([3, 40]);
    const total = d3.sum(data, d => d.val);

    const cx = d => M.left + colW * (d.col + 0.5);
    const cy = d => M.top + ROW_H * d.row + 48;

    bubbles = svg.append("g").selectAll("g.pick")
      .data(data).join("g")
      .attr("class", "pick")
      .on("click", (event, d) => APP.toggle(d.iso))
      .on("mousemove", (event, d) => {
        APP.showTooltip(event, `
          <div class="tt-title">${d.country}</div>
          <div class="tt-row"><span>Solar generation</span><span class="val">${APP.fmt1(d.val)} TWh</span></div>
          <div class="tt-row"><span>EU rank</span><span class="val">#${d.rank} of ${data.length}</span></div>
          <div class="tt-row"><span>Share of EU solar</span><span class="val">${(d.val / total * 100).toFixed(1)}%</span></div>
          <div class="tt-row"><span>Of ${d.country}'s primary energy (2024)</span><span class="val">${d.share != null ? d.share.toFixed(1) + "%" : "n/a"}</span></div>`);
      })
      .on("mouseleave", APP.hideTooltip);

    bubbles.append("rect")
      .attr("x", d => cx(d) - colW / 2).attr("y", d => M.top + ROW_H * d.row)
      .attr("width", colW).attr("height", ROW_H)
      .attr("fill", "transparent");

    bubbles.append("circle")
      .attr("cx", cx).attr("cy", cy)
      .attr("r", d => r(d.val))
      .attr("fill-opacity", 0.9);

    bubbles.append("text").attr("class", "name")
      .attr("x", cx).attr("y", d => M.top + ROW_H * d.row + 102)
      .attr("text-anchor", "middle")
      .style("font-size", "11px").style("font-weight", "bold")
      .text(d => d.country);

    bubbles.append("text").attr("class", "val")
      .attr("x", cx).attr("y", d => M.top + ROW_H * d.row + 116)
      .attr("text-anchor", "middle")
      .style("font-size", "11px").style("font-weight", "bold")
      .text(d => `${APP.fmt1(d.val)} TWh`);
  }

  function update(iso) {
    if (!bubbles) return;
    const lit = d => !iso || d.iso === iso;
    bubbles.select("circle")
      .attr("fill", d => lit(d) ? C.yellow : "#354A40");
    bubbles.select("text.name")
      .attr("fill", d => d.iso === iso ? C.yellow : (lit(d) ? C.light : "#5B6E63"));
    bubbles.select("text.val")
      .attr("fill", d => lit(d) ? C.light : "#5B6E63");
  }

  return { init, update };
})());
