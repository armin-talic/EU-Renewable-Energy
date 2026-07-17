/* Primary Energy Consumption (2024)
   Single EU map, the dashboard's filter. A toggle switches the choropleth
   metric between total consumption (TWh) and energy use per capita (kWh);
   the gradient legend follows. */
APP.charts.push((function () {
  const { C, snapshot, snapByIso, fmtComma, fmtK } = APP;

  const MAP_W = 900, MAP_H = 740;
  let countryPaths;
  let metric = "total";

  const METRICS = {
    total: { key: "primary_energy_consumption", fmt: v => `${fmtComma(v)} TWh` },
    percap: { key: "energy_per_capita", fmt: v => `${fmtComma(v)} kWh` },
  };
  const scales = {};

  function applyFill() {
    const m = METRICS[metric];
    // plain attr set; the fill change is animated by the CSS transition on .country
    countryPaths.attr("fill", d => {
      const s = snapByIso.get(d.properties.iso);
      return s && s[m.key] != null ? scales[metric](s[m.key]) : C.bgDeep;
    });
    const [lo, hi] = d3.extent(snapshot, d => d[m.key]);
    d3.select("#map-legend .lab.lo").text(m.fmt(lo));
    d3.select("#map-legend .lab.hi").text(m.fmt(hi));
  }

  function init() {
    const features = window.EU_GEO.features;
    const projection = d3.geoConicConformal().rotate([-10, 0]).parallels([40, 65]);
    projection.fitExtent([[12, 12], [MAP_W - 12, MAP_H - 12]], window.EU_GEO);
    const geoPath = d3.geoPath(projection);

    for (const [name, m] of Object.entries(METRICS)) {
      scales[name] = d3.scaleLinear()
        .domain(d3.extent(snapshot, d => d[m.key]))
        .range([C.mapLow, C.yellow]);
    }

    // gradient legend scaffold; labels are filled in by applyFill
    const lg = d3.select("#map-legend");
    lg.selectAll("*").remove();
    lg.append("span").attr("class", "lab lo");
    lg.append("span").attr("class", "bar");
    lg.append("span").attr("class", "lab hi");

    const svg = APP.makeSvg("#map", MAP_W, MAP_H);
    countryPaths = svg.append("g").selectAll("path")
      .data(features)
      .join("path")
      .attr("d", geoPath)
      .attr("class", "country")
      .attr("stroke", "#8f978f")
      .attr("stroke-width", 0.5)
      .on("click", (event, d) => APP.toggle(d.properties.iso))
      .on("mousemove", (event, d) => {
        const s = snapByIso.get(d.properties.iso);
        if (!s) return;
        APP.showTooltip(event, `
          <div class="tt-title">${s.display}</div>
          <div class="tt-row"><span>Primary energy</span><span class="val">${fmtComma(s.primary_energy_consumption)} TWh</span></div>
          <div class="tt-row"><span>Per capita</span><span class="val">${fmtK(s.energy_per_capita)} kWh</span></div>
          <div class="tt-row"><span>Share of EU</span><span class="val">${(s.primary_energy_consumption / APP.totalEU * 100).toFixed(1)}%</span></div>
          <div class="tt-row"><span>Renewables share of energy</span><span class="val">${s.renewables_share_energy != null ? s.renewables_share_energy.toFixed(1) + "%" : "n/a"}</span></div>
          <div class="tt-row"><span>EU rank</span><span class="val">#${s.rank} of ${snapshot.length}</span></div>
          <div style="color:${C.muted};margin-top:5px;font-style:italic">${APP.isSelected(s.iso) ? "click to clear the filter" : "click to filter the dashboard"}</div>`);
      })
      .on("mouseleave", APP.hideTooltip);

    d3.selectAll("#map-toggle button").on("click", function () {
      if (this.dataset.m === metric) return;
      metric = this.dataset.m;
      d3.selectAll("#map-toggle button").classed("active", function () {
        return this.dataset.m === metric;
      });
      applyFill();
    });

    applyFill();
  }

  function update(iso) {
    countryPaths
      .attr("stroke", d => APP.isSelected(d.properties.iso) ? C.light : "#8f978f")
      .attr("stroke-width", d => APP.isSelected(d.properties.iso) ? 2.4 : 0.5)
      .attr("fill-opacity", d => (iso && !APP.isSelected(d.properties.iso)) ? 0.45 : 1);
    countryPaths.filter(d => APP.isSelected(d.properties.iso)).raise();
  }

  return { init, update };
})());
