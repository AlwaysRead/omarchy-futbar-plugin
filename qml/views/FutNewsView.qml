import QtQuick
import qs.Commons
import qs.Ui
import "../components"
import "../controllers"
import "../data/FutExtras.js" as Extras

Column {
  id: view
  property var root: null
  property var selectedArticle: null
  property bool revealed: false
  readonly property color foreground: root ? root.contentForeground : "#eeeeee"
  readonly property string fontFamily: root && root.contentFontFamily ? root.contentFontFamily : Style.font.family
  readonly property bool hiddenSpoilers: root && (root.spoilersHidden !== undefined ? root.spoilersHidden : root.antiSpoiler) && !revealed
  readonly property var articles: Extras.news(request.result)
  width: parent ? parent.width : 0
  spacing: Style.space(12)
  function resetScroll() { if (root && typeof root.resetPanelScroll === "function") root.resetPanelScroll() }
  function openArticle(article) { selectedArticle = article; resetScroll() }
  function closeReader() { selectedArticle = null; resetScroll() }
  onVisibleChanged: if (!visible) { revealed = false; selectedArticle = null }
  Connections {
    target: view.root
    function onAntiSpoilerChanged() { view.revealed = false; view.closeReader() }
    function onOpenedChanged() { if (!view.root.opened) { view.revealed = false; view.selectedArticle = null } }
  }
  FutApiRequest {
    id: request
    responseKind: "news"
    url: "https://site.api.espn.com/apis/site/v2/sports/soccer/all/news"
    active: view.visible && view.root && view.root.opened && !view.hiddenSpoilers
  }
  Column {
    width: parent.width
    spacing: Style.space(8)
    visible: view.hiddenSpoilers
    Text { text: "News headlines may reveal results."; textFormat: Text.PlainText; color: view.foreground; font.family: view.fontFamily; font.pixelSize: Style.font.caption }
    Button {
      Accessible.role: Accessible.Button
      Accessible.name: tooltipText || text || "Action"
      focusable: true; text: "Reveal news"; onClicked: view.revealed = true; foreground: view.foreground; accent: view.foreground }
  }
  FutNewsReader {
    objectName: "newsReader"
    visible: !view.hiddenSpoilers && view.selectedArticle !== null
    article: view.selectedArticle
    foreground: view.foreground
    fontFamily: view.fontFamily
    fetchingEnabled: view.root && view.root.opened && !view.hiddenSpoilers
    onBackRequested: view.closeReader()
  }
  Column {
    width: parent.width
    spacing: Style.space(10)
    visible: !view.hiddenSpoilers && view.selectedArticle === null
    Item {
      width: parent.width
      implicitHeight: Math.max(newsHeading.implicitHeight, refreshButton.implicitHeight)
      Text {
        id: newsHeading
        anchors.left: parent.left
        anchors.right: refreshButton.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: "News"; textFormat: Text.PlainText
        color: view.foreground; font.family: view.fontFamily
        font.bold: true; font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      Button {
        Accessible.role: Accessible.Button
        Accessible.name: tooltipText || text || "Action"

        id: refreshButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: request.loading ? "Loading…" : (request.retryInSeconds ? "Retry in " + request.retryInSeconds + "s" : "Refresh")
        enabled: !request.loading && request.retryInSeconds === 0
        focusable: true; foreground: view.foreground; accent: view.foreground
        fontSize: Style.font.caption
        onClicked: request.refresh()
      }
    }
    Text { width: parent.width; text: "Latest football stories from ESPN"; textFormat: Text.PlainText; color: view.foreground; opacity: 0.6; font.family: view.fontFamily; font.pixelSize: Style.font.caption }
    Text {
      width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      text: request.error ? request.error + (request.stale ? " Showing cached news." : "") : (request.updatedAt ? "Updated " + Qt.formatDateTime(new Date(request.updatedAt), "hh:mm") : "")
      color: view.foreground; opacity: 0.6; font.family: view.fontFamily; font.pixelSize: Style.font.caption; visible: text !== ""
    }
    Text { width: parent.width; wrapMode: Text.WordWrap; visible: !request.loading && !request.error && view.articles.length === 0; text: "No news available in the current feed."; textFormat: Text.PlainText; color: view.foreground; font.family: view.fontFamily; font.pixelSize: Style.font.caption }
    Repeater {
      model: view.articles
      delegate: Rectangle {
        id: card
        required property var modelData
        objectName: "newsCard"
        width: parent.width
        height: Math.max(Style.space(78), storyText.implicitHeight) + Style.space(20)
        radius: Style.space(8)
        color: Util.alpha(view.foreground, mouse.containsMouse || activeFocus ? 0.07 : 0.03)
        border.color: Util.alpha(view.foreground, activeFocus ? 0.5 : 0.08)
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: modelData.title
        Accessible.onPressAction: view.openArticle(modelData)
        Keys.onReturnPressed: view.openArticle(modelData)
        Keys.onEnterPressed: view.openArticle(modelData)
        Keys.onSpacePressed: view.openArticle(modelData)
        FutNewsPhoto {
          id: thumbnail
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.margins: Style.space(10)
          width: Math.min(Style.space(106), parent.width * 0.28)
          height: Style.space(78)
          foreground: view.foreground
          imageUrl: card.modelData.image
          fetchingEnabled: view.root && view.root.opened && !view.hiddenSpoilers
        }
        Column {
          id: storyText
          anchors.left: thumbnail.right
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(10)
          spacing: Style.space(5)
          Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: card.modelData.title; color: view.foreground; font.family: view.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
          Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: (card.modelData.premium ? "ESPN+" : "ESPN") + " · " + card.modelData.published.slice(0, 10); color: view.foreground; opacity: 0.55; font.family: view.fontFamily; font.pixelSize: Style.font.caption - 1 }
          Text { visible: card.modelData.transfer; text: "TRANSFER NEWS"; textFormat: Text.PlainText; color: view.foreground; opacity: 0.7; font.family: view.fontFamily; font.pixelSize: Style.font.caption - 2; font.letterSpacing: 0.5 }
        }
        FutActionArea {
    actionLabel: "Open details"
 id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onActivated: { card.forceActiveFocus(); view.openArticle(card.modelData) } }
      }
    }
  }
}
