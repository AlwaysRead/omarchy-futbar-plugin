# Security and maintenance

FutBar is trusted local plugin code running inside the Omarchy shell. ESPN data
is untrusted input. Installing a modified plugin or compromising the local
Python interpreter, executable search path, shell, or user account is outside
the protection provided here. This is hardening, not a security certification.

## Boundaries

- All HTTP is handled by `lib/http_client.py` in subprocesses. Only HTTPS to
  `site.web.api.espn.com`, `site.api.espn.com`, `sports.core.api.espn.com`, and
  (for images) `a.espncdn.com` is allowed. Userinfo, nonstandard ports, fragments,
  controls, redirects, proxy environment settings, and compressed responses
  are rejected. TLS certificate validation uses Python's standard defaults.
- The shared HTTP scheduler admits at most four active HTTP operations and sixteen
  waiting callers across JSON, images and statistics helpers. Queue time consumes
  the caller's timeout. Successful small responses coalesce for three seconds in
  32 fixed cache slots (at most 256 KiB each / 8 MiB total). Runtime storage is
  per-user, mode 0700; files are mode 0600, regular, single-link files opened with
  `O_NOFOLLOW`. URLs are hashed as cache keys; cached public response bodies may
  contain provider links. Locks release on process exit. This bounds HTTP work,
  rather than claiming to sandbox helpers or impose one global process count.
- JSON responses have caller-specific limits of 1–8 MiB. Multi-URL requests
  share a total byte budget and allow at most 64 URLs. JSON is checked before
  reaching QML: depth ≤64, arrays ≤5,000 entries, objects ≤1,024 keys, strings
  ≤64 KiB, and at most 300,000 values per response. Aggregation permits at
  most 128 API URLs with four workers and 1 MiB per response. Helpers have wall
  time, CPU time, and 256 MiB virtual-memory limits.
- Remote image bodies are limited to 512 KiB and PNG dimensions to 1024×1024.
  Ancillary metadata is removed and the decompressed pixel stream is bounded
  and validated before Qt decoding. Images default to asynchronous 128×128
  decoding; individual views may specify their display resolution. Animation and unknown
  critical chunks are rejected. Four image workers share a cache bounded to
  128 entries / 8 MiB of encoded data. Other formats remain blank.
- News requests use a separate reusable controller: at most one
  request per view, 2 MiB for news / 5 MiB for schedules, a helper deadline and a QML watchdog.
  Selection changes cancel work and reject stale results. News links
  use the same ESPN-only external-link policy as profiles; no media streams or
  article HTML are embedded.
- News photos use the same HTTPS host policy and 512 KiB download cap. JPEGs
  require ImageMagick: headers are checked for at most 4096 per edge and 8 million
  pixels before decoding. A separate process receives bytes through stdin with
  an explicit JPEG decoder, a minimal environment, no disk pixel cache, 256 MiB
  address-space limit, four CPU seconds and a five-second subprocess timeout.
  Raw RGB output goes to a size-limited temporary file and is reconstructed as
  a metadata-free PNG (at most 512 per edge / 160,000 pixels), then checked by
  the existing PNG validator. Only that PNG reaches Qt. ESPN's CDN resizer is
  used for `/photo/` paths; its output is subject to the same local checks.
  This is resource containment, not an OS sandbox for ImageMagick.
- Profile links can open only `https://espn.com/…` or `https://www.espn.com/…`
  after an explicit button click. API-provided schemes cannot launch handlers.
- QML processes use argument arrays. Remote values are never shell commands,
  Python source, JavaScript source, or dynamically generated QML. The helpers
  ignore Python environment settings and user site packages. External programs
  still execute intentionally: `python3`, `notify-send`, `wl-copy`,
  `canberra-gtk-play`, optional `magick`, and `omarchy` IPC for widget settings.
- State and theme file paths are fixed local paths. Remote data does not select
  a file path to write. Notification text and pending notification counts are
  bounded; rendered remote text is treated as plain text or sanitized.

- Legacy profile, standings, statistics, search and match-detail processes now
  capture their selection context, cancel on changes, and discard obsolete output.
- Settings backup/restore accepts a versioned 64 KiB envelope and an allowlist of
  typed preferences / at most 24 followed tabs. Unknown fields are discarded;
  restore requires an explicit UI confirmation. Network responses cannot restore
  settings. Diagnostics reports no user paths, names, IDs or response bodies.
- Spoiler protection gates result-bearing panel content until explicit session
  reveal. Notifications remain suppressed regardless of panel reveal. Reminder
  history is bounded and persisted; stale/partial schedules do not trigger alerts.

## Structure

QML lives under `qml/`, grouped into `panels/`, `views/`, `components/`, `data/`,
and `services/`. Python helpers remain in `lib/` and regression tests in `tests/`.
See [the architecture guide](docs/architecture.md) for the file map, dependency
rules, model/layout boundaries, and the isolated Qt integration CI.

## Checks

```sh
python3 -m unittest discover -s tests -v
node tests/test_security.js
omarchy plugin validate .
git diff --check
```

Runtime checks should load both the widget and panel in an isolated Quickshell
config with the actual Qt 6/Wayland backend. Qt 5 `qmllint` checks syntax only;
Qt 6 lint reports existing dynamic-property warnings and is not a substitute
for exercising views. Interactive coverage of every football data scenario and
an independent security audit remain outside the checks above.

The Qt integration job uses a pinned shell source and headless compositor, rejects
skipped tests, and disables network access during tests. Recorded player-history
fixtures verify season/competition selection, cancellation and cached-data retries.
Layout tests use temporary preferences and mock helpers; they do not write user
configuration. See [the profiling baseline](docs/performance.md) for measured limits.
