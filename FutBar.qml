import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "FutUtils.js" as FutUtils

// A deliberately small bar widget. It asks ESPN's public scoreboard for the
// selected league, then makes a second request only for a live match so that
// the tooltip can include scorers.
BarWidget {
  id: root
  moduleName: "devbook.futbar"

  // Remembered favorite team, used as a fallback so a reload never shows the
  // manifest default (Barcelona) before settings are injected.
  readonly property string favoritePath: Quickshell.env("HOME") + "/.local/state/omarchy/futbar.json"
  property var savedFavorite: ({})
  function parseFavorite(txt) {
    return FutUtils.parseFavorite(txt)
  }
  function sanitizePlainText(raw) {
    return FutUtils.sanitizePlainText(raw)
  }
  readonly property var primaryItem: {
    if (root.savedFavorite && Array.isArray(root.savedFavorite.tabOrder) && root.savedFavorite.tabOrder.length > 0) {
      return root.savedFavorite.tabOrder[0]
    }
    if (root.savedFavorite && Array.isArray(root.savedFavorite.followedTeams) && root.savedFavorite.followedTeams.length > 0) {
      return root.savedFavorite.followedTeams[0]
    }
    return null
  }
  readonly property string teamName: {
    if (root.primaryItem && !root.primaryItem.followLeague && root.primaryItem.teamName) {
      return root.sanitizePlainText(root.primaryItem.teamName)
    }
    var raw = (root.savedFavorite.teamName !== undefined && root.savedFavorite.teamName !== "")
      ? root.savedFavorite.teamName : setting("teamName", "")
    return root.sanitizePlainText(raw)
  }
  readonly property string league: {
    if (root.primaryItem && root.primaryItem.league) {
      return root.sanitizePlainText(root.primaryItem.league)
    }
    var raw = (root.savedFavorite.league !== undefined && root.savedFavorite.league !== "")
      ? root.savedFavorite.league : setting("league", "")
    return root.sanitizePlainText(raw)
  }
  FileView {
    id: favoriteStore
    path: root.favoritePath
    printErrors: false
    onLoaded: root.savedFavorite = root.parseFavorite(text())
    onLoadFailed: root.savedFavorite = ({})
  }
  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: favoriteStore.reload()
  }
  readonly property bool needsTeam: panelLoader.item ? panelLoader.item.needsTeam === true : true
  property string tooltip: "Checking for a live match…"
  property string liveTooltip: ""
  property bool live: false
  property bool loading: (panelLoader.item ? (panelLoader.item.anyLoading === true || panelLoader.item.loading === true) : false)
  property real _pulse: 0.0

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property real openPanelIndicatorWidth: (root.barWidgetMode === "icon" || root.barDisplayText === "")
    ? Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
    : button.labelWidth
  opacity: root.loading ? 0.4 + 0.6 * root._pulse : 1.0

  SequentialAnimation on _pulse {
    running: root.loading
    loops: Animation.Infinite
    NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutQuad }
    NumberAnimation { to: 0.0; duration: 450; easing.type: Easing.InOutQuad }
  }

  // Event blink: on each activity pulse (goal, card, kickoff, HT/FT — fired
  // from the panel's notification path only, never per fetch) the icon
  // alternates foreground/accent a few times, then settles back to the
  // steady live color. Toggling useActiveColor keeps the accent binding and
  // guarantees the animation ends in the colored state.
  SequentialAnimation {
    id: eventBlink
    PropertyAction { target: button; property: "useActiveColor"; value: false }
    PauseAnimation { duration: 350 }
    PropertyAction { target: button; property: "useActiveColor"; value: true }
    PauseAnimation { duration: 350 }
    PropertyAction { target: button; property: "useActiveColor"; value: false }
    PauseAnimation { duration: 350 }
    PropertyAction { target: button; property: "useActiveColor"; value: true }
    PauseAnimation { duration: 350 }
    PropertyAction { target: button; property: "useActiveColor"; value: false }
    PauseAnimation { duration: 350 }
    PropertyAction { target: button; property: "useActiveColor"; value: true }
  }
  function refresh() {
    if (root.needsTeam) {
      root.live = false
      root.tooltip = "No Team Selected"
      return
    }
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
    root.updateTooltip()
  }

  // The panel now fetches the team's fixtures across every competition, so the
  // bar tooltip derives from that data instead of its own scoreboard request.
  // Live state is recomputed from scratch on every pass so error/loading
  // early-returns can never leave a stale "live" (and its colored icon)
  // behind after the match ends or a fetch fails.
  function updateTooltip() {
    var p = panelLoader.item
    root.live = false
    root.liveTooltip = ""
    if (root.needsTeam) {
      root.tooltip = "No Team Selected"
      return
    }
    if (!p) return
    // League-follow mode summarizes the whole competition instead of one club.
    if (p.leagueMode) {
      root.live = (Array.isArray(p.leagueLive) && p.leagueLive.length > 0)
      root.tooltip = root.sanitizePlainText(p.leagueLabel() + " — " +
        (p.leagueBoardSummary !== "" ? p.leagueBoardSummary : "checking fixtures…"))
      return
    }
    if (p.loading) {
      root.tooltip = root.sanitizePlainText("Fetching " + root.teamName + "…")
      return
    }
    if (p.requestError) {
      root.tooltip = root.sanitizePlainText(String(p.requestError))
      return
    }
    if (p.liveMatch) {
      var home = root.sanitizePlainText(p.teamNameFor(p.liveMatch, "home"))
      var away = root.sanitizePlainText(p.teamNameFor(p.liveMatch, "away"))
      var homeScore = root.sanitizePlainText(p.scoreFor(p.liveMatch, "home"))
      var awayScore = root.sanitizePlainText(p.scoreFor(p.liveMatch, "away"))
      var clock = root.sanitizePlainText(p.statusFor(p.liveMatch))
      root.liveTooltip = home + " vs " + away + " (" + homeScore + "–" + awayScore + "), " + clock
      var summary = root.sanitizePlainText(p.liveSummaryText())
      root.tooltip = root.sanitizePlainText(root.liveTooltip + (summary !== "" ? "\n\n" + summary : ""))
      root.live = true
      return
    }
    if (p.nextMatch) {
      var nextHome = root.sanitizePlainText(p.teamNameFor(p.nextMatch, "home"))
      var nextAway = root.sanitizePlainText(p.teamNameFor(p.nextMatch, "away"))
      var nextComp = root.sanitizePlainText(p.competitionNameFor(p.nextMatch))
      var nextDay = root.sanitizePlainText(p.kickoffDay(p.nextMatch))
      var nextTime = root.sanitizePlainText(p.kickoffTime(p.nextMatch))
      root.tooltip = root.sanitizePlainText("Next Match\n" + nextHome + " vs " + nextAway
        + "\n" + nextComp + " · " + nextDay + " · " + nextTime)
      return
    }
    root.tooltip = root.sanitizePlainText("No live match found for " + root.teamName + " in " + root.league)
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  // Popout switching (Tab between panels): mirror the panel's transient
  // closing state so the shell's switch can drive this widget too.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function toggle() {
    root.togglePanel()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
  }

  Component.onCompleted: refresh()
  onTeamNameChanged: refresh()
  onLeagueChanged: refresh()
  onNeedsTeamChanged: refresh()
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onTooltipChanged: {
    if (!root.bar || root.bar.tooltipTarget !== button) return
    if (root.bar.tooltipShown) root.bar.tooltipText = root.tooltip
    else if (button.tooltipHovered) root.bar.showTooltip(button, root.tooltip)
  }

  readonly property string barWidgetMode: {
    if (panelLoader.item && panelLoader.item.barWidgetMode !== undefined && panelLoader.item.barWidgetMode !== "") {
      return panelLoader.item.barWidgetMode
    }
    var raw = (root.savedFavorite && root.savedFavorite.barWidgetMode !== undefined && root.savedFavorite.barWidgetMode !== "")
      ? String(root.savedFavorite.barWidgetMode) : setting("barWidgetMode", "icon")
    if (raw === "score" || raw === "next" || raw === "icon") return raw
    return "icon"
  }

  readonly property string barDisplayText: {
    var p = panelLoader.item
    var mode = root.barWidgetMode
    if (!p) return ""
    if (mode === "icon") return ""

    var isClub = root.primaryItem ? !root.primaryItem.followLeague : (root.teamName !== "")
    var primaryKey = p.teamKey ? p.teamKey(root.teamName, root.league) : ""
    var cached = (primaryKey && p._teamStateCache) ? p._teamStateCache[primaryKey] : null

    if (mode === "score") {
      if (isClub) {
        var lm = (!p.leagueMode && p.teamName === root.teamName) ? p.liveMatch : (cached ? cached.liveMatch : p.liveMatch)
        if (lm) {
          var h = p.scoreFor(lm, "home")
          var a = p.scoreFor(lm, "away")
          var clk = p.statusFor(lm)
          var hAbbrev = p.teamTabLabel(p.teamNameFor(lm, "home"), root.league, "abbrev")
          var aAbbrev = p.teamTabLabel(p.teamNameFor(lm, "away"), root.league, "abbrev")
          return (hAbbrev || "H") + " " + h + "–" + a + " " + (aAbbrev || "A") + (clk ? " " + clk : "")
        }
        var prev = (!p.leagueMode && p.teamName === root.teamName) ? p.previousMatch : (cached ? cached.previousMatch : p.previousMatch)
        if (prev) {
          var prevH = p.scoreFor(prev, "home")
          var prevA = p.scoreFor(prev, "away")
          var prevClk = p.statusFor(prev) || "FT"
          var prevHAbbrev = p.teamTabLabel(p.teamNameFor(prev, "home"), root.league, "abbrev")
          var prevAAbbrev = p.teamTabLabel(p.teamNameFor(prev, "away"), root.league, "abbrev")
          return (prevHAbbrev || "H") + " " + prevH + "–" + prevA + " " + (prevAAbbrev || "A") + " " + prevClk
        }
        if (p.loading || root.loading) return "Fetching Scores…"
        return "No Live Match"
      } else {
        if (Array.isArray(p.leagueLive) && p.leagueLive.length > 0) {
          var lm = p.leagueLive[0]
          var lh = (lm.homeScore !== undefined && lm.homeScore !== "") ? lm.homeScore : "0"
          var la = (lm.awayScore !== undefined && lm.awayScore !== "") ? lm.awayScore : "0"
          var lclk = lm.status || "Live"
          var lhAbbrev = p.teamTabLabel(lm.homeName, p.league, "abbrev") || lm.homeName
          var laAbbrev = p.teamTabLabel(lm.awayName, p.league, "abbrev") || lm.awayName
          var lmore = p.leagueLive.length > 1 ? (" (+" + (p.leagueLive.length - 1) + ")") : ""
          return (lhAbbrev || "H") + " " + lh + "–" + la + " " + (laAbbrev || "A") + " " + lclk + lmore
        }
        if (Array.isArray(p.leagueRecent) && p.leagueRecent.length > 0) {
          var rm = p.leagueRecent[0]
          var rh = (rm.homeScore !== undefined && rm.homeScore !== "") ? rm.homeScore : "0"
          var ra = (rm.awayScore !== undefined && rm.awayScore !== "") ? rm.awayScore : "0"
          var rclk = rm.status || "FT"
          var rhAbbrev = p.teamTabLabel(rm.homeName, p.league, "abbrev") || rm.homeName
          var raAbbrev = p.teamTabLabel(rm.awayName, p.league, "abbrev") || rm.awayName
          return (rhAbbrev || "H") + " " + rh + "–" + ra + " " + (raAbbrev || "A") + " " + rclk
        }
        if (p.loading || root.loading) return "Checking Scores…"
        return "No Live Match"
      }
    }

    if (mode === "next") {
      if (isClub) {
        var nm = (!p.leagueMode && p.teamName === root.teamName) ? p.nextMatch : (cached ? cached.nextMatch : p.nextMatch)
        if (nm) {
          var home = p.teamNameFor(nm, "home")
          var away = p.teamNameFor(nm, "away")
          var homeAbbrev = p.teamTabLabel(home, root.league, "abbrev")
          var awayAbbrev = p.teamTabLabel(away, root.league, "abbrev")
          var t = p.kickoffTime(nm)
          return (homeAbbrev || home || "H") + " vs " + (awayAbbrev || away || "A") + (t ? " · " + t : "")
        }
        var rows = (!p.leagueMode && p.teamName === root.teamName) ? p.teamFixtureRows : (cached ? cached.teamFixtureRows : p.teamFixtureRows)
        if (Array.isArray(rows) && rows.length > 0) {
          for (var f = 0; f < rows.length; f++) {
            var row = rows[f]
            if (row && row.state === "pre") {
              var rHome = row.homeName || p.teamNameFor(row, "home")
              var rAway = row.awayName || p.teamNameFor(row, "away")
              var rHAbbrev = p.teamTabLabel(rHome, root.league, "abbrev") || rHome
              var rAAbbrev = p.teamTabLabel(rAway, root.league, "abbrev") || rAway
              var rTime = row.timeText || (row.date ? p.kickoffTime(row) : "")
              return (rHAbbrev || "H") + " vs " + (rAAbbrev || "A") + (rTime ? " · " + rTime : "")
            }
          }
        }
        if (p.loading || root.loading) return "Fetching Fixture…"
        return "No Upcoming Fixture"
      } else {
        var upMatch = null
        if (Array.isArray(p.leagueUpcoming) && p.leagueUpcoming.length > 0) {
          upMatch = p.leagueUpcoming[0]
        } else if (Array.isArray(p.matchWeekRows) && p.matchWeekRows.length > 0) {
          for (var i = 0; i < p.matchWeekRows.length; i++) {
            if (p.matchWeekRows[i].state === "pre") {
              upMatch = p.matchWeekRows[i]
              break
            }
          }
        }
        if (upMatch) {
          var uhAbbrev = p.teamTabLabel(upMatch.homeName, p.league, "abbrev") || upMatch.homeName
          var uaAbbrev = p.teamTabLabel(upMatch.awayName, p.league, "abbrev") || upMatch.awayName
          var ut = upMatch.timeText || (upMatch.kickoff ? root.sanitizePlainText(Qt.formatDateTime(new Date(upMatch.kickoff), "HH:mm")) : "")
          return (uhAbbrev || "H") + " vs " + (uaAbbrev || "A") + (ut ? " · " + ut : "")
        }
        if (p.loading || root.loading) return "Checking Fixtures…"
        return "No Upcoming Fixture"
      }
    }
    return ""
  }

  // Refresh cadence for the shared data fetches (scoreboard, fixtures).
  // Fast while a match is live so goals reach the bar and popup promptly;
  // relaxed otherwise to stay off ESPN's back. Notification bodies never
  // depend on this timing: they read scores from their own summary payload.
  readonly property int liveRefreshMs: ((panelLoader.item && panelLoader.item.livePollRate) ? panelLoader.item.livePollRate : 10) * 1000
  readonly property int idleRefreshMs: 60000

  Timer {
    interval: (root.live || root.opened) ? root.liveRefreshMs : root.idleRefreshMs
    running: !root.needsTeam
    repeat: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    // Cache-bust the panel URL: Qt.clearComponentCache does not drop
    // Loader-cached components, so without this a plugin reload would keep
    // running the previous version of FutBarPanel.qml.
    source: Qt.resolvedUrl("FutBarPanel.qml") + "?rev=" + Date.now()
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
      var p = panelLoader.item
      if (!p) return
      p.loadingChanged.connect(function() { root.updateTooltip() })
      p.liveMatchChanged.connect(function() { root.updateTooltip() })
      p.liveEventsChanged.connect(function() { root.updateTooltip() })
      p.nextMatchChanged.connect(function() { root.updateTooltip() })
      p.previousMatchChanged.connect(function() { root.updateTooltip() })
      p.requestErrorChanged.connect(function() { root.updateTooltip() })
      p.activityPulse.connect(eventBlink.restart)
      if (p.leagueLiveChanged) p.leagueLiveChanged.connect(function() { root.updateTooltip() })
      if (p.leagueUpcomingChanged) p.leagueUpcomingChanged.connect(function() { root.updateTooltip() })
      if (p.leagueRecentChanged) p.leagueRecentChanged.connect(function() { root.updateTooltip() })
      if (p.matchWeekRowsChanged) p.matchWeekRowsChanged.connect(function() { root.updateTooltip() })
      if (p.teamFixtureRowsChanged) p.teamFixtureRowsChanged.connect(function() { root.updateTooltip() })
      if (p.leagueModeChanged) p.leagueModeChanged.connect(function() { root.updateTooltip() })
      if (p.leagueBoardSummaryChanged) p.leagueBoardSummaryChanged.connect(function() { root.updateTooltip() })
      if (p.barWidgetModeChanged) p.barWidgetModeChanged.connect(function() { root.updateTooltip() })
      if (p.savedFavoriteChanged) p.savedFavoriteChanged.connect(function() {
        root.savedFavorite = p.savedFavorite
        root.updateTooltip()
      })
      root.updateTooltip()
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: (root.barWidgetMode === "icon" || root.barDisplayText === "") ? "󰒸" : root.barDisplayText
    labelVisible: true
    fontSize: (root.barWidgetMode === "icon" || root.barDisplayText === "") ? Style.bar.iconFont : Style.font.caption
    fixedWidth: (root.barWidgetMode === "icon" || root.barDisplayText === "") ? Style.bar.iconSlot : -1
    horizontalMargin: (root.barWidgetMode === "icon" || root.barDisplayText === "") ? 0 : 8.5
    active: root.live
    activeColor: Color.accent
    tooltipText: root.tooltip
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) root.refresh()
      else {
        root.refresh()
        root.togglePanel()
      }
    }
  }
}
