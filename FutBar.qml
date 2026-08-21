import QtQuick
import Quickshell
import Quickshell.Io
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
    if (!txt) return ({})
    try {
      var parsed = JSON.parse(txt)
      return parsed && typeof parsed === "object" ? parsed : ({})
    } catch (e) { return ({}) }
  }
  readonly property string teamName: String(root.savedFavorite.teamName !== undefined && root.savedFavorite.teamName !== ""
    ? root.savedFavorite.teamName : setting("teamName", ""))
  readonly property string league: String(root.savedFavorite.league !== undefined && root.savedFavorite.league !== ""
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
  property bool loading: (panelLoader.item ? panelLoader.item.loading === true : false)
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
  function updateTooltip() {
    var p = panelLoader.item
    if (root.needsTeam) {
      root.tooltip = "No Team Selected"
      return
    }
    if (!p) return
    if (p.loading) {
      root.tooltip = "Fetching " + root.teamName + "…"
      return
    }
    if (p.requestError) {
      root.tooltip = String(p.requestError)
      return
    }
    if (p.liveMatch) {
      var home = String(p.teamNameFor(p.liveMatch, "home"))
      var away = String(p.teamNameFor(p.liveMatch, "away"))
      var homeScore = String(p.scoreFor(p.liveMatch, "home"))
      var awayScore = String(p.scoreFor(p.liveMatch, "away"))
      var clock = String(p.statusFor(p.liveMatch))
      root.liveTooltip = home + " vs " + away + " (" + homeScore + "–" + awayScore + "), " + clock
      var summary = p.liveSummaryText()
      root.tooltip = root.liveTooltip + (summary !== "" ? "\n\n" + summary : "")
      root.live = true
      return
    }
    root.live = false
    root.liveTooltip = ""
    if (p.nextMatch) {
      root.tooltip = "Next Match\n" + p.teamNameFor(p.nextMatch, "home") + " vs " + p.teamNameFor(p.nextMatch, "away")
        + "\n" + p.competitionNameFor(p.nextMatch) + " · " + p.kickoffDay(p.nextMatch) + " · " + p.kickoffTime(p.nextMatch)
      return
    }
    root.tooltip = "No live match found for " + root.teamName + " in " + root.league
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

  Timer {
    interval: root.live ? 30000 : 300000
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
    active: root.live
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }
  }
}
