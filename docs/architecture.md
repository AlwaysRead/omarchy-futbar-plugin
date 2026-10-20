# Project layout

FutBar's manifest stays at the repository root so Omarchy can discover and
install the plugin. Its entry point is `qml/FutBar.qml`.

```text
.
├── manifest.json                  # Omarchy plugin registration and settings
├── README.md
├── SECURITY.md                    # Trust boundaries and security checks
├── LICENSE
├── preview.png                    # Marketplace preview
├── assets/                        # Documentation screenshots
├── docs/
│   ├── architecture.md
│   └── roadmap.md                # Priorities and ESPN feature opportunities
├── qml/
│   ├── FutBar.qml                 # Bar widget and panel loader
│   ├── controllers/
│   │   └── FutApiRequest.qml      # On-demand requests, cancellation, stale data
│   ├── panels/
│   │   └── FutBarPanel.qml        # Panel state, requests, and composition
│   ├── views/                     # Feature-specific screens
│   │   ├── FutBracketView.qml
│   │   ├── FutNewsView.qml
│   │   ├── FutProfileView.qml
│   │   ├── FutSettingsView.qml
│   │   ├── FutStandingsView.qml
│   │   ├── FutStatsView.qml
│   │   ├── FutTrendingView.qml
│   │   └── MatchDetailView.qml
│   ├── components/                # Reusable presentation components
│   │   ├── FutLoadingOverlay.qml
│   │   ├── FutRemoteImage.qml
│   │   └── FutSearchableDropdown.qml
│   ├── data/
│   │   ├── FutExtras.js           # Bounded news and video transformations
│   │   └── FutData.js             # Football data transformations and lookup tables
│   └── services/
│       ├── FutNetwork.js         # Helper commands and external-link policy
│       └── FutImageCache.js      # Shared bounded image cache and worker slots
├── lib/                           # Python subprocess helpers; standard library only
│   ├── http_client.py            # Shared HTTP policy and resource limits
│   ├── fetch_json.py
│   ├── fetch_image.py
│   └── aggregate_stats.py
├── tests/                         # Unit, security, and QML runtime checks
└── .github/workflows/check.yml    # Continuous regression checks
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

## Remaining internal refactor

The directory boundaries are established, but `FutBarPanel.qml` still combines
about 12,000 lines of state, request orchestration, and layout. Its next refactor
should extract profile/search state and fixture/calendar state into controllers,
then move panel layout into smaller components with explicit properties and
signals. That work needs view-by-view behavior tests; moving files alone does
not resolve this coupling.

## Verification

Run the commands listed in [SECURITY.md](../SECURITY.md#checks). The runtime tests
preserve the packaged directory layout so they detect broken imports and helper
paths. The full widget/panel test requires an installed Omarchy Wayland session;
it isolates favorite state in a temporary copy. The image lifecycle test needs
Quickshell and runs offscreen. CI skips tests whose runtime is unavailable.
