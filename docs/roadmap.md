# FutBar roadmap

Unchecked items are proposed work. Priorities reflect reliability first,
then everyday usefulness. ESPN endpoint observations were checked on 2026-10-20;
a successful sample is not a guarantee of coverage or a stable API contract.
This backlog uses ESPN only.

## Delivered in 2.6.0

- [x] League news with followed-club filtering, transfer labels, and safe ESPN links.
- The duplicate default-season game-log section was removed; the existing
  player Matches history remains the single view.
- [x] Related match video links and completed-match commentary.
- [x] Mark locally estimated ratings with an asterisk and explanation.
- [x] New request controller with context cancellation, bounded payloads, failure
  categories, retry cooldowns, and last-known-good results for the new views.
- [x] Spoiler guards for the new views, full match details, notifications, and bar
  scores/tooltips. This does not complete the cross-view spoiler audit below.

Form charts, wider season/competition controls, global scheduling, event maps,
lineup/schedule alerts, and the remaining items below still need implementation.

## P0 — reliability and hardening

- [ ] Global request scheduler: bound total workers and queued requests across
  JSON, images, and statistics; deduplicate requests and discard obsolete work.
- [ ] Complete spoiler protection across scores, tooltips, notifications,
  commentary, and match details, with explicit reveal.
- [ ] Structured failures: distinguish offline, timeout, rate limiting, invalid
  data, and unsupported images; offer appropriate retries.

## P1 — maintainability and everyday use

- [ ] Adaptive polling based on live matches, visible views, connectivity, and
  suspend/resume; exponential backoff with jitter on failures.
- [ ] Extract fixture, profile/search, notification, and preference controllers
  from the large panel. Keep explicit properties/signals and behavior coverage.
- [ ] Consistent last-known-good data, last-updated times, and stale/offline
  indicators across views.
- [ ] Qt 6/Quickshell integration CI with recorded fixtures and a test compositor.
- [ ] Local image fallbacks, reserved image space, and section-level loading.
- [ ] Kickoff reminders at configurable 5/15/30-minute offsets; deduplicate and
  reconcile rescheduled fixtures.
- [ ] My Matches: today/week across followed clubs and competitions.
- [ ] Notification quiet hours, snooze, and per-club/event preferences.
- [ ] Calendar export (`.ics`) with stable event IDs and timezone-safe times.
- [ ] Versioned, validated settings backup/restore with size limits.
- [ ] Diagnostics showing connectivity, dependencies, last successful requests,
  and a redacted report.

## P2 — UI/UX and cleanup

- [ ] Keyboard navigation, visible focus, accessible names, and shortcut help.
- [ ] Compact/comfortable density and reliable scaling.
- [ ] Preserve scroll positions and filters when returning to a view.
- [ ] Distinct empty states for no fixtures, unavailable coverage, and offline.
- [ ] Reduced-motion option for pulses, transitions, and loading effects.
- [ ] Profile with Qt QML Profiler before adding virtualization or lazy loading.
- [ ] Remove obsolete code as controllers are extracted; keep runtime resources,
  documentation, tests, and network helpers in their established directories.

## ESPN opportunities

Existing functionality already includes lineups, commentary, standings, leaders,
team form, recent player matches, transfers, broadcasts, venue/referee details,
and editorial previews/recaps. The items below extend that functionality.

### New endpoints not currently requested

| Priority | Feature | Endpoint and observed evidence | Delivery requirements |
| --- | --- | --- | --- |
| Delivered | League news and followed-club news feed | [`/apis/site/v2/sports/soccer/eng.1/news`](https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/news) returned articles with IDs, timestamps, team/topic categories, and ESPN web links. | Filter by category team IDs, deduplicate across leagues, label transfer rumors as news, respect spoilers. Start with text and validated ESPN links. |
| Future enhancement | Improve the existing player match history; no separate game-log section | [`/apis/common/v3/sports/soccer/athletes/173896/gamelog`](https://site.web.api.espn.com/apis/common/v3/sports/soccer/athletes/173896/gamelog) returned event metadata, named stat columns, and per-event statistics. | Enhance the existing recent-match view in place if needed; do not add a duplicate section. Map columns by returned names, validate season filters and competition coverage, and retain missing values as unknown. |

The news sample returned six articles. Filtering that small feed is not a
complete club-news archive. A probe of `/teams/364/news` returned an empty object,
so do not depend on a team-specific news endpoint without further evidence.
News images include JPEGs and external media hosts; the current static-PNG image
policy must not be bypassed to display them.

### New features from endpoints already in use

The following are additional uses of existing ESPN responses, not new APIs.
The [sample match summary](https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/summary?event=401879262)
contained commentary play coordinates and video metadata.

- [ ] **P2: Event/shot map.** Preserve `commentary[].play.fieldPositionX/Y`;
  deduplicate repeated commentary entries by play ID. Validate coordinate scale,
  attacking direction, shot classification, and coverage across competitions
  before rendering a pitch. Coordinates alone do not provide expected goals.
- [x] **P2: Match video links.** Show available clip titles/durations from
  `videos`; open a validated ESPN web page on explicit click. Availability and
  regional restrictions may vary. Do not embed streaming URLs or load new media
  hosts into the shell.
- [ ] **P1: Lineup-announced alerts.** Detect a transition from unavailable to
  confirmed lineups in `summary.rosters`, with one alert per match and corrections
  handled separately. Validate what indicates confirmation before shipping.
- [ ] **P1: Postponed/rescheduled/cancelled alerts.** Compare scoreboard/schedule
  status and kickoff times against bounded saved state; suppress first-load
  notifications and stale-response reversions.
- [ ] **P2: Fixture congestion and rest-day view.** Derive intervals from existing
  team schedules; explain when competition coverage is incomplete.
- [ ] **P2: Player/team comparisons.** Reuse statistics and game logs; align
  seasons, competitions, units, and minutes before calculating per-90 values.
- [ ] **P1: Data provenance.** Distinguish provider statistics from locally
  estimated player ratings and show missing/partial coverage explicitly.
- [x] **P2: Completed-match commentary.** Retain an accessible commentary tab
  after full time; the sampled completed match still returned commentary, and
  the UI now exposes the tab after full time when commentary is available.

### Investigate before committing to a feature

- [ ] **Injuries/suspensions:** the
  [league injuries endpoint](https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/injuries)
  returned an envelope with an empty `injuries` list. This does not establish
  usable soccer coverage or mean everyone is fit. Require populated samples
  across clubs/leagues and verified status semantics.
- [ ] **Expected goals and advanced shot quality:** no usable xG field was
  established in this inspection. Do not invent xG from coordinates or advertise
  it until a suitable ESPN payload and interpretation are verified.

## Acceptance criteria and order

Every API feature must use the existing bounded HTTP helpers, validate response
shape, cap collection sizes, handle missing data, and keep arbitrary API links
out of subprocess commands and URL fetches. Add representative fixtures for
populated, empty, malformed, and partial responses. Avoid uncontrolled polling
or reference-link fan-out.

Suggested order: global scheduler → spoiler protection → error/stale-data UX →
controller extraction → reminders/My Matches → ESPN news → lineup/schedule
alerts → game-log improvements → event maps and accessibility polish.

Useful engineering references:
[OWASP resource consumption](https://api-security.owasp.org/editions/2023/en/0xa4-unrestricted-resource-consumption/),
[Qt accessibility](https://doc.qt.io/qt-6/qml-qtquick-accessible.html),
and [Qt Quick profiling](https://doc.qt.io/qt-6/qtquick-profiling.html).
