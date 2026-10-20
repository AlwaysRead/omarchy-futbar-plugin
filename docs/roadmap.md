# FutBar roadmap

Checked items below are implemented in **2.7.0**.
Released 2.6.0 already included news, completed-match commentary, estimated-rating
labels and a reusable bounded request controller. The duplicate game-log section
and match videos were removed by request and remain removed. My Matches, its
Today/Week screen, calendar export and rest-day display were also removed by request.
The internal followed-schedule controller remains for reminders and alerts.

## Implemented

- [x] Universal football news with thumbnail-left rows, an in-panel photo/summary
  reader, safe ESPN links, a right-aligned Refresh button and Search first in the
  header. No league, player or followed-club news filters.
- [x] Configurable 5/15/30-minute kickoff reminders with persistent bounded
  deduplication and identities that change when kickoff time changes.
- [x] Quiet hours, persistent one-hour snooze, primary/all-followed scope and
  individual club muting. Existing goal/card/event preferences remain available.
- [x] Fixture-change alerts for observed changes to kickoff time or exceptional
  status. First snapshots are silent; partial/obsolete responses are suppressed.
- [x] Lineup-available alerts on an observed transition to at least eleven
  starters per team. First snapshots are silent. This does **not** claim official
  confirmation, and checks are capped at six imminent matches per minute.
- [x] Pinned player/club statistic snapshots with season/competition context,
  missing-value handling and mismatch warnings; no invented per-90 comparisons.
- [x] Estimated rating trend inside the existing player Matches view.
- [x] Compact/comfortable spacing for match crests, reduced
  motion for pulses/fades/spinners, shortcut help, header keyboard focus and
  accessible settings toggles.
- [x] Bounded per-view scroll restoration.
- [x] Versioned settings backup/restore with typed validation, a 64 KiB cap and
  an explicit restore confirmation.
- [x] Selectable redacted diagnostics with dependency checks and request timestamps.
- [x] Cross-process HTTP budget: four active operations, sixteen waiting callers,
  short-lived response coalescing and private, bounded runtime cache files.
- [x] Selection cancellation/output guards on legacy profile, search, statistics,
  standings, picker and match-detail requests.
- [x] Panel-session spoiler reveal across result-bearing content; permanent bar
  and notification protection while anti-spoiler is enabled.
- [x] Shared failure banner, adaptive live/visible/idle polling, bounded backoff
  with jitter and a wall-clock-gap refresh after suspend/resume.
- [x] Separate controllers for existing fixture/profile request pipelines, desktop
  notifications and preference persistence, plus controllers/data helpers for new
  followed schedules, alerts, comparisons, polling and view state. The panel’s layout and state are now separated. Removed invented minutes from starts × 90.
- [x] Deterministic Qt runtime tests for request cancellation, schedule aggregation,
  reminder persistence and lineup transitions, plus concurrency/security tests.

## Engineering updates in 2.7.0

- [x] Separate mutable legacy models into `qml/models/` and popup layout into
  `FutPanelWindow.qml`, retaining a compatibility facade for existing parsers.
- [x] Shared legacy request lifecycle/status controls, context cancellation,
  retry delays, update timestamps and same-context cached refreshes.
- [x] Stable image fallbacks and section loading/refresh status. Successful-update
  timestamps appear faintly at section bottoms and disappear after five seconds.
- [x] Keyboard activation and focus metadata for legacy buttons/rows, with
  narrow-width/large-font fixture checks and horizontally scrollable standings.
- [x] Qt 6/Quickshell integration CI with pinned Omarchy source and a headless
  compositor. Missing runtime tests fail the integration job instead of skipping.
- [x] QML Profiler baseline and a 200-match stress capture before adding new
  virtualization/lazy loading. See [measurements](performance.md); no new lazy
  loading has been introduced.
- [x] Season/competition controls, refresh/retry and cached-data handling inside
  the existing player Matches tab. Removed the superseded overview request/parser.

## Further engineering opportunities

- Narrow the remaining root compatibility contracts as parsers are refactored;
  file separation does not remove all coupling.
- Use the performance baseline to target measured desktop bottlenecks before
  changing view lifetimes or adding list virtualization.
- Extend fixtures when populated ESPN responses establish new data shapes.

## ESPN features requiring more evidence

ESPN observations were checked on 2026-10-20. Successful samples do not establish
complete coverage or a stable API contract. This backlog uses ESPN only.

- [ ] **Event/shot map:**
  [the Brentford–Liverpool summary](https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/summary?event=401879262)
  contains repeated play IDs and coordinates, including shots. Another sampled
  La Liga summary had no coordinates. Validate scale and attacking direction
  across matches/competitions before drawing a pitch. Coordinates do not give xG.
- [ ] **Injuries/suspensions:**
  [the league endpoint](https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/injuries)
  still returned an empty injuries list. Require populated samples and verified
  status meanings; an empty feed does not mean all players are fit.
- [ ] **Expected goals/advanced shot quality:** no reliable soccer xG contract was
  established. Do not synthesize xG or imply coverage from coordinates.
- [ ] **Official lineup confirmation:** available starter lists do not establish
  an official-confirmation flag. The implemented alert is explicitly availability.

## Acceptance criteria

All features must use bounded HTTP helpers, cap collections and strings, handle
missing/partial data, and keep API values out of executable code and shell command
strings. Use fixed HTTPS sources and explicit user actions for external links.
Release publication and marketplace verification always identify the exact target commit.
