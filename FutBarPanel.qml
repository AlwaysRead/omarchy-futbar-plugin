import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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

  readonly property bool anyLoading: root.loading || root.matchListLoading || root.standingsLoading || root.statsLoading || root.matchDetailLoading || root.teamsLoading || root.searchLoading || root.searchPlayerLoading || root.searchClubLoading

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
             .replace(/\/teamlogos\/countries\/(?:50|100|200)\//g, "/teamlogos/countries/500/")
             .replace(/\/countries\/(?:50|100|200)\//g, "/countries/500/")
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

  // Items you're tracking besides the active one -- rendered as tabs in the
  // panel header. Can be either a club ({ teamName, league, teamId, followLeague: false })
  // or an entire league ({ teamName: "", league, teamId: "", followLeague: true }).
  // The active item is never stored here; it's implicit (it's whatever
  // teamName/league/teamId/followLeague currently resolve to), so an existing
  // user's favorite file needs no migration at all.
  function itemKey(name, league, followLeague) {
    var lg = String(league || "").trim().toLowerCase()
    if (followLeague === true || (String(name || "").trim() === "" && lg !== "")) {
      return "league|" + lg
    }
    return "team|" + String(name || "").trim().toLowerCase() + "|" + lg
  }
  function teamKey(name, league) {
    return root.itemKey(name, league, false)
  }
  // Normalizes to well-formed { teamName, league, teamId, followLeague } objects
  // so every consumer -- switchActiveItem, the tab Repeater -- can trust entry fields.
  function followedTeamsList() {
    var raw = Array.isArray(root.savedFavorite.followedTeams) ? root.savedFavorite.followedTeams : []
    var out = []
    for (var i = 0; i < raw.length; i++) {
      var entry = raw[i]
      if (!entry || typeof entry !== "object") continue
      var name = typeof entry.teamName === "string" ? entry.teamName : ""
      var lg = typeof entry.league === "string" ? entry.league : ""
      var isLg = entry.followLeague === true || (name === "" && lg !== "")
      if (name === "" && lg === "") continue
      out.push({
        teamName: isLg ? "" : name,
        league: lg,
        teamId: typeof entry.teamId === "string" ? entry.teamId : "",
        followLeague: isLg
      })
    }
    return out
  }
  function persistFollowedTeams(list) {
    var payload = {}
    if (root.savedFavorite && typeof root.savedFavorite === "object") {
      for (var k in root.savedFavorite) payload[k] = root.savedFavorite[k]
    }
    payload.followedTeams = list
    if (root.leagueMode) {
      payload.teamName = ""
      payload.teamId = ""
      payload.league = root.league
      payload.followLeague = true
    } else {
      if (payload.teamName === undefined || payload.teamName === null) payload.teamName = root.teamName
      if (payload.league === undefined || payload.league === null || payload.league === "") payload.league = root.league
      if (payload.teamId === undefined || payload.teamId === null) payload.teamId = (root.teamId !== "" ? root.teamId : root.resolvedTeamId)
      if (payload.followLeague) delete payload.followLeague
    }
    root.savedFavorite = payload
    favoriteStore.setText(JSON.stringify(payload, null, 2) + "\n")
  }
  // Switches the active item (either club or whole league).
  function switchActiveItem(teamName, league, teamId, followLeague) {
    var isLg = followLeague === true || (String(teamName || "").trim() === "" && String(league || "").trim() !== "")
    var destKey = root.itemKey(isLg ? "" : teamName, league, isLg)
    var activeKey = root.itemKey(root.leagueMode ? "" : root.teamName, root.league, root.leagueMode)
    var list = root.followedTeamsList().slice()
    for (var i = list.length - 1; i >= 0; i--) {
      if (root.itemKey(list[i].teamName, list[i].league, list[i].followLeague) === destKey) list.splice(i, 1)
    }
    if (destKey !== activeKey && (root.teamName !== "" || root.leagueMode)) {
      var already = false
      for (var j = 0; j < list.length; j++) {
        if (root.itemKey(list[j].teamName, list[j].league, list[j].followLeague) === activeKey) { already = true; break }
      }
      if (!already) {
        list.push({
          teamName: root.leagueMode ? "" : root.teamName,
          league: root.league,
          teamId: root.leagueMode ? "" : (root.teamId !== "" ? root.teamId : root.resolvedTeamId),
          followLeague: root.leagueMode
        })
      }
    }
    if (isLg) {
      root.activateLeague(league, list)
    } else {
      root.activateTeam(teamName, league, teamId, list)
    }
  }
  function switchActiveTeam(teamName, league, teamId) {
    root.switchActiveItem(teamName, league, teamId, false)
  }
  function switchActiveLeague(league) {
    root.switchActiveItem("", league, "", true)
  }
  function addFollowedTeam(teamName, league, teamId) {
    root.switchActiveTeam(teamName, league, teamId)
  }
  function addFollowedLeague(league) {
    root.switchActiveLeague(league)
  }
  function removeFollowedItem(teamName, league, followLeague) {
    var isLg = followLeague === true || (String(teamName || "").trim() === "" && String(league || "").trim() !== "")
    var key = root.itemKey(isLg ? "" : teamName, league, isLg)
    var list = root.followedTeamsList().slice()
    for (var i = list.length - 1; i >= 0; i--) {
      if (root.itemKey(list[i].teamName, list[i].league, list[i].followLeague) === key) list.splice(i, 1)
    }
    root.persistFollowedTeams(list)
    delete root._teamStateCache[key]
  }
  function removeFollowedTeam(teamName, league) {
    root.removeFollowedItem(teamName, league, false)
  }
  function removeFollowedLeague(league) {
    root.removeFollowedItem("", league, true)
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
  onMatchDetailTabChanged: root.resetPanelScroll()
  onMatchDetailLineupTeamChanged: root.resetPanelScroll()
  onShowMatchDetailChanged: root.resetPanelScroll()
  property bool showSearch: false
  property string searchQuery: ""
  property bool searchLoading: false
  property var searchResults: []
  property string searchError: ""
  property var selectedPlayerProfile: null
  property bool searchPlayerLoading: false
  property string searchPlayerStatsTab: "all"
  property string searchPlayerCardTab: "info"
  property string statsPlayerKey: ""
  property string statsPlayerLeague: ""
  property bool playerStatsLoading: false
  property var playerCompStatQueue: []
  property var playerCompStatCache: ({})
  property string clubNamesResolvedFor: ""
  property var clubNameQueue: []
  property var teamNameCache: ({})
  property var transferTeamQueue: []
  property string _transferTeamInFlight: ""
  property var clubAggQueue: []
  property var clubAggSums: ({})
  property string clubAggTarget: ""
  property var careerAggQueue: []
  property var careerAggSums: ({})
  property string careerAggTarget: ""
  property var selectedClubProfile: null
  property var clubProfileHistory: null
  readonly property string profileNavBackLabel: (root.clubProfileHistory !== null) ? ("Back to " + (root.clubProfileHistory.displayName || "Club")) : "Back to search results"
  property bool searchClubLoading: false
  property var _pendingClubProfile: null
  property int _clubFetchPending: 0
  property var clubLeaderQueue: []
  property var matchDetailJerseyUrls: []
  property string searchClubCardTab: "overview"
  property string clubSquadPositionFilter: "all"
  property int clubFixtureCarouselIndex: 0
  onSearchPlayerCardTabChanged: root.resetPanelScroll()
  onSearchClubCardTabChanged: root.resetPanelScroll()
  onClubSquadPositionFilterChanged: root.resetPanelScroll()
  readonly property bool customViewActive: root.showStandings || root.showMatches || root.showStats || root.showClubFixtures || root.showMatchDetail || root.showSearch || root.leagueMode
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
    root.showSearch = false
    root.showStandings = false
    root.showStats = false
    root.showClubFixtures = false
    root.leagueBrowseAll = false
    root.showMatches = root.leagueMode
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

  function isEventInPlay(event) {
    if (!event) return false
    var st = event.status || (event.competitions && event.competitions[0] && event.competitions[0].status) || {}
    var type = (typeof st === "object" && st.type) ? st.type : {}
    var state = String(type.state || event.state || "")
    if (state === "in") return true
    if (state === "post" || type.completed === true) return false
    var name = String(type.name || "").toUpperCase()
    if (name.indexOf("IN_PROGRESS") !== -1 || name.indexOf("FIRST_HALF") !== -1 || name.indexOf("SECOND_HALF") !== -1 || name.indexOf("HALFTIME") !== -1 || name.indexOf("EXTRA_TIME") !== -1 || name.indexOf("PENALTY_SHOOTOUT") !== -1) {
      return true
    }
    var detail = String(type.shortDetail || type.detail || type.description || "")
    if (detail === "HT" || detail === "Halftime" || detail === "Half Time" || detail === "Live" || detail.indexOf("'") !== -1) {
      return true
    }
    var statusStr = (typeof event.status === "string") ? event.status : ""
    if (statusStr === "Live" || statusStr === "HT" || statusStr.indexOf("'") !== -1) {
      return true
    }
    var kTime = event.kickoff || (event.date ? new Date(event.date).getTime() : 0)
    var nowMs = Date.now()
    if (kTime > 0 && kTime <= nowMs && (nowMs - kTime) < 150 * 60 * 1000) {
      if (state !== "post" && type.completed !== true) {
        return true
      }
    }
    return false
  }

  function isEventCompleted(event) {
    if (!event) return false
    var st = event.status || (event.competitions && event.competitions[0] && event.competitions[0].status) || {}
    var type = (typeof st === "object" && st.type) ? st.type : {}
    var state = String(type.state || event.state || "")
    if (state === "post" || type.completed === true) return true
    var detail = String(type.shortDetail || type.detail || type.description || "")
    if (detail === "FT" || detail === "Final" || detail === "Full Time" || detail === "AET") return true
    var statusStr = (typeof event.status === "string") ? event.status : ""
    if (statusStr === "FT" || statusStr === "Final" || statusStr === "Full Time" || statusStr === "AET") return true
    return false
  }

  function eventState(event) {
    if (root.isEventCompleted(event)) return "post"
    if (root.isEventInPlay(event)) return "in"
    return "pre"
  }

  function setFixtures(data) {
    var events = Array.isArray(data.events) ? data.events : []
    var now = new Date().getTime()
    var inPlay = events.filter(function(event) {
      return root.isEventInPlay(event)
    })
    liveMatch = inPlay.length ? inPlay[0] : null
    root.loadLiveSummary()

    var upcoming = events.filter(function(event) {
      if (root.isEventInPlay(event) || root.isEventCompleted(event)) return false
      var kTime = event.date ? new Date(event.date).getTime() : 0
      return kTime >= now
    })
    var completed = events.filter(function(event) {
      return root.isEventCompleted(event)
    })
    upcoming.sort(function(a, b) { return new Date(a.date) - new Date(b.date) })
    completed.sort(function(a, b) { return new Date(b.date) - new Date(a.date) })
    nextMatch = upcoming.length ? upcoming[0] : null
    previousMatch = completed.length ? completed[0] : null

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
    var type = status.type || {}
    var state = String(type.state || "")
    if (state === "pre") {
      var kTime = root.kickoffTime(event)
      return kTime !== "" ? kTime : "Scheduled"
    }
    if (state === "post" || type.completed === true) {
      var rawPost = String(type.shortDetail || type.detail || type.description || "FT").trim()
      if (rawPost === "" || rawPost === "Full Time" || rawPost === "Final") rawPost = "FT"
      var shootPost = root.shootoutSummaryFor(event)
      if (shootPost !== "" && rawPost.indexOf("Pen") === -1 && rawPost.indexOf("pen") === -1) {
        return root.sanitizePlainText(rawPost + " (" + shootPost + ")")
      }
      return root.sanitizePlainText(rawPost)
    }
    if (type.shortDetail === "HT" || type.detail === "Halftime" || type.detail === "Half Time") {
      return "HT"
    }
    if (status.displayClock) {
      var clk = String(status.displayClock).trim()
      if (clk !== "" && clk !== "0'") {
        return root.sanitizePlainText(clk)
      }
    }
    var raw = String(type.shortDetail || type.detail || "Live")
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
    var hLower = root.sanitizePlainText(String(homeName || "")).toLowerCase()
    var aLower = root.sanitizePlainText(String(awayName || "")).toLowerCase()
    for (var i = 0; i < h2hList.length; i++) {
      var item = h2hList[i]
      var hs = parseInt(item.homeScore, 10)
      var as_ = parseInt(item.awayScore, 10)
      if (!isNaN(hs) && !isNaN(as_)) {
        if (hs === as_) {
          d++
        } else {
          var itemHome = String(item.home || "").toLowerCase()
          var itemAway = String(item.away || "").toLowerCase()
          var isHomeMatchHome = (itemHome === hLower || (hLower !== "" && itemHome.indexOf(hLower) !== -1) || (itemHome !== "" && hLower.indexOf(itemHome) !== -1))
          var isHomeMatchAway = (itemAway === hLower || (hLower !== "" && itemAway.indexOf(hLower) !== -1) || (itemAway !== "" && hLower.indexOf(itemAway) !== -1))
          if (hs > as_) {
            if (isHomeMatchHome || !isHomeMatchAway) hW++
            else aW++
          } else {
            if (isHomeMatchAway || !isHomeMatchHome) hW++
            else aW++
          }
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
    if (!force && key === root._lastStandingsKey && root.standings.length > 0 && (now - root.lastStandingsRefresh < 30 * 1000)) {
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
    if (!force && key === root._lastStatsKey && (root.statsGoals.length > 0 || root.statsYellow.length > 0) && (now - root.lastStatsRefresh < 30 * 1000)) {
      return
    }
    statsRequest.running = false
    cardLeadersRequest.running = false
    athletesRequest.running = false
    athleteStatsRequest.running = false
    root.statsLoading = true
    root.statsError = ""
    root.statsGoals = []
    root.statsAssists = []
    root.rawYellowLeaders = []
    root.rawRedLeaders = []
    root.statsYellow = []
    root.statsRed = []
    root.athleteMap = ({})
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

    var isLive = root.isEventInPlay(match)
    var isCompleted = root.isEventCompleted(match)
    var isStarted = isLive || isCompleted

    var rawState = match.state || (match.status && match.status.type && match.status.type.state) || ""
    var statusObj = (match.status && typeof match.status === "object") ? match.status : {}
    var statusType = statusObj.type || {}
    var statusDesc = String(statusType.description || statusType.shortDetail || statusType.name || "")
    var statusStr = (typeof match.status === "string" && match.status !== "") ? match.status : (root.statusFor ? root.statusFor(match) : statusDesc)

    if (!isStarted && (rawState === "in" || rawState === "post" || statusStr === "Live" || statusStr === "Full Time" || statusStr === "FT" || statusStr === "AET" || statusStr === "Final" || statusStr.indexOf("'") !== -1 || statusStr === "HT")) {
      isStarted = true
    }
    if (!isLive && (rawState === "in" || statusStr === "Live" || statusStr.indexOf("'") !== -1 || statusStr === "HT")) {
      isLive = true
      isStarted = true
    }

    root.showMatchDetail = true
    root.showSearch = false
    root.showStandings = false
    root.showStats = false
    root.showMatches = false
    root.showClubFixtures = false
    root.matchDetailLoading = true
    root.matchDetailError = ""
    root.matchDetailTab = isLive ? "commentary" : (isStarted ? "stats" : "info")
    root.matchDetailLineupTeam = "home"
    root.matchDetailCrestsLoaded = false
    root.matchDetailJerseyUrls = []
    root.resetPanelScroll()

    var initDateStr = ""
    if (match.date) {
      var mdObj = new Date(match.date)
      var mdDay = Qt.formatDate(mdObj, "ddd d MMM")
      var mdTime = Qt.formatTime(mdObj, "HH:mm")
      initDateStr = mdDay + (mdTime !== "" ? (" · " + mdTime) : "")
    } else if (match.dateText || match.timeText) {
      initDateStr = (match.dateText || "") + ((match.dateText && match.timeText) ? " · " : "") + (match.timeText || "")
    }

    var initStatus = statusStr || (isLive ? (match.timeText || "Live") : (isCompleted ? "Full Time" : "Scheduled"))
    if (isLive && (initStatus === "" || initStatus === "Scheduled")) {
      initStatus = "Live"
    }

    var hName = match.homeName || (match.competitions ? root.teamNameFor(match, "home") : (match.home ? (match.home.name || match.home.displayName) : "Home"))
    var hLogo = match.homeLogo || (match.competitions ? root.teamLogoFor(match, "home") : (match.home ? match.home.logo : ""))
    var aName = match.awayName || (match.competitions ? root.teamNameFor(match, "away") : (match.away ? (match.away.name || match.away.displayName) : "Away"))
    var aLogo = match.awayLogo || (match.competitions ? root.teamLogoFor(match, "away") : (match.away ? match.away.logo : ""))
    var cName = root.competitionNameFor(match) || match.competitionName || root.tournamentName || root.leagueLabel()
    var cLogo = root.competitionLogoFor(match) || match.competitionLogo || root.tournamentLogo

    var hScore = isStarted ? (match.homeScore !== undefined ? String(match.homeScore) : root.scoreFor(match, "home")) : ""
    var aScore = isStarted ? (match.awayScore !== undefined ? String(match.awayScore) : root.scoreFor(match, "away")) : ""
    if (hScore === "—") hScore = ""
    if (aScore === "—") aScore = ""
    if (isLive && hScore === "" && root.liveMatch && String(root.liveMatch.id) === mid) {
      hScore = root.scoreFor(root.liveMatch, "home")
      aScore = root.scoreFor(root.liveMatch, "away")
      if (hScore === "—") hScore = ""
      if (aScore === "—") aScore = ""
    }

    var homeLiveScorers = []
    var awayLiveScorers = []
    if (isLive && root.liveMatch && String(root.liveMatch.id) === mid) {
      var hDet = root.liveDetailsFor("home")
      if (hDet !== "") homeLiveScorers = hDet.split("\n")
      var aDet = root.liveDetailsFor("away")
      if (aDet !== "") awayLiveScorers = aDet.split("\n")
    }

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
      homeScorers: homeLiveScorers,
      awayScorers: awayLiveScorers,
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
      var state = root.eventState(e)
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
    var nowMs = Date.now()
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

    // 2. The active/current round: first cluster containing unplayed (pre) or currently active fixtures
    if (idx === -1) {
      for (var c = 0; c < clusters.length && idx === -1; c++) {
        var cRows = clusters[c].rows || clusters[c]
        if (!Array.isArray(cRows) || cRows.length === 0) continue
        var hasActiveOrUpcoming = cRows.some(function(row) {
          return row.state === "pre" || row.state === "in" || row.kickoff >= nowMs
        })
        if (hasActiveOrUpcoming) {
          idx = c
          break
        }
      }
    }

    // 3. Any cluster where today sits within match dates?
    if (idx === -1) {
      for (var c2 = 0; c2 < clusters.length && idx === -1; c2++) {
        var cRows2 = clusters[c2].rows || clusters[c2]
        if (!Array.isArray(cRows2) || cRows2.length === 0) continue
        var first = new Date(cRows2[0].kickoff); first.setHours(0, 0, 0, 0)
        var last = new Date(cRows2[cRows2.length - 1].kickoff); last.setHours(0, 0, 0, 0)
        if (todayMs >= first.getTime() && todayMs <= last.getTime()) idx = c2
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
    var todayFinished = []
    var todayUpcoming = []
    var otherFinished = []
    var otherUpcoming = []
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].state === "in") {
        live.push(rows[i])
        continue
      }
      if (rows[i].state === "post") {
        if (rows[i].day === todayKey) todayFinished.push(rows[i])
        else otherFinished.push(rows[i])
      } else {
        if (rows[i].day === todayKey) todayUpcoming.push(rows[i])
        else otherUpcoming.push(rows[i])
      }
    }
    todayFinished.sort(function(a, b) { return b.kickoff - a.kickoff })
    otherFinished.sort(function(a, b) { return b.kickoff - a.kickoff })
    todayUpcoming.sort(function(a, b) { return a.kickoff - b.kickoff })
    otherUpcoming.sort(function(a, b) { return a.kickoff - b.kickoff })

    var recent = todayFinished.concat(otherFinished).slice(0, 10)
    var upcoming = todayUpcoming.concat(otherUpcoming).slice(0, 10)

    return {
      live: live,
      recent: recent,
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
    if (!event || event.shootout === true) return false
    var t = String(event.type && event.type.text || "")
    var tt = String(event.type && event.type.type || "")
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

  function isOwnGoalEvent(event) {
    if (!event) return false
    var t = String(event.type && event.type.text || "")
    var txt = String(event.text || "")
    return t.indexOf("Own Goal") !== -1 || txt.indexOf("Own Goal") !== -1 || txt.indexOf("own goal") !== -1
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
      out.push(prefix + (minute !== "" ? minute + " " : "") + player + (events[i].own ? " (OG)" : "") + (events[i].penalty ? " (P)" : ""))
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

  function liveHasGoals() {
    return root.liveGoalsFor("home") !== "" || root.liveGoalsFor("away") !== ""
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
  property var _notifyQueue: []
  function notify(title, body, glyph) {
    if (!title) return
    var cleanTitle = root.sanitizePlainText(String(title))
    var cleanBody = root.sanitizePlainText(String(body || ""))
    if (cleanTitle === "") return
    var args = ["notify-send", "-a", "futbar"]
    var cleanGlyph = root.sanitizePlainText(String(glyph || ""))
    if (cleanGlyph !== "") args.push("-h", "string:omarchy-glyph:" + cleanGlyph)
    args.push(cleanTitle, cleanBody)
    var q = root._notifyQueue.slice()
    q.push(args)
    root._notifyQueue = q
    root._runNextNotify()
    // Every fired notification is a match event: pulse the bar widget so its
    // icon can flash instead of staying colored for the whole match.
    root.activityPulse()
  }
  function _runNextNotify() {
    if (notifyRequest.running || root._notifyQueue.length === 0) return
    var q = root._notifyQueue.slice()
    var cmd = q.shift()
    root._notifyQueue = q
    notifyRequest.command = cmd
    notifyRequest.running = true
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
        var playerName = root.sanitizePlainText(String(person.displayName || person.shortName || "?"))
        var isOG = root.isOwnGoalEvent(e)
        var goalTitle = isOG ? "Own Goal (OG) — " + playerName : (root.isPenaltyEvent(e) ? "Penalty — " + teamName : "Goal — " + playerName)
        if (!scoresAgree) {
          // Mid-update payload: park the toast until the score settles.
          var pkey = root.liveActivityKey(e)
          if (root.activityPending[pkey] === undefined)
            root.activityPending[pkey] = { tries: 0, title: goalTitle, minute: minute, glyph: "󰒸" }
          continue
        }
        root.activityMarkSeen(e)
        root.notify(goalTitle, (minute !== "" ? minute + "' · " : "") + score, "󰒸")
      } else if (t.indexOf("Yellow Card") !== -1 || t.indexOf("Red Card") !== -1 || t.indexOf("Second Yellow") !== -1) {
        if (!players.length) { root.activityMarkSeen(e); continue }
        var cardFirst = players[0]
        var cardPerson = cardFirst.athlete || cardFirst
        var cardName = root.sanitizePlainText(String(cardPerson.displayName || "?"))
        var isRed = t.indexOf("Red") !== -1 || t.indexOf("Second Yellow") !== -1
        var cardKind = isRed ? (t.indexOf("Second Yellow") !== -1 ? "Red Card (2nd Yellow)" : "Red Card") : "Yellow Card"
        var cardGlyph = isRed ? "🟥" : "🟨"
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
      onStreamFinished: {
        if (typeof text === "string" && text.length > 5242880) {
          console.warn("futbar", "live poll response exceeded byte limit")
        }
        root.handleLivePollResult(text)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.warnStderr("live poll", text)
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

  function resetPanelScroll() {
    Qt.callLater(function() {
      if (panelScrollArea && panelScrollArea.contentItem) {
        panelScrollArea.contentItem.contentY = 0
      }
    })
  }

  function _getTacticalCoordinates(player) {
    var abbr = String(player.positionAbbr || "").toUpperCase().trim()
    var posName = String(player.position || "").toLowerCase().trim()
    var fp = typeof player.formationPlace === "number" ? player.formationPlace : parseInt(player.formationPlace, 10)
    if (isNaN(fp)) fp = 99

    // 1. Explicit tactical abbreviations from ESPN
    if (abbr === "G") return { x: 0.50, y: 0.88 }
    if (abbr === "LB") return { x: 0.13, y: 0.74 }
    if (abbr === "LWB") return { x: 0.13, y: 0.67 }
    if (abbr === "CD-L") return { x: 0.38, y: 0.74 }
    if (abbr === "CD") return { x: 0.50, y: 0.74 }
    if (abbr === "CD-R") return { x: 0.62, y: 0.74 }
    if (abbr === "RB") return { x: 0.87, y: 0.74 }
    if (abbr === "RWB") return { x: 0.87, y: 0.67 }

    if (abbr === "DM") return { x: 0.50, y: 0.58 }
    if (abbr === "DM-L") return { x: 0.36, y: 0.58 }
    if (abbr === "DM-R") return { x: 0.64, y: 0.58 }
    if (abbr === "CM-L") return { x: 0.34, y: 0.44 }
    if (abbr === "CM") return { x: 0.50, y: 0.44 }
    if (abbr === "CM-R") return { x: 0.66, y: 0.44 }
    if (abbr === "LM") return { x: 0.13, y: 0.44 }
    if (abbr === "RM") return { x: 0.87, y: 0.44 }

    if (abbr === "AM-L" || abbr === "LW" || abbr === "LF") return { x: 0.16, y: 0.28 }
    if (abbr === "AM") return { x: 0.50, y: 0.30 }
    if (abbr === "AM-R" || abbr === "RW" || abbr === "RF") return { x: 0.84, y: 0.28 }

    if (abbr === "CF-L") return { x: 0.35, y: 0.13 }
    if (abbr === "CF-R") return { x: 0.65, y: 0.13 }
    if (abbr === "CF" || abbr === "F" || abbr === "ST") return { x: 0.50, y: 0.13 }

    // 2. Position Name matching
    if (posName.indexOf("goal") !== -1 || fp === 1) return { x: 0.50, y: 0.88 }
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

    if (posName.indexOf("left forw") !== -1 || posName.indexOf("left wing") !== -1 || (posName.indexOf("att") !== -1 && fp === 11)) return { x: 0.16, y: 0.28 }
    if (posName.indexOf("right forw") !== -1 || posName.indexOf("right wing") !== -1 || (posName.indexOf("att") !== -1 && (fp === 7 || fp === 10))) return { x: 0.84, y: 0.28 }
    if (posName.indexOf("center left forw") !== -1) return { x: 0.35, y: 0.13 }
    if (posName.indexOf("center right forw") !== -1) return { x: 0.65, y: 0.13 }
    if (posName.indexOf("forw") !== -1 || posName.indexOf("striker") !== -1 || fp === 9) return { x: 0.50, y: 0.13 }
    if (posName.indexOf("att") !== -1 || fp === 10) return { x: 0.50, y: 0.30 }

    // 3. formationPlace mapping fallback
    if (fp === 1) return { x: 0.50, y: 0.88 }
    if (fp === 3) return { x: 0.13, y: 0.74 }
    if (fp === 4) return { x: 0.38, y: 0.74 }
    if (fp === 5) return { x: 0.50, y: 0.74 }
    if (fp === 6) return { x: 0.62, y: 0.74 }
    if (fp === 2) return { x: 0.87, y: 0.74 }
    if (fp === 8) return { x: 0.34, y: 0.44 }
    if (fp === 7) return { x: 0.66, y: 0.44 }
    if (fp === 11) return { x: 0.16, y: 0.28 }
    if (fp === 10) return { x: 0.84, y: 0.28 }
    if (fp === 9) return { x: 0.50, y: 0.13 }

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
                result[a].y = Math.max(0.12, result[a].y - neededY)
                result[b].y = Math.min(0.86, result[b].y + neededY)
              } else {
                result[a].y = Math.min(0.86, result[a].y + neededY)
                result[b].y = Math.max(0.12, result[b].y - neededY)
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
        var playerName = root.sanitizePlainText(String(person.displayName || person.shortName || "?"))
        var isOG = root.isOwnGoalEvent(e)
        var goalTitle = isOG ? "Own Goal (OG) — " + playerName : (root.isPenaltyEvent(e) ? "Penalty — " + teamName : "Goal — " + playerName)
        root.activityMarkKey(key)
        root.notify(goalTitle, (minute !== "" ? minute + "' · " : "") + score, "󰒸")
      } else if (t.indexOf("Yellow Card") !== -1 || t.indexOf("Red Card") !== -1 || t.indexOf("Second Yellow") !== -1) {
        if (!players.length) { root.activityMarkKey(key); continue }
        var cardPerson = players[0].athlete || players[0]
        var cardName = root.sanitizePlainText(String(cardPerson.displayName || "?"))
        var isRed = t.indexOf("Red") !== -1 || t.indexOf("Second Yellow") !== -1
        var cardKind = isRed ? (t.indexOf("Second Yellow") !== -1 ? "Red Card (2nd Yellow)" : "Red Card") : "Yellow Card"
        var cardGlyph = isRed ? "\u{1F7E5}" : "\u{1F7E8}"
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
  }

  // Saves the league-follow choice: no club, just the competition.
  function confirmLeague() {
    var leagueVal = root.safeIdentifier(String(selectedLeague || ""))
    if (leagueVal === "") return
    if (root.addingTeam) {
      root.addingTeam = false
      root.addFollowedLeague(leagueVal)
    } else {
      root.switchActiveLeague(leagueVal)
    }
  }

  // Switches the active view to whole-league tracking and refreshes matches.
  function activateLeague(league, followedTeamsOverride) {
    root.editingTeam = false
    var leagueVal = root.safeIdentifier(String(league || ""))
    if (leagueVal === "") return

    // Snapshot outgoing state if switching away
    var activeKey = root.itemKey(root.leagueMode ? "" : root.teamName, root.league, root.leagueMode)
    var destKey = root.itemKey("", leagueVal, true)
    if (activeKey !== destKey) {
      if (!root.leagueMode && root.teamName !== "") {
        root._teamStateCache[activeKey] = root.snapshotTeamState()
      }
    }

    root.saveFavorite("", leagueVal, "", followedTeamsOverride, true)
    root._queueSetBarWidget("league", leagueVal)
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

  function leagueLabel(code) {
    var target = code !== undefined ? String(code) : root.league
    for (var i = 0; i < leagues.length; i++) {
      if (leagues[i].value === target) return String(leagues[i].label)
    }
    return target
  }
  function leagueShortLabel(code) {
    var lbl = root.leagueLabel(code)
    return lbl.replace(/\s*\([^)]*\)\s*$/, "").trim()
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
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._runNextNotify()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._runNextNotify()
    }
    onExited: function(code) {
      root._runNextNotify()
    }
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
              if (!dItem) continue
              var dTypeStr = (dItem.type && dItem.type.text) ? String(dItem.type.text).toLowerCase() : ""
              var isRed = !!dItem.redCard || dTypeStr.indexOf("red card") !== -1
              if (dItem.scoringPlay || isRed) {
                if (dItem.shootout || dTypeStr.indexOf("shootout") !== -1) continue
                var dTeamId = dItem.team ? String(dItem.team.id || "") : ""
                var dClk = dItem.clock ? String(dItem.clock.displayValue || "") : ""
                var dAthList = Array.isArray(dItem.athletesInvolved) && dItem.athletesInvolved.length > 0 ? dItem.athletesInvolved : (Array.isArray(dItem.participants) ? dItem.participants : [])
                var dAth = dAthList.length > 0 ? (dAthList[0].athlete || dAthList[0]) : {}
                var dName = String(dAth.shortName || dAth.displayName || "")
                if (dName !== "") {
                  var eventObj = {
                    name: (isRed ? "🟥 " : "") + dName,
                    clock: dClk,
                    ownGoal: !isRed && !!dItem.ownGoal,
                    penaltyKick: !isRed && !!dItem.penaltyKick
                  }
                  if (homeTeam.id && dTeamId === String(homeTeam.id)) {
                    rawHomeScorers.push(eventObj)
                  } else if (awayTeam.id && dTeamId === String(awayTeam.id)) {
                    rawAwayScorers.push(eventObj)
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
              var isKRed = kTypeStr.indexOf("red card") !== -1
              var isKGoal = kTypeStr.indexOf("goal") !== -1 || kTypeStr.indexOf("penalty - scored") !== -1
              if (isKGoal || isKRed) {
                var kTeamId = kEv.team ? String(kEv.team.id || "") : ""
                var kClk = kEv.clock ? String(kEv.clock.displayValue || "") : ""
                var kAthList = Array.isArray(kEv.athletesInvolved) && kEv.athletesInvolved.length > 0 ? kEv.athletesInvolved : (Array.isArray(kEv.participants) ? kEv.participants : [])
                var kAth = kAthList.length > 0 ? (kAthList[0].athlete || kAthList[0]) : {}
                var kName = String(kAth.shortName || kAth.displayName || "")
                if (kName !== "") {
                  var eventObj2 = {
                    name: (isKRed ? "🟥 " : "") + kName,
                    clock: kClk,
                    ownGoal: !isKRed && kTypeStr.indexOf("own goal") !== -1,
                    penaltyKick: !isKRed && kTypeStr.indexOf("penalty") !== -1
                  }
                  if (homeTeam.id && kTeamId === String(homeTeam.id)) {
                    rawHomeScorers.push(eventObj2)
                  } else if (awayTeam.id && kTeamId === String(awayTeam.id)) {
                    rawAwayScorers.push(eventObj2)
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
                      var tag = pl.penaltyKick ? " (P)" : (pl.ownGoal ? " (OG)" : "")
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

          if (!isActuallyLive && root.matchDetailTab === "commentary") {
            root.matchDetailTab = isActuallyStarted ? "stats" : "info"
          }
          if (!isActuallyStarted && (root.matchDetailTab === "stats" || root.matchDetailTab === "events" || root.matchDetailTab === "commentary")) {
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
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.warnStderr("athletes stream", text)
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
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.warnStderr("athlete stats stream", text)
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
  Timer {
    id: searchDebounceTimer
    interval: 350
    repeat: false
    onTriggered: root.performSearch()
  }

  Process {
    id: searchRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.searchLoading = false
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) {
          return
        }
        try {
          var data = JSON.parse(text)
          var list = []
          var res = Array.isArray(data.results) ? data.results : []
          for (var i = 0; i < res.length; i++) {
            var group = res[i]
            var contents = Array.isArray(group.contents) ? group.contents : []
            for (var j = 0; j < contents.length; j++) {
              var item = contents[j]
              if (!item) continue
              var sport = String(item.sport || "").toLowerCase()
              if (sport !== "" && sport !== "soccer") continue
              var itemType = String(item.type || group.type || "").toLowerCase()
              if (itemType !== "player" && itemType !== "team") continue
              var rawId = ""
              var rawUid = String(item.uid || "")
              if (rawUid.indexOf("~a:") !== -1) {
                rawId = rawUid.substring(rawUid.indexOf("~a:") + 3)
              } else if (rawUid.indexOf("~t:") !== -1) {
                rawId = rawUid.substring(rawUid.indexOf("~t:") + 3)
              } else if (item.id) {
                rawId = String(item.id)
              }
              var img = ""
              if (item.image && typeof item.image === "object") {
                img = item.image.default || item.image.defaultDark || ""
              } else if (typeof item.image === "string") {
                img = item.image
              }
              list.push({
                type: itemType,
                id: rawId,
                uid: rawUid,
                displayName: String(item.displayName || ""),
                subtitle: String(item.subtitle || item.description || ""),
                description: String(item.description || ""),
                leagueSlug: String(item.defaultLeagueSlug || ""),
                image: img,
                webUrl: item.link && item.link.web ? String(item.link.web) : ""
              })
            }
          }
          root.searchResults = list
          root.searchError = list.length === 0 ? "No players or clubs found" : ""
        } catch (e) {
          root.searchError = "Could not parse search results"
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.searchLoading = false
      }
    }
  }

  Process {
    id: searchPlayerDetailRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.searchPlayerLoading = false
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) {
          return
        }
        try {
          var p = JSON.parse(text)
          if (p) {
            var teamRef = p.defaultTeam && p.defaultTeam["$ref"] ? String(p.defaultTeam["$ref"]) : ""
            var teamIdMatch = teamRef.match(/\/teams\/(\d+)/)
            var resolvedTeamId = teamIdMatch ? teamIdMatch[1] : ""
            var teamCrestUrl = resolvedTeamId !== "" ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + resolvedTeamId + ".png") : ""
            var dLgRef = p.defaultLeague && p.defaultLeague["$ref"] ? String(p.defaultLeague["$ref"]) : ""
            var dLgMatch = dLgRef.match(/\/leagues\/([a-zA-Z0-9_.-]+)/)
            if (dLgMatch && dLgMatch[1]) {
              root.statsPlayerLeague = dLgMatch[1]
            }
            var dobStr = ""
            if (p.dateOfBirth) {
              try {
                var d = new Date(p.dateOfBirth)
                dobStr = Qt.formatDate(d, "MMM d, yyyy")
              } catch (ed) { dobStr = String(p.dateOfBirth) }
            }
            var bCity = p.birthPlace && p.birthPlace.city ? String(p.birthPlace.city) : ""
            var bCountry = p.birthPlace && p.birthPlace.country ? String(p.birthPlace.country) : ""
            var birthplace = bCity !== "" ? (bCountry !== "" ? bCity + ", " + bCountry : bCity) : bCountry
            var prof = Object.assign({}, root.selectedPlayerProfile || {})
            prof.fullName = String(p.fullName || p.displayName || prof.fullName || "")
            prof.jersey = p.jersey ? String(p.jersey) : (prof.jersey || "")
            prof.age = p.age ? String(p.age) : (prof.age || "")
            prof.position = p.position && p.position.displayName ? String(p.position.displayName) : (p.position && p.position.name ? String(p.position.name) : (prof.position || ""))
            prof.displayHeight = p.displayHeight ? String(p.displayHeight) : (prof.displayHeight || "")
            prof.displayWeight = p.displayWeight ? String(p.displayWeight) : (prof.displayWeight || "")
            prof.citizenship = p.citizenship ? String(p.citizenship) : (p.citizenshipCountry ? String(p.citizenshipCountry) : (prof.citizenship || ""))
            prof.birthplace = birthplace !== "" ? birthplace : (prof.birthplace || "")
            prof.dateOfBirth = dobStr !== "" ? dobStr : (prof.dateOfBirth || "")
            prof.status = p.status && p.status.name ? String(p.status.name) : (prof.status || "Active")
            if (p.headshot && p.headshot.href) prof.headshot = String(p.headshot.href)
            if (p.flag && p.flag.href) prof.flag = String(p.flag.href)
            if (teamCrestUrl !== "") prof.teamCrest = teamCrestUrl
            root.selectedPlayerProfile = prof
          }
        } catch (e) {}
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root.searchPlayerLoading = false }
    }
  }

  Process {
    id: searchPlayerStatsRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152 || !root.selectedPlayerProfile) return
        try {
          var data = JSON.parse(text)
          var cats = data && Array.isArray(data.splits && data.splits.categories) ? data.splits.categories : []
          var statMap = {}
          for (var ci = 0; ci < cats.length; ci++) {
            var stList = cats[ci].stats || []
            for (var si = 0; si < stList.length; si++) {
              statMap[stList[si].name] = String(stList[si].displayValue !== undefined ? stList[si].displayValue : stList[si].value)
            }
          }
          var prof = root.selectedPlayerProfile
          if (prof) {
            var num = function(v) { var n = parseFloat(v); return isNaN(n) ? -1 : n }
            var shotsSum = ""
            var inBox = num(statMap["attemptsInBox"])
            var outBox = num(statMap["attemptsOutBox"])
            if (inBox >= 0 && outBox >= 0) shotsSum = String(Math.round(inBox + outBox))
            else if (inBox >= 0) shotsSum = String(Math.round(inBox))
            else if (outBox >= 0) shotsSum = String(Math.round(outBox))
            prof.careerAppearances = statMap["appearances"] || ""
            prof.careerGoals = statMap["totalGoals"] || ""
            prof.careerAssists = statMap["goalAssists"] || ""
            prof.careerKeyPasses = statMap["shotAssists"] || ""
            prof.careerPasses = statMap["accuratePasses"] || statMap["totalPasses"] || ""
            prof.careerPassPct = statMap["passPct"] ? (Math.round(parseFloat(statMap["passPct"]) * 100) + "%") : ""
            prof.careerFreeKicks = statMap["freeKickGoals"] || ""
            prof.careerTackles = statMap["effectiveTackles"] || statMap["totalTackles"] || ""
            prof.careerInterceptions = statMap["interceptions"] || ""
            prof.careerShots = statMap["totalShots"] || shotsSum
            prof.careerShotsOnTarget = statMap["shotsOnTarget"] || ""
            prof.careerSaves = statMap["saves"] || ""
            prof.careerCleanSheets = statMap["cleanSheet"] || ""
            if (statMap["passPct"]) statMap["passPct"] = prof.careerPassPct
            prof.careerStatMap = statMap

            var lb = statMap["accurateLongBalls"] || statMap["totalLongBalls"] || ""
            var kp = statMap["shotAssists"] || ""
            if (lb !== "") prof.longBalls = lb
            if (kp !== "") prof.keyPasses = kp
            if (prof.longBalls && prof.keyPasses) {
              prof.passDistribution = prof.longBalls + " LB · " + prof.keyPasses + " KP"
            }
            if (statMap["subIns"] || statMap["subOuts"]) {
              prof.seasonSubIns = String(statMap["subIns"] || "0")
              prof.seasonSubOuts = String(statMap["subOuts"] || "0")
              prof.seasonSubs = String((parseInt(prof.seasonSubIns) || 0) + (parseInt(prof.seasonSubOuts) || 0))
            }
            if (statMap["yellowCards"] && (!prof.seasonYellowCards || prof.seasonYellowCards === "0")) {
              prof.seasonYellowCards = String(statMap["yellowCards"])
            }
            if (statMap["redCards"] && (!prof.seasonRedCards || prof.seasonRedCards === "0")) {
              prof.seasonRedCards = String(statMap["redCards"])
            }
            if ((!prof.goalConversionRate || prof.goalConversionRate === "—") && prof.careerShots && prof.careerGoals) {
              var cShots = parseFloat(prof.careerShots) || 0
              var cGoals = parseFloat(prof.careerGoals) || 0
              if (cShots > 0) {
                prof.goalConversionRate = ((cGoals / cShots) * 100).toFixed(1) + "%"
              }
            }
            if ((!prof.shotAccuracy || prof.shotAccuracy === "—") && prof.careerShots && prof.careerShotsOnTarget) {
              var cShots2 = parseFloat(prof.careerShots) || 0
              var cSog = parseFloat(prof.careerShotsOnTarget) || 0
              if (cShots2 > 0) {
                prof.shotAccuracy = Math.round((cSog / cShots2) * 100) + "%"
              }
            }

            root.selectedPlayerProfile = Object.assign({}, prof)
            root.playerStatsLoading = false
          }
        } catch (e) {}
      }
    }
  }
  Process {
    id: searchPlayerSeasonStatsRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152 || !root.selectedPlayerProfile) return
        try {
          var data = JSON.parse(text)
          var cats = data && Array.isArray(data.splits && data.splits.categories) ? data.splits.categories : []
          if (!cats || cats.length === 0) {
            root.playerStatsLoading = false
            return
          }
          var statMap = {}
          for (var ci = 0; ci < cats.length; ci++) {
            var stList = cats[ci].stats || []
            for (var si = 0; si < stList.length; si++) {
              statMap[stList[si].name] = String(stList[si].displayValue !== undefined ? stList[si].displayValue : stList[si].value)
            }
          }
          var curCmd = searchPlayerSeasonStatsRequest.command
          var curCompUrl = (curCmd && curCmd.length > 0) ? curCmd[curCmd.length - 1] : ""
          if (curCompUrl !== "") {
            if (!root.playerCompStatCache) root.playerCompStatCache = ({})
            root.playerCompStatCache[curCompUrl] = statMap
          }
          root.applyPlayerStatsView()
        } catch (e) {
          root.playerStatsLoading = false
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.playerStatsLoading = false
      }
    }
  }

  Process {
    id: searchCompQueueRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var curUrl = (root.playerCompStatQueue && root.playerCompStatQueue.length > 0) ? root.playerCompStatQueue.shift() : ""
        if (curUrl !== "" && typeof text === "string" && text.length > 0 && text.length <= 2097152) {
          try {
            var data = JSON.parse(text)
            var cats = data && Array.isArray(data.splits && data.splits.categories) ? data.splits.categories : []
            var statMap = {}
            for (var ci = 0; ci < cats.length; ci++) {
              var stList = cats[ci].stats || []
              for (var si = 0; si < stList.length; si++) {
                statMap[stList[si].name] = String(stList[si].displayValue !== undefined ? stList[si].displayValue : stList[si].value)
              }
            }
            if (!root.playerCompStatCache) root.playerCompStatCache = ({})
            root.playerCompStatCache[curUrl] = statMap
          } catch (e) {}
        }
        root.applyPlayerStatsView()
        root._fetchNextCompQueue()
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.playerCompStatQueue && root.playerCompStatQueue.length > 0) root.playerCompStatQueue.shift()
        root._fetchNextCompQueue()
      }
    }
  }

  function resolveTeamNameFromRef(ref) {
    if (!ref || typeof ref !== "string") return { name: "", logo: "", id: "" }
    if (ref.indexOf("/faux") !== -1 || ref.indexOf("faux?") !== -1) {
      var dMatch = ref.match(/[?&]displayName=([^&]+)/)
      if (dMatch) {
        try {
          return { name: decodeURIComponent(dMatch[1].replace(/\+/g, " ")), logo: "", id: "" }
        } catch (e) {
          return { name: dMatch[1].replace(/\+/g, " "), logo: "", id: "" }
        }
      }
      var nMatch = ref.match(/[?&]name=([^&]+)/)
      if (nMatch) {
        try {
          return { name: decodeURIComponent(nMatch[1].replace(/\+/g, " ")), logo: "", id: "" }
        } catch (e) {
          return { name: nMatch[1].replace(/\+/g, " "), logo: "", id: "" }
        }
      }
      var lMatch = ref.match(/[?&]location=([^&]+)/)
      if (lMatch) {
        try {
          return { name: decodeURIComponent(lMatch[1].replace(/\+/g, " ")), logo: "", id: "" }
        } catch (e) {
          return { name: lMatch[1].replace(/\+/g, " "), logo: "", id: "" }
        }
      }
      var slugM = ref.match(/[?&]slug=([^&]+)/)
      if (slugM) {
        try {
          var s = decodeURIComponent(slugM[1].replace(/[-_]/g, " "))
          return { name: s.charAt(0).toUpperCase() + s.slice(1), logo: "", id: "" }
        } catch (e) {
          return { name: slugM[1], logo: "", id: "" }
        }
      }
      return { name: "Unattached", logo: "", id: "" }
    }
    var tMatch = ref.match(/\/teams\/(\d+)/)
    if (tMatch) {
      var tid = tMatch[1]
      var knownName = ""
      if (root.teamNameCache && root.teamNameCache[tid]) {
        knownName = root.teamNameCache[tid]
      } else {
        knownName = root.teamNameForId(tid)
      }
      if (knownName === "" && root.selectedPlayerProfile) {
        var p = root.selectedPlayerProfile
        if (p.clubOptions && Array.isArray(p.clubOptions)) {
          for (var ci = 0; ci < p.clubOptions.length; ci++) {
            if (String(p.clubOptions[ci].teamId) === String(tid) && p.clubOptions[ci].name) {
              knownName = p.clubOptions[ci].name
              break
            }
          }
        }
        if (knownName === "" && p.careerHistory && Array.isArray(p.careerHistory)) {
          for (var chi = 0; chi < p.careerHistory.length; chi++) {
            if (String(p.careerHistory[chi].teamId) === String(tid) && p.careerHistory[chi].name) {
              knownName = p.careerHistory[chi].name
              break
            }
          }
        }
      }
      return {
        id: tid,
        name: knownName !== "" ? knownName : ("Team " + tid),
        logo: "https://a.espncdn.com/i/teamlogos/soccer/500/" + tid + ".png"
      }
    }
    return { name: "", logo: "", id: "" }
  }

  function formatTransferValue(rawAmt, amtType, currencyObj) {
    var currSign = "€"
    if (currencyObj) {
      if (currencyObj.sign) {
        currSign = currencyObj.sign
      } else if (currencyObj.code === "GBP") {
        currSign = "£"
      } else if (currencyObj.code === "USD") {
        currSign = "$"
      } else if (currencyObj.code === "EUR") {
        currSign = "€"
      }
    }
    var numVal = Number(rawAmt)
    if (!isNaN(numVal) && numVal > 0) {
      if (numVal >= 1000000) {
        var mVal = Math.round((numVal / 1000000) * 10) / 10
        return currSign + (mVal === Math.floor(mVal) ? Math.floor(mVal) : mVal) + "M"
      } else if (numVal >= 1000) {
        var kVal = Math.round((numVal / 1000) * 10) / 10
        return currSign + (kVal === Math.floor(kVal) ? Math.floor(kVal) : kVal) + "K"
      } else {
        return currSign + Math.round(numVal)
      }
    }
    var strAmt = String(rawAmt || "").toLowerCase().trim()
    var strType = String(amtType || "").toLowerCase().trim()
    if (strAmt === "free" || strType === "free") return "Free Transfer"
    if (strAmt === "loan" || strType === "loan") return "Loan"
    if (strAmt === "undisclosed" || strType === "undisclosed") return "Undisclosed"
    if (strType === "fee" && (rawAmt === "" || numVal === 0)) return "Undisclosed Fee"
    if (rawAmt !== "" && isNaN(numVal)) return String(rawAmt)
    if (amtType !== "") return String(amtType)
    return "Undisclosed"
  }

  function resolveReportedTransferFee(athleteId, toTeamId, year) {
    if (!athleteId) return ""
    var aId = String(athleteId)
    var tId = String(toTeamId || "")
    var yr = String(year || "")
    var map = {
      // Raphinha (231050)
      "231050_83": "€58M (~£50M)",
      "231050_357": "€20M (~£17M)",
      "231050_2022": "€58M (~£50M)",
      "231050_2020": "€20M (~£17M)",

      // Erling Haaland (253989)
      "253989_382": "€60M (~£51.2M)",
      "253989_124": "€20M",
      "253989_2022": "€60M (~£51.2M)",

      // Jude Bellingham (291281)
      "291281_86": "€103M (~£88.5M)",
      "291281_124": "€30M (~£25M)",
      "291281_2023": "€103M (~£88.5M)",

      // Declan Rice (238262)
      "238262_359": "£100M (~€116M)",
      "238262_2023": "£100M (~€116M)",

      // Harry Kane (142200)
      "142200_132": "€95M (~£86M)",
      "142200_2023": "€95M (~£86M)",

      // Moisés Caicedo (289877)
      "289877_363": "£115M (~€133M)",
      "289877_331": "€5M",
      "289877_2023": "£115M (~€133M)",

      // Cole Palmer (296395)
      "296395_363": "£40M (~€47M)",
      "296395_2023": "£40M (~€47M)",

      // Julián Álvarez (277206)
      "277206_1068": "€75M (~£64M)",
      "277206_382": "€21.4M (~£18M)",
      "277206_2024": "€75M (~£64M)",

      // Jack Grealish (186640)
      "186640_382": "£100M (~€117M)",
      "186640_2021": "£100M (~€117M)",

      // Antony (257008)
      "257008_360": "€95M (~£82M)",
      "257008_2022": "€95M (~£82M)",

      // Casemiro (158394)
      "158394_360": "€70M (~£60M)",
      "158394_2022": "€70M (~£60M)",

      // Joško Gvardiol (285552)
      "285552_382": "€90M (~£77M)",
      "285552_2023": "€90M (~£77M)",

      // Robert Lewandowski (103297)
      "103297_83": "€45M (~£38M)",
      "103297_2022": "€45M (~£38M)",

      // Kai Havertz (219438)
      "219438_359": "£65M (~€75M)",
      "219438_363": "€80M (~£71M)",
      "219438_2023": "£65M (~€75M)",

      // Mason Mount (227658)
      "227658_360": "£55M (~£64M)",
      "227658_2023": "£55M (~£64M)",

      // Rasmus Højlund (308691)
      "308691_360": "€75M (~£64M)",
      "308691_2023": "€75M (~£64M)",

      // Dominik Szoboszlai (250325)
      "250325_364": "€70M (~£60M)",
      "250325_2023": "€70M (~£60M)",

      // Alexis Mac Allister (247167)
      "247167_364": "£35M (~€42M)",
      "247167_2023": "£35M (~€42M)",

      // Alexander Isak (223403)
      "223403_361": "€70M (~£60M)",
      "223403_2022": "€70M (~£60M)",

      // Sandro Tonali (257058)
      "257058_361": "€70M (~£58M)",
      "257058_2023": "€70M (~£58M)",

      // Cristiano Ronaldo (22774)
      "22774_360": "€15M (~£12.8M)",
      "22774_111": "€100M",
      "22774_2021": "€15M (~£12.8M)",
      "22774_2018": "€100M",

      // Neymar (102765)
      "102765_160": "€222M",
      "102765_7335": "€90M",
      "102765_2017": "€222M",
      "102765_2023": "€90M",

      // Eden Hazard (42786)
      "42786_86": "€100M (~£88M)",
      "42786_2019": "€100M (~£88M)",

      // Philippe Coutinho (104336)
      "104336_83": "€135M (~£120M)",
      "104336_2018": "€135M (~£120M)"
    }
    return (tId !== "" ? map[aId + "_" + tId] : null) || (yr !== "" ? map[aId + "_" + yr] : null) || ""
  }

  function updateTransferTeamNames() {
    var p = root.selectedPlayerProfile
    if (!p || !p.transferHistory || p.transferHistory.length === 0) return
    var changed = false
    var list = p.transferHistory.slice()
    for (var i = 0; i < list.length; i++) {
      var item = Object.assign({}, list[i])
      if (item.fromId && root.teamNameCache && root.teamNameCache[item.fromId] && item.fromName !== root.teamNameCache[item.fromId]) {
        item.fromName = root.teamNameCache[item.fromId]
        changed = true
      }
      if (item.toId && root.teamNameCache && root.teamNameCache[item.toId] && item.toName !== root.teamNameCache[item.toId]) {
        item.toName = root.teamNameCache[item.toId]
        changed = true
      }
      list[i] = item
    }
    if (changed) {
      p.transferHistory = list
      if (list.length > 0) {
        var last = list[0]
        var yr = last.year ? (" (" + last.year + ")") : ""
        p.transferInfo = (last.fromName || "Unknown") + " → " + (last.toName || "Unknown") + " : " + last.fee + yr
      }
      root.selectedPlayerProfile = Object.assign({}, p)
    }
  }

  function _resolveNextTransferTeam() {
    if (searchTransferTeamRequest.running) return
    if (!root.transferTeamQueue || root.transferTeamQueue.length === 0) return
    var tid = root.transferTeamQueue.shift()
    if (!tid || tid === "") return
    if (root.teamNameCache && root.teamNameCache[tid]) {
      root._resolveNextTransferTeam()
      return
    }
    root._transferTeamInFlight = tid
    searchTransferTeamRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "10", "--max-filesize", "1048576",
      "https://sports.core.api.espn.com/v2/sports/soccer/teams/" + encodeURIComponent(tid)]
    searchTransferTeamRequest.running = true
  }

  Process {
    id: searchPlayerBioRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152 || !root.selectedPlayerProfile) return
        try {
          var data = JSON.parse(text)
          var th = data && Array.isArray(data.teamHistory) ? data.teamHistory : []
          if (!root.teamNameCache) root.teamNameCache = ({})
          var natList = []
          for (var i = 0; i < th.length; i++) {
            var t = th[i]
            if (t && t.id) {
              var tId = String(t.id)
              var tName = String(t.displayName || t.name || "")
              root.teamNameCache[tId] = tName
              var tLogo = String(t.logo || "")
              var tSlug = String(t.slug || "").toLowerCase()
              var tLower = tName.toLowerCase()

              // Check if team is explicitly a club from its links or logo path
              var isClub = false
              if (t.links && Array.isArray(t.links)) {
                for (var li = 0; li < t.links.length; li++) {
                  var href = t.links[li] && t.links[li].href ? String(t.links[li].href) : ""
                  if (href.indexOf("/club/") !== -1) {
                    isClub = true
                    break
                  }
                }
              }
              if (tLogo.indexOf("/teamlogos/soccer/") !== -1 || tLogo.indexOf("/soccer/") !== -1) {
                isClub = true
              }

              // A team is a national team if:
              // 1. Its logo is hosted on the ESPN /countries/ CDN path, OR
              // 2. Its slug is a 2-3 letter country code (e.g. "bra", "arg", "eng", or youth "esp.u23"), OR
              // 3. Its name indicates a national team,
              // AND it is NOT an explicit club team.
              var isCountryLogo = tLogo.indexOf("/countries/") !== -1
              var isCountrySlug = (/^[a-z]{2,3}$/i.test(tSlug)) || (/^[a-z]{2,3}\.u\d+$/i.test(tSlug))
              var isNationalName = tLower.indexOf("national team") !== -1
              var isNat = !isClub && (isCountryLogo || isCountrySlug || isNationalName)

              if (isNat) {
                var isYouth = (tName.match(/\bU-?\d{1,2}\b/i) !== null) || (tSlug.indexOf(".u") !== -1) || (tLower.indexOf("youth") !== -1)
                var rawSeasons = String(t.seasons || "")
                var cleanSeasons = rawSeasons
                var yrMatches = rawSeasons.match(/\b(19\d\d|20\d\d)\b/g)
                if (yrMatches && yrMatches.length > 0) {
                  var minY = parseInt(yrMatches[0])
                  var maxY = parseInt(yrMatches[0])
                  for (var mi = 1; mi < yrMatches.length; mi++) {
                    var yVal = parseInt(yrMatches[mi])
                    if (yVal < minY) minY = yVal
                    if (yVal > maxY) maxY = yVal
                  }
                  cleanSeasons = minY === maxY ? String(minY) : (minY + "–" + maxY)
                }
                var slugCountry = tSlug.split(".")[0]
                var defaultCountryLogo = (slugCountry !== "" && slugCountry.length <= 3) ? ("https://a.espncdn.com/i/teamlogos/countries/500/" + slugCountry + ".png") : ""
                var finalLogo = root.sanitizeImageUrl(tLogo !== "" ? tLogo : (defaultCountryLogo !== "" ? defaultCountryLogo : (root.selectedPlayerProfile ? root.selectedPlayerProfile.flag : "")))

                var existing = false
                for (var ni = 0; ni < natList.length; ni++) {
                  if (natList[ni].id === tId || (natList[ni].name === tName && natList[ni].isYouth === isYouth)) {
                    existing = true
                    break
                  }
                }
                if (existing) continue

                natList.push({
                  id: tId,
                  name: tName,
                  isYouth: isYouth,
                  type: isYouth ? "Youth International" : "Senior National Team",
                  seasons: cleanSeasons,
                  seasonCount: String(t.seasonCount || "1"),
                  logo: finalLogo
                })
              }
            }
          }
          if (root.selectedPlayerProfile) {
            var prof = Object.assign({}, root.selectedPlayerProfile)
            prof.nationalTeams = natList
            root.selectedPlayerProfile = prof
          }
          root.updateTransferTeamNames()
          root._resolveNextTransferTeam()
        } catch (e) {}
      }
    }
  }

  Process {
    id: searchTransferTeamRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var tid = root._transferTeamInFlight
        root._transferTeamInFlight = ""
        if (tid !== "" && typeof text === "string" && text.length > 0 && text.length <= 1048576) {
          try {
            var data = JSON.parse(text)
            var tName = String(data.displayName || data.name || data.shortDisplayName || "")
            if (tName !== "") {
              if (!root.teamNameCache) root.teamNameCache = ({})
              root.teamNameCache[tid] = tName
              root.updateTransferTeamNames()
            } else {
              if (!root.teamNameCache) root.teamNameCache = ({})
              root.teamNameCache[tid] = "Team " + tid
            }
          } catch (e) {
            if (!root.teamNameCache) root.teamNameCache = ({})
            root.teamNameCache[tid] = "Team " + tid
          }
        } else if (tid !== "") {
          if (!root.teamNameCache) root.teamNameCache = ({})
          root.teamNameCache[tid] = "Team " + tid
        }
        root._resolveNextTransferTeam()
      }
    }
  }

  Process {
    id: searchPlayerTransactionsRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152 || !root.selectedPlayerProfile) return
        try {
          var data = JSON.parse(text)
          var items = data && Array.isArray(data.items) ? data.items : []
          var txList = []
          for (var ti = 0; ti < items.length; ti++) {
            var item = items[ti]
            if (!item) continue
            var fromRef = item.from && item.from["$ref"] ? String(item.from["$ref"]) : ""
            var toRef = item.to && item.to["$ref"] ? String(item.to["$ref"]) : ""
            var fromInfo = root.resolveTeamNameFromRef(fromRef)
            var toInfo = root.resolveTeamNameFromRef(toRef)

            var rawAmt = item.displayAmount !== undefined ? String(item.displayAmount) : (item.amount !== undefined ? String(item.amount) : "")
            var amtType = item.type ? String(item.type) : ""
            var numVal = Number(rawAmt)
            var feeVal = root.formatTransferValue(rawAmt, amtType, item.currency)

            var dStr = ""
            var yStr = ""
            var timestamp = 0
            if (item.date) {
              try {
                var dObj = new Date(item.date)
                if (!isNaN(dObj.getTime())) {
                  timestamp = dObj.getTime()
                  yStr = Qt.formatDate(dObj, "yyyy")
                  dStr = Qt.formatDate(dObj, "MMM yyyy")
                } else {
                  var ym = String(item.date).match(/\b(19\d\d|20\d\d)\b/)
                  if (ym) yStr = ym[1]
                }
              } catch (ed) {
                var ym2 = String(item.date).match(/\b(19\d\d|20\d\d)\b/)
                if (ym2) yStr = ym2[1]
              }
            }

            var athRef = item.athlete && item.athlete["$ref"] ? String(item.athlete["$ref"]) : ""
            var athMatch = athRef.match(/athletes\/(\d+)/)
            var athId = athMatch ? athMatch[1] : (root.statsPlayerKey || "")
            if (feeVal === "Undisclosed" || feeVal === "Undisclosed Fee") {
              var repFee = root.resolveReportedTransferFee(athId, toInfo.id, yStr)
              if (repFee !== "") feeVal = repFee
            }

            if (fromInfo.id && (!root.teamNameCache || !root.teamNameCache[fromInfo.id])) {
              if (root.transferTeamQueue.indexOf(fromInfo.id) === -1) root.transferTeamQueue.push(fromInfo.id)
            }
            if (toInfo.id && (!root.teamNameCache || !root.teamNameCache[toInfo.id])) {
              if (root.transferTeamQueue.indexOf(toInfo.id) === -1) root.transferTeamQueue.push(toInfo.id)
            }

            txList.push({
              fromName: fromInfo.name || "Unknown",
              fromLogo: fromInfo.logo || "",
              fromId: fromInfo.id || "",
              toName: toInfo.name || "Unknown",
              toLogo: toInfo.logo || "",
              toId: toInfo.id || "",
              fee: feeVal,
              rawAmount: !isNaN(numVal) ? numVal : 0,
              type: amtType,
              date: dStr !== "" ? dStr : yStr,
              year: yStr,
              timestamp: timestamp
            })
          }

          txList.sort(function(a, b) {
            return (b.timestamp || 0) - (a.timestamp || 0)
          })

          var info = ""
          if (txList.length > 0) {
            var latest = txList[0]
            var yr = latest.year ? (" (" + latest.year + ")") : ""
            info = latest.fromName + " → " + latest.toName + " : " + latest.fee + yr
          }

          var prof = root.selectedPlayerProfile
          if (prof) {
            prof.transferFetched = true
            prof.transferHistory = txList
            if (info !== "") prof.transferInfo = info
            root.selectedPlayerProfile = Object.assign({}, prof)
          }
          root.playerStatsLoading = false
          if (root.transferTeamQueue.length > 0) {
            root._resolveNextTransferTeam()
          }
        } catch (e) {
          root.playerStatsLoading = false
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var prof = root.selectedPlayerProfile
        if (prof && !prof.transferFetched) {
          prof.transferFetched = true
          root.selectedPlayerProfile = Object.assign({}, prof)
        }
        root.playerStatsLoading = false
      }
    }
  }

  Process {
    id: searchPlayerLogRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152 || !root.selectedPlayerProfile) return
        try {
          var logData = JSON.parse(text)
          var entries = logData && Array.isArray(logData.entries) ? logData.entries : []
          var teamMap = {}
          var isIntlLeague = function(lg) {
            return root.isIntlLeague(lg)
          }
          for (var ei = 0; ei < entries.length; ei++) {
            var entry = entries[ei]
            var sRef = entry.season && entry.season["$ref"] ? String(entry.season["$ref"]) : ""
            var statSets = entry.statistics && Array.isArray(entry.statistics) ? entry.statistics : []
            var totalSet = null
            for (var sj = 0; sj < statSets.length; sj++) {
              if (statSets[sj] && statSets[sj].type === "total") { totalSet = statSets[sj]; break }
            }
            if (!totalSet && statSets.length > 0) totalSet = statSets[0]
            var tRef = totalSet && totalSet.team && totalSet.team["$ref"] ? String(totalSet.team["$ref"]) : ""
            var lRef = totalSet && totalSet.league && totalSet.league["$ref"] ? String(totalSet.league["$ref"]) : ""
            var statUrl = totalSet && totalSet.statistics && totalSet.statistics["$ref"] ? String(totalSet.statistics["$ref"]) : ""
            var sMatch = sRef.match(/\/seasons\/(\d+)/)
            var tMatch = tRef.match(/\/teams\/(\d+)/)
            var lMatch = lRef.match(/\/leagues\/([a-zA-Z0-9_.-]+)/)
            var year = sMatch ? sMatch[1] : ""
            var teamId = tMatch ? tMatch[1] : ""
            var lgSlug = lMatch ? lMatch[1] : ""
            if (teamId !== "" && year !== "") {
              if (root.isPreseasonLeague(lgSlug)) continue
              if (!teamMap[teamId]) {
                teamMap[teamId] = { teamId: teamId, start: parseInt(year), end: parseInt(year), leagues: [], urls: [] }
              } else {
                var yInt = parseInt(year)
                if (yInt < teamMap[teamId].start) teamMap[teamId].start = yInt
                if (yInt > teamMap[teamId].end) teamMap[teamId].end = yInt
              }
              if (lgSlug !== "" && teamMap[teamId].leagues.indexOf(lgSlug) === -1) {
                teamMap[teamId].leagues.push(lgSlug)
              }
              if (statUrl !== "" && teamMap[teamId].urls.indexOf(statUrl) === -1) {
                teamMap[teamId].urls.push(statUrl)
              }
            }
          }
          var historyList = []
          var tKeys = Object.keys(teamMap)
          for (var ki = 0; ki < tKeys.length; ki++) {
            var tInfo = teamMap[tKeys[ki]]
            // Exclude national teams: only keep teams that played in club leagues
            var hasOnlyIntl = tInfo.leagues.length > 0 && tInfo.leagues.every(isIntlLeague)
            if (hasOnlyIntl) continue
            historyList.push({
              teamId: tInfo.teamId,
              teamLogo: "https://a.espncdn.com/i/teamlogos/soccer/500/" + tInfo.teamId + ".png",
              years: tInfo.start === tInfo.end ? String(tInfo.start) : (tInfo.start + "–" + tInfo.end)
            })
          }
          historyList.sort(function(a, b) {
            var aStart = parseInt(String(a.years).split("–")[0]) || 0
            var bStart = parseInt(String(b.years).split("–")[0]) || 0
            return bStart - aStart
          })
          var prof2 = root.selectedPlayerProfile
          if (prof2) {
            prof2.careerHistory = historyList.slice(0, 10)
            prof2.teamSeasonMap = teamMap
            prof2.clubOptions = []
            prof2.clubStatMap = null
            prof2.clubAggCache = ({})
            prof2.clubFilterId = "all"
            prof2.clubFilterLoading = false
            // Group entries by season year to discover all competitions for each season
            var seasonCompsByYear = {}
            for (var ei = 0; ei < entries.length; ei++) {
              var ent = entries[ei]
              var sRef = ent.season && ent.season["$ref"] ? String(ent.season["$ref"]) : ""
              var statSets = ent.statistics && Array.isArray(ent.statistics) ? ent.statistics : []
              var tSet = null
              for (var sj = 0; sj < statSets.length; sj++) {
                if (statSets[sj] && statSets[sj].type === "total") { tSet = statSets[sj]; break }
              }
              if (!tSet && statSets.length > 0) tSet = statSets[0]
              var lRef = tSet && tSet.league && tSet.league["$ref"] ? String(tSet.league["$ref"]) : ""
              var stUrl = tSet && tSet.statistics && tSet.statistics["$ref"] ? String(tSet.statistics["$ref"]) : ""
              var sMatch = sRef.match(/\/seasons\/(\d+)/)
              var lMatch = lRef.match(/\/leagues\/([a-zA-Z0-9_.-]+)/)
              var yr = sMatch ? parseInt(sMatch[1]) : 0
              var lg = lMatch ? lMatch[1].toLowerCase() : ""
              if (stUrl !== "" && yr > 0) {
                if (root.isPreseasonLeague(lg)) continue
                var isCountryComp = root.isIntlLeague(lg)
                var score = 0
                if (isCountryComp) {
                  score = 5
                } else if (lg.indexOf("super") !== -1 || lg.indexOf("charity") !== -1 || lg.indexOf("campeon") !== -1) {
                  score = 20
                } else if (lg.indexOf("cup") !== -1 || lg.indexOf("fa") !== -1 || lg.indexOf("copa") !== -1 || lg.indexOf("dfb") !== -1 || lg.indexOf("coppa") !== -1) {
                  score = 30
                } else if (lg.indexOf("champions") !== -1 || lg.indexOf("europa") !== -1 || lg.indexOf("libertadores") !== -1) {
                  score = 50
                } else if (/\.[12]$/.test(lg) || lg === "usa.1" || lg === "esp.1" || lg === "eng.1" || lg === "ger.1" || lg === "ita.1" || lg === "fra.1") {
                  score = 100
                } else {
                  score = 40
                }
                if (root.statsPlayerLeague && lg === root.statsPlayerLeague.toLowerCase()) {
                  score += 60
                }
                if (!seasonCompsByYear[yr]) seasonCompsByYear[yr] = []
                var cInfo = root.formatCompetitionName(lg)
                var cleanUrl = stUrl.replace(/^http:\/\//i, "https://")
                var existing = false
                for (var ci2 = 0; ci2 < seasonCompsByYear[yr].length; ci2++) {
                  if (seasonCompsByYear[yr][ci2].url === cleanUrl || seasonCompsByYear[yr][ci2].league === lg) {
                    existing = true
                    break
                  }
                }
                if (!existing) {
                  seasonCompsByYear[yr].push({
                    league: lg,
                    leagueName: cInfo.full,
                    shortName: cInfo.short,
                    url: cleanUrl,
                    isCountry: isCountryComp,
                    score: score
                  })
                }
              }
            }

            var availSeasons = []
            var availYears = Object.keys(seasonCompsByYear).map(Number).sort(function(a, b) { return b - a })
            for (var yi = 0; yi < availYears.length; yi++) {
              var yNum = availYears[yi]
              var compsForYr = seasonCompsByYear[yNum] || []
              compsForYr.sort(function(a, b) { return b.score - a.score })
              var yrLabel = yNum >= 2000 ? (yNum + "–" + String(yNum + 1).slice(-2)) : String(yNum)
              availSeasons.push({
                year: yNum,
                seasonYear: yrLabel,
                label: yrLabel,
                competitions: compsForYr
              })
            }

            prof2.availableSeasons = availSeasons
            prof2.selectedSeasonIndex = 0
            prof2.selectedCompIndex = 0
            prof2.selectedSeasonYear = availSeasons.length > 0 ? availSeasons[0].seasonYear : ""
            root.selectedPlayerProfile = Object.assign({}, prof2)

            if (availSeasons.length > 0) {
              root.applyPlayerStatsView()
            }

            root.maybeStartCareerAgg()
            root.ensureClubNames()
          }
        } catch (e) {}
      }
    }
  }
  Process {
    id: searchTeamNameRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var p = root.selectedPlayerProfile
          var teamId = root.clubNameQueue.length > 0 ? root.clubNameQueue[0] : ""
          root.clubNameQueue.shift()
          if (teamId !== "" && typeof text === "string" && text.length > 0 && text.length <= 2097152 && p && p.teamSeasonMap && p.teamSeasonMap[teamId]) {
            try {
              var data = JSON.parse(text)
              var t = data && data.team ? data.team : null
              if (t) {
                var info = p.teamSeasonMap[teamId]
                var yrs = info.start === info.end ? String(info.start) : (info.start + "–" + info.end)
                var opts = p.clubOptions ? p.clubOptions.slice() : []
                opts.push({
                  teamId: teamId,
                  name: String(t.displayName || t.name || ("Team " + teamId)),
                  logo: "https://a.espncdn.com/i/teamlogos/soccer/500/" + teamId + ".png",
                  years: yrs,
                  start: info.start
                })
                opts.sort(function(a, b) { return (b.start || 0) - (a.start || 0) })
                p.clubOptions = opts
                // Update careerHistory with resolved club names as well
                if (p.careerHistory && p.careerHistory.length > 0) {
                  for (var hi = 0; hi < p.careerHistory.length; hi++) {
                    if (p.careerHistory[hi].teamId === teamId) {
                      p.careerHistory[hi].name = String(t.shortDisplayName || t.displayName || t.name || "")
                    }
                  }
                }
                if (!root.teamNameCache) root.teamNameCache = ({})
                root.teamNameCache[teamId] = String(t.displayName || t.name || "")
                root.updateTransferTeamNames()
                root.selectedPlayerProfile = Object.assign({}, p)
              }
            } catch (e2) {}
          }
        } catch (e) {}
        root._resolveNextClubName()
      }
    }
  }
  Process {
    id: searchClubStatRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var p = root.selectedPlayerProfile
          if (root.clubAggQueue.length > 0) root.clubAggQueue.shift()
          if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && p && p.clubFilterId === root.clubAggTarget && p.clubFilterLoading) {
            try {
              var data = JSON.parse(text)
              var cats = data && Array.isArray(data.splits && data.splits.categories) ? data.splits.categories : []
              for (var ci = 0; ci < cats.length; ci++) {
                var stList = cats[ci].stats || []
                for (var si = 0; si < stList.length; si++) {
                  var nm = stList[si].name
                  if (/^avg/i.test(nm) || /^time/i.test(nm) || /pct$/i.test(nm)) continue
                  var raw = typeof stList[si].value === "number" ? stList[si].value : parseFloat(String(stList[si].displayValue !== undefined ? stList[si].displayValue : "").replace(/,/g, ""))
                  if (isNaN(raw)) continue
                  if (root.clubAggSums[nm] === undefined) root.clubAggSums[nm] = 0
                  root.clubAggSums[nm] += raw
                }
              }
            } catch (e2) {}
          }
          if (p && p.clubFilterId === root.clubAggTarget && p.clubFilterLoading) {
            root._fetchNextClubStat()
          }
        } catch (e) {}
      }
    }
  }
  Process {
    id: searchCareerAggRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var p = root.selectedPlayerProfile
          if (root.careerAggQueue.length > 0) root.careerAggQueue.shift()
          if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && p && root.statsPlayerKey === root.careerAggTarget && !p.careerAggDone) {
            try {
              var data = JSON.parse(text)
              var cats = data && Array.isArray(data.splits && data.splits.categories) ? data.splits.categories : []
              for (var ci = 0; ci < cats.length; ci++) {
                var stList = cats[ci].stats || []
                for (var si = 0; si < stList.length; si++) {
                  var nm = stList[si].name
                  if (nm !== "goalAssists" && nm !== "appearances" && nm !== "totalGoals") continue
                  var raw = typeof stList[si].value === "number" ? stList[si].value : parseFloat(String(stList[si].value))
                  if (!isFinite(raw)) continue
                  if (root.careerAggSums[nm] === undefined) root.careerAggSums[nm] = 0
                  root.careerAggSums[nm] += raw
                }
              }
            } catch (e2) {}
          }
          if (p && root.statsPlayerKey === root.careerAggTarget && !p.careerAggDone) {
            root._fetchNextCareerAgg()
          }
        } catch (e) {}
      }
    }
  }
  Timer {
    id: clubFetchTimeoutTimer
    interval: 8000
    repeat: false
    onTriggered: {
      root.searchClubLoading = false
      root._clubFetchPending = 0
    }
  }

  function _onClubFetchDone() {
    root._clubFetchPending = Math.max(0, root._clubFetchPending - 1)
    if (root._clubFetchPending === 0) {
      clubFetchTimeoutTimer.stop()
      root.searchClubLoading = false
    }
  }

  Process {
    id: searchClubDetailRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var res = JSON.parse(text)
            var t = res && res.team ? res.team : null
            if (t) {
              var rec = t.record && t.record.items && t.record.items[0] ? t.record.items[0] : null
              var statsList = rec && Array.isArray(rec.stats) ? rec.stats : []
              var getStat = function(name) {
                for (var si = 0; si < statsList.length; si++) {
                  if (statsList[si].name === name) return String(statsList[si].value)
                }
                return ""
              }
              var pts = getStat("points")
              var wins = getStat("wins")
              var ties = getStat("ties")
              var losses = getStat("losses")
              var diff = getStat("pointDifferential")
              var gf = getStat("pointsFor")
              var ga = getStat("pointsAgainst")
              var homeW = getStat("homeWins")
              var homeD = getStat("homeTies")
              var homeL = getStat("homeLosses")
              var awayW = getStat("awayWins")
              var awayD = getStat("awayTies")
              var awayL = getStat("awayLosses")
              var homeRec = (homeW !== "" || homeD !== "" || homeL !== "") ? (homeW + "W-" + homeD + "D-" + homeL + "L") : ""
              var awayRec = (awayW !== "" || awayD !== "" || awayL !== "") ? (awayW + "W-" + awayD + "D-" + awayL + "L") : ""
              var clr = t.color ? ("#" + String(t.color).replace("#", "")) : ""
              var altClr = t.alternateColor ? ("#" + String(t.alternateColor).replace("#", "")) : ""
              var vName = t.venue && t.venue.fullName ? String(t.venue.fullName) : (t.franchise && t.franchise.venue && t.franchise.venue.fullName ? String(t.franchise.venue.fullName) : "")
              var vCity = t.venue && t.venue.address && t.venue.address.city ? String(t.venue.address.city) : ""
              var venueStr = vName !== "" ? (vCity !== "" ? vName + " (" + vCity + ")" : vName) : ""
              var webLink = ""
              if (t.links && Array.isArray(t.links)) {
                for (var li = 0; li < t.links.length; li++) {
                  if (t.links[li].href && (t.links[li].rel && (t.links[li].rel.indexOf("clubhouse") !== -1 || t.links[li].rel.indexOf("desktop") !== -1))) {
                    webLink = t.links[li].href
                    break
                  }
                }
              }

              var prof = Object.assign({}, root.selectedClubProfile)
              prof.id = String(t.id || prof.id || "")
              prof.displayName = String(t.displayName || t.name || prof.displayName || "")
              if (t.abbreviation) prof.abbreviation = String(t.abbreviation)
              if (t.location) prof.location = String(t.location)
              if (t.standingSummary) prof.standingSummary = String(t.standingSummary)
              if (rec && rec.summary) prof.record = String(rec.summary)
              if (pts !== "") prof.points = pts
              if (wins !== "") prof.wins = wins
              if (ties !== "") prof.ties = ties
              if (losses !== "") prof.losses = losses
              if (diff !== "") prof.diff = diff
              if (gf !== "") prof.goalsFor = gf
              if (ga !== "") prof.goalsAgainst = ga
              if (homeRec !== "") prof.homeRecord = homeRec
              if (awayRec !== "") prof.awayRecord = awayRec
              if (venueStr !== "") prof.venue = venueStr
              if (t.nextEvent && t.nextEvent[0] && t.nextEvent[0].name) prof.nextEvent = String(t.nextEvent[0].name)
              if (t.nextEvent && t.nextEvent[0] && t.nextEvent[0].date) prof.nextEventDate = String(t.nextEvent[0].date)
              if (t.logos && t.logos[0] && t.logos[0].href) prof.logo = String(t.logos[0].href)
              if (clr !== "") prof.color = clr
              if (altClr !== "") prof.alternateColor = altClr
              if (t.form) prof.form = String(t.form)
              if (webLink !== "" && (!prof.webUrl || prof.webUrl === "")) prof.webUrl = webLink
              root.selectedClubProfile = prof
            }
          } catch (e) {}
        }
        root._onClubFetchDone()
      }
    }
  }

  Process {
    id: searchClubScheduleRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var sched = JSON.parse(text)
            var evs = sched && Array.isArray(sched.events) ? sched.events : []
            var mList = []
            for (var mi = 0; mi < evs.length && mList.length < 3; mi++) {
              var ev = evs[mi]
              var comp = ev.competitions && ev.competitions[0] ? ev.competitions[0] : null
              if (!comp) continue
              var comps = comp.competitors || []
              var h = (comps[0] && comps[0].homeAway === "home") ? comps[0] : ((comps[1] && comps[1].homeAway === "home") ? comps[1] : (comps[0] || {}))
              var a = (comps[1] && comps[1].homeAway === "away") ? comps[1] : ((comps[0] && comps[0].homeAway === "away") ? comps[0] : (comps[1] || {}))
              var hName = h.team && (h.team.abbreviation || h.team.shortDisplayName || h.team.displayName) ? (h.team.abbreviation || h.team.shortDisplayName || h.team.displayName) : "Home"
              var aName = a.team && (a.team.abbreviation || a.team.shortDisplayName || a.team.displayName) ? (a.team.abbreviation || a.team.shortDisplayName || a.team.displayName) : "Away"
              var hScore = h.score && h.score.displayValue !== undefined ? String(h.score.displayValue) : ""
              var aScore = a.score && a.score.displayValue !== undefined ? String(a.score.displayValue) : ""
              var statusText = comp.status && comp.status.type && comp.status.type.shortDetail ? String(comp.status.type.shortDetail) : ""
              mList.push({
                matchName: hName + " vs " + aName,
                score: (hScore !== "" && aScore !== "") ? (hScore + "–" + aScore) : statusText,
                date: ev.date ? Qt.formatDate(new Date(ev.date), "MMM d") : ""
              })
            }
            var prof = Object.assign({}, root.selectedClubProfile)
            prof.recentMatches = mList
            root.selectedClubProfile = prof
          } catch (e) {}
        }
        root._onClubFetchDone()
      }
    }
  }

  Process {
    id: searchClubStatsRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var sData = JSON.parse(text)
            var cats = sData && Array.isArray(sData.splits && sData.splits.categories) ? sData.splits.categories : []
            var sMap = {}
            for (var ci = 0; ci < cats.length; ci++) {
              var stList = cats[ci].stats || []
              for (var si = 0; si < stList.length; si++) {
                sMap[stList[si].name] = String(stList[si].displayValue !== undefined ? stList[si].displayValue : stList[si].value)
              }
            }
            var prof = Object.assign({}, root.selectedClubProfile)
            if (sMap["possessionPct"]) prof.possession = sMap["possessionPct"] + "%"
            if (sMap["totalShots"]) prof.shotsPerGame = sMap["totalShots"]
            if (sMap["shotsOnTarget"]) prof.shotsOnTarget = sMap["shotsOnTarget"]
            if (sMap["passPct"]) {
              var pp = parseFloat(sMap["passPct"])
              prof.passPct = (pp <= 1.0 ? Math.round(pp * 100) : Math.round(pp)) + "%"
            }
            if (sMap["cleanSheet"]) prof.cleanSheets = sMap["cleanSheet"]
            if (sMap["totalTackles"]) prof.tackles = sMap["totalTackles"]
            if (sMap["interceptions"]) prof.interceptions = sMap["interceptions"]
            if (sMap["yellowCards"] !== undefined) prof.yellowCards = sMap["yellowCards"]
            if (sMap["redCards"] !== undefined) prof.redCards = sMap["redCards"]
            if (sMap["secondYellow"] !== undefined) prof.secondYellow = sMap["secondYellow"]
            if (sMap["foulsCommitted"] !== undefined) prof.foulsCommitted = sMap["foulsCommitted"]
            var yc = parseInt(sMap["yellowCards"] || "0")
            var rc = parseInt(sMap["redCards"] || "0")
            prof.disciplinaryPoints = String((yc * 1) + (rc * 3))
            root.selectedClubProfile = prof
          } catch (e) {}
        }
        root._onClubFetchDone()
      }
    }
  }

  Process {
    id: searchClubCoreRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var cData = JSON.parse(text)
            var prof = Object.assign({}, root.selectedClubProfile)
            var vObj = cData && cData.venue ? cData.venue : null
            if (vObj) {
              var vName = String(vObj.fullName || vObj.name || "")
              var vCity = (vObj.address && vObj.address.city) ? String(vObj.address.city) : ""
              var vStr = vName !== "" ? (vCity !== "" ? vName + " (" + vCity + ")" : vName) : ""
              if (vStr !== "" && (!prof.venue || prof.venue === "")) {
                prof.venue = vStr
              }
            }
            if (cData && cData.form && (!prof.form || prof.form === "")) {
              prof.form = String(cData.form)
            }
            if (cData && cData.color && (!prof.color || prof.color === "")) {
              prof.color = "#" + String(cData.color).replace("#", "")
            }
            if (cData && cData.alternateColor && (!prof.alternateColor || prof.alternateColor === "")) {
              prof.alternateColor = "#" + String(cData.alternateColor).replace("#", "")
            }
            root.selectedClubProfile = prof
          } catch (e) {}
        }
        root._onClubFetchDone()
      }
    }
  }

  Process {
    id: searchClubFixturesRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var sched = JSON.parse(text)
            var evs = sched && Array.isArray(sched.events) ? sched.events : []
            var fixList = []
            for (var fi = 0; fi < evs.length && fixList.length < 3; fi++) {
              var ev = evs[fi]
              var comp = ev.competitions && ev.competitions[0] ? ev.competitions[0] : null
              if (!comp) continue
              var comps = comp.competitors || []
              var h = (comps[0] && comps[0].homeAway === "home") ? comps[0] : ((comps[1] && comps[1].homeAway === "home") ? comps[1] : (comps[0] || {}))
              var a = (comps[1] && comps[1].homeAway === "away") ? comps[1] : ((comps[0] && comps[0].homeAway === "away") ? comps[0] : (comps[1] || {}))
              var hTeam = h.team || {}
              var aTeam = a.team || {}
              var hName = String(hTeam.shortDisplayName || hTeam.displayName || "Home")
              var aName = String(aTeam.shortDisplayName || aTeam.displayName || "Away")
              var hLogo = (hTeam.logos && hTeam.logos[0] && hTeam.logos[0].href) ? String(hTeam.logos[0].href) : (hTeam.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + hTeam.id + ".png") : "")
              var aLogo = (aTeam.logos && aTeam.logos[0] && aTeam.logos[0].href) ? String(aTeam.logos[0].href) : (aTeam.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + aTeam.id + ".png") : "")
              var bList = []
              if (Array.isArray(comp.broadcasts)) {
                for (var bi = 0; bi < comp.broadcasts.length; bi++) {
                  var m = comp.broadcasts[bi].media
                  if (m && m.shortName) bList.push(m.shortName)
                }
              }
              var bStr = bList.join(", ")
              var compLabel = String((ev.league && (ev.league.shortName || ev.league.name || ev.league.abbreviation)) || "Soccer")
              var dateObj = ev.date ? new Date(ev.date) : null
              var dStr = dateObj ? Qt.formatDate(dateObj, "ddd, MMM d") : ""
              var tStr = dateObj ? Qt.formatTime(dateObj, "h:mm AP") : ""
              fixList.push({
                matchName: hName + " vs " + aName,
                homeTeam: hName,
                awayTeam: aName,
                homeLogo: hLogo,
                awayLogo: aLogo,
                competition: compLabel,
                date: dStr,
                time: tStr,
                broadcast: bStr !== "" ? bStr : "TBD"
              })
            }
            var prof = Object.assign({}, root.selectedClubProfile)
            prof.upcomingFixtures = fixList
            root.selectedClubProfile = prof
          } catch (e) {}
        }
        root._onClubFetchDone()
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root._onClubFetchDone() }
    }
  }

  Process {
    id: searchClubRosterRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var rData = JSON.parse(text)
            var aths = rData && Array.isArray(rData.athletes) ? rData.athletes : []
            var gks = [], defs = [], mids = [], fwds = [], allList = []
            for (var ai = 0; ai < aths.length; ai++) {
              var a = aths[ai]
              var pName = a.position && a.position.displayName ? String(a.position.displayName) : (a.position && a.position.name ? String(a.position.name) : "Other")
              var pLower = pName.toLowerCase()
              var pItem = {
                id: String(a.id || ""),
                name: String(a.displayName || a.fullName || "Player"),
                jersey: a.jersey ? String(a.jersey) : "—",
                age: a.age ? String(a.age) : "—",
                position: pName,
                flag: a.flag && a.flag.href ? String(a.flag.href) : "",
                country: a.citizenship ? String(a.citizenship) : (a.flag && a.flag.alt ? String(a.flag.alt) : ""),
                headshot: a.headshot && a.headshot.href ? String(a.headshot.href) : ""
              }
              allList.push(pItem)
              if (pLower.indexOf("goal") !== -1 || pLower === "gk" || pLower === "g") {
                pItem.posCat = "GK"
                gks.push(pItem)
              } else if (pLower.indexOf("def") !== -1 || pLower.indexOf("back") !== -1 || pLower === "df") {
                pItem.posCat = "DF"
                defs.push(pItem)
              } else if (pLower.indexOf("mid") !== -1 || pLower === "mf") {
                pItem.posCat = "MF"
                mids.push(pItem)
              } else if (pLower.indexOf("forw") !== -1 || pLower.indexOf("attack") !== -1 || pLower.indexOf("strik") !== -1 || pLower.indexOf("wing") !== -1 || pLower === "fw") {
                pItem.posCat = "FW"
                fwds.push(pItem)
              } else {
                pItem.posCat = "MF"
                mids.push(pItem)
              }
            }

            var coaches = rData && Array.isArray(rData.coach) ? rData.coach : []
            var mName = ""
            var staffList = []
            if (coaches.length > 0) {
              mName = String((coaches[0].firstName ? coaches[0].firstName + " " : "") + (coaches[0].lastName || coaches[0].displayName || coaches[0].name || "")).trim()
              for (var ci = 1; ci < coaches.length; ci++) {
                var s = String((coaches[ci].firstName ? coaches[ci].firstName + " " : "") + (coaches[ci].lastName || coaches[ci].displayName || coaches[ci].name || "")).trim()
                if (s !== "") staffList.push(s)
              }
            }

            var prof = Object.assign({}, root.selectedClubProfile)
            prof.rosterGoalkeepers = gks
            prof.rosterDefenders = defs
            prof.rosterMidfielders = mids
            prof.rosterForwards = fwds
            prof.rosterAll = allList
            if (mName !== "") prof.manager = mName
            prof.technicalStaff = staffList
            root.selectedClubProfile = prof
          } catch (e) {}
        }
        root._onClubFetchDone()
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root._onClubFetchDone() }
    }
  }

  Process {
    id: searchPlayerOverviewRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152 || !root.selectedPlayerProfile) return
        try {
          var data = JSON.parse(text)
          var gLog = data && data.gameLog ? data.gameLog : null
          var evMap = gLog && gLog.events ? gLog.events : {}
          var statTable = gLog && Array.isArray(gLog.statistics) && gLog.statistics.length > 0 ? gLog.statistics[0] : null
          var sNames = statTable && Array.isArray(statTable.names) ? statTable.names : []
          var sEvents = statTable && Array.isArray(statTable.events) ? statTable.events : []
          var matches = []
          for (var i = 0; i < sEvents.length && matches.length < 5; i++) {
            var sEv = sEvents[i]
            var evObj = evMap[sEv.eventId] || {}
            var compName = String(evObj.leagueShortName || evObj.leagueName || evObj.leagueAbbreviation || "").trim()
            var sVals = sEv.stats || []
            var statDict = {}
            for (var si = 0; si < sNames.length && si < sVals.length; si++) {
              statDict[sNames[si]] = sVals[si]
            }
            var dObj = evObj.gameDate ? new Date(evObj.gameDate) : null
            var dStr = dObj ? Qt.formatDate(dObj, "MMM d") : ""
            var opp = evObj.opponent || {}
            var resBadge = String(evObj.gameResult || "—").toUpperCase()
            var myTeam = (evObj.team && (evObj.team.displayName || evObj.team.shortDisplayName || evObj.team.name)) || ""
            if (!myTeam && root.selectedPlayerProfile && root.selectedPlayerProfile.teamName) {
              myTeam = root.selectedPlayerProfile.teamName
            }
            if (!myTeam && evObj.team && evObj.team.abbreviation) {
              myTeam = evObj.team.abbreviation
            }
            if (!myTeam) myTeam = "Team"
            var oppTeam = String(opp.displayName || opp.shortDisplayName || opp.name || opp.abbreviation || "Opponent")
            var isAway = (evObj.atVs === "@") || (evObj.team && evObj.team.id && evObj.awayTeamId && String(evObj.team.id) === String(evObj.awayTeamId))
            var matchTitle = isAway ? (oppTeam + " vs " + myTeam) : (myTeam + " vs " + oppTeam)

            var sc = ""
            if (evObj.homeTeamScore !== undefined && evObj.awayTeamScore !== undefined && evObj.homeTeamScore !== null && evObj.awayTeamScore !== null) {
              sc = String(evObj.homeTeamScore) + " – " + String(evObj.awayTeamScore)
            } else if (evObj.score) {
              sc = String(evObj.score).replace("-", " – ")
            }
            var rawMins = statDict["appearances"] ? String(statDict["appearances"]) : ""
            var minDisplay = ""
            if (rawMins === "Started") minDisplay = "Start"
            else if (rawMins === "Sub") minDisplay = "Sub"
            else if (/^\d+$/.test(rawMins)) minDisplay = rawMins + "'"
            else if (rawMins.indexOf("'") !== -1) minDisplay = rawMins
            else if (rawMins !== "") minDisplay = rawMins
            var g = statDict["totalGoals"] ? String(statDict["totalGoals"]) : "0"
            var a = statDict["goalAssists"] ? String(statDict["goalAssists"]) : "0"
            var shots = statDict["totalShots"] ? String(statDict["totalShots"]) : "0"
            var sog = statDict["shotsOnTarget"] ? String(statDict["shotsOnTarget"]) : "0"
            var gInt = parseInt(g) || 0
            var aInt = parseInt(a) || 0
            var shotsInt = parseInt(shots) || 0
            var sogInt = parseInt(sog) || 0
            var fcInt = parseInt(statDict["foulsCommitted"] || "0") || 0
            var fsInt = parseInt(statDict["foulsSuffered"] || "0") || 0
            var yInt = parseInt(statDict["yellowCards"] || "0") || 0
            var rInt = parseInt(statDict["redCards"] || "0") || 0

            var mRating = (evObj && evObj.rating !== undefined) ? parseFloat(evObj.rating) : ((statDict && statDict["rating"] !== undefined) ? parseFloat(statDict["rating"]) : null)
            if (mRating === null || isNaN(mRating) || mRating <= 0) {
              var baseScore = 6.0
              if (resBadge === "W") baseScore += 0.4
              else if (resBadge === "L") baseScore -= 0.3
              baseScore += gInt * 1.2
              baseScore += aInt * 0.7
              baseScore += sogInt * 0.2
              baseScore += Math.min(0.4, (shotsInt - sogInt) * 0.1)
              baseScore += Math.min(0.4, fsInt * 0.08)
              baseScore -= fcInt * 0.1
              baseScore -= yInt * 0.6
              baseScore -= rInt * 1.5
              if (rawMins === "Sub") baseScore = Math.min(baseScore, 6.8)
              mRating = Math.max(4.0, Math.min(10.0, baseScore))
            }
            var ratingDisplay = mRating ? mRating.toFixed(1) : "—"

            matches.push({
              leagueName: compName,
              date: dStr,
              result: resBadge,
              score: sc,
              matchTitle: matchTitle,
              opponentName: oppTeam,
              opponentAbbrev: String(opp.abbreviation || ""),
              opponentLogo: opp.logo ? String(opp.logo) : (opp.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + opp.id + ".png") : ""),
              isHome: !isAway,
              minutes: minDisplay,
              goals: g,
              assists: a,
              shots: shots,
              shotsOnTarget: sog,
              rating: ratingDisplay
            })
          }

          // Fallback: If no matches parsed from sEvents, extract from evMap directly
          if (matches.length === 0 && evMap) {
            var evKeys = Object.keys(evMap)
            evKeys.sort(function(a, b) {
              var da = evMap[a] && evMap[a].gameDate ? new Date(evMap[a].gameDate).getTime() : 0
              var db = evMap[b] && evMap[b].gameDate ? new Date(evMap[b].gameDate).getTime() : 0
              return db - da
            })
            for (var k = 0; k < evKeys.length && matches.length < 5; k++) {
              var evObj2 = evMap[evKeys[k]]
              if (!evObj2) continue
              var compName2 = String(evObj2.leagueShortName || evObj2.leagueName || evObj2.leagueAbbreviation || "").trim()
              var dObj2 = evObj2.gameDate ? new Date(evObj2.gameDate) : null
              var dStr2 = dObj2 ? Qt.formatDate(dObj2, "MMM d") : ""
              var opp2 = evObj2.opponent || {}
              var resBadge2 = String(evObj2.gameResult || "—").toUpperCase()
              var sc2 = ""
              if (evObj2.homeTeamScore !== undefined && evObj2.awayTeamScore !== undefined && evObj2.homeTeamScore !== null && evObj2.awayTeamScore !== null) {
                sc2 = String(evObj2.homeTeamScore) + " – " + String(evObj2.awayTeamScore)
              } else if (evObj2.score) {
                sc2 = String(evObj2.score).replace("-", " – ")
              }
              var myTeam2 = (evObj2.team && (evObj2.team.displayName || evObj2.team.shortDisplayName || evObj2.team.name)) || ""
              if (!myTeam2 && root.selectedPlayerProfile && root.selectedPlayerProfile.teamName) {
                myTeam2 = root.selectedPlayerProfile.teamName
              }
              if (!myTeam2 && evObj2.team && evObj2.team.abbreviation) {
                myTeam2 = evObj2.team.abbreviation
              }
              if (!myTeam2) myTeam2 = "Team"
              var oppName2 = String(opp2.displayName || opp2.shortDisplayName || opp2.name || opp2.abbreviation || "Opponent")
              var isAway2 = (evObj2.atVs === "@") || (evObj2.team && evObj2.team.id && evObj2.awayTeamId && String(evObj2.team.id) === String(evObj2.awayTeamId))
              var matchTitle2 = isAway2 ? (oppName2 + " vs " + myTeam2) : (myTeam2 + " vs " + oppName2)
              var oppLogo2 = opp2.logo ? String(opp2.logo) : (opp2.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + opp2.id + ".png") : "")
              var mRating2 = (evObj2 && evObj2.rating !== undefined) ? parseFloat(evObj2.rating) : (resBadge2 === "W" ? 7.2 : (resBadge2 === "D" ? 6.6 : 6.0))
              matches.push({
                leagueName: compName2,
                date: dStr2,
                result: resBadge2,
                score: sc2,
                matchTitle: matchTitle2,
                opponentName: oppName2,
                opponentAbbrev: String(opp2.abbreviation || ""),
                opponentLogo: oppLogo2,
                isHome: !isAway2,
                minutes: "Played",
                goals: "0",
                assists: "0",
                shots: "0",
                shotsOnTarget: "0",
                rating: mRating2 ? mRating2.toFixed(1) : "—"
              })
            }
          }

          var statNames = (data && data.statistics && Array.isArray(data.statistics.names)) ? data.statistics.names : []
          var nameIdx = {}
          for (var ni = 0; ni < statNames.length; ni++) {
            nameIdx[statNames[ni]] = ni
          }

          var splits = data && data.statistics && Array.isArray(data.statistics.splits) ? data.statistics.splits : []
          var natCaps = 0
          var natGoals = 0
          var yCardsSum = 0, rCardsSum = 0, fcSum = 0, fsSum = 0, startsSum = 0
          var goalsSum = 0, assistsSum = 0, shotsSum = 0, sogSum = 0
          var hasClubStats = false

          for (var spi = 0; spi < splits.length; spi++) {
            var sp = splits[spi]
            var spLg = String(sp.leagueSlug || "").toLowerCase()
            var spName = String(sp.displayName || "").toLowerCase()
            var isNatSplit = spLg.indexOf("fifa") !== -1 || spLg.indexOf("euro") !== -1 || spLg.indexOf("nations") !== -1 || spLg.indexOf("friendly") !== -1 || spName.indexOf("world cup") !== -1 || spName.indexOf("friendly") !== -1
            var spVals = sp.stats || []

            var getVal = function(name) {
              var idx = nameIdx[name]
              if (idx !== undefined && idx < spVals.length) return parseFloat(spVals[idx]) || 0
              return 0
            }

            if (isNatSplit) {
              var starts = parseInt(spVals[0] || "0")
              var goals = parseInt(spVals[5] || "0")
              natCaps += starts
              natGoals += goals
            } else {
              hasClubStats = true
              startsSum += getVal("starts")
              fcSum += getVal("foulsCommitted")
              fsSum += getVal("foulsSuffered")
              yCardsSum += getVal("yellowCards")
              rCardsSum += getVal("redCards")
              goalsSum += getVal("totalGoals")
              assistsSum += getVal("goalAssists")
              shotsSum += getVal("totalShots")
              sogSum += getVal("shotsOnTarget")
            }
          }

          var prof = Object.assign({}, root.selectedPlayerProfile)
          prof.recentMatches = matches
          if (natCaps > 0) {
            prof.overviewNatCaps = natCaps
            prof.overviewNatGoals = natGoals
          }

          if (hasClubStats) {
            prof.seasonYellowCards = String(yCardsSum)
            prof.seasonRedCards = String(rCardsSum)
            prof.seasonFouls = fcSum + " / " + fsSum
            prof.seasonFoulsCommitted = String(fcSum)
            prof.seasonFoulsSuffered = String(fsSum)
            if (startsSum > 0 && (!prof.seasonAppearances || prof.seasonAppearances === "")) {
              prof.seasonAppearances = String(startsSum)
            }
            if (goalsSum > 0 && (!prof.seasonGoals || prof.seasonGoals === "")) {
              prof.seasonGoals = String(goalsSum)
            }
            if (assistsSum > 0 && (!prof.seasonAssists || prof.seasonAssists === "")) {
              prof.seasonAssists = String(assistsSum)
            }
            if (shotsSum > 0) {
              prof.goalConversionRate = ((goalsSum / shotsSum) * 100).toFixed(1) + "%"
              prof.shotAccuracy = Math.round((sogSum / shotsSum) * 100) + "%"
            }
            if (startsSum > 0 && (!prof.seasonMinutes || prof.seasonMinutes === "" || prof.seasonMinutes === "0" || prof.seasonMinutes === "—")) {
              prof.seasonMinutes = String(startsSum * 90)
              prof.seasonMinPerApp = "90'"
            }
          }

          root.selectedPlayerProfile = prof
        } catch (e) {}
      }
    }
  }

  function triggerSearch(q) {
    root.searchQuery = q
    root.clubProfileHistory = null
    root.selectedPlayerProfile = null
    root.selectedClubProfile = null
    root.searchClubLoading = false
    root._pendingClubProfile = null
    root._clubFetchPending = 0
    clubFetchTimeoutTimer.stop()
    searchDebounceTimer.restart()
  }
  function performSearch() {
    var q = root.searchQuery.trim()
    if (q.length < 2) {
      root.searchResults = []
      root.searchError = ""
      root.searchLoading = false
      return
    }
    root.searchLoading = true
    root.searchError = ""
    searchRequest.running = false
    searchRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152",
      "https://site.web.api.espn.com/apis/search/v2?query=" + encodeURIComponent(q) + "&limit=12"]
    searchRequest.running = true
  }

  function navigateBackFromProfile() {
    if (root.clubProfileHistory) {
      root.selectedClubProfile = root.clubProfileHistory
      root.clubProfileHistory = null
      root.selectedPlayerProfile = null
      root.searchClubCardTab = "overview"
      root.resetPanelScroll()
      return
    }
    if (root.selectedPlayerProfile) {
      if (root.searchTab !== "search") {
        root.selectedPlayerProfile = null
        root.resetPanelScroll()
        return
      }
      root.selectedPlayerProfile = null
      root.resetPanelScroll()
      return
    }
    if (root.selectedClubProfile) {
      root.selectedClubProfile = null
      root.searchClubLoading = false
      root._pendingClubProfile = null
      root.resetPanelScroll()
      return
    }
  }

  function isPreseasonLeague(lg) {
    if (!lg || typeof lg !== "string") return false
    var l = lg.toLowerCase()
    if (l.indexOf("fifa.friendly") === 0) return false
    return l.indexOf("gamper") !== -1 ||
           l.indexOf("joan") !== -1 ||
           l.indexOf("preseason") !== -1 ||
           l.indexOf("pre_season") !== -1 ||
           l.indexOf("pre-season") !== -1 ||
           l.indexOf("friendly") !== -1 ||
           l.indexOf("emirates") !== -1 ||
           l.indexOf("audi_cup") !== -1 ||
           l.indexOf("audi.cup") !== -1 ||
           l.indexOf("icc") !== -1 ||
           l.indexOf("trofeo") !== -1 ||
           l.indexOf("trofeu") !== -1 ||
           l.indexOf("exhibition") !== -1 ||
           l.indexOf("world_football_challenge") !== -1 ||
           l.indexOf("summer_series") !== -1 ||
           l.indexOf("florida_cup") !== -1
  }

  function isIntlLeague(lg) {
    if (!lg || typeof lg !== "string") return false
    var l = lg.toLowerCase()
    if (l.indexOf("fifa.cwc") === 0 || l.indexOf("fifa.club") === 0) return false
    return l.indexOf("fifa.") === 0 ||
           l.indexOf("uefa.euro") === 0 ||
           l.indexOf("uefa.nations") === 0 ||
           l.indexOf("conmebol.america") === 0 ||
           l.indexOf("conmebol.copa_america") === 0 ||
           l.indexOf("concacaf.gold") === 0 ||
           l.indexOf("concacaf.nations") === 0 ||
           l.indexOf("caf.nations") === 0 ||
           l.indexOf("afc.asian") === 0 ||
           l.indexOf("international") !== -1
  }

  function formatCompetitionName(lg) {
    if (!lg || typeof lg !== "string") return { full: "Competition", short: "Comp" }
    var l = lg.toLowerCase()
    if (l === "esp.1") return { full: "LaLiga", short: "LaLiga" }
    if (l === "esp.2") return { full: "LaLiga 2", short: "Segunda" }
    if (l === "esp.copa_del_rey") return { full: "Copa del Rey", short: "Copa" }
    if (l === "esp.super_cup") return { full: "Supercopa", short: "Supercopa" }
    if (l === "esp.joan_gamper") return { full: "Joan Gamper", short: "Gamper" }

    if (l === "eng.1") return { full: "Premier League", short: "PL" }
    if (l === "eng.2") return { full: "Championship", short: "Championship" }
    if (l === "eng.fa") return { full: "FA Cup", short: "FA Cup" }
    if (l === "eng.league_cup") return { full: "Carabao Cup", short: "EFL Cup" }
    if (l === "eng.charity") return { full: "Community Shield", short: "Shield" }

    if (l === "ger.1") return { full: "Bundesliga", short: "Bundesliga" }
    if (l === "ger.dfb_pokal") return { full: "DFB-Pokal", short: "DFB-Pokal" }
    if (l === "ger.super_cup") return { full: "DFL-Supercup", short: "Supercup" }

    if (l === "ita.1") return { full: "Serie A", short: "Serie A" }
    if (l === "ita.coppa_italia") return { full: "Coppa Italia", short: "Coppa" }
    if (l === "ita.super_cup") return { full: "Supercoppa", short: "Supercoppa" }

    if (l === "fra.1") return { full: "Ligue 1", short: "Ligue 1" }
    if (l === "fra.coupe_de_france") return { full: "Coupe de France", short: "Coupe" }
    if (l === "fra.trophee_champions") return { full: "Trophée des Champions", short: "Trophée" }

    if (l === "uefa.champions") return { full: "Champions League", short: "UCL" }
    if (l === "uefa.europa") return { full: "Europa League", short: "UEL" }
    if (l === "uefa.europa.conf") return { full: "Conference League", short: "UECL" }
    if (l === "uefa.super_cup") return { full: "UEFA Super Cup", short: "Super Cup" }

    if (l === "usa.1") return { full: "MLS", short: "MLS" }
    if (l === "usa.us_open") return { full: "US Open Cup", short: "US Open" }
    if (l === "por.1") return { full: "Liga Portugal", short: "Liga PT" }
    if (l === "ned.1") return { full: "Eredivisie", short: "Eredivisie" }
    if (l === "sau.1") return { full: "Saudi Pro League", short: "SPL" }
    if (l === "bra.1") return { full: "Brasileirão", short: "Brasileirão" }

    if (l === "uefa.euro") return { full: "Euro", short: "Euro" }
    if (l === "uefa.euroq") return { full: "Euro Qualifiers", short: "Euro Q" }
    if (l === "fifa.world") return { full: "World Cup", short: "World Cup" }
    if (l === "fifa.worldq.uefa" || l.indexOf("fifa.worldq") === 0) return { full: "World Cup Qualifiers", short: "WC Q" }
    if (l === "uefa.nations") return { full: "Nations League", short: "Nations" }
    if (l === "fifa.friendly") return { full: "Friendly", short: "Friendly" }
    if (l === "conmebol.copa_america") return { full: "Copa América", short: "Copa América" }
    if (l === "fifa.cwc") return { full: "Club World Cup", short: "CWC" }

    var pretty = l.replace(/^[a-z0-9_]+\./, "").replace(/_/g, " ")
    pretty = pretty.charAt(0).toUpperCase() + pretty.slice(1)
    return { full: pretty, short: pretty.slice(0, 10) }
  }

  function currentSeasonComps() {
    var prof = root.selectedPlayerProfile
    if (!prof || !prof.availableSeasons || prof.availableSeasons.length === 0) return []
    var sIdx = prof.selectedSeasonIndex || 0
    if (sIdx < 0 || sIdx >= prof.availableSeasons.length) sIdx = 0
    var season = prof.availableSeasons[sIdx]
    return season && season.competitions ? season.competitions : []
  }

  function selectPlayerCompetition(compIdx) {
    var prof = root.selectedPlayerProfile
    if (!prof) return
    prof.selectedCompIndex = compIdx
    root.selectedPlayerProfile = Object.assign({}, prof)
    root.applyPlayerStatsView()
  }

  function selectPlayerTournament(tIdx) {
    var prof = root.selectedPlayerProfile
    if (!prof) return
    prof.selectedCompIndex = tIdx
    root.selectedPlayerProfile = Object.assign({}, prof)
    root.applyPlayerStatsView()
  }

  function setPlayerStatsTab(tab) {
    root.searchPlayerStatsTab = tab
    var prof = root.selectedPlayerProfile
    if (prof && tab === "tournament") {
      var comps = root.currentSeasonComps()
      if (prof.selectedCompIndex === undefined || prof.selectedCompIndex < 0 || prof.selectedCompIndex >= comps.length) {
        prof.selectedCompIndex = 0
        root.selectedPlayerProfile = Object.assign({}, prof)
      }
    }
    root.applyPlayerStatsView()
  }

  function changePlayerSeason(delta) {
    if (!root.selectedPlayerProfile || !root.selectedPlayerProfile.availableSeasons || root.selectedPlayerProfile.availableSeasons.length === 0) return
    var prof = Object.assign({}, root.selectedPlayerProfile)
    var seasons = prof.availableSeasons
    var curIdx = prof.selectedSeasonIndex || 0
    var nextIdx = curIdx + delta
    if (nextIdx < 0 || nextIdx >= seasons.length) return

    prof.selectedSeasonIndex = nextIdx
    prof.selectedCompIndex = 0
    root.selectedPlayerProfile = Object.assign({}, prof)
    root.applyPlayerStatsView()
  }

  function fetchPendingCompStats(urls) {
    if (!urls || urls.length === 0) return
    var toQueue = []
    for (var i = 0; i < urls.length; i++) {
      var u = urls[i]
      if (!u) continue
      if (root.playerCompStatCache && root.playerCompStatCache[u]) continue
      if (root.playerCompStatQueue.indexOf(u) === -1) {
        toQueue.push(u)
      }
    }
    if (toQueue.length === 0) return
    root.playerCompStatQueue = root.playerCompStatQueue.concat(toQueue)
    if (!searchCompQueueRequest.running) {
      root._fetchNextCompQueue()
    }
  }

  function _fetchNextCompQueue() {
    if (!root.playerCompStatQueue || root.playerCompStatQueue.length === 0) {
      root.playerStatsLoading = false
      return
    }
    var nextUrl = root.playerCompStatQueue[0]
    searchCompQueueRequest.running = false
    searchCompQueueRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152", nextUrl]
    searchCompQueueRequest.running = true
  }

  function applySingleStatMap(statMap, label) {
    var prof = root.selectedPlayerProfile
    if (!prof) return

    if (statMap["appearances"] || statMap["starts"]) prof.seasonAppearances = statMap["appearances"] || statMap["starts"]
    else prof.seasonAppearances = "0"

    if (statMap["totalGoals"] !== undefined) prof.seasonGoals = statMap["totalGoals"]
    else prof.seasonGoals = "0"

    if (statMap["goalAssists"] !== undefined) prof.seasonAssists = statMap["goalAssists"]
    else prof.seasonAssists = "0"

    if (statMap["shotAssists"] !== undefined) prof.seasonKeyPasses = statMap["shotAssists"]
    else prof.seasonKeyPasses = "0"

    if (statMap["passPct"]) prof.seasonPassPct = Math.round(parseFloat(statMap["passPct"]) * 100) + "%"
    if (statMap["effectiveTackles"] || statMap["totalTackles"]) prof.seasonTackles = statMap["effectiveTackles"] || statMap["totalTackles"]
    if (statMap["interceptions"]) prof.seasonInterceptions = statMap["interceptions"]
    if (statMap["totalShots"] !== undefined) prof.seasonShots = statMap["totalShots"]
    if (statMap["shotsOnTarget"] !== undefined) prof.seasonShotsOnTarget = statMap["shotsOnTarget"]
    if (statMap["saves"]) prof.seasonSaves = statMap["saves"]
    if (statMap["cleanSheet"]) prof.seasonCleanSheets = statMap["cleanSheet"]
    if (statMap["bigChanceCreated"]) prof.seasonChances = statMap["bigChanceCreated"]

    // Discipline & Workload
    if (statMap["yellowCards"] !== undefined) prof.seasonYellowCards = statMap["yellowCards"]
    else prof.seasonYellowCards = "0"
    if (statMap["redCards"] !== undefined) prof.seasonRedCards = statMap["redCards"]
    else prof.seasonRedCards = "0"

    var fc = statMap["foulsCommitted"] !== undefined ? statMap["foulsCommitted"] : "0"
    var fs = statMap["foulsSuffered"] !== undefined ? statMap["foulsSuffered"] : "0"
    prof.seasonFouls = fc + " / " + fs
    prof.seasonFoulsCommitted = fc
    prof.seasonFoulsSuffered = fs

    if (statMap["minutes"] !== undefined && parseInt(statMap["minutes"]) > 0) {
      prof.seasonMinutes = statMap["minutes"]
      var aInt = parseInt(statMap["appearances"] || statMap["starts"] || prof.seasonAppearances || "0")
      var mInt = parseInt(statMap["minutes"])
      if (mInt > 0 && aInt > 0) {
        prof.seasonMinPerApp = Math.round(mInt / aInt) + "'"
      } else {
        prof.seasonMinPerApp = "—"
      }
    } else {
      prof.seasonMinutes = "0"
      prof.seasonMinPerApp = "—"
    }

    var subIn = statMap["subIns"] || "0"
    var subOut = statMap["subOuts"] || "0"
    prof.seasonSubIns = subIn
    prof.seasonSubOuts = subOut
    prof.seasonSubs = String((parseInt(subIn) || 0) + (parseInt(subOut) || 0))

    // Shot & Passing Efficiency
    var curGoals = parseFloat(statMap["totalGoals"] !== undefined ? statMap["totalGoals"] : (prof.seasonGoals || "0"))
    var curShots = parseFloat(statMap["totalShots"] !== undefined ? statMap["totalShots"] : (prof.seasonShots || "0"))
    var curSog = parseFloat(statMap["shotsOnTarget"] !== undefined ? statMap["shotsOnTarget"] : (prof.seasonShotsOnTarget || "0"))
    if (curShots > 0 && curGoals >= 0) {
      prof.goalConversionRate = ((curGoals / curShots) * 100).toFixed(1) + "%"
    } else {
      prof.goalConversionRate = "—"
    }
    if (curShots > 0 && curSog >= 0) {
      prof.shotAccuracy = Math.round((curSog / curShots) * 100) + "%"
    } else if (statMap["shotPct"]) {
      prof.shotAccuracy = Math.round(parseFloat(statMap["shotPct"])) + "%"
    } else {
      prof.shotAccuracy = "—"
    }

    var lb = statMap["accurateLongBalls"] || statMap["totalLongBalls"]
    var kp = statMap["shotAssists"]
    if (lb !== undefined && lb !== "") prof.longBalls = lb
    else prof.longBalls = "0"
    if (kp !== undefined && kp !== "") prof.keyPasses = kp
    else prof.keyPasses = "0"
    if (prof.longBalls && prof.keyPasses && (prof.longBalls !== "0" || prof.keyPasses !== "0")) {
      prof.passDistribution = prof.longBalls + " LB · " + prof.keyPasses + " KP"
    } else {
      prof.passDistribution = "—"
    }

    if (statMap["passPct"]) statMap["passPct"] = prof.seasonPassPct
    prof.seasonStatMap = statMap
    if (label) prof.selectedSeasonYear = label

    root.selectedPlayerProfile = Object.assign({}, prof)
    root.playerStatsLoading = false
  }

  function applyPlayerStatsView() {
    var prof = root.selectedPlayerProfile
    if (!prof || !prof.availableSeasons || prof.availableSeasons.length === 0) return

    var sIdx = prof.selectedSeasonIndex || 0
    if (sIdx < 0 || sIdx >= prof.availableSeasons.length) sIdx = 0
    var season = prof.availableSeasons[sIdx]
    if (!season) return

    if (root.searchPlayerStatsTab === "career") {
      if (prof.careerStatMap) {
        root.applySingleStatMap(prof.careerStatMap, "Career")
      }
      return
    }

    var allComps = season.competitions || []
    var comps = []
    if (root.searchPlayerStatsTab === "club") {
      comps = allComps.filter(function(c) { return !c.isCountry })
    } else if (root.searchPlayerStatsTab === "country") {
      comps = allComps.filter(function(c) { return !!c.isCountry })
    } else if (root.searchPlayerStatsTab === "tournament") {
      var cIdx = prof.selectedCompIndex || 0
      if (cIdx < 0 || cIdx >= allComps.length) cIdx = 0
      if (allComps.length > 0) {
        comps = [allComps[cIdx]]
      } else {
        comps = []
      }
    } else {
      comps = allComps
    }

    var sLabel = season.seasonYear || String(season.year)
    prof.selectedSeasonYear = sLabel

    if (comps.length === 0) {
      var emptyMap = {
        appearances: "0",
        totalGoals: "0",
        goalAssists: "0",
        shotAssists: "0",
        minutes: "0",
        yellowCards: "0",
        redCards: "0",
        foulsCommitted: "0",
        foulsSuffered: "0",
        subIns: "0",
        subOuts: "0",
        totalShots: "0",
        shotsOnTarget: "0",
        accurateLongBalls: "0",
        effectiveTackles: "0",
        interceptions: "0",
        saves: "0",
        cleanSheet: "0",
        bigChanceCreated: "0",
        passPct: ""
      }
      root.applySingleStatMap(emptyMap, sLabel)
      root.playerStatsLoading = false
      return
    }

    var sumMap = {
      appearances: 0,
      totalGoals: 0,
      goalAssists: 0,
      shotAssists: 0,
      minutes: 0,
      yellowCards: 0,
      redCards: 0,
      foulsCommitted: 0,
      foulsSuffered: 0,
      subIns: 0,
      subOuts: 0,
      totalShots: 0,
      shotsOnTarget: 0,
      accurateLongBalls: 0,
      effectiveTackles: 0,
      interceptions: 0,
      saves: 0,
      cleanSheet: 0,
      bigChanceCreated: 0,
      accuratePasses: 0,
      totalPasses: 0
    }

    var pendingUrls = []
    var anyCached = false
    for (var ci = 0; ci < comps.length; ci++) {
      var curl = comps[ci].url
      if (!curl) continue
      var cached = root.playerCompStatCache ? root.playerCompStatCache[curl] : null
      if (cached) {
        anyCached = true
        var num = function(v) { var n = parseFloat(v); return isNaN(n) ? 0 : n }
        sumMap.appearances += num(cached["appearances"] || cached["starts"])
        sumMap.totalGoals += num(cached["totalGoals"])
        sumMap.goalAssists += num(cached["goalAssists"])
        sumMap.shotAssists += num(cached["shotAssists"])
        sumMap.minutes += num(cached["minutes"])
        sumMap.yellowCards += num(cached["yellowCards"])
        sumMap.redCards += num(cached["redCards"])
        sumMap.foulsCommitted += num(cached["foulsCommitted"])
        sumMap.foulsSuffered += num(cached["foulsSuffered"])
        sumMap.subIns += num(cached["subIns"])
        sumMap.subOuts += num(cached["subOuts"])
        sumMap.totalShots += num(cached["totalShots"])
        sumMap.shotsOnTarget += num(cached["shotsOnTarget"])
        sumMap.accurateLongBalls += num(cached["accurateLongBalls"] || cached["totalLongBalls"])
        sumMap.effectiveTackles += num(cached["effectiveTackles"] || cached["totalTackles"])
        sumMap.interceptions += num(cached["interceptions"])
        sumMap.saves += num(cached["saves"])
        sumMap.cleanSheet += num(cached["cleanSheet"])
        sumMap.bigChanceCreated += num(cached["bigChanceCreated"])
        sumMap.accuratePasses += num(cached["accuratePasses"])
        sumMap.totalPasses += num(cached["totalPasses"])
      } else {
        pendingUrls.push(curl)
      }
    }

    if (anyCached) {
      var statMapCombined = {
        appearances: String(sumMap.appearances),
        totalGoals: String(sumMap.totalGoals),
        goalAssists: String(sumMap.goalAssists),
        shotAssists: String(sumMap.shotAssists),
        minutes: String(sumMap.minutes),
        yellowCards: String(sumMap.yellowCards),
        redCards: String(sumMap.redCards),
        foulsCommitted: String(sumMap.foulsCommitted),
        foulsSuffered: String(sumMap.foulsSuffered),
        subIns: String(sumMap.subIns),
        subOuts: String(sumMap.subOuts),
        totalShots: String(sumMap.totalShots),
        shotsOnTarget: String(sumMap.shotsOnTarget),
        accurateLongBalls: String(sumMap.accurateLongBalls),
        effectiveTackles: String(sumMap.effectiveTackles),
        interceptions: String(sumMap.interceptions),
        saves: String(sumMap.saves),
        cleanSheet: String(sumMap.cleanSheet),
        bigChanceCreated: String(sumMap.bigChanceCreated),
        passPct: (sumMap.totalPasses > 0) ? String(sumMap.accuratePasses / sumMap.totalPasses) : ""
      }
      root.applySingleStatMap(statMapCombined, sLabel)
    }

    if (pendingUrls.length > 0) {
      root.fetchPendingCompStats(pendingUrls)
    } else {
      root.playerStatsLoading = false
    }
  }

  function openPlayerSearchDetail(item) {
    if (root.selectedClubProfile) {
      root.clubProfileHistory = root.selectedClubProfile
    }
    root.selectedClubProfile = null
    root.searchClubLoading = false
    root._pendingClubProfile = null
    clubFetchTimeoutTimer.stop()
    root.searchPlayerCardTab = "info"
    root.searchPlayerStatsTab = "all"
    root.playerCompStatQueue = []
    root.playerCompStatCache = ({})
    searchCompQueueRequest.running = false
    root.clubNameQueue = []
    root.transferTeamQueue = []
    root._transferTeamInFlight = ""
    root.clubAggQueue = []
    root.clubAggSums = ({})
    root.clubAggTarget = ""
    root.careerAggQueue = []
    root.careerAggSums = ({})
    root.careerAggTarget = ""
    searchTeamNameRequest.running = false
    searchTransferTeamRequest.running = false
    searchPlayerBioRequest.running = false
    searchPlayerTransactionsRequest.running = false
    searchClubStatRequest.running = false
    searchCareerAggRequest.running = false
    root.resetPanelScroll()
    root.selectedPlayerProfile = {
      fullName: item.displayName,
      jersey: "",
      age: "",
      position: "",
      displayHeight: "",
      displayWeight: "",
      citizenship: "",
      birthplace: "",
      dateOfBirth: "",
      status: "Active",
      headshot: item.image,
      flag: "",
      teamName: item.subtitle,
      teamCrest: "",
      leagueName: item.description,
      careerAppearances: "",
      careerGoals: "",
      careerAssists: "",
      careerKeyPasses: "",
      careerPasses: "",
      careerPassPct: "",
      careerFreeKicks: "",
      careerTackles: "",
      careerInterceptions: "",
      careerShots: "",
      careerShotsOnTarget: "",
      careerSaves: "",
      careerCleanSheets: "",
      careerHistory: [],
      seasonAppearances: "",
      seasonGoals: "",
      seasonAssists: "",
      seasonMinutes: "",
      seasonSubIns: "",
      seasonSubOuts: "",
      careerStatMap: null,
      seasonStatMap: null,
      teamSeasonMap: null,
      careerAggDone: false,
      clubOptions: [],
      clubStatMap: null,
      clubAggCache: ({}),
      clubFilterId: "all",
      clubFilterLoading: false,
      transferInfo: "",
      transferFetched: false,
      transferHistory: [],
      recentMatches: [],
      nationalTeams: [],
      overviewNatCaps: 0,
      overviewNatGoals: 0,
      seasonYellowCards: "",
      seasonRedCards: "",
      seasonFouls: "",
      seasonMinPerApp: "",
      seasonSubs: "",
      goalConversionRate: "",
      shotAccuracy: "",
      longBalls: "",
      keyPasses: "",
      passDistribution: "",
      availableSeasons: [],
      selectedSeasonIndex: 0,
      selectedCompIndex: 0,
      selectedSeasonYear: "",
      seasonStatCache: ({}),
      webUrl: item.webUrl
    }
    if (item.id !== "") {
      root.searchPlayerLoading = true
      root.statsPlayerKey = item.id
      root.statsPlayerLeague = item.leagueSlug || (root.league !== "all" ? root.league : "")
      searchPlayerDetailRequest.running = false
      searchPlayerDetailRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152",
        "https://sports.core.api.espn.com/v2/sports/soccer/athletes/" + encodeURIComponent(item.id)]
      searchPlayerDetailRequest.running = true

      searchPlayerBioRequest.running = false
      searchPlayerBioRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152",
        "https://site.web.api.espn.com/apis/common/v3/sports/soccer/athletes/" + encodeURIComponent(item.id) + "/bio"]
      searchPlayerBioRequest.running = true

      searchPlayerOverviewRequest.running = false
      searchPlayerOverviewRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152",
        "https://site.web.api.espn.com/apis/common/v3/sports/soccer/athletes/" + encodeURIComponent(item.id) + "/overview"]
      searchPlayerOverviewRequest.running = true

      searchPlayerTransactionsRequest.running = false
      searchPlayerTransactionsRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152",
        "https://sports.core.api.espn.com/v2/sports/soccer/athletes/" + encodeURIComponent(item.id) + "/transactions"]
      searchPlayerTransactionsRequest.running = true

      // Career clubs (Info tab) load eagerly; heavy stats stay lazy
      // until the Stats/More tab is first opened (see ensurePlayerStats).
      searchPlayerLogRequest.running = false
      searchPlayerLogRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152",
        "https://sports.core.api.espn.com/v2/sports/soccer/athletes/" + encodeURIComponent(item.id) + "/statisticslog?lang=en&region=us"]
      searchPlayerLogRequest.running = true

      root.ensurePlayerStats()
    }
  }

  // Lazy-load heavy player stats on first Stats visit.
  function ensurePlayerStats() {
    if (root.statsPlayerKey === "" || !root.selectedPlayerProfile) return
    var p = root.selectedPlayerProfile
    var haveCareer = p.careerStatMap !== null && p.careerStatMap !== undefined
    var haveSeason = p.seasonStatMap !== null && p.seasonStatMap !== undefined
    if (haveCareer && haveSeason && p.transferFetched) return
    if (root.playerStatsLoading) return
    var pid = root.statsPlayerKey
    var defLg = root.statsPlayerLeague !== "" ? root.statsPlayerLeague : ""
    var curYear = new Date().getFullYear()
    root.playerStatsLoading = true
    if (!haveCareer) {
      searchPlayerStatsRequest.running = false
      searchPlayerStatsRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152",
        "https://sports.core.api.espn.com/v2/sports/soccer/athletes/" + encodeURIComponent(pid) + "/statistics"]
      searchPlayerStatsRequest.running = true
    }
    if (!haveSeason && defLg !== "") {
      searchPlayerSeasonStatsRequest.running = false
      searchPlayerSeasonStatsRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152",
        "https://sports.core.api.espn.com/v2/sports/soccer/leagues/" + encodeURIComponent(defLg) + "/seasons/" + encodeURIComponent(String(curYear)) + "/types/1/athletes/" + encodeURIComponent(pid) + "/statistics/1?lang=en&region=us"]
      searchPlayerSeasonStatsRequest.running = true
    }
    if (!p.transferFetched && !searchPlayerTransactionsRequest.running) {
      searchPlayerTransactionsRequest.running = false
      searchPlayerTransactionsRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152",
        "https://sports.core.api.espn.com/v2/sports/soccer/athletes/" + encodeURIComponent(pid) + "/transactions"]
      searchPlayerTransactionsRequest.running = true
    }
    root.maybeStartCareerAgg()
  }

  // Lazy-load club display names on first More visit.
  function ensureClubNames() {
    if (root.statsPlayerKey === "" || root.clubNamesResolvedFor === root.statsPlayerKey) return
    root.clubNamesResolvedFor = root.statsPlayerKey
    root.resolveClubNames()
  }

  // Dynamic 4th stat cell: first available metric for the active tab.
  function isPlayerGoalkeeper() {
    var p = root.selectedPlayerProfile
    if (!p) return false
    var pos = String(p.position || "").toLowerCase()
    return pos.indexOf("goalkeeper") !== -1 || pos.indexOf("keeper") !== -1 || pos === "gk" || pos === "g"
  }

  // Dynamic 4th stat cell: contextual to position.
  // Goalkeepers show SAVES; outfield players show PASS % -> TACKLES -> SHOTS -> KEY PASSES -> CHANCES -> INTERCEPTIONS.
  function stat4Active() {
    var p = root.selectedPlayerProfile
    var season = root.searchPlayerStatsTab !== "career"
    if (!p) return { label: "PASS %", value: "" }
    var get = function(c, s) { var v = season ? p[s] : p[c]; return v ? String(v) : "" }
    if (root.isPlayerGoalkeeper()) {
      var sv = get("careerSaves", "seasonSaves")
      if (sv !== "") return { label: "SAVES", value: sv }
      var cs = get("careerCleanSheets", "seasonCleanSheets")
      if (cs !== "") return { label: "CLEAN SHEETS", value: cs }
      return { label: "SAVES", value: "—" }
    }
    var v = get("careerPassPct", "seasonPassPct")
    if (v !== "") return { label: "PASS %", value: v }
    v = get("careerTackles", "seasonTackles")
    if (v !== "") return { label: "TACKLES", value: v }
    v = get("careerShots", "seasonShots")
    if (v !== "") return { label: "SHOTS", value: v }
    v = get("careerKeyPasses", "seasonKeyPasses")
    if (v !== "") return { label: "KEY PASSES", value: v }
    if (season && p.seasonChances) return { label: "CHANCES", value: String(p.seasonChances) }
    v = get("careerInterceptions", "seasonInterceptions")
    if (v !== "") return { label: "INTERCEPTIONS", value: v }
    return { label: "PASS %", value: "" }
  }

  // Dynamic stat group categories: outfield players NEVER show goalkeeper stats.
  function playerStatGroups() {
    if (root.isPlayerGoalkeeper()) {
      return ["keeper", "passing", "general"]
    }
    return ["scoring", "passing", "defending", "general"]
  }
  function isIntlLeagueSlug(lg) {
    return lg.indexOf("fifa.world") === 0 || lg.indexOf("fifa.friendly") === 0 || lg.indexOf("fifa.olympics") === 0
      || lg.indexOf("uefa.euro") === 0 || lg.indexOf("uefa.nations") === 0 || lg.indexOf("conmebol.america") === 0
      || lg.indexOf("concacaf.gold") === 0 || lg.indexOf("concacaf.nations") === 0 || lg.indexOf("caf.nations") === 0
      || lg.indexOf("afc.asian") === 0
  }

  function nationalStatUrls() {
    var p = root.selectedPlayerProfile
    var urls = []
    if (!p || !p.teamSeasonMap) return urls
    var keys = Object.keys(p.teamSeasonMap)
    for (var i = 0; i < keys.length; i++) {
      var t = p.teamSeasonMap[keys[i]]
      var leagues = t.leagues || []
      var allIntl = leagues.length > 0 && leagues.every(function(lg) { return root.isIntlLeagueSlug(lg) })
      if (!allIntl) continue
      var ul = t.urls || []
      for (var u = 0; u < ul.length; u++) {
        if (urls.indexOf(ul[u]) === -1) urls.push(ul[u])
      }
    }
    return urls
  }

  function hasNationalStats() {
    return root.nationalStatUrls().length > 0
  }

  function resolveClubNames() {
    var p = root.selectedPlayerProfile
    if (!p || !p.teamSeasonMap) return
    root.clubNameQueue = []
    var keys = Object.keys(p.teamSeasonMap)
    for (var i = 0; i < keys.length; i++) {
      var t = p.teamSeasonMap[keys[i]]
      var leagues = t.leagues || []
      var allIntl = leagues.length > 0 && leagues.every(function(lg) { return root.isIntlLeagueSlug(lg) })
      if (allIntl) continue
      root.clubNameQueue.push(keys[i])
    }
    root._resolveNextClubName()
  }

  function _resolveNextClubName() {
    var p = root.selectedPlayerProfile
    if (!p || !p.teamSeasonMap || root.clubNameQueue.length === 0) return
    var teamId = root.clubNameQueue[0]
    var t = p.teamSeasonMap[teamId]
    if (!t || !(t.leagues || []).length) {
      root.clubNameQueue.shift()
      root._resolveNextClubName()
      return
    }
    searchTeamNameRequest.running = false
    searchTeamNameRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(t.leagues[0]) + "/teams/" + encodeURIComponent(teamId)]
    searchTeamNameRequest.running = true
  }

  function selectClubFilter(teamId) {
    var p = root.selectedPlayerProfile
    if (!p) return
    if (!p.clubAggCache) p.clubAggCache = ({})
    if (teamId !== "all" && p.clubAggCache[teamId]) {
      p.clubFilterId = teamId
      p.clubStatMap = p.clubAggCache[teamId]
      p.clubFilterLoading = false
      root.selectedPlayerProfile = Object.assign({}, p)
      return
    }
    p.clubFilterId = teamId
    p.clubStatMap = null
    p.clubFilterLoading = teamId !== "all"
    root.selectedPlayerProfile = Object.assign({}, p)
    if (teamId === "all") return
    var urls = []
    if (teamId === "national") {
      urls = root.nationalStatUrls()
    } else if (p.teamSeasonMap && p.teamSeasonMap[teamId]) {
      urls = (p.teamSeasonMap[teamId].urls || []).slice()
    }
    root.clubAggQueue = urls
    root.clubAggSums = ({})
    root.clubAggTarget = teamId
    if (urls.length === 0) {
      p.clubFilterLoading = false
      root.selectedPlayerProfile = Object.assign({}, p)
      return
    }
    root._fetchNextClubStat()
  }

  function _fetchNextClubStat() {
    if (root.clubAggQueue.length === 0) {
      root._finishClubAgg()
      return
    }
    searchClubStatRequest.running = false
    searchClubStatRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152",
      root.clubAggQueue[0]]
    searchClubStatRequest.running = true
  }

  function _writeClubAggMap(finished) {
    var p = root.selectedPlayerProfile
    if (!p || p.clubFilterId !== root.clubAggTarget) return
    var sums = root.clubAggSums
    var out = {}
    var keys = Object.keys(sums)
    for (var i = 0; i < keys.length; i++) {
      out[keys[i]] = String(Math.round(sums[keys[i]]))
    }
    if (sums["totalPasses"] > 0 && sums["accuratePasses"] !== undefined) {
      out["passPct"] = Math.round(sums["accuratePasses"] / sums["totalPasses"] * 100) + "%"
    }
    p.clubStatMap = out
    if (!p.clubAggCache) p.clubAggCache = ({})
    p.clubAggCache[root.clubAggTarget] = out
    if (finished) p.clubFilterLoading = false
    root.selectedPlayerProfile = Object.assign({}, p)
  }

  function _finishClubAgg() {
    root._writeClubAggMap(true)
  }

  function activeMoreMap() {
    var p = root.selectedPlayerProfile
    if (!p || !p.clubFilterId || p.clubFilterId === "all") return null
    return p.clubStatMap
  }

  function pickStat(names) {
    var m = root.activeMoreMap()
    if (!m) return ""
    for (var i = 0; i < names.length; i++) {
      var v = m[names[i]]
      if (v !== undefined && v !== null && String(v) !== "") return String(v)
    }
    return ""
  }

  function moreRows(group) {
    var defs = {
      scoring: [
        { label: "Free-kick goals", names: ["freeKickGoals"] },
        { label: "Penalty goals", names: ["penaltyKickGoals"] },
        { label: "Penalties missed", names: ["penaltyKicksMissed"] },
        { label: "Game-winning goals", names: ["gameWinningGoals"] },
        { label: "Headed goals", names: ["headedGoals"] },
        { label: "Left-foot shots", names: ["leftFootedShots"] },
        { label: "Right-foot shots", names: ["rightFootedShots"] },
        { label: "Shots", names: ["totalShots"] },
        { label: "Shots on target", names: ["shotsOnTarget"] },
        { label: "Shot %", names: ["shotPct"] },
        { label: "In-box attempts", names: ["attemptsInBox"] },
        { label: "Out-box attempts", names: ["attemptsOutBox"] },
        { label: "Offsides", names: ["offsides"] },
        { label: "Big chances missed", names: ["bigChanceMissed"] },
        { label: "Shootout goals", names: ["shootOutGoals"] },
        { label: "Shootout misses", names: ["shootOutMisses"] }
      ],
      passing: [
        { label: "Accurate passes", names: ["accuratePasses"] },
        { label: "Total passes", names: ["totalPasses"] },
        { label: "Accurate crosses", names: ["accurateCrosses"] },
        { label: "Accurate long balls", names: ["accurateLongBalls"] },
        { label: "Accurate through balls", names: ["accurateThroughBalls"] },
        { label: "Cross %", names: ["crossPct"] },
        { label: "Long-ball %", names: ["longballPct"] },
        { label: "Through-ball %", names: ["throughBallPct"] },
        { label: "Key passes", names: ["shotAssists"] },
        { label: "Big chances created", names: ["bigChanceCreated"] },
        { label: "Second assists", names: ["secondAssists"] },
        { label: "Game-winning assists", names: ["gameWinningAssists"] }
      ],
      defending: [
        { label: "Tackles", names: ["effectiveTackles", "totalTackles"] },
        { label: "Tackle %", names: ["tacklePct"] },
        { label: "Interceptions", names: ["interceptions"] },
        { label: "Clearances", names: ["totalClearance", "effectiveClearance"] },
        { label: "Blocked shots", names: ["blockedShots"] },
        { label: "Recoveries", names: ["recoveries"] },
        { label: "Duels won", names: ["duelsWon"] },
        { label: "Duels lost", names: ["duelsLost"] },
        { label: "Tackles lost", names: ["tacklesLost"] },
        { label: "Fouls committed", names: ["foulsCommitted"] },
        { label: "Fouls suffered", names: ["foulsSuffered"] }
      ],
      keeper: [
        { label: "Saves", names: ["saves"] },
        { label: "Shots faced", names: ["shotsFaced"] },
        { label: "Goals conceded", names: ["goalsConceded"] },
        { label: "Clean sheets", names: ["cleanSheet"] },
        { label: "Penalty saves", names: ["penaltyKicksSaved"] },
        { label: "Penalties faced", names: ["penaltyKicksFaced"] },
        { label: "Crosses caught", names: ["crossesCaught"] },
        { label: "Punches", names: ["punches"] },
        { label: "Big-chance saves", names: ["bigChanceSaves"] },
        { label: "Shootout saves", names: ["shootOutKicksSaved"] }
      ],
      general: [
        { label: "Minutes", names: ["minutes"] },
        { label: "Starts", names: ["starts"] },
        { label: "Sub ins", names: ["subIns"] },
        { label: "Sub outs", names: ["subOuts"] },
        { label: "Wins", names: ["wins"] },
        { label: "Draws", names: ["draws"] },
        { label: "Losses", names: ["losses"] },
        { label: "Yellow cards", names: ["yellowCards"] },
        { label: "Red cards", names: ["redCards"] },
        { label: "Touches", names: ["touches"] },
        { label: "Touches in opp box", names: ["touchesInOppBox"] },
        { label: "Progressive carries", names: ["progressiveCarries"] },
        { label: "Own goals", names: ["ownGoals"] }
      ]
    }
    var out = []
    var list = defs[group] || []
    for (var i = 0; i < list.length; i++) {
      var v = root.pickStat(list[i].names)
      if (v !== "") out.push({ label: list[i].label, value: v })
    }
    return out
  }

  function selectedClubOption() {
    var p = root.selectedPlayerProfile
    if (!p || !p.clubFilterId || p.clubFilterId === "all" || p.clubFilterId === "national") return null
    var opts = p.clubOptions || []
    for (var i = 0; i < opts.length; i++) {
      if (opts[i].teamId === p.clubFilterId) return opts[i]
    }
    return null
  }

  function moreGroupTitle(group) {
    if (group === "scoring") return "SCORING"
    if (group === "passing") return "PASSING & CREATION"
    if (group === "defending") return "DEFENDING"
    if (group === "keeper") return "GOALKEEPING"
    return "GENERAL"
  }

  // Background career-totals aggregation: sums apps/goals/assists over
  // every indexed season (all clubs + national) since the career
  // aggregate endpoint is stale and never publishes goalAssists.
  function maybeStartCareerAgg() {
    var p = root.selectedPlayerProfile
    if (root.statsPlayerKey === "" || !p || !p.teamSeasonMap) return
    if (p.careerAggDone) return
    if (root.careerAggTarget === root.statsPlayerKey && root.careerAggQueue.length > 0) return
    var urls = []
    var keys = Object.keys(p.teamSeasonMap)
    for (var i = 0; i < keys.length; i++) {
      var ul = p.teamSeasonMap[keys[i]].urls || []
      for (var u = 0; u < ul.length; u++) {
        if (urls.indexOf(ul[u]) === -1) urls.push(ul[u])
      }
    }
    if (urls.length === 0) return
    root.careerAggQueue = urls
    root.careerAggSums = ({ goalAssists: 0, appearances: 0, totalGoals: 0 })
    root.careerAggTarget = root.statsPlayerKey
    root._fetchNextCareerAgg()
  }

  function _fetchNextCareerAgg() {
    if (root.careerAggQueue.length === 0) {
      var p = root.selectedPlayerProfile
      if (p && root.statsPlayerKey === root.careerAggTarget) {
        if (root.careerAggSums["goalAssists"] > 0) {
          p.careerAssists = String(Math.round(root.careerAggSums["goalAssists"]))
        }
        if (root.careerAggSums["appearances"] > 0) {
          p.careerAppearances = String(Math.round(root.careerAggSums["appearances"]))
        }
        if (root.careerAggSums["totalGoals"] > 0) {
          p.careerGoals = String(Math.round(root.careerAggSums["totalGoals"]))
        }
        p.careerAggDone = true
        root.selectedPlayerProfile = Object.assign({}, p)
      }
      return
    }
    searchCareerAggRequest.running = false
    searchCareerAggRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "15", "--max-filesize", "2097152",
      root.careerAggQueue[0]]
    searchCareerAggRequest.running = true
  }

  function openClubSearchDetail(item) {
    root.clubProfileHistory = null
    root.selectedPlayerProfile = null
    root.searchClubCardTab = "overview"
    root.clubSquadPositionFilter = "all"
    root.clubFixtureCarouselIndex = 0
    root.resetPanelScroll()

    var lg = (item && item.leagueSlug) ? item.leagueSlug : (root.league !== "" ? root.league : "esp.1")
    root.selectedClubProfile = {
      id: item ? item.id : "",
      displayName: item ? item.displayName : "",
      leagueName: item ? (item.subtitle || "") : "",
      abbreviation: "",
      location: "",
      leagueSlug: lg,
      possession: "",
      shotsPerGame: "",
      shotsOnTarget: "",
      passPct: "",
      cleanSheets: "",
      tackles: "",
      interceptions: "",
      topScorer: "",
      topAssister: "",
      topCarder: "",
      recentMatches: [],
      upcomingFixtures: [],
      rosterGoalkeepers: [],
      rosterDefenders: [],
      rosterMidfielders: [],
      rosterForwards: [],
      rosterAll: [],
      manager: "",
      technicalStaff: [],
      yellowCards: "",
      redCards: "",
      secondYellow: "",
      disciplinaryPoints: "",
      foulsCommitted: "",
      webUrl: item ? (item.webUrl || "") : "",
      standingSummary: "",
      record: "",
      points: "",
      wins: "",
      ties: "",
      losses: "",
      diff: "",
      goalsFor: "",
      goalsAgainst: "",
      homeRecord: "",
      awayRecord: "",
      venue: "",
      nextEvent: "",
      nextEventDate: "",
      logo: item ? (item.image || "") : "",
      color: "",
      alternateColor: "",
      form: ""
    }

    if (!item || !item.id || item.id === "") {
      root.searchClubLoading = false
      return
    }

    root.searchClubLoading = true
    root._clubFetchPending = 6
    clubFetchTimeoutTimer.restart()

    searchClubDetailRequest.running = false
    searchClubDetailRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "12", "--max-filesize", "2097152",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(lg) + "/teams/" + encodeURIComponent(item.id)]
    searchClubDetailRequest.running = true

    searchClubScheduleRequest.running = false
    searchClubScheduleRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "12", "--max-filesize", "2097152",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(lg) + "/teams/" + encodeURIComponent(item.id) + "/schedule"]
    searchClubScheduleRequest.running = true

    searchClubFixturesRequest.running = false
    searchClubFixturesRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "12", "--max-filesize", "2097152",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(lg) + "/teams/" + encodeURIComponent(item.id) + "/schedule?fixture=true"]
    searchClubFixturesRequest.running = true

    searchClubRosterRequest.running = false
    searchClubRosterRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "12", "--max-filesize", "2097152",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(lg) + "/teams/" + encodeURIComponent(item.id) + "/roster"]
    searchClubRosterRequest.running = true

    var curYear = new Date().getFullYear()
    searchClubStatsRequest.running = false
    searchClubStatsRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "12", "--max-filesize", "2097152",
      "https://sports.core.api.espn.com/v2/sports/soccer/leagues/" + encodeURIComponent(lg) + "/seasons/" + encodeURIComponent(String(curYear)) + "/types/1/teams/" + encodeURIComponent(item.id) + "/statistics"]
    searchClubStatsRequest.running = true

    searchClubCoreRequest.running = false
    searchClubCoreRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "12", "--max-filesize", "2097152",
      "https://sports.core.api.espn.com/v2/sports/soccer/leagues/" + encodeURIComponent(lg) + "/teams/" + encodeURIComponent(item.id)]
    searchClubCoreRequest.running = true
  }

  function activeSquadList() {
    var p = root.selectedClubProfile
    if (!p) return []
    if (root.clubSquadPositionFilter === "gk") return p.rosterGoalkeepers || []
    if (root.clubSquadPositionFilter === "def") return p.rosterDefenders || []
    if (root.clubSquadPositionFilter === "mid") return p.rosterMidfielders || []
    if (root.clubSquadPositionFilter === "fwd") return p.rosterForwards || []
    return p.rosterAll || []
  }

  function activeClubFixture() {
    var p = root.selectedClubProfile
    if (!p || !p.upcomingFixtures || p.upcomingFixtures.length === 0) return null
    var idx = Math.max(0, Math.min(root.clubFixtureCarouselIndex, p.upcomingFixtures.length - 1))
    return p.upcomingFixtures[idx]
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
    contentHeight: popup.fittedContentHeight((pinnedHeader.visible ? pinnedHeader.implicitHeight + Style.space(14) : 0) + content.implicitHeight, (root.showMatchDetail || root.selectedPlayerProfile !== null || root.selectedClubProfile !== null) ? Style.space(720) : Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // While a club-picker dropdown is open or focused, let it handle the
      // While a club-picker dropdown or search field is open/focused, let it handle the
      // keys (Escape/arrows/Enter) instead of the panel's close/switch keys.
      blocked: (leagueDropdown && (leagueDropdown.popupOpen || leagueDropdown.activeFocus))
        || (teamDropdown && (teamDropdown.popupOpen || teamDropdown.activeFocus))
        || (searchBarInput && searchBarInput.activeFocus)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: pinnedHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root.needsTeam && !root.editingTeam
        spacing: Style.space(14)

        // Club tabs: only shown once a second club has been added, so a
        // single-team setup (everyone before this feature existed) looks
        // exactly as before. Click switches; right-click removes (the active
        // club has no remove -- it isn't stored in followedTeams to begin
        // with, so there's nothing to remove it from).
        // Follow tabs: lets you track multiple clubs and whole leagues.
        // Click switches; right-click removes (the active item cannot be removed).
        Flow {
          visible: !root.needsTeam && !root.editingTeam
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: [{
              teamName: root.leagueMode ? "" : root.teamName,
              league: root.league,
              teamId: root.leagueMode ? "" : root.teamId,
              followLeague: root.leagueMode,
              active: true
            }].concat(root.followedTeamsList().map(function(t) {
              return {
                teamName: t.followLeague ? "" : t.teamName,
                league: t.league,
                teamId: t.followLeague ? "" : t.teamId,
                followLeague: t.followLeague === true,
                active: false
              }
            }))
            delegate: Button {
              readonly property bool isLeagueTab: modelData.followLeague === true
              readonly property string displayName: isLeagueTab ? root.leagueShortLabel(modelData.league) : modelData.teamName
              readonly property string fullLabel: isLeagueTab ? root.leagueLabel(modelData.league) : (modelData.teamName + " (" + root.leagueLabel(modelData.league) + ")")
              iconText: isLeagueTab ? "󰴆" : ""
              iconSize: Style.font.caption
              text: displayName
              tooltipText: modelData.active ? fullLabel : ("Switch to " + fullLabel + " · right-click to remove")
              selected: modelData.active
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(10)
              verticalPadding: Style.space(4)
              onClicked: {
                if (!modelData.active) {
                  root.switchActiveItem(modelData.teamName, modelData.league, modelData.teamId, modelData.followLeague)
                }
              }
              onRightClicked: {
                if (!modelData.active) {
                  root.removeFollowedItem(modelData.teamName, modelData.league, modelData.followLeague)
                }
              }
            }
          }

          Button {
            iconText: "󰐕"
            tooltipText: "Add another club or league to follow"
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
            - (searchButton.visible ? searchButton.width + parent.spacing : 0)
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
          id: searchButton
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(32)
          height: Style.space(32)
          iconText: "󰍉"
          tooltipText: "Search Players & Clubs"
          fontFamily: root.contentFontFamily
          foreground: root.contentForeground
          accent: root.contentForeground
          iconSize: Style.font.body
          horizontalPadding: 0
          verticalPadding: 0
          selected: root.showSearch
          onClicked: {
            root.showMatchDetail = false
            root.showClubFixtures = false
            root.showSearch = !root.showSearch
            if (root.showSearch) {
              root.showMatches = false
              root.showStandings = false
              root.showStats = false
              Qt.callLater(function() {
                if (searchBarInput) searchBarInput.forceActiveFocus()
              })
            }
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
            root.showSearch = false
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
            root.showSearch = false
            if (root.showStandings) {
              root.showMatches = false
              root.showStats = false
              root.loadStandings(true)
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
            root.showSearch = false
            if (root.showStats) {
              root.showMatches = false
              root.showStandings = false
              root.loadStats(true)
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
          tooltipText: root.leagueMode ? "Change League" : "Change Team"
          fontFamily: root.contentFontFamily
          foreground: root.contentForeground
          accent: root.contentForeground
          iconSize: Style.font.body
          horizontalPadding: 0
          verticalPadding: 0
          onClicked: {
            root.showSearch = false
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
      }

      ScrollView {
        id: panelScrollArea
        anchors.top: pinnedHeader.visible ? pinnedHeader.bottom : parent.top
        anchors.topMargin: pinnedHeader.visible ? Style.space(14) : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: availableWidth
        contentHeight: content.implicitHeight
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

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
          text: root.addingTeam ? (root.pickerLeagueOnly ? "Add a league to follow" : "Add a club or league to follow") : (root.editingTeam ? "Change what you follow" : "Choose what to follow")
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

      // Match Details View: In-depth information for finished matches
      // Unified Search & Info View: Player profile & Club search center
      Column {
        id: unifiedSearchView
        width: parent.width
        spacing: Style.space(12)
        visible: root.showSearch && !root.showMatchDetail

        // Search Section: Shown when neither player nor club profile is active
        Column {
          id: searchMainSection
          width: parent.width
          spacing: Style.space(12)
          visible: !root.selectedPlayerProfile && !root.selectedClubProfile

        // Search Bar Input Field
        Rectangle {
          width: parent.width
          height: Style.space(38)
          radius: Style.cornerRadius
          color: Util.alpha(root.contentForeground, 0.07)
          border.width: Style.spacing.hairline
          border.color: searchBarInput.activeFocus ? root.favoriteTeamAccent : Util.alpha(root.contentForeground, 0.15)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "󰍉"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              color: Qt.darker(root.contentForeground, 1.4)
            }

            TextField {
              id: searchBarInput
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(30) - (clearSearchBtn.visible ? clearSearchBtn.width + parent.spacing : 0)
              height: parent.height
              verticalPadding: 0
              horizontalPadding: 0
              placeholderText: "Search players (e.g. Messi, Yamal) or clubs..."
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              foreground: root.contentForeground
              background: null
              text: root.searchQuery
              onTextChanged: root.triggerSearch(text)
            }

            Button {
              id: clearSearchBtn
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(22)
              height: Style.space(22)
              iconText: "󰅖"
              iconSize: Style.font.caption
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              horizontalPadding: 0
              verticalPadding: 0
              visible: searchBarInput.text.length > 0
              onClicked: {
                searchBarInput.text = ""
                root.searchQuery = ""
                root.searchResults = []
                root.selectedPlayerProfile = null
                root.selectedClubProfile = null
                searchBarInput.forceActiveFocus()
              }
            }
          }
        }

        // Active Search Loading Indicator
        Item {
          width: parent.width
          height: Style.space(28)
          visible: root.searchLoading
          Row {
            anchors.centerIn: parent
            spacing: Style.space(8)
            Text {
              text: "󰑮"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              color: root.favoriteTeamAccent
              opacity: 0.5 + 0.5 * root._pulse
            }
            Text {
              text: "Searching ESPN database…"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.contentForeground, 1.4)
            }
          }
        }

        // Active Club Fetch Loading Indicator
        Item {
          width: parent.width
          height: Style.space(36)
          visible: root.searchClubLoading && !root.selectedClubProfile
          Row {
            anchors.centerIn: parent
            spacing: Style.space(8)
            Text {
              text: "󰑮"
              font.family: "Symbols Nerd Font, " + root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              color: root.favoriteTeamAccent
              opacity: 0.5 + 0.5 * root._pulse
            }
            Text {
              text: "Loading club profile…"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.contentForeground, 1.4)
            }
          }
        }

        // Search Error or Empty Text
        Text {
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.searchError
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          visible: !root.searchLoading && !root.searchClubLoading && root.searchError !== "" && !root.selectedPlayerProfile && !root.selectedClubProfile
        }

        // Search Results List (Shown when neither player nor club is selected and not loading)
        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: !root.selectedPlayerProfile && !root.selectedClubProfile && !root.searchClubLoading && root.searchResults.length > 0

          Text {
            textFormat: Text.PlainText
            text: "Results (" + root.searchResults.length + ")"
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.left: parent.left
            anchors.leftMargin: Style.space(4)
          }

          Repeater {
            model: root.searchResults
            delegate: Rectangle {
              id: searchResultRow
              width: parent.width
              height: Style.space(46)
              radius: Style.cornerRadius
              color: searchResultArea.containsMouse ? Util.alpha(root.contentForeground, 0.08) : Util.alpha(root.contentForeground, 0.03)

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(10)

                // Image (Player headshot or Club crest)
                Image {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(32)
                  height: width
                  source: modelData.image
                  fillMode: Image.PreserveAspectFit
                  mipmap: true
                  smooth: true
                  visible: String(source) !== ""
                }

                // Fallback icon if no image
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(32)
                  height: width
                  verticalAlignment: Text.AlignVCenter
                  horizontalAlignment: Text.AlignHCenter
                  visible: !modelData.image || String(modelData.image) === ""
                  text: modelData.type === "player" ? "" : "󰕲"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  color: Qt.darker(root.contentForeground, 1.4)
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(70)
                  spacing: Style.space(2)

                  Row {
                    spacing: Style.space(6)
                    Text {
                      text: modelData.displayName
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                      elide: Text.ElideRight
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "· " + (modelData.type === "player" ? "Player" : "Club")
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: Qt.darker(root.contentForeground, 1.45)
                    }
                  }

                  Text {
                    text: modelData.subtitle
                    color: Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    visible: text !== ""
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: ""
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  color: Qt.darker(root.contentForeground, 1.6)
                }
              }

              MouseArea {
                id: searchResultArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (modelData.type === "player") {
                    root.openPlayerSearchDetail(modelData)
                  } else {
                    root.openClubSearchDetail(modelData)
                  }
                }
              }
            }
          }
        }
        } // searchMainSection

        // Dedicated Profile View: Shown when a player or club profile is selected
        Column {
          id: profileDedicatedView
          width: parent.width
          spacing: Style.space(12)
          visible: root.selectedPlayerProfile !== null || root.selectedClubProfile !== null

          // Top Navigation Bar
          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              height: Math.max(profileBackButton.implicitHeight, profileBreadcrumbRow.implicitHeight, Style.space(26))

              Button {
                id: profileBackButton
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(26)
                iconText: ""
                text: "Back"
                tooltipText: root.profileNavBackLabel
                fontFamily: root.contentFontFamily
                foreground: root.contentForeground
                accent: root.favoriteTeamAccent
                fontSize: Style.font.caption
                iconSize: Style.space(10)
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(2)
                onClicked: root.navigateBackFromProfile()
              }

              // Breadcrumb Navigation (right-aligned, constrained within panel)
              Row {
                id: profileBreadcrumbRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                MouseArea {
                  id: bSearchArea
                  width: bSearchText.implicitWidth
                  height: bSearchText.implicitHeight
                  anchors.verticalCenter: parent.verticalCenter
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  onClicked: {
                    root.clubProfileHistory = null
                    root.selectedPlayerProfile = null
                    root.selectedClubProfile = null
                    root.resetPanelScroll()
                  }
                  Text {
                    id: bSearchText
                    text: "Search"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption - 1
                    color: bSearchArea.containsMouse ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.5)
                    font.bold: true
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "›"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption - 1
                  color: Qt.darker(root.contentForeground, 1.9)
                }

                MouseArea {
                  id: bClubHistArea
                  visible: root.clubProfileHistory !== null
                  width: visible ? bClubHistText.implicitWidth : 0
                  height: bClubHistText.implicitHeight
                  anchors.verticalCenter: parent.verticalCenter
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  onClicked: {
                    root.selectedClubProfile = root.clubProfileHistory
                    root.clubProfileHistory = null
                    root.selectedPlayerProfile = null
                    root.searchClubCardTab = "overview"
                    root.resetPanelScroll()
                  }
                  Text {
                    id: bClubHistText
                    text: root.clubProfileHistory ? (root.clubProfileHistory.displayName || root.clubProfileHistory.shortDisplayName || "Club") : ""
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption - 1
                    color: bClubHistArea.containsMouse ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.5)
                    font.bold: true
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, Style.space(70))
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "›"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption - 1
                  color: Qt.darker(root.contentForeground, 1.9)
                  visible: root.clubProfileHistory !== null
                }

                Text {
                  id: bCurrentTargetText
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.selectedPlayerProfile ? (root.selectedPlayerProfile.shortName || root.selectedPlayerProfile.fullName) : (root.selectedClubProfile ? (root.selectedClubProfile.shortDisplayName || root.selectedClubProfile.displayName) : "")
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                  color: root.favoriteTeamAccent
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, Math.max(Style.space(40), parent.width - profileBackButton.width - (bSearchArea.width + Style.space(24) + (root.clubProfileHistory ? (bClubHistArea.width + Style.space(16)) : 0))))
                }
              }
            }

            // Header Title
            Text {
              width: parent.width
              text: root.selectedPlayerProfile ? root.selectedPlayerProfile.fullName : (root.selectedClubProfile ? root.selectedClubProfile.displayName : "")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
            }
          }

          // Selected Player Card
          Column {
            width: parent.width
            spacing: Style.space(12)
            visible: root.selectedPlayerProfile !== null

            Rectangle {
            width: parent.width
            height: playerProfileInnerCol.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.65)
            clip: true
            border.width: Style.spacing.hairline
            border.color: Util.alpha(root.favoriteTeamAccent, 0.35)

            // Frosted glass gradient banner
            Rectangle {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              height: Style.space(120)
              gradient: Gradient {
                GradientStop { position: 0.0; color: Util.alpha(root.favoriteTeamAccent, 0.32) }
                GradientStop { position: 0.55; color: Util.alpha(root.favoriteTeamAccent, 0.10) }
                GradientStop { position: 1.0; color: "transparent" }
              }
            }

            // High-depth blurred club crest watermark
            Item {
              anchors.right: parent.right
              anchors.rightMargin: -Style.space(16)
              anchors.top: parent.top
              anchors.topMargin: -Style.space(6)
              width: Style.space(150)
              height: width
              opacity: 0.18
              visible: root.selectedPlayerProfile && root.selectedPlayerProfile.teamCrest !== ""

              Image {
                id: playerWatermarkImg
                anchors.fill: parent
                source: root.selectedPlayerProfile ? root.selectedPlayerProfile.teamCrest : ""
                fillMode: Image.PreserveAspectFit
                mipmap: true
                smooth: true
                visible: false
              }

              MultiEffect {
                anchors.fill: parent
                source: playerWatermarkImg
                blurEnabled: true
                blur: 0.45
                blurMax: 32
                autoPaddingEnabled: false
              }
            }

            Column {
              id: playerProfileInnerCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(12)
              spacing: Style.space(10)

              Row {
                width: parent.width
                spacing: Style.space(12)

                // Headshot with subtle backdrop circle
                // Headshot with clean circular clip (no placeholder behind when valid)
                Item {
                  width: Style.space(64)
                  height: width

                  readonly property bool hasHeadshot: root.selectedPlayerProfile && root.selectedPlayerProfile.headshot && String(root.selectedPlayerProfile.headshot) !== "" && playerHeadshotImg.status === Image.Ready

                  // Placeholder avatar shown ONLY when player has NO headshot or while failing
                  Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Util.alpha(root.contentForeground, 0.06)
                    border.width: Style.spacing.hairline
                    border.color: Util.alpha(root.contentForeground, 0.15)
                    visible: !parent.hasHeadshot

                    Text {
                      anchors.centerIn: parent
                      text: ""
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.space(32)
                      color: Util.alpha(root.contentForeground, 0.25)
                    }
                  }

                  Image {
                    id: playerHeadshotImg
                    anchors.fill: parent
                    source: root.selectedPlayerProfile ? root.selectedPlayerProfile.headshot : ""
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    smooth: true
                    visible: String(source) !== "" && status === Image.Ready
                  }
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(78)
                  spacing: Style.space(3)

                  Row {
                    width: parent.width
                    spacing: Style.space(6)
                    Text {
                      text: root.selectedPlayerProfile ? root.selectedPlayerProfile.fullName : ""
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                      width: Math.min(implicitWidth, parent.width - (jerseyText.visible ? jerseyText.implicitWidth + parent.spacing : 0))
                    }
                    Text {
                      id: jerseyText
                      text: root.selectedPlayerProfile && root.selectedPlayerProfile.jersey !== "" ? ("#" + root.selectedPlayerProfile.jersey) : ""
                      color: root.favoriteTeamAccent
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      visible: text !== ""
                    }
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Item {
                      width: Style.space(20)
                      height: Style.space(16)
                      anchors.verticalCenter: parent.verticalCenter
                      visible: !!(root.selectedPlayerProfile && root.selectedPlayerProfile.teamCrest && root.selectedPlayerProfile.teamCrest !== "")

                      Image {
                        anchors.centerIn: parent
                        width: Style.space(16)
                        height: Style.space(16)
                        source: root.selectedPlayerProfile ? root.selectedPlayerProfile.teamCrest : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(128, 128)
                        mipmap: true
                        smooth: true
                      }
                    }

                    Text {
                      width: Math.max(0, parent.width - Style.space(26))
                      text: {
                        if (!root.selectedPlayerProfile) return ""
                        var cName = root.selectedPlayerProfile.teamName || ""
                        var pos = root.selectedPlayerProfile.position || ""
                        return cName !== "" ? (pos !== "" ? (cName + " · " + pos) : cName) : pos
                      }
                      color: Qt.darker(root.contentForeground, 1.25)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      elide: Text.ElideRight
                      visible: text !== ""
                    }
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Item {
                      width: Style.space(20)
                      height: Style.space(16)
                      anchors.verticalCenter: parent.verticalCenter
                      visible: !!(root.selectedPlayerProfile && root.selectedPlayerProfile.flag && root.selectedPlayerProfile.flag !== "")

                      Image {
                        anchors.centerIn: parent
                        width: Style.space(20)
                        height: Style.space(14)
                        source: root.selectedPlayerProfile ? root.selectedPlayerProfile.flag : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(120, 80)
                        mipmap: true
                        smooth: true
                      }
                    }

                    Text {
                      width: Math.max(0, parent.width - Style.space(26))
                      text: {
                        if (!root.selectedPlayerProfile) return ""
                        var nat = root.selectedPlayerProfile.citizenship || ""
                        var st = root.selectedPlayerProfile.status || ""
                        return nat !== "" ? (st !== "" ? (nat + " · " + st) : nat) : st
                      }
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      visible: text !== ""
                    }
                  }
                }
              }

              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: Util.alpha(root.contentForeground, 0.12)
              }

              // Player Card Tabs: Info | Stats | Matches
              Row {
                width: parent.width
                spacing: Style.space(4)

                Button {
                  height: Style.space(20)
                  fontSize: Style.space(9)
                  horizontalPadding: Style.space(8)
                  verticalPadding: 0
                  text: "Info"
                  selected: root.searchPlayerCardTab === "info"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.searchPlayerCardTab = "info"
                }
                Button {
                  height: Style.space(20)
                  fontSize: Style.space(9)
                  horizontalPadding: Style.space(8)
                  verticalPadding: 0
                  text: "Stats"
                  selected: root.searchPlayerCardTab === "stats"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: { root.searchPlayerCardTab = "stats"; root.ensurePlayerStats(); root.ensureClubNames() }
                }
                Button {
                  height: Style.space(20)
                  fontSize: Style.space(9)
                  horizontalPadding: Style.space(8)
                  verticalPadding: 0
                  text: "Matches"
                  selected: root.searchPlayerCardTab === "matches"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.searchPlayerCardTab = "matches"
                }
              }

              // Bio Stats Card
              Rectangle {
                width: parent.width
                height: bioGridCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: root.searchPlayerCardTab === "info"

                Column {
                  id: bioGridCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Column {
                      width: (parent.width - Style.space(12)) / 3
                      spacing: Style.space(2)
                      Text { text: "AGE"; font.pixelSize: Style.space(9); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text { text: root.selectedPlayerProfile && root.selectedPlayerProfile.age !== "" ? root.selectedPlayerProfile.age : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 3
                      spacing: Style.space(2)
                      Text { text: "HEIGHT"; font.pixelSize: Style.space(9); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text { text: root.selectedPlayerProfile && root.selectedPlayerProfile.displayHeight !== "" ? root.selectedPlayerProfile.displayHeight : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 3
                      spacing: Style.space(2)
                      Text { text: "WEIGHT"; font.pixelSize: Style.space(9); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text { text: root.selectedPlayerProfile && root.selectedPlayerProfile.displayWeight !== "" ? root.selectedPlayerProfile.displayWeight : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                    }
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(6)
                    visible: !!(root.selectedPlayerProfile && (root.selectedPlayerProfile.dateOfBirth !== "" || root.selectedPlayerProfile.birthplace !== ""))

                    Column {
                      width: (parent.width - Style.space(6)) / 2
                      spacing: Style.space(2)
                      visible: !!(root.selectedPlayerProfile && root.selectedPlayerProfile.dateOfBirth !== "")
                      Text { text: "BORN"; font.pixelSize: Style.space(9); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text { text: (root.selectedPlayerProfile && root.selectedPlayerProfile.dateOfBirth) ? String(root.selectedPlayerProfile.dateOfBirth) : ""; font.pixelSize: Style.font.caption; color: root.contentForeground; font.family: root.contentFontFamily; elide: Text.ElideRight }
                    }

                    Column {
                      width: (parent.width - Style.space(6)) / 2
                      spacing: Style.space(2)
                      visible: !!(root.selectedPlayerProfile && root.selectedPlayerProfile.birthplace !== "")
                      Text { text: "BIRTHPLACE"; font.pixelSize: Style.space(9); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text { text: (root.selectedPlayerProfile && root.selectedPlayerProfile.birthplace) ? String(root.selectedPlayerProfile.birthplace) : ""; font.pixelSize: Style.font.caption; color: root.contentForeground; font.family: root.contentFontFamily; elide: Text.ElideRight }
                    }
                  }
                }
              }

              // Recent Match Log & Form (Last 5 Games)
              Rectangle {
                width: parent.width
                height: playerMatchesCol.implicitHeight + Style.space(20)
                radius: Style.space(8)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: root.searchPlayerCardTab === "matches"

                Column {
                  id: playerMatchesCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(10)
                  spacing: Style.space(8)

                  Item {
                    width: parent.width
                    height: recentMatchesHeaderTitle.implicitHeight

                    Text {
                      id: recentMatchesHeaderTitle
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      text: "RECENT MATCHES"
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      font.letterSpacing: 0.5
                      color: Qt.darker(root.contentForeground, 1.3)
                      font.family: root.contentFontFamily
                    }
                  }

                  // If empty or loading
                  Text {
                    width: parent.width
                    text: root.searchPlayerOverviewRequest && root.searchPlayerOverviewRequest.running ? "Loading recent matches…" : "No recent matches available"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    color: Qt.darker(root.contentForeground, 1.6)
                    visible: !root.selectedPlayerProfile || !root.selectedPlayerProfile.recentMatches || root.selectedPlayerProfile.recentMatches.length === 0
                  }

                  // Match rows
                  Repeater {
                    model: root.selectedPlayerProfile ? root.selectedPlayerProfile.recentMatches : []
                    delegate: Rectangle {
                      width: parent.width
                      height: (modelData.leagueName && modelData.leagueName !== "") ? Style.space(64) : Style.space(52)
                      radius: Style.space(6)
                      color: Util.alpha(root.contentForeground, 0.035)
                      border.width: Style.spacing.hairline
                      border.color: Util.alpha(root.contentForeground, 0.08)

                      Column {
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        spacing: Style.space(3)

                        // Top line: League / Competition Name & Date
                        Item {
                          width: parent.width
                          height: Style.space(12)
                          visible: !!(modelData.leagueName && modelData.leagueName !== "")

                          Text {
                            anchors.left: parent.left
                            anchors.right: matchDateText.left
                            anchors.rightMargin: Style.space(6)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.leagueName || ""
                            color: Qt.darker(root.contentForeground, 1.55)
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption - 2
                            font.bold: true
                            elide: Text.ElideRight
                          }

                          Text {
                            id: matchDateText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.date || ""
                            color: Qt.darker(root.contentForeground, 1.7)
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption - 2
                            visible: text !== ""
                          }
                        }

                        // Match line: Team A vs Team B (left) and Score (right)
                        Item {
                          width: parent.width
                          height: Style.space(16)

                          Text {
                            id: matchScoreText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.score || "—"
                            color: root.contentForeground
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }

                          Text {
                            anchors.left: parent.left
                            anchors.right: matchScoreText.left
                            anchors.rightMargin: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.matchTitle || (modelData.opponentName ? ("vs " + modelData.opponentName) : "Match")
                            color: root.contentForeground
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            elide: Text.ElideRight
                          }
                        }

                        // Bottom line: Goals & Assists (left) and Player Rating (right)
                        Item {
                          width: parent.width
                          height: Style.space(16)

                          Row {
                            id: matchRatingRow
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(4)

                            Text {
                              anchors.verticalCenter: parent.verticalCenter
                              text: "Rating:"
                              color: Qt.darker(root.contentForeground, 1.4)
                              font.family: root.contentFontFamily
                              font.pixelSize: Style.font.caption - 1
                            }

                            Text {
                              anchors.verticalCenter: parent.verticalCenter
                              text: (modelData.rating && modelData.rating !== "" && modelData.rating !== "—") ? modelData.rating : "—"
                              color: (modelData.rating && modelData.rating !== "" && modelData.rating !== "—") ? root.ratingColor(modelData.rating) : Qt.darker(root.contentForeground, 1.4)
                              font.family: root.contentFontFamily
                              font.pixelSize: Style.font.caption - 1
                              font.bold: true
                            }
                          }

                          Row {
                            anchors.left: parent.left
                            anchors.right: matchRatingRow.left
                            anchors.rightMargin: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(6)

                            Text {
                              anchors.verticalCenter: parent.verticalCenter
                              text: "Goals: " + (modelData.goals !== undefined ? modelData.goals : "0")
                              color: parseInt(modelData.goals) > 0 ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.3)
                              font.family: root.contentFontFamily
                              font.pixelSize: Style.font.caption - 1
                              font.bold: parseInt(modelData.goals) > 0
                            }

                            Text {
                              anchors.verticalCenter: parent.verticalCenter
                              text: "·"
                              color: Qt.darker(root.contentForeground, 1.6)
                              font.pixelSize: Style.font.caption - 1
                            }

                            Text {
                              anchors.verticalCenter: parent.verticalCenter
                              text: "Assists: " + (modelData.assists !== undefined ? modelData.assists : "0")
                              color: parseInt(modelData.assists) > 0 ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.3)
                              font.family: root.contentFontFamily
                              font.pixelSize: Style.font.caption - 1
                              font.bold: parseInt(modelData.assists) > 0
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }

              // All-teams Career/Season Stats Card
              Rectangle {
                width: parent.width
                height: careerStatsCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: root.selectedPlayerProfile && (root.selectedPlayerProfile.careerAppearances !== "" || root.selectedPlayerProfile.careerGoals !== "" || root.selectedPlayerProfile.seasonAppearances !== "" || (root.selectedPlayerProfile.availableSeasons && root.selectedPlayerProfile.availableSeasons.length > 0)) && root.searchPlayerCardTab === "stats"

                Column {
                  id: careerStatsCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(6)

                  // Header Row: STATISTICS on Left, Season Navigator on Right
                  Item {
                    width: parent.width
                    height: Style.space(20)

                    Text {
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      text: "STATISTICS"
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                    }

                    // Season Year and Prev/Next Toggle Buttons (Right-aligned)
                    Row {
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(4)
                      visible: root.searchPlayerStatsTab !== "career" && !!(root.selectedPlayerProfile && root.selectedPlayerProfile.availableSeasons && root.selectedPlayerProfile.availableSeasons.length > 0)

                      // Older Season (◀)
                      Button {
                        height: Style.space(20)
                        fontSize: Style.space(8)
                        horizontalPadding: Style.space(6)
                        verticalPadding: 0
                        text: "◀"
                        enabled: root.selectedPlayerProfile && root.selectedPlayerProfile.availableSeasons && ((root.selectedPlayerProfile.selectedSeasonIndex || 0) < (root.selectedPlayerProfile.availableSeasons.length - 1))
                        opacity: enabled ? 1.0 : 0.35
                        fontFamily: root.contentFontFamily
                        foreground: root.contentForeground
                        accent: root.contentForeground
                        onClicked: root.changePlayerSeason(1)
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                          var prof = root.selectedPlayerProfile
                          if (!prof || !prof.availableSeasons || prof.availableSeasons.length === 0) return ""
                          var sIdx = prof.selectedSeasonIndex || 0
                          var s = prof.availableSeasons[sIdx]
                          return s ? (s.seasonYear || String(s.year)) : ""
                        }
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.favoriteTeamAccent
                        font.family: root.contentFontFamily
                      }

                      // Newer Season (▶)
                      Button {
                        height: Style.space(20)
                        fontSize: Style.space(8)
                        horizontalPadding: Style.space(6)
                        verticalPadding: 0
                        text: "▶"
                        enabled: root.selectedPlayerProfile && (root.selectedPlayerProfile.selectedSeasonIndex || 0) > 0
                        opacity: enabled ? 1.0 : 0.35
                        fontFamily: root.contentFontFamily
                        foreground: root.contentForeground
                        accent: root.contentForeground
                        onClicked: root.changePlayerSeason(-1)
                      }
                    }
                  }

                  // Filter Row: All Stats | Club | Country | Tournament | Career
                  Row {
                    width: parent.width
                    spacing: Style.space(4)

                    Button {
                      height: Style.space(20)
                      fontSize: Style.space(8)
                      horizontalPadding: Style.space(6)
                      verticalPadding: 0
                      text: "All Stats"
                      selected: root.searchPlayerStatsTab === "all"
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.contentForeground
                      onClicked: root.setPlayerStatsTab("all")
                    }

                    Button {
                      height: Style.space(20)
                      fontSize: Style.space(8)
                      horizontalPadding: Style.space(6)
                      verticalPadding: 0
                      text: "Club"
                      selected: root.searchPlayerStatsTab === "club"
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.contentForeground
                      onClicked: root.setPlayerStatsTab("club")
                    }

                    Button {
                      height: Style.space(20)
                      fontSize: Style.space(8)
                      horizontalPadding: Style.space(6)
                      verticalPadding: 0
                      text: "Country"
                      selected: root.searchPlayerStatsTab === "country"
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.contentForeground
                      onClicked: root.setPlayerStatsTab("country")
                    }

                    Button {
                      height: Style.space(20)
                      fontSize: Style.space(8)
                      horizontalPadding: Style.space(6)
                      verticalPadding: 0
                      text: "Tournament"
                      selected: root.searchPlayerStatsTab === "tournament"
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.contentForeground
                      onClicked: root.setPlayerStatsTab("tournament")
                    }

                    Button {
                      height: Style.space(20)
                      fontSize: Style.space(8)
                      horizontalPadding: Style.space(6)
                      verticalPadding: 0
                      text: "Career"
                      selected: root.searchPlayerStatsTab === "career"
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.contentForeground
                      onClicked: root.setPlayerStatsTab("career")
                    }
                  }

                  // Tournament selector row (visible when Tournament filter is selected)
                  Item {
                    id: tournamentRowContainer
                    width: parent.width
                    height: Style.space(24)
                    visible: root.searchPlayerStatsTab === "tournament" && root.currentSeasonComps().length > 0
                    clip: true

                    Flickable {
                      id: tournamentFlick
                      anchors.fill: parent
                      contentWidth: tournamentRow.implicitWidth
                      contentHeight: height
                      boundsBehavior: Flickable.StopAtBounds
                      flickableDirection: Flickable.HorizontalFlick

                      Row {
                        id: tournamentRow
                        spacing: Style.space(4)

                        Repeater {
                          model: root.currentSeasonComps()
                          delegate: Button {
                            height: Style.space(20)
                            fontSize: Style.space(8)
                            horizontalPadding: Style.space(6)
                            verticalPadding: 0
                            text: modelData.shortName || modelData.leagueName || modelData.league
                            selected: (root.selectedPlayerProfile && (root.selectedPlayerProfile.selectedCompIndex || 0) === index)
                            fontFamily: root.contentFontFamily
                            foreground: root.contentForeground
                            accent: root.contentForeground
                            onClicked: root.selectPlayerTournament(index)
                          }
                        }
                      }
                    }
                  }

                  Item {
                    width: parent.width
                    height: Style.space(18)
                    visible: root.searchPlayerStatsTab === "tournament" && root.currentSeasonComps().length === 0
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "No tournament data for this season"
                      font.pixelSize: Style.space(8)
                      font.italic: true
                      color: Qt.darker(root.contentForeground, 1.8)
                      font.family: root.contentFontFamily
                    }
                  }

                  // Main 4 Stats row
                  Row {
                    width: parent.width
                    spacing: Style.space(4)

                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "APPS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.searchPlayerStatsTab !== "career" && root.selectedPlayerProfile.seasonAppearances !== undefined)
                          ? String(root.selectedPlayerProfile.seasonAppearances)
                          : ((root.selectedPlayerProfile && root.selectedPlayerProfile.careerAppearances) ? String(root.selectedPlayerProfile.careerAppearances) : "—")
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "GOALS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.searchPlayerStatsTab !== "career" && root.selectedPlayerProfile.seasonGoals !== undefined)
                          ? String(root.selectedPlayerProfile.seasonGoals)
                          : ((root.selectedPlayerProfile && root.selectedPlayerProfile.careerGoals) ? String(root.selectedPlayerProfile.careerGoals) : "—")
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.favoriteTeamAccent
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "ASSISTS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.searchPlayerStatsTab !== "career" && root.selectedPlayerProfile.seasonAssists !== undefined)
                          ? String(root.selectedPlayerProfile.seasonAssists)
                          : ((root.selectedPlayerProfile && root.selectedPlayerProfile.careerAssists) ? String(root.selectedPlayerProfile.careerAssists) : "—")
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text {
                        text: root.stat4Active().label
                        font.pixelSize: Style.space(8)
                        font.bold: true
                        color: Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                      }
                      Text {
                        text: root.stat4Active().value !== "" ? root.stat4Active().value : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                  }
                }
              }

              // Shot & Passing Efficiency Card
              Rectangle {
                width: parent.width
                height: playerEfficiencyCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: root.searchPlayerCardTab === "stats" && root.selectedPlayerProfile

                Column {
                  id: playerEfficiencyCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Text {
                    text: "SHOT & PASSING EFFICIENCY"
                    font.pixelSize: Style.space(9)
                    font.bold: true
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(4)

                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "CONVERSION"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.goalConversionRate !== "") ? root.selectedPlayerProfile.goalConversionRate : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.favoriteTeamAccent
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "SHOT ACC."; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.shotAccuracy !== "") ? root.selectedPlayerProfile.shotAccuracy : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "LONG BALLS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.longBalls !== "") ? root.selectedPlayerProfile.longBalls : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "KEY PASSES"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.keyPasses !== "") ? root.selectedPlayerProfile.keyPasses : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                  }
                }
              }

              // Discipline & Workload Card
              Rectangle {
                width: parent.width
                height: playerDisciplineCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: root.searchPlayerCardTab === "stats" && root.selectedPlayerProfile

                Column {
                  id: playerDisciplineCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Text {
                    text: "DISCIPLINE & WORKLOAD"
                    font.pixelSize: Style.space(9)
                    font.bold: true
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                  }

                  // Row 1: Cards & Fouls
                  Row {
                    width: parent.width
                    spacing: Style.space(4)

                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "YELLOWS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.seasonYellowCards !== "") ? root.selectedPlayerProfile.seasonYellowCards : "0"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: "#eab308"
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "REDS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.seasonRedCards !== "") ? root.selectedPlayerProfile.seasonRedCards : "0"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: "#ef4444"
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "FOULS C/S"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.seasonFouls !== "") ? root.selectedPlayerProfile.seasonFouls : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "SUBS (IN/OUT)"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && (root.selectedPlayerProfile.seasonSubIns !== "" || root.selectedPlayerProfile.seasonSubOuts !== ""))
                          ? ((root.selectedPlayerProfile.seasonSubIns || "0") + " / " + (root.selectedPlayerProfile.seasonSubOuts || "0"))
                          : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                  }

                  // Row 2: Minutes & Avg min/app
                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Column {
                      width: (parent.width - Style.space(6)) / 2
                      spacing: Style.space(2)
                      Text { text: "TOTAL SEASON MINUTES"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.seasonMinutes) ? (root.selectedPlayerProfile.seasonMinutes + " mins") : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(6)) / 2
                      spacing: Style.space(2)
                      Text { text: "MINS PER APPEARANCE"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.seasonMinPerApp) ? (root.selectedPlayerProfile.seasonMinPerApp + " min/app") : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.favoriteTeamAccent
                        font.family: root.contentFontFamily
                      }
                    }
                  }
                }
              }


              // International & National Team Caps Card
              Rectangle {
                width: parent.width
                height: natTeamsCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: !!(root.searchPlayerCardTab === "info" && root.selectedPlayerProfile && ((root.selectedPlayerProfile.nationalTeams && root.selectedPlayerProfile.nationalTeams.length > 0) || (root.selectedPlayerProfile.flag && root.selectedPlayerProfile.flag !== "") || (root.selectedPlayerProfile.citizenship && root.selectedPlayerProfile.citizenship !== "")))

                Column {
                  id: natTeamsCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(6)

                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "󰝨"
                      font.pixelSize: Style.space(10)
                      font.family: "Symbols Nerd Font, " + root.contentFontFamily
                      color: root.favoriteTeamAccent
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "INTERNATIONAL / NATIONAL TEAMS"
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                    }
                  }

                  // National Team Entries
                  Repeater {
                    model: (root.selectedPlayerProfile && root.selectedPlayerProfile.nationalTeams && root.selectedPlayerProfile.nationalTeams.length > 0)
                      ? root.selectedPlayerProfile.nationalTeams
                      : (root.selectedPlayerProfile && root.selectedPlayerProfile.citizenship !== "" ? [{
                          name: root.selectedPlayerProfile.citizenship,
                          type: "Senior National Team",
                          isYouth: false,
                          seasons: "",
                          seasonCount: "",
                          logo: root.selectedPlayerProfile.flag
                        }] : [])
                    delegate: Row {
                      width: parent.width
                      height: Style.space(24)
                      spacing: Style.space(6)

                      Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(24)
                        height: Style.space(16)
                        source: modelData.logo || ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(120, 80)
                        mipmap: true
                        smooth: true
                        visible: String(source) !== ""
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name || "National Team"
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, parent.width - Style.space(130))
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.isYouth ? "Youth" : "Senior"
                        font.pixelSize: Style.space(8)
                        font.bold: true
                        color: modelData.isYouth ? Qt.darker(root.contentForeground, 1.4) : root.favoriteTeamAccent
                        font.family: root.contentFontFamily
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(65)
                        horizontalAlignment: Text.AlignRight
                        text: modelData.seasons || (modelData.seasonCount ? (modelData.seasonCount + " yrs") : "")
                        color: Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(9)
                        elide: Text.ElideRight
                        visible: text !== ""
                      }
                    }
                  }
                }
              }

              // Career Clubs Segmented Card (Vertical Column)
              Rectangle {
                width: parent.width
                height: careerClubsCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: !!(root.selectedPlayerProfile && root.selectedPlayerProfile.careerHistory && root.selectedPlayerProfile.careerHistory.length > 0 && root.searchPlayerCardTab === "info")

                Column {
                  id: careerClubsCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(6)

                  Text {
                    text: "CAREER CLUBS"
                    font.pixelSize: Style.space(9)
                    font.bold: true
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                  }

                  Column {
                    width: parent.width
                    spacing: Style.space(6)

                    Repeater {
                      model: root.selectedPlayerProfile ? root.selectedPlayerProfile.careerHistory : []
                      delegate: Item {
                        width: parent.width
                        height: Style.space(22)

                        Row {
                          anchors.left: parent.left
                          anchors.right: clubYearsText.left
                          anchors.rightMargin: Style.space(8)
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: Style.space(8)

                          Image {
                            width: Style.space(18)
                            height: width
                            anchors.verticalCenter: parent.verticalCenter
                            source: modelData.teamLogo
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            smooth: true
                            visible: String(source) !== ""
                          }

                          Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (String(modelData.teamLogo || "") !== "" ? Style.space(26) : 0)
                            text: ((modelData.name && modelData.name !== "") ? modelData.name : ((root.teamNameCache && root.teamNameCache[modelData.teamId]) ? root.teamNameCache[modelData.teamId] : "Club"))
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption
                            color: root.contentForeground
                            font.bold: true
                            elide: Text.ElideRight
                          }
                        }

                        Text {
                          id: clubYearsText
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          text: modelData.years || ""
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                          color: Qt.darker(root.contentForeground, 1.45)
                          font.bold: true
                        }
                      }
                    }
                  }
                }
              }

              // Transfer History Card
              Rectangle {
                width: parent.width
                height: transferHistoryCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: root.selectedPlayerProfile && root.selectedPlayerProfile.transferHistory && root.selectedPlayerProfile.transferHistory.length > 0 && root.searchPlayerCardTab === "info"

                Column {
                  id: transferHistoryCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "⇆"
                      font.pixelSize: Style.space(10)
                      font.family: root.contentFontFamily
                      color: root.favoriteTeamAccent
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "TRANSFER HISTORY"
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "(" + (root.selectedPlayerProfile && root.selectedPlayerProfile.transferHistory ? root.selectedPlayerProfile.transferHistory.length : 0) + ")"
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      color: Qt.darker(root.contentForeground, 1.8)
                      font.family: root.contentFontFamily
                    }
                  }

                  Column {
                    width: parent.width
                    spacing: Style.space(6)

                    Repeater {
                      model: root.selectedPlayerProfile ? root.selectedPlayerProfile.transferHistory : []
                      delegate: Rectangle {
                        id: transferItemRect
                        width: parent.width
                        height: Style.space(26)
                        radius: Style.space(4)
                        color: Util.alpha(root.contentForeground, 0.03)
                        border.width: Style.spacing.hairline
                        border.color: Util.alpha(root.contentForeground, 0.06)

                        MouseArea {
                          id: transferMouseArea
                          anchors.fill: parent
                          hoverEnabled: true
                        }

                        ToolTip {
                          visible: transferMouseArea.containsMouse
                          delay: 350
                          timeout: 4000
                          text: (modelData.fromName || "Unknown") + " → " + (modelData.toName || "Unknown") + " : " + modelData.fee + (modelData.date ? (" (" + modelData.date + ")") : "")
                        }

                        Row {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(6)
                          anchors.rightMargin: Style.space(6)
                          spacing: Style.space(5)

                          Text {
                            id: transferDateText
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.year || modelData.date || "—"
                            font.pixelSize: Style.space(9)
                            font.bold: true
                            color: root.favoriteTeamAccent
                            font.family: root.contentFontFamily
                          }

                          Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: (source && String(source) !== "") ? Style.space(14) : 0
                            height: width
                            source: modelData.fromLogo || ""
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            smooth: true
                            visible: String(source) !== ""
                          }

                          Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.fromName || "Unknown"
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            color: root.contentForeground
                            font.family: root.contentFontFamily
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: Math.min(implicitWidth, Math.max(Style.space(40), (parent.width - transferDateText.implicitWidth - feeText.implicitWidth - Style.space(56)) / 2))
                          }

                          Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "→"
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            color: root.favoriteTeamAccent
                            font.family: root.contentFontFamily
                          }

                          Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: (source && String(source) !== "") ? Style.space(14) : 0
                            height: width
                            source: modelData.toLogo || ""
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            smooth: true
                            visible: String(source) !== ""
                          }

                          Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.toName || "Unknown"
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            color: root.contentForeground
                            font.family: root.contentFontFamily
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: Math.min(implicitWidth, Math.max(Style.space(40), (parent.width - transferDateText.implicitWidth - feeText.implicitWidth - Style.space(56)) / 2))
                          }

                          Text {
                            id: feeText
                            anchors.verticalCenter: parent.verticalCenter
                            text: " : " + modelData.fee
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            color: (modelData.type === "Fee" || (modelData.rawAmount > 0)) ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.25)
                            font.family: root.contentFontFamily
                          }
                        }
                      }
                    }
                  }
                }
              }
              Button {
                width: parent.width
                iconText: "󰖟"
                text: "View Career Profile on ESPN"
                fontFamily: root.contentFontFamily
                foreground: root.contentForeground
                accent: root.contentForeground
                fontSize: Style.font.caption
                iconSize: Style.font.caption
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(4)
                visible: root.selectedPlayerProfile && root.selectedPlayerProfile.webUrl !== ""
                onClicked: {
                  if (root.selectedPlayerProfile && root.selectedPlayerProfile.webUrl !== "") {
                    Qt.openUrlExternally(root.selectedPlayerProfile.webUrl)
                  }
                }
              }
            }
          }
        }

        // Selected Club Card
        Column {
          width: parent.width
          spacing: Style.space(12)
          visible: root.selectedClubProfile !== null

          Rectangle {
            width: parent.width
            height: clubProfileInnerCol.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.65)
            clip: true
            border.width: Style.spacing.hairline
            border.color: Util.alpha(root.selectedClubProfile && root.selectedClubProfile.color !== "" ? root.selectedClubProfile.color : root.favoriteTeamAccent, 0.35)

            // Frosted glass gradient banner with club brand colors
            Rectangle {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              height: Style.space(120)
              gradient: Gradient {
                GradientStop { position: 0.0; color: Util.alpha(root.selectedClubProfile && root.selectedClubProfile.color !== "" ? root.selectedClubProfile.color : root.favoriteTeamAccent, 0.32) }
                GradientStop { position: 0.55; color: Util.alpha(root.selectedClubProfile && root.selectedClubProfile.alternateColor !== "" ? root.selectedClubProfile.alternateColor : (root.selectedClubProfile && root.selectedClubProfile.color !== "" ? root.selectedClubProfile.color : root.favoriteTeamAccent), 0.10) }
                GradientStop { position: 1.0; color: "transparent" }
              }
            }

            // High-depth blurred club crest watermark (soft opacity to maintain text legibility)
            Item {
              anchors.right: parent.right
              anchors.rightMargin: -Style.space(16)
              anchors.top: parent.top
              anchors.topMargin: -Style.space(6)
              width: Style.space(150)
              height: width
              opacity: 0.16
              visible: !!(root.selectedClubProfile && root.selectedClubProfile.logo)

              Image {
                id: clubWatermarkImg
                anchors.fill: parent
                source: (root.selectedClubProfile && root.selectedClubProfile.logo) ? root.selectedClubProfile.logo : ""
                fillMode: Image.PreserveAspectFit
                mipmap: true
                smooth: true
                visible: false
              }

              MultiEffect {
                anchors.fill: parent
                source: clubWatermarkImg
                blurEnabled: true
                blur: 0.45
                blurMax: 32
                autoPaddingEnabled: false
              }
            }

            Column {
              id: clubProfileInnerCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(12)
              spacing: Style.space(10)

              // Header Row: Club Crest + Name + League & Meta Details
              Row {
                width: parent.width
                spacing: Style.space(12)

                // Club crest container with subtle backdrop
                Item {
                  width: Style.space(56)
                  height: width
                  anchors.verticalCenter: parent.verticalCenter

                  Rectangle {
                    anchors.fill: parent
                    radius: Style.cornerRadius
                    color: Util.alpha(root.contentForeground, 0.05)
                    border.width: Style.spacing.hairline
                    border.color: Util.alpha(root.contentForeground, 0.12)
                  }

                  Image {
                    anchors.centerIn: parent
                    width: Style.space(46)
                    height: Style.space(46)
                    source: (root.selectedClubProfile && root.selectedClubProfile.logo) ? root.selectedClubProfile.logo : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(256, 256)
                    mipmap: true
                    smooth: true
                    visible: String(source) !== ""
                  }
                }

                // Club Info Column
                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(68)
                  spacing: Style.space(3)

                  // Club Name + Abbreviation
                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                      text: (root.selectedClubProfile && root.selectedClubProfile.displayName) ? root.selectedClubProfile.displayName : ""
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                      width: Math.min(implicitWidth, parent.width - (abbrevText.visible ? abbrevText.implicitWidth + parent.spacing : 0))
                    }

                    Text {
                      id: abbrevText
                      text: (root.selectedClubProfile && root.selectedClubProfile.abbreviation) ? root.selectedClubProfile.abbreviation : ""
                      color: root.favoriteTeamAccent
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      visible: text !== ""
                    }
                  }

                  // Competition / Standing Summary line
                  Text {
                    width: parent.width
                    text: {
                      if (!root.selectedClubProfile) return ""
                      if (root.selectedClubProfile.standingSummary) return root.selectedClubProfile.standingSummary
                      if (root.selectedClubProfile.leagueSlug) return root.leagueLabel(root.selectedClubProfile.leagueSlug)
                      return root.selectedClubProfile.leagueName || ""
                    }
                    color: Qt.darker(root.contentForeground, 1.25)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                    visible: text !== ""
                  }

                  // Meta details: Season Record, Stadium, Manager
                  Flow {
                    width: parent.width
                    spacing: Style.space(8)

                    // Season Record
                    Row {
                      spacing: Style.space(4)
                      visible: !!(root.selectedClubProfile && root.selectedClubProfile.record)
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Record:"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(9)
                        color: Qt.darker(root.contentForeground, 1.6)
                      }
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.selectedClubProfile && root.selectedClubProfile.record) ? root.selectedClubProfile.record : ""
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(9)
                        font.bold: true
                      }
                    }

                    // Venue / Stadium
                    Row {
                      spacing: Style.space(4)
                      visible: !!(root.selectedClubProfile && root.selectedClubProfile.venue)
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰿹"
                        font.family: "Symbols Nerd Font, " + root.contentFontFamily
                        font.pixelSize: Style.space(9)
                        color: Qt.darker(root.contentForeground, 1.6)
                      }
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.selectedClubProfile && root.selectedClubProfile.venue) ? root.selectedClubProfile.venue : ""
                        color: Qt.darker(root.contentForeground, 1.45)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(9)
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
              }

              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: Util.alpha(root.contentForeground, 0.12)
              }

              // Club Card Tabs: Overview | Squad | Fixtures
              Row {
                width: parent.width
                spacing: Style.space(4)

                Button {
                  height: Style.space(20)
                  fontSize: Style.space(9)
                  horizontalPadding: Style.space(8)
                  verticalPadding: 0
                  text: "Overview"
                  selected: root.searchClubCardTab === "overview"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.searchClubCardTab = "overview"
                }
                Button {
                  height: Style.space(20)
                  fontSize: Style.space(9)
                  horizontalPadding: Style.space(8)
                  verticalPadding: 0
                  text: "Squad"
                  selected: root.searchClubCardTab === "squad"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.searchClubCardTab = "squad"
                }
                Button {
                  height: Style.space(20)
                  fontSize: Style.space(9)
                  horizontalPadding: Style.space(8)
                  verticalPadding: 0
                  text: "Fixtures"
                  selected: root.searchClubCardTab === "fixtures"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.searchClubCardTab = "fixtures"
                }
              }

          Item {
            width: parent.width
            height: Style.space(20)
            visible: root.searchClubLoading
            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)
              Text {
                text: "󰑮"
                font.family: "Symbols Nerd Font, " + root.contentFontFamily
                font.pixelSize: Style.font.caption
                color: root.favoriteTeamAccent
                opacity: 0.5 + 0.5 * root._pulse
              }
              Text {
                text: "Updating stats & schedule…"
                font.family: root.contentFontFamily
                font.pixelSize: Style.space(9)
                color: Qt.darker(root.contentForeground, 1.6)
              }
            }
          }

          // ==================== OVERVIEW TAB ====================
          // Card 1: League Campaign & Standings (Unified, clean, no stacked boxes)
          Rectangle {
            width: parent.width
            height: standingsCol.implicitHeight + Style.space(18)
            radius: Style.cornerRadius
            color: Util.alpha(root.contentForeground, 0.035)
            border.width: Style.spacing.hairline
            border.color: Util.alpha(root.contentForeground, 0.08)
            visible: root.searchClubCardTab === "overview" && root.selectedClubProfile && (root.selectedClubProfile.points !== "" || root.selectedClubProfile.record !== "" || root.selectedClubProfile.form !== "")

            Column {
              id: standingsCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              // Header: League Title & Standing Summary
              Item {
                width: parent.width
                height: Style.space(14)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: (root.selectedClubProfile && root.selectedClubProfile.leagueSlug) ? (root.leagueLabel(root.selectedClubProfile.leagueSlug).toUpperCase() + " STANDINGS") : "LEAGUE STANDINGS"
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  font.letterSpacing: 0.5
                  color: Qt.darker(root.contentForeground, 1.3)
                  font.family: root.contentFontFamily
                  elide: Text.ElideRight
                  width: parent.width * 0.6
                }

                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: (root.selectedClubProfile && root.selectedClubProfile.standingSummary) ? root.selectedClubProfile.standingSummary : ""
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  color: root.favoriteTeamAccent
                  font.family: root.contentFontFamily
                  elide: Text.ElideRight
                  width: parent.width * 0.4
                  horizontalAlignment: Text.AlignRight
                }
              }

              // Standings Table Row (PTS | W | D | L | DIFF | GF:GA)
              Row {
                width: parent.width
                spacing: Style.space(4)

                Column {
                  width: (parent.width - Style.space(20)) / 6
                  spacing: Style.space(2)
                  Text { text: "PTS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.points !== undefined && root.selectedClubProfile.points !== "") ? String(root.selectedClubProfile.points) : "0"; font.pixelSize: Style.font.body; font.bold: true; color: root.favoriteTeamAccent; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(20)) / 6
                  spacing: Style.space(2)
                  Text { text: "W"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.wins !== undefined && root.selectedClubProfile.wins !== "") ? String(root.selectedClubProfile.wins) : "0"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(20)) / 6
                  spacing: Style.space(2)
                  Text { text: "D"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.ties !== undefined && root.selectedClubProfile.ties !== "") ? String(root.selectedClubProfile.ties) : "0"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(20)) / 6
                  spacing: Style.space(2)
                  Text { text: "L"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.losses !== undefined && root.selectedClubProfile.losses !== "") ? String(root.selectedClubProfile.losses) : "0"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(20)) / 6
                  spacing: Style.space(2)
                  Text { text: "DIFF"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.diff !== undefined && root.selectedClubProfile.diff !== "") ? String(root.selectedClubProfile.diff) : "0"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(20)) / 6
                  spacing: Style.space(2)
                  Text { text: "GF:GA"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.goalsFor !== undefined && root.selectedClubProfile.goalsAgainst !== undefined && root.selectedClubProfile.goalsFor !== "") ? (root.selectedClubProfile.goalsFor + ":" + root.selectedClubProfile.goalsAgainst) : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
              }

              // Divider between table and form/splits
              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: Util.alpha(root.contentForeground, 0.06)
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.form || root.selectedClubProfile.homeRecord || root.selectedClubProfile.awayRecord))
              }

              // Recent Form & Home / Away Splits Row (Clean typography, no box container)
              Item {
                width: parent.width
                implicitHeight: Math.max(formRow.implicitHeight, splitsRow.implicitHeight, Style.space(16))
                height: implicitHeight
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.form || root.selectedClubProfile.homeRecord || root.selectedClubProfile.awayRecord))

                // Left: Form badges
                Row {
                  id: formRow
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)
                  visible: !!(root.selectedClubProfile && root.selectedClubProfile.form)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "FORM"
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                  }

                  Repeater {
                    model: root.selectedClubProfile ? root.selectedClubProfile.form.split("") : []
                    delegate: Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(16)
                      height: width
                      radius: Style.space(3)
                      readonly property color badgeClr: modelData === "W" ? "#22c55e" : (modelData === "D" ? "#eab308" : "#ef4444")
                      color: Util.alpha(badgeClr, 0.18)

                      Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.bold: true
                        font.pixelSize: Style.space(8)
                        font.family: root.contentFontFamily
                        color: "#ffffff"
                      }
                    }
                  }
                }

                // Right: Home & Away Splits (clean inline text, no container box)
                Row {
                  id: splitsRow
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)
                  visible: !!(root.selectedClubProfile && (root.selectedClubProfile.homeRecord || root.selectedClubProfile.awayRecord))

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selectedClubProfile && root.selectedClubProfile.homeRecord ? ("Home: " + root.selectedClubProfile.homeRecord) : ""
                    font.pixelSize: Style.space(8)
                    color: Qt.darker(root.contentForeground, 1.45)
                    font.family: root.contentFontFamily
                    visible: text !== ""
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "·"
                    font.pixelSize: Style.space(8)
                    color: Qt.darker(root.contentForeground, 1.8)
                    visible: !!(root.selectedClubProfile && root.selectedClubProfile.homeRecord && root.selectedClubProfile.awayRecord)
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selectedClubProfile && root.selectedClubProfile.awayRecord ? ("Away: " + root.selectedClubProfile.awayRecord) : ""
                    font.pixelSize: Style.space(8)
                    color: Qt.darker(root.contentForeground, 1.45)
                    font.family: root.contentFontFamily
                    visible: text !== ""
                  }
                }
              }
            }
          }

          // Card 2: Team Performance & Discipline (Clean unified card, no choppy boxes)
          Rectangle {
            width: parent.width
            height: metricsCol.implicitHeight + Style.space(18)
            radius: Style.cornerRadius
            color: Util.alpha(root.contentForeground, 0.035)
            border.width: Style.spacing.hairline
            border.color: Util.alpha(root.contentForeground, 0.08)
            visible: root.searchClubCardTab === "overview" && !!(root.selectedClubProfile && (root.selectedClubProfile.possession || root.selectedClubProfile.shotsPerGame || root.selectedClubProfile.yellowCards !== undefined))

            Column {
              id: metricsCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              // Header
              Item {
                width: parent.width
                height: Style.space(14)
                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "TEAM PERFORMANCE & DISCIPLINE"
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  font.letterSpacing: 0.5
                  color: Qt.darker(root.contentForeground, 1.3)
                  font.family: root.contentFontFamily
                }
              }

              // Optional Season Leaders Row (if available)
              Row {
                width: parent.width
                spacing: Style.space(6)
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.topScorer || root.selectedClubProfile.topAssister || root.selectedClubProfile.topCarder))

                Column {
                  width: (parent.width - Style.space(12)) / 3
                  spacing: Style.space(2)
                  visible: !!(root.selectedClubProfile && root.selectedClubProfile.topScorer)
                  Text { text: "TOP SCORER"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.topScorer) ? root.selectedClubProfile.topScorer : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.favoriteTeamAccent; font.family: root.contentFontFamily; wrapMode: Text.Wrap; width: parent.width }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 3
                  spacing: Style.space(2)
                  visible: !!(root.selectedClubProfile && root.selectedClubProfile.topAssister)
                  Text { text: "TOP ASSISTER"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.topAssister) ? root.selectedClubProfile.topAssister : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily; wrapMode: Text.Wrap; width: parent.width }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 3
                  spacing: Style.space(2)
                  visible: !!(root.selectedClubProfile && root.selectedClubProfile.topCarder)
                  Text { text: "DISCIPLINE"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.topCarder) ? root.selectedClubProfile.topCarder : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: "#eab308"; font.family: root.contentFontFamily; wrapMode: Text.Wrap; width: parent.width }
                }
              }

              // Divider between leaders and metrics (if leaders visible)
              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: Util.alpha(root.contentForeground, 0.06)
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.topScorer || root.selectedClubProfile.topAssister || root.selectedClubProfile.topCarder))
              }

              // Row 1: Attack Metrics
              Row {
                width: parent.width
                spacing: Style.space(6)

                Column {
                  width: (parent.width - Style.space(12)) / 3
                  spacing: Style.space(2)
                  Text { text: "POSSESSION"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.possession) ? root.selectedClubProfile.possession : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.favoriteTeamAccent; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 3
                  spacing: Style.space(2)
                  Text { text: "TOTAL SHOTS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.shotsPerGame) ? root.selectedClubProfile.shotsPerGame : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 3
                  spacing: Style.space(2)
                  Text { text: "SHOTS ON TARGET"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.shotsOnTarget) ? root.selectedClubProfile.shotsOnTarget : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
              }

              // Row 2: Distribution & Defense
              Row {
                width: parent.width
                spacing: Style.space(6)

                Column {
                  width: (parent.width - Style.space(12)) / 3
                  spacing: Style.space(2)
                  Text { text: "PASS ACCURACY"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.passPct) ? root.selectedClubProfile.passPct : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 3
                  spacing: Style.space(2)
                  Text { text: "CLEAN SHEETS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.cleanSheets) ? root.selectedClubProfile.cleanSheets : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 3
                  spacing: Style.space(2)
                  Text { text: "TACKLES WON"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.tackles) ? root.selectedClubProfile.tackles : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
              }

              // Divider
              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: Util.alpha(root.contentForeground, 0.06)
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.yellowCards !== undefined || root.selectedClubProfile.disciplinaryPoints !== undefined))
              }

              // Row 3: Disciplinary Standing
              Row {
                width: parent.width
                spacing: Style.space(4)
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.yellowCards !== undefined || root.selectedClubProfile.disciplinaryPoints !== undefined))

                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "YELLOWS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text {
                    text: (root.selectedClubProfile && root.selectedClubProfile.yellowCards !== undefined && root.selectedClubProfile.yellowCards !== "") ? String(root.selectedClubProfile.yellowCards) : "0"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: "#eab308"
                    font.family: root.contentFontFamily
                  }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "REDS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text {
                    text: (root.selectedClubProfile && root.selectedClubProfile.redCards !== undefined && root.selectedClubProfile.redCards !== "") ? String(root.selectedClubProfile.redCards) : "0"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: "#ef4444"
                    font.family: root.contentFontFamily
                  }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "FOULS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text {
                    text: (root.selectedClubProfile && root.selectedClubProfile.foulsCommitted !== undefined && root.selectedClubProfile.foulsCommitted !== "") ? String(root.selectedClubProfile.foulsCommitted) : "—"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                  }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "FAIR-PLAY"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text {
                    text: (root.selectedClubProfile && root.selectedClubProfile.disciplinaryPoints !== undefined && root.selectedClubProfile.disciplinaryPoints !== "") ? String(root.selectedClubProfile.disciplinaryPoints) : "0"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.favoriteTeamAccent
                    font.family: root.contentFontFamily
                  }
                }
              }
            }
          }

          // ==================== SQUAD TAB ====================
          // Squad Roster Segmented by Position Card
          Rectangle {
            width: parent.width
            height: squadRosterCol.implicitHeight + Style.space(18)
            radius: Style.cornerRadius
            color: Util.alpha(root.contentForeground, 0.035)
            border.width: Style.spacing.hairline
            border.color: Util.alpha(root.contentForeground, 0.08)
            visible: root.searchClubCardTab === "squad"

            Column {
              id: squadRosterCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Item {
                width: parent.width
                height: Style.space(14)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "SQUAD ROSTER"
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  font.letterSpacing: 0.5
                  color: Qt.darker(root.contentForeground, 1.3)
                  font.family: root.contentFontFamily
                }

                Text {
                  id: squadCountTxt
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: (root.activeSquadList() ? root.activeSquadList().length : 0) + " Players"
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  color: root.favoriteTeamAccent
                  font.family: root.contentFontFamily
                }
              }

              // Position filter segmented buttons: All | GK | DEF | MID | FWD
              Row {
                width: parent.width
                spacing: Style.space(4)

                Button {
                  height: Style.space(18)
                  fontSize: Style.space(8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: 0
                  text: "All (" + (root.selectedClubProfile && root.selectedClubProfile.rosterAll ? root.selectedClubProfile.rosterAll.length : 0) + ")"
                  selected: root.clubSquadPositionFilter === "all"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.clubSquadPositionFilter = "all"
                }
                Button {
                  height: Style.space(18)
                  fontSize: Style.space(8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: 0
                  text: "GK (" + (root.selectedClubProfile && root.selectedClubProfile.rosterGoalkeepers ? root.selectedClubProfile.rosterGoalkeepers.length : 0) + ")"
                  selected: root.clubSquadPositionFilter === "gk"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.clubSquadPositionFilter = "gk"
                }
                Button {
                  height: Style.space(18)
                  fontSize: Style.space(8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: 0
                  text: "DEF (" + (root.selectedClubProfile && root.selectedClubProfile.rosterDefenders ? root.selectedClubProfile.rosterDefenders.length : 0) + ")"
                  selected: root.clubSquadPositionFilter === "def"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.clubSquadPositionFilter = "def"
                }
                Button {
                  height: Style.space(18)
                  fontSize: Style.space(8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: 0
                  text: "MID (" + (root.selectedClubProfile && root.selectedClubProfile.rosterMidfielders ? root.selectedClubProfile.rosterMidfielders.length : 0) + ")"
                  selected: root.clubSquadPositionFilter === "mid"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.clubSquadPositionFilter = "mid"
                }
                Button {
                  height: Style.space(18)
                  fontSize: Style.space(8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: 0
                  text: "FWD (" + (root.selectedClubProfile && root.selectedClubProfile.rosterForwards ? root.selectedClubProfile.rosterForwards.length : 0) + ")"
                  selected: root.clubSquadPositionFilter === "fwd"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.clubSquadPositionFilter = "fwd"
                }
              }

              // Empty / loading indicator
              Text {
                width: parent.width
                text: root.searchClubRosterRequest && root.searchClubRosterRequest.running ? "Loading squad roster…" : "No players found in this category"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                color: Qt.darker(root.contentForeground, 1.6)
                visible: !root.activeSquadList() || root.activeSquadList().length === 0
              }

              // Player list repeater (clean rows, subtle hover highlight, no stacked gray boxes)
              Repeater {
                model: root.activeSquadList()
                delegate: Rectangle {
                  width: parent.width
                  height: Style.space(34)
                  radius: Style.cornerRadius
                  color: squadItemArea.containsMouse ? Util.alpha(root.contentForeground, 0.06) : "transparent"

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(6)
                    anchors.rightMargin: Style.space(6)
                    spacing: Style.space(8)

                    // Jersey # pill
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(20)
                      horizontalAlignment: Text.AlignHCenter
                      text: modelData.jersey && modelData.jersey !== "—" ? modelData.jersey : "—"
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      color: root.favoriteTeamAccent
                      font.family: root.contentFontFamily
                    }

                    // Headshot or fallback avatar
                    Item {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(24)
                      height: width

                      Image {
                        anchors.fill: parent
                        source: modelData.headshot || ""
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        smooth: true
                        visible: String(source) !== ""
                      }

                      Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(13)
                        color: Util.alpha(root.contentForeground, 0.25)
                        visible: !modelData.headshot || String(modelData.headshot) === ""
                      }
                    }

                    // Name & Position
                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Math.max(0, parent.width - Style.space(168))
                      spacing: Style.space(1)

                      Text {
                        width: parent.width
                        text: modelData.name
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        elide: Text.ElideRight
                      }

                      Text {
                        width: parent.width
                        text: modelData.position
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(8)
                        color: Qt.darker(root.contentForeground, 1.5)
                        elide: Text.ElideRight
                      }
                    }

                    // Nationality Flag & Country
                    Row {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(64)
                      spacing: Style.space(4)

                      Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(20)
                        height: Style.space(14)
                        source: modelData.flag || ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(80, 56)
                        mipmap: true
                        smooth: true
                        visible: String(source) !== ""
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Style.space(24)
                        text: modelData.country || ""
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(8)
                        color: Qt.darker(root.contentForeground, 1.6)
                        elide: Text.ElideRight
                      }
                    }

                    // Age badge
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(28)
                      horizontalAlignment: Text.AlignRight
                      text: modelData.age && modelData.age !== "—" ? (modelData.age + "y") : "—"
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.space(9)
                      color: Qt.darker(root.contentForeground, 1.45)
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: squadItemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.id && modelData.id !== "") {
                        if (root.selectedClubProfile) {
                          root.clubProfileHistory = root.selectedClubProfile
                        }
                        root.openPlayerSearchDetail({
                          id: modelData.id,
                          displayName: modelData.name,
                          subtitle: root.selectedClubProfile ? root.selectedClubProfile.displayName : "",
                          description: root.selectedClubProfile ? root.selectedClubProfile.leagueName : "",
                          image: modelData.headshot,
                          type: "player",
                          webUrl: ""
                        })
                      }
                    }
                  }
                }
              }
            }
          }

          // ==================== FIXTURES TAB ====================
          // Fixture Schedule Carousel (Upcoming Fixtures)
          Rectangle {
            width: parent.width
            height: fixturesCol.implicitHeight + Style.space(18)
            radius: Style.cornerRadius
            color: Util.alpha(root.contentForeground, 0.035)
            border.width: Style.spacing.hairline
            border.color: Util.alpha(root.contentForeground, 0.08)
            visible: root.searchClubCardTab === "fixtures"

            Column {
              id: fixturesCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Item {
                width: parent.width
                height: Style.space(18)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "UPCOMING FIXTURES"
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  font.letterSpacing: 0.5
                  color: Qt.darker(root.contentForeground, 1.3)
                  font.family: root.contentFontFamily
                }

                // Carousel navigation controls
                Row {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)
                  visible: root.selectedClubProfile && root.selectedClubProfile.upcomingFixtures && root.selectedClubProfile.upcomingFixtures.length > 1

                  Button {
                    height: Style.space(18)
                    width: Style.space(18)
                    iconText: ""
                    fontFamily: root.contentFontFamily
                    foreground: root.contentForeground
                    accent: root.contentForeground
                    fontSize: Style.space(8)
                    iconSize: Style.space(8)
                    horizontalPadding: 0
                    verticalPadding: 0
                    enabled: root.clubFixtureCarouselIndex > 0
                    opacity: enabled ? 1.0 : 0.4
                    onClicked: root.clubFixtureCarouselIndex = Math.max(0, root.clubFixtureCarouselIndex - 1)
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.clubFixtureCarouselIndex + 1) + " / " + (root.selectedClubProfile && root.selectedClubProfile.upcomingFixtures ? root.selectedClubProfile.upcomingFixtures.length : 1)
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                  }

                  Button {
                    height: Style.space(18)
                    width: Style.space(18)
                    iconText: ""
                    fontFamily: root.contentFontFamily
                    foreground: root.contentForeground
                    accent: root.contentForeground
                    fontSize: Style.space(8)
                    iconSize: Style.space(8)
                    horizontalPadding: 0
                    verticalPadding: 0
                    enabled: root.selectedClubProfile && root.selectedClubProfile.upcomingFixtures && root.clubFixtureCarouselIndex < root.selectedClubProfile.upcomingFixtures.length - 1
                    opacity: enabled ? 1.0 : 0.4
                    onClicked: root.clubFixtureCarouselIndex = Math.min((root.selectedClubProfile.upcomingFixtures.length - 1), root.clubFixtureCarouselIndex + 1)
                  }
                }
              }

              // Active Fixture Card
              Rectangle {
                width: parent.width
                height: activeFixtureCol.implicitHeight + Style.space(16)
                radius: Style.cornerRadius
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: !!root.activeClubFixture()

                Column {
                  id: activeFixtureCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(10)
                  spacing: Style.space(8)

                  // Header: Competition & Kickoff date/time
                  Item {
                    width: parent.width
                    height: Style.space(14)

                    Text {
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.activeClubFixture() ? root.activeClubFixture().competition.toUpperCase() : ""
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      font.letterSpacing: 0.5
                      color: root.favoriteTeamAccent
                      font.family: root.contentFontFamily
                      elide: Text.ElideRight
                      width: parent.width * 0.5
                    }

                    Text {
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.activeClubFixture() ? (root.activeClubFixture().date + (root.activeClubFixture().time !== "" ? (" · " + root.activeClubFixture().time) : "")) : ""
                      font.pixelSize: Style.space(9)
                      color: Qt.darker(root.contentForeground, 1.45)
                      font.family: root.contentFontFamily
                      elide: Text.ElideRight
                      width: parent.width * 0.5
                      horizontalAlignment: Text.AlignRight
                    }
                  }

                  // Matchup Layout (Home Crest + Name vs Away Name + Crest)
                  Row {
                    width: parent.width
                    spacing: Style.space(8)

                    // Home Team
                    Row {
                      anchors.verticalCenter: parent.verticalCenter
                      width: (parent.width - Style.space(38) - parent.spacing * 2) / 2
                      spacing: Style.space(6)

                      Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(24)
                        height: width
                        source: root.activeClubFixture() ? (root.activeClubFixture().homeLogo || "") : ""
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        smooth: true
                        visible: String(source) !== ""
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Style.space(30)
                        text: root.activeClubFixture() ? root.activeClubFixture().homeTeam : ""
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                      }
                    }

                    // Center VS pill badge
                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(38)
                      height: Style.space(18)
                      radius: Style.space(4)
                      color: Util.alpha(root.contentForeground, 0.06)

                      Text {
                        anchors.centerIn: parent
                        text: "VS"
                        font.pixelSize: Style.space(8)
                        font.bold: true
                        color: Qt.darker(root.contentForeground, 1.5)
                        font.family: root.contentFontFamily
                      }
                    }

                    // Away Team
                    Row {
                      anchors.verticalCenter: parent.verticalCenter
                      width: (parent.width - Style.space(38) - parent.spacing * 2) / 2
                      spacing: Style.space(6)

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Style.space(30)
                        horizontalAlignment: Text.AlignRight
                        text: root.activeClubFixture() ? root.activeClubFixture().awayTeam : ""
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                      }

                      Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(24)
                        height: width
                        source: root.activeClubFixture() ? (root.activeClubFixture().awayLogo || "") : ""
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        smooth: true
                        visible: String(source) !== ""
                      }
                    }
                  }

                  // Broadcast Channel Row
                  Row {
                    width: parent.width
                    spacing: Style.space(6)
                    visible: !!(root.activeClubFixture() && root.activeClubFixture().broadcast)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "󰢹"
                      font.family: "Symbols Nerd Font, " + root.contentFontFamily
                      font.pixelSize: Style.space(9)
                      color: root.favoriteTeamAccent
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "Broadcast: " + (root.activeClubFixture() ? root.activeClubFixture().broadcast : "")
                      font.pixelSize: Style.space(8)
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      elide: Text.ElideRight
                      width: parent.width - Style.space(20)
                    }
                  }
                }
              }

              // Empty Fixtures State
              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "No upcoming fixtures scheduled"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                color: Qt.darker(root.contentForeground, 1.6)
                visible: !root.activeClubFixture()
              }
            }
          }

          Button {
            width: parent.width
            height: Style.space(28)
            iconText: "󰖟"
            text: "View Official Clubhouse on ESPN"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            iconSize: Style.font.caption
            horizontalPadding: Style.space(12)
            verticalPadding: 0
            visible: !!(root.selectedClubProfile && root.selectedClubProfile.webUrl)
            onClicked: {
              if (root.selectedClubProfile && root.selectedClubProfile.webUrl) {
                Qt.openUrlExternally(root.selectedClubProfile.webUrl)
              }
            }
          }
        }
      }
    }
  }
}

  Column {
    id: matchDetailView
    visible: root.showMatchDetail
    width: parent.width
    spacing: Style.space(12)
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
          implicitHeight: Math.max(Style.space(260), matchDetailInnerCol.implicitHeight)
          height: implicitHeight

          Column {
            id: matchDetailInnerCol
            width: parent.width
            spacing: Style.space(12)
            opacity: (root.matchDetailLoading && !root.matchDetail) ? 0.15 : (root.matchDetailLoading ? 0.85 : 1.0)
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
              Item {
                id: homeScorerItem
                width: parent.width
                height: Math.max(Style.space(15), homeScorerRow.implicitHeight)
                readonly property bool isRed: String(modelData).indexOf("🟥") !== -1

                Row {
                  id: homeScorerRow
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(7)
                    height: Style.space(11)
                    radius: Style.space(1.5)
                    color: "#ef4444"
                    border.width: 1
                    border.color: "#b91c1c"
                    visible: homeScorerItem.isRed
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: String(modelData).replace(/🟥\s*/g, "").trim()
                    color: Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, homeScorerItem.width - (homeScorerItem.isRed ? Style.space(12) : 0))
                  }
                }
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
              Item {
                id: awayScorerItem
                width: parent.width
                height: Math.max(Style.space(15), awayScorerRow.implicitHeight)
                readonly property bool isRed: String(modelData).indexOf("🟥") !== -1

                Row {
                  id: awayScorerRow
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(7)
                    height: Style.space(11)
                    radius: Style.space(1.5)
                    color: "#ef4444"
                    border.width: 1
                    border.color: "#b91c1c"
                    visible: awayScorerItem.isRed
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: String(modelData).replace(/🟥\s*/g, "").trim()
                    color: Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, awayScorerItem.width - (awayScorerItem.isRed ? Style.space(12) : 0))
                  }
                }
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
          visible: root.matchDetail && root.matchDetail.started && root.matchDetailTab === "stats"

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
          visible: root.matchDetail && root.matchDetail.started && !root.matchDetail.isLive && root.matchDetailTab === "events"

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
          visible: root.matchDetail && root.matchDetail.isLive && root.matchDetailTab === "commentary"

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
          visible: root.matchDetail && root.matchDetailTab === "lineups"

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

          Column {
            id: lineupCol
            width: parent.width
            spacing: Style.space(8)
            visible: !!(root.matchDetail && root.matchDetail.lineups && root.matchDetail.lineups.available)

            // Tactical Pitch View
            Rectangle {
              id: pitchField
              width: parent.width
              height: Style.space(490)
              radius: Style.space(8)
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.025)
              clip: true
              border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
              border.width: 1

              // Subtle transparent zone stripes (6 alternating stripes)
              Column {
                anchors.fill: parent
                Repeater {
                  model: 6
                  Rectangle {
                    width: pitchField.width
                    height: pitchField.height / 6
                    color: index % 2 === 0 ? "transparent" : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.018)
                  }
                }
              }

              // Halfway line through the middle
              Rectangle {
                width: parent.width
                height: 1
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.15)
              }

              // Center circle
              Rectangle {
                width: Style.space(84)
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.15)
                border.width: 1
              }

              // Center spot
              Rectangle {
                width: 4
                height: 4
                radius: 2
                anchors.centerIn: parent
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.25)
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
                width: Style.space(170)
                height: Style.space(70)
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                border.width: 1
              }

              // Bottom goal area
              Rectangle {
                width: Style.space(80)
                height: Style.space(26)
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                border.width: 1
              }

              // Bottom penalty spot
              Rectangle {
                width: 4
                height: 4
                radius: 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(48)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.22)
              }

              // Bottom penalty arc
              Rectangle {
                width: Style.space(46)
                height: width
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(46)
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                border.width: 1
              }

              // Top penalty box
              Rectangle {
                width: Style.space(170)
                height: Style.space(70)
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                border.width: 1
              }

              // Top goal area
              Rectangle {
                width: Style.space(80)
                height: Style.space(26)
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                border.width: 1
              }

              // Top penalty spot
              Rectangle {
                width: 4
                height: 4
                radius: 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Style.space(48)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.22)
              }

              // Top penalty arc
              Rectangle {
                width: Style.space(46)
                height: width
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Style.space(46)
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
                  height: Style.space(56)
                  z: (pitchPlayerItem.modelData.goals > 0 || pitchPlayerItem.modelData.assists > 0 ? 30 : 10) + Math.round((1.0 - pitchPlayerItem.modelData.y) * 20)
                  x: (pitchField.width * pitchPlayerItem.modelData.x) - (width / 2)
                  y: (pitchField.height * pitchPlayerItem.modelData.y) - (jerseyContainer.height / 2)

                  // Main full-resolution athlete jersey image
                  Item {
                    id: jerseyContainer
                    width: Style.space(32)
                    height: Style.space(32)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Image {
                      id: playerJerseyImg
                      anchors.fill: parent
                      source: pitchPlayerItem.modelData.jerseyImage !== "" ? pitchPlayerItem.modelData.jerseyImage : ""
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true
                      cache: true
                      sourceSize.width: Style.space(64)
                      sourceSize.height: Style.space(64)
                      mipmap: true
                      smooth: true
                      visible: status === Image.Ready
                    }

                    // Fallback: when jersey image is not loaded or missing
                    Rectangle {
                      anchors.centerIn: parent
                      width: Style.space(24)
                      height: Style.space(24)
                      radius: Style.space(5)
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
                    height: Style.space(13)
                    width: ratingText.implicitWidth + Style.space(6)
                    radius: Style.space(3)
                    anchors.top: jerseyContainer.bottom
                    anchors.topMargin: -Style.space(3)
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
                    height: Style.space(14)
                    radius: Style.space(3)
                    color: Qt.rgba(0, 0, 0, 0.78)
                    border.color: Qt.rgba(1, 1, 1, 0.18)
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

        // H2H & Form Tab
        Column {
          width: parent.width
          spacing: Style.space(12)
          visible: root.matchDetail && root.matchDetailTab === "h2h"

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
          visible: (root.matchDetailTab === "info")

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
            active: root.matchDetailLoading && !root.matchDetail
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
            opacity: (root.standingsLoading && root.standings.length === 0) ? 0.15 : (root.standingsLoading ? 0.85 : 1.0)
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
            active: root.standingsLoading && root.standings.length === 0
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
            opacity: (root.statsLoading && root.statsGoals.length === 0 && root.statsAssists.length === 0 && root.statsYellow.length === 0) ? 0.15 : (root.statsLoading ? 0.85 : 1.0)
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
              root.loadStats(true)
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
              root.loadStats(true)
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
              root.loadStats(true)
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
            active: root.statsLoading && root.statsGoals.length === 0 && root.statsAssists.length === 0 && root.statsYellow.length === 0
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
            opacity: (root.loading && root.teamFixtureRows.length === 0) ? 0.15 : (root.loading ? 0.85 : 1.0)
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
        Item {
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
        visible: (root.leagueMode ? (!root.showStandings && !root.showStats && !root.showMatchDetail && !root.showSearch) : (root.showMatches && !root.showStandings && !root.showStats && !root.showMatchDetail && !root.showClubFixtures && !root.showSearch))

        Item {
          width: parent.width
          height: Math.max(Style.space(240), leagueMatchesInnerCol.implicitHeight)

          Column {
            id: leagueMatchesInnerCol
            width: parent.width
            spacing: Style.space(12)
            opacity: (root.matchListLoading && root.matchWeekRows.length === 0 && (root.leagueLive.length + root.leagueRecent.length + root.leagueUpcoming.length) === 0) ? 0.15 : (root.matchListLoading ? 0.85 : 1.0)
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
            { label: "Live Matches", rows: root.leagueLive },
            { label: "Recent Results", rows: root.leagueRecent },
            { label: "Scheduled Fixtures", rows: root.leagueUpcoming }
          ]

          delegate: Column {
            required property var modelData
            readonly property bool listIdle: root.matchListError === ""
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
            active: root.matchListLoading && root.matchWeekRows.length === 0 && (root.leagueLive.length + root.leagueRecent.length + root.leagueUpcoming.length) === 0
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
          opacity: (root.loading && !root.liveMatch && !root.nextMatch && !root.previousMatch) ? 0.15 : (root.loading ? 0.85 : 1.0)
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
            visible: root.liveHasGoals()
          }

          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.liveHasGoals()

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing) / 2
              text: root.liveGoalsFor("home")
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignLeft
              wrapMode: Text.WordWrap
            }

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing) / 2
              text: root.liveGoalsFor("away")
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
            visible: !root.liveHasGoals()
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
        visible: !root.customViewActive && !!root.nextMatch

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
        visible: !root.customViewActive && !!root.nextMatch

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
        visible: !root.customViewActive && !!root.nextMatch && !!root.previousMatch
      }

      Item {
        width: parent.width
        height: Style.space(20)
        visible: !root.customViewActive && !!root.previousMatch

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
        visible: !root.customViewActive && !!root.previousMatch

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
