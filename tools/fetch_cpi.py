#!/usr/bin/env python3
"""Fetch monthly CPI-U series from the BLS public API into data/cpi.json.

Usage: python3 tools/fetch_cpi.py [start_year] [end_year]
No API key needed (v1 endpoint: 25 queries/day, 10 years per query).
"""
import json
import sys
import urllib.request
from datetime import date

SERIES = {
    "all_items": "CUUR0000SA0",       # CPI-U, all items (not seasonally adjusted)
    "food_away": "CUUR0000SEFV",      # food away from home (menu prices)
    "food_home": "CUUR0000SAF11",     # food at home (ingredient costs)
    "gasoline": "CUUR0000SETB01",     # gasoline, all types (fuel costs)
}

start = sys.argv[1] if len(sys.argv) > 1 else "2025"
end = sys.argv[2] if len(sys.argv) > 2 else str(date.today().year)

req = urllib.request.Request(
    "https://api.bls.gov/publicAPI/v1/timeseries/data/",
    data=json.dumps({"seriesid": list(SERIES.values()), "startyear": start, "endyear": end}).encode(),
    headers={"Content-Type": "application/json"},
)
with urllib.request.urlopen(req, timeout=30) as resp:
    payload = json.load(resp)

if payload.get("status") != "REQUEST_SUCCEEDED":
    sys.exit(f"BLS error: {payload.get('message')}")

by_id = {s["seriesID"]: s["data"] for s in payload["Results"]["series"]}
out = {"source": "U.S. Bureau of Labor Statistics CPI-U (1982-84=100)", "fetched": date.today().isoformat(), "series": {}}
for name, sid in SERIES.items():
    months = {}
    for row in by_id[sid]:
        if row["period"].startswith("M") and row["period"] != "M13" and row["value"] != "-":
            months[f'{row["year"]}-{row["period"][1:]}'] = float(row["value"])
    out["series"][name] = dict(sorted(months.items()))

with open("data/cpi.json", "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
print({k: len(v) for k, v in out["series"].items()}, "months written to data/cpi.json")
