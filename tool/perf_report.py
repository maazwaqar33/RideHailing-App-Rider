"""Prints a table of frame stats from build/perf*/<scenario>.timeline_summary.json.

Usage: python tool/perf_report.py [dir ...]   (default: build/perf)
Columns: frames, build avg/p90/p99/worst (ms), raster avg/p90/p99/worst (ms), jank = frames over the 16.7 ms
budget (build or raster) as a percentage of all frames.
"""
import glob
import json
import os
import sys

dirs = sys.argv[1:] or ['build/perf']
for d in dirs:
    print(f'== {d}')
    print(f'{"scenario":22} {"frames":>6} | {"b.avg":>6} {"b.p90":>6} {"b.p99":>6} {"b.max":>6} | '
          f'{"r.avg":>6} {"r.p90":>6} {"r.p99":>6} {"r.max":>6} | {"jank%":>6}')
    for f in sorted(glob.glob(os.path.join(d, '*.timeline_summary.json'))):
        j = json.load(open(f, encoding='utf8'))
        n = j.get('frame_count', 0) or 1
        jank = max(j.get('missed_frame_build_budget_count', 0),
                   j.get('missed_frame_rasterizer_budget_count', 0))
        name = os.path.basename(f).replace('.timeline_summary.json', '')
        print(f'{name:22} {n:6d} | '
              f'{j["average_frame_build_time_millis"]:6.1f} {j["90th_percentile_frame_build_time_millis"]:6.1f} '
              f'{j["99th_percentile_frame_build_time_millis"]:6.1f} {j["worst_frame_build_time_millis"]:6.1f} | '
              f'{j["average_frame_rasterizer_time_millis"]:6.1f} {j["90th_percentile_frame_rasterizer_time_millis"]:6.1f} '
              f'{j["99th_percentile_frame_rasterizer_time_millis"]:6.1f} {j["worst_frame_rasterizer_time_millis"]:6.1f} | '
              f'{100.0 * jank / n:6.1f}')
