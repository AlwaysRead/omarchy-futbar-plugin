import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// The expandable fixture view. It deliberately loads a small date range only
// when opened, rather than making the compact bar widget poll every fixture.
Panel {
  id: root
  moduleName: "devbook.futbar"
  ipcTarget: "devbook.futbar"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  // The last team the user chose is remembered in a small state file, so a
  // reload never falls back to the manifest default (Barcelona) when the
  // shell.json setting is missing or arrives late.
  readonly property string favoritePath: Quickshell.env("HOME") + "/.local/state/omarchy/futbar.json"
  property var savedFavorite: ({})
  property bool _favoriteLoaded: false
  function parseFavorite(txt) {
    if (!txt || typeof txt !== "string" || txt.length > 65536) return ({})
    try {
      var parsed = JSON.parse(txt)
      return parsed && typeof parsed === "object" ? parsed : ({})
    } catch (e) { return ({}) }
  }
  // The state file is authoritative: the shell's injected settings can be
  // stale at reload (it hands over the previous in-memory team before syncing
  // shell.json), so prefer the remembered favorite over settings.
  readonly property string teamName: root.leagueMode ? "" : root.sanitizePlainText(root.savedFavorite.teamName !== undefined && root.savedFavorite.teamName !== ""
    ? root.savedFavorite.teamName : setting("teamName", ""))
  readonly property string league: root.sanitizePlainText(root.savedFavorite.league !== undefined && root.savedFavorite.league !== ""
    ? root.savedFavorite.league : setting("league", ""))
  readonly property string teamId: root.leagueMode ? "" : root.safeIdentifier(root.savedFavorite.teamId !== undefined && root.savedFavorite.teamId !== ""
    ? root.savedFavorite.teamId : setting("teamId", ""))
  // Bar widgets expose their text color as barForeground. Using `foreground`
  // here resolves to an invalid (transparent) color on the popup.
  readonly property color contentForeground: bar ? bar.barForeground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string themeColorsPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
  property var themePalette: ({})

  FileView {
    id: themeColorsFile
    path: root.themeColorsPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      var lines = String(text() || "").split("\n")
      var pal = {}
      for (var i = 0; i < lines.length; i++) {
        var match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
        if (match) pal[match[1]] = match[2]
      }
      root.themePalette = pal
    }
  }

  readonly property color statsHomeColor: (root.themePalette && (root.themePalette.cyan || root.themePalette.blue || root.themePalette.bright_cyan || root.themePalette.bright_blue))
    ? (root.themePalette.cyan || root.themePalette.blue || root.themePalette.bright_cyan || root.themePalette.bright_blue)
    : Color.accent

  readonly property color statsAwayColor: (root.themePalette && (root.themePalette.red || root.themePalette.orange || root.themePalette.bright_red || root.themePalette.magenta))
    ? (root.themePalette.red || root.themePalette.orange || root.themePalette.bright_red || root.themePalette.magenta)
    : Color.urgent

  readonly property bool anyLoading: root.loading || root.matchListLoading || root.standingsLoading || root.statsLoading || root.matchDetailLoading || root.teamsLoading

  SequentialAnimation on _pulse {
    running: root.anyLoading
    loops: Animation.Infinite
    NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutQuad }
    NumberAnimation { to: 0.0; duration: 450; easing.type: Easing.InOutQuad }
  }

  component LoadingOverlay: Item {
    id: overlay
    property bool active: false
    property string text: "Fetching data…"
    property int spinnerSize: Style.space(36)

    anchors.fill: parent
    visible: opacity > 0
    opacity: active ? 1.0 : 0.0
    z: 99

    Behavior on opacity {
      NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Color.popups.background
      opacity: 0.90
    }

    Column {
      anchors.centerIn: parent
      spacing: Style.space(12)

      Item {
        id: spinnerContainer
        anchors.horizontalCenter: parent.horizontalCenter
        width: overlay.spinnerSize
        height: overlay.spinnerSize

        Canvas {
          id: spinnerCanvas
          anchors.fill: parent
          antialiasing: true

          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2
            var cy = height / 2
            var radius = Math.min(width, height) / 2 - Style.space(3)

            ctx.beginPath()
            ctx.arc(cx, cy, radius, 0, 2 * Math.PI)
            ctx.lineWidth = Style.space(3)
            ctx.strokeStyle = Util.alpha(root.contentForeground, 0.15)
            ctx.stroke()

            ctx.beginPath()
            ctx.arc(cx, cy, radius, -Math.PI / 2, Math.PI / 4)
            ctx.lineWidth = Style.space(3.5)
            ctx.lineCap = "round"
            ctx.strokeStyle = root.contentForeground
            ctx.stroke()
          }
        }

        RotationAnimator on rotation {
          running: overlay.active && overlay.visible
          from: 0
          to: 360
          duration: 850
          loops: Animation.Infinite
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.sanitizePlainText(overlay.text)
        color: root.contentForeground
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        opacity: 0.6 + 0.4 * root._pulse
      }
    }
  }
  // First run: no team has been stored in shell.json yet. The manifest default
  // only feeds the settings UI, so an untouched widget has an undefined value.
  // A remembered favorite (the state file) counts as a team too.
  property bool needsTeam: root.leagueMode
    ? false
    : (root.settings
        ? (root.settings.teamName === undefined && root.savedFavorite.teamName === undefined)
        : true)
  // League-follow mode: the user tracks a whole competition instead of a
  // single club. Stored in the favorite file (authoritative on reload).
  readonly property bool leagueMode: (root.savedFavorite.followLeague === true
    || ((root.savedFavorite.teamName === undefined || root.savedFavorite.teamName === "") && (setting("teamName", "") === "") && String(root.league || "") !== ""))
    && String(root.league || "") !== ""
  // True once the widget has started fetching with a real team. Reloads must
  // not fetch (or worse, resolve+persist) with stale in-memory settings before
  // the shell finishes syncing the current shell.json — the shell hands the
  // old team first, then the real one. The first refresh is gated until the
  // team inputs stay identical across two consecutive checks (~1.2s), so the
  // stale injection is never used.
  property bool _started: false
  property string _startupSig: ""
  function hasRealTeam() {
    return String(root.teamName) !== ""
  }
  function teamSignature() {
    return String(root.teamName) + "|" + String(root.teamId) + "|" + String(root.league) + "|" + String(root.leagueMode)
  }
  function ensureStarted() {
    if (root._started) return
    // Wait until the state file has actually been read (it is authoritative),
    // otherwise the injected (possibly stale) settings would win the race.
    if (!root._favoriteLoaded) return
    if (!root.hasRealTeam() && !root.leagueMode) return
    var sig = root.teamSignature()
    if (sig !== root._startupSig) {
      root._startupSig = sig
      return
    }
    root._started = true
    root.refresh()
  }
  Timer {
    id: startupGate
    interval: 600
    repeat: true
    running: !root._started
    onTriggered: root.ensureStarted()
  }

  function safeIdentifier(val) {
    if (!val || typeof val !== "string") return ""
    var trimmed = val.trim()
    return /^[a-zA-Z0-9_.\-]+$/.test(trimmed) ? trimmed : ""
  }

  function sanitizePlainText(raw) {
    if (raw === undefined || raw === null) return ""
    var str = String(raw)
    str = str.replace(/&#(?:60|0*60|x0*3c|x0*3C);/gi, '<')
             .replace(/&#(?:62|0*62|x0*3e|x0*3E);/gi, '>')
             .replace(/&lt;/gi, '<')
             .replace(/&gt;/gi, '>')
             .replace(/&quot;/gi, '"')
             .replace(/&apos;/gi, "'")
             .replace(/&#39;/gi, "'")
             .replace(/&amp;/gi, '&')
    str = str.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]/g, '')
    var prev = ""
    while (prev !== str) {
      prev = str
      str = str.replace(/<[^<>]*>/g, '')
    }
    str = str.replace(/[<>]/g, '')
    str = str.replace(/&(?:[a-zA-Z0-9]+|#\d+|#x[0-9a-fA-F]+);/g, '')
    return str.trim()
  }

  function sanitizeImageUrl(raw) {
    if (!raw || typeof raw !== "string") return ""
    var url = raw.trim()
    if (url.indexOf("http://") === 0) {
      url = "https://" + url.substring(7)
    }
    if (!/^https:\/\/[a-zA-Z0-9\-\._~:\/\?#\[\]@!\$&'\(\)\*\+,;=%]+$/.test(url)) {
      return ""
    }
    // Automatically upgrade lower-resolution ESPN CDN URLs to crisp 500px high-res assets
    url = url.replace(/\/soccer\/(?:50|100|200)\//g, "/soccer/500/")
             .replace(/\/leaguelogos\/soccer\/(?:50|100|200)\//g, "/leaguelogos/soccer/500/")
             .replace(/\/teamlogos\/soccer\/(?:50|100|200)\//g, "/teamlogos/soccer/500/")
             .replace(/&w=\d+/g, "&w=500")
             .replace(/&h=\d+/g, "&h=500")
    return url
  }

  // Reads and safely persists the remembered favorite on startup without shell execution.
  FileView {
    id: favoriteStore
    path: root.favoritePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.savedFavorite = root.parseFavorite(text())
      var ids = root.savedFavorite.followMatchIds
      root.followedLeagueMatches = Array.isArray(ids)
        ? ids.filter(function(x) { return root.safeIdentifier(String(x)) !== "" }) : []
      root._favoriteLoaded = true
    }
    onLoadFailed: { root.savedFavorite = ({}); root._favoriteLoaded = true }
  }

  // The first read can race shell startup; one delayed reload self-corrects.
  Timer {
    interval: 1500
    running: true
    onTriggered: favoriteStore.reload()
  }

  // followedTeamsOverride (5th arg): pass the list explicitly when it's
  // changing in the same logical action as the active club (e.g. adding a
  // club switches to it *and* pushes the outgoing active club onto the tab
  // strip) -- writing both in one setText() avoids a second, separate write
  // racing this one (two back-to-back writes previously let addFollowedTeam
  // persist "adding Liverpool, tab-list gets Ajax" as two steps, where a
  // reload between them could leave the active club still Ajax with Ajax
  // *also* now in the tab list -- "two Ajax tabs" instead of Ajax+Liverpool).
  function saveFavorite(teamName, league, teamId, followedTeamsOverride) {
    var name = teamName !== undefined ? teamName : root.teamName
    var lg = league !== undefined ? league : root.league
    var tid = teamId !== undefined ? teamId : (root.teamId !== "" ? root.teamId : root.resolvedTeamId)
    // A truthy 5th argument (asLeague, shifted down since followedTeamsOverride
    // took slot 4) saves a league-follow instead of a club; it also clears
    // stale club fields so the favorite file stays consistent.
    var asLeague = arguments.length > 4 && arguments[4] === true
    var payload = asLeague
      ? { teamName: "", league: lg, teamId: "", followLeague: true }
      : { teamName: name, league: lg, teamId: tid }
    // Preserve fields this function doesn't know about across a plain save --
    // it used to fully replace the payload, silently dropping followMatchIds
    // (and now followedTeams) whenever the active club changed.
    if (root.savedFavorite && typeof root.savedFavorite === "object") {
      if (Array.isArray(root.savedFavorite.followMatchIds)) payload.followMatchIds = root.savedFavorite.followMatchIds
      if (Array.isArray(root.savedFavorite.followedTeams)) payload.followedTeams = root.savedFavorite.followedTeams
    }
    if (followedTeamsOverride !== undefined) payload.followedTeams = followedTeamsOverride
    root.savedFavorite = payload
    favoriteStore.setText(JSON.stringify(payload, null, 2) + "\n")
  }

  // Teams you're tracking besides the active one -- rendered as tabs in the
  // panel header. The active team is never stored here; it's implicit (it's
  // whatever teamName/league/teamId currently resolve to), so a single-team
  // user's favorite file needs no migration at all.
  function teamKey(name, league) {
    return String(name || "").trim().toLowerCase() + "|" + String(league || "").trim().toLowerCase()
  }
  // Normalizes to well-formed { teamName, league, teamId } objects (all
  // strings) so every consumer -- switchActiveTeam, the tab Repeater -- can
  // trust entry.teamName/.league without a null-check of its own. A
  // hand-edited or otherwise malformed favorite file (nulls, strings,
  // missing keys in followedTeams) would otherwise throw at runtime the
  // first time something reads a field off a bad entry.
  function followedTeamsList() {
    var raw = Array.isArray(root.savedFavorite.followedTeams) ? root.savedFavorite.followedTeams : []
    var out = []
    for (var i = 0; i < raw.length; i++) {
      var entry = raw[i]
      if (!entry || typeof entry !== "object") continue
      var name = typeof entry.teamName === "string" ? entry.teamName : ""
      var lg = typeof entry.league === "string" ? entry.league : ""
      if (name === "" && lg === "") continue
      out.push({ teamName: name, league: lg, teamId: typeof entry.teamId === "string" ? entry.teamId : "" })
    }
    return out
  }
  function persistFollowedTeams(list) {
    var payload = {}
    if (root.savedFavorite && typeof root.savedFavorite === "object") {
      for (var k in root.savedFavorite) payload[k] = root.savedFavorite[k]
    }
    payload.followedTeams = list
    if (payload.teamName === undefined || payload.teamName === null) payload.teamName = root.teamName
    if (payload.league === undefined || payload.league === null || payload.league === "") payload.league = root.league
    if (payload.teamId === undefined || payload.teamId === null) payload.teamId = (root.teamId !== "" ? root.teamId : root.resolvedTeamId)
    root.savedFavorite = payload
    favoriteStore.setText(JSON.stringify(payload, null, 2) + "\n")
  }
  // The one place that changes which club is active. The active club is
  // never itself stored in followedTeams (it's implicit -- whatever
  // teamName/league/teamId currently resolve to), which means every switch
  // has to do two things to the *explicit* list, not just one:
  //   1. drop the destination club from it (it's about to become the
  //      implicit active club, so leaving it in the list too would render
  //      as a duplicate tab of itself)
  //   2. add the club we're switching AWAY from, if it isn't already there
  //      (otherwise it just vanishes -- it was only ever "remembered" by
  //      virtue of being active, and it's about to stop being that)
  // A plain tab click used to call activateTeam directly and only do
  // neither, which is exactly what made switching away from a freshly
  // added club discard that club and re-duplicate whatever you switched to.
  function switchActiveTeam(teamName, league, teamId) {
    var destKey = root.teamKey(teamName, league)
    var activeKey = root.teamKey(root.teamName, root.league)
    var list = root.followedTeamsList().slice()
    for (var i = list.length - 1; i >= 0; i--) {
      if (root.teamKey(list[i].teamName, list[i].league) === destKey) list.splice(i, 1)
    }
    if (destKey !== activeKey && root.teamName !== "") {
      var already = false
      for (var j = 0; j < list.length; j++) {
        if (root.teamKey(list[j].teamName, list[j].league) === activeKey) { already = true; break }
      }
      if (!already) list.push({ teamName: root.teamName, league: root.league, teamId: (root.teamId !== "" ? root.teamId : root.resolvedTeamId) })
    }
    root.activateTeam(teamName, league, teamId, list)
  }
  // "+" flow: adding a club is just switching to one that (typically) isn't
  // followed yet, so it reuses the exact same bookkeeping.
  function addFollowedTeam(teamName, league, teamId) {
    root.switchActiveTeam(teamName, league, teamId)
  }
  function removeFollowedTeam(teamName, league) {
    var key = root.teamKey(teamName, league)
    var list = root.followedTeamsList().slice()
    for (var i = list.length - 1; i >= 0; i--) {
      if (root.teamKey(list[i].teamName, list[i].league) === key) list.splice(i, 1)
    }
    root.persistFollowedTeams(list)
    // Unfollowed clubs don't need their fetched state kept around for a
    // switch that can no longer happen.
    delete root._teamStateCache[key]
  }
  onSettingsChanged: root.ensureStarted()

  property bool loading: false
  property real _pulse: 0.0
  // When the fixtures were last fetched, used to skip redundant refreshes.
  property var lastRefresh: 0
  property string requestError: ""
  property string tournamentName: ""
  property string tournamentLogo: ""
  property var nextMatch: null
  property var previousMatch: null
  property var liveMatch: null
  // Goal / card events for the live match, from the summary endpoint.
  property var liveEvents: []
  // Id of the match the current liveEvents belong to, so stale scorers from a
  // previous match are dropped instead of shown for a few seconds.
  property string summaryMatchId: ""
  // Live Activity: desktop notifications for match start, goals, red cards,
  // half-time and full-time while a match is in play.
  property bool liveActivity: false
  property string activityMatchId: ""
  property var activityFlags: ({ started: false, halftime: false, secondhalf: false, fulltime: false })
  // False until the first summary poll has seeded the flags from the match's
  // current state, so enabling Live Activity mid-match never retro-reports
  // events that already happened.
  property bool activityInitialized: false
  // True while Live Activity has seen the half-time break, so the moment play
  // resumes can be announced as the start of the second half. Needed because
  // soccer keeps both halves and the break under state "in".
  property bool activityWasHT: false
  // True once a knockout match has entered extra time, detected from the
  // "Start Extra Time" key event. The summary header carries no period field,
  // so this flag keeps the regular half-time logic from firing during ET.
  property bool activityET: false
  // How long before kickoff a not-yet-live match can be followed. Tracking
  // before kickoff is what makes the "Match Started" notification possible:
  // enabling during play adopts the current phase silently instead.
  readonly property int followLeadMs: 30 * 60 * 1000
  property var activityEvents: []
  // Goal toasts held back while ESPN's header score lags its key events (the
  // race that made a fresh goal announce the previous scoreline). Maps
  // liveActivityKey → { tries, title, minute, glyph }; resolved once the two
  // sources agree, or after activityPendingMaxTries polls as a safety valve.
  property var activityPending: ({})
  readonly property int activityPendingMaxTries: 3
  // League standings for the selected league, shown from the header button.
  property bool showStandings: false
  // How many seasons back the table is viewing (0 = live season). Reset
  // when the popup closes.
  property int standingsSeasonOffset: 0
  // Soccer seasons straddle calendar years; a July flip covers the main
  // European and American calendars well enough for a label.
  readonly property int standingsSeasonYear: {
    var now = new Date()
    return now.getMonth() >= 6 ? now.getFullYear() : now.getFullYear() - 1
  }
  function seasonChipLabel(offset) {
    var y = root.standingsSeasonYear - offset
    return String(y % 100).padStart(2, "0") + "/" + String((y + 1) % 100).padStart(2, "0")
  }
  property bool standingsLoading: false
  property string standingsError: ""
  property var standingsGroups: []
  property int standingsGroupIndex: 0
  readonly property var activeStandingsGroup: standingsGroups.length > 0
    ? standingsGroups[Math.max(0, Math.min(standingsGroupIndex, standingsGroups.length - 1))] : null
  property string standingsGroupName: activeStandingsGroup ? (activeStandingsGroup.name || "") : ""
  readonly property var standings: activeStandingsGroup ? (activeStandingsGroup.entries || []) : []
  readonly property real standingsRowHeight: Style.space(28)
  readonly property real standingsStatWidth: Style.space(26)
  readonly property real standingsRankWidth: Style.space(24)
  readonly property real standingsRankGap: Style.space(10)
  readonly property real standingsLogoWidth: Style.space(16)
  // Table width tracks the actual standings viewport (bound to the live
  // item below, whose width comes from the panel's real interior), so the
  // rightmost columns (GD, Pts) are never clipped by the Flickable.
  readonly property real standingsRowWidth: standingsTable ? standingsTable.width : Style.space(348)
  readonly property real standingsTeamWidth: root.standingsRowWidth - root.standingsRankWidth - root.standingsRankGap - root.standingsLogoWidth - 8 * root.standingsStatWidth
  // Matches for the selected league's current matchweek, shown from a
  // header button. ESPN carries no round field on soccer events, so the
  // matchweek is detected as the cluster of fixture days around today;
  // chevron arrows page through the other rounds in the window.
  property bool showMatches: false
  property bool showClubFixtures: false
  property bool matchListLoading: false
  property string matchListError: ""
  property var matchClusters: []
  property int matchClusterIndex: 0
  // League-follow board: everything live plus a slice of results/upcoming.
  property var leagueLive: []
  property var leagueRecent: []
  property var leagueUpcoming: []
  // One-line summary for the bar tooltip ("2 live · Real Madrid 1–0 Barça").
  property string leagueBoardSummary: ""
  // When true, the board lists every fixture across the shifted window
  // (past and upcoming) instead of just today's slate.
  property bool leagueBrowseAll: false
  property bool showStats: false
  property int statsSeasonOffset: 0
  property string statsCategory: "goals"
  readonly property bool showStatsMatchesColumn: !(root.league === "usa.1" && (root.statsCategory === "yellow" || root.statsCategory === "red"))
  property var statsGoals: []
  property var statsAssists: []
  property var statsYellow: []
  property var statsRed: []
  property var rawYellowLeaders: []
  property var rawRedLeaders: []
  property var athleteMap: ({})
  property bool statsLoading: false
  property string statsError: ""
  property real lastStandingsRefresh: 0
  property string _lastStandingsKey: ""
  property real lastStatsRefresh: 0
  property string _lastStatsKey: ""
  property real lastMatchListRefresh: 0
  property string _lastMatchListKey: ""
  property bool showMatchDetail: false
  property var matchDetail: null
  property bool matchDetailLoading: false
  property string matchDetailError: ""
  property string matchDetailTab: "stats"
  property string matchDetailLineupTeam: "home"
  property string matchDetailLineupView: "pitch"
  property bool matchDetailCrestsLoaded: false
  property var matchDetailJerseyUrls: []
  readonly property bool customViewActive: root.showStandings || root.showMatches || root.showStats || root.showClubFixtures || root.showMatchDetail || root.leagueMode
  // Per-match league tracking: each followed live fixture notifies its own
  // goals and cards independently (no phase notifications).
  property var followedLeagueMatches: []
  property var leagueSummaryQueue: []
  property string leagueCurrentId: ""
  readonly property var activeMatchCluster: matchClusters.length > 0
    ? matchClusters[Math.max(0, Math.min(matchClusterIndex, matchClusters.length - 1))] : null
  readonly property string matchWeekLabel: activeMatchCluster ? activeMatchCluster.label : ""
  readonly property var matchWeekRows: activeMatchCluster ? activeMatchCluster.rows : []
  // Manual matchweek paging extends the scoreboard window by this many days
  // per step past its edge, so older/future rounds stay reachable one press
  // at a time without preloading the whole season.
  property int matchWindowOffset: 0
  property string pendingEdge: ""
  // Boundary day of the round being viewed when the window was extended;
  // the refreshed payload lands on the round directly beyond it.
  property string navAnchorDay: ""
  readonly property real matchRowHeight: Style.space(52)
  readonly property real matchLogoSize: Style.space(30)
  readonly property real matchScoreWidth: Style.space(92)
  // Favorite team gets a green highlight in the standings for quick scanning.
  readonly property color favoriteTeamAccent: Color.accent
  readonly property color favoriteTeamTint: Util.alpha(Color.accent, 0.45)
  // True for the standings row belonging to the selected club.
  function isFavoriteStanding(entry) {
    if (!entry) return false
    var tid = String(entry.teamId || "")
    var wantedId = root.resolvedTeamId !== "" ? root.resolvedTeamId : root.teamId
    if (tid !== "" && wantedId !== "") return tid === wantedId
    return String(entry.teamName || "").toLowerCase() === String(root.teamName).toLowerCase()
  }
  readonly property var standingsColumns: [
    { label: "P", name: "gamesPlayed" },
    { label: "W", name: "wins" },
    { label: "D", name: "ties" },
    { label: "L", name: "losses" },
    { label: "GF", name: "pointsFor" },
    { label: "GA", name: "pointsAgainst" },
    { label: "GD", name: "pointDifferential" },
    { label: "Pts", name: "points" }
  ]
  // Qualification zones come straight from ESPN's per-entry `note` (e.g.
  // "Champions League", "Relegation playoff"), which tracks the yearly-
  // changing allocations. No local cutoff config is kept.
  readonly property var standingsZoneColors: ({
    cl: "#2f7de1", el: "#f97316", ecl: "#22c55e",
    po: "#a78bfa", rel: "#ef4444", promo: "#2f7de1", promoPo: "#a78bfa"
  })
  readonly property var standingsZoneLabels: ({
    cl: "Champions Lg", el: "Europa Lg", ecl: "Conf. Lg",
    po: "Rel. Playoff", rel: "Relegated", promo: "Promotion", promoPo: "Prom. Playoff"
  })
  function zoneKeyFromNote(note) {
    if (!note) return ""
    var d = String(note.description || "").toLowerCase()
    if (d.indexOf("promotion playoff") !== -1) return "promoPo"
    if (d.indexOf("promotion") !== -1) return "promo"
    if (d.indexOf("champions") !== -1) return "cl"
    if (d.indexOf("europa") !== -1) return "el"
    if (d.indexOf("conference") !== -1) return "ecl"
    if (d.indexOf("relegation playoff") !== -1) return "po"
    if (d.indexOf("relegation") !== -1) return "rel"
    return ""
  }
  function standingsZoneFor(entry) {
    if (!entry) return ""
    return root.zoneKeyFromNote(entry.note)
  }
  function standingsZoneColor(entry) {
    var key = root.standingsZoneFor(entry)
    return key === "" ? "transparent" : String(root.standingsZoneColors[key] || "")
  }
  // Legend shows only the zones actually present in the fetched standings.
  readonly property var standingsLegend: root.standingsLegendFrom(root.standings)
  function standingsLegendFrom(standings) {
    var seen = []
    var i, key
    for (i = 0; i < standings.length; i++) {
      key = root.standingsZoneFor(standings[i])
      if (key !== "" && seen.indexOf(key) === -1) seen.push(key)
    }
    var out = []
    for (i = 0; i < seen.length; i++) {
      key = seen[i]
      out.push({ color: String(root.standingsZoneColors[key] || ""), label: String(root.standingsZoneLabels[key] || key) })
    }
    return out
  }
  property var teams: []
  property bool teamsLoading: teamsRequest.running
  // Team id resolved from the /teams list when it was not stored with the
  // setting (e.g. the team was set through the generic settings UI).
  property string resolvedTeamId: ""
  // slug -> { name, logo } cache for every competition the team plays in.
  property var leagueInfo: ({})
  // Distinct competition slugs the team has fixtures in (e.g. esp.1,
  // uefa.champions, esp.copa_del_rey, club.friendly).
  property var competitionSlugs: []
  property var competitionRefresh: 0
  // Sequential fetch pipeline: one Process drives every request so the
  // pipeline survives shell reloads without interleaving.
  property var fetchQueue: []
  property var collectedEvents: []
  property string fetchStage: ""
  readonly property var teamFixtureRows: root.matchRowsFromEvents(root.collectedEvents)
  property int clubFixturePage: 0
  readonly property int clubPageSize: 5
  readonly property int clubPageCount: Math.max(1, Math.ceil(teamFixtureRows.length / clubPageSize))
  readonly property var pagedClubRows: teamFixtureRows.slice(clubFixturePage * clubPageSize, (clubFixturePage + 1) * clubPageSize)

  function clubSeasonWindow() {
    var now = new Date()
    var currentYear = now.getFullYear()
    var currentMonth = now.getMonth()
    var startYear, endYear
    if (root.league === "usa.1" || root.league === "bra.1" || root.league === "jpn.1") {
      return String(currentYear) + "0101-" + String(currentYear) + "1231"
    }
    if (currentMonth >= 6) {
      startYear = currentYear
      endYear = currentYear + 1
    } else {
      startYear = currentYear - 1
      endYear = currentYear
    }
    return String(startYear) + "0701-" + String(endYear) + "0630"
  }

  function initClubFixturePage() {
    var rows = root.teamFixtureRows
    if (rows.length === 0) { root.clubFixturePage = 0; return }
    var nowMs = Date.now()
    var idx = -1
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].state === "in" || rows[i].state === "pre" || rows[i].kickoff >= nowMs) {
        idx = i
        break
      }
    }
    if (idx !== -1) {
      root.clubFixturePage = Math.floor(idx / root.clubPageSize)
    } else {
      root.clubFixturePage = Math.max(0, root.clubPageCount - 1)
    }
  }
readonly property var leagues: [
    { value: "eng.1", label: "Premier League (England)" },
    { value: "esp.1", label: "LaLiga (Spain)" },
    { value: "ita.1", label: "Serie A (Italy)" },
    { value: "ger.1", label: "Bundesliga (Germany)" },
    { value: "fra.1", label: "Ligue 1 (France)" },
    { value: "ned.1", label: "Eredivisie (Netherlands)" },
    { value: "por.1", label: "Primeira Liga (Portugal)" },
    { value: "ksa.1", label: "Saudi Pro League" },
    { value: "usa.1", label: "MLS (USA)" },
    { value: "mex.1", label: "Liga MX (Mexico)" },
    { value: "bra.1", label: "Brasileirão Série A (Brazil)" },
    { value: "arg.1", label: "Liga Profesional (Argentina)" },
    { value: "sco.1", label: "Scottish Premiership" },
    { value: "bel.1", label: "Belgian Pro League" },
    { value: "tur.1", label: "Süper Lig (Turkey)" },
    { value: "aut.1", label: "Austrian Bundesliga" },
    { value: "gre.1", label: "Greek Super League" },
    { value: "den.1", label: "Danish Superliga" },
    { value: "swe.1", label: "Swedish Allsvenskan" },
    { value: "nor.1", label: "Norwegian Eliteserien" },
    { value: "rus.1", label: "Russian Premier League" },
    { value: "jpn.1", label: "J1 League (Japan)" },
    { value: "chn.1", label: "Chinese Super League" },
    { value: "ind.1", label: "Indian Super League" },
    { value: "aus.1", label: "A-League Men (Australia)" },
    { value: "col.1", label: "Categoría Primera A (Colombia)" },
    { value: "chi.1", label: "Primera División (Chile)" },
    { value: "per.1", label: "Liga 1 (Peru)" },
    { value: "ecu.1", label: "LigaPro Serie A (Ecuador)" },
    { value: "uru.1", label: "Primera División (Uruguay)" },
    { value: "par.1", label: "Primera División (Paraguay)" },
    { value: "bol.1", label: "División Profesional (Bolivia)" },
    { value: "ven.1", label: "Liga FUTVE (Venezuela)" },
    { value: "crc.1", label: "Liga Promerica (Costa Rica)" },
    { value: "rsa.1", label: "South African Premier Division" },
    { value: "eng.2", label: "Championship (England)" },
    { value: "eng.3", label: "League One (England)" },
    { value: "eng.4", label: "League Two (England)" },
    { value: "eng.5", label: "National League (England)" },
    { value: "esp.2", label: "LaLiga 2 (Spain)" },
    { value: "ger.2", label: "2. Bundesliga (Germany)" },
    { value: "ita.2", label: "Serie B (Italy)" },
    { value: "fra.2", label: "Ligue 2 (France)" },
    { value: "ned.2", label: "Eerste Divisie (Netherlands)" },
    { value: "sco.2", label: "Scottish Championship" },
    { value: "usa.usl.1", label: "USL Championship (USA)" },
    { value: "usa.usl.l1", label: "USL League One (USA)" },
    { value: "mex.2", label: "Liga de Expansión MX" },
    { value: "bra.2", label: "Brasileirão Série B" },
    { value: "arg.2", label: "Primera Nacional (Argentina)" },
    { value: "arg.3", label: "Primera B Metropolitana (Argentina)" },
    { value: "usa.nwsl", label: "NWSL (USA Women)" },
    { value: "eng.w.1", label: "Women's Super League (England)" },
    { value: "esp.w.1", label: "Liga F (Spain Women)" },
    { value: "fra.w.1", label: "Première Ligue (France Women)" },
    { value: "aus.w.1", label: "A-League Women (Australia)" },
    { value: "uefa.wchampions", label: "UEFA Women's Champions League" },
    { value: "concacaf.w.champions_cup", label: "CONCACAF W Champions Cup" },
    { value: "usa.w.usl.1", label: "USL Super League (USA Women)" },
    { value: "uefa.champions", label: "UEFA Champions League" },
    { value: "uefa.europa", label: "UEFA Europa League" },
    { value: "uefa.europa.conf", label: "UEFA Conference League" },
    { value: "uefa.super_cup", label: "UEFA Super Cup" },
    { value: "conmebol.libertadores", label: "CONMEBOL Copa Libertadores" },
    { value: "conmebol.sudamericana", label: "CONMEBOL Copa Sudamericana" },
    { value: "conmebol.recopa", label: "CONMEBOL Recopa Sudamericana" },
    { value: "concacaf.champions", label: "CONCACAF Champions Cup" },
    { value: "concacaf.leagues.cup", label: "Leagues Cup (MLS & Liga MX)" },
    { value: "afc.champions", label: "AFC Champions League Elite" },
    { value: "afc.cup", label: "AFC Champions League Two" },
    { value: "caf.champions", label: "CAF Champions League" },
    { value: "caf.confed", label: "CAF Confederation Cup" },
    { value: "fifa.cwc", label: "FIFA Club World Cup" },
    { value: "campeones.cup", label: "Campeones Cup" },
    { value: "eng.fa", label: "FA Cup (England)" },
    { value: "eng.league_cup", label: "Carabao Cup (England)" },
    { value: "eng.charity", label: "FA Community Shield (England)" },
    { value: "esp.copa_del_rey", label: "Copa del Rey (Spain)" },
    { value: "esp.super_cup", label: "Supercopa de España" },
    { value: "ita.coppa_italia", label: "Coppa Italia (Italy)" },
    { value: "ita.super_cup", label: "Supercoppa Italiana" },
    { value: "ger.dfb_pokal", label: "DFB-Pokal (Germany)" },
    { value: "ger.super_cup", label: "DFL-Supercup (Germany)" },
    { value: "fra.coupe_de_france", label: "Coupe de France" },
    { value: "fra.super_cup", label: "Trophée des Champions (France)" },
    { value: "usa.open", label: "US Open Cup" },
    { value: "por.taca.portugal", label: "Taça de Portugal" },
    { value: "ned.cup", label: "KNVB Beker (Netherlands)" },
    { value: "sco.tennents", label: "Scottish Cup" },
    { value: "sco.cis", label: "Scottish League Cup" },
    { value: "ksa.kings.cup", label: "King Cup of Champions (Saudi)" },
    { value: "bra.copa_do_brazil", label: "Copa do Brasil" },
    { value: "bra.supercopa_do_brazil", label: "Supercopa do Brasil" },
    { value: "arg.copa", label: "Copa Argentina" },
    { value: "arg.supercopa", label: "Supercopa Argentina" },
    { value: "col.copa", label: "Copa Colombia" },
    { value: "fifa.world", label: "FIFA World Cup" },
    { value: "fifa.wwc", label: "FIFA Women's World Cup" },
    { value: "uefa.euro", label: "UEFA European Championship (EURO)" },
    { value: "uefa.weuro", label: "UEFA Women's EURO" },
    { value: "uefa.nations", label: "UEFA Nations League" },
    { value: "uefa.w.nations", label: "UEFA Women's Nations League" },
    { value: "conmebol.america", label: "Copa América" },
    { value: "conmebol.america.femenina", label: "Copa América Femenina" },
    { value: "concacaf.gold", label: "CONCACAF Gold Cup" },
    { value: "concacaf.w.gold", label: "CONCACAF W Gold Cup" },
    { value: "concacaf.nations.league", label: "CONCACAF Nations League" },
    { value: "caf.nations", label: "Africa Cup of Nations (AFCON)" },
    { value: "afc.asian.cup", label: "AFC Asian Cup" },
    { value: "fifa.olympics", label: "Olympic Men Football" },
    { value: "fifa.w.olympics", label: "Olympic Women Football" },
    { value: "fifa.friendly", label: "International Friendlies" },
    { value: "fifa.friendly.w", label: "Women's Friendlies" },
    { value: "club.friendly", label: "Club Friendlies" },
    { value: "afc.cupq", label: "AFC Asian Cup Qualifiers" },
    { value: "afc.champions_qual", label: "AFC Champions League Elite Qualifying" },
    { value: "afc.cup_qual", label: "AFC Champions League Two Qualifying" },
    { value: "afc.w.asian.cup", label: "AFC Women's Asian Cup" },
    { value: "aff.championship", label: "ASEAN Championship" },
    { value: "caf.nations_qual", label: "Africa Cup of Nations Qualifying" },
    { value: "caf.championship", label: "African Nations Championship" },
    { value: "global.gulf_cup", label: "Arabian Gulf Cup" },
    { value: "arg.copa_de_la_superliga", label: "Argentine Copa de la Superliga" },
    { value: "arg.supercopa.internacional", label: "Argentine Supercopa Internacional" },
    { value: "arg.trofeo_de_la_campeones", label: "Argentine Trofeo de Campeones" },
    { value: "global.arnold.clark_cup", label: "Arnold Clark Cup" },
    { value: "bel.promotion.relegation", label: "Belgian Pro League Promotion/Relegation Playoffs" },
    { value: "bol.ply.rel", label: "Bolivian Liga Profesional Promotion/Relegation Playoffs" },
    { value: "bra.camp.carioca", label: "Brazilian Campeonato Carioca" },
    { value: "bra.camp.gaucho", label: "Brazilian Campeonato Gaucho" },
    { value: "bra.camp.mineiro", label: "Brazilian Campeonato Mineiro" },
    { value: "bra.camp.paulista", label: "Brazilian Campeonato Paulista" },
    { value: "concacaf.champions_cup", label: "CONCACAF Champions Cup" },
    { value: "concacaf.u23", label: "CONCACAF U23 Tournament" },
    { value: "fifa.conmebol.olympicsq", label: "CONMEBOL Pre-Olympic Tournament" },
    { value: "global.club_challenge", label: "CONMEBOL-UEFA Club Challenge" },
    { value: "global.finalissima", label: "CONMEBOL-UEFA Cup of Champions" },
    { value: "global.u20.intercontinental_cup", label: "CONMEBOL-UEFA U20 Intercontinental Cup" },
    { value: "global.w.finalissima", label: "CONMEBOL-UEFA Women's Cup of Champions" },
    { value: "caf.cosafa", label: "COSAFA Cup" },
    { value: "chi.1.promotion.relegation", label: "Chilean Primera División Promotion/Relegation Playoffs" },
    { value: "chi.super_cup", label: "Chilean Supercopa" },
    { value: "chn.1.promotion.relegation", label: "Chinese Super League Promotion/Relegation Playoffs" },
    { value: "col.superliga", label: "Colombian Superliga" },
    { value: "concacaf.central.american.cup", label: "Concacaf Central American Cup" },
    { value: "concacaf.confederations_playoff", label: "Concacaf Cup" },
    { value: "concacaf.gold_qual", label: "Concacaf Gold Cup Qualifying" },
    { value: "concacaf.womens.championship", label: "Concacaf W Championship" },
    { value: "fifa.w.concacaf.olympicsq", label: "Concacaf Women's Olympic Qualifying" },
    { value: "bol.copa", label: "Copa Bolivia" },
    { value: "chi.copa_chi", label: "Copa Chile" },
    { value: "ned.playoff.relegation", label: "Dutch Eredivisie Promotion/Relegation Playoffs" },
    { value: "ned.supercup", label: "Dutch Johan Cruyff Shield" },
    { value: "ned.w.knvb_cup", label: "Dutch KNVB Beker Vrouwen" },
    { value: "ned.3.promotion.relegation", label: "Dutch Tweede Divisie Promotion/Relegation Playoffs" },
    { value: "ned.w.1", label: "Dutch Vrouwen Eredivisie" },
    { value: "friendly.emirates_cup", label: "Emirates Cup" },
    { value: "eng.trophy", label: "English EFL Trophy" },
    { value: "eng.fa_qual", label: "English FA Cup Qualifying" },
    { value: "eng.w.fa", label: "English Women's FA Cup" },
    { value: "eng.w.league_cup", label: "English Women's League Cup" },
    { value: "eng.w.promotion.relegation", label: "English Women's Super League Promotion/Relegation Playoff" },
    { value: "fifa.intercontinental_cup", label: "FIFA Intercontinental Cup" },
    { value: "fifa.wworld.u17", label: "FIFA Under-17 Women's World Cup" },
    { value: "fifa.world.u17", label: "FIFA Under-17 World Cup" },
    { value: "fifa.world.u20", label: "FIFA Under-20 World Cup" },
    { value: "fifa.w.champions_cup", label: "FIFA Women's Champions Cup" },
    { value: "fifa.wwcq.ply", label: "FIFA Women's World Cup Qualifying - Playoff Tournament" },
    { value: "fifa.wworldq.uefa", label: "FIFA Women's World Cup Qualifying - UEFA" },
    { value: "fifa.worldq.afc", label: "FIFA World Cup Qualifying - AFC" },
    { value: "fifa.worldq.caf", label: "FIFA World Cup Qualifying - CAF" },
    { value: "fifa.worldq.conmebol", label: "FIFA World Cup Qualifying - CONMEBOL" },
    { value: "fifa.worldq.concacaf", label: "FIFA World Cup Qualifying - Concacaf" },
    { value: "fifa.worldq.ofc", label: "FIFA World Cup Qualifying - OFC" },
    { value: "fifa.wcq.ply", label: "FIFA World Cup Qualifying - Playoff Tournament" },
    { value: "fifa.worldq.uefa", label: "FIFA World Cup Qualifying - UEFA" },
    { value: "fra.1.promotion.relegation", label: "French Ligue 1 Promotion/Relegation Playoffs" },
    { value: "ger.2.promotion.relegation", label: "German Bundesliga 2. Promotion/Relegation Playoffs" },
    { value: "ger.playoff.relegation", label: "German Bundesliga Promotion/Relegation Playoff" },
    { value: "gua.1", label: "Guatemalan Liga Nacional" },
    { value: "hon.1", label: "Honduran Liga Nacional" },
    { value: "fifa.intercontinental.cup", label: "Intercontinental Cup (India)" },
    { value: "jpn.world_challenge", label: "Japanese J.League World Challenge" },
    { value: "fifa.concacaf.olympicsq", label: "Men's Olympic Qualifying Playoff" },
    { value: "mex.campeon", label: "Mexican Campeon de Campeones" },
    { value: "usa.ncaa.m.1", label: "NCAA Men's Soccer" },
    { value: "usa.ncaa.w.1", label: "NCAA Women's Soccer" },
    { value: "usa.nwsl.cup", label: "NWSL Challenge Cup" },
    { value: "can.w.nsl", label: "Northern Super League" },
    { value: "nor.1.promotion.relegation", label: "Norwegian Eliteserien Promotion/Relegation Playoffs" },
    { value: "par.1.supercopa", label: "Paraguayan Supercopa" },
    { value: "global.pinatar_cup", label: "Pinatar Cup" },
    { value: "por.1.promotion.relegation", label: "Portuguese Primeira Liga Promotion/Relegation Playoffs" },
    { value: "rus.1.promotion.relegation", label: "Russian Premier League Relegation/Promotion Playoffs" },
    { value: "afc.saff.championship", label: "SAFF Championship" },
    { value: "slv.1", label: "Salvadoran Primera Division" },
    { value: "sco.2.promotion.relegation", label: "Scottish Championship Promotion/Relegation Playoffs" },
    { value: "sco.tennents_qual", label: "Scottish Cup Qualifying" },
    { value: "sco.challenge", label: "Scottish League Challenge Cup" },
    { value: "sco.1.promotion.relegation", label: "Scottish Premiership Promotion/Relegation Playoffs" },
    { value: "fifa.shebelieves", label: "SheBelieves Cup" },
    { value: "esp.copa_de_la_reina", label: "Spanish Copa de la Reina" },
    { value: "swe.1.promotion.relegation", label: "Swedish Allsvenskan Promotion/Relegation Playoffs" },
    { value: "esp.joan_gamper", label: "Trofeo Joan Gamper" },
    { value: "uefa.champions_qual", label: "UEFA Champions League Qualifying" },
    { value: "uefa.europa.conf_qual", label: "UEFA Conference League Qualifying" },
    { value: "uefa.europa_qual", label: "UEFA Europa League Qualifying" },
    { value: "uefa.euroq", label: "UEFA European Championship Qualifying" },
    { value: "uefa.euro.u19", label: "UEFA European Under-19 Championship" },
    { value: "uefa.euro_u21", label: "UEFA European Under-21 Championship" },
    { value: "uefa.euro_u21_qual", label: "UEFA European Under-21 Championship Qualifying" },
    { value: "uefa.wchampions_qual", label: "UEFA Women's Champions League Qualifying" },
    { value: "uefa.w.europa", label: "UEFA Women's Europa Cup" },
    { value: "usa.usl.l1.cup", label: "USL Cup" },
    { value: "fifa.friendly_u21", label: "Under-21 International Friendly" },
    { value: "caf.w.nations", label: "Women's Africa Cup of Nations" }
  ]

  readonly property var leagueLogoMap: ({
    "eng.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/23.png",
    "esp.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/15.png",
    "ita.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/12.png",
    "ger.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/10.png",
    "fra.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/9.png",
    "ned.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/11.png",
    "por.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/14.png",
    "ksa.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2488.png",
    "usa.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/19.png",
    "mex.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/22.png",
    "bra.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/85.png",
    "arg.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1.png",
    "sco.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/45.png",
    "bel.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/6.png",
    "tur.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/18.png",
    "aut.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/5.png",
    "gre.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/98.png",
    "den.1": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "swe.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/16.png",
    "nor.1": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "rus.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/106.png",
    "jpn.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2199.png",
    "chn.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2350.png",
    "ind.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2334.png",
    "aus.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1308.png",
    "col.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1543.png",
    "chi.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/86.png",
    "per.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1813.png",
    "ecu.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1944.png",
    "uru.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1592.png",
    "par.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1892.png",
    "bol.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1949.png",
    "ven.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1947.png",
    "crc.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2245.png",
    "rsa.1": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "eng.2": "https://a.espncdn.com/i/leaguelogos/soccer/500/24.png",
    "eng.3": "https://a.espncdn.com/i/leaguelogos/soccer/500/25.png",
    "eng.4": "https://a.espncdn.com/i/leaguelogos/soccer/500/26.png",
    "eng.5": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "esp.2": "http://a.espncdn.com/i/leaguelogos/soccer/500/107.png",
    "ger.2": "https://a.espncdn.com/i/leaguelogos/soccer/500/97.png",
    "ita.2": "http://a.espncdn.com/i/leaguelogos/soccer/500/99.png",
    "fra.2": "http://a.espncdn.com/i/leaguelogos/soccer/500/96.png",
    "ned.2": "https://a.espncdn.com/i/leaguelogos/soccer/500/105.png",
    "sco.2": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "usa.usl.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2292.png",
    "usa.usl.l1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2452.png",
    "mex.2": "https://a.espncdn.com/i/leaguelogos/soccer/500/2306.png",
    "bra.2": "https://a.espncdn.com/i/leaguelogos/soccer/500/2299.png",
    "arg.2": "https://a.espncdn.com/i/leaguelogos/soccer/500/2294.png",
    "arg.3": "https://a.espncdn.com/i/leaguelogos/soccer/500/2308.png",
    "usa.nwsl": "https://a.espncdn.com/i/leaguelogos/soccer/500/2323.png",
    "eng.w.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2314.png",
    "esp.w.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/15.png",
    "fra.w.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/9.png",
    "aus.w.1": "http://a.espncdn.com/i/leaguelogos/soccer/500/2402.png",
    "uefa.wchampions": "https://a.espncdn.com/i/leaguelogos/soccer/500/2408.png",
    "concacaf.w.champions_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2298.png",
    "usa.w.usl.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2292.png",
    "uefa.champions": "https://a.espncdn.com/i/leaguelogos/soccer/500/2.png",
    "uefa.europa": "https://a.espncdn.com/i/leaguelogos/soccer/500/2310.png",
    "uefa.europa.conf": "https://a.espncdn.com/i/leaguelogos/soccer/500/20296.png",
    "uefa.super_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/1272.png",
    "conmebol.libertadores": "https://a.espncdn.com/i/leaguelogos/soccer/500/58.png",
    "conmebol.sudamericana": "https://a.espncdn.com/i/leaguelogos/soccer/500/1208.png",
    "conmebol.recopa": "https://a.espncdn.com/i/leaguelogos/soccer/500/2335.png",
    "concacaf.champions": "https://a.espncdn.com/i/leaguelogos/soccer/500/2298.png",
    "concacaf.leagues.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2410.png",
    "afc.champions": "https://a.espncdn.com/i/leaguelogos/soccer/500/2200.png",
    "afc.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2243.png",
    "caf.champions": "https://a.espncdn.com/i/leaguelogos/soccer/500/2391.png",
    "caf.confed": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "fifa.cwc": "https://a.espncdn.com/i/leaguelogos/soccer/500/1932.png",
    "campeones.cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "eng.fa": "https://a.espncdn.com/i/leaguelogos/soccer/500/40.png",
    "eng.league_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/41.png",
    "eng.charity": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "esp.copa_del_rey": "https://a.espncdn.com/i/leaguelogos/soccer/500/80.png",
    "esp.super_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/431.png",
    "ita.coppa_italia": "https://a.espncdn.com/i/leaguelogos/soccer/500/2192.png",
    "ita.super_cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "ger.dfb_pokal": "https://a.espncdn.com/i/leaguelogos/soccer/500/2061.png",
    "ger.super_cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "fra.coupe_de_france": "https://a.espncdn.com/i/leaguelogos/soccer/500/182.png",
    "fra.super_cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "usa.open": "https://a.espncdn.com/i/leaguelogos/soccer/500/69.png",
    "por.taca.portugal": "https://a.espncdn.com/i/leaguelogos/soccer/500/14.png",
    "ned.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2196.png",
    "sco.tennents": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "sco.cis": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "ksa.kings.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2488.png",
    "bra.copa_do_brazil": "https://a.espncdn.com/i/leaguelogos/soccer/500/528.png",
    "bra.supercopa_do_brazil": "https://a.espncdn.com/i/leaguelogos/soccer/500/85.png",
    "arg.copa": "https://a.espncdn.com/i/leaguelogos/soccer/500/2320.png",
    "arg.supercopa": "https://a.espncdn.com/i/leaguelogos/soccer/500/2343.png",
    "col.copa": "https://a.espncdn.com/i/leaguelogos/soccer/500/2332.png",
    "fifa.world": "https://a.espncdn.com/i/leaguelogos/soccer/500/4.png",
    "fifa.wwc": "https://a.espncdn.com/i/leaguelogos/soccer/500/60.png",
    "uefa.euro": "https://a.espncdn.com/i/leaguelogos/soccer/500/74.png",
    "uefa.weuro": "https://a.espncdn.com/i/leaguelogos/soccer/500/2381.png",
    "uefa.nations": "https://a.espncdn.com/i/leaguelogos/soccer/500/2395.png",
    "uefa.w.nations": "https://a.espncdn.com/i/leaguelogos/soccer/500/2395.png",
    "conmebol.america": "https://a.espncdn.com/i/leaguelogos/soccer/500/83.png",
    "conmebol.america.femenina": "https://a.espncdn.com/i/leaguelogos/soccer/500/83.png",
    "concacaf.gold": "https://a.espncdn.com/i/leaguelogos/soccer/500/59.png",
    "concacaf.w.gold": "https://a.espncdn.com/i/leaguelogos/soccer/500/59.png",
    "concacaf.nations.league": "https://a.espncdn.com/i/leaguelogos/soccer/500/2406.png",
    "caf.nations": "https://a.espncdn.com/i/leaguelogos/soccer/500/76.png",
    "afc.asian.cup": "https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/2243.png",
    "fifa.olympics": "https://a.espncdn.com/i/leaguelogos/soccer/500/71.png",
    "fifa.w.olympics": "https://a.espncdn.com/i/leaguelogos/soccer/500/84.png",
    "fifa.friendly": "https://a.espncdn.com/i/leaguelogos/soccer/500/53.png",
    "fifa.friendly.w": "https://a.espncdn.com/i/leaguelogos/soccer/500/70.png",
    "club.friendly": "https://a.espncdn.com/i/leaguelogos/soccer/500/53.png",
    "afc.cupq": "http://a.espncdn.com/i/leaguelogos/soccer/500/2246.png",
    "afc.champions_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/2200.png",
    "afc.cup_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/2243.png",
    "afc.w.asian.cup": "https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/2243.png",
    "aff.championship": "https://a.espncdn.com/i/leaguelogos/soccer/500/2261.png",
    "caf.nations_qual": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "caf.championship": "https://a.espncdn.com/i/leaguelogos/soccer/500/76.png",
    "global.gulf_cup": "https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/2243.png",
    "arg.copa_de_la_superliga": "https://a.espncdn.com/i/leaguelogos/soccer/500/2407.png",
    "arg.supercopa.internacional": "https://a.espncdn.com/i/leaguelogos/soccer/500/1.png",
    "arg.trofeo_de_la_campeones": "https://a.espncdn.com/i/leaguelogos/soccer/500/1.png",
    "global.arnold.clark_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2314.png",
    "bel.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/6.png",
    "bol.ply.rel": "https://a.espncdn.com/i/leaguelogos/soccer/500/1949.png",
    "bra.camp.carioca": "https://a.espncdn.com/i/leaguelogos/soccer/500/2265.png",
    "bra.camp.gaucho": "https://a.espncdn.com/i/leaguelogos/soccer/500/2272.png",
    "bra.camp.mineiro": "https://a.espncdn.com/i/leaguelogos/soccer/500/2360.png",
    "bra.camp.paulista": "https://a.espncdn.com/i/leaguelogos/soccer/500/2322.png",
    "concacaf.champions_cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "concacaf.u23": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "fifa.conmebol.olympicsq": "https://a.espncdn.com/i/leaguelogos/soccer/500/19727.png",
    "global.club_challenge": "https://a.espncdn.com/i/leaguelogos/soccer/500/2310.png",
    "global.finalissima": "https://a.espncdn.com/i/leaguelogos/soccer/500/74.png",
    "global.u20.intercontinental_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/58.png",
    "global.w.finalissima": "https://a.espncdn.com/i/leaguelogos/soccer/500/2381.png",
    "caf.cosafa": "https://a.espncdn.com/i/leaguelogos/soccer/500/76.png",
    "chi.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/86.png",
    "chi.super_cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "chn.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/2350.png",
    "col.superliga": "https://a.espncdn.com/i/leaguelogos/soccer/500-dark/2405.png",
    "concacaf.central.american.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2298.png",
    "concacaf.confederations_playoff": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "concacaf.gold_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/59.png",
    "concacaf.womens.championship": "https://a.espncdn.com/i/leaguelogos/soccer/500/18969.png",
    "fifa.w.concacaf.olympicsq": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "bol.copa": "https://a.espncdn.com/i/leaguelogos/soccer/500/1949.png",
    "chi.copa_chi": "http://a.espncdn.com/i/leaguelogos/soccer/500/2331.png",
    "ned.playoff.relegation": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "ned.supercup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "ned.w.knvb_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2196.png",
    "ned.3.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/11.png",
    "ned.w.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2453.png",
    "friendly.emirates_cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "eng.trophy": "https://a.espncdn.com/i/leaguelogos/soccer/500/42.png",
    "eng.fa_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/40.png",
    "eng.w.fa": "https://a.espncdn.com/i/leaguelogos/soccer/500/40.png",
    "eng.w.league_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/41.png",
    "eng.w.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/2314.png",
    "fifa.intercontinental_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/1932.png",
    "fifa.wworld.u17": "https://a.espncdn.com/i/leaguelogos/soccer/500/60.png",
    "fifa.world.u17": "https://a.espncdn.com/i/leaguelogos/soccer/500/2288.png",
    "fifa.world.u20": "https://a.espncdn.com/i/leaguelogos/soccer/500/2285.png",
    "fifa.w.champions_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/60.png",
    "fifa.wwcq.ply": "https://a.espncdn.com/i/leaguelogos/soccer/500/60.png",
    "fifa.wworldq.uefa": "https://a.espncdn.com/i/leaguelogos/soccer/500/60.png",
    "fifa.worldq.afc": "https://a.espncdn.com/i/leaguelogos/soccer/500/62.png",
    "fifa.worldq.caf": "https://a.espncdn.com/i/leaguelogos/soccer/500/63.png",
    "fifa.worldq.conmebol": "https://a.espncdn.com/i/leaguelogos/soccer/500/65.png",
    "fifa.worldq.concacaf": "https://a.espncdn.com/i/leaguelogos/soccer/500/64.png",
    "fifa.worldq.ofc": "https://a.espncdn.com/i/leaguelogos/soccer/500/66.png",
    "fifa.wcq.ply": "https://a.espncdn.com/i/leaguelogos/soccer/500/4.png",
    "fifa.worldq.uefa": "https://a.espncdn.com/i/leaguelogos/soccer/500/67.png",
    "fra.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/9.png",
    "ger.2.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/97.png",
    "ger.playoff.relegation": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "gua.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2248.png",
    "hon.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2247.png",
    "fifa.intercontinental.cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "jpn.world_challenge": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "fifa.concacaf.olympicsq": "https://a.espncdn.com/i/leaguelogos/soccer/500/71.png",
    "mex.campeon": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "usa.ncaa.m.1": "https://a.espncdn.com/combiner/i?img=/redesign/assets/img/icons/sports-soccer-solid.png",
    "usa.ncaa.w.1": "https://a.espncdn.com/combiner/i?img=/redesign/assets/img/icons/sports-soccer-solid.png",
    "usa.nwsl.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2445.png",
    "can.w.nsl": "https://a.espncdn.com/i/leaguelogos/soccer/500/2323.png",
    "nor.1.promotion.relegation": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "par.1.supercopa": "https://a.espncdn.com/i/leaguelogos/soccer/500/1892.png",
    "global.pinatar_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/15.png",
    "por.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/14.png",
    "rus.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/106.png",
    "afc.saff.championship": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "slv.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2244.png",
    "sco.2.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/45.png",
    "sco.tennents_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/45.png",
    "sco.challenge": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "sco.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/45.png",
    "fifa.shebelieves": "https://a.espncdn.com/i/leaguelogos/soccer/500/60.png",
    "esp.copa_de_la_reina": "https://a.espncdn.com/i/leaguelogos/soccer/500/80.png",
    "swe.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/16.png",
    "esp.joan_gamper": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "uefa.champions_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/2.png",
    "uefa.europa.conf_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/20296.png",
    "uefa.europa_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/2310.png",
    "uefa.euroq": "https://a.espncdn.com/i/leaguelogos/soccer/500/56.png",
    "uefa.euro.u19": "http://a.espncdn.com/i/leaguelogos/soccer/500/2297.png",
    "uefa.euro_u21": "http://a.espncdn.com/i/leaguelogos/soccer/500/2284.png",
    "uefa.euro_u21_qual": "http://a.espncdn.com/i/leaguelogos/soccer/500/2284.png",
    "uefa.wchampions_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/2408.png",
    "uefa.w.europa": "https://a.espncdn.com/i/leaguelogos/soccer/500/2310.png",
    "usa.usl.l1.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2452.png",
    "fifa.friendly_u21": "https://a.espncdn.com/i/leaguelogos/soccer/500/53.png",
    "caf.w.nations": "https://a.espncdn.com/i/leaguelogos/soccer/500/76.png",
  })
  property string selectedLeague: ""
  property string selectedLeagueName: ""
  property var selectedTeam: null
  // Reopens the first-run picker after setup so the favorite team can change.
  property bool editingTeam: false
  // Picker-local: when true, Confirm saves a league-follow instead of a club.
  property bool pickerLeagueOnly: false
  // Picker-local: when true, Confirm adds the picked club to followedTeams
  // and switches to it, instead of replacing the single active club.
  property bool addingTeam: false

  function open() {
    // Always start on the fixtures view; standings, stats and league matches are
    // toggles.
    root.showStandings = false
    root.showStats = false
    root.showClubFixtures = false
    root.leagueBrowseAll = false
    root.showMatches = root.leagueMode
    root.matchWindowOffset = 0
    root.pendingEdge = ""
    root.navAnchorDay = ""
    if (root.matchClusters && root.matchClusters.length > 0) {
      root.matchClusterIndex = root.currentMatchWeekIndex(root.matchClusters)
    }
    if (root.leagueMode) root.loadMatchList()
    root.controller.show()
    // Cached fixtures are shown instantly; only refetch when they are stale
    // or nothing has been fetched yet. The refresh never clears what is on
    // screen, so the UI is never blocked while it runs.
    if (!root.fixtureFresh()) root.refresh()
  }

  function close() {
    root.resetMatchWeekNav()
    root.controller.hide()
  }

  // Closing always returns the League Matches view to the live round: the
  // next open refetches the standard window and lands on today's matchweek.
  function resetMatchWeekNav() {
    root.showClubFixtures = false
    root.leagueBrowseAll = false
    root.matchWindowOffset = 0
    root.pendingEdge = ""
    root.navAnchorDay = ""
    if (root.matchClusters && root.matchClusters.length > 0) {
      root.matchClusterIndex = root.currentMatchWeekIndex(root.matchClusters)
    }
    root.standingsSeasonOffset = 0
    root.statsSeasonOffset = 0
    root.showStats = false
    root.showMatchDetail = false
  }
  function toggle() { if (root.opened) root.close(); else root.open() }

  // Fixture data is considered fresh until its TTL expires: 10 minutes when a
  // fixture involving the team falls on today, 30 minutes otherwise.
  function fixtureTtl() {
    if (root.liveMatch) return 15 * 1000
    var today = Qt.formatDate(new Date(), "yyyyMMdd")
    var candidates = [root.nextMatch, root.previousMatch]
    for (var i = 0; i < candidates.length; i++) {
      var ev = candidates[i]
      if (ev && Qt.formatDate(new Date(ev.date), "yyyyMMdd") === today) return 10 * 60 * 1000
    }
    return 30 * 60 * 1000
  }

  function fixtureFresh() {
    return new Date().getTime() - root.lastRefresh <= root.fixtureTtl()
  }

  // Team the displayed fixtures belong to. Changing clubs invalidates the
  // cached competition list and freshness clock so the next fetch targets
  // the new team instead of reusing the previous one's slugs.
  property string _fixtureTeamKey: ""
  function fixtureTeamKey() {
    return String(root.resolvedTeamId !== "" ? root.resolvedTeamId : root.teamId) + "|" + String(root.teamName)
  }

  function resetTeamData() {
    root.competitionSlugs = []
    root.competitionRefresh = 0
    root.leagueInfo = {}
    root.lastRefresh = 0
    root.nextMatch = null
    root.previousMatch = null
    root.liveMatch = null
    root.liveEvents = []
    root.collectedEvents = []
    root.requestError = ""
  }

  // In-memory only (never written to the favorite file) cache of each
  // followed club's already-fetched dashboard state, keyed by teamKey().
  // Switching clubs used to reset*() + refetch from zero every single
  // time, even switching straight back to a club you were looking at
  // seconds ago -- this is what let switchActiveTeam() skip that for a
  // club already in here. Session-only by design: a stale-for-days cache
  // surviving a restart would be worse than just refetching once on
  // startup, so this intentionally starts empty every launch.
  property var _teamStateCache: ({})

  function snapshotTeamState() {
    return {
      competitionSlugs: root.competitionSlugs,
      competitionRefresh: root.competitionRefresh,
      leagueInfo: root.leagueInfo,
      lastRefresh: root.lastRefresh,
      nextMatch: root.nextMatch,
      previousMatch: root.previousMatch,
      liveMatch: root.liveMatch,
      liveEvents: root.liveEvents,
      collectedEvents: root.collectedEvents
    }
  }

  // Restores exactly the fields resetTeamData() clears -- deliberately not
  // the resetMatchList()/standings/stats fields (the fixtures-browser and
  // standings/stats sub-views): those are opt-in views nobody sees on a
  // plain tab switch, so caching them would add complexity for state the
  // dashboard's default view never renders. A club whose fixtures browser
  // you've already opened once just pays that specific sub-fetch again.
  function restoreTeamState(snap) {
    root.competitionSlugs = snap.competitionSlugs
    root.competitionRefresh = snap.competitionRefresh
    root.leagueInfo = snap.leagueInfo
    root.lastRefresh = snap.lastRefresh
    root.nextMatch = snap.nextMatch
    root.previousMatch = snap.previousMatch
    root.liveMatch = snap.liveMatch
    root.liveEvents = snap.liveEvents
    root.collectedEvents = snap.collectedEvents
    // Computed fresh rather than carried over from the snapshot: this is
    // what tells refresh() "the currently-live properties already belong
    // to this club" so it skips its own resetTeamData() and loading=true
    // -- deriving it here guarantees that match instead of trusting it
    // stayed valid since the snapshot was taken (resolvedTeamId in
    // particular could in principle have been re-resolved differently
    // meanwhile, e.g. by the picker's own team search).
    root._fixtureTeamKey = root.fixtureTeamKey()
  }

  // matchWeekRows/matchWeekLabel are deliberately not reset here: both are
  // `readonly` properties derived from activeMatchCluster (itself derived
  // from matchClusters/matchClusterIndex, both reset below), so they
  // recompute correctly on their own. Explicitly assigning to a readonly
  // property throws a TypeError -- previously the very first thing this
  // function did, on every single call. QML's error handling for that
  // varies by call context enough that it wasn't always visibly obvious,
  // but at least via a direct imperative call (confirmed while testing the
  // club-switch cache below, which calls this function) it aborted the
  // rest of resetMatchList() (and this function only ever had two callers,
  // both further up their own call chain -- see git history if the exact
  // blast radius of that ever needs re-deriving).
  function resetMatchList() {
    root.matchClusters = []
    root.matchClusterIndex = 0
    root.matchWindowOffset = 0
    root.leagueLive = []
    root.leagueRecent = []
    root.leagueUpcoming = []
    root.leagueBoardSummary = ""
    root.matchListError = ""
  }

  function refresh() {
    if (root.leagueMode) {
      root.loadMatchList()
      return
    }
    if (root.needsTeam) return
    // Never fetch (or run teams-resolution/persist) before the startup gate
    // has seen the team inputs settle, otherwise a reload's stale settings
    // injection would be fetched and re-persisted as the fallback.
    if (!root._started) { root.ensureStarted(); return }
    var key = root.fixtureTeamKey()
    if (key !== root._fixtureTeamKey) {
      root._fixtureTeamKey = key
      root.resetTeamData()
    }
    if (root.collectedEvents.length === 0) {
      root.loading = true
    }
    root.requestError = ""
    // Cancel in-flight requests to prevent stalls and start fresh
    fixtureRequest.running = false
    sbRequest1.running = false
    sbRequest2.running = false
    sbRequest3.running = false
    if (root.teamId === "" && root.resolvedTeamId === "") {
      fetchQueue = [{ kind: "teams" }]
    } else {
      root.buildFetchQueue()
    }
    root.startNextFetch()
  }

  // Orders the next round of requests: discover which competitions the team
  // plays in, then fetch each competition's scoreboard in parallel. League
  // names and logos come from each scoreboard's own `leagues` array, so no
  // separate league request is needed.
  function buildFetchQueue() {
    var stale = new Date().getTime() - root.competitionRefresh > 6 * 3600 * 1000
    if (root.competitionSlugs.length === 0 || stale) root.fetchQueue = [{ kind: "discover" }]
    else root.fetchQueue = []
  }

  function startNextFetch() {
    if (root.fetchQueue.length === 0) {
      root.startScoreboards()
      return
    }
    var next = root.fetchQueue.shift()
    root.fetchStage = next.kind
    var window = root.clubSeasonWindow()
    var team = root.safeIdentifier(root.resolvedTeamId !== "" ? root.resolvedTeamId : root.teamId)
    var leagueCode = root.safeIdentifier(root.league)
    if (next.kind === "teams") {
      if (leagueCode === "") { root.loading = false; return }
      fixtureRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
        "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(leagueCode) + "/teams"]
    } else if (next.kind === "discover") {
      if (team === "") { root.startScoreboards(); return }
      fixtureRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
        "https://sports.core.api.espn.com/v2/sports/soccer/teams/" + encodeURIComponent(team) + "/events?dates=" + encodeURIComponent(window) + "&limit=100"]
    }
    fixtureRequest.running = true
  }

  // Slugs waiting to be fetched by the parallel scoreboard pool.
  property var scoreboardQueue: []
  property var sbSlugs: ["", "", ""]

  function startScoreboards() {
    var slugs = root.competitionSlugs.slice()
    if (slugs.indexOf(root.league) === -1) slugs.unshift(root.league)
    root.scoreboardQueue = slugs
    root.kickScoreboards()
  }

  // Fills free scoreboard slots from the queue. Each Process finishes by
  // calling this again, so up to three requests run concurrently.
  function kickScoreboards() {
    while (root.scoreboardQueue.length > 0) {
      var assigned = false
      var procs = [sbRequest1, sbRequest2, sbRequest3]
      for (var i = 0; i < procs.length; i++) {
        if (!procs[i].running) {
          var rawSlug = root.scoreboardQueue.shift()
          var slug = root.safeIdentifier(rawSlug)
          if (slug === "") continue
          root.sbSlugs[i] = slug
          var window = root.clubSeasonWindow()
          procs[i].command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "5242880",
            "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(slug) + "/scoreboard?dates=" + encodeURIComponent(window) + "&limit=500"]
          procs[i].running = true
          assigned = true
          break
        }
      }
      if (!assigned) break
    }
    root.maybeFinishScoreboards()
  }

  function handleScoreboard(index, text) {
    var slug = root.sbSlugs[index]
    if (typeof text !== "string" || text.length === 0 || text.length > 5242880) {
      if (typeof text === "string" && text.length > 5242880) {
        console.warn("futbar", "scoreboard response exceeded byte limit for " + slug)
      }
      root.sbSlugs[index] = ""
      root.kickScoreboards()
      return
    }
    try {
      var data = JSON.parse(text)
      var leagues = Array.isArray(data.leagues) ? data.leagues : []
      if (leagues.length > 0 && slug !== "") {
        var info = {}
        info.name = root.sanitizePlainText(String(leagues[0].name || leagues[0].abbreviation || slug))
        info.logo = root.sanitizeImageUrl(leagues[0].logos && leagues[0].logos.length ? String(leagues[0].logos[0].href || "") : "")
        var map = Object.assign({}, root.leagueInfo)
        map[slug] = info
        root.leagueInfo = map
      }
      var merged = root.collectedEvents.slice()
      var events = Array.isArray(data.events) ? data.events : []
      for (var e = 0; e < events.length; e++) {
        if (!root.eventMatchesTeam(events[e])) continue
        if (events[e].competitionSlug === undefined) events[e].competitionSlug = slug
        var existingIndex = -1
        for (var k = 0; k < merged.length; k++) {
          if (String(merged[k].id) === String(events[e].id)) {
            existingIndex = k
            break
          }
        }
        if (existingIndex !== -1) {
          merged[existingIndex] = events[e]
        } else {
          merged.push(events[e])
        }
      }
      root.collectedEvents = merged
    } catch (error) {
      console.warn("futbar", "scoreboard: " + error)
    }
    root.sbSlugs[index] = ""
    root.kickScoreboards()
  }

  function maybeFinishScoreboards() {
    if (root.scoreboardQueue.length > 0) return
    var procs = [sbRequest1, sbRequest2, sbRequest3]
    for (var i = 0; i < procs.length; i++) {
      if (procs[i].running) return
    }
    root.finishFetch()
  }

  function finishFetch() {
    root.setFixtures({ events: root.collectedEvents })
    if (root.clubFixturePage === 0 && root.teamFixtureRows.length > 0) {
      root.initClubFixturePage()
    }
  }

  // A team plays in many competitions (league, cup, continental, friendly), so
  // the club identity is the reliable filter. Name matching is only a fallback
  // until the id has been resolved.
  function eventMatchesTeam(event) {
    var competitors = event && event.competitions && event.competitions[0] && event.competitions[0].competitors
    if (!Array.isArray(competitors)) return false
    var wantedId = root.resolvedTeamId !== "" ? root.resolvedTeamId : root.teamId
    if (wantedId !== "") {
      return competitors.some(function(competitor) {
        return String(competitor.team && competitor.team.id || "") === String(wantedId)
      })
    }
    var wanted = root.teamName.toLowerCase()
    return competitors.some(function(competitor) {
      var team = competitor.team || {}
      return [team.displayName, team.shortDisplayName, team.name, team.abbreviation].some(function(name) {
        return String(name || "").toLowerCase().indexOf(wanted) !== -1
      })
    })
  }

  function competitionInfo(slug) {
    if (!slug) return null
    return root.leagueInfo[slug] || null
  }

  function competitionNameFor(event) {
    var slug = event ? String(event.competitionSlug || "") : ""
    var info = root.competitionInfo(slug)
    if (info && info.name) return root.sanitizePlainText(String(info.name))
    for (var i = 0; i < root.leagues.length; i++) {
      if (root.leagues[i].value === slug) return String(root.leagues[i].label)
    }
    if (slug === "" || slug === root.league) return root.leagueLabel()
    return root.safeIdentifier(slug)
  }

  function competitionLogoFor(event) {
    if (!event) return ""
    if (event.competitionLogo) {
      var directLogo = root.sanitizeImageUrl(String(event.competitionLogo))
      if (directLogo !== "") return directLogo
    }
    var slug = event ? String(event.competitionSlug || "") : ""
    if (slug !== "") {
      var info = root.competitionInfo(slug)
      if (info && info.logo) {
        var infoLogo = root.sanitizeImageUrl(String(info.logo))
        if (infoLogo !== "") return infoLogo
      }
      if (root.leagueLogoMap && root.leagueLogoMap[slug]) {
        var mapLogo = root.sanitizeImageUrl(String(root.leagueLogoMap[slug]))
        if (mapLogo !== "") return mapLogo
      }
    }
    return root.leagueLogoUrl()
  }

  function setFixtures(data) {
    var events = Array.isArray(data.events) ? data.events : []
    var now = new Date().getTime()
    // ESPN occasionally omits or delays the `pre` state. A dated future
    // fixture is still the next match, so do not hide its teams in that case.
    var upcoming = events.filter(function(event) {
      return new Date(event.date).getTime() >= now
    })
    var completed = events.filter(function(event) {
      return event.status && event.status.type.state === "post"
    })
    upcoming.sort(function(a, b) { return new Date(a.date) - new Date(b.date) })
    completed.sort(function(a, b) { return new Date(b.date) - new Date(a.date) })
    nextMatch = upcoming.length ? upcoming[0] : null
    previousMatch = completed.length ? completed[0] : null

    var inPlay = events.filter(function(event) {
      return event.status && event.status.type && event.status.type.state === "in"
    })
    liveMatch = inPlay.length ? inPlay[0] : null
    root.loadLiveSummary()

    var ref = nextMatch || previousMatch
    tournamentName = ref ? root.competitionNameFor(ref) : root.leagueLabel()
    tournamentLogo = ref ? root.competitionLogoFor(ref) : ""
    root.lastRefresh = new Date().getTime()
    loading = false
  }

  function competitor(event, side) {
    var entries = event && event.competitions && event.competitions[0] && event.competitions[0].competitors
    if (!Array.isArray(entries)) return null
    return entries.find(function(item) { return item.homeAway === side }) || null
  }

  function teamNameFor(event, side) {
    if (!event) return "—"
    if (side === "home" && event.homeName) return root.sanitizePlainText(String(event.homeName))
    if (side === "away" && event.awayName) return root.sanitizePlainText(String(event.awayName))
    if (side === "home" && event.home && (event.home.name || event.home.displayName)) {
      return root.sanitizePlainText(String(event.home.name || event.home.displayName))
    }
    if (side === "away" && event.away && (event.away.name || event.away.displayName)) {
      return root.sanitizePlainText(String(event.away.name || event.away.displayName))
    }
    var item = competitor(event, side)
    var raw = item && item.team ? String(item.team.shortDisplayName || item.team.displayName || item.team.name || "—") : "—"
    return root.sanitizePlainText(raw)
  }

  function teamLogoFor(event, side) {
    if (!event) return ""
    if (side === "home" && event.homeLogo) return root.sanitizeImageUrl(String(event.homeLogo))
    if (side === "away" && event.awayLogo) return root.sanitizeImageUrl(String(event.awayLogo))
    if (side === "home" && event.home && event.home.logo) return root.sanitizeImageUrl(String(event.home.logo))
    if (side === "away" && event.away && event.away.logo) return root.sanitizeImageUrl(String(event.away.logo))

    var item = competitor(event, side)
    var t = item ? (item.team || item || {}) : {}
    if (!item) {
      if (side === "home" && event.homeTeam) t = event.homeTeam
      else if (side === "away" && event.awayTeam) t = event.awayTeam
      else if (side === "home" && event.home) t = event.home
      else if (side === "away" && event.away) t = event.away
    }
    var l = String(t.logo || (item && item.team && item.team.logo) || "")
    if (l === "" && Array.isArray(t.logos) && t.logos.length > 0) {
      l = String(t.logos[0].href || t.logos[0] || "")
    }
    if (l === "" && item && item.team && Array.isArray(item.team.logos) && item.team.logos.length > 0) {
      l = String(item.team.logos[0].href || item.team.logos[0] || "")
    }
    if (l === "" && (t.id || (item && item.team && item.team.id))) {
      var rawId = String(t.id || (item && item.team && item.team.id) || "")
      var safeId = root.safeIdentifier(rawId)
      if (safeId !== "") l = "https://a.espncdn.com/i/teamlogos/soccer/500/" + safeId + ".png"
    }
    if (l === "" && (t.displayName || t.name)) {
      var rawName = String(t.displayName || t.name || "").toLowerCase()
      if (Array.isArray(root.teams)) {
        for (var m = 0; m < root.teams.length; m++) {
          if (root.teams[m] && String(root.teams[m].label || root.teams[m].value || "").toLowerCase() === rawName) {
            if (root.teams[m].logo) { l = String(root.teams[m].logo); break }
            if (root.teams[m].id) { l = "https://a.espncdn.com/i/teamlogos/soccer/500/" + root.safeIdentifier(String(root.teams[m].id)) + ".png"; break }
          }
        }
      }
    }
    return root.sanitizeImageUrl(l)
  }

  function scoreFor(event, side) {
    if (!event) return "—"
    if (side === "home" && event.homeScore !== undefined && event.homeScore !== "") return root.sanitizePlainText(String(event.homeScore))
    if (side === "away" && event.awayScore !== undefined && event.awayScore !== "") return root.sanitizePlainText(String(event.awayScore))
    if (side === "home" && event.home && event.home.score !== undefined && event.home.score !== "") return root.sanitizePlainText(String(event.home.score))
    if (side === "away" && event.away && event.away.score !== undefined && event.away.score !== "") return root.sanitizePlainText(String(event.away.score))
    var item = competitor(event, side)
    var raw = item ? String(item.score !== undefined ? item.score : "0") : "—"
    return root.sanitizePlainText(raw)
  }

  function kickoffDay(event) {
    return event ? root.sanitizePlainText(Qt.formatDate(new Date(event.date), "ddd d MMM")) : ""
  }

  function kickoffTime(event) {
    return event ? root.sanitizePlainText(Qt.formatTime(new Date(event.date), "HH:mm")) : ""
  }

  function shootoutSummaryFor(event) {
    if (!event) return ""
    var comp = (event.competitions && event.competitions[0]) || event
    if (comp.shootout) {
      var sH = comp.shootout.homeScore !== undefined ? String(comp.shootout.homeScore) : ""
      var sA = comp.shootout.awayScore !== undefined ? String(comp.shootout.awayScore) : ""
      if (sH !== "" && sA !== "") return sH + "–" + sA + " Pens"
    }
    var hComp = root.competitor(event, "home")
    var aComp = root.competitor(event, "away")
    if (hComp && aComp) {
      var shH = hComp.shootoutScore !== undefined ? String(hComp.shootoutScore) : ""
      var shA = aComp.shootoutScore !== undefined ? String(aComp.shootoutScore) : ""
      if (shH !== "" && shA !== "") return shH + "–" + shA + " Pens"
    }
    return ""
  }

  function statusFor(event) {
    if (!event) return ""
    var status = event.status || (event.competitions && event.competitions[0] && event.competitions[0].status)
    if (!status) return ""
    if (status.type && status.type.state === "pre") {
      var kTime = root.kickoffTime(event)
      return kTime !== "" ? kTime : "Scheduled"
    }
    if (status.displayClock) {
      var clk = String(status.displayClock).trim()
      if (clk !== "" && clk !== "0'") {
        if (status.type && (status.type.shortDetail === "HT" || status.type.detail === "Halftime" || status.type.detail === "Half Time")) {
          return "HT"
        }
        return root.sanitizePlainText(clk)
      }
    }
    var raw = status.type ? String(status.type.shortDetail || status.type.detail || "Full time") : "Full time"
    if (/\d{1,2}\/\d{1,2}\s*-\s*\d{1,2}:\d{2}/.test(raw)) {
      var kTime2 = root.kickoffTime(event)
      raw = kTime2 !== "" ? kTime2 : "Scheduled"
    }
    var shoot = root.shootoutSummaryFor(event)
    if (shoot !== "" && raw.indexOf("Pen") === -1 && raw.indexOf("pen") === -1) {
      return root.sanitizePlainText(raw + " (" + shoot + ")")
    }
    return root.sanitizePlainText(raw)
  }

  function h2hSummary(h2hList, homeName, awayName) {
    if (!Array.isArray(h2hList) || h2hList.length === 0) return ""
    var hW = 0
    var aW = 0
    var d = 0
    for (var i = 0; i < h2hList.length; i++) {
      var item = h2hList[i]
      var hs = parseInt(item.homeScore, 10)
      var as_ = parseInt(item.awayScore, 10)
      if (!isNaN(hs) && !isNaN(as_)) {
        if (hs === as_) {
          d++
        } else if (hs > as_) {
          if (item.home === homeName) hW++
          else aW++
        } else {
          if (item.away === homeName) hW++
          else aW++
        }
      }
    }
    var parts = []
    if (homeName) parts.push(homeName + " " + hW + "W")
    if (d > 0) parts.push(d + "D")
    if (awayName) parts.push(awayName + " " + aW + "W")
    return root.sanitizePlainText(parts.join(" · "))
  }

  // Fetches the live match's play-by-play so scorers and red cards can be shown
  // with their minutes. The summary lives under the match's own competition,
  // not necessarily the team's home league. Existing scorers are kept until the
  // new list arrives so the card does not flicker empty on every refresh.
  function loadLiveSummary() {
    if (!root.liveMatch) {
      root.liveEvents = []
      root.summaryMatchId = ""
      return
    }
    var id = root.safeIdentifier(String(root.liveMatch.id))
    if (id === "") return
    if (root.summaryMatchId !== id) {
      root.liveEvents = []
      root.summaryMatchId = id
    }
    if (panelSummaryRequest.running) return
    var slug = root.safeIdentifier(String(root.liveMatch.competitionSlug || root.league))
    if (slug === "") return
    panelSummaryRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(slug) + "/summary?event=" + encodeURIComponent(id)]
    panelSummaryRequest.running = true
  }

  // Fetches the league standings table for the selected league. ESPN's site
  // API has no standings children for soccer; the web API does.
  function loadStandings(force) {
    if (root.needsTeam) return
    var leagueCode = root.safeIdentifier(root.league)
    if (leagueCode === "") return
    var key = leagueCode + "|" + String(root.standingsSeasonOffset)
    var now = Date.now()
    if (!force && key === root._lastStandingsKey && root.standings.length > 0 && (now - root.lastStandingsRefresh < 15 * 60 * 1000)) {
      return
    }
    standingsRequest.running = false
    standingsLoading = true
    standingsError = ""
    var season = root.standingsSeasonYear - root.standingsSeasonOffset
    standingsRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
      "https://site.web.api.espn.com/apis/v2/sports/soccer/" + encodeURIComponent(leagueCode)
      + "/standings?season=" + encodeURIComponent(String(season))]
    standingsRequest.running = true
  }

  // Fetches player stats (goals and assists) and player card leaders (yellow and red cards).
  function loadStats(force) {
    if (root.needsTeam) return
    var leagueCode = root.safeIdentifier(root.league)
    if (leagueCode === "") return
    var key = leagueCode + "|" + String(root.statsSeasonOffset)
    var now = Date.now()
    if (!force && key === root._lastStatsKey && (root.statsGoals.length > 0 || root.statsYellow.length > 0) && (now - root.lastStatsRefresh < 15 * 60 * 1000)) {
      return
    }
    statsRequest.running = false
    root.statsLoading = true
    root.statsError = ""
    root.rawYellowLeaders = []
    root.rawRedLeaders = []
    root.statsYellow = []
    root.statsRed = []
    var targetYear = root.standingsSeasonYear - root.statsSeasonOffset
    var statsUrl = "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(leagueCode) + "/statistics"
    if (root.statsSeasonOffset > 0) {
      statsUrl += "?season=" + encodeURIComponent(String(targetYear))
    }
    statsRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152", statsUrl]
    statsRequest.running = true
  }

  function openMatchDetail(match) {
    if (!match) return
    var mid = root.safeIdentifier(String(match.id || ""))
    if (mid === "") return
    var slug = root.safeIdentifier(String(match.competitionSlug || root.league || "eng.1"))
    var isStarted = match.state === "in" || match.state === "post"
    if (match.status && (match.status === "Live" || match.status === "Full Time" || match.status === "FT" || match.status === "AET" || match.status === "Final")) {
      isStarted = true
    }
    var isLive = match.state === "in" || (match.status && (match.status === "Live" || String(match.status).indexOf("'") !== -1 || match.status === "HT"))

    root.showMatchDetail = true
    root.showStandings = false
    root.showStats = false
    root.showMatches = false
    root.showClubFixtures = false
    root.matchDetailLoading = true
    root.matchDetailError = ""
    root.matchDetailTab = isStarted ? "stats" : "info"
    root.matchDetailLineupTeam = "home"
    root.matchDetailCrestsLoaded = false
    root.matchDetailJerseyUrls = []

    var initDateStr = ""
    if (match.date) {
      var mdObj = new Date(match.date)
      var mdDay = Qt.formatDate(mdObj, "ddd d MMM")
      var mdTime = Qt.formatTime(mdObj, "HH:mm")
      initDateStr = mdDay + (mdTime !== "" ? (" · " + mdTime) : "")
    } else if (match.dateText || match.timeText) {
      initDateStr = (match.dateText || "") + ((match.dateText && match.timeText) ? " · " : "") + (match.timeText || "")
    }

    var initStatus = match.status || (match.state === "post" ? "Full Time" : (match.state === "in" ? (match.timeText || "Live") : "Scheduled"))

    var hName = match.homeName || (match.competitions ? root.teamNameFor(match, "home") : (match.home ? (match.home.name || match.home.displayName) : "Home"))
    var hLogo = match.homeLogo || (match.competitions ? root.teamLogoFor(match, "home") : (match.home ? match.home.logo : ""))
    var aName = match.awayName || (match.competitions ? root.teamNameFor(match, "away") : (match.away ? (match.away.name || match.away.displayName) : "Away"))
    var aLogo = match.awayLogo || (match.competitions ? root.teamLogoFor(match, "away") : (match.away ? match.away.logo : ""))
    var cName = root.competitionNameFor(match) || match.competitionName || root.tournamentName || root.leagueLabel()
    var cLogo = root.competitionLogoFor(match) || match.competitionLogo || root.tournamentLogo

    var hScore = isStarted ? (match.homeScore !== undefined ? String(match.homeScore) : root.scoreFor(match, "home")) : ""
    var aScore = isStarted ? (match.awayScore !== undefined ? String(match.awayScore) : root.scoreFor(match, "away")) : ""

    root.matchDetail = {
      id: mid,
      started: isStarted,
      isLive: isLive,
      competitionSlug: slug,
      competitionName: root.sanitizePlainText(cName),
      competitionLogo: root.sanitizeImageUrl(cLogo),
      status: root.sanitizePlainText(initStatus),
      dateFormatted: root.sanitizePlainText(initDateStr),
      dateText: root.sanitizePlainText(match.dateText || (match.date ? Qt.formatDate(new Date(match.date), "ddd d MMM") : "")),
      timeText: root.sanitizePlainText(match.timeText || (match.date ? Qt.formatTime(new Date(match.date), "HH:mm") : "")),
      home: {
        name: root.sanitizePlainText(hName),
        logo: root.sanitizeImageUrl(hLogo),
        score: root.sanitizePlainText(hScore)
      },
      away: {
        name: root.sanitizePlainText(aName),
        logo: root.sanitizeImageUrl(aLogo),
        score: root.sanitizePlainText(aScore)
      },
      homeScorers: [],
      awayScorers: [],
      events: [],
      stats: [],
      commentary: [],
      leaders: [],
      lineups: { available: false, homeFormation: "", awayFormation: "", homeStarters: [], homeSubs: [], awayStarters: [], awaySubs: [] },
      h2h: [],
      homeForm: [],
      awayForm: [],
      odds: null,
      seriesNote: "",
      shootoutNote: "",
      shootoutScore: "",
      shootoutText: "",
      info: { venue: "", attendance: "", officials: "" }
    }

    matchDetailRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(slug) + "/summary?event=" + encodeURIComponent(mid)]
    matchDetailRequest.running = true
  }

  function extractIdFromRef(ref, prefix) {
    if (typeof ref !== "string" || ref === "") return ""
    var parts = ref.split(prefix + "/")
    if (parts.length > 1) {
      var idPart = parts[1].split("/")[0].split("?")[0]
      return root.safeIdentifier(idPart)
    }
    return ""
  }

  function teamNameForId(id) {
    if (Array.isArray(root.teams)) {
      for (var i = 0; i < root.teams.length; i++) {
        if (String(root.teams[i].id) === String(id)) return root.teams[i].name || root.teams[i].label || ""
      }
    }
    return ""
  }

  function sortLeaders(list) {
    if (!Array.isArray(list)) return []
    var sorted = list.slice().sort(function(a, b) {
      var valA = Number(a.value) || 0
      var valB = Number(b.value) || 0
      if (valB !== valA) return valB - valA
      var appA = a.appearances !== "" && a.appearances !== "—" ? (Number(a.appearances) || 0) : 999999
      var appB = b.appearances !== "" && b.appearances !== "—" ? (Number(b.appearances) || 0) : 999999
      if (appA !== appB) return appA - appB
      return 0
    })
    for (var i = 0; i < sorted.length; i++) {
      sorted[i].rank = i + 1
    }
    return sorted
  }

  function rebuildCardStats() {
    var yellow = []
    for (var y = 0; y < root.rawYellowLeaders.length; y++) {
      var ly = root.rawYellowLeaders[y]
      var aidY = ly.athleteId
      var athY = root.athleteMap[aidY]
      var nameY = athY ? athY.name : (ly.name || "Player")
      var jerseyY = athY ? athY.jersey : ""
      var appsY = athY && athY.appearances ? athY.appearances : "—"
      var numValY = Number(ly.value) || 0
      var numAppsY = Number(appsY) || 0
      // Sanity guard: a player cannot receive more than 2 yellow cards per match
      if (appsY !== "—" && numValY > 2 && numAppsY < Math.ceil(numValY / 2)) {
        appsY = "—"
      }
      var teamNameY = root.teamNameForId(ly.teamId)
      yellow.push({
        rank: y + 1,
        name: nameY,
        jersey: jerseyY,
        teamName: teamNameY,
        teamLogo: ly.teamLogo,
        appearances: appsY,
        value: ly.value
      })
    }
    root.statsYellow = root.sortLeaders(yellow)

    var red = []
    for (var r = 0; r < root.rawRedLeaders.length; r++) {
      var lr = root.rawRedLeaders[r]
      var aidR = lr.athleteId
      var athR = root.athleteMap[aidR]
      var nameR = athR ? athR.name : (lr.name || "Player")
      var jerseyR = athR ? athR.jersey : ""
      var appsR = athR && athR.appearances ? athR.appearances : "—"
      var numValR = Number(lr.value) || 0
      var numAppsR = Number(appsR) || 0
      // Sanity guard: a player cannot receive more than 1 red card per match
      if (appsR !== "—" && numValR > 1 && numAppsR < numValR) {
        appsR = "—"
      }
      var teamNameR = root.teamNameForId(lr.teamId)
      red.push({
        rank: r + 1,
        name: nameR,
        jersey: jerseyR,
        teamName: teamNameR,
        teamLogo: lr.teamLogo,
        appearances: appsR,
        value: lr.value
      })
    }
    root.statsRed = root.sortLeaders(red)
  }

  function parseCoreLeaders(data) {
    var rawYellow = []
    var rawRed = []
    var athIds = []
    var cats = data && Array.isArray(data.categories) ? data.categories : []
    for (var c = 0; c < cats.length; c++) {
      var cat = cats[c]
      if (!cat) continue
      var catName = String(cat.name || "")
      if (catName === "yellowCards" || catName === "redCards") {
        var leaders = Array.isArray(cat.leaders) ? cat.leaders : []
        var list = []
        for (var j = 0; j < leaders.length && j < 15; j++) {
          var l = leaders[j]
          if (!l) continue
          var athRef = l.athlete && l.athlete.$ref ? String(l.athlete.$ref) : ""
          var teamRef = l.team && l.team.$ref ? String(l.team.$ref) : ""
          var aid = root.extractIdFromRef(athRef, "athletes")
          var tid = root.extractIdFromRef(teamRef, "teams")
          var val = root.sanitizePlainText(String(l.value !== undefined ? Math.round(Number(l.value)) : (l.displayValue || "0")))
          var teamLogo = tid !== "" ? root.sanitizeImageUrl("https://a.espncdn.com/i/teamlogos/soccer/500/" + tid + ".png") : ""
          list.push({
            athleteId: aid,
            teamId: tid,
            teamLogo: teamLogo,
            value: val
          })
          if (aid !== "" && athIds.indexOf(aid) === -1) {
            athIds.push(aid)
          }
        }
        if (catName === "yellowCards") rawYellow = list
        else if (catName === "redCards") rawRed = list
      }
    }
    root.rawYellowLeaders = rawYellow
    root.rawRedLeaders = rawRed
    root.rebuildCardStats()

    if (athIds.length > 0) {
      if (!athletesRequest.running) {
        athletesRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
          "https://sports.core.api.espn.com/v2/sports/soccer/athletes/{" + athIds.join(",") + "}"]
        athletesRequest.running = true
      }
      var targetYear = root.standingsSeasonYear - root.statsSeasonOffset
      var seasonYear = root.statsSeasonOffset > 0 ? String(targetYear) : (data.season && data.season.year ? String(data.season.year) : String(targetYear))
      var leagueCode = root.safeIdentifier(root.league)
      if (leagueCode !== "" && !athleteStatsRequest.running) {
        athleteStatsRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
          "https://sports.core.api.espn.com/v2/sports/soccer/leagues/" + encodeURIComponent(leagueCode)
          + "/seasons/" + encodeURIComponent(seasonYear) + "/types/1/athletes/{" + athIds.join(",") + "}/statistics/0"]
        athleteStatsRequest.running = true
      }
    }
  }

  function parseAthletesStream(text) {
    if (typeof text !== "string" || text.length === 0) return
    var map = Object.assign({}, root.athleteMap)
    var depth = 0
    var start = -1
    for (var i = 0; i < text.length; i++) {
      var ch = text[i]
      if (ch === "{") {
        if (depth === 0) start = i
        depth++
      } else if (ch === "}") {
        depth--
        if (depth === 0 && start !== -1) {
          try {
            var obj = JSON.parse(text.substring(start, i + 1))
            var aid = root.safeIdentifier(String(obj.id || ""))
            var name = root.sanitizePlainText(String(obj.displayName || obj.fullName || obj.shortName || ""))
            if (aid !== "" && name !== "") {
              var existing = map[aid] || {}
              map[aid] = {
                name: name,
                jersey: root.sanitizePlainText(String(obj.jersey || "")),
                appearances: existing.appearances || "—"
              }
            }
          } catch (e) {}
          start = -1
        }
      }
    }
    root.athleteMap = map
    root.rebuildCardStats()
  }

  function parseAthleteStatsStream(text) {
    if (typeof text !== "string" || text.length === 0) return
    var map = Object.assign({}, root.athleteMap)
    var depth = 0
    var start = -1
    for (var i = 0; i < text.length; i++) {
      var ch = text[i]
      if (ch === "{") {
        if (depth === 0) start = i
        depth++
      } else if (ch === "}") {
        depth--
        if (depth === 0 && start !== -1) {
          try {
            var obj = JSON.parse(text.substring(start, i + 1))
            var ref = String(obj.$ref || (obj.athlete && obj.athlete.$ref) || "")
            var aid = root.extractIdFromRef(ref, "athletes")
            var apps = ""
            var splits = obj.splits && Array.isArray(obj.splits.categories) ? obj.splits.categories : []
            for (var c = 0; c < splits.length; c++) {
              var stats = Array.isArray(splits[c].stats) ? splits[c].stats : []
              for (var s = 0; s < stats.length; s++) {
                if (stats[s] && stats[s].name === "appearances") {
                  apps = String(stats[s].displayValue !== undefined ? stats[s].displayValue : (stats[s].value !== undefined ? Math.round(Number(stats[s].value)) : ""))
                  break
                }
              }
              if (apps !== "") break
            }
            if (aid !== "" && apps !== "") {
              var cur = map[aid] || { name: "Player", jersey: "" }
              cur.appearances = root.sanitizePlainText(apps)
              map[aid] = cur
            }
          } catch (e) {}
          start = -1
        }
      }
    }
    root.athleteMap = map
    root.rebuildCardStats()
  }

  function parseStats(data) {
    var goals = []
    var assists = []
    var statsList = data && Array.isArray(data.stats) ? data.stats : []
    for (var i = 0; i < statsList.length; i++) {
      var cat = statsList[i]
      if (!cat) continue
      var catName = String(cat.name || "")
      var leaders = Array.isArray(cat.leaders) ? cat.leaders : []
      var out = []
      for (var j = 0; j < leaders.length; j++) {
        var l = leaders[j]
        if (!l) continue
        var ath = l.athlete || {}
        var team = ath.team || l.team || {}
        var disp = String(l.displayValue || "")
        var matchRegex = disp.match(/Matches:\s*(\d+)/i)
        var apps = matchRegex ? matchRegex[1] : ""
        if (apps === "") {
          var athStats = Array.isArray(ath.statistics) ? ath.statistics : []
          for (var s = 0; s < athStats.length; s++) {
            if (athStats[s] && athStats[s].name === "appearances") {
              apps = String(athStats[s].displayValue !== undefined ? athStats[s].displayValue : (athStats[s].value !== undefined ? Math.round(Number(athStats[s].value)) : ""))
              break
            }
          }
        }
        var statVal = ""
        if (l.value !== undefined && l.value !== null && l.value !== "") {
          statVal = String(Math.round(Number(l.value)))
        } else {
          var statRegex = disp.match(/(?:Goals|Assists):\s*(\d+)/i)
          statVal = statRegex ? statRegex[1] : disp
        }
        var teamLogo = ""
        if (team.logos && team.logos[0]) {
          teamLogo = root.sanitizeImageUrl(String(team.logos[0].href || ""))
        } else if (team.logo) {
          teamLogo = root.sanitizeImageUrl(String(team.logo))
        } else if (team.id) {
          var safeTid = root.safeIdentifier(String(team.id))
          if (safeTid !== "") teamLogo = "https://a.espncdn.com/i/teamlogos/soccer/500/" + safeTid + ".png"
        }
        var entry = {
          rank: j + 1,
          name: root.sanitizePlainText(String(ath.displayName || ath.shortName || "Unknown")),
          jersey: root.sanitizePlainText(String(ath.jersey || "")),
          teamName: root.sanitizePlainText(String(team.displayName || team.name || "")),
          teamLogo: teamLogo,
          appearances: root.sanitizePlainText(apps),
          value: root.sanitizePlainText(statVal)
        }
        if (entry.name !== "") out.push(entry)
      }
      if (catName.indexOf("goals") !== -1) goals = root.sortLeaders(out)
      else if (catName.indexOf("assists") !== -1) assists = root.sortLeaders(out)
    }
    return { goals: goals, assists: assists }
  }

  function statFor(stats, name) {
    var value = stats && stats[name]
    return value !== undefined && value !== null ? String(value) : "0"
  }

  function mergeRows(existing, incoming) {
    if (!existing || existing.length === 0 || !incoming || incoming.length === 0) return incoming
    if (existing.length !== incoming.length) return incoming
    var changed = false
    var merged = []
    for (var i = 0; i < incoming.length; i++) {
      var inR = incoming[i]
      var exR = existing[i]
      if (inR.id !== exR.id || inR.state !== exR.state || inR.homeScore !== exR.homeScore || inR.awayScore !== exR.awayScore || inR.status !== exR.status || inR.timeText !== exR.timeText || inR.dateText !== exR.dateText) {
        changed = true
        merged.push(inR)
      } else {
        merged.push(exR)
      }
    }
    return changed ? merged : existing
  }

  function mergeMatchClusters(existing, incoming) {
    if (!existing || existing.length === 0 || !incoming || incoming.length === 0) return incoming
    if (existing.length !== incoming.length) return incoming
    var changed = false
    var merged = []
    for (var c = 0; c < incoming.length; c++) {
      var inCluster = incoming[c]
      var exCluster = existing[c]
      if (inCluster.label !== exCluster.label || inCluster.rows.length !== exCluster.rows.length) {
        return incoming
      }
      var rows = root.mergeRows(exCluster.rows, inCluster.rows)
      if (rows !== exCluster.rows) {
        changed = true
        merged.push({ label: inCluster.label, rows: rows })
      } else {
        merged.push(exCluster)
      }
    }
    return changed ? merged : existing
  }

  // Fetches the scoreboard window for the selected league so the League
  // Matches section can show what matters: everything live, the next few
  // upcoming fixtures, and the last few results. Same endpoint class as the
  // scoreboard pool, so the same 5 MiB bound. One week back, two weeks
  // ahead, so a round that spills past day +7 (e.g. a Mon/Tue game after a
  // weekend) is still fetched and clustered with its matchweek.
  function loadMatchList(force) {
    if (root.needsTeam) return
    var slug = root.safeIdentifier(root.league)
    if (slug === "") return
    var key = slug + "|" + String(root.matchWindowOffset) + "|" + String(root.leagueBrowseAll)
    var now = Date.now()
    if (!force && key === root._lastMatchListKey && (root.matchClusters.length > 0 || root.matchWeekRows.length > 0) && root.leagueLive.length === 0 && (now - root.lastMatchListRefresh < 30 * 1000)) {
      return
    }
    matchListRequest.running = false
    root.matchListLoading = true
    root.matchListError = ""
    // League board covers the local day plus its UTC neighbours: an
    // evening UTC kickoff lands on the next morning east of Greenwich, so
    // a strict single-day fetch would miss exactly those live matches.
    var window
    if (root.leagueMode && !root.leagueBrowseAll)
      window = root.rangeDate(-1) + "-" + root.rangeDate(1)
    else if (root.leagueMode)
      window = root.rangeDate(-7 + root.matchWindowOffset)
        + "-" + root.rangeDate(14 + root.matchWindowOffset)
    else
      window = root.rangeDate(-7 + root.matchWindowOffset)
        + "-" + root.rangeDate(14 + root.matchWindowOffset)
    matchListRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "5242880",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(slug)
      + "/scoreboard?dates=" + encodeURIComponent(window) + "&limit=500"]
    matchListRequest.running = true
  }

  // Shared row builder for every scoreboard-derived view. Names/scores go
  // through the same helpers as every other sink; rows come back sorted by
  // kickoff with their local calendar day attached.
  function matchRowsFromEvents(events) {
    var rows = []
    for (var i = 0; i < events.length; i++) {
      var e = events[i]
      var type = e.status && e.status.type || {}
      var state = String(type.state || "")
      // Only unplayed fixtures carry a time: upcoming shows the full date
      // and time; started matches just show their state ("67'", "HT", "FT").
      var detail = root.statusFor(e)
      var status = state === "pre"
        ? root.sanitizePlainText(Qt.formatDateTime(new Date(e.date), "ddd d MMM · HH:mm"))
        : detail
      var row = {
        state: state,
        id: root.safeIdentifier(String(e.id || "")),
        kickoff: new Date(e.date).getTime() || 0,
        // Split kickoff parts so upcoming rows can stack time over date
        // inside the narrow centre column without truncation.
        timeText: root.sanitizePlainText(Qt.formatDateTime(new Date(e.date), "HH:mm")),
        dateText: root.sanitizePlainText(Qt.formatDateTime(new Date(e.date), "ddd d MMM")),
        // Local calendar day, not the raw UTC slice of the ISO timestamp:
        // an evening UTC kickoff lands on the next day east of Greenwich,
        // which otherwise splits rounds and mislabels the date range.
        day: Qt.formatDate(new Date(e.date), "yyyy-MM-dd"),
        status: status,
        shootoutNote: root.shootoutSummaryFor(e),
        homeName: root.teamNameFor(e, "home"),
        awayName: root.teamNameFor(e, "away"),
        homeScore: root.scoreFor(e, "home"),
        awayScore: root.scoreFor(e, "away"),
        homeLogo: root.teamLogoFor(e, "home"),
        awayLogo: root.teamLogoFor(e, "away"),
        competitionSlug: e.competitionSlug !== undefined ? e.competitionSlug : (root.leagueMode ? root.league : ""),
        competitionName: root.competitionNameFor(e),
        competitionLogo: root.competitionLogoFor(e)
      }
      if (row.homeName === "—" || row.awayName === "—") continue
      if (!isNaN(row.kickoff)) rows.push(row)
    }
    rows.sort(function(a, b) { return a.kickoff - b.kickoff })
    return rows
  }

  function currentMatchWeekIndex(clusters) {
    if (!clusters || !Array.isArray(clusters) || clusters.length === 0) return 0
    var today = new Date(); today.setHours(0, 0, 0, 0)
    var todayMs = today.getTime()
    var idx = -1

    // 1. Any cluster containing a live/active match?
    for (var cl = 0; cl < clusters.length && idx === -1; cl++) {
      var rows = clusters[cl].rows || clusters[cl]
      if (!Array.isArray(rows)) continue
      for (var r = 0; r < rows.length; r++) {
        if (rows[r].state === "in" || rows[r].status === "Live" || String(rows[r].status).indexOf("'") !== -1 || rows[r].status === "HT") {
          idx = cl
          break
        }
      }
    }

    // 2. Any cluster where today sits within match dates (with 1 day grace for night finishes)?
    for (var c = 0; c < clusters.length && idx === -1; c++) {
      var cRows = clusters[c].rows || clusters[c]
      if (!Array.isArray(cRows) || cRows.length === 0) continue
      var first = new Date(cRows[0].kickoff); first.setHours(0, 0, 0, 0)
      var last = new Date(cRows[cRows.length - 1].kickoff); last.setHours(0, 0, 0, 0)
      last.setDate(last.getDate() + 1)
      if (todayMs >= first.getTime() && todayMs <= last.getTime()) idx = c
    }

    // 3. Nearest future cluster?
    if (idx === -1) {
      for (var f = 0; f < clusters.length && idx === -1; f++) {
        var fRows = clusters[f].rows || clusters[f]
        if (!Array.isArray(fRows) || fRows.length === 0) continue
        var start = new Date(fRows[0].kickoff); start.setHours(0, 0, 0, 0)
        if (start.getTime() > todayMs) idx = f
      }
    }

    // 4. Fallback: latest cluster
    if (idx === -1) idx = Math.max(0, clusters.length - 1)
    return Math.max(0, Math.min(idx, clusters.length - 1))
  }

  function parseMatchWeek(data) {
    var events = data && Array.isArray(data.events) ? data.events : []
    var rows = root.matchRowsFromEvents(events)
    if (rows.length === 0) return null
    // Group fixtures into fixed-size rounds: half the league's team count
    // per group (10 for a 20-team league), filled in kickoff order. ESPN
    // publishes no round numbers for soccer and congested calendars make
    // date-based round detection ambiguous, so equal chunks are the one
    // rule that always yields the same match count and never hides a game.
    var teamTotal = {}
    for (var t = 0; t < rows.length; t++) {
      teamTotal[rows[t].homeName] = true
      teamTotal[rows[t].awayName] = true
    }
    var perRound = Math.max(1, Math.ceil(Object.keys(teamTotal).length / 2))

    var clusters = []
    for (var cStart = 0; cStart < rows.length; cStart += perRound)
      clusters.push(rows.slice(cStart, cStart + perRound))

    var labeled = clusters.map(function(c) {
      var from = new Date(c[0].kickoff)
      var to = new Date(c[c.length - 1].kickoff)
      var label = Qt.formatDate(from, "d MMM")
      if (Qt.formatDate(from, "yyyyMMdd") !== Qt.formatDate(to, "yyyyMMdd")) {
        label += " – " + Qt.formatDate(to, "d MMM")
      }
      return { rows: c, label: root.sanitizePlainText(label) }
    })
    var idx = root.currentMatchWeekIndex(labeled)
    return { clusters: labeled, index: idx }
  }

  // Crest URL for the followed club: taken from its own fixture entry when
  // one exists, otherwise from the team picker or direct ESPN CDN asset.
  function clubLogoUrl() {
    if (root.leagueMode) return ""
    var candidates = [root.liveMatch, root.nextMatch, root.previousMatch]
    var wanted = String(root.resolvedTeamId !== "" ? root.resolvedTeamId : root.teamId)
    if (wanted !== "") {
      for (var i = 0; i < candidates.length; i++) {
        var ev = candidates[i]
        if (!ev) continue
        var entries = ev.competitions && ev.competitions[0] && ev.competitions[0].competitors || []
        for (var j = 0; j < entries.length; j++) {
          if (String(entries[j].team && entries[j].team.id || "") === wanted) {
            var l = String(entries[j].team.logo || (entries[j].team.logos && entries[j].team.logos[0] ? entries[j].team.logos[0].href : ""))
            if (l !== "") return root.sanitizeImageUrl(l)
          }
        }
      }
      var cleanWanted = root.safeIdentifier(wanted)
      if (cleanWanted !== "") {
        return root.sanitizeImageUrl("https://a.espncdn.com/i/teamlogos/soccer/500/" + cleanWanted + ".png")
      }
    }
    if (root.selectedTeam && root.selectedTeam.logo) {
      return root.sanitizeImageUrl(String(root.selectedTeam.logo))
    }
    if (root.teamName !== "" && Array.isArray(root.teams)) {
      var tName = root.teamName.toLowerCase()
      for (var k = 0; k < root.teams.length; k++) {
        if (root.teams[k] && String(root.teams[k].label || root.teams[k].value || "").toLowerCase() === tName) {
          if (root.teams[k].logo) return root.sanitizeImageUrl(String(root.teams[k].logo))
          if (root.teams[k].id) return root.sanitizeImageUrl("https://a.espncdn.com/i/teamlogos/soccer/500/" + root.safeIdentifier(String(root.teams[k].id)) + ".png")
        }
      }
    }
    return ""
  }

  // League icon URL with built-in CDN mapping fallback
  function leagueLogoUrl() {
    if (root.tournamentLogo !== "") {
      var s = root.sanitizeImageUrl(root.tournamentLogo)
      if (s !== "") return s
    }
    var code = root.safeIdentifier(root.league)
    if (code !== "" && root.leagueLogoMap && root.leagueLogoMap[code]) {
      return root.sanitizeImageUrl(String(root.leagueLogoMap[code]))
    }
    if (code !== "") {
      return root.sanitizeImageUrl("https://a.espncdn.com/i/leaguelogos/soccer/500/" + code + ".png")
    }
    return ""
  }

  // Builds the league-follow board from one scoreboard window: all live
  // matches first, then the latest results, then the nearest upcoming.
  function parseLeagueBoard(data) {
    var events = data && Array.isArray(data.events) ? data.events : []
    var rows = root.matchRowsFromEvents(events)
    var todayKey = Qt.formatDate(new Date(), "yyyy-MM-dd")
    var live = []
    var finished = []
    var upcoming = []
    for (var i = 0; i < rows.length; i++) {
      // Live matches count wherever they sit on the UTC grid; played and
      // upcoming must belong to the user's local calendar day.
      if (rows[i].state === "in") { live.push(rows[i]); continue }
      if (rows[i].day !== todayKey) continue
      if (rows[i].state === "post") finished.push(rows[i])
      else upcoming.push(rows[i])
    }
    finished.sort(function(a, b) { return b.kickoff - a.kickoff })
    upcoming.sort(function(a, b) { return a.kickoff - b.kickoff })
    return {
      live: live,
      recent: finished,
      upcoming: upcoming
    }
  }

  // Determines which side of the live match a team id belongs to.
  function teamSide(teamId) {
    var home = root.competitor(root.liveMatch, "home")
    var away = root.competitor(root.liveMatch, "away")
    var hid = home && home.team ? String(home.team.id || "") : ""
    var aid = away && away.team ? String(away.team.id || "") : ""
    var tid = String(teamId || "")
    if (tid === "" ) return ""
    if (tid === hid) return "home"
    if (tid === aid) return "away"
    return ""
  }

  // True for any event that puts the ball in the net: plain goals, own goals
  // and scored penalties. ESPN keys penalties as "Penalty - Scored" with a
  // `penalty---scored` type rather than "Goal", so a plain text match misses
  // them.
  function isGoalEvent(event) {
    var t = String(event && event.type && event.type.text || "")
    var tt = String(event && event.type && event.type.type || "")
    if (t.indexOf("Goal") !== -1) return true
    if (t.indexOf("Penalty - Scored") !== -1) return true
    if (tt.indexOf("goal") !== -1) return true
    if (tt.indexOf("penalty---scored") !== -1) return true
    return false
  }

  function isPenaltyEvent(event) {
    var t = String(event && event.type && event.type.text || "")
    var tt = String(event && event.type && event.type.type || "")
    return t.indexOf("Penalty") !== -1 || tt.indexOf("penalty") !== -1
  }

  // Extracts goal (or card) events from the live summary. `kind` matches the
  // event type text ("Goal" or "Red").
  function liveEventDetails(kind) {
    var out = []
    var evs = Array.isArray(root.liveEvents) ? root.liveEvents : []
    for (var i = 0; i < evs.length; i++) {
      var e = evs[i]
      var t = e.type && e.type.text || ""
      if (kind === "Goal") {
        if (!root.isGoalEvent(e)) continue
      } else if (String(t).indexOf(kind) === -1) {
        continue
      }
      // ESPN serves two shapes for keyEvents: a flat `athletesInvolved` list
      // or nested `participants[].athlete` plus a top-level `team`.
      var players = e.athletesInvolved || e.participants || []
      if (!players.length) continue
      var first = players[0]
      var person = first.athlete || first
      var team = e.team || first.team || {}
      out.push({
        minute: root.sanitizePlainText(String((e.clock && e.clock.displayValue) || "").replace(/'/g, "")),
        player: root.sanitizePlainText(String(person.displayName || person.shortName || "?")),
        teamName: root.sanitizePlainText(String(team.displayName || team.shortName || "")),
        own: String(e.text || "").indexOf("Own Goal") !== -1,
        penalty: root.isPenaltyEvent(e),
        isHome: root.teamSide(String(team.id || ""))
      })
    }
    return out
  }

  function liveGoals() { return root.liveEventDetails("Goal") }
  function liveRedCards() { return root.liveEventDetails("Red") }

  function formatEvents(events, side, prefix) {
    var out = []
    for (var i = 0; i < events.length; i++) {
      if (String(events[i].isHome) !== side) continue
      var minute = events[i].minute !== "" ? events[i].minute + "'" : ""
      var player = root.sanitizePlainText(events[i].player)
      out.push(prefix + (minute !== "" ? minute + " " : "") + player + (events[i].own ? " (og)" : "") + (events[i].penalty ? " (P)" : ""))
    }
    return root.sanitizePlainText(out.join("\n"))
  }

  function liveGoalsFor(side) { return root.formatEvents(root.liveGoals(), side, "") }
  function liveRedCardsFor(side) { return root.formatEvents(root.liveRedCards(), side, "🟥 ") }

  // Combined scorer + red card lines for one side of the live match.
  function liveDetailsFor(side) {
    var parts = []
    var goals = root.liveGoalsFor(side)
    var cards = root.liveRedCardsFor(side)
    if (goals !== "") parts.push(goals)
    if (cards !== "") parts.push(cards)
    return parts.join("\n")
  }

  function liveHasDetails() {
    return root.liveDetailsFor("home") !== "" || root.liveDetailsFor("away") !== ""
  }

  // Single-string summary for the bar tooltip.
  function liveSummaryText() {
    var home = root.liveDetailsFor("home")
    var away = root.liveDetailsFor("away")
    var parts = []
    if (home !== "") parts.push(root.teamNameFor(root.liveMatch, "home") + ": " + home.split("\n").join(" · "))
    if (away !== "") parts.push(root.teamNameFor(root.liveMatch, "away") + ": " + away.split("\n").join(" · "))
    return root.sanitizePlainText(parts.join("\n"))
  }

  // Sends a desktop notification through the freedesktop daemon the shell
  // runs, which the omarchy notifications service renders as a popup. The
  // optional glyph (Nerd Font character or emoji) travels in the omarchy-glyph
  // hint and is drawn in the card's icon slot; other daemons ignore it.
  function notify(title, body, glyph) {
    if (!title) return
    var cleanTitle = root.sanitizePlainText(String(title))
    var cleanBody = root.sanitizePlainText(String(body || ""))
    if (cleanTitle === "") return
    var args = ["notify-send", "-a", "futbar"]
    var cleanGlyph = root.sanitizePlainText(String(glyph || ""))
    if (cleanGlyph !== "") args.push("-h", "string:omarchy-glyph:" + cleanGlyph)
    args.push(cleanTitle, cleanBody)
    notifyRequest.command = args
    notifyRequest.running = true
    // Every fired notification is a match event: pulse the bar widget so its
    // icon can flash instead of staying colored for the whole match.
    root.activityPulse()
  }

  // Emitted whenever a live-activity notification fires (goal, card, kickoff,
  // half-time, full-time…). FutBar listens to flash its icon briefly.
  signal activityPulse()

  // Stable identity for a summary event so the same one is never notified
  // twice. ESPN's keyEvents carry an id; when they do not, fall back to
  // type + clock + player, which is unique enough within one match.
  function liveActivityKey(event) {
    if (!event) return ""
    var id = event.id !== undefined && event.id !== null ? String(event.id) : ""
    if (id !== "") return "id:" + id
    var clock = event.clock ? String(event.clock.displayValue || "") : ""
    var t = event.type ? String(event.type.text || "") : ""
    var players = event.athletesInvolved || event.participants || []
    var player = ""
    if (players[0]) {
      var person = players[0].athlete || players[0]
      player = String(person.displayName || person.shortName || "")
    }
    return "ev:" + t + ":" + clock + ":" + player
  }

  function activityMarkSeen(event) {
    root.activityMarkKey(root.liveActivityKey(event))
  }

  function activityMarkKey(key) {
    if (key === "" || root.activityEvents.indexOf(key) !== -1) return
    root.activityEvents = root.activityEvents.concat([key])
  }

  function activityAlreadySeen(event) {
    return root.activityEvents.indexOf(root.liveActivityKey(event)) !== -1
  }

  // Recounts the score from the goal-type key events themselves, attributing
  // each goal to a side via its team id/displayName. Returns null when any
  // goal cannot be attributed, so callers fall back to the header score.
  function countedScorePair(comp, events) {
    var entries = comp && Array.isArray(comp.competitors) ? comp.competitors : []
    if (!comp || entries.length < 2) return null
    var counts = { home: 0, away: 0 }
    for (var i = 0; i < events.length; i++) {
      var e = events[i]
      if (!root.isGoalEvent(e)) continue
      var team = e.team || {}
      var tid = String(team.id || "")
      var tname = String(team.displayName || team.shortDisplayName || "")
      var placed = false
      for (var j = 0; j < entries.length && !placed; j++) {
        var c = entries[j]
        var cid = String(c.team && c.team.id || "")
        var cname = String(c.team && c.team.displayName || "")
        if ((tid !== "" && tid === cid) || (tname !== "" && tname === cname)) {
          counts[c.homeAway === "away" ? "away" : "home"]++
          placed = true
        }
      }
      if (!placed) return null
    }
    return counts
  }

  // Numeric home/away pair from a match-shaped source, or null when absent.
  function headerScorePair(source) {
    var h = Number(root.scoreFor(source, "home"))
    var a = Number(root.scoreFor(source, "away"))
    return isNaN(h) || isNaN(a) ? null : { home: h, away: a }
  }

  // Fires held-back goal toasts once the header score agrees with the event
  // recount (ESPN caught up), or once the patience window runs out so a
  // stubborn mismatch still reports instead of dropping the goal silently.
  // The body's score is rebuilt here from the freshest payload.
  function resolvePendingGoals(scoreSource, agree) {
    var keys = Object.keys(root.activityPending)
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i]
      var entry = root.activityPending[key]
      if (!agree && entry.tries < root.activityPendingMaxTries) {
        entry.tries++
        continue
      }
      delete root.activityPending[key]
      root.activityMarkKey(key)
      var score = root.scoreTextFor(scoreSource)
      root.notify(entry.title, (entry.minute !== "" ? entry.minute + "' · " : "") + score, entry.glyph)
    }
  }

  // Pulls the tracked match's summary and fires notifications for anything new.
  function pollLiveActivity() {
    if (!root.liveActivity) return
    var target = root.activityTarget()
    if (!target) {
      // Nothing to attach to anymore (the fixture vanished between
      // refreshes, e.g. postponed): tracking has no purpose left.
      root.stopLiveActivity()
      return
    }
    var id = root.safeIdentifier(String(target.id))
    if (id === "") return
    if (root.activityMatchId !== id) {
      // A different match went live while activity was on: start tracking it
      // cleanly, so its start/goals are reported from scratch.
      root.activityMatchId = id
      root.activityFlags = { started: false, halftime: false, secondhalf: false, fulltime: false }
      root.activityInitialized = false
      root.activityWasHT = false
      root.activityET = false
      root.activityEvents = []
      root.activityPending = ({})
    }
    if (activityRequest.running) return
    var slug = root.safeIdentifier(String(target.competitionSlug || root.league))
    if (slug === "") return
    activityRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(slug) + "/summary?event=" + encodeURIComponent(id)]
    activityRequest.running = true
  }

  function startLiveActivity() {
    root.liveActivity = true
    root.activityMatchId = ""
    root.activityFlags = { started: false, halftime: false, secondhalf: false, fulltime: false }
    root.activityInitialized = false
    root.activityWasHT = false
    root.activityET = false
    root.activityEvents = []
    root.activityPending = ({})
    activityPollTimer.start()
    root.pollLiveActivity()
  }

  function stopLiveActivity() {
    root.liveActivity = false
    root.activityPending = ({})
    activityPollTimer.stop()
  }

  // The match Live Activity should track right now: the live match, or an
  // upcoming fixture inside the follow-lead window before kickoff. Following
  // before kickoff is what allows "Match Started" to fire at the transition.
  function activityTarget() {
    if (root.liveMatch) return root.liveMatch
    if (!root.nextMatch) return null
    var ms = new Date(root.nextMatch.date).getTime()
    if (isNaN(ms)) return null
    if (ms - new Date().getTime() > root.followLeadMs) return null
    return root.nextMatch
  }

  // Shared stderr sink for curl Processes: trim, drop empties, optional
  // label. Keeps every collector's failure path to one auditable line.
  function warnStderr(label, raw) {
    var detail = String(raw || "").trim()
    if (detail !== "") console.warn("futbar", label === "" ? detail : label + ": " + detail)
  }

  // Score text built from an arbitrary match-shaped source. Notifications use
  // the live summary's own competitors, whose scores are fresher than the
  // scoreboard data (the two refresh on independent timers, so a goal event
  // can arrive while root.liveMatch still shows the previous score).
  function scoreTextFor(source) {
    return root.teamNameFor(source, "home") + " " + root.scoreFor(source, "home")
      + "–" + root.scoreFor(source, "away") + " " + root.teamNameFor(source, "away")
  }

  function shortScoreTextFor(source) {
    return root.teamNameFor(source, "home") + " " + root.scoreFor(source, "home")
      + "–" + root.scoreFor(source, "away")
  }

  // "1st half" / "2nd half" etc. from the summary's status type.
  function periodLabel(typeObj) {
    var desc = String(typeObj && typeObj.description || "")
    if (desc.indexOf("Extra Time") !== -1) {
      if (desc.indexOf("Half") !== -1) return "extra time break"
      if (desc.indexOf("Second") !== -1) return "extra time 2nd half"
      return "extra time"
    }
    if (desc.indexOf("First Half") !== -1) return "1st half"
    if (desc.indexOf("Second Half") !== -1) return "2nd half"
    if (desc.indexOf("Half") !== -1) return "half time"
    if (desc.indexOf("Overtime") !== -1) return "overtime"
    if (desc.indexOf("Penalty Shootout") !== -1) return "penalty shootout"
    var detail = String(typeObj && (typeObj.shortDetail || typeObj.detail) || "")
    return root.sanitizePlainText(detail !== "" ? detail : "in progress")
  }

  // ESPN reports soccer's half-time break under state "in" with a Halftime
  // status type instead of a dedicated state, so it must be read from the
  // type. The "hal" state only exists in other sports.
  function isHalftimeStatus(status) {
    var type = status && status.type ? status.type : {}
    if (String(type.name || "") === "STATUS_HALFTIME") return true
    if (String(type.description || "").indexOf("Halftime") !== -1 || String(type.description || "").indexOf("Half Time") !== -1) return true
    if (String(type.shortDetail || "") === "HT" || String(type.detail || "") === "HT") return true
    return false
  }

  // Compares a fresh summary against what has already been reported.
  function handleActivitySummary(data) {
    if (!root.liveActivity) return
    var comp = data && data.header && data.header.competitions && data.header.competitions[0]
    var status = comp ? comp.status || {} : {}
    var state = String(status.type && status.type.state || "")

    // First poll: adopt the match's current phase silently so only genuine
    // transitions after this point produce notifications. Events that already
    // happened before Live Activity was enabled are marked seen, never
    // replayed.
    if (!root.activityInitialized) {
      root.activityInitialized = true
      // Whether extra time already began must be known before the phase
      // branches below: an ET break looks like a half-time status, but its
      // second half is announced through the ET key events instead.
      var existing = Array.isArray(data.keyEvents) ? data.keyEvents : []
      for (var k = 0; k < existing.length; k++) {
        root.activityMarkSeen(existing[k])
        if (!root.activityET && String(existing[k].type && existing[k].type.text || "") === "Start Extra Time")
          root.activityET = true
      }
      if (state === "post") {
        root.activityFlags.started = true
        root.activityFlags.halftime = true
        root.activityFlags.secondhalf = true
        root.activityFlags.fulltime = true
      } else if (state === "hal" || root.isHalftimeStatus(status)) {
        root.activityFlags.started = true
        root.activityFlags.halftime = true
        // Adopted the break silently, but play resuming is still worth
        // announcing as the start of the second half — unless this break is
        // the extra-time one, whose resumption has its own notification.
        if (!root.activityET) root.activityWasHT = true
      } else if (state === "in") {
        root.activityFlags.started = true
        if (status.period === 2 || String(status.type && status.type.name || "") === "STATUS_SECOND_HALF" || String(status.type && status.type.description || "").indexOf("Second Half") !== -1) {
          root.activityFlags.halftime = true
          root.activityFlags.secondhalf = true
        }
      }
      return
    }

    // Regular half-time only applies before extra time; ESPN reports the ET
    // break through its own key events rather than a distinct status state.
    var halftime = !root.activityET && (state === "hal" || root.isHalftimeStatus(status))

    // Notification scores come from the summary payload itself: its
    // competitors carry the score at the moment the events were recorded,
    // while root.liveMatch refreshes on a separate timer and can lag a goal
    // behind (a 1–0 goal would otherwise be announced with the old 0–0).
    var scoreSource = comp && Array.isArray(comp.competitors) && comp.competitors.length > 0
      ? { competitions: [{ competitors: comp.competitors }] }
      : root.liveMatch

    if (!root.activityFlags.halftime && halftime) {
      root.activityFlags.halftime = true
      root.notify("Half Time", root.scoreTextFor(scoreSource) + " (HT)", "󱎫")
    }

    // The break ended and play resumed or match reached period 2 / second half:
    // announce the second half.
    var isSecondHalf = !root.activityET && (status.period === 2 || String(status.type && status.type.name || "") === "STATUS_SECOND_HALF" || String(status.type && status.type.description || "").indexOf("Second Half") !== -1)
    if ((!root.activityFlags.secondhalf && isSecondHalf && !halftime) || (root.activityWasHT && !halftime && state !== "" && state !== "pre" && state !== "post")) {
      root.activityFlags.secondhalf = true
      root.activityFlags.halftime = true
      root.notify("Second Half Started", root.scoreTextFor(scoreSource) + " · " + root.periodLabel(status.type), "󰦶")
    }
    root.activityWasHT = halftime

    // A match is "pre" until moments after kickoff, so reaching any later
    // state without having announced the start is the start.
    if (!root.activityFlags.started && state !== "" && state !== "pre") {
      root.activityFlags.started = true
      root.notify("Match Started",
        root.teamNameFor(root.liveMatch, "home") + " vs " + root.teamNameFor(root.liveMatch, "away")
          + " · " + root.periodLabel(status.type), "󰦶")
    }

    if (!root.activityFlags.fulltime && state === "post") {
      root.activityFlags.fulltime = true
      var ftHome = Number(root.scoreFor(scoreSource, "home"))
      var ftAway = Number(root.scoreFor(scoreSource, "away"))
      // A level scoreline is only a draw when nobody won on penalties:
      // shootout finishes (STATUS_FINAL_PEN) keep equal scores but a winner.
      var tied = !isNaN(ftHome) && !isNaN(ftAway) && ftHome === ftAway
        && String(status.type && status.type.name || "") !== "STATUS_FINAL_PEN"
      root.notify(tied ? "Match Tied" : "Full Time", root.scoreTextFor(scoreSource) + " (FT)", "󱉾")
      activityPollTimer.stop()
      return
    }

    var events = Array.isArray(data.keyEvents) ? data.keyEvents : []

    // ESPN can publish a goal key event before the header score catches up,
    // which made fresh goals announce the previous scoreline. Recount the
    // score from the events and hold goal toasts back while the two sources
    // disagree; every other event type announces immediately. An
    // unattributable recount (null) means "cannot cross-check" → trust the
    // header like before.
    var headerPair = root.headerScorePair(scoreSource)
    var countedPair = root.countedScorePair(comp, events)
    var scoresAgree = !headerPair || !countedPair
      || (headerPair.home === countedPair.home && headerPair.away === countedPair.away)
    if (Object.keys(root.activityPending).length > 0) root.resolvePendingGoals(scoreSource, scoresAgree)

    for (var i = 0; i < events.length; i++) {
      var e = events[i]
      if (root.activityAlreadySeen(e)) continue
      var t = String(e.type && e.type.text || "")
      var minute = root.sanitizePlainText(String(e.clock && e.clock.displayValue || "").replace(/'/g, ""))
      var players = e.athletesInvolved || e.participants || []
      var team = e.team || (players[0] && players[0].team) || {}
      var teamName = root.sanitizePlainText(String(team.displayName || team.shortName || ""))
      var score = root.scoreTextFor(scoreSource)

      if (root.isGoalEvent(e)) {
        if (!players.length) { root.activityMarkSeen(e); continue }
        var first = players[0]
        var person = first.athlete || first
        var playerName = root.sanitizePlainText(String(person.displayName || "?"))
        var goalTitle = root.isPenaltyEvent(e) ? "Penalty — " + teamName : "Goal — " + playerName
        if (!scoresAgree) {
          // Mid-update payload: park the toast until the score settles.
          var pkey = root.liveActivityKey(e)
          if (root.activityPending[pkey] === undefined)
            root.activityPending[pkey] = { tries: 0, title: goalTitle, minute: minute, glyph: "󰒸" }
          continue
        }
        root.activityMarkSeen(e)
        root.notify(goalTitle, (minute !== "" ? minute + "' · " : "") + score, "󰒸")
      } else if (t.indexOf("Yellow Card") !== -1 || t.indexOf("Red Card") !== -1) {
        if (!players.length) { root.activityMarkSeen(e); continue }
        var cardFirst = players[0]
        var cardPerson = cardFirst.athlete || cardFirst
        var cardName = root.sanitizePlainText(String(cardPerson.displayName || "?"))
        var cardKind = t.indexOf("Yellow") !== -1 ? "Yellow Card" : "Red Card"
        var cardGlyph = t.indexOf("Yellow") !== -1 ? "🟨" : "🟥"
        var parts = []
        if (minute !== "") parts.push(minute + "'")
        if (teamName !== "") parts.push(teamName)
        parts.push(root.shortScoreTextFor(scoreSource))
        root.activityMarkSeen(e)
        root.notify(cardKind + " — " + cardName, parts.join(" · "), cardGlyph)
      } else if (t === "Start Extra Time") {
        // Knockout matches: 2 x 15 minutes after regular time ends level.
        root.activityMarkSeen(e)
        root.activityET = true
        root.notify("Extra Time Starts", (minute !== "" ? minute + "' · " : "") + score, "󰦶")
      } else if (t === "Halftime Extra Time") {
        // End of the first extra-time half, before the second begins.
        root.activityMarkSeen(e)
        root.notify("Extra Time Half-Time", score + " (ET HT)", "󱎫")
      } else if (t === "Start 2nd Half Extra Time") {
        root.activityMarkSeen(e)
        root.notify("Extra Time Second Half", (minute !== "" ? minute + "' · " : "") + score, "󰦶")
      } else {
        root.activityMarkSeen(e)
      }
    }
  }

  // Fetch only once a real team is available. The widget stays idle until the
  // user picks a club in the first-run picker and presses Confirm, or until the
  // saved settings / remembered favorite arrive.
  Component.onCompleted: root.ensureStarted()
  onSavedFavoriteChanged: root.ensureStarted()
  onOpenedChanged: {
    if (!root.opened) {
      root.editingTeam = false
      root.pickerLeagueOnly = false
      root.addingTeam = false
    } else {
      root.refresh()
      if (root.leagueMode || root.showMatches) {
        root.loadMatchList(true)
      }
      if (root.showStandings) {
        root.loadStandings(true)
      }
      if (root.showStats) {
        root.loadStats(true)
      }
      if (root.showMatchDetail && root.matchDetail && root.matchDetail.id) {
        root.openMatchDetail(root.matchDetail)
      }
    }
  }
  // A team change lands as a sequence of setting updates (name, league, id),
  // so refresh from each; the guard inside refresh() coalesces them into a
  // single fetch that always targets the newly selected club.
  onTeamNameChanged: root.refresh()
  onTeamIdChanged: root.refresh()
  onResolvedTeamIdChanged: root.refresh()
  // Refresh data and reset identity when the league changes.
  onLeagueChanged: {
    root.tournamentName = root.leagueLabel()
    root.tournamentLogo = ""
    root.statsGoals = []
    root.statsAssists = []
    root.statsYellow = []
    root.statsRed = []
    root.rawYellowLeaders = []
    root.rawRedLeaders = []
    root.athleteMap = ({})
    root.standingsGroups = []
    root.standingsGroupIndex = 0
    root.matchClusters = []
    root.matchClusterIndex = 0
    root._lastStandingsKey = ""
    root._lastStatsKey = ""
    root._lastMatchListKey = ""
    root.lastStandingsRefresh = 0
    root.lastStatsRefresh = 0
    root.lastMatchListRefresh = 0
    root.refresh()
    if (root.leagueMode) {
      if (!matchListRequest.running) root.loadMatchList(true)
      if (root.showStandings && !standingsRequest.running) root.loadStandings(true)
      if (root.showStats && !statsRequest.running) root.loadStats(true)
    } else {
      if (root.opened && root.showStandings && !standingsRequest.running) root.loadStandings(true)
      if (root.opened && root.showStats && !statsRequest.running) root.loadStats(true)
      if (root.opened && root.showMatches) {
        root.matchWindowOffset = 0
        root.pendingEdge = ""
        root.navAnchorDay = ""
        root.loadMatchList(true)
      }
    }
  }

  // Live Activity polling cadence. Tracking only runs during a live match,
  // so one fast interval keeps goals/cards/half-time announcements within
  // seconds of the summary updating them.
  readonly property int activityPollMs: 10000

  // Live Activity polling: check the summary for new events while the user
  // has notifications enabled and a match is in play.
  Timer {
    id: activityPollTimer
    interval: root.activityPollMs
    repeat: true
    onTriggered: root.pollLiveActivity()
  }

  // Auto-switch to whichever followed club is live right now, so the bar
  // icon shows an in-progress match without the user having to notice and
  // pick it themselves. Deliberately NOT reusing the heavy per-club fixture
  // pipeline above (buildFetchQueue/scoreboardQueue) for every followed
  // club -- that fetches every competition a club plays in; this only needs
  // a single scoreboard per unique followed league, run occasionally.
  property bool _liveSwitchDone: false
  property var _livePollQueue: []
  Timer {
    id: livePollTimer
    interval: 90000
    repeat: true
    running: true
    onTriggered: root.startLivePoll()
  }
  Process {
    id: livePollProcess
    stdout: StdioCollector {
      id: livePollOut
      waitForEnd: true
      onStreamFinished: root.handleLivePollResult(text)
    }
    onExited: function(code) {
      if (code !== 0) root.pollNextLiveCheck()
    }
  }
  function startLivePoll() {
    // The active club's own liveMatch already comes from the full fetch
    // pipeline -- nothing to gain by polling, and switching away from a club
    // that's currently live (to another live one) would just be disruptive.
    if (root.leagueMode || root.liveMatch) return
    var seen = {}
    var leagues = []
    var candidates = root.followedTeamsList()
    for (var i = 0; i < candidates.length; i++) {
      var lg = root.safeIdentifier(String(candidates[i].league || ""))
      if (lg === "" || seen[lg]) continue
      seen[lg] = true
      leagues.push(lg)
    }
    if (leagues.length === 0) return
    root._liveSwitchDone = false
    root._livePollQueue = leagues
    root.pollNextLiveCheck()
  }
  function pollNextLiveCheck() {
    if (livePollProcess.running || root._liveSwitchDone) return
    if (root._livePollQueue.length === 0) return
    var queue = root._livePollQueue.slice()
    var slug = queue.shift()
    root._livePollQueue = queue
    // Local day +/- 1 UTC neighbour, same reasoning as loadMatchList: an
    // evening UTC kickoff lands on the next morning east of Greenwich.
    var window = root.rangeDate(-1) + "-" + root.rangeDate(1)
    livePollProcess.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "5242880",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(slug)
      + "/scoreboard?dates=" + encodeURIComponent(window) + "&limit=500"]
    livePollProcess.running = true
  }
  function handleLivePollResult(text) {
    try {
      if (typeof text === "string" && text.length > 0 && text.length <= 5242880) {
        var data = JSON.parse(text)
        var events = Array.isArray(data.events) ? data.events : []
        var candidates = root.followedTeamsList()
        var activeKey = root.teamKey(root.teamName, root.league)
        for (var i = 0; i < events.length && !root._liveSwitchDone; i++) {
          var comp = events[i].competitions && events[i].competitions[0]
          var state = comp && comp.status && comp.status.type ? String(comp.status.type.state) : ""
          if (state !== "in") continue
          var competitors = comp.competitors
          if (!Array.isArray(competitors)) continue
          for (var c = 0; c < candidates.length; c++) {
            var cand = candidates[c]
            if (root.teamKey(cand.teamName, cand.league) === activeKey) continue
            var matched = false
            for (var k = 0; k < competitors.length; k++) {
              var team = competitors[k].team || {}
              if (cand.teamId && String(team.id || "") === String(cand.teamId)) { matched = true; break }
              if (!cand.teamId) {
                var wanted = String(cand.teamName || "").toLowerCase()
                if ([team.displayName, team.shortDisplayName, team.name, team.abbreviation].some(function(n) {
                  return String(n || "").toLowerCase().indexOf(wanted) !== -1
                })) { matched = true; break }
              }
            }
            if (matched) {
              root._liveSwitchDone = true
              root.switchActiveTeam(cand.teamName, cand.league, cand.teamId)
              break
            }
          }
        }
      }
    } catch (e) {
      console.warn("futbar", "live poll parse error: " + e)
    }
    root.pollNextLiveCheck()
  }

  property var _setWidgetQueue: []
  function _queueSetBarWidget(key, value) {
    var cleanKey = root.safeIdentifier(String(key))
    if (cleanKey === "") return
    var queue = root._setWidgetQueue.slice()
    queue.push(["omarchy", "shell", "-q", "shell", "setBarWidget", root.moduleName, cleanKey, JSON.stringify(String(value)), "{}"])
    root._setWidgetQueue = queue
    root._runNextSetWidget()
  }
  function _runNextSetWidget() {
    if (setTeamRequest.running || root._setWidgetQueue.length === 0) return
    var queue = root._setWidgetQueue.slice()
    var cmd = queue.shift()
    root._setWidgetQueue = queue
    setTeamRequest.command = cmd
    setTeamRequest.running = true
  }

  function _getTacticalCoordinates(player) {
    var abbr = String(player.positionAbbr || "").toUpperCase().trim()
    var posName = String(player.position || "").toLowerCase().trim()
    var fp = typeof player.formationPlace === "number" ? player.formationPlace : parseInt(player.formationPlace, 10)
    if (isNaN(fp)) fp = 99

    // 1. Explicit tactical abbreviations from ESPN
    if (abbr === "G") return { x: 0.50, y: 0.90 }
    if (abbr === "LB") return { x: 0.13, y: 0.74 }
    if (abbr === "LWB") return { x: 0.13, y: 0.68 }
    if (abbr === "CD-L") return { x: 0.38, y: 0.74 }
    if (abbr === "CD") return { x: 0.50, y: 0.74 }
    if (abbr === "CD-R") return { x: 0.62, y: 0.74 }
    if (abbr === "RB") return { x: 0.87, y: 0.74 }
    if (abbr === "RWB") return { x: 0.87, y: 0.68 }

    if (abbr === "DM") return { x: 0.50, y: 0.58 }
    if (abbr === "DM-L") return { x: 0.36, y: 0.58 }
    if (abbr === "DM-R") return { x: 0.64, y: 0.58 }
    if (abbr === "CM-L") return { x: 0.34, y: 0.44 }
    if (abbr === "CM") return { x: 0.50, y: 0.44 }
    if (abbr === "CM-R") return { x: 0.66, y: 0.44 }
    if (abbr === "LM") return { x: 0.13, y: 0.44 }
    if (abbr === "RM") return { x: 0.87, y: 0.44 }

    if (abbr === "AM-L" || abbr === "LW" || abbr === "LF") return { x: 0.16, y: 0.24 }
    if (abbr === "AM") return { x: 0.50, y: 0.30 }
    if (abbr === "AM-R" || abbr === "RW" || abbr === "RF") return { x: 0.84, y: 0.24 }

    if (abbr === "CF-L") return { x: 0.35, y: 0.12 }
    if (abbr === "CF-R") return { x: 0.65, y: 0.12 }
    if (abbr === "CF" || abbr === "F" || abbr === "ST") return { x: 0.50, y: 0.12 }

    // 2. Position Name matching
    if (posName.indexOf("goal") !== -1 || fp === 1) return { x: 0.50, y: 0.90 }
    if (posName.indexOf("left back") !== -1 || (posName.indexOf("def") !== -1 && fp === 3)) return { x: 0.13, y: 0.74 }
    if (posName.indexOf("right back") !== -1 || (posName.indexOf("def") !== -1 && fp === 2)) return { x: 0.87, y: 0.74 }
    if (posName.indexOf("center left def") !== -1 || (posName.indexOf("def") !== -1 && (fp === 4 || fp === 6))) return { x: 0.38, y: 0.74 }
    if (posName.indexOf("center right def") !== -1 || (posName.indexOf("def") !== -1 && (fp === 5 || fp === 7))) return { x: 0.62, y: 0.74 }
    if (posName.indexOf("center def") !== -1 || (posName.indexOf("def") !== -1 && fp === 5)) return { x: 0.50, y: 0.74 }

    if (posName.indexOf("defensive mid") !== -1) return { x: 0.50, y: 0.58 }
    if (posName.indexOf("left mid") !== -1) return { x: 0.13, y: 0.44 }
    if (posName.indexOf("right mid") !== -1) return { x: 0.87, y: 0.44 }
    if (posName.indexOf("center left mid") !== -1 || (posName.indexOf("mid") !== -1 && fp === 8)) return { x: 0.34, y: 0.44 }
    if (posName.indexOf("center right mid") !== -1 || (posName.indexOf("mid") !== -1 && fp === 7)) return { x: 0.66, y: 0.44 }
    if (posName.indexOf("center mid") !== -1 || (posName.indexOf("mid") !== -1 && fp === 4)) return { x: 0.50, y: 0.44 }

    if (posName.indexOf("left forw") !== -1 || posName.indexOf("left wing") !== -1 || (posName.indexOf("att") !== -1 && fp === 11)) return { x: 0.16, y: 0.24 }
    if (posName.indexOf("right forw") !== -1 || posName.indexOf("right wing") !== -1 || (posName.indexOf("att") !== -1 && (fp === 7 || fp === 10))) return { x: 0.84, y: 0.24 }
    if (posName.indexOf("center left forw") !== -1) return { x: 0.35, y: 0.12 }
    if (posName.indexOf("center right forw") !== -1) return { x: 0.65, y: 0.12 }
    if (posName.indexOf("forw") !== -1 || posName.indexOf("striker") !== -1 || fp === 9) return { x: 0.50, y: 0.12 }
    if (posName.indexOf("att") !== -1 || fp === 10) return { x: 0.50, y: 0.30 }

    // 3. formationPlace mapping fallback
    if (fp === 1) return { x: 0.50, y: 0.90 }
    if (fp === 3) return { x: 0.13, y: 0.74 }
    if (fp === 4) return { x: 0.38, y: 0.74 }
    if (fp === 5) return { x: 0.50, y: 0.74 }
    if (fp === 6) return { x: 0.62, y: 0.74 }
    if (fp === 2) return { x: 0.87, y: 0.74 }
    if (fp === 8) return { x: 0.34, y: 0.44 }
    if (fp === 7) return { x: 0.66, y: 0.44 }
    if (fp === 11) return { x: 0.16, y: 0.24 }
    if (fp === 10) return { x: 0.84, y: 0.24 }
    if (fp === 9) return { x: 0.50, y: 0.12 }

    return { x: 0.50, y: 0.50 }
  }

  function layoutPitchPlayers(formationStr, starters) {
    if (!starters || starters.length === 0) return []
    var result = []
    for (var i = 0; i < starters.length; i++) {
      var pObj = starters[i]
      var coords = root._getTacticalCoordinates(pObj)
      var sName = pObj.shortName || ""
      if (sName === "" && pObj.name) {
        var parts = pObj.name.trim().split(" ")
        sName = parts[parts.length - 1]
      }
      result.push({
        name: pObj.name || "",
        shortName: sName,
        jersey: pObj.jersey || "",
        position: pObj.position || "",
        positionAbbr: pObj.positionAbbr || "",
        formationPlace: pObj.formationPlace,
        goals: pObj.goals || 0,
        assists: pObj.assists || 0,
        yellowCards: pObj.yellowCards || 0,
        redCards: pObj.redCards || 0,
        subbedOut: !!pObj.subbedOut,
        subbedIn: !!pObj.subbedIn,
        rating: pObj.rating !== undefined ? pObj.rating : null,
        jerseyImage: pObj.jerseyImage || pObj.headshot || "",
        headshot: pObj.headshot || "",
        x: coords.x,
        y: coords.y
      })
    }

    // Robust multi-pass 2D de-collision repulsion: ensure minimum 0.18 horizontal and 0.08 vertical separation
    for (var pass = 0; pass < 6; pass++) {
      for (var a = 0; a < result.length; a++) {
        for (var b = a + 1; b < result.length; b++) {
          var dx = Math.abs(result[a].x - result[b].x)
          var dy = Math.abs(result[a].y - result[b].y)
          if (dy < 0.10 && dx < 0.18) {
            var neededX = (0.18 - dx) / 2
            if (result[a].x <= result[b].x) {
              result[a].x = Math.max(0.12, result[a].x - neededX)
              result[b].x = Math.min(0.88, result[b].x + neededX)
            } else {
              result[a].x = Math.min(0.88, result[a].x + neededX)
              result[b].x = Math.max(0.12, result[b].x - neededX)
            }
            if (dy < 0.06) {
              var neededY = (0.06 - dy) / 2
              if (result[a].y <= result[b].y) {
                result[a].y = Math.max(0.10, result[a].y - neededY)
                result[b].y = Math.min(0.90, result[b].y + neededY)
              } else {
                result[a].y = Math.min(0.90, result[a].y + neededY)
                result[b].y = Math.max(0.10, result[b].y - neededY)
              }
            }
          }
        }
      }
    }
    return result
  }

  function ratingColor(r) {
    var val = Number(r)
    if (isNaN(val) || val <= 0) return "#64748b"
    if (val >= 7.0) return "#16a34a"  // Green (Good / Excellent)
    if (val >= 6.0) return "#ca8a04"  // Yellow / Amber (Average / Solid)
    return "#dc2626"                  // Red (Below Average)
  }

  // Persists the user's club choice through the shell IPC, which writes
  // shell.json and patches the running widget's settings in place. After that
  // needsTeam flips to false and the fixtures take over.
  function selectLeague(code) {
    var cleanCode = root.safeIdentifier(code)
    if (cleanCode === "") return
    var match = null
    for (var i = 0; i < leagues.length; i++) {
      if (leagues[i].value === cleanCode) { match = leagues[i]; break }
    }
    selectedLeague = cleanCode
    selectedLeagueName = match ? String(match.label) : cleanCode
    teams = []
    selectedTeam = null
    var leagueCode = root.safeIdentifier(root.selectedLeague)
    if (leagueCode !== "") {
      teamsRequest.running = false
      teamsRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
        "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(leagueCode) + "/teams"]
      teamsRequest.running = true
    }
  }

  function selectTeam(name) {
    var cleanName = root.sanitizePlainText(name)
    if (cleanName === "") return
    for (var i = 0; i < teams.length; i++) {
      if (String(teams[i].value) === cleanName) { selectedTeam = teams[i]; break }
    }
  }

  // Switches the active club and refetches everything for it. Shared by the
  // picker's Confirm button, tab clicks, and the live-poller's auto-switch.
  // followedTeamsOverride: pass when the tab list is changing in the same
  // action as the active club (see addFollowedTeam) so both land in one write.
  function activateTeam(teamName, league, teamId, followedTeamsOverride) {
    root.editingTeam = false
    var teamVal = root.sanitizePlainText(String(teamName || ""))
    var leagueVal = root.safeIdentifier(String(league || ""))
    var teamIdVal = root.safeIdentifier(String(teamId || ""))

    // Snapshot the outgoing club's already-fetched state before touching
    // anything, so switching back to it later can restore instead of
    // refetching from zero. Uses root.teamName/league as they still read
    // *before* this function changes them below.
    if (root.teamName !== "" && root.teamKey(root.teamName, root.league) !== root.teamKey(teamVal, leagueVal)) {
      root._teamStateCache[root.teamKey(root.teamName, root.league)] = root.snapshotTeamState()
    }

    root.resolvedTeamId = teamIdVal
    root.saveFavorite(teamVal, leagueVal, teamIdVal, followedTeamsOverride)
    root._queueSetBarWidget("teamName", teamVal)
    root._queueSetBarWidget("league", leagueVal)
    root._queueSetBarWidget("teamId", teamIdVal)

    // View/navigation state always resets on a club switch, cache hit or
    // not -- whatever detail view was open belonged to the outgoing club.
    // (standingsRows/statsRows/standingsLeagueKey/statsLeagueKey used to be
    // "reset" here too, but none of the four is an actually-declared
    // property anywhere in this file -- assigning to them throws "Cannot
    // assign to non-existent property" and, same as the resetMatchList()
    // bug above, aborted whatever called this. Dead/vestigial, removed.)
    root.resetMatchList()
    root.showStandings = false
    root.showStats = false
    root.showMatches = false
    root.showClubFixtures = false
    root.showMatchDetail = false
    root.clubFixturePage = 0
    root.requestError = ""

    // Cancel in-flight processes -- their result would belong to whichever
    // club was active when they were fired, not this one.
    fixtureRequest.running = false
    sbRequest1.running = false
    sbRequest2.running = false
    sbRequest3.running = false
    matchListRequest.running = false

    var cached = root._teamStateCache[root.teamKey(teamVal, leagueVal)]
    if (cached) {
      // Cache hit: show the last-known dashboard instantly, no reset-to-
      // empty/spinner flash. refresh() below still runs to bring it up to
      // date -- restoreTeamState() sets _fixtureTeamKey to match, so
      // refresh() skips its own resetTeamData() and (since collectedEvents
      // is non-empty again) the loading flag, and buildFetchQueue() skips
      // rediscovering competitions if competitionSlugs is still fresh --
      // so this becomes a light "just refetch scoreboards" pass rather
      // than the full cold-start pipeline.
      root.restoreTeamState(cached)
      root.loading = false
    } else {
      // No cache entry -- never loaded this session (first pick, or just
      // added via "+"). Today's full reset + spinner + fetch from scratch.
      root.resetTeamData()
      root._fixtureTeamKey = ""
      root.loading = true
    }

    root.refresh()
  }

  function confirmTeam() {
    if (!selectedTeam) return
    var teamVal = root.sanitizePlainText(String(selectedTeam.value || ""))
    var leagueVal = root.safeIdentifier(String(selectedLeague || ""))
    var teamIdVal = root.safeIdentifier(String(selectedTeam.id || ""))
    if (root.addingTeam) {
      root.addingTeam = false
      root.addFollowedTeam(teamVal, leagueVal, teamIdVal)
    } else {
      root.switchActiveTeam(teamVal, leagueVal, teamIdVal)
    }
  }

  function isLeagueMatchFollowed(id) {
    return id !== "" && Array.isArray(root.followedLeagueMatches) && root.followedLeagueMatches.indexOf(id) !== -1
  }

  // Clicking a live board row toggles its own follow; the list persists.
  function toggleLeagueMatchFollow(id) {
    if (id === "") return
    var list = Array.isArray(root.followedLeagueMatches) ? root.followedLeagueMatches.slice() : []
    var pos = list.indexOf(id)
    if (pos !== -1) list.splice(pos, 1)
    else list.push(id)
    root.followedLeagueMatches = list

    var payload = {}
    if (root.savedFavorite && typeof root.savedFavorite === "object") {
      for (var k in root.savedFavorite) payload[k] = root.savedFavorite[k]
    }
    payload.followMatchIds = list
    if (payload.teamName === undefined || payload.teamName === null) payload.teamName = root.teamName
    if (payload.league === undefined || payload.league === null || payload.league === "") payload.league = root.league
    if (payload.teamId === undefined || payload.teamId === null) payload.teamId = (root.teamId !== "" ? root.teamId : root.resolvedTeamId)
    root.savedFavorite = payload
    favoriteStore.setText(JSON.stringify(payload, null, 2) + "\n")

    if (pos === -1) {
      root.enqueueLeagueSummary(id)
      root.pollNextLeagueSummary()
    }
  }

  // Queues a live fixture for league-wide tracking (dedup safe).
  function enqueueLeagueSummary(id) {
    if (id === "") return
    if (root.leagueSummaryQueue.indexOf(id) !== -1) return
    if (id === root.leagueCurrentId) return
    root.leagueSummaryQueue.push(id)
  }

  function pollNextLeagueSummary() {
    if (leagueSummaryRequest.running) return
    if (root.leagueSummaryQueue.length === 0) { root.leagueCurrentId = ""; return }
    root.leagueCurrentId = root.leagueSummaryQueue[0]
    var slug = root.safeIdentifier(root.league)
    if (slug === "") { root.leagueSummaryQueue.shift(); root.pollNextLeagueSummary(); return }
    leagueSummaryRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(slug)
      + "/summary?event=" + encodeURIComponent(root.leagueCurrentId)]
    leagueSummaryRequest.running = true
  }

  // Per-match flag store so each followed fixture runs the exact same
  // notification policy as club mode: kickoff, goals, penalties, cards,
  // half-time, second half, extra time phases, and full-time result.
  property var leagueMatchFlags: ({})

  function leagueFlagsFor(matchId) {
    if (root.leagueMatchFlags[matchId] === undefined)
      root.leagueMatchFlags[matchId] = {
        initialized: false, started: false, halftime: false,
        fulltime: false, wasHT: false, et: false
      }
    return root.leagueMatchFlags[matchId]
  }

  function handleLeagueSummary(matchId, data) {
    var comp = data && data.header && data.header.competitions && data.header.competitions[0]
    if (!comp || !Array.isArray(comp.competitors)) return
    var status = comp.status || {}
    var state = String(status.type && status.type.state || "")
    var flags = root.leagueFlagsFor(matchId)

    var scoreSource = { competitions: [{ competitors: comp.competitors }] }

    if (!flags.initialized) {
      flags.initialized = true
      var existing = Array.isArray(data.keyEvents) ? data.keyEvents : []
      for (var k = 0; k < existing.length; k++) {
        root.activityMarkKey(matchId + ":" + root.liveActivityKey(existing[k]))
        if (!flags.et && String(existing[k].type && existing[k].type.text || "") === "Start Extra Time")
          flags.et = true
      }
      if (state === "post") {
        flags.fulltime = true
        flags.started = true
        flags.halftime = true
        flags.secondhalf = true
      } else if (state === "hal" || root.isHalftimeStatus(status)) {
        flags.started = true
        flags.halftime = true
        if (!flags.et) flags.wasHT = true
      } else if (state === "in") {
        flags.started = true
        if (status.period === 2 || String(status.type && status.type.name || "") === "STATUS_SECOND_HALF" || String(status.type && status.type.description || "").indexOf("Second Half") !== -1) {
          flags.halftime = true
          flags.secondhalf = true
        }
      }
    }

    var halftime = !flags.et && (state === "hal" || root.isHalftimeStatus(status))

    if (!flags.halftime && halftime) {
      flags.halftime = true
      root.notify("Half Time", root.scoreTextFor(scoreSource) + " (HT)", "󱎫")
    }
    if (halftime) flags.halftime = true

    var isSecondHalf = !flags.et && (status.period === 2 || String(status.type && status.type.name || "") === "STATUS_SECOND_HALF" || String(status.type && status.type.description || "").indexOf("Second Half") !== -1)
    if ((!flags.secondhalf && isSecondHalf && !halftime) || (flags.wasHT && !halftime && state !== "" && state !== "pre" && state !== "post")) {
      flags.secondhalf = true
      flags.halftime = true
      root.notify("Second Half Started",
        root.scoreTextFor(scoreSource) + " \u00b7 " + root.periodLabel(status.type), "󰦶")
    }
    flags.wasHT = halftime

    if (!flags.started && state !== "" && state !== "pre") {
      flags.started = true
      var homeName = root.teamNameFor({ competitions: [{ competitors: comp.competitors }] }, "home")
      var awayName = root.teamNameFor({ competitions: [{ competitors: comp.competitors }] }, "away")
      root.notify("Match Started",
        homeName + " vs " + awayName + " \u00b7 " + root.periodLabel(status.type), "󰦶")
    }

    if (!flags.fulltime && state === "post") {
      flags.fulltime = true
      var ftHome = Number(root.scoreFor(scoreSource, "home"))
      var ftAway = Number(root.scoreFor(scoreSource, "away"))
      var tied = !isNaN(ftHome) && !isNaN(ftAway) && ftHome === ftAway
        && String(status.type && status.type.name || "") !== "STATUS_FINAL_PEN"
      root.notify(tied ? "Match Tied" : "Full Time",
        root.scoreTextFor(scoreSource) + " (FT)", "󱉾")
      delete root.leagueMatchFlags[matchId]
      return
    }

    var events = Array.isArray(data.keyEvents) ? data.keyEvents : []
    for (var i = 0; i < events.length; i++) {
      var e = events[i]
      var key = matchId + ":" + root.liveActivityKey(e)
      if (root.activityEvents.indexOf(key) !== -1) continue
      var t = String(e.type && e.type.text || "")
      var minute = root.sanitizePlainText(String(e.clock && e.clock.displayValue || "").replace(/'/g, ""))
      var players = e.athletesInvolved || e.participants || []
      var team = e.team || (players[0] && players[0].team) || {}
      var teamName = root.sanitizePlainText(String(team.displayName || team.shortName || ""))
      var score = root.scoreTextFor(scoreSource)

      if (root.isGoalEvent(e)) {
        if (!players.length) { root.activityMarkKey(key); continue }
        var person = players[0].athlete || players[0]
        var playerName = root.sanitizePlainText(String(person.displayName || "?"))
        root.activityMarkKey(key)
        var goalTitle = root.isPenaltyEvent(e) ? "Penalty — " + teamName : "Goal — " + playerName
        root.notify(goalTitle, (minute !== "" ? minute + "' · " : "") + score, "󰒸")
      } else if (t.indexOf("Yellow Card") !== -1 || t.indexOf("Red Card") !== -1) {
        if (!players.length) { root.activityMarkKey(key); continue }
        var cardPerson = players[0].athlete || players[0]
        var cardName = root.sanitizePlainText(String(cardPerson.displayName || "?"))
        var cardKind = t.indexOf("Yellow") !== -1 ? "Yellow Card" : "Red Card"
        var cardGlyph = t.indexOf("Yellow") !== -1 ? "\u{1F7E8}" : "\u{1F7E5}"
        root.activityMarkKey(key)
        root.notify(cardKind + " — " + cardName,
          (minute !== "" ? minute + "' · " : "") + root.shortScoreTextFor(scoreSource), cardGlyph)
      } else if (t === "Start Extra Time") {
        flags.et = true
        root.activityMarkKey(key)
        root.notify("Extra Time Starts", (minute !== "" ? minute + "' · " : "") + score, "󰦶")
      } else if (t === "Halftime Extra Time") {
        flags.halftime = true
        root.activityMarkKey(key)
        root.notify("Extra Time Half-Time", score + " (ET HT)", "󱎫")
      } else if (t === "Start 2nd Half Extra Time") {
        root.activityMarkKey(key)
        root.notify("Extra Time Second Half", (minute !== "" ? minute + "' · " : "") + score, "󰦶")
      } else {
        root.activityMarkKey(key)
      }
    }
  }

  // Saves the league-follow choice: no club, just the competition.
  function confirmLeague() {
    var leagueVal = root.safeIdentifier(String(selectedLeague || ""))
    if (leagueVal === "") return
    root.editingTeam = false
    root.saveFavorite("", leagueVal, "", undefined, true)
    root._queueSetBarWidget("league", leagueVal)
    // Wipe the previous club from widget settings so a reload cannot
    // resurrect it alongside the league-follow.
    root._queueSetBarWidget("teamName", "")
    root._queueSetBarWidget("teamId", "")

    // Force clean state and immediate fetch for new league
    root.resetTeamData()
    root.resetMatchList()
    root._fixtureTeamKey = ""
    root.showStandings = false
    root.showStats = false
    root.showMatches = true
    root.showMatchDetail = false
    root.leagueBrowseAll = false
    root.matchWindowOffset = 0
    root.matchListLoading = true
    root.matchListError = ""

    // Cancel in-flight processes
    fixtureRequest.running = false
    sbRequest1.running = false
    sbRequest2.running = false
    sbRequest3.running = false
    matchListRequest.running = false

    root.loadMatchList(true)
  }

  // Stores a team id resolved from the /teams list when the team was set
  // through the generic settings UI rather than the picker.
  function persistTeamId(id) {
    var cleanId = root.safeIdentifier(String(id || ""))
    if (cleanId === "") return
    root.saveFavorite(undefined, undefined, cleanId)
    root._queueSetBarWidget("teamId", cleanId)
  }

  function leagueLabel() {
    for (var i = 0; i < leagues.length; i++) {
      if (leagues[i].value === root.league) return String(leagues[i].label)
    }
    return root.league
  }

  function showAllFixtures() {
    root.showMatchDetail = false
    root.showStandings = false
    root.showStats = false
    root.showClubFixtures = false
    root.showMatches = true
    root.matchWindowOffset = 0
    root.pendingEdge = ""
    root.navAnchorDay = ""
    if (root.matchClusters && root.matchClusters.length > 0) {
      root.matchClusterIndex = root.currentMatchWeekIndex(root.matchClusters)
    }
    if (root.leagueMode) {
      root.leagueBrowseAll = true
      root.loadMatchList(true)
    } else {
      root.loadMatchList(true)
    }
  }

  function showClubAllFixtures() {
    root.showMatchDetail = false
    root.showStandings = false
    root.showStats = false
    root.showMatches = false
    root.showClubFixtures = true
    root.initClubFixturePage()
    if (root.collectedEvents.length === 0 && !root.loading) {
      root.refresh()
    }
  }

  // Loads the current league's club list and shows the picker for editing.
  function openTeamPicker() {
    root.editingTeam = true
    root.addingTeam = false
    root.selectedLeague = root.league !== "" ? root.league : (root.leagues.length > 0 ? root.leagues[0].value : "esp.1")
    root.selectedLeagueName = root.leagueLabel()
    root.pickerLeagueOnly = root.leagueMode
    root.teams = []
    root.selectedTeam = null
    if (!teamsRequest.running) teamsRequest.running = true
  }

  // Same picker, but Confirm adds the club to the tab strip instead of
  // replacing the active one. Defaults to the first league in the list
  // (independent of whichever league the active club plays in), so adding
  // e.g. Liverpool doesn't require first clearing Ajax out of the League
  // dropdown.
  function openAddTeamPicker() {
    root.editingTeam = true
    root.addingTeam = true
    root.selectedLeague = root.leagues.length > 0 ? root.leagues[0].value : "esp.1"
    root.selectedLeagueName = root.leagues.length > 0 ? String(root.leagues[0].label) : root.selectedLeague
    root.pickerLeagueOnly = false
    root.teams = []
    root.selectedTeam = null
    if (!teamsRequest.running) teamsRequest.running = true
  }

  function rangeDate(days) {
    var date = new Date()
    date.setDate(date.getDate() + days)
    return Qt.formatDate(date, "yyyyMMdd")
  }

  Process {
    id: fixtureRequest
    // Sequential pipeline: the command changes per queue item and one request
    // runs at a time, chaining via onStreamFinished. A team's fixtures span
    // every competition it enters, so discovery + per-competition scoreboards
    // are needed rather than a single league scoreboard.
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) {
          if (typeof text === "string" && text.length > 2097152) {
            console.warn("futbar", root.fetchStage + " response exceeded byte limit")
          }
          root.startNextFetch()
          return
        }
        try {
          var data = JSON.parse(text)
          if (root.fetchStage === "teams") {
            var leagues = data.sports && data.sports[0] && data.sports[0].leagues || []
            var list = (leagues[0] && leagues[0].teams) || []
            var wanted = root.teamName.toLowerCase()
            var found = null
            for (var i = 0; i < list.length; i++) {
              var team = list[i].team || {}
              var names = [team.displayName, team.shortDisplayName, team.name, team.abbreviation]
              for (var j = 0; j < names.length; j++) {
                if (String(names[j] || "").toLowerCase().indexOf(wanted) !== -1) { found = team; break }
              }
              if (found) break
            }
            if (found) {
              var cleanFoundId = root.safeIdentifier(String(found.id || ""))
              if (cleanFoundId !== "") {
                root.resolvedTeamId = cleanFoundId
                root.persistTeamId(cleanFoundId)
                root.buildFetchQueue()
              } else {
                root.requestError = "Could not resolve team"
                root.loading = false
                return
              }
            } else {
              console.warn("futbar", "could not resolve team id for " + root.teamName)
              root.requestError = "Could not resolve team"
              root.loading = false
              return
            }
          } else if (root.fetchStage === "discover") {
            var items = data.items || []
            var slugs = []
            for (var k = 0; k < items.length; k++) {
              var m = String(items[k].$ref || "").match(/\/leagues\/([^\/]+)\/events\//)
              if (m) {
                var cleanSlug = root.safeIdentifier(m[1])
                if (cleanSlug !== "" && slugs.indexOf(cleanSlug) === -1) slugs.push(cleanSlug)
              }
            }
            if (slugs.length === 0 && root.safeIdentifier(root.league) !== "") slugs.push(root.safeIdentifier(root.league))
            root.competitionSlugs = slugs
            root.competitionRefresh = new Date().getTime()
            root.buildFetchQueue()
          }
        } catch (error) {
          console.warn("futbar", root.fetchStage + ": " + error)
        }
        root.startNextFetch()
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
onStreamFinished: root.warnStderr("", text)
    }
  }

  // Parallel scoreboard pool: up to three scoreboards fetch concurrently,
  // each finishing by kicking the next queued slug. League names and logos
  // are read from each response's `leagues` array, so no league request runs.
  Process {
    id: sbRequest1
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleScoreboard(0, text)
    }
    stderr: StdioCollector {
      waitForEnd: true
onStreamFinished: root.warnStderr("", text)
    }
  }

  Process {
    id: sbRequest2
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleScoreboard(1, text)
    }
    stderr: StdioCollector {
      waitForEnd: true
onStreamFinished: root.warnStderr("", text)
    }
  }

  Process {
    id: sbRequest3
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleScoreboard(2, text)
    }
    stderr: StdioCollector {
      waitForEnd: true
onStreamFinished: root.warnStderr("", text)
    }
  }

  Process {
    id: panelSummaryRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) {
          root.liveEvents = []
          return
        }
        try {
          var data = JSON.parse(text)
          root.liveEvents = Array.isArray(data.keyEvents) ? data.keyEvents : []
          if (data.header && Array.isArray(data.header.competitions) && data.header.competitions[0] && root.liveMatch) {
            var headerComp = data.header.competitions[0]
            var updated = Object.assign({}, root.liveMatch)
            if (headerComp.status) updated.status = headerComp.status
            if (Array.isArray(headerComp.competitors)) {
              if (!Array.isArray(updated.competitions) || !updated.competitions[0]) {
                updated.competitions = [{ competitors: headerComp.competitors, status: headerComp.status }]
              } else {
                var newComps = updated.competitions.slice()
                newComps[0] = Object.assign({}, newComps[0], {
                  competitors: headerComp.competitors,
                  status: headerComp.status || newComps[0].status
                })
                updated.competitions = newComps
              }
            }
            root.liveMatch = updated
          }
        } catch (error) {
          root.liveEvents = []
          console.warn("futbar", "summary: " + error)
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.warnStderr("summary", text)
      }
    }
  }

  Process {
    id: activityRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) return
        try {
          root.handleActivitySummary(JSON.parse(text))
        } catch (error) {
          console.warn("futbar", "activity: " + error)
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.warnStderr("activity", text)
      }
    }
  }

  Process {
    id: notifyRequest
    running: false
  }

  Process {
    id: standingsRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) {
          root.standingsError = "Could not load standings"
          root.standingsLoading = false
          return
        }
        try {
          var data = JSON.parse(text)
          var children = data.children || []
          var groups = []
          for (var c = 0; c < children.length; c++) {
            var child = children[c]
            var standing = child.standings || {}
            var rawEntries = standing.entries || []
            var groupName = String(child.name || "")
            var groupAbbrev = String(child.abbreviation || child.shortName || groupName)
            if (rawEntries.length === 0) continue

            var parsedEntries = rawEntries.map(function(entry, index) {
              var team = entry.team || {}
              var stats = {}
              var list = entry.stats || []
              for (var s = 0; s < list.length; s++) {
                var item = list[s]
                if (!item) continue
                var key = root.safeIdentifier(String(item.name || ""))
                if (key !== "") stats[key] = item.displayValue !== undefined && item.displayValue !== null ? root.sanitizePlainText(String(item.displayValue)) : "0"
              }
              var rankVal = stats.rank
              if (rankVal === undefined || rankVal === "") {
                var noteRank = entry.note && entry.note.rank
                rankVal = noteRank !== undefined && noteRank !== null ? String(noteRank) : String(index + 1)
              }
              return {
                rank: root.sanitizePlainText(String(rankVal)),
                teamName: root.sanitizePlainText(String(team.displayName || team.name || "—")),
                teamId: root.safeIdentifier(String(team.id || "")),
                logo: root.sanitizeImageUrl(team.logos && team.logos[0] ? String(team.logos[0].href || "") : (team.logo ? String(team.logo) : (team.id ? "https://a.espncdn.com/i/teamlogos/soccer/500/" + root.safeIdentifier(String(team.id)) + ".png" : ""))),
                note: entry.note || null,
                stats: stats
              }
            })

            parsedEntries.sort(function(a, b) {
              var rA = Number(a.rank) || 999
              var rB = Number(b.rank) || 999
              if (rA !== rB) return rA - rB
              var pA = Number(a.stats && a.stats.points) || 0
              var pB = Number(b.stats && b.stats.points) || 0
              return pB - pA
            })

            groups.push({
              name: root.sanitizePlainText(groupName),
              shortName: root.sanitizePlainText(groupAbbrev),
              entries: parsedEntries
            })
          }
          root.standingsGroups = groups
          var targetGrp = 0
          if (!root.leagueMode && root.teamName !== "") {
            for (var gi = 0; gi < groups.length; gi++) {
              var gEntries = groups[gi].entries || []
              for (var ej = 0; ej < gEntries.length; ej++) {
                if (gEntries[ej].teamName.toLowerCase().indexOf(root.teamName.toLowerCase()) !== -1 ||
                    (root.teamId !== "" && gEntries[ej].teamId === root.teamId)) {
                  targetGrp = gi
                  break
                }
              }
            }
          }
          root.standingsGroupIndex = Math.min(targetGrp, Math.max(0, groups.length - 1))
          root._lastStandingsKey = root.safeIdentifier(root.league) + "|" + String(root.standingsSeasonOffset)
          root.lastStandingsRefresh = Date.now()
        } catch (error) {
          root.standingsError = "Could not parse standings"
        }
        root.standingsLoading = false
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var detail = String(text || "").trim()
        if (detail !== "") {
          root.standingsError = "Could not load standings"
          root.standingsLoading = false
        }
      }
    }
  }

  Process {
    id: matchDetailRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) {
          root.matchDetailLoading = false
          return
        }
        try {
          var data = JSON.parse(text)
          var hdr = data.header || {}
          var comp = (hdr.competitions && hdr.competitions[0]) || {}
          var competitors = comp.competitors || []
          var homeComp = null
          var awayComp = null
          for (var ci = 0; ci < competitors.length; ci++) {
            if (competitors[ci].homeAway === "home") homeComp = competitors[ci]
            else if (competitors[ci].homeAway === "away") awayComp = competitors[ci]
          }
          if (!homeComp && competitors.length > 0) homeComp = competitors[0]
          if (!awayComp && competitors.length > 1) awayComp = competitors[1]

          var homeTeam = (homeComp && homeComp.team) || {}
          var awayTeam = (awayComp && awayComp.team) || {}

          var rawEvents = Array.isArray(data.keyEvents) ? data.keyEvents : []
          var parsedEvents = []
          for (var ei = 0; ei < rawEvents.length; ei++) {
            var ev = rawEvents[ei]
            if (!ev) continue
            var typeObj = ev.type || {}
            var kType = String(typeObj.text || "")
            var clockObj = ev.clock || {}
            var clk = String(clockObj.displayValue || "")
            var rawTxt = String(ev.text || "").trim()
            if (rawTxt === "" || rawTxt === "None") continue

            var lowerType = kType.toLowerCase()
            var isGoal = lowerType.indexOf("goal") !== -1 || lowerType.indexOf("penalty - scored") !== -1 || ev.scoringPlay === true
            var isCard = lowerType.indexOf("yellow card") !== -1 || lowerType.indexOf("red card") !== -1
            var isSub = lowerType.indexOf("substitution") !== -1
            var isPenalty = lowerType.indexOf("penalty") !== -1
            var isVar = lowerType.indexOf("var") !== -1

            if (!isGoal && !isCard && !isSub && !isPenalty && !isVar) {
              continue
            }

            var glyph = "•"
            var cardColor = ""
            var eventDetail = rawTxt
            var kParts = Array.isArray(ev.participants) ? ev.participants : []

            if (isGoal) {
              glyph = ""
              if (kParts.length >= 2 && kParts[1].athlete) {
                var astName = String(kParts[1].athlete.displayName || kParts[1].athlete.shortName || "")
                if (astName !== "") {
                  eventDetail = eventDetail + " (Assist: " + astName + ")"
                }
              }
            } else if (lowerType.indexOf("yellow card") !== -1) {
              cardColor = "#eab308"
            } else if (lowerType.indexOf("red card") !== -1) {
              cardColor = "#ef4444"
            } else if (isSub) {
              glyph = ""
              if (kParts.length >= 2) {
                var sIn = kParts[0] ? String((kParts[0].athlete && (kParts[0].athlete.displayName || kParts[0].athlete.shortName)) || kParts[0].displayName || "") : ""
                var sOut = kParts[1] ? String((kParts[1].athlete && (kParts[1].athlete.displayName || kParts[1].athlete.shortName)) || kParts[1].displayName || "") : ""
                if (sIn !== "" && sOut !== "") {
                  eventDetail = sIn + " (in) ⇄ " + sOut + " (out)"
                }
              }
            } else if (isPenalty) {
              glyph = "󰡬"
            } else if (isVar) {
              glyph = "󰀪"
            }

            parsedEvents.push({
              type: root.sanitizePlainText(kType),
              glyph: root.sanitizePlainText(glyph),
              minute: root.sanitizePlainText(clk),
              text: root.sanitizePlainText(eventDetail),
              isGoal: isGoal,
              isCard: isCard,
              isSub: isSub,
              cardColor: cardColor
            })
          }

          var parsedStats = []
          var boxTeams = (data.boxscore && Array.isArray(data.boxscore.teams)) ? data.boxscore.teams : []
          if (boxTeams.length >= 2) {
            var hBox = boxTeams[0]
            var aBox = boxTeams[1]
            if (homeTeam.id && hBox.team && String(hBox.team.id) !== String(homeTeam.id)) {
              hBox = boxTeams[1]
              aBox = boxTeams[0]
            }

            var hStatsList = Array.isArray(hBox.statistics) ? hBox.statistics : []
            var aStatsList = Array.isArray(aBox.statistics) ? aBox.statistics : []
            var hMap = {}
            var aMap = {}
            for (var si = 0; si < hStatsList.length; si++) {
              if (hStatsList[si] && hStatsList[si].name) hMap[hStatsList[si].name] = hStatsList[si].displayValue
            }
            for (var sj = 0; sj < aStatsList.length; sj++) {
              if (aStatsList[sj] && aStatsList[sj].name) aMap[aStatsList[sj].name] = aStatsList[sj].displayValue
            }

            var statDefs = [
              { name: "possessionPct", label: "Possession", suffix: "%" },
              { name: "totalShots", altName: "shots", label: "Total Shots", suffix: "" },
              { name: "shotsOnTarget", label: "Shots on Target", suffix: "" },
              { name: "accuratePasses", label: "Accurate Passes", suffix: "" },
              { name: "totalPasses", label: "Total Passes", suffix: "" },
              { name: "passPct", label: "Pass Accuracy", suffix: "%" },
              { name: "wonCorners", altName: "cornerKicks", label: "Corner Kicks", suffix: "" },
              { name: "effectiveTackles", altName: "totalTackles", label: "Tackles Won", suffix: "" },
              { name: "tacklePct", label: "Tackles Won %", suffix: "%" },
              { name: "interceptions", label: "Interceptions", suffix: "" },
              { name: "effectiveClearance", altName: "totalClearance", label: "Clearances", suffix: "" },
              { name: "foulsCommitted", label: "Fouls", suffix: "" },
              { name: "yellowCards", label: "Yellow Cards", suffix: "" },
              { name: "redCards", label: "Red Cards", suffix: "" },
              { name: "offsides", label: "Offsides", suffix: "" },
              { name: "saves", label: "Goalkeeper Saves", suffix: "" }
            ]

            for (var sd = 0; sd < statDefs.length; sd++) {
              var def = statDefs[sd]
              var hV = hMap[def.name] !== undefined ? hMap[def.name] : (def.altName ? hMap[def.altName] : undefined)
              var aV = aMap[def.name] !== undefined ? aMap[def.name] : (def.altName ? aMap[def.altName] : undefined)
              if (hV !== undefined || aV !== undefined) {
                var hNum = parseFloat(hV) || 0
                var aNum = parseFloat(aV) || 0
                var total = hNum + aNum
                var hRatio = total > 0 ? (hNum / total) : 0.5
                parsedStats.push({
                  name: def.name,
                  label: def.label,
                  homeValue: root.sanitizePlainText(String(hV !== undefined ? hV : "0") + def.suffix),
                  awayValue: root.sanitizePlainText(String(aV !== undefined ? aV : "0") + def.suffix),
                  homeRatio: hRatio
                })
              }
            }
          }

          var parsedLeaders = []
          if (Array.isArray(data.leaders)) {
            for (var lIdx = 0; lIdx < data.leaders.length; lIdx++) {
              var leadTeam = data.leaders[lIdx]
              if (!leadTeam) continue
              var lTeamId = leadTeam.team ? String(leadTeam.team.id || "") : ""
              var isHomeLeader = (homeTeam.id && lTeamId === String(homeTeam.id)) || (lIdx === 0)
              var catList = Array.isArray(leadTeam.leaders) ? leadTeam.leaders : []
              var teamCats = []
              for (var cIdx = 0; cIdx < catList.length; cIdx++) {
                var cat = catList[cIdx]
                if (!cat) continue
                var catName = String(cat.displayName || cat.name || "")
                var leadAthletes = Array.isArray(cat.leaders) ? cat.leaders : []
                if (leadAthletes.length > 0 && leadAthletes[0].athlete) {
                  var pLead = leadAthletes[0]
                  teamCats.push({
                    category: root.sanitizePlainText(catName),
                    player: root.sanitizePlainText(String(pLead.athlete.displayName || pLead.athlete.shortName || "")),
                    value: root.sanitizePlainText(String(pLead.displayValue || pLead.value || ""))
                  })
                }
              }
              if (teamCats.length > 0) {
                parsedLeaders.push({
                  isHome: isHomeLeader,
                  teamName: root.sanitizePlainText(String(leadTeam.team && (leadTeam.team.displayName || leadTeam.team.name) || (isHomeLeader ? "Home" : "Away"))),
                  categories: teamCats
                })
              }
            }
          }

          var parsedCommentary = []
          if (Array.isArray(data.commentary) && data.commentary.length > 0) {
            for (var ci = data.commentary.length - 1; ci >= 0; ci--) {
              var cItem = data.commentary[ci]
              if (!cItem || !cItem.text) continue
              var cTime = (cItem.time && cItem.time.displayValue) ? String(cItem.time.displayValue).trim() : ""
              if (cTime !== "" && !cTime.endsWith("'") && !isNaN(Number(cTime))) cTime += "'"
              parsedCommentary.push({
                time: root.sanitizePlainText(cTime),
                text: root.sanitizePlainText(String(cItem.text || "")),
                sequence: cItem.sequence || ci
              })
              if (parsedCommentary.length >= 60) break
            }
          }

          var seriesNote = ""
          if (comp.series && comp.series.summary) {
            seriesNote = root.sanitizePlainText(String(comp.series.summary))
          } else if (comp.series && comp.series.title) {
            seriesNote = root.sanitizePlainText(String(comp.series.title))
          }
          var shootoutNote = ""
          var shootoutScore = ""
          var shootoutText = ""
          if (comp.shootout) {
            var sH = comp.shootout.homeScore !== undefined ? String(comp.shootout.homeScore) : ""
            var sA = comp.shootout.awayScore !== undefined ? String(comp.shootout.awayScore) : ""
            if (sH !== "" && sA !== "") {
              shootoutScore = sH + " – " + sA
              shootoutNote = sH + "–" + sA + " Pens"
              shootoutText = "After Penalties"
            }
          }
          if (shootoutNote === "" && homeComp && awayComp) {
            var sH2 = homeComp.shootoutScore !== undefined ? String(homeComp.shootoutScore) : ""
            var sA2 = awayComp.shootoutScore !== undefined ? String(awayComp.shootoutScore) : ""
            if (sH2 !== "" && sA2 !== "") {
              shootoutScore = sH2 + " – " + sA2
              shootoutNote = sH2 + "–" + sA2 + " Pens"
              shootoutText = "After Penalties"
            }
          }
          if (shootoutNote === "" && Array.isArray(comp.notes)) {
            for (var nti = 0; nti < comp.notes.length; nti++) {
              var nt = comp.notes[nti]
              var ntText = nt ? String(nt.text || nt.headline || "") : ""
              var mPen = ntText.match(/(\d+)\s*[-–]\s*(\d+)\s+on\s+penalties/i) || ntText.match(/penalties.*?(\d+)\s*[-–]\s*(\d+)/i)
              if (mPen) {
                shootoutScore = mPen[1] + " – " + mPen[2]
                shootoutNote = mPen[1] + "–" + mPen[2] + " Pens"
                shootoutText = "After Penalties"
                break
              } else if (ntText.toLowerCase().indexOf("penalties") !== -1) {
                shootoutNote = ntText
                shootoutText = "After Penalties"
              }
            }
          }

          var venueObj = comp.venue || (data.gameInfo && data.gameInfo.venue) || {}
          var vName = String(venueObj.fullName || "")
          var vCity = (venueObj.address && venueObj.address.city) ? String(venueObj.address.city) : ""
          var venueStr = vName + (vCity !== "" ? (", " + vCity) : "")

          var attVal = comp.attendance || (data.gameInfo && data.gameInfo.attendance) || ""
          var attStr = attVal ? String(attVal).replace(/\B(?=(\d{3})+(?!\d))/g, ",") : ""

          var officialsList = (data.gameInfo && Array.isArray(data.gameInfo.officials)) ? data.gameInfo.officials : []
          var offNames = []
          for (var oi = 0; oi < officialsList.length; oi++) {
            if (officialsList[oi] && officialsList[oi].displayName) offNames.push(officialsList[oi].displayName)
          }
          var officialsStr = offNames.join(", ")

          var parsedH2H = []
          if (Array.isArray(data.seasonseries) && data.seasonseries.length > 0) {
            var ssEvents = Array.isArray(data.seasonseries[0].events) ? data.seasonseries[0].events : []
            for (var h2i = 0; h2i < ssEvents.length; h2i++) {
              var sEv = ssEvents[h2i]
              if (!sEv) continue
              var sComps = Array.isArray(sEv.competitors) ? sEv.competitors : []
              var sH = null
              var sA = null
              for (var sc = 0; sc < sComps.length; sc++) {
                if (sComps[sc].homeAway === "home") sH = sComps[sc]
                else if (sComps[sc].homeAway === "away") sA = sComps[sc]
              }
              if (!sH && sComps.length > 0) sH = sComps[0]
              if (!sA && sComps.length > 1) sA = sComps[1]

              var sHTeam = (sH && sH.team) || {}
              var sATeam = (sA && sA.team) || {}
              var sHName = String(sHTeam.shortDisplayName || sHTeam.displayName || "Home")
              var sAName = String(sATeam.shortDisplayName || sATeam.displayName || "Away")
              var sHScore = String(sH && sH.score !== undefined ? sH.score : "-")
              var sAScore = String(sA && sA.score !== undefined ? sA.score : "-")
              var sCompName = String(sEv.competitionName || "")
              var sDateStr = ""
              if (sEv.date) {
                sDateStr = Qt.formatDate(new Date(sEv.date), "d MMM yyyy")
              }
              parsedH2H.push({
                home: root.sanitizePlainText(sHName),
                away: root.sanitizePlainText(sAName),
                homeScore: root.sanitizePlainText(sHScore),
                awayScore: root.sanitizePlainText(sAScore),
                competition: root.sanitizePlainText(sCompName),
                dateFormatted: root.sanitizePlainText(sDateStr)
              })
            }
          }

          var parsedHomeForm = []
          var parsedAwayForm = []
          if (Array.isArray(data.lastFiveGames)) {
            for (var lfi = 0; lfi < data.lastFiveGames.length; lfi++) {
              var lfgItem = data.lastFiveGames[lfi]
              if (!lfgItem) continue
              var lfgTeamId = lfgItem.team ? String(lfgItem.team.id || "") : ""
              var isHomeLfg = (homeTeam.id && lfgTeamId === String(homeTeam.id)) || (lfi === 0)
              var targetFormList = isHomeLfg ? parsedHomeForm : parsedAwayForm

              var lfgEvs = Array.isArray(lfgItem.events) ? lfgItem.events : []
              for (var ge = 0; ge < lfgEvs.length; ge++) {
                var gObj = lfgEvs[ge]
                if (!gObj) continue
                var oppObj = gObj.opponent || {}
                var oppName = String(oppObj.shortDisplayName || oppObj.displayName || "Opponent")
                var resChar = String(gObj.gameResult || "-").toUpperCase()
                var gScore = String(gObj.score || "")
                var gDateStr = gObj.gameDate ? Qt.formatDate(new Date(gObj.gameDate), "d MMM") : ""

                targetFormList.push({
                  opponent: root.sanitizePlainText(oppName),
                  result: root.sanitizePlainText(resChar),
                  score: root.sanitizePlainText(gScore),
                  dateFormatted: root.sanitizePlainText(gDateStr)
                })
              }
            }
          }

          var parsedOdds = null
          if (Array.isArray(data.pickcenter) && data.pickcenter.length > 0) {
            var pc = data.pickcenter[0]
            if (pc) {
              var provName = (pc.provider && pc.provider.name) ? String(pc.provider.name) : "Match Odds"
              var dLine = pc.details ? String(pc.details) : ""
              var ou = (pc.overUnder !== undefined && pc.overUnder !== null) ? String(pc.overUnder) : ""
              var sp = (pc.spread !== undefined && pc.spread !== null) ? String(pc.spread) : ""
              var hML = (pc.homeTeamOdds && pc.homeTeamOdds.moneyLine !== undefined) ? String(pc.homeTeamOdds.moneyLine) : ""
              var aML = (pc.awayTeamOdds && pc.awayTeamOdds.moneyLine !== undefined) ? String(pc.awayTeamOdds.moneyLine) : ""
              var dML = (pc.drawOdds && pc.drawOdds.moneyLine !== undefined) ? String(pc.drawOdds.moneyLine) : ""

              parsedOdds = {
                provider: root.sanitizePlainText(provName),
                details: root.sanitizePlainText(dLine),
                overUnder: root.sanitizePlainText(ou),
                spread: root.sanitizePlainText(sp),
                homeML: root.sanitizePlainText(hML),
                awayML: root.sanitizePlainText(aML),
                drawML: root.sanitizePlainText(dML)
              }
            }
          }

          var statusDesc = (comp.status && comp.status.type && comp.status.type.description) ? String(comp.status.type.description) : "Full Time"

          function formatGroupedScorers(items) {
            var grouped = {}
            var order = []
            for (var i = 0; i < items.length; i++) {
              var it = items[i]
              if (!it || !it.name) continue
              var nameKey = it.name
              var clkPart = String(it.clock || "").trim()
              while (clkPart.endsWith("''")) clkPart = clkPart.substring(0, clkPart.length - 1)
              if (clkPart !== "" && !clkPart.endsWith("'") && !isNaN(Number(clkPart))) clkPart += "'"
              if (it.ownGoal) clkPart += (clkPart !== "" ? " " : "") + "(OG)"
              else if (it.penaltyKick) clkPart += (clkPart !== "" ? " " : "") + "(P)"
              if (!grouped[nameKey]) {
                grouped[nameKey] = []
                order.push(nameKey)
              }
              if (clkPart !== "") grouped[nameKey].push(clkPart)
            }
            var res = []
            for (var j = 0; j < order.length; j++) {
              var n = order[j]
              var clkList = grouped[n].join(", ")
              var line = (n + " " + clkList).trim()
              if (line !== "") res.push(root.sanitizePlainText(line))
            }
            return res
          }

          var rawHomeScorers = []
          var rawAwayScorers = []
          var detailsList = Array.isArray(comp.details) ? comp.details : []
          if (detailsList.length > 0) {
            for (var di = 0; di < detailsList.length; di++) {
              var dItem = detailsList[di]
              if (dItem && dItem.scoringPlay) {
                var dTypeStr = (dItem.type && dItem.type.text) ? String(dItem.type.text).toLowerCase() : ""
                if (dItem.shootout || dTypeStr.indexOf("shootout") !== -1) continue
                var dTeamId = dItem.team ? String(dItem.team.id || "") : ""
                var dClk = dItem.clock ? String(dItem.clock.displayValue || "") : ""
                var dParts = Array.isArray(dItem.participants) ? dItem.participants : []
                var dAth = (dParts.length > 0 && dParts[0].athlete) ? dParts[0].athlete : {}
                var dName = String(dAth.shortName || dAth.displayName || "")
                if (dName !== "") {
                  var scorerObj = {
                    name: dName,
                    clock: dClk,
                    ownGoal: !!dItem.ownGoal,
                    penaltyKick: !!dItem.penaltyKick
                  }
                  if (homeTeam.id && dTeamId === String(homeTeam.id)) {
                    rawHomeScorers.push(scorerObj)
                  } else if (awayTeam.id && dTeamId === String(awayTeam.id)) {
                    rawAwayScorers.push(scorerObj)
                  }
                }
              }
            }
          } else {
            for (var ki = 0; ki < rawEvents.length; ki++) {
              var kEv = rawEvents[ki]
              if (!kEv) continue
              var kTypeStr = (kEv.type && kEv.type.text) ? String(kEv.type.text).toLowerCase() : ""
              if (kEv.shootout || kTypeStr.indexOf("shootout") !== -1) continue
              if (kTypeStr.indexOf("goal") !== -1 || kTypeStr.indexOf("penalty - scored") !== -1) {
                var kTeamId = kEv.team ? String(kEv.team.id || "") : ""
                var kClk = kEv.clock ? String(kEv.clock.displayValue || "") : ""
                var kParts = Array.isArray(kEv.participants) ? kEv.participants : []
                var kAth = (kParts.length > 0 && kParts[0].athlete) ? kParts[0].athlete : {}
                var kName = String(kAth.shortName || kAth.displayName || "")
                if (kName !== "") {
                  var scorerObj2 = {
                    name: kName,
                    clock: kClk,
                    ownGoal: kTypeStr.indexOf("own goal") !== -1,
                    penaltyKick: kTypeStr.indexOf("penalty") !== -1
                  }
                  if (homeTeam.id && kTeamId === String(homeTeam.id)) {
                    rawHomeScorers.push(scorerObj2)
                  } else if (awayTeam.id && kTeamId === String(awayTeam.id)) {
                    rawAwayScorers.push(scorerObj2)
                  }
                }
              }
            }
          }

          var homeScorers = formatGroupedScorers(rawHomeScorers)
          var awayScorers = formatGroupedScorers(rawAwayScorers)

          var matchDateStr = ""
          if (comp.date) {
            var dObj = new Date(comp.date)
            var dDay = Qt.formatDate(dObj, "ddd d MMM")
            var dTime = Qt.formatTime(dObj, "HH:mm")
            matchDateStr = dDay + (dTime !== "" ? (" · " + dTime) : "")
          } else if (root.matchDetail && root.matchDetail.dateFormatted) {
            matchDateStr = root.matchDetail.dateFormatted
          }

          var compState = (comp.status && comp.status.type && comp.status.type.state) ? String(comp.status.type.state) : ""
          var isActuallyLive = compState === "in"
          var isActuallyStarted = isActuallyLive || compState === "post" || (parsedEvents.length > 0) || (parsedStats.length > 0)
          if (!isActuallyStarted && root.matchDetail) {
            isActuallyStarted = !!root.matchDetail.started
            if (!isActuallyLive) isActuallyLive = !!root.matchDetail.isLive
          }

          var statusDesc = (comp.status && comp.status.type && comp.status.type.description) ? String(comp.status.type.description) : "Full Time"
          if (statusDesc.toLowerCase().indexOf("penalties") !== -1 || statusDesc.toLowerCase().indexOf("penalty") !== -1) {
            if (shootoutText === "") shootoutText = "After Penalties"
            statusDesc = "Full Time"
          }
          if (isActuallyLive) {
            var rawClk = ""
            if (comp.status && comp.status.displayClock) {
              rawClk = String(comp.status.displayClock).trim()
            } else if (comp.status && comp.status.type && comp.status.type.shortDetail) {
              rawClk = String(comp.status.type.shortDetail).trim()
            } else if (comp.status && comp.status.type && comp.status.type.detail) {
              rawClk = String(comp.status.type.detail).trim()
            }
            if (rawClk !== "") {
              while (rawClk.endsWith("''")) {
                rawClk = rawClk.substring(0, rawClk.length - 1)
              }
              if (!rawClk.endsWith("'") && !isNaN(Number(rawClk))) {
                rawClk = rawClk + "'"
              }
              statusDesc = rawClk
            }
          }

          var parsedLineups = {
            available: false,
            homeFormation: "",
            awayFormation: "",
            homeStarters: [],
            homeSubs: [],
            awayStarters: [],
            awaySubs: []
          }

          if (Array.isArray(data.rosters) && data.rosters.length > 0) {
            for (var rIdx = 0; rIdx < data.rosters.length; rIdx++) {
              var rTeam = data.rosters[rIdx]
              if (!rTeam) continue
              var rTeamId = rTeam.team ? String(rTeam.team.id || "") : ""
              var isHomeRoster = false
              if (rTeam.homeAway === "home") {
                isHomeRoster = true
              } else if (rTeam.homeAway === "away") {
                isHomeRoster = false
              } else if (homeTeam.id && String(rTeamId) === String(homeTeam.id)) {
                isHomeRoster = true
              } else if (awayTeam.id && String(rTeamId) === String(awayTeam.id)) {
                isHomeRoster = false
              } else {
                isHomeRoster = (rIdx === 0)
              }
              var rFormation = root.sanitizePlainText(String(rTeam.formation || ""))
              var rPlayers = Array.isArray(rTeam.roster) ? rTeam.roster : []
              var rStarters = []
              var rSubs = []

              for (var pIdx = 0; pIdx < rPlayers.length; pIdx++) {
                var pObj = rPlayers[pIdx]
                if (!pObj) continue
                var ath = pObj.athlete || {}
                var pName = root.sanitizePlainText(String(ath.displayName || ath.fullName || ath.shortName || ""))
                var pShort = root.sanitizePlainText(String(ath.shortName || ath.displayName || ath.fullName || ""))
                var pNum = root.sanitizePlainText(String(pObj.jersey || ath.jersey || ""))
                var posObj = pObj.position || ath.position || {}
                var pPos = root.sanitizePlainText(String(posObj.displayName || posObj.name || ""))
                if (pName === "") continue
                var pStats = {}
                if (Array.isArray(pObj.stats)) {
                  for (var si = 0; si < pObj.stats.length; si++) {
                    var st = pObj.stats[si]
                    if (st && st.name) {
                      pStats[st.name] = Number(st.value !== undefined ? st.value : (st.displayValue || 0)) || 0
                    }
                  }
                }

                var goalsCount = Math.round(pStats.totalGoals || 0)
                var assistsCount = Math.round(pStats.goalAssists || 0)
                var yellowCardsCount = Math.round(pStats.yellowCards || 0)
                var redCardsCount = Math.round(pStats.redCards || 0)
                var isSubbedOut = false
                if (pObj.subbedOut === true || (pObj.subbedOut && pObj.subbedOut.didSub === true)) {
                  isSubbedOut = true
                }
                var isSubbedIn = false
                if (pObj.subbedIn === true || (pObj.subbedIn && pObj.subbedIn.didSub === true)) {
                  isSubbedIn = true
                }

                var playerRating = null
                if (isActuallyStarted && (pObj.starter === true || isSubbedIn || (pStats.appearances && pStats.appearances > 0))) {
                  var rawRating = pObj.rating !== undefined ? Number(pObj.rating) : (ath.rating !== undefined ? Number(ath.rating) : null)
                  if (rawRating !== null && !isNaN(rawRating) && rawRating > 0) {
                    playerRating = Math.max(4.0, Math.min(10.0, rawRating))
                  } else {
                    var baseR = 6.0
                    var gBonus = goalsCount * 1.2
                    var aBonus = assistsCount * 0.7
                    var saveBonus = (pStats.saves || 0) * 0.3
                    var shotBonus = (pStats.shotsOnTarget || 0) * 0.2
                    var faBonus = (pStats.foulsSuffered || 0) * 0.1
                    var yPenalty = yellowCardsCount * 0.5
                    var rPenalty = redCardsCount * 1.5
                    var fcPenalty = (pStats.foulsCommitted || 0) * 0.1
                    var calcR = baseR + gBonus + aBonus + saveBonus + shotBonus + faBonus - yPenalty - rPenalty - fcPenalty
                    playerRating = Math.max(4.0, Math.min(10.0, Math.round(calcR * 10) / 10))
                  }
                }

                var jerseyImgUrl = ""
                if (Array.isArray(ath.jerseyImages) && ath.jerseyImages.length > 0 && ath.jerseyImages[0].href) {
                  jerseyImgUrl = String(ath.jerseyImages[0].href)
                } else if (ath.headshot && ath.headshot.href) {
                  jerseyImgUrl = String(ath.headshot.href)
                }

                var eventDetails = []
                if (Array.isArray(pObj.plays)) {
                  for (var pli = 0; pli < pObj.plays.length; pli++) {
                    var pl = pObj.plays[pli]
                    if (!pl) continue
                    var clk = pl.clock && pl.clock.displayValue ? String(pl.clock.displayValue).trim() : ""
                    if (pl.didScore) {
                      var tag = pl.penaltyKick ? " (P)" : (pl.ownGoal ? " (og)" : "")
                      eventDetails.push("" + (clk !== "" ? (" " + clk) : "") + tag)
                    }
                    if (pl.didAssist) {
                      eventDetails.push("󱗇" + (clk !== "" ? (" " + clk) : ""))
                    }
                    if (pl.redCard) {
                      eventDetails.push("󰡬" + (clk !== "" ? (" " + clk) : ""))
                    } else if (pl.yellowCard) {
                      eventDetails.push("󰀪" + (clk !== "" ? (" " + clk) : ""))
                    }
                    if (pl.substitution) {
                      if (isSubbedIn) {
                        eventDetails.push("▲" + (clk !== "" ? (" " + clk) : ""))
                      } else if (isSubbedOut) {
                        eventDetails.push("▼" + (clk !== "" ? (" " + clk) : ""))
                      }
                    }
                  }
                }
                if (eventDetails.length === 0) {
                  if (goalsCount > 0) {
                    for (var g = 0; g < goalsCount; g++) eventDetails.push("")
                  }
                  if (assistsCount > 0) {
                    for (var a = 0; a < assistsCount; a++) eventDetails.push("󱗇")
                  }
                  if (redCardsCount > 0) eventDetails.push("󰡬")
                  else if (yellowCardsCount > 0) eventDetails.push("󰀪")
                  if (isSubbedOut) eventDetails.push("▼")
                  else if (isSubbedIn) eventDetails.push("▲")
                }

                var pItem = {
                  name: pName,
                  shortName: pShort,
                  jersey: pNum,
                  position: pPos,
                  positionAbbr: root.sanitizePlainText(String(posObj.abbreviation || "")),
                  formationPlace: pObj.formationPlace !== undefined ? parseInt(pObj.formationPlace, 10) : 99,
                  starter: pObj.starter === true,
                  goals: goalsCount,
                  assists: assistsCount,
                  yellowCards: yellowCardsCount,
                  redCards: redCardsCount,
                  subbedOut: isSubbedOut,
                  subbedIn: isSubbedIn,
                  rating: playerRating,
                  eventsText: root.sanitizePlainText(eventDetails.join(" · ")),
                  jerseyImage: root.sanitizeImageUrl(jerseyImgUrl),
                  headshot: root.sanitizeImageUrl(jerseyImgUrl)
                }
                if (pObj.starter === true) {
                  rStarters.push(pItem)
                } else {
                  rSubs.push(pItem)
                }
              }

              if (rStarters.length > 0 || rSubs.length > 0) {
                parsedLineups.available = true
              }

              if (isHomeRoster) {
                parsedLineups.homeFormation = rFormation
                parsedLineups.homeStarters = rStarters
                parsedLineups.homeSubs = rSubs
              } else {
                parsedLineups.awayFormation = rFormation
                parsedLineups.awayStarters = rStarters
                parsedLineups.awaySubs = rSubs
              }
            }
          }

          var allJerseyUrls = []
          var allPlayersList = [].concat(
            parsedLineups.homeStarters || [],
            parsedLineups.awayStarters || [],
            parsedLineups.homeSubs || [],
            parsedLineups.awaySubs || []
          )
          for (var jui = 0; jui < allPlayersList.length; jui++) {
            var jUrl = allPlayersList[jui].jerseyImage || allPlayersList[jui].headshot || ""
            if (jUrl !== "" && allJerseyUrls.indexOf(jUrl) === -1) {
              allJerseyUrls.push(jUrl)
            }
          }
          root.matchDetailJerseyUrls = allJerseyUrls

          root.matchDetail = {
            id: String(data.id || (root.matchDetail && root.matchDetail.id) || ""),
            started: isActuallyStarted,
            isLive: isActuallyLive,
            competitionSlug: (root.matchDetail && root.matchDetail.competitionSlug) || root.league,
            competitionName: root.sanitizePlainText((hdr.league && (hdr.league.name || hdr.league.description)) || (root.matchDetail && root.matchDetail.competitionName) || ""),
            competitionLogo: root.sanitizeImageUrl((hdr.league && hdr.league.logos && hdr.league.logos[0] ? hdr.league.logos[0].href : "") || (root.matchDetail && root.matchDetail.competitionLogo) || ""),
            status: root.sanitizePlainText(statusDesc),
            seriesNote: root.sanitizePlainText(seriesNote),
            shootoutNote: root.sanitizePlainText(shootoutNote),
            shootoutScore: root.sanitizePlainText(shootoutScore),
            shootoutText: root.sanitizePlainText(shootoutText),
            home: {
              name: root.sanitizePlainText(String(homeTeam.displayName || homeTeam.name || (root.matchDetail && root.matchDetail.home && root.matchDetail.home.name) || "Home")),
              logo: root.sanitizeImageUrl((homeTeam.logos && homeTeam.logos[0] ? String(homeTeam.logos[0].href || "") : "") || String(homeTeam.logo || "") || (homeTeam.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + root.safeIdentifier(String(homeTeam.id)) + ".png") : "") || (root.matchDetail && root.matchDetail.home && root.matchDetail.home.logo) || ""),
              score: isActuallyStarted ? root.sanitizePlainText(String(homeComp && homeComp.score !== undefined ? homeComp.score : "0")) : ""
            },
            away: {
              name: root.sanitizePlainText(String(awayTeam.displayName || awayTeam.name || (root.matchDetail && root.matchDetail.away && root.matchDetail.away.name) || "Away")),
              logo: root.sanitizeImageUrl((awayTeam.logos && awayTeam.logos[0] ? String(awayTeam.logos[0].href || "") : "") || String(awayTeam.logo || "") || (awayTeam.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + root.safeIdentifier(String(awayTeam.id)) + ".png") : "") || (root.matchDetail && root.matchDetail.away && root.matchDetail.away.logo) || ""),
              score: isActuallyStarted ? root.sanitizePlainText(String(awayComp && awayComp.score !== undefined ? awayComp.score : "0")) : ""
            },
            homeScorers: homeScorers,
            awayScorers: awayScorers,
            events: parsedEvents,
            stats: parsedStats,
            leaders: parsedLeaders,
            commentary: parsedCommentary,
            lineups: parsedLineups,
            h2h: parsedH2H,
            homeForm: parsedHomeForm,
            awayForm: parsedAwayForm,
            odds: parsedOdds,
            info: {
              venue: root.sanitizePlainText(venueStr),
              attendance: root.sanitizePlainText(attStr),
              officials: root.sanitizePlainText(officialsStr)
            }
          }

          if (!isActuallyStarted && root.matchDetailTab === "stats") {
            root.matchDetailTab = "info"
          }
        } catch (e) {
          console.warn("futbar", "matchDetail parse error: " + e)
          root.matchDetailError = "Could not parse match details"
        }
        root.matchDetailLoading = false
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.warnStderr("matchDetail", text)
        root.matchDetailLoading = false
      }
    }
  }

  // Fallback timer ensuring athlete jersey preloading begins even if crest status signals are skipped
  Timer {
    id: matchDetailCrestsFallbackTimer
    interval: 250
    running: root.showMatchDetail && !root.matchDetailCrestsLoaded
    repeat: false
    onTriggered: {
      root.matchDetailCrestsLoaded = true
    }
  }

  Process {
    id: statsRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) {
          if (typeof text === "string" && text.length > 2097152)
            console.warn("futbar", "stats exceeded byte limit")
          root.statsError = "Could not load stats"
          root.statsLoading = false
          return
        }
        try {
          var data = JSON.parse(text)
          var res = root.parseStats(data)
          root.statsGoals = res.goals
          root.statsAssists = res.assists
          var lg = data.league || {}
          if (String(lg.name || "") !== "") root.tournamentName = root.sanitizePlainText(String(lg.name))
          if (lg.logos && lg.logos[0]) {
            var lgo = root.sanitizeImageUrl(String(lg.logos[0].href || ""))
            if (lgo !== "") root.tournamentLogo = lgo
          }
          if (res.goals.length === 0 && res.assists.length === 0 && root.statsYellow.length === 0 && root.statsRed.length === 0) {
            root.statsError = "No statistics available for this season"
          }

          var targetYear = root.standingsSeasonYear - root.statsSeasonOffset
          var seasonYear = root.statsSeasonOffset > 0 ? String(targetYear) : (data.season && data.season.year ? String(data.season.year) : String(targetYear))
          var leagueCode = root.safeIdentifier(root.league)
          if (leagueCode !== "") {
            cardLeadersRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
              "https://sports.core.api.espn.com/v2/sports/soccer/leagues/" + encodeURIComponent(leagueCode)
              + "/seasons/" + encodeURIComponent(seasonYear) + "/types/1/leaders"]
            cardLeadersRequest.running = true
          }
          root._lastStatsKey = root.safeIdentifier(root.league) + "|" + String(root.statsSeasonOffset)
          root.lastStatsRefresh = Date.now()
        } catch (error) {
          console.warn("futbar", "could not read stats: " + error)
          root.statsError = "Could not parse stats"
        }
        root.statsLoading = false
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var detail = String(text || "").trim()
        if (detail !== "") {
          root.statsError = "Could not load stats"
          root.statsLoading = false
        }
      }
    }
  }

  Process {
    id: cardLeadersRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) {
          if (typeof text === "string" && text.length > 2097152)
            console.warn("futbar", "card leaders exceeded byte limit")
          root.statsLoading = false
          return
        }
        try {
          var data = JSON.parse(text)
          root.parseCoreLeaders(data)
        } catch (e) {
          console.warn("futbar", "could not parse card leaders: " + e)
        }
        root.statsLoading = false
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.statsLoading = false
      }
    }
  }

  Process {
    id: athletesRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) {
          if (typeof text === "string" && text.length > 2097152)
            console.warn("futbar", "athletes stream exceeded byte limit")
          return
        }
        root.parseAthletesStream(text)
      }
    }
  }

  Process {
    id: athleteStatsRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) {
          if (typeof text === "string" && text.length > 2097152)
            console.warn("futbar", "athlete stats stream exceeded byte limit")
          return
        }
        root.parseAthleteStatsStream(text)
      }
    }
  }

  Process {
    id: teamsRequest
    // Fetched per league when the user picks one in the first-run picker.
    command: ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(root.safeIdentifier(root.selectedLeague)) + "/teams"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) return
        try {
          var data = JSON.parse(text)
          var leagues = data.sports && data.sports[0] && data.sports[0].leagues || []
          var list = (leagues[0] && leagues[0].teams) || []
          root.teams = list.map(function(entry) {
            var team = entry.team || {}
            var rawName = String(team.displayName || team.name || "")
            var name = root.sanitizePlainText(rawName)
            // The /teams endpoint nests logos in a `logos[]` array rather than
            // the single `logo` string the scoreboard uses.
            var logo = String(team.logo || "")
            if (logo === "" && team.logos && team.logos[0]) logo = String(team.logos[0].href || "")
            var safeId = root.safeIdentifier(String(team.id || ""))
            if (logo === "" && safeId !== "") {
              logo = "https://a.espncdn.com/i/teamlogos/soccer/500/" + safeId + ".png"
            }
            var safeLogo = root.sanitizeImageUrl(logo)
            return name === "" ? null : { value: name, label: name, logo: safeLogo, id: safeId }
          }).filter(function(item) { return item !== null })
          // Pre-highlighting the active club only makes sense when *changing*
          // it -- openAddTeamPicker() also sets editingTeam=true, and without
          // this guard, browsing to a league your active club also plays in
          // (e.g. Champions League) while adding a *different* club silently
          // preselects your active club instead, one confirm-click away from
          // adding a duplicate of it rather than the club you meant to add.
          if (root.editingTeam && !root.addingTeam) {
            for (var i = 0; i < root.teams.length; i++) {
              if (String(root.teams[i].value) === root.teamName) {
                root.selectedTeam = root.teams[i]
                break
              }
            }
          }
        } catch (error) {
          console.warn("futbar", "could not read team list: " + error)
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.warnStderr("team list", text)
      }
    }
  }

  Process {
    id: matchListRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 5242880) {
          if (typeof text === "string" && text.length > 5242880)
            console.warn("futbar", "league scoreboard exceeded byte limit")
          root.matchListLoading = false
          return
        }
        try {
          var data = JSON.parse(text)
          var lg = data.leagues && data.leagues[0] ? data.leagues[0] : (data.league || {})
          if (String(lg.name || "") !== "")
            root.tournamentName = root.sanitizePlainText(String(lg.name))
          if (lg.logos && lg.logos[0]) {
            var lgo = root.sanitizeImageUrl(String(lg.logos[0].href || ""))
            if (lgo !== "") root.tournamentLogo = lgo
          }
          if (root.leagueMode && !root.leagueBrowseAll) {
            var board = root.parseLeagueBoard(data)
            root.leagueLive = root.mergeRows(root.leagueLive, board.live)
            root.leagueRecent = root.mergeRows(root.leagueRecent, board.recent)
            root.leagueUpcoming = root.mergeRows(root.leagueUpcoming, board.upcoming)
            var liveCount = board.live.length
            root.leagueBoardSummary = liveCount > 0 ? liveCount + " live" : "no live matches"
            // Feed followed live fixtures to the tracker; prune follows
            // whose match is no longer in play.
            if (root.followedLeagueMatches.length > 0) {
              for (var fi = root.followedLeagueMatches.length - 1; fi >= 0; fi--) {
                var stillLive = false
                for (var lj = 0; lj < board.live.length; lj++)
                  if (board.live[lj].id === root.followedLeagueMatches[fi]) { stillLive = true; break }
                if (!stillLive && board.live.length >= 0) {
                  var wasQueued = root.leagueSummaryQueue.indexOf(root.followedLeagueMatches[fi])
                  if (wasQueued !== -1) root.leagueSummaryQueue.splice(wasQueued, 1)
                  root.followedLeagueMatches.splice(fi, 1)
                }
              }
              for (var li = 0; li < board.live.length; li++)
                root.enqueueLeagueSummary(board.live[li].id)
              root.pollNextLeagueSummary()
            }
            root.matchListLoading = false
            return
          }
          var week = root.parseMatchWeek(data)
          if (!week) {
            // Paged past every fixture (or a quiet stretch): an empty round
            // list is a normal state, not a fetch failure. Navigation stays
            // available so the user can head back toward real fixtures.
            root.matchClusters = []
            root.matchClusterIndex = 0
            root.pendingEdge = ""
            root.navAnchorDay = ""
            root.matchListLoading = false
            return
          }
          root.matchClusters = root.mergeMatchClusters(root.matchClusters, week.clusters)
          // A navigation-driven window extension lands on the newly opened
          // edge round; otherwise auto-refresh must never yank the view back
          // to the live round — keep showing whichever matchweek is on
          // screen (matched by its stable date-range label). Only when that
          // round has fallen out of the scoreboard window does the view snap
          // to the detected current one.
          var landed = false
          if (root.pendingEdge === "next") {
            if (root.navAnchorDay !== "") {
              for (var n = 0; n < week.clusters.length && !landed; n++) {
                if (week.clusters[n].rows[0].day > root.navAnchorDay) {
                  root.matchClusterIndex = n
                  landed = true
                }
              }
            }
            // Coming from an empty stretch, the nearest fixtures are the
            // first rounds of the shifted window.
            if (!landed) root.matchClusterIndex = 0
          } else if (root.pendingEdge === "prev") {
            if (root.navAnchorDay !== "") {
              for (var p = week.clusters.length - 1; p >= 0 && !landed; p--) {
                var lastRow = week.clusters[p].rows[week.clusters[p].rows.length - 1]
                if (lastRow.day < root.navAnchorDay) {
                  root.matchClusterIndex = p
                  landed = true
                }
              }
            }
            if (!landed) root.matchClusterIndex = week.clusters.length - 1
          } else {
            if (root.matchWindowOffset === 0) {
              root.matchClusterIndex = week.index
            } else {
              var keep = -1
              for (var k = 0; k < week.clusters.length && keep === -1; k++) {
                if (week.clusters[k].label === root.matchWeekLabel) keep = k
              }
              root.matchClusterIndex = keep !== -1 ? keep : week.index
            }
          }
          root.pendingEdge = ""
          root.navAnchorDay = ""
          root._lastMatchListKey = root.safeIdentifier(root.league) + "|" + String(root.matchWindowOffset) + "|" + String(root.leagueBrowseAll)
          root.lastMatchListRefresh = Date.now()
        } catch (error) {
          console.warn("futbar", "could not read league scoreboard: " + error)
          root.matchListError = "Could not load matches"
        }
        root.matchListLoading = false
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.warnStderr("league scoreboard", text)
    }
  }

  // Drains the live-fixture summary queue one match at a time.
  Process {
    id: leagueSummaryRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var handledId = root.leagueCurrentId
        root.leagueCurrentId = ""
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152) {
          try { root.handleLeagueSummary(handledId, JSON.parse(text)) }
          catch (error) { console.warn("futbar", "league summary: " + error) }
        } else if (typeof text === "string" && text.length > 2097152) {
          console.warn("futbar", "league summary exceeded byte limit")
        }
        if (root.leagueSummaryQueue.length > 0 && root.leagueSummaryQueue[0] === handledId)
          root.leagueSummaryQueue.shift()
        else {
          var pos = root.leagueSummaryQueue.indexOf(handledId)
          if (pos !== -1) root.leagueSummaryQueue.splice(pos, 1)
        }
        Qt.callLater(root.pollNextLeagueSummary)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.warnStderr("league summary", text)
    }
  }

  // Background heartbeat for league-wide tracking: keeps the board and the
  // summary queue current even when the popup is closed.
  Timer {
    interval: 60000
    running: root.leagueMode && root.followedLeagueMatches.length > 0
    repeat: true
    onTriggered: {
      // Drop fixtures that are no longer live from the queue.
      for (var i = root.leagueSummaryQueue.length - 1; i >= 0; i--) {
        var tracked = false
        for (var j = 0; j < root.leagueLive.length; j++)
          if (root.leagueLive[j].id === root.leagueSummaryQueue[i]) { tracked = true; break }
        if (!tracked) root.leagueSummaryQueue.splice(i, 1)
      }
      root.loadMatchList(true)
    }
  }

  // Keeps matches and live scores fresh while the panel is open.
  Timer {
    id: panelOpenRefreshTimer
    interval: 15000
    running: root.opened && !root.needsTeam
    repeat: true
    onTriggered: {
      if (root.leagueMode) {
        if (root.showMatches || root.leagueBrowseAll) {
          root.loadMatchList(true)
        }
      } else {
        if (root.liveMatch || !root.fixtureFresh()) root.refresh()
      }
      if (root.showMatchDetail && root.matchDetail && root.matchDetail.id && (root.matchDetail.isLive || !root.matchDetail.started)) {
        if (!matchDetailRequest.running) {
          var slug = root.safeIdentifier(String(root.matchDetail.competitionSlug || root.league || "eng.1"))
          var mid = root.safeIdentifier(String(root.matchDetail.id))
          if (slug !== "" && mid !== "") {
            matchDetailRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "2097152",
              "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(slug) + "/summary?event=" + encodeURIComponent(mid)]
            matchDetailRequest.running = true
          }
        }
      }
    }
  }

  Process {
    id: setTeamRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._runNextSetWidget()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
root.warnStderr("team select failed", text)
        root._runNextSetWidget()
      }
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // Keep the card tied to its bar button instead of centering it on the bar.
    centerOnBar: false
    contentWidth: popup.fittedContentWidth(Style.space(390))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // While a club-picker dropdown is open or focused, let it handle the
      // keys (Escape/arrows/Enter) instead of the panel's close/switch keys.
      blocked: (leagueDropdown && (leagueDropdown.popupOpen || leagueDropdown.activeFocus))
        || (teamDropdown && (teamDropdown.popupOpen || teamDropdown.activeFocus))
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: panelScrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: content.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          target: panelScrollArea.contentItem
          property: "interactive"
          value: content.implicitHeight > panelScrollArea.height
        }

        Column {
          id: content
          width: panelScrollArea.width
          spacing: Style.space(14)

        Column {
        visible: root.needsTeam || root.editingTeam
        width: parent.width
        spacing: Style.space(14)

        Text {
          textFormat: Text.PlainText
          text: root.addingTeam ? "Add a club to follow" : (root.editingTeam ? "Change your club" : "Choose your club")
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        SearchableDropdown {
          id: leagueDropdown
          width: parent.width
          label: "League"
          placeholderText: "Search league…"
          emptyText: "No leagues found"
          fontFamily: root.contentFontFamily
          options: root.leagues
          value: root.selectedLeague
          onChanged: function(value) { root.selectLeague(value) }
        }

        Button {
          id: leagueFollowToggle
          width: parent.width
          anchors.horizontalCenter: parent.horizontalCenter
          iconText: root.pickerLeagueOnly ? "󰴆" : "󰒭"
          text: root.pickerLeagueOnly ? "Following whole league" : "Follow whole league instead"
          tooltipText: "Track every match in the selected league instead of one club"
          fontFamily: root.contentFontFamily
          foreground: root.contentForeground
          accent: root.contentForeground
          fontSize: Style.font.caption
          iconSize: Style.font.caption
          horizontalPadding: Style.space(10)
          verticalPadding: Style.space(4)
          selected: root.pickerLeagueOnly
          enabled: root.selectedLeague !== ""
          onClicked: root.pickerLeagueOnly = !root.pickerLeagueOnly
        }

        SearchableDropdown {
          id: teamDropdown
          width: parent.width
          visible: !root.pickerLeagueOnly
          label: root.teamsLoading ? "Fetching clubs…" : "Club"
          placeholderText: "Search club…"
          emptyText: "No clubs found"
          fontFamily: root.contentFontFamily
          options: root.teams
          value: root.selectedTeam ? String(root.selectedTeam.value) : ""
          enabled: root.selectedLeague !== "" && !root.teamsLoading
          onChanged: function(value) { root.selectTeam(value) }
        }

        Item {
          width: parent.width
          height: Style.space(70)
          visible: root.teamsLoading && !root.pickerLeagueOnly

          LoadingOverlay {
            active: root.teamsLoading && !root.pickerLeagueOnly
            text: root.sanitizePlainText("Fetching " + root.selectedLeagueName + " clubs…")
            spinnerSize: Style.space(28)
          }
        }

        Row {
          visible: root.selectedTeam && !root.pickerLeagueOnly
          width: parent.width
          height: Style.space(48)
          spacing: Style.space(12)

          Image {
            width: Style.space(40)
            height: width
            source: root.selectedTeam ? root.selectedTeam.logo : ""
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 128
            sourceSize.height: 128
            mipmap: true
            smooth: true
            anchors.verticalCenter: parent.verticalCenter
            visible: String(source) !== ""
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              textFormat: Text.PlainText
              text: root.selectedTeam ? String(root.selectedTeam.value) : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Text {
              textFormat: Text.PlainText
              text: root.selectedLeagueName
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        Button {
          visible: root.selectedTeam || root.pickerLeagueOnly
          width: parent.width
          text: "Confirm"
          fontFamily: root.contentFontFamily
          foreground: root.contentForeground
          accent: root.contentForeground
          onClicked: root.pickerLeagueOnly ? root.confirmLeague() : root.confirmTeam()
        }
      }

      Column {
        visible: !root.needsTeam && !root.editingTeam
        width: parent.width
        spacing: Style.space(14)

        // Club tabs: only shown once a second club has been added, so a
        // single-team setup (everyone before this feature existed) looks
        // exactly as before. Click switches; right-click removes (the active
        // club has no remove -- it isn't stored in followedTeams to begin
        // with, so there's nothing to remove it from).
        Flow {
          // Always visible (once a club is active, outside league-follow mode)
          // so the "add" button is reachable even before a second club has
          // ever been followed -- not gated on followedTeamsList() being
          // non-empty, or there'd be no way to add the very first extra club.
          visible: !root.leagueMode
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: [{ teamName: root.teamName, league: root.league, teamId: root.teamId, active: true }]
              .concat(root.followedTeamsList().map(function(t) {
                return { teamName: t.teamName, league: t.league, teamId: t.teamId, active: false }
              }))
            delegate: Button {
              text: modelData.teamName
              tooltipText: modelData.active ? modelData.teamName : ("Switch to " + modelData.teamName + " · right-click to remove")
              selected: modelData.active
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(10)
              verticalPadding: Style.space(4)
              onClicked: if (!modelData.active) root.switchActiveTeam(modelData.teamName, modelData.league, modelData.teamId)
              onRightClicked: if (!modelData.active) root.removeFollowedTeam(modelData.teamName, modelData.league)
            }
          }

          Button {
            iconText: "󰐕"
            tooltipText: "Add another club to follow"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.font.caption
            horizontalPadding: Style.space(8)
            verticalPadding: Style.space(4)
            onClicked: root.openAddTeamPicker()
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(10)

        Image {
          id: tournamentLogoImage
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(36)
          height: width
          // League identity while browsing matchweeks, stats, table, or in league-follow;
          // club identity otherwise.
          source: root.showClubFixtures
            ? (root.clubLogoUrl() !== "" ? root.clubLogoUrl() : root.leagueLogoUrl())
            : ((root.showMatches || root.showStats || root.showStandings || root.leagueMode)
              ? (root.leagueLogoUrl() !== "" ? root.leagueLogoUrl() : root.clubLogoUrl())
              : (root.clubLogoUrl() !== "" ? root.clubLogoUrl() : root.leagueLogoUrl()))
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          cache: true
          mipmap: true
          smooth: true
          visible: String(source) !== ""
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - (tournamentLogoImage.visible ? tournamentLogoImage.width + parent.spacing : 0)
            - (standingsButton.visible ? standingsButton.width + parent.spacing : 0)
            - (statsButton.visible ? statsButton.width + parent.spacing : 0)
            - (matchesButton.visible ? matchesButton.width + parent.spacing : 0)
            - (changeTeamButton.visible ? changeTeamButton.width + parent.spacing : 0)
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.showClubFixtures
              ? (root.teamName + " Fixtures")
              : ((root.showMatches || root.showStats || root.showStandings || root.leagueMode)
                ? (root.tournamentName || root.leagueLabel())
                : (root.teamName || root.tournamentName || root.leagueLabel()))
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.showClubFixtures
              ? root.leagueLabel()
              : ((root.showMatches || root.showStats || root.showStandings || root.leagueMode)
                ? (root.leagueMode ? "" : root.teamName)
                : root.leagueLabel())
            color: Qt.darker(root.contentForeground, 1.25)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            visible: text !== ""
          }
        }

        Button {
          id: matchesButton
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(32)
          height: Style.space(32)
          iconText: "󰕲"
          tooltipText: root.leagueMode ? (root.leagueBrowseAll ? "Daily Slate" : "All League Fixtures") : "League Fixtures"
          fontFamily: root.contentFontFamily
          foreground: root.contentForeground
          accent: root.contentForeground
          iconSize: Style.font.body
          horizontalPadding: 0
          verticalPadding: 0
          selected: root.leagueMode ? (!root.showStandings && !root.showStats && root.leagueBrowseAll) : (root.showMatches && !root.showStandings && !root.showStats && !root.showClubFixtures)
          onClicked: {
            root.showMatchDetail = false
            root.showClubFixtures = false
            if (root.leagueMode) {
              if (root.showStandings || root.showStats) {
                root.showStandings = false
                root.showStats = false
                root.leagueBrowseAll = true
              } else {
                root.leagueBrowseAll = !root.leagueBrowseAll
              }
              root.matchWindowOffset = 0
              root.pendingEdge = ""
              root.navAnchorDay = ""
              if (root.matchClusters && root.matchClusters.length > 0) {
                root.matchClusterIndex = root.currentMatchWeekIndex(root.matchClusters)
              }
              root.loadMatchList(true)
              return
            }
            if (root.showStandings || root.showStats) {
              root.showStandings = false
              root.showStats = false
              root.showMatches = true
              root.matchWindowOffset = 0
              root.pendingEdge = ""
              root.navAnchorDay = ""
              if (root.matchClusters && root.matchClusters.length > 0) {
                root.matchClusterIndex = root.currentMatchWeekIndex(root.matchClusters)
              }
              root.loadMatchList(true)
              return
            }
            root.showMatches = !root.showMatches
            if (root.showMatches) {
              root.matchWindowOffset = 0
              root.pendingEdge = ""
              root.navAnchorDay = ""
              if (root.matchClusters && root.matchClusters.length > 0) {
                root.matchClusterIndex = root.currentMatchWeekIndex(root.matchClusters)
              }
              root.loadMatchList(true)
            }
          }
        }
        Button {
          id: standingsButton
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(32)
          height: Style.space(32)
          iconText: "󰕶"
          tooltipText: "League Table"
          fontFamily: root.contentFontFamily
          foreground: root.contentForeground
          accent: root.contentForeground
          iconSize: Style.font.body
          horizontalPadding: 0
          verticalPadding: 0
          selected: root.showStandings
          onClicked: {
            root.showMatchDetail = false
            root.showClubFixtures = false
            root.showStandings = !root.showStandings
            if (root.showStandings) {
              root.showMatches = false
              root.showStats = false
              root.loadStandings()
            } else if (root.leagueMode) {
              // League-follow always lands back on the match board.
              root.showMatches = true
              root.leagueBrowseAll = false
              root.matchWindowOffset = 0
              root.pendingEdge = ""
              root.navAnchorDay = ""
              if (root.matchClusters && root.matchClusters.length > 0) {
                root.matchClusterIndex = root.currentMatchWeekIndex(root.matchClusters)
              }
              if (!matchListRequest.running) root.loadMatchList()
            }
          }
        }
        Button {
          id: statsButton
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(32)
          height: Style.space(32)
          iconText: "󰄪"
          tooltipText: "Stats"
          fontFamily: root.contentFontFamily
          foreground: root.contentForeground
          accent: root.contentForeground
          iconSize: Style.font.body
          horizontalPadding: 0
          verticalPadding: 0
          selected: root.showStats
          onClicked: {
            root.showMatchDetail = false
            root.showClubFixtures = false
            root.showStats = !root.showStats
            if (root.showStats) {
              root.showMatches = false
              root.showStandings = false
              root.loadStats()
            } else if (root.leagueMode) {
              // League-follow always lands back on the match board.
              root.showMatches = true
              root.leagueBrowseAll = false
              root.matchWindowOffset = 0
              root.pendingEdge = ""
              root.navAnchorDay = ""
              if (root.matchClusters && root.matchClusters.length > 0) {
                root.matchClusterIndex = root.currentMatchWeekIndex(root.matchClusters)
              }
              if (!matchListRequest.running) root.loadMatchList()
            }
          }
        }

        Button {
          id: changeTeamButton
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(32)
          height: Style.space(32)
          iconText: "󰒓"
          tooltipText: "Change Team"
          fontFamily: root.contentFontFamily
          foreground: root.contentForeground
          accent: root.contentForeground
          iconSize: Style.font.body
          horizontalPadding: 0
          verticalPadding: 0
          onClicked: {
            root.showClubFixtures = false
            root.openTeamPicker()
          }
        }
      }

      Rectangle {
        width: parent.width
        height: Style.spacing.hairline
        color: root.contentForeground
        opacity: 0.15
      }

      // Match Details View: In-depth information for finished matches
      Column {
        id: matchDetailView
        width: parent.width
        spacing: Style.space(12)
        visible: root.showMatchDetail

        // Back button & header
        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            width: Style.space(26)
            height: Style.space(26)
            iconText: ""
            tooltipText: "Back to matches"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.font.caption
            horizontalPadding: 0
            verticalPadding: 0
            onClicked: root.showMatchDetail = false
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: root.matchDetail ? (root.matchDetail.competitionName || "Match Details") : "Match Details"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
            width: parent.width - Style.space(26 + 8)
          }
        }

        Item {
          width: parent.width
          height: Math.max(Style.space(260), matchDetailInnerCol.implicitHeight)

          Column {
            id: matchDetailInnerCol
            width: parent.width
            spacing: Style.space(12)
            opacity: root.matchDetailLoading ? 0.15 : 1.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // Scoreboard Hero Card
        Item {
          id: heroCard
          width: parent.width
          height: Math.max(Style.space(114), dateTextHeader.implicitHeight + Math.max(scoreCenterCol.implicitHeight, Math.max(homeSideCol.implicitHeight, awaySideCol.implicitHeight)) + (shootoutBottomCol.visible ? shootoutBottomCol.implicitHeight + Style.space(8) : 0) + Style.space(24))

          Rectangle {
            anchors.fill: parent
            radius: Style.space(8)
            color: root.contentForeground
            opacity: 0.05
          }

          Text {
            id: dateTextHeader
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Style.space(8)
            text: root.matchDetail ? (root.matchDetail.dateFormatted || "") : ""
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.NoWrap
            visible: text !== ""
          }

          // Center Score & Status
          Column {
            id: scoreCenterCol
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: (dateTextHeader.visible && dateTextHeader.text !== "") ? dateTextHeader.bottom : parent.top
            anchors.topMargin: (dateTextHeader.visible && dateTextHeader.text !== "") ? Style.space(6) : Style.space(10)
            width: Style.space(90)
            spacing: Style.space(4)

            // Upper area: Score centered between the crests (height: Style.space(50))
            Item {
              width: parent.width
              height: Style.space(50)

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: (root.matchDetail && root.matchDetail.started && root.matchDetail.home && root.matchDetail.away)
                  ? (root.matchDetail.home.score + " – " + root.matchDetail.away.score) : "vs"
                color: (root.matchDetail && !root.matchDetail.started) ? Qt.darker(root.contentForeground, 1.5) : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: (root.matchDetail && !root.matchDetail.started) ? Style.font.body : Style.font.title
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
              }
            }

            // Lower area: Full Time / Status text below the score, aligned with club names
            Column {
              width: parent.width
              spacing: Style.space(2)

              Text {
                id: statusText
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.matchDetail ? (root.matchDetail.status || (root.matchDetail.started ? "Full Time" : "Scheduled")) : "Full Time"
                color: (root.matchDetail && root.matchDetail.isLive) ? "#4ade80" : Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
              }

              Text {
                id: seriesText
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.matchDetail ? (root.matchDetail.shootoutNote === "" ? (root.matchDetail.seriesNote || "") : "") : ""
                color: Qt.darker(root.contentForeground, 1.6)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
              }
            }
          }

          // Home Team (left side)
          Column {
            id: homeSideCol
            anchors.left: parent.left
            anchors.right: scoreCenterCol.left
            anchors.top: scoreCenterCol.top
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(4)

            Image {
              id: homeDetailCrestImg
              anchors.horizontalCenter: parent.horizontalCenter
              width: Style.space(50)
              height: width
              source: root.matchDetail && root.matchDetail.home ? root.matchDetail.home.logo : ""
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              visible: String(source) !== ""
              onStatusChanged: {
                if (status === Image.Ready || status === Image.Error) {
                  if (!root.matchDetailCrestsLoaded && (!awayDetailCrestImg.visible || awayDetailCrestImg.status === Image.Ready || awayDetailCrestImg.status === Image.Error)) {
                    root.matchDetailCrestsLoaded = true
                  }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.matchDetail && root.matchDetail.home ? root.matchDetail.home.name : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Repeater {
              model: (root.matchDetail && root.matchDetail.homeScorers) ? root.matchDetail.homeScorers : []
              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: modelData
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.NoWrap
              }
            }
          }

          // Away Team (right side)
          Column {
            id: awaySideCol
            anchors.left: scoreCenterCol.right
            anchors.right: parent.right
            anchors.top: scoreCenterCol.top
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(4)

            Image {
              id: awayDetailCrestImg
              anchors.horizontalCenter: parent.horizontalCenter
              width: Style.space(50)
              height: width
              source: root.matchDetail && root.matchDetail.away ? root.matchDetail.away.logo : ""
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              visible: String(source) !== ""
              onStatusChanged: {
                if (status === Image.Ready || status === Image.Error) {
                  if (!root.matchDetailCrestsLoaded && (!homeDetailCrestImg.visible || homeDetailCrestImg.status === Image.Ready || homeDetailCrestImg.status === Image.Error)) {
                    root.matchDetailCrestsLoaded = true
                  }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.matchDetail && root.matchDetail.away ? root.matchDetail.away.name : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Repeater {
              model: (root.matchDetail && root.matchDetail.awayScorers) ? root.matchDetail.awayScorers : []
              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: modelData
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.NoWrap
              }
            }
          }

          // Penalty Shootout Result (bottom middle)
          Column {
            id: shootoutBottomCol
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(8)
            spacing: Style.space(1)
            visible: !!(root.matchDetail && (root.matchDetail.shootoutNote !== "" || root.matchDetail.shootoutScore !== "" || (root.matchDetail.shootoutText && root.matchDetail.shootoutText !== "")))

            Text {
              textFormat: Text.PlainText
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.matchDetail ? (root.matchDetail.shootoutText || "After Penalties") : "After Penalties"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              textFormat: Text.PlainText
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.matchDetail ? (root.matchDetail.shootoutScore !== "" ? root.matchDetail.shootoutScore : root.matchDetail.shootoutNote) : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              visible: text !== ""
            }
          }
        }

        // Section Tabs
        Row {
          width: parent.width
          spacing: Style.space(8)
          visible: !!root.matchDetail

          Button {
            height: Style.space(24)
            text: "Stats"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            visible: !!(root.matchDetail && root.matchDetail.started)
            selected: root.matchDetailTab === "stats"
            onClicked: root.matchDetailTab = "stats"
          }

          Button {
            height: Style.space(24)
            text: "Timeline"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            visible: !!(root.matchDetail && root.matchDetail.started && !root.matchDetail.isLive)
            selected: root.matchDetailTab === "events"
            onClicked: root.matchDetailTab = "events"
          }

          Button {
            height: Style.space(24)
            text: "Commentary"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            visible: !!(root.matchDetail && root.matchDetail.isLive && root.matchDetail.commentary && root.matchDetail.commentary.length > 0)
            selected: root.matchDetailTab === "commentary"
            onClicked: root.matchDetailTab = "commentary"
          }

          Button {
            height: Style.space(24)
            text: "Lineups"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            visible: !!root.matchDetail
            selected: root.matchDetailTab === "lineups"
            onClicked: root.matchDetailTab = "lineups"
          }

          Button {
            height: Style.space(24)
            text: "H2H & Form"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            visible: !!(root.matchDetail && ((root.matchDetail.h2h && root.matchDetail.h2h.length > 0) || (root.matchDetail.homeForm && root.matchDetail.homeForm.length > 0) || (root.matchDetail.awayForm && root.matchDetail.awayForm.length > 0)))
            selected: root.matchDetailTab === "h2h"
            onClicked: root.matchDetailTab = "h2h"
          }

          Button {
            height: Style.space(24)
            text: "Info"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            selected: root.matchDetailTab === "info"
            onClicked: root.matchDetailTab = "info"
          }
        }

        // Loading & Error states
        Text {
          textFormat: Text.PlainText
          width: parent.width
          opacity: root.matchDetailLoading ? 0.4 + 0.6 * root._pulse : 1.0
          text: root.matchDetailLoading ? "Fetching match details…" : (root.matchDetailError !== "" ? root.matchDetailError : "")
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          visible: text !== ""
        }

        // Stats Tab
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.matchDetail && root.matchDetail.started && root.matchDetailTab === "stats" && !root.matchDetailLoading

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "No boxscore stats recorded for this match"
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            visible: !root.matchDetail || !root.matchDetail.stats || root.matchDetail.stats.length === 0
          }

          Repeater {
            model: root.matchDetail ? (root.matchDetail.stats || []) : []

            delegate: Column {
              id: statRowItem
              required property var modelData
              width: parent ? parent.width : 0
              spacing: Style.space(2)

              Row {
                width: parent.width

                Text {
                  textFormat: Text.PlainText
                  width: Style.space(50)
                  text: statRowItem.modelData.homeValue
                  color: statRowItem.modelData.homeRatio > 0.5 ? root.statsHomeColor : (statRowItem.modelData.homeRatio < 0.5 ? Qt.darker(root.contentForeground, 1.4) : root.contentForeground)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: statRowItem.modelData.homeRatio > 0.5
                  horizontalAlignment: Text.AlignLeft
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width - Style.space(100)
                  text: statRowItem.modelData.label
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  horizontalAlignment: Text.AlignHCenter
                }

                Text {
                  textFormat: Text.PlainText
                  width: Style.space(50)
                  text: statRowItem.modelData.awayValue
                  color: statRowItem.modelData.homeRatio < 0.5 ? root.statsAwayColor : (statRowItem.modelData.homeRatio > 0.5 ? Qt.darker(root.contentForeground, 1.4) : root.contentForeground)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: statRowItem.modelData.homeRatio < 0.5
                  horizontalAlignment: Text.AlignRight
                }
              }

              // Ultra-thin high-contrast comparative visual line (1.5px)
              Item {
                width: parent.width
                height: 1.5

                // Background track
                Rectangle {
                  anchors.fill: parent
                  radius: 0.75
                  color: root.contentForeground
                  opacity: 0.1
                }

                // Home Bar (Left, Sky Cyan)
                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: Math.max(0, (parent.width - 2) * statRowItem.modelData.homeRatio)
                  radius: 0.75
                  color: root.statsHomeColor
                  visible: width > 0
                }

                // Away Bar (Right, Coral Rose)
                Rectangle {
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: Math.max(0, (parent.width - 2) * (1.0 - statRowItem.modelData.homeRatio))
                  radius: 0.75
                  color: root.statsAwayColor
                  visible: width > 0
                }
              }
            }
          }

          // Match Leaders Section
          Rectangle {
            width: parent.width
            height: leadersCol.implicitHeight + Style.space(20)
            radius: Style.space(8)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
            border.width: 1
            visible: !!(root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders.length > 0)

            Column {
              id: leadersCol
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: "MATCH LEADERS"
                color: Qt.darker(root.contentForeground, 1.6)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption - 1
                font.letterSpacing: 1
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                // Home Leaders
                Column {
                  width: (parent.width - parent.spacing) / 2
                  spacing: Style.space(6)
                  visible: !!(root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders.length > 0)

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders[0] ? root.matchDetail.leaders[0].teamName : "Home"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Repeater {
                    model: (root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders[0]) ? root.matchDetail.leaders[0].categories : []
                    delegate: Column {
                      id: hLeadRow
                      required property var modelData
                      width: parent ? parent.width : 0
                      spacing: Style.space(1)

                      Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        text: hLeadRow.modelData.category
                        color: Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                      }

                      Row {
                        width: parent.width
                        spacing: Style.space(4)

                        Text {
                          textFormat: Text.PlainText
                          width: Math.max(0, parent.width - hLeadVal.implicitWidth - parent.spacing)
                          text: hLeadRow.modelData.player
                          color: Qt.darker(root.contentForeground, 1.15)
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                          elide: Text.ElideRight
                        }

                        Text {
                          id: hLeadVal
                          textFormat: Text.PlainText
                          text: hLeadRow.modelData.value
                          color: root.statsHomeColor
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                        }
                      }
                    }
                  }
                }

                // Away Leaders
                Column {
                  width: (parent.width - parent.spacing) / 2
                  spacing: Style.space(6)
                  visible: !!(root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders.length > 1)

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders[1] ? root.matchDetail.leaders[1].teamName : "Away"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Repeater {
                    model: (root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders[1]) ? root.matchDetail.leaders[1].categories : []
                    delegate: Column {
                      id: aLeadRow
                      required property var modelData
                      width: parent ? parent.width : 0
                      spacing: Style.space(1)

                      Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        text: aLeadRow.modelData.category
                        color: Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                      }

                      Row {
                        width: parent.width
                        spacing: Style.space(4)

                        Text {
                          textFormat: Text.PlainText
                          width: Math.max(0, parent.width - aLeadVal.implicitWidth - parent.spacing)
                          text: aLeadRow.modelData.player
                          color: Qt.darker(root.contentForeground, 1.15)
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                          elide: Text.ElideRight
                        }

                        Text {
                          id: aLeadVal
                          textFormat: Text.PlainText
                          text: aLeadRow.modelData.value
                          color: root.statsAwayColor
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Timeline Tab
        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.matchDetail && root.matchDetail.started && !root.matchDetail.isLive && root.matchDetailTab === "events" && !root.matchDetailLoading

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "No key events available for this match"
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            visible: !root.matchDetail || !root.matchDetail.events || root.matchDetail.events.length === 0
          }

          Flickable {
            id: timelineFlickable
            width: parent.width
            height: Math.min(timelineCol.implicitHeight, Style.space(250))
            contentHeight: timelineCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: root.matchDetail && root.matchDetail.events && root.matchDetail.events.length > 0

            Column {
              id: timelineCol
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.matchDetail ? (root.matchDetail.events || []) : []

                delegate: Item {
                  id: eventRow
                  required property var modelData
                  width: parent ? parent.width : 0
                  height: Math.max(Style.space(28), eventTextCol.implicitHeight + Style.space(6))

                  Rectangle {
                    anchors.fill: parent
                    radius: Style.space(4)
                    color: root.contentForeground
                    opacity: eventRow.modelData.isGoal ? 0.06 : 0.02
                  }

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(4)
                    spacing: Style.space(8)

                    // Minute Pill Box
                    Rectangle {
                      width: Style.space(34)
                      height: Style.space(18)
                      radius: Style.space(3)
                      color: eventRow.modelData.minute !== ""
                        ? (eventRow.modelData.isGoal
                            ? Qt.rgba(root.favoriteTeamAccent.r, root.favoriteTeamAccent.g, root.favoriteTeamAccent.b, 0.18)
                            : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08))
                        : "transparent"
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: eventRow.modelData.minute !== "" ? eventRow.modelData.minute : "—"
                        color: eventRow.modelData.isGoal ? root.favoriteTeamAccent : root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.NoWrap
                      }
                    }

                    // Icon / Badge
                    Item {
                      width: Style.space(18)
                      height: parent.height

                      Rectangle {
                        anchors.centerIn: parent
                        width: Style.space(9)
                        height: Style.space(13)
                        radius: Style.space(2)
                        color: eventRow.modelData.cardColor || "transparent"
                        border.color: eventRow.modelData.cardColor ? (eventRow.modelData.cardColor === "#eab308" ? "#fde047" : "#fca5a5") : "transparent"
                        border.width: 1
                        visible: eventRow.modelData.isCard
                      }

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: eventRow.modelData.glyph
                        color: eventRow.modelData.isGoal ? root.favoriteTeamAccent : root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                        visible: !eventRow.modelData.isCard
                      }
                    }

                    // Description
                    Column {
                      id: eventTextCol
                      width: parent.width - Style.space(34 + 18 + 16)
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        text: eventRow.modelData.text
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Commentary Tab
        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.matchDetail && root.matchDetail.isLive && root.matchDetailTab === "commentary" && !root.matchDetailLoading

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "No live commentary available for this match"
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            visible: !root.matchDetail || !root.matchDetail.commentary || root.matchDetail.commentary.length === 0
          }

          Flickable {
            id: commFlickable
            width: parent.width
            height: Math.min(commCol.implicitHeight, Style.space(320))
            contentHeight: commCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: root.matchDetail && root.matchDetail.commentary && root.matchDetail.commentary.length > 0

            Column {
              id: commCol
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.matchDetail ? (root.matchDetail.commentary || []) : []

                delegate: Rectangle {
                  id: commItem
                  required property var modelData
                  width: parent ? parent.width : 0
                  height: commTextCol.implicitHeight + Style.space(12)
                  radius: Style.space(6)
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)

                  Row {
                    id: commTextCol
                    anchors.fill: parent
                    anchors.margins: Style.space(6)
                    spacing: Style.space(8)

                    Rectangle {
                      width: Style.space(34)
                      height: Style.space(18)
                      radius: Style.space(3)
                      color: commItem.modelData.time !== "" ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"
                      anchors.top: parent.top

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: commItem.modelData.time
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                        visible: text !== ""
                      }
                    }

                    Text {
                      textFormat: Text.PlainText
                      width: parent.width - Style.space(42)
                      anchors.top: parent.top
                      text: commItem.modelData.text
                      color: Qt.darker(root.contentForeground, 1.2)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption - 1
                      wrapMode: Text.WordWrap
                    }
                  }
                }
              }
            }
          }
        }

        // Lineups Tab
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.matchDetail && root.matchDetailTab === "lineups" && !root.matchDetailLoading

          // Team Selector Bar (Home Team vs Away Team)
          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - parent.spacing) / 2
              height: Style.space(28)
              text: {
                var name = root.matchDetail && root.matchDetail.home ? root.matchDetail.home.name : "Home"
                var form = root.matchDetail && root.matchDetail.lineups && root.matchDetail.lineups.homeFormation ? (" (" + root.matchDetail.lineups.homeFormation + ")") : ""
                return name + form
              }
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.statsHomeColor
              fontSize: Style.font.caption
              horizontalPadding: Style.space(6)
              verticalPadding: 0
              selected: root.matchDetailLineupTeam === "home"
              onClicked: root.matchDetailLineupTeam = "home"
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              height: Style.space(28)
              text: {
                var name = root.matchDetail && root.matchDetail.away ? root.matchDetail.away.name : "Away"
                var form = root.matchDetail && root.matchDetail.lineups && root.matchDetail.lineups.awayFormation ? (" (" + root.matchDetail.lineups.awayFormation + ")") : ""
                return name + form
              }
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.statsAwayColor
              fontSize: Style.font.caption
              horizontalPadding: Style.space(6)
              verticalPadding: 0
              selected: root.matchDetailLineupTeam === "away"
              onClicked: root.matchDetailLineupTeam = "away"
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "Lineups not yet announced for this match"
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            visible: !!(!root.matchDetail || !root.matchDetail.lineups || !root.matchDetail.lineups.available)
          }

          Flickable {
            id: lineupFlickable
            width: parent.width
            height: Math.min(lineupCol.implicitHeight, Style.space(390))
            contentHeight: lineupCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: !!(root.matchDetail && root.matchDetail.lineups && root.matchDetail.lineups.available)

            Column {
              id: lineupCol
              width: parent.width
              spacing: Style.space(8)

              // Tactical Pitch View
              Rectangle {
                id: pitchField
                width: parent.width
                height: Style.space(370)
                radius: Style.space(8)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.025)
                clip: true
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                border.width: 1

                // Subtle transparent zone stripes
                Column {
                  anchors.fill: parent
                  Repeater {
                    model: 5
                    Rectangle {
                      width: pitchField.width
                      height: pitchField.height / 5
                      color: index % 2 === 0 ? "transparent" : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.015)
                    }
                  }
                }

                // Halfway line through the middle
                Rectangle {
                  width: parent.width
                  height: 1
                  anchors.verticalCenter: parent.verticalCenter
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                }

                // Center circle
                Rectangle {
                  width: Style.space(76)
                  height: width
                  radius: width / 2
                  anchors.centerIn: parent
                  color: "transparent"
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                  border.width: 1
                }

                // Center spot
                Rectangle {
                  width: 4
                  height: 4
                  radius: 2
                  anchors.centerIn: parent
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.22)
                }

                // Corner arcs
                Rectangle {
                  width: Style.space(18)
                  height: width
                  radius: width
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.topMargin: -width / 2
                  anchors.leftMargin: -width / 2
                  color: "transparent"
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                  border.width: 1
                }
                Rectangle {
                  width: Style.space(18)
                  height: width
                  radius: width
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.topMargin: -width / 2
                  anchors.rightMargin: -width / 2
                  color: "transparent"
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                  border.width: 1
                }
                Rectangle {
                  width: Style.space(18)
                  height: width
                  radius: width
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left
                  anchors.bottomMargin: -width / 2
                  anchors.leftMargin: -width / 2
                  color: "transparent"
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                  border.width: 1
                }
                Rectangle {
                  width: Style.space(18)
                  height: width
                  radius: width
                  anchors.bottom: parent.bottom
                  anchors.right: parent.right
                  anchors.bottomMargin: -width / 2
                  anchors.rightMargin: -width / 2
                  color: "transparent"
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                  border.width: 1
                }

                // Bottom penalty box
                Rectangle {
                  width: Style.space(160)
                  height: Style.space(55)
                  anchors.bottom: parent.bottom
                  anchors.horizontalCenter: parent.horizontalCenter
                  color: "transparent"
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                  border.width: 1
                }

                // Bottom goal area
                Rectangle {
                  width: Style.space(76)
                  height: Style.space(20)
                  anchors.bottom: parent.bottom
                  anchors.horizontalCenter: parent.horizontalCenter
                  color: "transparent"
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                  border.width: 1
                }

                // Bottom penalty arc
                Rectangle {
                  width: Style.space(48)
                  height: width
                  radius: width / 2
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.space(35)
                  color: "transparent"
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                  border.width: 1
                }

                // Top penalty box
                Rectangle {
                  width: Style.space(160)
                  height: Style.space(55)
                  anchors.top: parent.top
                  anchors.horizontalCenter: parent.horizontalCenter
                  color: "transparent"
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                  border.width: 1
                }

                // Top goal area
                Rectangle {
                  width: Style.space(76)
                  height: Style.space(20)
                  anchors.top: parent.top
                  anchors.horizontalCenter: parent.horizontalCenter
                  color: "transparent"
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                  border.width: 1
                }

                // Top penalty arc
                Rectangle {
                  width: Style.space(48)
                  height: width
                  radius: width / 2
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.top: parent.top
                  anchors.topMargin: Style.space(35)
                  color: "transparent"
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                  border.width: 1
                }

                // Circular Player Nodes
                Repeater {
                  model: (root.matchDetail && root.matchDetail.lineups) ? root.layoutPitchPlayers(
                    root.matchDetailLineupTeam === "home" ? root.matchDetail.lineups.homeFormation : root.matchDetail.lineups.awayFormation,
                    root.matchDetailLineupTeam === "home" ? root.matchDetail.lineups.homeStarters : root.matchDetail.lineups.awayStarters
                  ) : []

                  delegate: Item {
                    id: pitchPlayerItem
                    required property var modelData
                    width: Style.space(64)
                    height: Style.space(50)
                    z: (pitchPlayerItem.modelData.goals > 0 || pitchPlayerItem.modelData.assists > 0 ? 30 : 10) + Math.round((1.0 - pitchPlayerItem.modelData.y) * 20)
                    x: (pitchField.width * pitchPlayerItem.modelData.x) - (width / 2)
                    y: (pitchField.height * pitchPlayerItem.modelData.y) - (jerseyContainer.height / 2)

                    // Main full-resolution athlete jersey image
                    Item {
                      id: jerseyContainer
                      width: Style.space(34)
                      height: Style.space(34)
                      anchors.horizontalCenter: parent.horizontalCenter

                      Image {
                        id: playerJerseyImg
                        anchors.fill: parent
                        source: pitchPlayerItem.modelData.jerseyImage !== "" ? pitchPlayerItem.modelData.jerseyImage : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        sourceSize.width: Style.space(68)
                        sourceSize.height: Style.space(68)
                        mipmap: true
                        smooth: true
                        visible: status === Image.Ready
                      }

                      // Fallback: when jersey image is not loaded or missing
                      Rectangle {
                        anchors.centerIn: parent
                        width: Style.space(22)
                        height: Style.space(22)
                        radius: Style.space(4)
                        color: root.matchDetailLineupTeam === "home" ? root.statsHomeColor : root.statsAwayColor
                        border.color: Qt.lighter(root.matchDetailLineupTeam === "home" ? root.statsHomeColor : root.statsAwayColor, 1.4)
                        border.width: 1
                        visible: playerJerseyImg.status !== Image.Ready

                        Text {
                          textFormat: Text.PlainText
                          anchors.centerIn: parent
                          text: pitchPlayerItem.modelData.jersey !== "" ? pitchPlayerItem.modelData.jersey : "—"
                          color: "#ffffff"
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                      }
                    }

                    // 1. Goals (Top-Right of Jersey - Overlapping Badges, White Icon)
                    Row {
                      id: goalOverlapRow
                      anchors.top: jerseyContainer.top
                      anchors.right: jerseyContainer.right
                      anchors.topMargin: -Style.space(3)
                      anchors.rightMargin: -Style.space(4)
                      spacing: -Style.space(4)
                      z: 20
                      visible: !!(pitchPlayerItem.modelData.goals && pitchPlayerItem.modelData.goals > 0)

                      Repeater {
                        model: Math.min(5, pitchPlayerItem.modelData.goals || 0)
                        Rectangle {
                          width: Style.space(13)
                          height: Style.space(13)
                          radius: width / 2
                          color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
                          border.color: Qt.rgba(1, 1, 1, 0.3)
                          border.width: 0.7
                          z: 20 - index

                          Text {
                            textFormat: Text.PlainText
                            anchors.centerIn: parent
                            text: ""
                            color: "#ffffff"
                            font.family: "Symbols Nerd Font, " + root.contentFontFamily
                            font.pixelSize: Style.font.caption - 3
                            font.bold: true
                          }
                        }
                      }
                    }

                    // 2. Assists (Top-Left of Jersey - Overlapping Boot Badges, White Icon)
                    Row {
                      id: assistOverlapRow
                      anchors.top: jerseyContainer.top
                      anchors.left: jerseyContainer.left
                      anchors.topMargin: -Style.space(3)
                      anchors.leftMargin: -Style.space(4)
                      spacing: -Style.space(4)
                      z: 20
                      visible: !!(pitchPlayerItem.modelData.assists && pitchPlayerItem.modelData.assists > 0)

                      Repeater {
                        model: Math.min(5, pitchPlayerItem.modelData.assists || 0)
                        Rectangle {
                          width: Style.space(13)
                          height: Style.space(13)
                          radius: width / 2
                          color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
                          border.color: Qt.rgba(1, 1, 1, 0.3)
                          border.width: 0.7
                          z: 20 - index

                          Text {
                            textFormat: Text.PlainText
                            anchors.centerIn: parent
                            text: "󱗇"
                            rotation: 45
                            transformOrigin: Item.Center
                            color: "#ffffff"
                            font.family: "Symbols Nerd Font, " + root.contentFontFamily
                            font.pixelSize: Style.font.caption - 3
                            font.bold: true
                          }
                        }
                      }
                    }

                    // 3. Substitute Out Badge (Bottom-Right - White ▼)
                    Rectangle {
                      id: subBadge
                      width: Style.space(13)
                      height: Style.space(13)
                      radius: width / 2
                      anchors.bottom: jerseyContainer.bottom
                      anchors.right: jerseyContainer.right
                      anchors.bottomMargin: -Style.space(2)
                      anchors.rightMargin: -Style.space(3)
                      color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
                      border.color: Qt.rgba(1, 1, 1, 0.3)
                      border.width: 0.7
                      z: 20
                      visible: !!pitchPlayerItem.modelData.subbedOut

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: "▼"
                        color: "#ffffff"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                      }
                    }

                    // 4. Card Badge (Bottom-Left - Yellow / Red Card)
                    Rectangle {
                      id: cardBadge
                      width: Style.space(7)
                      height: Style.space(10)
                      radius: 1
                      anchors.bottom: jerseyContainer.bottom
                      anchors.left: jerseyContainer.left
                      anchors.bottomMargin: -Style.space(1)
                      anchors.leftMargin: -Style.space(3)
                      color: (pitchPlayerItem.modelData.redCards && pitchPlayerItem.modelData.redCards > 0) ? "#ef4444" : "#eab308"
                      border.color: "#ffffff"
                      border.width: 0.8
                      z: 20
                      visible: !!((pitchPlayerItem.modelData.redCards && pitchPlayerItem.modelData.redCards > 0) || (pitchPlayerItem.modelData.yellowCards && pitchPlayerItem.modelData.yellowCards > 0))
                    }

                    // 5. Rating Badge (Centre Bottom)
                    Rectangle {
                      id: ratingBadge
                      height: Style.space(12)
                      width: ratingText.implicitWidth + Style.space(6)
                      radius: Style.space(3)
                      anchors.top: jerseyContainer.bottom
                      anchors.topMargin: -Style.space(4)
                      anchors.horizontalCenter: jerseyContainer.horizontalCenter
                      color: root.ratingColor(pitchPlayerItem.modelData.rating)
                      border.color: "#ffffff"
                      border.width: 0.8
                      z: 20
                      visible: !!(pitchPlayerItem.modelData.rating !== null && pitchPlayerItem.modelData.rating !== undefined)

                      Text {
                        id: ratingText
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: pitchPlayerItem.modelData.rating ? Number(pitchPlayerItem.modelData.rating).toFixed(1) : ""
                        color: "#ffffff"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 3
                        font.bold: true
                      }
                    }

                    // Sleek dark pill for player name
                    Rectangle {
                      anchors.top: ratingBadge.visible ? ratingBadge.bottom : jerseyContainer.bottom
                      anchors.topMargin: Style.space(2)
                      anchors.horizontalCenter: parent.horizontalCenter
                      width: Math.min(parent.width, Math.max(Style.space(32), pitchNameText.implicitWidth + Style.space(8)))
                      height: Style.space(13)
                      radius: Style.space(3)
                      color: Qt.rgba(0, 0, 0, 0.75)
                      border.color: Qt.rgba(1, 1, 1, 0.15)
                      border.width: 0.5
                      clip: true

                      Text {
                        id: pitchNameText
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        width: parent.width - Style.space(6)
                        text: pitchPlayerItem.modelData.shortName !== "" ? pitchPlayerItem.modelData.shortName : pitchPlayerItem.modelData.name
                        color: "#ffffff"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
              }

              // Starting XI Section List
              Text {
                textFormat: Text.PlainText
                text: "STARTING XI (" + (root.matchDetail && root.matchDetail.lineups ? (root.matchDetailLineupTeam === "home" ? (root.matchDetail.lineups.homeStarters || []).length : (root.matchDetail.lineups.awayStarters || []).length) : 0) + ")"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.bold: true
              }

              Repeater {
                model: root.matchDetail && root.matchDetail.lineups ? (root.matchDetailLineupTeam === "home" ? root.matchDetail.lineups.homeStarters : root.matchDetail.lineups.awayStarters) : []

                delegate: Item {
                  id: starterRow
                  required property var modelData
                  width: parent ? parent.width : 0
                  height: Style.space(26)

                  Rectangle {
                    anchors.fill: parent
                    radius: Style.space(4)
                    color: root.contentForeground
                    opacity: 0.02
                  }

                  Row {
                    id: starterRowContent
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(6)
                    anchors.rightMargin: Style.space(6)
                    spacing: Style.space(6)

                    // Player Jersey Image
                    Item {
                      id: starterJerseyBox
                      width: Style.space(24)
                      height: Style.space(24)
                      anchors.verticalCenter: parent.verticalCenter

                      Image {
                        id: starterJerseyImg
                        anchors.fill: parent
                        source: starterRow.modelData.jerseyImage !== "" ? starterRow.modelData.jerseyImage : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        sourceSize.width: Style.space(48)
                        sourceSize.height: Style.space(48)
                        mipmap: true
                        smooth: true
                        visible: status === Image.Ready
                      }

                      Rectangle {
                        anchors.centerIn: parent
                        width: Style.space(20)
                        height: Style.space(20)
                        radius: Style.space(3)
                        color: root.contentForeground
                        opacity: 0.08
                        visible: starterJerseyImg.status !== Image.Ready

                        Text {
                          textFormat: Text.PlainText
                          anchors.centerIn: parent
                          text: starterRow.modelData.jersey !== "" ? starterRow.modelData.jersey : "—"
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                        }
                      }
                    }

                    // Rating Pill (if available)
                    Rectangle {
                      width: starterRatingTxt.implicitWidth + Style.space(6)
                      height: Style.space(16)
                      anchors.verticalCenter: parent.verticalCenter
                      radius: Style.space(3)
                      color: root.ratingColor(starterRow.modelData.rating)
                      visible: !!(starterRow.modelData.rating !== null && starterRow.modelData.rating !== undefined)

                      Text {
                        id: starterRatingTxt
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: starterRow.modelData.rating ? Number(starterRow.modelData.rating).toFixed(1) : ""
                        color: "#ffffff"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                      }
                    }

                    // Player Name
                    Text {
                      textFormat: Text.PlainText
                      width: Math.max(0, parent.width - starterJerseyBox.width - (starterRow.modelData.rating ? (starterRatingTxt.implicitWidth + Style.space(12)) : 0) - starterPosText.implicitWidth - parent.spacing * 3)
                      anchors.verticalCenter: parent.verticalCenter
                      text: starterRow.modelData.name
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      elide: Text.ElideRight
                    }

                    // Position
                    Text {
                      id: starterPosText
                      textFormat: Text.PlainText
                      anchors.verticalCenter: parent.verticalCenter
                      text: starterRow.modelData.position
                      color: Qt.darker(root.contentForeground, 1.4)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                    }
                  }
                }
              }

              // Substitutes Section
              Item { width: 1; height: Style.space(4) }

              Text {
                textFormat: Text.PlainText
                text: "SUBSTITUTES (" + (root.matchDetail && root.matchDetail.lineups ? (root.matchDetailLineupTeam === "home" ? (root.matchDetail.lineups.homeSubs || []).length : (root.matchDetail.lineups.awaySubs || []).length) : 0) + ")"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.bold: true
                visible: !!(root.matchDetail && root.matchDetail.lineups && ((root.matchDetailLineupTeam === "home" ? (root.matchDetail.lineups.homeSubs || []).length : (root.matchDetail.lineups.awaySubs || []).length) > 0))
              }

              Repeater {
                model: root.matchDetail && root.matchDetail.lineups ? (root.matchDetailLineupTeam === "home" ? root.matchDetail.lineups.homeSubs : root.matchDetail.lineups.awaySubs) : []

                delegate: Item {
                  id: subRow
                  required property var modelData
                  width: parent ? parent.width : 0
                  height: Style.space(26)

                  Rectangle {
                    anchors.fill: parent
                    radius: Style.space(4)
                    color: root.contentForeground
                    opacity: 0.02
                  }

                  Row {
                    id: subRowContent
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(6)
                    anchors.rightMargin: Style.space(6)
                    spacing: Style.space(6)

                    // Player Jersey Image
                    Item {
                      id: subJerseyBox
                      width: Style.space(24)
                      height: Style.space(24)
                      anchors.verticalCenter: parent.verticalCenter

                      Image {
                        id: subJerseyImg
                        anchors.fill: parent
                        source: subRow.modelData.jerseyImage !== "" ? subRow.modelData.jerseyImage : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        sourceSize.width: Style.space(48)
                        sourceSize.height: Style.space(48)
                        mipmap: true
                        smooth: true
                        visible: status === Image.Ready
                      }

                      Rectangle {
                        anchors.centerIn: parent
                        width: Style.space(20)
                        height: Style.space(20)
                        radius: Style.space(3)
                        color: root.contentForeground
                        opacity: 0.08
                        visible: subJerseyImg.status !== Image.Ready

                        Text {
                          textFormat: Text.PlainText
                          anchors.centerIn: parent
                          text: subRow.modelData.jersey !== "" ? subRow.modelData.jersey : "—"
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                        }
                      }
                    }

                    // Rating Pill (if available)
                    Rectangle {
                      width: subRatingTxt.implicitWidth + Style.space(6)
                      height: Style.space(16)
                      anchors.verticalCenter: parent.verticalCenter
                      radius: Style.space(3)
                      color: root.ratingColor(subRow.modelData.rating)
                      visible: !!(subRow.modelData.rating !== null && subRow.modelData.rating !== undefined)

                      Text {
                        id: subRatingTxt
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: subRow.modelData.rating ? Number(subRow.modelData.rating).toFixed(1) : ""
                        color: "#ffffff"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                      }
                    }

                    // Player Name
                    Text {
                      textFormat: Text.PlainText
                      width: Math.max(0, parent.width - subJerseyBox.width - (subRow.modelData.rating ? (subRatingTxt.implicitWidth + Style.space(12)) : 0) - subPosText.implicitWidth - subEventIcons.implicitWidth - parent.spacing * 4)
                      anchors.verticalCenter: parent.verticalCenter
                      text: subRow.modelData.name
                      color: Qt.darker(root.contentForeground, 1.2)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }

                    // Event Icons (Goals, Assists, Cards, Subs - ESPN Format)
                    Text {
                      id: subEventIcons
                      textFormat: Text.PlainText
                      anchors.verticalCenter: parent.verticalCenter
                      text: subRow.modelData.eventsText || ""
                      color: root.contentForeground
                      font.family: "Symbols Nerd Font, " + root.contentFontFamily
                      font.pixelSize: Style.font.caption - 2
                      visible: text !== ""
                    }

                    // Position
                    Text {
                      id: subPosText
                      textFormat: Text.PlainText
                      anchors.verticalCenter: parent.verticalCenter
                      text: subRow.modelData.position
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                    }
                  }
                }
              }
            }
          }
        }

        // H2H & Form Tab
        Column {
          width: parent.width
          spacing: Style.space(12)
          visible: root.matchDetail && root.matchDetailTab === "h2h" && !root.matchDetailLoading

          // 1. RECENT FORM CARD
          Rectangle {
            width: parent.width
            height: formCardCol.implicitHeight + Style.space(20)
            radius: Style.space(8)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
            border.width: 1
            visible: !!(root.matchDetail && ((root.matchDetail.homeForm && root.matchDetail.homeForm.length > 0) || (root.matchDetail.awayForm && root.matchDetail.awayForm.length > 0)))

            Column {
              id: formCardCol
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(10)

              Text {
                textFormat: Text.PlainText
                text: "FORM GUIDE (LAST 5 MATCHES)"
                color: Qt.darker(root.contentForeground, 1.6)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption - 1
                font.letterSpacing: 1
                font.bold: true
              }

              // Home Form Row
              Row {
                width: parent.width
                spacing: Style.space(8)
                visible: !!(root.matchDetail && root.matchDetail.homeForm && root.matchDetail.homeForm.length > 0)

                Image {
                  width: Style.space(22)
                  height: width
                  source: (root.matchDetail && root.matchDetail.home) ? root.matchDetail.home.logo : ""
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: 64
                  sourceSize.height: 64
                  mipmap: true
                  smooth: true
                  anchors.verticalCenter: parent.verticalCenter
                  visible: String(source) !== ""
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width - (parent.spacing * 2) - Style.space(22) - Style.space(120)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.matchDetail && root.matchDetail.home ? root.matchDetail.home.name : "Home"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                }

                Row {
                  spacing: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter

                  Repeater {
                    model: root.matchDetail ? (root.matchDetail.homeForm || []) : []
                    delegate: Rectangle {
                      id: hFormPill
                      required property var modelData
                      width: Style.space(20)
                      height: Style.space(20)
                      radius: Style.space(4)
                      color: modelData.result === "W" ? "#16a34a" : (modelData.result === "D" ? "#475569" : "#dc2626")

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: hFormPill.modelData.result
                        color: "#ffffff"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                      }
                    }
                  }
                }
              }

              // Divider
              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: root.contentForeground
                opacity: 0.1
                visible: !!(root.matchDetail && root.matchDetail.homeForm && root.matchDetail.homeForm.length > 0 && root.matchDetail.awayForm && root.matchDetail.awayForm.length > 0)
              }

              // Away Form Row
              Row {
                width: parent.width
                spacing: Style.space(8)
                visible: !!(root.matchDetail && root.matchDetail.awayForm && root.matchDetail.awayForm.length > 0)

                Image {
                  width: Style.space(22)
                  height: width
                  source: (root.matchDetail && root.matchDetail.away) ? root.matchDetail.away.logo : ""
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: 64
                  sourceSize.height: 64
                  mipmap: true
                  smooth: true
                  anchors.verticalCenter: parent.verticalCenter
                  visible: String(source) !== ""
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width - (parent.spacing * 2) - Style.space(22) - Style.space(120)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.matchDetail && root.matchDetail.away ? root.matchDetail.away.name : "Away"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                }

                Row {
                  spacing: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter

                  Repeater {
                    model: root.matchDetail ? (root.matchDetail.awayForm || []) : []
                    delegate: Rectangle {
                      id: aFormPill
                      required property var modelData
                      width: Style.space(20)
                      height: Style.space(20)
                      radius: Style.space(4)
                      color: modelData.result === "W" ? "#16a34a" : (modelData.result === "D" ? "#475569" : "#dc2626")

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: aFormPill.modelData.result
                        color: "#ffffff"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                      }
                    }
                  }
                }
              }
            }
          }

          // 2. HEAD-TO-HEAD HISTORY CARD
          Rectangle {
            width: parent.width
            height: h2hCardCol.implicitHeight + Style.space(20)
            radius: Style.space(8)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
            border.width: 1
            visible: !!(root.matchDetail && root.matchDetail.h2h && root.matchDetail.h2h.length > 0)

            Column {
              id: h2hCardCol
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(10)

              Item {
                width: parent.width
                height: Math.max(h2hTitleTxt.implicitHeight, h2hSumTxt.implicitHeight)

                Text {
                  id: h2hTitleTxt
                  textFormat: Text.PlainText
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "HEAD-TO-HEAD"
                  color: Qt.darker(root.contentForeground, 1.6)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.letterSpacing: 1
                  font.bold: true
                }

                Text {
                  id: h2hSumTxt
                  textFormat: Text.PlainText
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.matchDetail ? root.h2hSummary(root.matchDetail.h2h, root.matchDetail.home ? root.matchDetail.home.name : "", root.matchDetail.away ? root.matchDetail.away.name : "") : ""
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                  visible: text !== ""
                }
              }

              // List of H2H Matches
              Column {
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                  model: root.matchDetail ? (root.matchDetail.h2h || []) : []
                  delegate: Column {
                    id: h2hRow
                    required property var modelData
                    width: parent ? parent.width : 0
                    spacing: Style.space(3)

                    // Match Header (Date & Competition)
                    Text {
                      textFormat: Text.PlainText
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      text: (h2hRow.modelData.competition !== "" ? (h2hRow.modelData.competition + " · ") : "") + h2hRow.modelData.dateFormatted
                      color: Qt.darker(root.contentForeground, 1.8)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption - 2
                      elide: Text.ElideRight
                    }

                    // Match Score Line
                    Row {
                      width: parent.width
                      spacing: Style.space(8)

                      Text {
                        textFormat: Text.PlainText
                        width: (parent.width - parent.spacing * 2 - Style.space(56)) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: h2hRow.modelData.home
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                      }

                      Rectangle {
                        width: Style.space(56)
                        height: Style.space(20)
                        radius: Style.space(4)
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)

                        Text {
                          textFormat: Text.PlainText
                          anchors.centerIn: parent
                          text: h2hRow.modelData.homeScore + " – " + h2hRow.modelData.awayScore
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                      }

                      Text {
                        textFormat: Text.PlainText
                        width: (parent.width - parent.spacing * 2 - Style.space(56)) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                        text: h2hRow.modelData.away
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                      }
                    }

                    Rectangle {
                      width: parent.width
                      height: Style.spacing.hairline
                      color: root.contentForeground
                      opacity: 0.08
                    }
                  }
                }
              }
            }
          }
        }

        // Info Tab (stadium, referee, broadcast, odds, editorial recap)
        Column {
          width: parent.width
          spacing: Style.space(10)
          visible: (root.matchDetailTab === "info") && !root.matchDetailLoading

          // Venue
          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.matchDetail && root.matchDetail.info && root.matchDetail.info.venue !== ""

            Text {
              textFormat: Text.PlainText
              width: Style.space(70)
              text: "Stadium"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width - Style.space(78)
              text: root.matchDetail && root.matchDetail.info ? root.matchDetail.info.venue : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // Attendance
          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.matchDetail && root.matchDetail.info && root.matchDetail.info.attendance !== ""

            Text {
              textFormat: Text.PlainText
              width: Style.space(70)
              text: "Attendance"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width - Style.space(78)
              text: root.matchDetail && root.matchDetail.info ? root.matchDetail.info.attendance : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // Officials
          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.matchDetail && root.matchDetail.info && root.matchDetail.info.officials !== ""

            Text {
              textFormat: Text.PlainText
              width: Style.space(70)
              text: "Referee"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width - Style.space(78)
              text: root.matchDetail && root.matchDetail.info ? root.matchDetail.info.officials : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // Match Betting Odds (upcoming/live only, hidden once match is finished)
          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: !!(root.matchDetail && root.matchDetail.odds && (!root.matchDetail.started || root.matchDetail.isLive))

            Text {
              textFormat: Text.PlainText
              text: "MATCH ODDS (" + (root.matchDetail && root.matchDetail.odds ? root.matchDetail.odds.provider : "ODDS") + ")"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Rectangle {
                width: (parent.width - Style.space(16)) / 3
                height: Style.space(42)
                radius: Style.space(6)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(2)

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Spread"
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption - 2
                  }

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (root.matchDetail && root.matchDetail.odds && root.matchDetail.odds.spread !== "") ? root.matchDetail.odds.spread : "—"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              Rectangle {
                width: (parent.width - Style.space(16)) / 3
                height: Style.space(42)
                radius: Style.space(6)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(2)

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Over/Under"
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption - 2
                  }

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (root.matchDetail && root.matchDetail.odds && root.matchDetail.odds.overUnder !== "") ? root.matchDetail.odds.overUnder : "—"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              Rectangle {
                width: (parent.width - Style.space(16)) / 3
                height: Style.space(42)
                radius: Style.space(6)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(2)

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Line"
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption - 2
                  }

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (root.matchDetail && root.matchDetail.odds && root.matchDetail.odds.details !== "") ? root.matchDetail.odds.details : "—"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }
          }
        }
          }

          LoadingOverlay {
            active: root.matchDetailLoading
            text: "Fetching match details…"
          }
        }
      }

      Column {
        id: standingsView
        width: parent.width
        spacing: Style.space(12)
        visible: root.showStandings && !root.showMatchDetail

        Item {
          width: parent.width
          height: Math.max(Style.space(260), standingsInnerCol.implicitHeight)

          Column {
            id: standingsInnerCol
            width: parent.width
            spacing: Style.space(12)
            opacity: root.standingsLoading ? 0.15 : 1.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Row {
              width: parent.width
              spacing: Style.space(8)

          Button {
            id: prevSeasonButton
            width: Style.space(22)
            height: Style.space(22)
            iconText: ""
            tooltipText: "Older season"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.font.caption
            horizontalPadding: 0
            verticalPadding: 0
            onClicked: {
              root.standingsSeasonOffset++
              root.loadStandings()
            }
          }

          Button {
            id: seasonChip
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(52)
            height: Style.space(22)
            text: root.seasonChipLabel(root.standingsSeasonOffset)
            tooltipText: "Standings season"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: 0
            verticalPadding: 0
            onClicked: {
              root.standingsSeasonOffset = 0
              root.loadStandings()
            }
          }

          Button {
            id: nextSeasonButton
            width: Style.space(22)
            height: Style.space(22)
            iconText: ""
            tooltipText: "Newer season"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.font.caption
            horizontalPadding: 0
            verticalPadding: 0
            enabled: root.standingsSeasonOffset > 0
            opacity: enabled ? 1 : 0.35
            onClicked: {
              root.standingsSeasonOffset--
              root.loadStandings()
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(6)
          visible: root.standingsGroups.length > 1

          Repeater {
            model: root.standingsGroups

            Button {
              height: Style.space(24)
              text: root.sanitizePlainText(String(modelData.name || modelData.shortName || ""))
              tooltipText: root.sanitizePlainText(String(modelData.name || ""))
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(10)
              verticalPadding: 0
              selected: root.standingsGroupIndex === index
              onClicked: root.standingsGroupIndex = index
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          opacity: root.standingsLoading ? 0.4 + 0.6 * root._pulse : 1.0
          text: root.standingsLoading ? "Fetching standings…"
            : (root.standingsError !== "" ? root.standingsError
            : (root.standings.length === 0 ? "No standings available" : ""))
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          visible: text !== ""
        }

        Flickable {
          id: standingsTable
          width: parent.width
          // Full table, no internal scrolling: every position visible.
          height: headerRow.implicitHeight + root.standings.length * standingsRowHeight
          clip: true
          interactive: false
          contentHeight: headerRow.implicitHeight + root.standings.length * standingsRowHeight
          visible: root.standings.length > 0

          Column {
            width: parent.width
            spacing: 0

            Row {
              id: headerRow
              width: parent.width
              height: Style.space(26)
              Text { textFormat: Text.PlainText; width: standingsRankWidth; height: parent.height; text: "#"; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
              Item { width: standingsRankGap; height: 1 }
              Item { width: standingsLogoWidth; height: 1 }
              Text { textFormat: Text.PlainText; width: standingsTeamWidth; height: parent.height; text: "Team"; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true; verticalAlignment: Text.AlignVCenter }
              Repeater {
                model: root.standingsColumns
                Text {
                  textFormat: Text.PlainText
                  width: root.standingsStatWidth; height: parent.height
                  text: modelData.label
                  color: Qt.darker(root.contentForeground, 1.6)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  horizontalAlignment: Text.AlignRight
                  verticalAlignment: Text.AlignVCenter
                }
              }
            }

            Repeater {
              model: root.standings
              width: parent.width

              Rectangle {
                id: rowRect
                readonly property var entry: modelData
                readonly property bool favorite: root.isFavoriteStanding(modelData)
                readonly property color zoneColor: root.standingsZoneColor(modelData)
                readonly property bool hasZone: root.standingsZoneFor(modelData) !== ""
                // A zoned row is tinted with its zone color; otherwise the
                // favorite theme accent is used. The zone bar is the single
                // left indicator — the theme bar only shows for a favorite
                // that has no qualification zone (avoiding two stacked bars).
                readonly property color rowAccent: favorite
                  ? (hasZone ? zoneColor : root.favoriteTeamAccent) : "transparent"
                readonly property color rowTint: favorite
                  ? (hasZone ? Util.alpha(zoneColor, 0.45) : root.favoriteTeamTint) : "transparent"
                width: parent.width
                height: standingsRowHeight
                radius: Style.cornerRadius
                color: rowTint

                Rectangle {
                  id: zoneBar
                  visible: rowRect.hasZone
                  width: 3
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left
                  radius: 1
                  color: rowRect.zoneColor
                }

                Rectangle {
                  id: zoneFavoriteThemeBar
                  visible: rowRect.favorite && !rowRect.hasZone
                  width: 3
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left
                  radius: 1
                  color: root.favoriteTeamAccent
                }

                Row {
                  width: parent.width
                  height: parent.height

                  Text {
                    textFormat: Text.PlainText
                    width: standingsRankWidth; height: parent.height
                    text: rowRect.entry.rank
                    color: rowRect.favorite ? rowRect.rowAccent : Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: rowRect.favorite
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                  }
                  Item { width: standingsRankGap; height: 1 }
                  Image {
                    width: standingsLogoWidth; height: width
                    anchors.verticalCenter: parent.verticalCenter
                    source: rowRect.entry.logo
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 64
                    sourceSize.height: 64
                    asynchronous: true
                    cache: true
                    mipmap: true
                    smooth: true
                    visible: String(source) !== ""
                  }
                  Text {
                    textFormat: Text.PlainText
                    width: standingsTeamWidth; height: parent.height
                    text: rowRect.entry.teamName
                    color: rowRect.favorite ? rowRect.rowAccent : root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: rowRect.favorite
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                  }
                  Repeater {
                    model: root.standingsColumns
                    Text {
                      textFormat: Text.PlainText
                      width: root.standingsStatWidth; height: rowRect.height
                      text: root.statFor(rowRect.entry.stats, modelData.name)
                      color: rowRect.favorite ? rowRect.rowAccent : Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: rowRect.favorite
                      horizontalAlignment: Text.AlignRight
                      verticalAlignment: Text.AlignVCenter
                    }
                  }
                }
              }
            }
          }
        }

        Flow {
          width: parent.width
          spacing: Style.space(14)
          visible: root.standings.length > 0 && root.standingsLegend.length > 0
          Repeater {
            model: root.standingsLegend
            Row {
              spacing: Style.space(5)
              Rectangle {
                width: 8
                height: 8
                anchors.verticalCenter: parent.verticalCenter
                radius: 2
                color: modelData.color
              }
              Text {
                textFormat: Text.PlainText
                text: modelData.label
                color: Qt.darker(root.contentForeground, 1.8)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
          }

          LoadingOverlay {
            active: root.standingsLoading
            text: "Fetching standings…"
          }
        }
      }

      // League Matches: what matters for the selected league — everything
      // live, the next few upcoming fixtures, and the last few results.
      Component {
        id: matchRowDelegate

          Item {
            id: matchRow
            required property var modelData
            width: parent ? parent.width : 0

            readonly property int rowVPadding: Style.space(8)
            readonly property int rowHPadding: Style.space(10)

            // League rows grow to fit the Follow button above the teams,
            // PLUS symmetric top and bottom padding.
            height: matchColumn.implicitHeight + rowVPadding * 2

            readonly property bool rowFollowable: root.leagueMode && !root.leagueBrowseAll && modelData.id !== ""
              && (modelData.state === "in"
                  || (modelData.state === "pre"
                      && modelData.kickoff - Date.now() <= root.followLeadMs))
            readonly property bool rowFollowed: root.leagueMode && !root.leagueBrowseAll
              && root.isLeagueMatchFollowed(modelData.id)

            Rectangle {
              anchors.fill: parent
              radius: Style.space(6)
              color: root.contentForeground
              opacity: matchRow.modelData.state === "in" ? 0.07 : (rowMouseArea.containsMouse ? 0.06 : 0.03)
            }

            MouseArea {
              id: rowMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openMatchDetail(matchRow.modelData)
              onDoubleClicked: root.openMatchDetail(matchRow.modelData)
            }

            Column {
              id: matchColumn
              anchors.fill: parent
              anchors.topMargin: matchRow.rowVPadding
              anchors.bottomMargin: matchRow.rowVPadding
              anchors.leftMargin: matchRow.rowHPadding
              anchors.rightMargin: matchRow.rowHPadding
              spacing: Style.space(4)

            Button {
              z: 2
              visible: matchRow.rowFollowable
              anchors.horizontalCenter: parent.horizontalCenter
              iconText: matchRow.rowFollowed ? "󰴅" : "󰡬"
              text: matchRow.rowFollowed ? "Following" : "Follow"
              tooltipText: matchRow.rowFollowed ? "Stop notifications for this match" : "Notify on goals, cards, half-time and full-time"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              iconSize: Style.font.caption
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(2)
              selected: matchRow.rowFollowed
              onClicked: root.toggleLeagueMatchFollow(matchRow.modelData.id)
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Image {
                anchors.verticalCenter: parent.verticalCenter
                width: root.matchLogoSize
                height: root.matchLogoSize
                source: matchRow.modelData.homeLogo
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 128
                sourceSize.height: 128
                mipmap: true
                cache: true
                asynchronous: true
                smooth: true
                visible: String(source) !== ""
              }

              Text {
                textFormat: Text.PlainText
                width: (parent.width - parent.spacing * 4 - root.matchScoreWidth - root.matchLogoSize * 2) / 2
                anchors.verticalCenter: parent.verticalCenter
                text: matchRow.modelData.homeName
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: matchRow.modelData.state === "in"
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
              }

              Text {
                textFormat: Text.PlainText
                width: root.matchScoreWidth
                anchors.verticalCenter: parent.verticalCenter
                text: matchRow.modelData.state === "pre"
                  ? matchRow.modelData.timeText
                  : matchRow.modelData.homeScore + "–" + matchRow.modelData.awayScore
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: matchRow.modelData.state !== "post"
                horizontalAlignment: Text.AlignHCenter
              }

              Text {
                textFormat: Text.PlainText
                width: (parent.width - parent.spacing * 4 - root.matchScoreWidth - root.matchLogoSize * 2) / 2
                anchors.verticalCenter: parent.verticalCenter
                text: matchRow.modelData.awayName
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: matchRow.modelData.state === "in"
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignLeft
              }

              Image {
                anchors.verticalCenter: parent.verticalCenter
                width: root.matchLogoSize
                height: root.matchLogoSize
                source: matchRow.modelData.awayLogo
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 128
                sourceSize.height: 128
                mipmap: true
                cache: true
                asynchronous: true
                smooth: true
                visible: String(source) !== ""
              }
            }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(5)

              Image {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(12)
                height: width
                source: matchRow.modelData.competitionLogo || ""
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 32
                sourceSize.height: 32
                mipmap: true
                asynchronous: true
                smooth: true
                visible: String(source) !== "" && !root.leagueMode
              }

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: matchRow.modelData.competitionName || ""
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                visible: text !== "" && !root.leagueMode
              }

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: "·"
                color: Qt.darker(root.contentForeground, 1.8)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                visible: !root.leagueMode && (matchRow.modelData.competitionName || "") !== "" && matchRowSubText.text !== ""
              }

              Text {
                id: matchRowSubText
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: matchRow.modelData.state === "pre"
                  ? matchRow.modelData.dateText : matchRow.modelData.status
                color: matchRow.modelData.state === "in"
                  ? "#4ade80" : Qt.darker(root.contentForeground, 1.6)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: matchRow.modelData.state === "in"
                visible: text !== ""
                elide: Text.ElideRight
              }
            }
          }
        }
      }

      Column {
        id: statsView
        width: parent.width
        spacing: Style.space(12)
        visible: root.showStats && !root.showMatchDetail

        Item {
          width: parent.width
          height: Math.max(Style.space(260), statsInnerCol.implicitHeight)

          Column {
            id: statsInnerCol
            width: parent.width
            spacing: Style.space(12)
            opacity: root.statsLoading ? 0.15 : 1.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Row {
              width: parent.width
              spacing: Style.space(8)

          Button {
            id: prevStatsSeasonButton
            width: Style.space(22)
            height: Style.space(22)
            iconText: ""
            tooltipText: "Older season"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.font.caption
            horizontalPadding: 0
            verticalPadding: 0
            onClicked: {
              root.statsSeasonOffset++
              root.loadStats()
            }
          }

          Button {
            id: statsSeasonChip
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(52)
            height: Style.space(22)
            text: root.seasonChipLabel(root.statsSeasonOffset)
            tooltipText: "Stats season"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: 0
            verticalPadding: 0
            onClicked: {
              root.statsSeasonOffset = 0
              root.loadStats()
            }
          }

          Button {
            id: nextStatsSeasonButton
            width: Style.space(22)
            height: Style.space(22)
            iconText: ""
            tooltipText: "Newer season"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.font.caption
            horizontalPadding: 0
            verticalPadding: 0
            enabled: root.statsSeasonOffset > 0
            opacity: enabled ? 1 : 0.35
            onClicked: {
              root.statsSeasonOffset--
              root.loadStats()
            }
          }
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)

          Button {
            id: goalsTabButton
            height: Style.space(22)
            text: "Goals"
            tooltipText: "Top goal scorers"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            selected: root.statsCategory === "goals"
            onClicked: root.statsCategory = "goals"
          }

          Button {
            id: assistsTabButton
            height: Style.space(22)
            text: "Assists"
            tooltipText: "Top assists leaders"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            selected: root.statsCategory === "assists"
            onClicked: root.statsCategory = "assists"
          }

          Button {
            id: yellowTabButton
            height: Style.space(22)
            text: "Yellow Cards"
            tooltipText: "Yellow cards leaders"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            selected: root.statsCategory === "yellow"
            onClicked: root.statsCategory = "yellow"
          }

          Button {
            id: redTabButton
            height: Style.space(22)
            text: "Red Cards"
            tooltipText: "Red cards leaders"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            selected: root.statsCategory === "red"
            onClicked: root.statsCategory = "red"
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          opacity: root.statsLoading ? 0.4 + 0.6 * root._pulse : 1.0
          text: root.statsLoading ? "Fetching statistics…"
            : (root.statsError !== "" ? root.statsError
            : ((root.statsCategory === "goals" ? root.statsGoals.length : (root.statsCategory === "assists" ? root.statsAssists.length : (root.statsCategory === "yellow" ? root.statsYellow.length : root.statsRed.length))) === 0 ? "No stats available" : ""))
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          visible: text !== ""
        }

        Column {
          width: parent.width
          spacing: 0
          visible: (root.statsCategory === "goals" ? root.statsGoals.length : (root.statsCategory === "assists" ? root.statsAssists.length : (root.statsCategory === "yellow" ? root.statsYellow.length : root.statsRed.length))) > 0

          Row {
            width: parent.width
            height: Style.space(26)

            Text {
              textFormat: Text.PlainText
              width: Style.space(20)
              height: parent.height
              text: "#"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignRight
              verticalAlignment: Text.AlignVCenter
            }
            Item { width: Style.space(8); height: 1 }
            Item { width: Style.space(20); height: 1 }
            Item { width: Style.space(6); height: 1 }
            Text {
              textFormat: Text.PlainText
              width: parent.width - Style.space(20 + 8 + 20 + 6 + (root.showStatsMatchesColumn ? 48 : 0) + 48)
              height: parent.height
              text: "Player"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              verticalAlignment: Text.AlignVCenter
            }
            Text {
              textFormat: Text.PlainText
              width: root.showStatsMatchesColumn ? Style.space(48) : 0
              height: parent.height
              text: "Matches"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              visible: root.showStatsMatchesColumn
            }
            Text {
              textFormat: Text.PlainText
              width: Style.space(48)
              height: parent.height
              text: root.statsCategory === "goals" ? "Goals" : (root.statsCategory === "assists" ? "Assists" : (root.statsCategory === "yellow" ? "Yellow" : "Red"))
              color: root.statsCategory === "yellow" ? "#eab308" : (root.statsCategory === "red" ? "#ef4444" : root.favoriteTeamAccent)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }

          Repeater {
            model: (root.statsCategory === "goals" ? root.statsGoals : (root.statsCategory === "assists" ? root.statsAssists : (root.statsCategory === "yellow" ? root.statsYellow : root.statsRed))).slice(0, 15)

            delegate: Item {
              id: statRow
              required property var modelData
              width: parent ? parent.width : 0
              height: Style.space(32)

              Rectangle {
                anchors.fill: parent
                color: root.contentForeground
                opacity: statRow.modelData.rank % 2 === 1 ? 0.03 : 0.0
                radius: Style.space(4)
              }

              Row {
                anchors.fill: parent

                Text {
                  textFormat: Text.PlainText
                  width: Style.space(20)
                  height: parent.height
                  text: statRow.modelData.rank
                  color: statRow.modelData.rank <= 3 ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: statRow.modelData.rank <= 3
                  horizontalAlignment: Text.AlignRight
                  verticalAlignment: Text.AlignVCenter
                }

                Item { width: Style.space(8); height: 1 }

                Image {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(20)
                  height: Style.space(20)
                  source: statRow.modelData.teamLogo
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: 64
                  sourceSize.height: 64
                  mipmap: true
                  asynchronous: true
                  smooth: true
                  visible: String(source) !== ""
                }

                Item { width: Style.space(6); height: 1 }

                Column {
                  width: parent.width - Style.space(20 + 8 + 20 + 6 + (root.showStatsMatchesColumn ? 48 : 0) + 48)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 0

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: statRow.modelData.name
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: statRow.modelData.teamName
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    visible: text !== ""
                  }
                }

                Text {
                  textFormat: Text.PlainText
                  width: root.showStatsMatchesColumn ? Style.space(48) : 0
                  height: parent.height
                  text: statRow.modelData.appearances !== "" ? statRow.modelData.appearances : "—"
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  visible: root.showStatsMatchesColumn
                }

                Text {
                  textFormat: Text.PlainText
                  width: Style.space(48)
                  height: parent.height
                  text: statRow.modelData.value
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
              }
            }
          }
        }
          }

          LoadingOverlay {
            active: root.statsLoading
            text: "Fetching statistics…"
          }
        }
      }

      // Selected club's own full fixtures list (5 matches per view with Earlier/Later navigation)
      Column {
        id: clubFixturesView
        width: parent.width
        spacing: Style.space(12)
        visible: !root.leagueMode && root.showClubFixtures && !root.showStandings && !root.showStats && !root.showMatchDetail

        Item {
          width: parent.width
          height: Math.max(Style.space(220), clubFixturesInnerCol.implicitHeight)

          Column {
            id: clubFixturesInnerCol
            width: parent.width
            spacing: Style.space(12)
            opacity: (root.loading && root.teamFixtureRows.length === 0) ? 0.15 : 1.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Item {
              width: parent.width
              height: clubFixturesTitleText.implicitHeight

          Text {
            id: clubFixturesTitleText
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            opacity: root.loading ? 0.4 + 0.6 * root._pulse : 1.0
            text: root.loading
              ? ("Fetching " + root.teamName + " fixtures…")
              : (root.teamFixtureRows.length > 0 ? (root.teamName + " Fixtures") : ("No fixtures found for " + root.teamName))
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
          }
        }

        Column {
          width: parent.width
          spacing: 0
          visible: root.teamFixtureRows.length > 0

          Repeater {
            model: root.pagedClubRows
            delegate: matchRowDelegate
          }
        }

        // Navigation arrows below the 5 fixtures
        Row {
          width: parent.width
          height: Style.space(32)
          visible: root.clubPageCount > 1

          Button {
            id: clubPrevPageBtn
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(85)
            height: Style.space(28)
            iconText: ""
            text: "Earlier"
            enabled: root.clubFixturePage > 0
            opacity: root.clubFixturePage > 0 ? 1.0 : 0.4
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            iconSize: Style.font.caption
            horizontalPadding: Style.space(8)
            verticalPadding: 0
            onClicked: {
              if (root.clubFixturePage > 0) root.clubFixturePage--
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: (root.clubFixturePage * root.clubPageSize + 1) + "–" + Math.min((root.clubFixturePage + 1) * root.clubPageSize, root.teamFixtureRows.length) + " of " + root.teamFixtureRows.length
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Button {
            id: clubNextPageBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(85)
            height: Style.space(28)
            iconText: ""
            text: "Later"
            enabled: root.clubFixturePage < root.clubPageCount - 1
            opacity: root.clubFixturePage < root.clubPageCount - 1 ? 1.0 : 0.4
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            iconSize: Style.font.caption
            horizontalPadding: Style.space(8)
            verticalPadding: 0
            onClicked: {
              if (root.clubFixturePage < root.clubPageCount - 1) root.clubFixturePage++
            }
          }
        }
          }

          LoadingOverlay {
            active: root.loading && root.teamFixtureRows.length === 0
            text: root.sanitizePlainText("Fetching " + root.teamName + " fixtures…")
          }
        }
      }

      // League Matchweek Fixtures and Daily Slate container
      Column {
        id: leagueMatchesView
        width: parent.width
        spacing: Style.space(12)
        visible: (root.leagueMode ? (!root.showStandings && !root.showStats && !root.showMatchDetail) : (root.showMatches && !root.showStandings && !root.showStats && !root.showMatchDetail && !root.showClubFixtures))

        Item {
          width: parent.width
          height: Math.max(Style.space(240), leagueMatchesInnerCol.implicitHeight)

          Column {
            id: leagueMatchesInnerCol
            width: parent.width
            spacing: Style.space(12)
            opacity: root.matchListLoading ? 0.15 : 1.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // League name on the left; on the right, chevrons page between the
            // detected fixture rounds around the date-range label.
            Item {
          width: parent.width
          height: Math.max(matchTitleText.implicitHeight, matchWeekNav.implicitHeight)

          Text {
            id: matchTitleText
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (matchWeekNav.visible ? matchWeekNav.width + parent.spacing : 0)
              - (liveBadge.visible ? liveBadge.width + parent.spacing : 0)
            opacity: root.matchListLoading ? 0.4 + 0.6 * root._pulse : 1.0
            text: root.matchListError !== "" ? "Could not load matches"
              : (root.leagueBrowseAll || !root.leagueMode
                ? (root.matchWeekRows.length > 0 ? root.leagueLabel() : (root.matchListLoading ? "Fetching matches…" : "No fixtures this week"))
                : ((root.leagueLive.length + root.leagueRecent.length + root.leagueUpcoming.length) > 0
                  ? root.leagueLabel() : (root.matchListLoading ? "Fetching matches…" : "No matches today")))
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            id: liveBadge
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            // Sits between the title and the season/round controls.
            anchors.right: matchWeekNav.visible ? matchWeekNav.left : parent.right
            anchors.rightMargin: matchWeekNav.visible ? parent.spacing : 0
            text: root.leagueMode ? (root.leagueLive.length + " live") : "Live"
            color: "#4ade80"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            visible: root.leagueMode ? (root.leagueLive.length > 0) : (root.liveMatch !== null)
          }

          Row {
            id: matchWeekNav
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            visible: (root.leagueMode && root.leagueBrowseAll) || (!root.leagueMode && root.showMatches)

            Button {
              id: prevWeekButton
              width: Style.space(22)
              height: Style.space(22)
              iconText: ""
              tooltipText: "Previous matchweek"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              iconSize: Style.font.caption
              horizontalPadding: 0
              verticalPadding: 0
              onClicked: {
                if (matchListRequest.running || root.pendingEdge !== "") return
                if (root.matchClusterIndex > 0) { root.matchClusterIndex--; return }
                // Empty view has no boundary row: let the landing logic use
                // the far edge of whatever the shifted window returns.
                root.navAnchorDay = root.matchWeekRows.length ? root.matchWeekRows[0].day : ""
                root.matchWindowOffset -= 21
                root.pendingEdge = "prev"
                root.loadMatchList()
              }
            }

            Text {
              id: matchWeekLabelText
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: root.matchWeekLabel
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1
            }

            Button {
              id: nextWeekButton
              width: Style.space(22)
              height: Style.space(22)
              iconText: ""

              tooltipText: "Next matchweek"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              iconSize: Style.font.caption
              horizontalPadding: 0
              verticalPadding: 0
              onClicked: {
                if (matchListRequest.running || root.pendingEdge !== "") return
                if (root.matchClusterIndex < root.matchClusters.length - 1) { root.matchClusterIndex++; return }
                root.navAnchorDay = root.matchWeekRows.length ? root.matchWeekRows[root.matchWeekRows.length - 1].day : ""
                root.matchWindowOffset += 21
                root.pendingEdge = "next"
                root.loadMatchList()
              }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.matchListError
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          visible: root.matchListError !== ""
        }

        // Full league fixtures by matchweek
        Column {
          width: parent.width
          spacing: 0
          visible: ((root.leagueMode && root.leagueBrowseAll) || (!root.leagueMode && root.showMatches)) && root.matchWeekRows.length > 0

          Repeater {
            model: root.matchWeekRows
            delegate: matchRowDelegate
          }
        }

        // League-follow board: live now, then recent results, then what's
        // coming up — all from the same window fetch.
        Repeater {
          model: [
            { label: "Live", rows: root.leagueLive },
            { label: "Played Today", rows: root.leagueRecent },
            { label: "Later Today", rows: root.leagueUpcoming }
          ]

          delegate: Column {
            required property var modelData
            readonly property bool listIdle: !root.matchListLoading && root.matchListError === ""
            width: parent ? parent.width : 0
            spacing: Style.space(4)
            visible: root.leagueMode && !root.leagueBrowseAll && listIdle && modelData.rows.length > 0

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: modelData.label
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Repeater {
              model: modelData.rows
              delegate: matchRowDelegate
            }
          }
        }

        Item {
          width: parent.width
          height: Style.space(32)
          visible: root.leagueMode && !root.leagueBrowseAll && !root.matchListLoading && root.matchListError === "" && (root.leagueLive.length + root.leagueRecent.length + root.leagueUpcoming.length) === 0

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: "No matches scheduled for today"
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // Daily slate option: navigate to all fixtures window
        Item {
          id: seeFixturesRow
          width: parent.width
          height: Style.space(38)
          visible: root.leagueMode && !root.leagueBrowseAll && root.matchListError === ""
          opacity: root.matchListLoading ? 0.5 : 1.0

          Rectangle {
            anchors.fill: parent
            radius: Style.space(6)
            color: root.contentForeground
            opacity: seeFixturesMouseArea.containsMouse ? 0.08 : 0.04
          }

          MouseArea {
            id: seeFixturesMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showAllFixtures()
          }

          Row {
            anchors.centerIn: parent
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "󰕲"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "Show full fixtures"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: ""
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
          }

          LoadingOverlay {
            active: root.matchListLoading
            text: "Fetching fixtures…"
          }
        }
      }

      Item {
        id: overviewContainer
        width: parent.width
        height: Math.max(overviewInnerCol.implicitHeight, (root.loading && !root.liveMatch && !root.nextMatch && !root.previousMatch) ? Style.space(240) : 0)
        visible: !root.customViewActive

        Column {
          id: overviewInnerCol
          width: parent.width
          spacing: Style.space(14)
          opacity: (root.loading && !root.liveMatch && !root.nextMatch && !root.previousMatch) ? 0.15 : 1.0
          Behavior on opacity { NumberAnimation { duration: 180 } }

          Item {
            width: parent.width
            height: Style.space(20)
            visible: root.liveMatch && !root.customViewActive

        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "LIVE MATCH"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "LIVE"
          color: "#4ade80"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Item {
        width: parent.width
        height: liveColumn.implicitHeight + Style.space(8)
        // The dedicated live card is redundant inside the League Matches / Stats
        // views and below the standings table.
        visible: root.liveMatch && !root.customViewActive

        MouseArea {
          id: liveCardArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.liveMatch) root.openMatchDetail(root.liveMatch)
          onDoubleClicked: if (root.liveMatch) root.openMatchDetail(root.liveMatch)
        }

        Column {
          id: liveColumn
          width: Style.space(348)
          anchors.centerIn: parent
          spacing: Style.space(6)
          topPadding: Style.space(8)
          bottomPadding: Style.space(8)

          Button {
            id: liveFollowBtn
            z: 2
            anchors.horizontalCenter: parent.horizontalCenter
            iconText: root.liveActivity ? "󰴅" : "󰡬"
            text: root.liveActivity ? "Following" : "Follow"
            tooltipText: root.liveActivity ? "Stop match notifications" : "Notify on goals, cards, half-time, full-time and extra time"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            iconSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: Style.space(3)
            selected: root.liveActivity
            onClicked: root.liveActivity ? root.stopLiveActivity() : root.startLiveActivity()
          }

          Row {
            id: liveTeamsScoreRow
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            spacing: Style.space(8)

            Image { width: Style.space(50); height: width; source: root.teamLogoFor(root.liveMatch, "home"); fillMode: Image.PreserveAspectFit; asynchronous: true; cache: true; mipmap: true; smooth: true; anchors.verticalCenter: parent.verticalCenter; visible: String(source) !== "" }
            Text {
              textFormat: Text.PlainText
              width: (parent.width - Style.space(50) * 2 - Style.space(90) - parent.spacing * 4) / 2
              anchors.verticalCenter: parent.verticalCenter
              text: root.teamNameFor(root.liveMatch, "home")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignRight
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }
            Column {
              width: Style.space(90)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)
              clip: true

              Text {
                textFormat: Text.PlainText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.scoreFor(root.liveMatch, "home") + " – " + root.scoreFor(root.liveMatch, "away")
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.statusFor(root.liveMatch)
                color: "#4ade80"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: text !== ""
              }
            }
            Text {
              textFormat: Text.PlainText
              width: (parent.width - Style.space(50) * 2 - Style.space(90) - parent.spacing * 4) / 2
              anchors.verticalCenter: parent.verticalCenter
              text: root.teamNameFor(root.liveMatch, "away")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignLeft
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }
            Image { width: Style.space(50); height: width; source: root.teamLogoFor(root.liveMatch, "away"); fillMode: Image.PreserveAspectFit; asynchronous: true; cache: true; mipmap: true; smooth: true; anchors.verticalCenter: parent.verticalCenter; visible: String(source) !== "" }
          }

          Item {
            width: 1
            height: Style.space(6)
            visible: root.liveHasDetails()
          }

          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.liveHasDetails()

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing) / 2
              text: root.liveDetailsFor("home")
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignLeft
              wrapMode: Text.WordWrap
            }

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing) / 2
              text: root.liveDetailsFor("away")
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
              wrapMode: Text.WordWrap
            }
          }

          Row {
            id: liveCompRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(5)
            Image { id: competitionLogo; width: Style.space(14); height: width; source: root.competitionLogoFor(root.liveMatch); fillMode: Image.PreserveAspectFit; asynchronous: true; cache: true; mipmap: true; smooth: true; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 2; visible: String(source) !== "" }
            Text {
              textFormat: Text.PlainText
              text: root.competitionNameFor(root.liveMatch)
              anchors.verticalCenter: competitionLogo.verticalCenter
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // Bottom spacer to equalize distance from center to top and bottom
          Item {
            width: 1
            height: Math.max(0, liveFollowBtn.implicitHeight - liveCompRow.implicitHeight)
            visible: !root.liveHasDetails()
          }
        }
      }

      Rectangle {
        width: parent.width
        height: Style.spacing.hairline
        color: root.contentForeground
        opacity: 0.15
        // Only separate the live card from the next card; without a live match
        // the header's own hairline is the single separator at the top.
        visible: root.liveMatch && !root.customViewActive
      }

      Item {
        width: parent.width
        height: Style.space(20)
        visible: !root.customViewActive

        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "NEXT MATCH"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.kickoffDay(root.nextMatch) + " · " + root.kickoffTime(root.nextMatch)
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Item {
        id: nextMatchCard
        width: parent.width
        height: nextMatchCol.implicitHeight + Style.space(16)
        visible: !root.customViewActive

        Rectangle {
          anchors.fill: parent
          radius: Style.space(6)
          color: root.contentForeground
          opacity: nextCardArea.containsMouse ? 0.06 : 0.03
        }

        MouseArea {
          id: nextCardArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.nextMatch) root.openMatchDetail(root.nextMatch)
          onDoubleClicked: if (root.nextMatch) root.openMatchDetail(root.nextMatch)
        }

        Column {
          id: nextMatchCol
          anchors.fill: parent
          anchors.topMargin: Style.space(8)
          anchors.bottomMargin: Style.space(8)
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(6)

          Row {
            width: parent.width
            spacing: Style.space(8)

            Image {
              width: Style.space(36)
              height: width
              source: root.teamLogoFor(root.nextMatch, "home")
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              anchors.verticalCenter: parent.verticalCenter
              visible: String(source) !== ""
            }

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing * 4 - Style.space(36) * 2 - Style.space(36)) / 2
              anchors.verticalCenter: parent.verticalCenter
              text: root.teamNameFor(root.nextMatch, "home")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              horizontalAlignment: Text.AlignRight
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Text {
              textFormat: Text.PlainText
              width: Style.space(36)
              anchors.verticalCenter: parent.verticalCenter
              horizontalAlignment: Text.AlignHCenter
              text: "vs"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing * 4 - Style.space(36) * 2 - Style.space(36)) / 2
              anchors.verticalCenter: parent.verticalCenter
              text: root.teamNameFor(root.nextMatch, "away")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              horizontalAlignment: Text.AlignLeft
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Image {
              width: Style.space(36)
              height: width
              source: root.teamLogoFor(root.nextMatch, "away")
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              anchors.verticalCenter: parent.verticalCenter
              visible: String(source) !== ""
            }
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(5)
            Image {
              width: Style.space(18)
              height: width
              source: root.competitionLogoFor(root.nextMatch)
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              anchors.verticalCenter: parent.verticalCenter
              visible: String(source) !== ""
            }
            Text {
              textFormat: Text.PlainText
              text: root.competitionNameFor(root.nextMatch)
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: Style.spacing.hairline
        color: root.contentForeground
        opacity: 0.15
        visible: !root.customViewActive
      }

      Item {
        width: parent.width
        height: Style.space(20)
        visible: !root.customViewActive

        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "PREVIOUS MATCH"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.kickoffDay(root.previousMatch) + " · " + root.statusFor(root.previousMatch)
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Item {
        id: prevMatchCard
        width: parent.width
        height: prevMatchCol.implicitHeight + Style.space(16)
        visible: !root.customViewActive

        Rectangle {
          anchors.fill: parent
          radius: Style.space(6)
          color: root.contentForeground
          opacity: prevCardArea.containsMouse ? 0.06 : 0.03
        }

        MouseArea {
          id: prevCardArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.previousMatch) root.openMatchDetail(root.previousMatch)
          onDoubleClicked: if (root.previousMatch) root.openMatchDetail(root.previousMatch)
        }

        Column {
          id: prevMatchCol
          anchors.fill: parent
          anchors.topMargin: Style.space(8)
          anchors.bottomMargin: Style.space(8)
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(6)

          Row {
            width: parent.width
            spacing: Style.space(8)

            Image {
              width: Style.space(36)
              height: width
              source: root.teamLogoFor(root.previousMatch, "home")
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              anchors.verticalCenter: parent.verticalCenter
              visible: String(source) !== ""
            }

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing * 4 - Style.space(36) * 2 - Style.space(60)) / 2
              anchors.verticalCenter: parent.verticalCenter
              text: root.teamNameFor(root.previousMatch, "home")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignRight
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Text {
              textFormat: Text.PlainText
              width: Style.space(60)
              anchors.verticalCenter: parent.verticalCenter
              horizontalAlignment: Text.AlignHCenter
              text: root.scoreFor(root.previousMatch, "home") + " – " + root.scoreFor(root.previousMatch, "away")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing * 4 - Style.space(36) * 2 - Style.space(60)) / 2
              anchors.verticalCenter: parent.verticalCenter
              horizontalAlignment: Text.AlignLeft
              text: root.teamNameFor(root.previousMatch, "away")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Image {
              width: Style.space(36)
              height: width
              source: root.teamLogoFor(root.previousMatch, "away")
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              anchors.verticalCenter: parent.verticalCenter
              visible: String(source) !== ""
            }
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(5)
            Image {
              width: Style.space(18)
              height: width
              source: root.competitionLogoFor(root.previousMatch)
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              anchors.verticalCenter: parent.verticalCenter
              visible: String(source) !== ""
            }
            Text {
              textFormat: Text.PlainText
              text: root.competitionNameFor(root.previousMatch)
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      Item {
        id: clubSeeFixturesRow
        width: parent.width
        height: Style.space(38)
        visible: !root.customViewActive && !root.loading && root.requestError === "" && (root.nextMatch || root.previousMatch)

        Rectangle {
          anchors.fill: parent
          radius: Style.space(6)
          color: root.contentForeground
          opacity: clubSeeFixturesMouseArea.containsMouse ? 0.08 : 0.04
        }

        MouseArea {
          id: clubSeeFixturesMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.showClubAllFixtures()
        }

        Row {
          anchors.centerIn: parent
          spacing: Style.space(8)

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: "󰕲"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: "Show full fixtures"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: !root.customViewActive && root.requestError !== ""
        text: root.requestError
        color: Qt.darker(root.contentForeground, 1.5)
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.caption
      }
        }

        LoadingOverlay {
          active: root.loading && !root.liveMatch && !root.nextMatch && !root.previousMatch
          text: root.sanitizePlainText("Fetching " + (root.teamName || "fixtures") + "…")
        }
      }
    }
  }
}
}
}
}
