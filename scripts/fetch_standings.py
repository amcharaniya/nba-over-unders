#!/usr/bin/env python3
"""Pull current NBA W/L records from Basketball-Reference and write them as JSON.

Usage: python3 fetch_standings.py [season_end_year] [out_path]
Writes {"updatedAt", "source", "teams": {ABBR: {"w", "l"}}} — the shape the
site's `league/standings` document expects.
"""
import json
import re
import sys
import urllib.request
from datetime import datetime, timezone

year = sys.argv[1] if len(sys.argv) > 1 else "2027"
out = sys.argv[2] if len(sys.argv) > 2 else "standings.json"
url = f"https://www.basketball-reference.com/leagues/NBA_{year}_standings.html"

req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (over-under league tracker)"})
html = urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")

row_re = re.compile(
    r'/teams/([A-Z]{3})/' + year + r'\.html">[^<]+</a>(?:(?!</tr>).)*?'
    r'data-stat="wins"[^>]*>(\d*)<(?:(?!</tr>).)*?data-stat="losses"[^>]*>(\d*)<',
    re.S,
)
teams = {}
for abbr, w, l in row_re.findall(html):
    teams.setdefault(abbr, {"w": int(w or 0), "l": int(l or 0)})

if len(teams) != 30:
    sys.exit(f"Expected 30 teams, parsed {len(teams)} — page layout may have changed")

doc = {
    "updatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    "source": url,
    "teams": teams,
}
with open(out, "w") as f:
    json.dump(doc, f, indent=1)
print(f"Wrote {out}: {sum(t['w'] for t in teams.values())} total wins across 30 teams")
