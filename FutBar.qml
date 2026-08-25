import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

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
    if (!txt || typeof txt !== "string" || txt.length > 65536) return ({})
    try {
      var parsed = JSON.parse(txt)
      return parsed && typeof parsed === "object" ? parsed : ({})
    } catch (e) { return ({}) }
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
  readonly property string teamName: root.sanitizePlainText(root.savedFavorite.teamName !== undefined && root.savedFavorite.teamName !== ""
    ? root.savedFavorite.teamName : setting("teamName", ""))
  readonly property string league: root.sanitizePlainText(root.savedFavorite.league !== undefined && root.savedFavorite.league !== ""
    ? root.savedFavorite.league : setting("league", ""))
  FileView {
    id: favoriteStore
    path: root.favoritePath
    printErrors: false
    onLoaded: root.savedFavorite = root.parseFavorite(text())
    onLoadFailed: root.savedFavorite = ({})
  }
  Timer {
    interval: 1500
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

  // Refresh cadence for the shared data fetches (scoreboard, fixtures).
  // Fast while a match is live so goals reach the bar and popup promptly;
  // relaxed otherwise to stay off ESPN's back. Notification bodies never
  // depend on this timing: they read scores from their own summary payload.
  readonly property int liveRefreshMs: 10000
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
      root.updateTooltip()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Keep the bar clean: fixture details stay in the popup and tooltip.
    text: "󰒸"
    tooltipText: root.tooltip
    // Steady theme accent while a match is live; white otherwise. Events
    // blink it via the eventBlink animation above.
    active: root.live
    activeColor: Color.accent
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) root.refresh()
      else {
        root.refresh()
        root.togglePanel()
      }
    }
  }
}
