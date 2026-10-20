import QtQuick
import qs.Commons
import qs.Ui
import "../controllers"
import "../data/FutExtras.js" as Extras
import "../services/FutNetwork.js" as Network

Column {
  id: view
  property var root: null
  property string athleteId: ""
  property bool expanded: false
  property bool revealed: false
  Connections { target: view.root; function onAntiSpoilerChanged() { view.revealed = false } }
  readonly property bool hiddenSpoilers: root && root.antiSpoiler && !revealed
  readonly property var rows: Extras.gameLog(request.result)
  width: parent ? parent.width : 0
  spacing: Style.space(8)
  onAthleteIdChanged: { expanded = false; revealed = false }
  onVisibleChanged: if (!visible) revealed = false
  FutApiRequest {
    id: request
    responseKind: "gamelog"
    url: /^[0-9]{1,20}$/.test(view.athleteId) ? "https://site.web.api.espn.com/apis/common/v3/sports/soccer/athletes/" + view.athleteId + "/gamelog" : ""
    active: view.visible && view.expanded && !view.hiddenSpoilers && view.root && view.root.opened
  }
  Button { focusable: true; text: view.expanded ? "Hide ESPN season game log" : "Show ESPN season game log"; foreground: root.contentForeground; accent: root.contentForeground; onClicked: view.expanded = !view.expanded }
  Column {
    visible: view.expanded; width: parent.width; spacing: Style.space(8)
    Button { focusable: true; visible: view.hiddenSpoilers; text: "Reveal match statistics"; foreground: root.contentForeground; accent: root.contentForeground; onClicked: view.revealed = true }
    Column {
      width: parent.width; spacing: Style.space(8); visible: !view.hiddenSpoilers
      Text { text: "ESPN's current default season · up to 100 matches"; color: root.contentForeground; font.pixelSize: Style.font.caption; textFormat: Text.PlainText }
      Text { width: parent.width; wrapMode: Text.WordWrap; text: request.loading ? "Loading game log…" : (request.error ? request.error + (request.stale ? " Showing the last successful game log." : "") : (view.rows.length ? "" : "No game log available for this player.")); visible: text !== ""; color: root.contentForeground; textFormat: Text.PlainText }
      Button { focusable: true; visible: request.error !== ""; text: request.retryInSeconds ? "Retry in " + request.retryInSeconds + "s" : "Retry"; enabled: !request.loading && request.retryInSeconds === 0; onClicked: request.refresh(); foreground: root.contentForeground; accent: root.contentForeground }
      Repeater {
        model: view.rows
        delegate: Column {
          required property var modelData
          width: parent.width; spacing: Style.space(3)
          Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: modelData.date.slice(0, 10) + " · " + modelData.opponent + " · " + modelData.competition; color: root.contentForeground; font.bold: true; font.pixelSize: Style.font.caption }
          Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: modelData.stats.map(function(s) { return s.label + ": " + s.value }).join(" · "); color: root.contentForeground; font.pixelSize: Style.font.caption }
          Button { focusable: true; visible: modelData.url !== ""; text: "Match on ESPN"; onClicked: { var url = Network.safeProfileUrl(modelData.url); if (url) Qt.openUrlExternally(url) } foreground: root.contentForeground; accent: root.contentForeground }
        }
      }
    }
  }
}
