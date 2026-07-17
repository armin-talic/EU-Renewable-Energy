/* Renewables Over the Years - country detail section.
   Hidden until a country is selected AND the sidebar button is clicked.
   One chart, four renewable sources, 2000-2025: a wind turbine per year
   (tower height = wind TWh), a sun per year (height = solar TWh), and
   plain lines for hydro and biofuels. */
APP.charts.push((function () {
  const { C, byIso, isoName } = APP;

  const W = 1020, H = 480;
  const M = { top: 24, right: 20, bottom: 40, left: 64 };

  const SOURCES = [
    { key: "wind_electricity", name: "Wind", color: C.blue },
    { key: "solar_electricity", name: "Solar", color: C.yellow },
    { key: "hydro_electricity", name: "Hydro", color: C.green },
    { key: "biofuel_electricity", name: "Biofuels", color: C.muted },
  ];

  let open = false;

  function build(iso) {
    return (byIso.get(iso) || [])
      .filter(d => d.year >= 2000 && d.year <= 2025)
      .map(d => ({
        year: d.year,
        wind: d.wind_electricity ?? 0,
        solar: d.solar_electricity ?? 0,
        hydro: d.hydro_electricity ?? 0,
        bio: d.biofuel_electricity ?? 0,
      }));
  }

  function render(iso) {
    const data = build(iso);
    const svg = APP.makeSvg("#progress", W, H);
    if (!data.length) return;

    const x = d3.scaleLinear().domain([2000, 2025]).range([M.left, W - M.right]);
    const step = x(2001) - x(2000);
    const maxVal = d3.max(data, d => Math.max(d.wind, d.solar, d.hydro, d.bio));
    const y = d3.scaleLinear().domain([0, maxVal * 1.15]).nice().range([H - M.bottom, M.top]);

    // hydro and biofuel first, as plain lines behind the pictograms
    const line = key => d3.line().x(d => x(d.year)).y(d => y(d[key]));
    svg.append("path").datum(data).attr("d", line("hydro"))
      .attr("fill", "none").attr("stroke", C.green).attr("stroke-width", 2.2);
    svg.append("path").datum(data).attr("d", line("bio"))
      .attr("fill", "none").attr("stroke", C.muted).attr("stroke-width", 2.2);

    // faint guide under the suns so the solar trend reads as a line too
    svg.append("path").datum(data).attr("d", line("solar"))
      .attr("fill", "none").attr("stroke", C.yellow)
      .attr("stroke-width", 1).attr("stroke-opacity", 0.45);

    // one wind turbine per year
    const yBlade = 9;
    const xBlade = Math.min(step * 0.32, 7);
    const turbines = svg.append("g").selectAll("g.turb")
      .data(data).join("g");
    turbines.append("line")
      .attr("x1", d => x(d.year)).attr("x2", d => x(d.year))
      .attr("y1", y(0)).attr("y2", d => y(d.wind))
      .attr("stroke", C.blue).attr("stroke-width", 2.4);
    turbines.append("line")
      .attr("x1", d => x(d.year)).attr("y1", d => y(d.wind))
      .attr("x2", d => x(d.year)).attr("y2", d => y(d.wind) - yBlade)
      .attr("stroke", C.blue).attr("stroke-width", 1.3);
    turbines.append("line")
      .attr("x1", d => x(d.year)).attr("y1", d => y(d.wind))
      .attr("x2", d => x(d.year) + xBlade).attr("y2", d => y(d.wind) + yBlade * 0.6)
      .attr("stroke", C.blue).attr("stroke-width", 1.3);
    turbines.append("line")
      .attr("x1", d => x(d.year)).attr("y1", d => y(d.wind))
      .attr("x2", d => x(d.year) - xBlade).attr("y2", d => y(d.wind) + yBlade * 0.6)
      .attr("stroke", C.blue).attr("stroke-width", 1.3);
    turbines.append("circle")
      .attr("cx", d => x(d.year)).attr("cy", d => y(d.wind))
      .attr("r", 1.5).attr("fill", C.bg);

    // one sun per year at the solar value
    const suns = svg.append("g").selectAll("g.sun")
      .data(data).join("g");
    const RAYS = d3.range(8).map(i => i * Math.PI / 4);
    RAYS.forEach(a => {
      suns.append("line")
        .attr("x1", d => x(d.year) + Math.cos(a) * 5.5)
        .attr("y1", d => y(d.solar) + Math.sin(a) * 5.5)
        .attr("x2", d => x(d.year) + Math.cos(a) * 8)
        .attr("y2", d => y(d.solar) + Math.sin(a) * 8)
        .attr("stroke", C.yellow).attr("stroke-width", 1);
    });
    suns.append("circle")
      .attr("cx", d => x(d.year)).attr("cy", d => y(d.solar))
      .attr("r", 4).attr("fill", C.yellow);

    // ground line
    svg.append("line")
      .attr("x1", M.left).attr("x2", W - M.right)
      .attr("y1", y(0)).attr("y2", y(0))
      .attr("stroke", C.axis).attr("stroke-width", 1.5);

    APP.styleAxis(svg.append("g")
      .attr("transform", `translate(0,${H - M.bottom})`)
      .call(d3.axisBottom(x).tickValues(d3.range(2000, 2026, 5)).tickFormat(d3.format("d")).tickSize(4)));
    APP.styleAxis(svg.append("g")
      .attr("transform", `translate(${M.left},0)`)
      .call(d3.axisLeft(y).ticks(6).tickSize(4)));

    svg.append("text")
      .attr("transform", `translate(${M.left - 46},${(M.top + H - M.bottom) / 2}) rotate(-90)`)
      .attr("text-anchor", "middle")
      .attr("fill", C.light).style("font-size", "12px").style("font-weight", "bold")
      .text("Generation (TWh)");

    APP.hoverStrip(svg, {
      x, margin: M, width: W, height: H, data,
      html: rec => `
        <div class="tt-title">${isoName.get(iso)} &middot; ${rec.year}</div>
        <div class="tt-row"><span><span class="sw" style="background:${C.blue}"></span>Wind</span><span class="val">${APP.fmt1(rec.wind)} TWh</span></div>
        <div class="tt-row"><span><span class="sw" style="background:${C.yellow}"></span>Solar</span><span class="val">${APP.fmt1(rec.solar)} TWh</span></div>
        <div class="tt-row"><span><span class="sw" style="background:${C.green}"></span>Hydro</span><span class="val">${APP.fmt1(rec.hydro)} TWh</span></div>
        <div class="tt-row"><span><span class="sw" style="background:${C.muted}"></span>Biofuels</span><span class="val">${APP.fmt1(rec.bio)} TWh</span></div>`,
    });
  }

  function setVisible(visible) {
    d3.select("#sec-progress").style("display", visible ? null : "none");
  }

  function init() {
    APP.legend("#progress-legend", SOURCES.map(s => ({ name: s.name, color: s.color })));
    d3.select("#progress-btn").on("click", () => {
      const iso = APP.selected();
      if (!iso) return;
      open = true;
      render(iso);
      setVisible(true);
      document.getElementById("sec-progress").scrollIntoView({ behavior: "smooth", block: "start" });
    });
    d3.select("#progress-close").on("click", () => {
      open = false;
      setVisible(false);
    });
  }

  function update(iso) {
    const btn = d3.select("#progress-btn");
    if (!iso) {
      open = false;
      setVisible(false);
      btn.style("display", "none");
      return;
    }
    btn.style("display", null).text(`View ${isoName.get(iso)}'s progression`);
    if (open) {
      render(iso);
      setVisible(true);
    } else {
      setVisible(false);
    }
  }

  return { init, update };
})());
