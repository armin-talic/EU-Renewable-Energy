# Prepares the data files for the D3 dashboard.
#
# Reads the raw OWID energy dataset and Natural Earth country geometries
# (downloaded into ./raw, see README.md) and writes compact JavaScript data
# files into ./data. Data is embedded as .js files (not fetched JSON) so the
# dashboard also works when index.html is opened directly via file://.
#
# Usage:  python prepare_data.py

import csv
import json
import heapq
import os

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(HERE, "data")

EU27 = {
    "AUT": "Austria", "BEL": "Belgium", "BGR": "Bulgaria", "HRV": "Croatia",
    "CYP": "Cyprus", "CZE": "Czechia", "DNK": "Denmark", "EST": "Estonia",
    "FIN": "Finland", "FRA": "France", "DEU": "Germany", "GRC": "Greece",
    "HUN": "Hungary", "IRL": "Ireland", "ITA": "Italy", "LVA": "Latvia",
    "LTU": "Lithuania", "LUX": "Luxembourg", "MLT": "Malta", "NLD": "Netherlands",
    "POL": "Poland", "PRT": "Portugal", "ROU": "Romania", "SVK": "Slovakia",
    "SVN": "Slovenia", "ESP": "Spain", "SWE": "Sweden",
}

COLUMNS = [
    "primary_energy_consumption",   # TWh
    "energy_per_capita",            # kWh
    "renewables_share_energy",      # %
    "solar_share_energy",           # %
    "wind_share_energy",            # %
    "hydro_share_energy",           # %
    "biofuel_share_energy",         # %
    "coal_electricity",             # TWh
    "oil_electricity",
    "gas_electricity",
    "nuclear_electricity",
    "hydro_electricity",
    "biofuel_electricity",
    "wind_electricity",
    "solar_electricity",
    "renewables_electricity",
    "gdp",
]

# electricity columns run through 2025; primary energy / shares / gdp end earlier
YEAR_MIN, YEAR_MAX = 2000, 2025


def build_energy():
    src = os.path.join(RAW, "owid-energy-data.csv")
    rows = []
    with open(src, newline="", encoding="utf-8") as f:
        for rec in csv.DictReader(f):
            iso = rec.get("iso_code", "")
            if iso not in EU27:
                continue
            year = int(rec["year"])
            if year < YEAR_MIN or year > YEAR_MAX:
                continue
            vals = []
            for col in COLUMNS:
                v = rec.get(col, "")
                vals.append(round(float(v), 3) if v not in ("", None) else None)
            rows.append([iso, rec["country"], year] + vals)

    payload = {"columns": ["iso", "country", "year"] + COLUMNS, "rows": rows}
    out = os.path.join(OUT, "energy.js")
    with open(out, "w", encoding="utf-8") as f:
        f.write("window.ENERGY_RAW = ")
        json.dump(payload, f, separators=(",", ":"))
        f.write(";\n")
    print(f"energy.js: {len(rows)} rows, {os.path.getsize(out) / 1024:.0f} KB")


# --- geometry helpers -------------------------------------------------------

def ring_area(ring):
    s = 0.0
    for i in range(len(ring) - 1):
        x1, y1 = ring[i]
        x2, y2 = ring[i + 1]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2.0


def tri_area(a, b, c):
    return abs((b[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (b[1] - a[1])) / 2.0


def simplify_ring(ring, threshold):
    """Visvalingam-Whyatt: drop points whose effective triangle area < threshold."""
    n = len(ring)
    if n <= 5:
        return ring
    closed = ring[0] == ring[-1]
    pts = ring[:-1] if closed else ring
    n = len(pts)
    if n <= 4:
        return ring
    prev = list(range(-1, n - 1))
    nxt = list(range(1, n + 1))
    prev[0], nxt[n - 1] = n - 1, 0  # rings wrap around
    alive = [True] * n
    heap = []
    for i in range(n):
        a = tri_area(pts[prev[i]], pts[i], pts[nxt[i]])
        heapq.heappush(heap, (a, i))
    count = n
    min_pts = 6
    while heap and count > min_pts:
        a, i = heapq.heappop(heap)
        if not alive[i]:
            continue
        cur = tri_area(pts[prev[i]], pts[i], pts[nxt[i]])
        if cur > a + 1e-15:  # stale entry, re-push with fresh area
            heapq.heappush(heap, (cur, i))
            continue
        if cur >= threshold:
            break
        alive[i] = False
        count -= 1
        p, q = prev[i], nxt[i]
        nxt[p], prev[q] = q, p
        for j in (p, q):
            heapq.heappush(heap, (tri_area(pts[prev[j]], pts[j], pts[nxt[j]]), j))
    result = [pts[i] for i in range(n) if alive[i]]
    if closed:
        result.append(result[0])
    return result


def build_geo():
    src = os.path.join(RAW, "ne_50m_countries.geojson")
    with open(src, encoding="utf-8") as f:
        world = json.load(f)

    # keep only polygons inside the Europe viewport (drops overseas territories)
    LON_MIN, LON_MAX, LAT_MIN, LAT_MAX = -25.0, 45.0, 30.0, 72.0
    SIMPLIFY = 0.0008   # deg^2 triangle-area threshold
    MIN_POLY = 0.015    # deg^2, drop smaller islands (largest polygon always kept)

    features = []
    for feat in world["features"]:
        iso = feat["properties"].get("ADM0_A3")
        if iso not in EU27:
            continue
        geom = feat["geometry"]
        polys = [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]

        kept = []
        for poly in polys:
            outer = poly[0]
            xs = [p[0] for p in outer]
            ys = [p[1] for p in outer]
            cx, cy = sum(xs) / len(xs), sum(ys) / len(ys)
            if not (LON_MIN <= cx <= LON_MAX and LAT_MIN <= cy <= LAT_MAX):
                continue
            kept.append((ring_area(outer), poly))
        if not kept:
            continue
        kept.sort(key=lambda t: -t[0])
        polys_out = []
        for idx, (area, poly) in enumerate(kept):
            if idx > 0 and area < MIN_POLY:
                continue
            rings = []
            for ring in poly:
                if ring_area(ring) < MIN_POLY / 3 and len(rings) > 0:
                    continue  # drop tiny holes
                simplified = simplify_ring(ring, SIMPLIFY)
                rings.append([[round(x, 3), round(y, 3)] for x, y in simplified])
            polys_out.append(rings)

        geometry = ({"type": "Polygon", "coordinates": polys_out[0]}
                    if len(polys_out) == 1
                    else {"type": "MultiPolygon", "coordinates": polys_out})
        features.append({
            "type": "Feature",
            "properties": {"iso": iso, "name": EU27[iso]},
            "geometry": geometry,
        })

    found = {f["properties"]["iso"] for f in features}
    missing = set(EU27) - found
    if missing:
        print(f"WARNING: no geometry for {sorted(missing)}")

    fc = {"type": "FeatureCollection", "features": features}
    out = os.path.join(OUT, "geo.js")
    with open(out, "w", encoding="utf-8") as f:
        f.write("window.EU_GEO = ")
        json.dump(fc, f, separators=(",", ":"))
        f.write(";\n")
    print(f"geo.js: {len(features)} countries, {os.path.getsize(out) / 1024:.0f} KB")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    build_energy()
    build_geo()
