import QtQuick
import Quickshell.Io
import "../components"
import "../services/FutNetwork.js" as FutNetwork

// Fixture model is exposed through the root facade; this component owns its fetch pipeline.
Item {
  visible: false
  property var root: null
  readonly property var fixtureRequest: internalFixtureRequest
  readonly property var sbRequest1: internalSbRequest1
  readonly property var sbRequest2: internalSbRequest2
  readonly property var sbRequest3: internalSbRequest3

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
    } else if (root.scoreboardsRunning()) {
      // A fetch cycle is already in flight: let it finish.
      return
    }
    if (root.collectedEvents.length === 0) {
      root.loading = true
    }
    root.requestError = ""
    root.fixtureCycleReceived = false
    // Cancel in-flight requests to prevent stalls and start fresh
    internalFixtureRequest.running = false
    internalSbRequest1.running = false
    internalSbRequest2.running = false
    internalSbRequest3.running = false
    if (root.teamId === "" && root.resolvedTeamId === "") {
      root.fetchQueue = [{ kind: "teams" }]
    } else {
      root.buildFetchQueue()
    }
    root.startNextFetch()
  }

  function scoreboardsRunning() {
    if (internalFixtureRequest.running) return true
    var procs = [internalSbRequest1, internalSbRequest2, internalSbRequest3]
    for (var i = 0; i < procs.length; i++) {
      if (procs[i].running) return true
    }
    return false
  }

  function buildFetchQueue() {
    var team = root.safeIdentifier(root.resolvedTeamId !== "" ? root.resolvedTeamId : root.teamId)
    if (team !== "") {
      root.fetchQueue = [{ kind: "schedule" }]
    } else {
      var stale = new Date().getTime() - root.competitionRefresh > 6 * 3600 * 1000
      if (root.competitionSlugs.length === 0 || stale) root.fetchQueue = [{ kind: "discover" }]
      else root.fetchQueue = []
    }
  }

  function startNextFetch() {
    if (root.fetchQueue.length === 0) {
      root.finishFetch()
      return
    }
    var next = root.fetchQueue.shift()
    root.fetchStage = next.kind
    var team = root.safeIdentifier(root.resolvedTeamId !== "" ? root.resolvedTeamId : root.teamId)
    var leagueCode = root.safeIdentifier(root.league)
    if (next.kind === "teams") {
      if (leagueCode === "") { root.loading = false; return }
      internalFixtureRequest.command = FutNetwork.jsonCommand(["https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(leagueCode) + "/teams"], 2097152, 20)
    } else if (next.kind === "schedule" || next.kind === "schedule_past" || next.kind === "schedule_future") {
      if (team === "") { root.loading = false; return }
      internalFixtureRequest.command = FutNetwork.jsonCommand(["https://site.web.api.espn.com/apis/site/v2/sports/soccer/all/teams/" + encodeURIComponent(team) + "/schedule",
        "https://site.web.api.espn.com/apis/site/v2/sports/soccer/all/teams/" + encodeURIComponent(team) + "/schedule?fixture=true"], 4194304, 20)
    } else if (next.kind === "discover") {
      if (team === "") { root.finishFetch(); return }
      var window = root.clubSeasonWindow()
      internalFixtureRequest.command = FutNetwork.jsonCommand(["https://sports.core.api.espn.com/v2/sports/soccer/teams/" + encodeURIComponent(team) + "/events?dates=" + encodeURIComponent(window) + "&limit=100"], 2097152, 20)
    }
    internalFixtureRequest.running = true
  }

  function startScoreboards() {
    var slugs = root.competitionSlugs.slice()
    var primarySlug = root.safeIdentifier(root.league || "esp.1")
    var pIdx = slugs.indexOf(primarySlug)
    if (pIdx > 0) slugs.splice(pIdx, 1)
    if (slugs.indexOf(primarySlug) === -1) slugs.unshift(primarySlug)
    else if (slugs[0] !== primarySlug) slugs.unshift(primarySlug)
    root.scoreboardQueue = slugs
    root._sbRetry = {}
    root.kickScoreboards()
  }

  function kickScoreboards() {
    while (root.scoreboardQueue.length > 0) {
      var assigned = false
      var procs = [internalSbRequest1, internalSbRequest2, internalSbRequest3]
      for (var i = 0; i < procs.length; i++) {
        if (!procs[i].running) {
          var rawSlug = root.scoreboardQueue.shift()
          var slug = root.safeIdentifier(rawSlug)
          if (slug === "") continue
          root.sbSlugs[i] = slug
          procs[i].command = FutNetwork.jsonCommand(["https://site.web.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(slug) + "/scoreboard?limit=500"], 5242880, 20)
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
        root.sbSlugs[index] = ""
        root.kickScoreboards()
        return
      }
      // Empty reply (network DNS/timeout/HTTP error): the slug is not done.
      root.retryScoreboard(index, slug)
      return
    }
    try {
      var data = JSON.parse(text)
      if (!data || !Array.isArray(data.events)) throw new Error("Unsupported scoreboard data")
      root.fixtureCycleReceived = true
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
        if (events[e].competitionName === undefined && leagues.length > 0) {
          events[e].competitionName = root.sanitizePlainText(String(leagues[0].name || leagues[0].shortName || leagues[0].abbreviation || slug))
        }
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
      if (merged.length > 0) {
        root.setFixtures({ events: merged })
        if (root.clubFixturePage === 0 && root.teamFixtureRows.length > 0) {
          root.initClubFixturePage()
        }
      }
      if (slug !== "") {
        var clearRetry = Object.assign({}, root._sbRetry)
        delete clearRetry[slug]
        root._sbRetry = clearRetry
      }
    } catch (error) {
      console.warn("futbar", "scoreboard: " + error)
      // Truncated download (e.g. a refresh killed a request mid-flight and the
      // partial stdout was delivered): re-queue instead of dropping the slug.
      root.retryScoreboard(index, slug)
      return
    }
    root.sbSlugs[index] = ""
    root.kickScoreboards()
  }

  function retryScoreboard(index, slug) {
    root.sbSlugs[index] = ""
    if (slug !== "") {
      var tries = (root._sbRetry[slug] || 0) + 1
      var pending = Object.assign({}, root._sbRetry)
      pending[slug] = tries
      root._sbRetry = pending
      if (tries <= 2) {
        root.scoreboardQueue.unshift(slug)
      } else {
        console.warn("futbar", "scoreboard retry exhausted for " + slug)
      }
    }
    root.kickScoreboards()
  }

  function maybeFinishScoreboards() {
    if (root.scoreboardQueue.length > 0) return
    var procs = [internalSbRequest1, internalSbRequest2, internalSbRequest3]
    for (var i = 0; i < procs.length; i++) {
      if (procs[i].running) return
    }
    root.finishFetch()
  }

  function finishFetch() {
    if (!root.fixtureCycleReceived) {
      root.loading = false
      root.requestError = root.networkError || "No fresh fixture data. Showing cached fixtures when available."
      return
    }
    // A fully failed cycle (every board truncated or errored) must not wipe
    // good data: keep showing the last known fixtures instead of flipping
    // the bar back to icon-only until the next cycle succeeds.
    if (root.collectedEvents.length === 0 && root.lastRefresh > 0) {
      root.loading = false
      return
    }
    root.setFixtures({ events: root.collectedEvents })
    if (root.clubFixturePage === 0 && root.teamFixtureRows.length > 0) {
      root.initClubFixturePage()
    }
  }

  FutContextProcess {
    id: internalFixtureRequest
    requestContext: root.league + "|" + root.teamName + "|" + root.leagueMode
    // Sequential pipeline: the command changes per queue item and one request
    // runs at a time, chaining via onStreamFinished. A team's fixtures span
    // every competition it enters, so discovery + per-competition scoreboards
    // are needed rather than a single league scoreboard.
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalFixtureRequest.responseCurrent) return

        if (typeof text !== "string" || text.length === 0 || text.length > 4194304) {
          if (typeof text === "string" && text.length > 4194304) {
            console.warn("futbar", root.fetchStage + " response exceeded byte limit")
          }
          root.startNextFetch()
          return
        }
        try {
          var data = root.parseScoreboardPayload(text)
          if (!data) throw new Error("Could not parse schedule payload")
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
          } else if (root.fetchStage === "schedule" || root.fetchStage === "schedule_past" || root.fetchStage === "schedule_future") {
            if (!Array.isArray(data.events)) throw new Error("Unsupported schedule data")
            root.fixtureCycleReceived = true
            var events = Array.isArray(data.events) ? data.events : []
            var merged = root.collectedEvents.slice()
            var slugs = root.competitionSlugs.slice()
            var map = Object.assign({}, root.leagueInfo)
            for (var e = 0; e < events.length; e++) {
              var ev = events[e]
              var comp = (ev.competitions && ev.competitions[0]) || {}
              if (!ev.status && comp.status) ev.status = comp.status
              var lgSlug = (ev.league && ev.league.slug) ? root.safeIdentifier(ev.league.slug) : root.safeIdentifier(root.league)
              if (ev.competitionSlug === undefined) ev.competitionSlug = lgSlug
              var lgName = (ev.league && (ev.league.name || ev.league.shortName || ev.league.abbreviation)) ? String(ev.league.name || ev.league.shortName || ev.league.abbreviation) : ""
              if (ev.competitionName === undefined && lgName !== "") ev.competitionName = lgName
              if (lgSlug !== "" && slugs.indexOf(lgSlug) === -1) slugs.push(lgSlug)
              if (lgSlug !== "" && !map[lgSlug] && ev.league) {
                map[lgSlug] = {
                  name: root.sanitizePlainText(String(ev.league.name || ev.league.abbreviation || lgSlug)),
                  logo: root.sanitizeImageUrl(ev.league.logos && ev.league.logos.length ? String(ev.league.logos[0].href || "") : "")
                }
              }
              var existingIndex = -1
              for (var k = 0; k < merged.length; k++) {
                if (String(merged[k].id) === String(ev.id)) { existingIndex = k; break }
              }
              if (existingIndex !== -1) merged[existingIndex] = ev
              else merged.push(ev)
            }
            root.collectedEvents = merged
            root.competitionSlugs = slugs
            root.leagueInfo = map
            if (merged.length > 0) {
              root.setFixtures({ events: merged })
              if (root.clubFixturePage === 0 && root.teamFixtureRows.length > 0) {
                root.initClubFixturePage()
              }
            }
            if (root.fetchQueue.length === 0) {
              root.finishFetch()
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
onStreamFinished: {
        if (!internalFixtureRequest.responseCurrent) return
        root.warnStderr("", text)
      }
    }
  }

  FutContextProcess {
    id: internalSbRequest1
    requestContext: root.league + "|" + root.teamName + "|" + root.leagueMode
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSbRequest1.responseCurrent) return
        root.handleScoreboard(0, text)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
onStreamFinished: {
        if (!internalSbRequest1.responseCurrent) return
        root.warnStderr("", text)
      }
    }
  }

  FutContextProcess {
    id: internalSbRequest2
    requestContext: root.league + "|" + root.teamName + "|" + root.leagueMode
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSbRequest2.responseCurrent) return
        root.handleScoreboard(1, text)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
onStreamFinished: {
        if (!internalSbRequest2.responseCurrent) return
        root.warnStderr("", text)
      }
    }
  }

  FutContextProcess {
    id: internalSbRequest3
    requestContext: root.league + "|" + root.teamName + "|" + root.leagueMode
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSbRequest3.responseCurrent) return
        root.handleScoreboard(2, text)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
onStreamFinished: {
        if (!internalSbRequest3.responseCurrent) return
        root.warnStderr("", text)
      }
    }
  }
}
