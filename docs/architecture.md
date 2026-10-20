# Project layout

FutBar's manifest stays at the repository root so Omarchy can discover and
install the plugin. Its entry point is `qml/FutBar.qml`.

```text
.
├── manifest.json                  # Plugin registration and settings
├── README.md / SECURITY.md
├── assets/                        # Documentation screenshots
├── docs/                          # Architecture and remaining roadmap
├── qml/
│   ├── FutBar.qml                 # Bar widget and panel loader
│   ├── panels/FutBarPanel.qml     # Composition, compatibility facade and domain logic
│   ├── models/                    # Profile, fixture, competition, detail and navigation state
│   ├── controllers/
│   │   ├── FutPlayerHistory.qml   # Season/competition history requests
│   │   ├── FutApiRequest.qml      # Single-flight, bounded requests and stale data
│   │   ├── FutFixtureController.qml # Existing fixture fetch pipeline
│   │   ├── FutProfileRequests.qml # Existing profile/search requests and parsers
│   │   ├── FutNotificationController.qml # Desktop notification delivery
│   │   ├── FutPreferenceController.qml # Preference persistence and reset
│   │   ├── FutFollowedMatches.qml # Bounded followed-schedule aggregation
│   │   ├── FutAlertController.qml # Persistent reminders and fixture transitions
│   │   ├── FutLineupAlerts.qml    # Starting-lineup availability transitions
│   │   └── FutViewState.qml       # Bounded per-view scroll restoration
│   ├── views/                     # News, matches, profiles, tables, settings
│   │   ├── FutPanelWindow.qml     # Popup layout and private view handles
│   │   ├── FutComparisonCard.qml
│   │   ├── FutExtraSettings.qml
│   │   ├── FutNewsView.qml / FutNewsReader.qml
│   │   └── ...                    # Existing feature screens
│   ├── components/
│   │   ├── FutContextProcess.qml  # Selection guards for legacy request parsers
│   │   ├── FutActionArea.qml / FutRequestStatus.qml
│   │   ├── FutFormChart.qml       # Estimated recent-rating trend
│   │   ├── FutRemoteImage.qml / FutNewsPhoto.qml
│   │   └── ...                    # Loading and searchable dropdown controls
│   ├── data/
│   │   ├── FutPlayerHistory.js    # Bounded named-stat parsing and filter URLs
│   │   ├── FutMatches.js          # Schedule normalization and reminders
│   │   ├── FutPreferences.js      # Typed/versioned settings and quiet hours
│   │   ├── FutComparison.js       # Context-preserving statistic snapshots
│   │   └── FutData.js / FutExtras.js
│   └── services/
│       ├── FutNetwork.js          # Fixed helper commands and URL policy
│       ├── FutPollingPolicy.js    # Activity-aware intervals and backoff
│       └── FutImageCache.js       # Bounded image cache and worker slots
├── lib/
│   ├── http_client.py             # HTTP policy and resource limits
│   ├── request_scheduler.py       # Cross-process HTTP budget and coalescing
│   ├── fetch_json.py / aggregate_stats.py
│   ├── fetch_image.py / fetch_photo.py
│   └── diagnostics.py             # Redacted dependency report
├── ci/                            # Pinned runtime, offline UI workload and profiling
├── tests/                         # Data, security, concurrency and Qt runtime
└── .github/workflows/check.yml
```

## Placement and dependencies

- Add feature screens under `qml/views/` and reusable UI under `qml/components/`.
- Reusable request lifecycle components belong in `qml/controllers/`. New views
  use `FutApiRequest` for cancellation, bounded responses, retries, and stale data.
- Keep football parsing and formatting in `qml/data/`. Network command building
  and shared runtime services belong in `qml/services/`.
- All Python network access goes through `lib/http_client.py`. QML invokes those
  helpers through `FutNetwork.js`, which resolves `../../lib/` relative to itself.
- Use explicit relative imports between QML directories. Views receive panel
  state through their existing `root` property; they must not import the panel.
- The bar imports the panel as a QML component. This lets Quickshell discover
  the panel and its dependencies when it loads the manifest entry point.
- Keep user-facing documentation images in `assets/`; they are not runtime UI
  resources. The root preview remains available to marketplace tooling.

## Model and view boundaries

`qml/models/` owns mutable profile, competition, fixture, detail and navigation
state. `FutBarPanel.qml` exposes compatibility aliases so existing views and
parsers keep the same root contract. `FutPanelWindow.qml` owns the popup layout,
UI-only inline controls, and private view IDs; it exports the four handles needed
for navigation and scroll restoration. The panel is about 7,100 lines, primarily
existing domain logic; the window is about 2,900 lines. The root facade deliberately
remains while individual parser/view contracts can be narrowed in later refactors.

`FutContextProcess` gives older request parsers shared selection invalidation,
watchdogs, failure state, retry timing and successful-response timestamps.
`FutRequestStatus` presents loading, cached refresh, error, update time and retry
consistently in profile, standings/bracket, statistics, match detail and match lists.
New requests and player history use `FutApiRequest`. Refreshes retain data for the
same context; context changes invalidate obsolete output. Image placeholders keep
reserved slots stable while helpers load or reject images.

## Verification

Run the commands listed in [SECURITY.md](../SECURITY.md#checks). The runtime tests
preserve the packaged directory layout so they detect broken imports and helper
paths. The full widget/panel test requires Omarchy UI modules and a Wayland compositor;
it isolates favorite state in a temporary copy. The image lifecycle test needs
Quickshell and runs offscreen. The lightweight security job permits unavailable-runtime skips; the separate
Qt integration job builds `ci/Dockerfile`, pins Omarchy source to
`0a7beb7d6fe2b677bdc57ff05518b073b2d6ee60`, runs Cage with a headless software
renderer, disables test network access, and fails if any test skips. Arch runtime
packages update together; the base image digest and shell source are pinned.

```sh
docker build -f ci/Dockerfile -t futbar-runtime .
docker run --rm --network none -v "$PWD:/work" futbar-runtime
```

The UI workload checks visible geometry and focus metadata at 360px width with
12px and 18px base fonts, captures screenshots, and exercises profiles, standings,
statistics, trending, match detail, settings and news. Qt Quick Test sends real
Tab/Shift+Tab/Return/Space events to legacy clickable rows. These fixture checks
complement interactive QA; they do not establish coverage of every live API shape.

The new features are already separated into controllers, pure data helpers and
views. Legacy parser callbacks use `FutContextProcess` to keep selection lifetime
checks out of their football parsing. `FutFollowedMatches` talks only to bounded
requests and normalized match records; `FutAlertController` owns reminder state
and emits notification requests rather than executing desktop commands itself.
