import QtQuick
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
    if (!txt) return ({})
    try {
      var parsed = JSON.parse(txt)
      return parsed && typeof parsed === "object" ? parsed : ({})
    } catch (e) { return ({}) }
  }
  // The state file is authoritative: the shell's injected settings can be
  // stale at reload (it hands over the previous in-memory team before syncing
  // shell.json), so prefer the remembered favorite over settings.
  readonly property string teamName: String(root.savedFavorite.teamName !== undefined && root.savedFavorite.teamName !== ""
    ? root.savedFavorite.teamName : setting("teamName", ""))
  readonly property string league: String(root.savedFavorite.league !== undefined && root.savedFavorite.league !== ""
    ? root.savedFavorite.league : setting("league", ""))
  readonly property string teamId: String(root.savedFavorite.teamId !== undefined && root.savedFavorite.teamId !== ""
    ? root.savedFavorite.teamId : setting("teamId", ""))
  // Bar widgets expose their text color as barForeground. Using `foreground`
  // here resolves to an invalid (transparent) color on the popup.
  readonly property color contentForeground: bar ? bar.barForeground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  SequentialAnimation on _pulse {
    running: root.loading
    loops: Animation.Infinite
    NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutQuad }
    NumberAnimation { to: 0.0; duration: 450; easing.type: Easing.InOutQuad }
  }
  // First run: no team has been stored in shell.json yet. The manifest default
  // only feeds the settings UI, so an untouched widget has an undefined value.
  // A remembered favorite (the state file) counts as a team too.
  property bool needsTeam: root.settings
    ? (root.settings.teamName === undefined && root.savedFavorite.teamName === undefined)
    : true
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
    return String(root.teamName) + "|" + String(root.teamId) + "|" + String(root.league)
  }
  function ensureStarted() {
    if (root._started) return
    // Wait until the state file has actually been read (it is authoritative),
    // otherwise the injected (possibly stale) settings would win the race.
    if (!root._favoriteLoaded) return
    if (!root.hasRealTeam()) return
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

  // Reads the remembered favorite on startup.
  FileView {
    id: favoriteStore
    path: root.favoritePath
    printErrors: false
    onLoaded: { root.savedFavorite = root.parseFavorite(text()); root._favoriteLoaded = true }
    onLoadFailed: { root.savedFavorite = ({}); root._favoriteLoaded = true }
  }

  // The first read can race shell startup; one delayed reload self-corrects.
  Timer {
    interval: 1500
    running: true
    onTriggered: favoriteStore.reload()
  }

  // Persists the current favorite so it survives reloads as the fallback.
  Process {
    id: saveFavoriteProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var detail = String(text || "").trim()
        if (detail !== "") console.warn("futbar", "saveFavorite stderr:", detail)
      }
    }
  }
  function saveFavorite(teamName, league, teamId) {
    var name = teamName !== undefined ? teamName : root.teamName
    var lg = league !== undefined ? league : root.league
    var tid = teamId !== undefined ? teamId : (root.teamId !== "" ? root.teamId : root.resolvedTeamId)
    // Mirror into memory so the teamName/teamId bindings update instantly
    // instead of waiting for the next FileView read.
    root.savedFavorite = { teamName: name, league: lg, teamId: tid }
    var payload = JSON.stringify({ teamName: name, league: lg, teamId: tid })
    payload = payload.replace(/'/g, "'\\''")
    var dir = root.favoritePath.substring(0, root.favoritePath.lastIndexOf("/"))
    saveFavoriteProc.command = ["bash", "-c", "mkdir -p '" + dir + "' && printf '%s' '" + payload + "' > '" + root.favoritePath + "'"]
    saveFavoriteProc.running = true
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
  property var activityFlags: ({ started: false, halftime: false, fulltime: false })
  // False until the first summary poll has seeded the flags from the match's
  // current state, so enabling Live Activity mid-match never retro-reports
  // events that already happened.
  property bool activityInitialized: false
  // Last observed status state, so transitions like halftime→second half can
  // be detected.
  property string activityPrevState: ""
  property var activityEvents: []
  // League standings for the selected league, shown from the header button.
  property bool showStandings: false
  property bool standingsLoading: false
  property string standingsError: ""
  property string standingsGroupName: ""
  property var standings: []
  readonly property real standingsRowHeight: Style.space(28)
  readonly property real standingsStatWidth: Style.space(26)
  readonly property real standingsRankWidth: Style.space(24)
  readonly property real standingsRankGap: Style.space(10)
  readonly property real standingsLogoWidth: Style.space(16)
  // Table width tracks the panel's content area (which is narrower than the
  // requested card width once padding/border are applied), so the rightmost
  // columns (GD, Pts) are never clipped by the Flickable.
  readonly property real standingsRowWidth: root.content ? root.content.width : Style.space(390)
  readonly property real standingsTeamWidth: root.standingsRowWidth - root.standingsRankWidth - root.standingsRankGap - root.standingsLogoWidth - 8 * root.standingsStatWidth
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
  readonly property var leagues: [
    { value: "eng.1", label: "Premier League" },
    { value: "esp.1", label: "LaLiga" },
    { value: "ita.1", label: "Serie A" },
    { value: "ger.1", label: "Bundesliga" },
    { value: "fra.1", label: "Ligue 1" },
    { value: "ned.1", label: "Eredivisie" },
    { value: "por.1", label: "Primeira Liga" },
    { value: "sco.1", label: "Scottish Premiership" },
    { value: "bel.1", label: "Pro League" },
    { value: "tur.1", label: "Süper Lig" },
    { value: "usa.1", label: "MLS" },
    { value: "bra.1", label: "Brasileirão" },
    { value: "arg.1", label: "Liga Profesional" },
    { value: "mex.1", label: "Liga BBVA MX" },
    { value: "jpn.1", label: "J.League" },
    { value: "aus.1", label: "A-League Men" },
    { value: "uefa.champions", label: "Champions League" },
    { value: "uefa.europa", label: "Europa League" },
    { value: "eng.2", label: "Championship" },
    { value: "esp.2", label: "La Liga 2" },
    { value: "ger.2", label: "2. Bundesliga" },
    { value: "ita.2", label: "Serie B" },
    { value: "fra.2", label: "Ligue 2" }
  ]
  property string selectedLeague: ""
  property string selectedLeagueName: ""
  property var selectedTeam: null
  // Reopens the first-run picker after setup so the favorite team can change.
  property bool editingTeam: false

  function open() {
    // Always start on the fixtures view; the standings table is a toggle.
    root.showStandings = false
    root.controller.show()
    // Cached fixtures are shown instantly; only refetch when they are stale
    // or nothing has been fetched yet. The refresh never clears what is on
    // screen, so the UI is never blocked while it runs.
    if (!root.fixtureFresh()) root.refresh()
  }

  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }

  // Fixture data is considered fresh until its TTL expires: 10 minutes when a
  // fixture involving the team falls on today, 30 minutes otherwise.
  function fixtureTtl() {
    var today = Qt.formatDate(new Date(), "yyyyMMdd")
    var candidates = [root.nextMatch, root.previousMatch, root.liveMatch]
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
  }

  function refresh() {
    if (root.needsTeam) return
    // Never fetch (or run teams-resolution/persist) before the startup gate
    // has seen the team inputs settle, otherwise a reload's stale settings
    // injection would be fetched and re-persisted as the fallback.
    if (!root._started) { root.ensureStarted(); return }
    var key = root.fixtureTeamKey()
    if (key !== root._fixtureTeamKey) {
      root._fixtureTeamKey = key
      // A pipeline already in flight targets the new team (its id is resolved
      // before the fetch starts), so only reset when it is idle.
      if (fixtureRequest.running) return
      root.resetTeamData()
    }
    if (fixtureRequest.running) return
    loading = true
    requestError = ""
    collectedEvents = []
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
    var window = root.rangeDate(-120) + "-" + root.rangeDate(60)
    var team = root.resolvedTeamId !== "" ? root.resolvedTeamId : root.teamId
    if (next.kind === "teams") {
      fixtureRequest.command = ["curl", "-fsSL", "--max-time", "10",
        "https://site.api.espn.com/apis/site/v2/sports/soccer/" + root.league + "/teams"]
    } else if (next.kind === "discover") {
      fixtureRequest.command = ["curl", "-fsSL", "--max-time", "10",
        "https://sports.core.api.espn.com/v2/sports/soccer/teams/" + team + "/events?dates=" + window + "&limit=100"]
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
          var slug = root.scoreboardQueue.shift()
          root.sbSlugs[i] = slug
          var window = root.rangeDate(-120) + "-" + root.rangeDate(60)
          procs[i].command = ["curl", "-fsSL", "--max-time", "10",
            "https://site.api.espn.com/apis/site/v2/sports/soccer/" + slug + "/scoreboard?dates=" + window + "&limit=500"]
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
    try {
      var data = JSON.parse(text)
      var leagues = Array.isArray(data.leagues) ? data.leagues : []
      if (leagues.length > 0 && slug !== "") {
        var info = {}
        info.name = String(leagues[0].name || leagues[0].abbreviation || slug)
        info.logo = leagues[0].logos && leagues[0].logos.length ? String(leagues[0].logos[0].href || "") : ""
        var map = root.leagueInfo
        map[slug] = info
        root.leagueInfo = map
      }
      var merged = root.collectedEvents.slice()
      var events = Array.isArray(data.events) ? data.events : []
      for (var e = 0; e < events.length; e++) {
        if (!root.eventMatchesTeam(events[e])) continue
        var dup = merged.some(function(ev) { return String(ev.id) === String(events[e].id) })
        if (dup) continue
        if (events[e].competitionSlug === undefined) events[e].competitionSlug = slug
        merged.push(events[e])
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
    if (info && info.name) return String(info.name)
    if (slug === "") return root.leagueLabel()
    return slug
  }

  function competitionLogoFor(event) {
    var slug = event ? String(event.competitionSlug || "") : ""
    var info = root.competitionInfo(slug)
    return info && info.logo ? String(info.logo) : ""
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

    // ESPN reports a match as `pre` until moments after kickoff. A scheduled
    // event whose kickoff just passed is therefore treated as in-play so it
    // does not vanish between kickoff and ESPN flipping it to `in`.
    var nowMs = now
    var inPlay = events.filter(function(event) {
      if (event.status && event.status.type.state === "in") return true
      if (event.status && event.status.type.state === "pre") {
        var ms = new Date(event.date).getTime()
        return ms <= nowMs && nowMs - ms <= 3 * 3600 * 1000
      }
      return false
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
    var item = competitor(event, side)
    return item && item.team ? String(item.team.shortDisplayName || item.team.displayName || "—") : "—"
  }

  function teamLogoFor(event, side) {
    var item = competitor(event, side)
    return item && item.team ? String(item.team.logo || "") : ""
  }

  function scoreFor(event, side) {
    var item = competitor(event, side)
    return item ? String(item.score || "0") : "—"
  }

  function kickoffDay(event) {
    return event ? Qt.formatDate(new Date(event.date), "ddd d MMM") : ""
  }

  function kickoffTime(event) {
    return event ? Qt.formatTime(new Date(event.date), "HH:mm") : ""
  }

  function statusFor(event) {
    var status = event && event.status
    return status && status.type ? String(status.type.shortDetail || status.type.detail || "Full time") : "Full time"
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
    var id = String(root.liveMatch.id)
    if (root.summaryMatchId !== id) {
      root.liveEvents = []
      root.summaryMatchId = id
    }
    if (panelSummaryRequest.running) return
    var slug = String(root.liveMatch.competitionSlug || root.league)
    panelSummaryRequest.command = ["curl", "-fsSL", "--max-time", "10",
      "https://site.api.espn.com/apis/site/v2/sports/soccer/" + slug + "/summary?event=" + id]
    panelSummaryRequest.running = true
  }

  // Fetches the league standings table for the selected league. ESPN's site
  // API has no standings children for soccer; the web API does.
  function loadStandings() {
    if (root.needsTeam) return
    if (standingsRequest.running) return
    standingsLoading = true
    standingsError = ""
    standingsRequest.command = ["curl", "-fsSL", "--max-time", "10",
      "https://site.web.api.espn.com/apis/v2/sports/soccer/" + root.league + "/standings"]
    standingsRequest.running = true
  }

  function statFor(stats, name) {
    var value = stats && stats[name]
    return value !== undefined && value !== null ? String(value) : "0"
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
        minute: String((e.clock && e.clock.displayValue) || "").replace("'", ""),
        player: String(person.displayName || person.shortName || "?"),
        teamName: String(team.displayName || team.shortName || ""),
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
      out.push(prefix + (minute !== "" ? minute + " " : "") + events[i].player + (events[i].own ? " (og)" : "") + (events[i].penalty ? " (P)" : ""))
    }
    return out.join("\n")
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
    return parts.join("\n")
  }

  // Sends a desktop notification through the freedesktop daemon the shell
  // runs, which the omarchy notifications service renders as a popup.
  function notify(title, body) {
    if (!title) return
    notifyRequest.command = ["notify-send", "-a", "futbar", "-i", "dialog-information",
      String(title), String(body || "")]
    notifyRequest.running = true
  }

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
    var key = root.liveActivityKey(event)
    if (root.activityEvents.indexOf(key) !== -1) return
    root.activityEvents = root.activityEvents.concat([key])
  }

  function activityAlreadySeen(event) {
    return root.activityEvents.indexOf(root.liveActivityKey(event)) !== -1
  }

  // Pulls the live match's summary and fires notifications for anything new.
  function pollLiveActivity() {
    if (!root.liveActivity) return
    if (!root.liveMatch) {
      root.stopLiveActivity()
      return
    }
    var id = String(root.liveMatch.id)
    if (root.activityMatchId !== id) {
      // A different match went live while activity was on: start tracking it
      // cleanly, so its start/goals are reported from scratch.
      root.activityMatchId = id
      root.activityFlags = { started: false, halftime: false, fulltime: false }
      root.activityInitialized = false
      root.activityEvents = []
    }
    if (activityRequest.running) return
    var slug = String(root.liveMatch.competitionSlug || root.league)
    activityRequest.command = ["curl", "-fsSL", "--max-time", "10",
      "https://site.api.espn.com/apis/site/v2/sports/soccer/" + slug + "/summary?event=" + id]
    activityRequest.running = true
  }

  function startLiveActivity() {
    root.liveActivity = true
    root.activityMatchId = ""
    root.activityFlags = { started: false, halftime: false, fulltime: false }
    root.activityInitialized = false
    root.activityEvents = []
    activityPollTimer.start()
    root.pollLiveActivity()
  }

  function stopLiveActivity() {
    root.liveActivity = false
    activityPollTimer.stop()
  }

  // "Barcelona 2–0 Al Ahly" for the current live match.
  function scoreText() {
    return root.teamNameFor(root.liveMatch, "home") + " " + root.scoreFor(root.liveMatch, "home")
      + "–" + root.scoreFor(root.liveMatch, "away") + " " + root.teamNameFor(root.liveMatch, "away")
  }

  // "Barcelona 2–0" — the score without the away team name, used for cards.
  function shortScoreText() {
    return root.teamNameFor(root.liveMatch, "home") + " " + root.scoreFor(root.liveMatch, "home")
      + "–" + root.scoreFor(root.liveMatch, "away")
  }

  // "1st half" / "2nd half" etc. from the summary's status type.
  function periodLabel(typeObj) {
    var desc = String(typeObj && typeObj.description || "")
    if (desc.indexOf("First Half") !== -1) return "1st half"
    if (desc.indexOf("Second Half") !== -1) return "2nd half"
    if (desc.indexOf("Half") !== -1) return "half time"
    if (desc.indexOf("Overtime") !== -1) return "overtime"
    if (desc.indexOf("Penalty Shootout") !== -1) return "penalty shootout"
    var detail = String(typeObj && (typeObj.shortDetail || typeObj.detail) || "")
    return detail !== "" ? detail : "in progress"
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
      if (state === "hal") {
        root.activityFlags.started = true
        root.activityFlags.halftime = true
      } else if (state === "post") {
        root.activityFlags.started = true
        root.activityFlags.halftime = true
        root.activityFlags.fulltime = true
      } else if (state === "in") {
        root.activityFlags.started = true
      }
      root.activityPrevState = state
      var existing = Array.isArray(data.keyEvents) ? data.keyEvents : []
      for (var k = 0; k < existing.length; k++) root.activityMarkSeen(existing[k])
      return
    }

    // The second half began: the match left the half-time period back into
    // play.
    if (root.activityPrevState === "hal" && state === "in") {
      root.notify("Second Half Started", root.scoreText() + " · " + root.periodLabel(status.type))
    }

    // A match is "pre" until moments after kickoff, so reaching any later
    // state without having announced the start is the start.
    if (!root.activityFlags.started && state !== "" && state !== "pre") {
      root.activityFlags.started = true
      root.notify("Match Started",
        root.teamNameFor(root.liveMatch, "home") + " vs " + root.teamNameFor(root.liveMatch, "away")
          + " · " + root.periodLabel(status.type))
    }

    if (!root.activityFlags.halftime && state === "hal") {
      root.activityFlags.halftime = true
      root.notify("Half Time", root.scoreText() + " (HT)")
    }

    if (!root.activityFlags.fulltime && state === "post") {
      root.activityFlags.fulltime = true
      root.notify("Full Time", root.scoreText() + " (FT)")
      activityPollTimer.stop()
      return
    }

    var events = Array.isArray(data.keyEvents) ? data.keyEvents : []
    for (var i = 0; i < events.length; i++) {
      var e = events[i]
      if (root.activityAlreadySeen(e)) continue
      var t = String(e.type && e.type.text || "")
      var minute = String(e.clock && e.clock.displayValue || "").replace("'", "")
      var players = e.athletesInvolved || e.participants || []
      var team = e.team || (players[0] && players[0].team) || {}
      var teamName = String(team.displayName || team.shortName || "")
      var score = root.scoreText()

      if (root.isGoalEvent(e)) {
        if (!players.length) { root.activityMarkSeen(e); continue }
        var first = players[0]
        var person = first.athlete || first
        var playerName = String(person.displayName || "?")
        root.activityMarkSeen(e)
        if (root.isPenaltyEvent(e)) {
          root.notify("Penalty — " + teamName, (minute !== "" ? minute + "' · " : "") + score)
        } else {
          root.notify("Goal — " + playerName, (minute !== "" ? minute + "' · " : "") + score)
        }
      } else if (t.indexOf("Yellow Card") !== -1 || t.indexOf("Red Card") !== -1) {
        if (!players.length) { root.activityMarkSeen(e); continue }
        var cardFirst = players[0]
        var cardPerson = cardFirst.athlete || cardFirst
        var cardName = String(cardPerson.displayName || "?")
        var cardKind = t.indexOf("Yellow") !== -1 ? "Yellow Card" : "Red Card"
        var parts = []
        if (minute !== "") parts.push(minute + "'")
        if (teamName !== "") parts.push(teamName)
        parts.push(root.shortScoreText())
        root.activityMarkSeen(e)
        root.notify(cardKind + " — " + cardName, parts.join(" · "))
      } else {
        root.activityMarkSeen(e)
      }
    }

    root.activityPrevState = state
  }

  // Fetch only once a real team is available. The widget stays idle until the
  // user picks a club in the first-run picker and presses Confirm, or until the
  // saved settings / remembered favorite arrive.
  Component.onCompleted: root.ensureStarted()
  onSavedFavoriteChanged: root.ensureStarted()
  // Leaving the picker without confirming keeps the previous team in place.
  onOpenedChanged: if (!root.opened) root.editingTeam = false
  // A team change lands as a sequence of setting updates (name, league, id),
  // so refresh from each; the guard inside refresh() coalesces them into a
  // single fetch that always targets the newly selected club.
  onTeamNameChanged: root.refresh()
  onTeamIdChanged: root.refresh()
  onResolvedTeamIdChanged: root.refresh()
  // Refresh the table after the team picker changes the league.
  onLeagueChanged: { root.refresh(); if (root.opened && root.showStandings) root.loadStandings() }

  // Live Activity polling: check the summary for new events while the user
  // has notifications enabled and a match is in play.
  Timer {
    id: activityPollTimer
    interval: 30000
    repeat: true
    onTriggered: root.pollLiveActivity()
  }

  // Persists the user's club choice through the shell IPC, which writes
  // shell.json and patches the running widget's settings in place. After that
  // needsTeam flips to false and the fixtures take over.
  function selectLeague(code) {
    if (code === "") return
    var match = null
    for (var i = 0; i < leagues.length; i++) {
      if (leagues[i].value === code) { match = leagues[i]; break }
    }
    selectedLeague = code
    selectedLeagueName = match ? String(match.label) : code
    teams = []
    selectedTeam = null
    if (!teamsRequest.running) teamsRequest.running = true
  }

  function selectTeam(name) {
    if (name === "") return
    for (var i = 0; i < teams.length; i++) {
      if (String(teams[i].value) === name) { selectedTeam = teams[i]; break }
    }
  }

  function confirmTeam() {
    if (!selectedTeam) return
    root.editingTeam = false
    root.resolvedTeamId = String(selectedTeam.id || "")
    root.saveFavorite(String(selectedTeam.value), String(selectedLeague), String(selectedTeam.id || ""))
    setTeamRequest.command = ["bash", "-c",
      "omarchy shell shell setBarWidget '" + root.moduleName + "' teamName '" + JSON.stringify(String(selectedTeam.value))
      + "' '{}' && omarchy shell shell setBarWidget '" + root.moduleName + "' league '" + JSON.stringify(String(selectedLeague))
      + "' '{}' && omarchy shell shell setBarWidget '" + root.moduleName + "' teamId '" + JSON.stringify(String(selectedTeam.id || "")) + "' '{}'"]
    setTeamRequest.running = true
  }

  // Stores a team id resolved from the /teams list when the team was set
  // through the generic settings UI rather than the picker.
  function persistTeamId(id) {
    if (id === "") return
    root.saveFavorite(undefined, undefined, id)
    setTeamRequest.command = ["bash", "-c",
      "omarchy shell shell setBarWidget '" + root.moduleName + "' teamId '" + JSON.stringify(id) + "' '{}'"]
    setTeamRequest.running = true
  }

  function leagueLabel() {
    for (var i = 0; i < leagues.length; i++) {
      if (leagues[i].value === root.league) return String(leagues[i].label)
    }
    return root.league
  }

  // Loads the current league's club list and shows the picker for editing.
  function openTeamPicker() {
    root.editingTeam = true
    root.selectedLeague = root.league
    root.selectedLeagueName = root.leagueLabel()
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
              root.resolvedTeamId = String(found.id || "")
              root.persistTeamId(root.resolvedTeamId)
              root.buildFetchQueue()
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
              if (m && slugs.indexOf(m[1]) === -1) slugs.push(m[1])
            }
            if (slugs.length === 0) slugs.push(root.league)
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
      onStreamFinished: {
        var detail = String(text || "").trim()
        if (detail !== "") console.warn("futbar", detail)
      }
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
      onStreamFinished: {
        var detail = String(text || "").trim()
        if (detail !== "") console.warn("futbar", detail)
      }
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
      onStreamFinished: {
        var detail = String(text || "").trim()
        if (detail !== "") console.warn("futbar", detail)
      }
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
      onStreamFinished: {
        var detail = String(text || "").trim()
        if (detail !== "") console.warn("futbar", detail)
      }
    }
  }

  Process {
    id: panelSummaryRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.liveEvents = Array.isArray(data.keyEvents) ? data.keyEvents : []
        } catch (error) {
          root.liveEvents = []
          console.warn("futbar", "summary: " + error)
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var detail = String(text || "").trim()
        if (detail !== "") console.warn("futbar", "summary: " + detail)
      }
    }
  }

  Process {
    id: activityRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
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
        var detail = String(text || "").trim()
        if (detail !== "") console.warn("futbar", "activity: " + detail)
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
        try {
          var data = JSON.parse(text)
          var children = data.children || []
          var entries = []
          var name = ""
          for (var c = 0; c < children.length; c++) {
            var standing = children[c].standings || {}
            entries = standing.entries || []
            name = String(children[c].name || "")
            if (entries.length) break
          }
          root.standingsGroupName = name
          root.standings = entries.map(function(entry, index) {
            var team = entry.team || {}
            var stats = {}
            var list = entry.stats || []
            for (var s = 0; s < list.length; s++) {
              var item = list[s]
              if (!item) continue
              var key = String(item.name || "")
              if (key !== "") stats[key] = item.displayValue !== undefined && item.displayValue !== null ? String(item.displayValue) : "0"
            }
            var rankVal = stats.rank
            if (rankVal === undefined || rankVal === "") {
              var noteRank = entry.note && entry.note.rank
              rankVal = noteRank !== undefined && noteRank !== null ? String(noteRank) : String(index + 1)
            }
            return {
              rank: String(rankVal),
              teamName: String(team.displayName || team.name || "—"),
              teamId: String(team.id || ""),
              logo: team.logos && team.logos[0] ? String(team.logos[0].href || "") : "",
              note: entry.note || null,
              stats: stats
            }
          })
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
    id: teamsRequest
    // Fetched per league when the user picks one in the first-run picker.
    command: ["curl", "-fsSL", "--max-time", "10",
      "https://site.api.espn.com/apis/site/v2/sports/soccer/" + root.selectedLeague + "/teams"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          var leagues = data.sports && data.sports[0] && data.sports[0].leagues || []
          var list = (leagues[0] && leagues[0].teams) || []
          root.teams = list.map(function(entry) {
            var team = entry.team || {}
            var name = String(team.displayName || team.name || "")
            // The /teams endpoint nests logos in a `logos[]` array rather than
            // the single `logo` string the scoreboard uses.
            var logo = String(team.logo || "")
            if (logo === "" && team.logos && team.logos[0]) logo = String(team.logos[0].href || "")
            return name === "" ? null : { value: name, label: name, logo: logo, id: String(team.id || "") }
          }).filter(function(item) { return item !== null })
          if (root.editingTeam) {
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
        var detail = String(text || "").trim()
        if (detail !== "") console.warn("futbar", "team list: " + detail)
      }
    }
  }

  Process {
    id: setTeamRequest
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { /* setBarWidget output is not needed */ }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var error = String(text || "").trim()
        if (error !== "") console.warn("futbar", "team select failed: " + error)
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

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

      Column {
        visible: root.needsTeam || root.editingTeam
        width: parent.width
        spacing: Style.space(14)

        Text {
          text: root.editingTeam ? "Change your club" : "Choose your club"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Dropdown {
          id: leagueDropdown
          width: parent.width
          label: "League"
          fontFamily: root.contentFontFamily
          options: root.leagues
          value: root.selectedLeague
          onChanged: function(value) { root.selectLeague(value) }
        }

        Dropdown {
          id: teamDropdown
          width: parent.width
          label: root.teamsLoading ? "Loading clubs…" : "Club"
          fontFamily: root.contentFontFamily
          options: root.teams
          value: root.selectedTeam ? String(root.selectedTeam.value) : ""
          enabled: root.selectedLeague !== ""
          onChanged: function(value) { root.selectTeam(value) }
        }

        Row {
          visible: root.selectedTeam
          width: parent.width
          height: Style.space(48)
          spacing: Style.space(12)

          Image {
            width: Style.space(40)
            height: width
            source: root.selectedTeam ? root.selectedTeam.logo : ""
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 40
            sourceSize.height: 40
            smooth: true
            anchors.verticalCenter: parent.verticalCenter
            visible: source !== ""
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              text: root.selectedTeam ? String(root.selectedTeam.value) : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Text {
              text: root.selectedLeagueName
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        Button {
          visible: root.selectedTeam
          width: parent.width
          text: "Confirm"
          fontFamily: root.contentFontFamily
          foreground: root.contentForeground
          accent: root.contentForeground
          onClicked: root.confirmTeam()
        }
      }

      Column {
        visible: !root.needsTeam && !root.editingTeam
        width: parent.width
        spacing: Style.space(14)

        Row {
          width: parent.width
          spacing: Style.space(10)

        Image {
          id: tournamentLogoImage
          width: Style.space(36)
          height: width
          source: root.tournamentLogo
          fillMode: Image.PreserveAspectFit
          sourceSize.width: 36
          sourceSize.height: 36
          smooth: true
          visible: source !== ""
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - (tournamentLogoImage.visible ? tournamentLogoImage.width + parent.spacing : 0)
            - (standingsButton.visible ? standingsButton.width + parent.spacing : 0)
            - (changeTeamButton.visible ? changeTeamButton.width + parent.spacing : 0)
          text: root.tournamentName || root.leagueLabel()
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
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
            root.showStandings = !root.showStandings
            if (root.showStandings) root.loadStandings()
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
          onClicked: root.openTeamPicker()
        }
      }

      Rectangle {
        width: parent.width
        height: Style.spacing.hairline
        color: root.contentForeground
        opacity: 0.15
      }

      Column {
        width: parent.width
        spacing: Style.space(12)
        visible: root.showStandings

        Text {
          width: parent.width
          text: root.standingsLoading ? "Loading standings…"
            : (root.standingsError !== "" ? "Could not load standings"
            : (root.standingsGroupName !== "" ? root.standingsGroupName : root.leagueLabel()))
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Text {
          width: parent.width
          text: root.standingsError
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          visible: root.standingsError !== ""
        }

        Flickable {
          width: parent.width
          height: Math.min(headerRow.implicitHeight + root.standings.length * standingsRowHeight, Style.space(520))
          clip: true
          interactive: contentHeight > height
          contentHeight: headerRow.implicitHeight + root.standings.length * standingsRowHeight
          visible: !root.standingsLoading && root.standingsError === "" && root.standings.length > 0

          Column {
            width: parent.width
            spacing: 0

            Row {
              id: headerRow
              width: parent.width
              height: Style.space(26)
              Text { width: standingsRankWidth; height: parent.height; text: "#"; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
              Item { width: standingsRankGap; height: 1 }
              Item { width: standingsLogoWidth; height: 1 }
              Text { width: standingsTeamWidth; height: parent.height; text: "Team"; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true; verticalAlignment: Text.AlignVCenter }
              Repeater {
                model: root.standingsColumns
                Text {
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
                    sourceSize.width: 16; sourceSize.height: 16
                    smooth: true
                    visible: rowRect.entry.logo !== ""
                  }
                  Text {
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
          visible: !root.standingsLoading && root.standingsError === "" && root.standings.length > 0 && root.standingsLegend.length > 0
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
                text: modelData.label
                color: Qt.darker(root.contentForeground, 1.8)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        Text {
          width: parent.width
          text: "Standings refresh when opened."
          color: Qt.darker(root.contentForeground, 1.8)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          visible: !root.standingsLoading && root.standingsError === "" && root.standings.length > 0
        }
      }

      Item {
        width: parent.width
        height: Style.space(20)
        visible: root.liveMatch && !root.showStandings

        Text {
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
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.statusFor(root.liveMatch)
          color: "#4ade80"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Item {
        width: parent.width
        height: liveColumn.implicitHeight
        visible: root.liveMatch

        Column {
          id: liveColumn
          width: Style.space(348)
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(4)

          Button {
            anchors.horizontalCenter: parent.horizontalCenter
            iconText: root.liveActivity ? "󰂢" : "󰂣"
            text: "Live Activity"
            tooltipText: root.liveActivity ? "Stop match notifications" : "Notify on goals, cards, half-time and full-time"
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
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            spacing: Style.space(8)

            Image { width: Style.space(44); height: width; source: root.teamLogoFor(root.liveMatch, "home"); fillMode: Image.PreserveAspectFit; sourceSize.width: 44; sourceSize.height: 44; smooth: true; anchors.verticalCenter: parent.verticalCenter; visible: source !== "" }
            Text { width: Style.space(76); anchors.verticalCenter: parent.verticalCenter; text: root.teamNameFor(root.liveMatch, "home"); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft }
            Text {
              width: Style.space(86)
              anchors.verticalCenter: parent.verticalCenter
              horizontalAlignment: Text.AlignHCenter
              text: root.scoreFor(root.liveMatch, "home") + " – " + root.scoreFor(root.liveMatch, "away")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text { width: Style.space(76); anchors.verticalCenter: parent.verticalCenter; text: root.teamNameFor(root.liveMatch, "away"); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; horizontalAlignment: Text.AlignLeft; elide: Text.ElideRight }
            Image { width: Style.space(44); height: width; source: root.teamLogoFor(root.liveMatch, "away"); fillMode: Image.PreserveAspectFit; sourceSize.width: 44; sourceSize.height: 44; smooth: true; anchors.verticalCenter: parent.verticalCenter; visible: source !== "" }
          }

          Item {
            width: 1
            height: Style.space(10)
          }

          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.liveHasDetails()

            Text {
              width: (parent.width - parent.spacing) / 2
              text: root.liveDetailsFor("home")
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignLeft
              wrapMode: Text.WordWrap
            }

            Text {
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
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(5)
            Image { id: competitionLogo; width: Style.space(14); height: width; source: root.competitionLogoFor(root.liveMatch); fillMode: Image.PreserveAspectFit; sourceSize.width: 14; sourceSize.height: 14; smooth: true; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 2; visible: source !== "" }
            Text {
              text: root.competitionNameFor(root.liveMatch)
              anchors.verticalCenter: competitionLogo.verticalCenter
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
        // Only separate the live card from the next card; without a live match
        // the header's own hairline is the single separator at the top.
        visible: root.liveMatch && !root.showStandings
      }

      Item {
        width: parent.width
        height: Style.space(20)
        visible: !root.showStandings

        Text {
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
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.kickoffDay(root.nextMatch) + " · " + root.kickoffTime(root.nextMatch)
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Item {
        width: parent.width
        height: Style.space(86)
        visible: !root.showStandings

        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(320)
            spacing: Style.space(8)

            Image { width: Style.space(36); height: width; source: root.teamLogoFor(root.nextMatch, "home"); fillMode: Image.PreserveAspectFit; sourceSize.width: 36; sourceSize.height: 36; smooth: true; anchors.verticalCenter: parent.verticalCenter; visible: source !== "" }
            Text { width: Style.space(72); anchors.verticalCenter: parent.verticalCenter; text: root.teamNameFor(root.nextMatch, "home"); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft }
            Text { width: Style.space(72); anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignHCenter; text: "vs"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
            Text { width: Style.space(72); anchors.verticalCenter: parent.verticalCenter; text: root.teamNameFor(root.nextMatch, "away"); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; horizontalAlignment: Text.AlignLeft; elide: Text.ElideRight }
            Image { width: Style.space(36); height: width; source: root.teamLogoFor(root.nextMatch, "away"); fillMode: Image.PreserveAspectFit; sourceSize.width: 36; sourceSize.height: 36; smooth: true; anchors.verticalCenter: parent.verticalCenter; visible: source !== "" }
          }

          Item {
            width: 1
            height: Style.space(10)
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(5)
            Image { width: Style.space(18); height: width; source: root.competitionLogoFor(root.nextMatch); fillMode: Image.PreserveAspectFit; sourceSize.width: 18; sourceSize.height: 18; smooth: true; anchors.verticalCenter: parent.verticalCenter; visible: source !== "" }
            Text {
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
      }

      Item {
        width: parent.width
        height: Style.space(20)
        visible: !root.showStandings

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "PREVIOUS MATCH"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        Image {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(20)
          height: width
          source: root.competitionLogoFor(root.previousMatch)
          fillMode: Image.PreserveAspectFit
          sourceSize.width: 20
          sourceSize.height: 20
          smooth: true
          visible: source !== ""
        }
      }

      Item {
        width: parent.width
        height: Style.space(86)
        visible: !root.showStandings

        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(320)
            spacing: Style.space(8)
            Image { width: Style.space(36); height: width; source: root.teamLogoFor(root.previousMatch, "home"); fillMode: Image.PreserveAspectFit; sourceSize.width: 36; sourceSize.height: 36; smooth: true; anchors.verticalCenter: parent.verticalCenter; visible: source !== "" }
            Text { width: Style.space(72); anchors.verticalCenter: parent.verticalCenter; text: root.teamNameFor(root.previousMatch, "home"); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft }
            Text { width: Style.space(72); anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignHCenter; text: root.scoreFor(root.previousMatch, "home") + " – " + root.scoreFor(root.previousMatch, "away"); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
            Text { width: Style.space(72); anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignLeft; text: root.teamNameFor(root.previousMatch, "away"); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
            Image { width: Style.space(36); height: width; source: root.teamLogoFor(root.previousMatch, "away"); fillMode: Image.PreserveAspectFit; sourceSize.width: 36; sourceSize.height: 36; smooth: true; anchors.verticalCenter: parent.verticalCenter; visible: source !== "" }
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(5)
            Image { width: Style.space(18); height: width; source: root.competitionLogoFor(root.previousMatch); fillMode: Image.PreserveAspectFit; sourceSize.width: 18; sourceSize.height: 18; smooth: true; anchors.verticalCenter: parent.verticalCenter; visible: source !== "" }
            Text {
              text: root.competitionNameFor(root.previousMatch)
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      Text {
        visible: !root.showStandings && (root.loading || root.requestError !== "" || (!root.nextMatch && !root.previousMatch))
        opacity: root.loading ? 0.4 + 0.6 * root._pulse : 1.0
        text: root.loading ? "Loading fixtures…" : (root.requestError !== "" ? root.requestError : "No fixtures found for " + root.teamName)
        color: Qt.darker(root.contentForeground, 1.5)
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
}
}
