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
- News and game-log requests use a separate reusable controller: at most one
  request per view, 2 MiB per response, a helper deadline and a QML watchdog.
  Selection changes cancel work and reject stale results. News and video links
  use the same ESPN-only external-link policy as profiles; no media streams or
  article HTML are embedded. The existing image policy remains unchanged.
- Profile links can open only `https://espn.com/…` or `https://www.espn.com/…`
  after an explicit button click. API-provided schemes cannot launch handlers.
- QML processes use argument arrays. Remote values are never shell commands,
  Python source, JavaScript source, or dynamically generated QML. The helpers
  ignore Python environment settings and user site packages. External programs
  still execute intentionally: `python3`, `notify-send`, `wl-copy`,
  `canberra-gtk-play`, and `omarchy` IPC for widget settings.
- State and theme file paths are fixed local paths. Remote data does not select
  a file path to write. Notification text and pending notification counts are
  bounded; rendered remote text is treated as plain text or sanitized.

## Structure

QML lives under `qml/`, grouped into `panels/`, `views/`, `components/`, `data/`,
and `services/`. Python helpers remain in `lib/` and regression tests in `tests/`.
See [the architecture guide](docs/architecture.md) for the file map, dependency
rules, and the remaining work to split the large panel's state and layout.

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
