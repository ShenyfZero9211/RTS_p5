#!/usr/bin/env python3
import argparse
import csv
import datetime as dt
import json
from pathlib import Path


def parse_row(parts):
    if len(parts) < 22:
        return None
    try:
        row = {
            "run_id": parts[0],
            "timestamp": parts[1],
            "avg_fps": float(parts[8]),
            "p95_frame_ms": float(parts[10]),
            "p99_frame_ms": float(parts[11]),
            "max_frame_ms": float(parts[12]),
            "enemy_ai_profile": (parts[20] or "unknown").lower(),
            "battle_intensity": "unknown",
            "reinforce_interval_sec": "default",
            "reinforce_count_per_faction": "default",
            "troop_profile": "balanced",
        }
        if len(parts) >= 23 and parts[21]:
            row["battle_intensity"] = parts[21].lower()
        if len(parts) >= 24 and parts[22]:
            row["reinforce_interval_sec"] = parts[22]
        if len(parts) >= 25 and parts[23]:
            row["reinforce_count_per_faction"] = parts[23]
        if len(parts) >= 26 and parts[24]:
            row["troop_profile"] = parts[24].lower()
        row["group_key"] = (
            f"{row['enemy_ai_profile']}|{row['battle_intensity']}|"
            f"{row['reinforce_interval_sec']}|{row['reinforce_count_per_faction']}|"
            f"{row['troop_profile']}"
        )
        return row
    except Exception:
        return None


def load_rows(csv_path):
    rows = []
    with csv_path.open("r", encoding="utf-8", newline="") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("run_id,"):
                continue
            parts = next(csv.reader([line]))
            r = parse_row(parts)
            if r:
                rows.append(r)
    rows.sort(key=lambda x: x["timestamp"])
    return rows


def latest_heatmap(rows):
    by_key = {}
    for r in rows:
        key = (r["enemy_ai_profile"], r["battle_intensity"], r["troop_profile"])
        by_key[key] = r
    return list(by_key.values())


def build_html(rows):
    profiles = sorted({r["enemy_ai_profile"] for r in rows})
    intensities = ["medium", "heavy", "extreme", "unknown"]
    troop_profiles = sorted({r["troop_profile"] for r in rows})
    data_json = json.dumps(rows)
    profiles_json = json.dumps(profiles)
    intensities_json = json.dumps(intensities)
    troop_json = json.dumps(troop_profiles)
    generated = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    return f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <title>RTS Benchmark Dashboard</title>
  <script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 16px; }}
    .row {{ display: flex; gap: 12px; align-items: center; margin-bottom: 10px; flex-wrap: wrap; }}
    .panel {{ border: 1px solid #ccc; border-radius: 8px; padding: 8px; margin-bottom: 12px; }}
  </style>
</head>
<body>
  <h2>RTS Benchmark Dashboard</h2>
  <div>Generated: {generated}</div>
  <div class="row">
    <label>Troop Profile:
      <select id="troopSel"></select>
    </label>
    <label>Group Key:
      <select id="groupSel"></select>
    </label>
  </div>
  <div class="panel"><div id="trend" style="height:360px;"></div></div>
  <div class="panel"><div id="heatmap" style="height:360px;"></div></div>
  <div class="panel"><div id="delta" style="height:360px;"></div></div>
  <script>
    const rows = {data_json};
    const profiles = {profiles_json};
    const intensities = {intensities_json};
    const troopProfiles = {troop_json};
    const troopSel = document.getElementById("troopSel");
    const groupSel = document.getElementById("groupSel");
    ["all", ...troopProfiles].forEach(v => {{
      const o = document.createElement("option"); o.value = v; o.textContent = v; troopSel.appendChild(o);
    }});

    function filteredRows() {{
      const tp = troopSel.value;
      return rows.filter(r => tp === "all" ? true : r.troop_profile === tp);
    }}

    function refreshGroupOptions() {{
      const keys = [...new Set(filteredRows().map(r => r.group_key))].sort();
      groupSel.innerHTML = "";
      keys.forEach(k => {{
        const o = document.createElement("option"); o.value = k; o.textContent = k; groupSel.appendChild(o);
      }});
    }}

    function drawTrend() {{
      const key = groupSel.value;
      const rs = filteredRows().filter(r => r.group_key === key).sort((a,b)=>a.timestamp.localeCompare(b.timestamp));
      const x = rs.map(r => r.timestamp);
      Plotly.newPlot("trend", [
        {{x, y: rs.map(r => r.avg_fps), name: "avg_fps", type: "scatter", mode: "lines+markers", yaxis: "y1"}},
        {{x, y: rs.map(r => r.p99_frame_ms), name: "p99_frame_ms", type: "scatter", mode: "lines+markers", yaxis: "y2"}}
      ], {{
        title: "Trend by Group Key",
        xaxis: {{title: "timestamp"}},
        yaxis: {{title: "avg_fps"}},
        yaxis2: {{title: "p99_frame_ms", overlaying: "y", side: "right"}}
      }}, {{responsive: true}});
    }}

    function drawHeatmap() {{
      const rs = filteredRows();
      const latest = new Map();
      rs.sort((a,b)=>a.timestamp.localeCompare(b.timestamp)).forEach(r => {{
        latest.set(r.enemy_ai_profile + "|" + r.battle_intensity, r);
      }});
      const z = profiles.map(p => intensities.map(i => {{
        const k = p + "|" + i;
        return latest.has(k) ? latest.get(k).avg_fps : null;
      }}));
      Plotly.newPlot("heatmap", [{{
        z, x: intensities, y: profiles, type: "heatmap", hoverongaps: false
      }}], {{
        title: "Latest avg_fps (profile x intensity)"
      }}, {{responsive: true}});
    }}

    function drawDelta() {{
      const byGroup = new Map();
      filteredRows().forEach(r => {{
        if (!byGroup.has(r.group_key)) byGroup.set(r.group_key, []);
        byGroup.get(r.group_key).push(r);
      }});
      const labels = [];
      const fpsDelta = [];
      const p99Delta = [];
      for (const [k, arr] of byGroup.entries()) {{
        arr.sort((a,b)=>a.timestamp.localeCompare(b.timestamp));
        if (arr.length < 2) continue;
        const prev = arr[arr.length - 2];
        const last = arr[arr.length - 1];
        labels.push(k);
        fpsDelta.push((last.avg_fps - prev.avg_fps).toFixed(2));
        p99Delta.push((last.p99_frame_ms - prev.p99_frame_ms).toFixed(2));
      }}
      Plotly.newPlot("delta", [
        {{x: labels, y: fpsDelta, type: "bar", name: "fps_delta"}},
        {{x: labels, y: p99Delta, type: "bar", name: "p99_delta"}}
      ], {{
        title: "Latest vs Previous Delta by Group",
        xaxis: {{title: "group_key", automargin: true}},
        yaxis: {{title: "delta"}}
      }}, {{responsive: true}});
    }}

    function redrawAll() {{
      refreshGroupOptions();
      drawTrend();
      drawHeatmap();
      drawDelta();
    }}

    troopSel.addEventListener("change", redrawAll);
    groupSel.addEventListener("change", drawTrend);
    redrawAll();
  </script>
</body>
</html>
"""


def main():
    parser = argparse.ArgumentParser(description="Generate benchmark HTML dashboard.")
    parser.add_argument("--project-root", default=r"D:\projects\cursor\RTS_p5")
    parser.add_argument("--csv-path", default="")
    parser.add_argument("--output-path", default="")
    args = parser.parse_args()

    project_root = Path(args.project_root)
    csv_path = Path(args.csv_path) if args.csv_path else (project_root / "benchmarks" / "runtime_metrics.csv")
    if not csv_path.exists():
        raise SystemExit(f"CSV not found: {csv_path}")

    out_dir = project_root / "benchmarks"
    out_dir.mkdir(parents=True, exist_ok=True)
    if args.output_path:
        out_path = Path(args.output_path)
    else:
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        out_path = out_dir / f"dashboard-{stamp}.html"

    rows = load_rows(csv_path)
    if not rows:
        raise SystemExit("No valid rows in runtime metrics CSV.")

    html = build_html(rows)
    out_path.write_text(html, encoding="utf-8")
    print(f"[DASHBOARD] Created: {out_path}")


if __name__ == "__main__":
    main()
