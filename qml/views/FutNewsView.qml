import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "../controllers"
import "../data/FutExtras.js" as Extras
import "../services/FutNetwork.js" as Network

Column {
  id: view
  property var root: null
  width: parent ? parent.width : 0
  spacing: Style.space(10)
  property bool followedOnly: false
  property bool revealed: false
  Connections { target: view.root; function onAntiSpoilerChanged() { view.revealed = false } }
  readonly property string league: root ? root.safeIdentifier(root.league) : ""
  readonly property bool hiddenSpoilers: root && root.antiSpoiler && !revealed
  readonly property var followedIds: {
    var ids = []
    if (root) root.allFollowedTabs().forEach(function(t) { if (t.teamId) ids.push(String(t.teamId)) })
    return ids
  }
  readonly property var articles: followedOnly && !followedIds.length ? [] : Extras.news(request.result, followedOnly ? followedIds : [])
  onLeagueChanged: revealed = false
  onVisibleChanged: if (!visible) revealed = false
  FutApiRequest {
    id: request
    responseKind: "news"
    url: view.league ? "https://site.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(view.league) + "/news" : ""
    active: view.visible && view.root && view.root.opened && !view.hiddenSpoilers
  }
  Text { text: "League news"; color: root.contentForeground; font.bold: true; font.pixelSize: Style.font.body; textFormat: Text.PlainText }
  Text {
    width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
    text: hiddenSpoilers ? "News headlines may reveal results." : "Recent ESPN headlines for this league. Club filtering covers this feed, not a complete news archive."
    color: root.contentForeground; font.pixelSize: Style.font.caption
  }
  Button { focusable: true; visible: view.hiddenSpoilers; text: "Reveal news"; onClicked: view.revealed = true; foreground: root.contentForeground; accent: root.contentForeground }
  Column {
    width: parent.width; spacing: Style.space(8); visible: !view.hiddenSpoilers
    Controls.CheckBox { text: "Followed clubs only"; checked: view.followedOnly; onToggled: view.followedOnly = checked }
    Button { focusable: true; text: request.loading ? "Loading…" : (request.retryInSeconds ? "Retry in " + request.retryInSeconds + "s" : "Refresh news"); enabled: !request.loading && request.retryInSeconds === 0; foreground: root.contentForeground; accent: root.contentForeground; onClicked: request.refresh() }
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      text: request.error ? request.error + (request.stale ? " Showing cached news from " + Qt.formatDateTime(new Date(request.updatedAt), "hh:mm") + "." : "") : (request.updatedAt ? "Updated " + Qt.formatDateTime(new Date(request.updatedAt), "hh:mm") : "")
      color: root.contentForeground; font.pixelSize: Style.font.caption; visible: text !== ""
    }
    Text { visible: !request.loading && !request.error && view.articles.length === 0; text: "No matching news available."; color: root.contentForeground; font.pixelSize: Style.font.caption }
    Repeater {
      model: view.articles
      delegate: Column {
        required property var modelData
        width: parent.width; spacing: Style.space(3)
        Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: modelData.title; color: root.contentForeground; font.pixelSize: Style.font.bodySmall }
        Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: (modelData.transfer ? "Transfer news · " : "") + (modelData.premium ? "ESPN+ · " : "") + modelData.byline + " · " + modelData.published.slice(0, 10); color: root.contentForeground; font.pixelSize: Style.font.caption }
        Button { focusable: true; text: "Read on ESPN"; Accessible.name: "Read " + modelData.title + " on ESPN"; foreground: root.contentForeground; accent: root.contentForeground; onClicked: { var url = Network.safeProfileUrl(modelData.url); if (url) Qt.openUrlExternally(url) } }
      }
    }
  }
}
