# QML performance baseline

Captured on 2026-10-20 with Qt QML Profiler, Qt 6, Quickshell and the pinned
Omarchy runtime in `ci/Dockerfile`. Both runs used Cage's headless Wayland backend,
software rendering, temporary preferences, mock helpers and disabled network access.
This is a reproducible development baseline, not a desktop frame-rate benchmark.

The workload loads the complete panel with its native popup closed and renders
representative views in an ordinary window constrained to 360px. It visits player
Info/Matches/Stats, 20 standings rows, 15 leaderboard rows, Trending, news, match
detail, settings and the news reader. News contains 20 fixture articles. Because
the real panel also constructs its hidden popup, this intentionally includes extra
view construction; it does not represent the cost of a single visible screen.
The stress run expands a recorded game-log fixture to the parser's 200-match cap
and raises the base font from 12px to 18px. All statistics remain fixture data.

## Measurements

| Capture | Trace window | Creating records | Longest creation | Longest binding | Longest JS handler |
| --- | ---: | ---: | ---: | ---: | ---: |
| Normal, 3 matches / 12px | 8.266s | 19,556 | 69.957ms | 31.324ms | 51.201ms |
| Stress, 200 matches / 18px | 8.435s | 25,894 | 68.567ms | 55.767ms | 114.753ms |

The trace window includes deliberate 650ms waits between views and screenshot
capture. It is not startup latency. Individual records overlap and nest; inclusive
totals must not be added together or interpreted as CPU/wall time. Both captures
completed with zero unfinished records. Machine-readable summaries are stored in
[normal.json](performance/normal.json) and [stress.json](performance/stress.json).

The longest normal JS chain is shell palette initialization (`Color.qml`). The
longest stress signal/JS chain is the harness timer, which walks geometry/focus
metadata and requests a screenshot. Those operations are test overhead, not
production event handlers. Increased creation/binding work at 200 matches makes
the history list a candidate for a focused desktop profile, but these measurements
do not isolate delegate creation from rendering, theme initialization and harness
work. No new lazy loading or virtualization was introduced. Existing bounded lists
and existing on-demand requests remain in place.

## Reproduce

Build the image as described in [architecture](architecture.md), then run:

```sh
mkdir -p /tmp/futbar-profile
# The container must be able to write this output directory.
docker run --rm --network none \
  -v "$PWD:/work" -v /tmp/futbar-profile:/output futbar-runtime \
  bash -c 'export XDG_RUNTIME_DIR=$(mktemp -d); chmod 700 "$XDG_RUNTIME_DIR"; dbus-run-session -- cage -- python3 ci/ui_workload.py --output /output --profile'
python3 ci/summarize_profile.py /tmp/futbar-profile/trace.qtd
```

For the stress case, append `--font-size 18 --history-count 200` to the workload
command. Omit `--profile` for the same visual/geometry workload without profiler
overhead. Each run produces screenshots and a runtime log; profiler runs also
produce `trace.qtd`, which Qt Creator can open. The integration suite runs normal
and large-font geometry/focus checks without profiling and sends real keyboard
input through Qt Quick Test. Host runtime versions, GPU rendering, warm caches and
real API payloads can change results; repeat a focused profile before optimizing.
