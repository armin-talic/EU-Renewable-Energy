# EU Energy Transition - D3 Dashboard

An interactive D3.js rebuild of the charts from the
[EU-Renewable-Energy](https://github.com/armin-talic/EU-Renewable-Energy) R/ggplot2 project,
using the same [Our World in Data energy dataset](https://github.com/owid/energy-data) and the
same dark green design system.

## Open it

Double-click **`Open Dashboard.url`**, or open `index.html` in any browser.

No server or build step is needed: D3 is vendored in `lib/`, and the data is embedded as plain
`.js` files rather than fetched, so `file://` works. If you prefer a local server anyway
(`http://localhost:8641`):

```
python serve.py
```

## Filtering

Two ways to filter, always in sync:

- **The map** in the first chart: click a country to filter every chart to it, click again to
  go back to the aggregate. The renewable-share bars and the wind and solar charts are
  clickable too. A toggle above the map switches its choropleth between total consumption
  (TWh) and energy use per capita (kWh).
- **The sidebar** fixed on the right edge: it stays visible while scrolling, lists all 27
  members, and "EU-27 (all countries)" clears the selection.

Every chart title states its current scope in brackets: **(EU-27)** or **(Germany)**.

When a country is selected, a **"View [country]'s progression"** button appears in the sidebar.
It reveals a hidden detail section: one chart with all four renewable sources over 2000-2025,
drawn as a wind turbine per year (tower height = wind TWh), a sun per year (height = solar TWh),
and lines for hydro and biofuels. Clearing the selection hides it again.

Charts respond in one of two ways, depending on what they show:

- **Time series** (electricity mix, coal vs renewables, decoupling) are *subset*: they redraw
  from the selected country's data, or from the EU-27 aggregate when nothing is selected.
- **Cross-country rankings** (per capita, renewable share, wind, solar) are *highlighted*:
  all 27 members stay on screen so the comparison survives, and the selected one is lit while
  the rest dim back.

## Layout

One chart per row, each with its title directly above the chart and a short narrative that
carries the story from the original README. The renewable-share, coal-vs-renewables and
decoupling sections keep their story in a side column; the rest place it above or below
the chart:

| Row | Chart |
|---|---|
| 1 | Primary Energy Consumption (2024): map with a Total / Per Capita metric toggle |
| 2 | Wind Energy Producers (2025) |
| 3 | Solar Energy Producers (2025) |
| - | Renewables Over the Years (hidden; opens from the sidebar for a selected country) |
| 4 | Renewable Energy Share of Primary Energy (2024), split into Solar / Wind / Hydro / Biofuels / Other |
| 5 | Electricity Generation by Source |
| 6 | Coal vs. Renewables (Electricity Generation), with a dynamic "renewables overtook coal in [year]" subtitle |
| 7 | Efficiency & Decoupling |

## Differences from the R version

These are deliberate, and mostly follow from the map filter replacing the fixed country panels.

- **No "Top 3" panels.** The R charts hard-coded Germany/France/Italy facet panels beside each
  EU-27 aggregate. Here that job belongs to the map filter, so each of those charts is a single
  panel whose scope you choose.
- **Wind and solar show the EU-27, not the global top 10.** The turbine and bubble designs are
  kept, but ranked across member states instead of world leaders, so "EU highlighted / others
  dimmed" became "selected country highlighted / others dimmed".
- **The map's top-5 callout labels are gone**, since hovering any country now gives you its
  figures, rank and EU share. A gradient legend replaces them.
- **The decoupling y-axis is fitted per country** instead of fixed at 70-150. That range works
  for the EU aggregate and the big three, but it would clip most members off the panel entirely:
  Romania's GDP index reaches ~400 and Ireland's ~240 by 2022.
- **Charts 05, 07, 08, 09 and 13 from the R project are not (yet) included** here.

## Data notes

- **Electricity data runs through 2025** for all 27 members (wind, solar, hydro, biofuel, coal,
  gas, oil, nuclear generation), so the electricity charts and the wind/solar rankings use 2025.
  **Primary energy, per-capita and share figures stop at 2024**, so the map and the
  renewable-share chart stay on 2024, and the wind/solar tooltips label their share line "(2024)".
- The **coal-vs-renewables crossover subtitle** is computed from the data: the year of the final
  upward crossing after which renewables stay ahead (EU-27: 2013, Germany: 2019). Countries where
  coal still leads, or where renewables led the whole period, get their own wording.
- **"Other Renewables"** in the share chart is the residual after subtracting the reported solar,
  wind, hydro and biofuel shares from the reported renewables total, so the segments always add
  up; it covers geothermal, wave and tidal.

Carried over from the R analysis:

- **Malta** has no 2024 primary energy figure, so it falls back to 2023 and is marked `*`. It
  reports no `renewables_share_energy` at all and is therefore absent from the renewable-share
  chart, exactly as in the R version.
- **GDP stops in 2022** across all 27 members in this dataset, so the decoupling chart ends
  there rather than in 2024.
- The EU-27 decoupling aggregate only sums countries reporting *both* GDP and energy in a given
  year, matching the R `filter(!is.na(gdp), !is.na(primary_energy_consumption))` step. It
  reproduces the R output exactly: GDP index 147.8, energy 89.6.

## Structure

```
index.html            markup, one <section class="card"> per chart (story column + chart)
styles.css            design system as CSS variables (colors copied from the R script)
js/main.js            data unpacking, selection state, sidebar, shared tooltip/legend helpers
js/chart_*.js         one file per chart; each registers { init, update(iso) } with APP.charts
data/energy.js        prepared OWID data (EU-27, 2000-2025) as window.ENERGY_RAW
data/geo.js           simplified EU-27 country outlines as window.EU_GEO
prepare_data.py       rebuilds data/ from raw/
serve.py              optional local static server on port 8641
raw/                  downloaded sources (OWID CSV, Natural Earth GeoJSON)
```

### Rebuilding the data

`raw/` holds the two downloads; re-fetch them to pick up newer OWID figures:

```
curl -o raw/owid-energy-data.csv https://raw.githubusercontent.com/owid/energy-data/master/owid-energy-data.csv
curl -o raw/ne_50m_countries.geojson https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson
python prepare_data.py
```

`prepare_data.py` trims the 9 MB OWID CSV to the 17 columns and ~700 rows the dashboard uses
(89 KB), and reduces the 3 MB Natural Earth file to EU-27 outlines only (89 KB) by clipping to
the European viewport, dropping small islands, and simplifying the rings with a
Visvalingam-Whyatt pass.

---

*Data: [Our World in Data, Energy dataset](https://github.com/owid/energy-data) &middot; Charts: D3.js*
