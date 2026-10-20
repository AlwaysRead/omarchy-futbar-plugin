import QtQuick
import qs.Commons
import qs.Ui
import "../components"
import "../services/FutNetwork.js" as Network

Column {
  id: reader
  property var article: null
  property color foreground: "#eeeeee"
  property string fontFamily: Style.font.family
  property bool fetchingEnabled: true
  signal backRequested()
  width: parent ? parent.width : 0
  spacing: Style.space(12)

  Button {
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText || text || "Action"

    text: "‹ Back to news"
    focusable: true
    foreground: reader.foreground
    accent: reader.foreground
    fontFamily: reader.fontFamily
    onClicked: reader.backRequested()
  }
  FutNewsPhoto {
    width: parent.width
    height: width * 9 / 16
    foreground: reader.foreground
    imageUrl: reader.article ? reader.article.image : ""
    fetchingEnabled: reader.fetchingEnabled
    visible: imageUrl !== ""
  }
  Text {
    width: parent.width
    text: reader.article ? reader.article.credit : ""
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: reader.foreground
    opacity: 0.5
    font.family: reader.fontFamily
    font.pixelSize: Style.font.caption - 1
    visible: text !== ""
  }
  Text {
    width: parent.width
    text: reader.article ? reader.article.title : ""
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: reader.foreground
    font.family: reader.fontFamily
    font.pixelSize: Style.font.body + 2
    font.bold: true
  }
  Text {
    width: parent.width
    text: reader.article ? ((reader.article.byline || "ESPN") + " · " + reader.article.published.slice(0, 10) + (reader.article.premium ? " · ESPN+" : "")) : ""
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: reader.foreground
    opacity: 0.6
    font.family: reader.fontFamily
    font.pixelSize: Style.font.caption
  }
  Rectangle { width: parent.width; height: 1; color: Util.alpha(reader.foreground, 0.1) }
  Text {
    width: parent.width
    text: reader.article && reader.article.description ? reader.article.description : "No summary is available for this story."
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: reader.foreground
    font.family: reader.fontFamily
    font.pixelSize: Style.font.bodySmall
    lineHeight: 1.3
  }
  Text {
    width: parent.width
    text: "Preview provided by ESPN. Read the full article on ESPN."
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: reader.foreground
    opacity: 0.55
    font.family: reader.fontFamily
    font.pixelSize: Style.font.caption
  }
  Button {
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText || text || "Action"

    text: "Read on ESPN ↗"
    bordered: true
    focusable: true
    foreground: reader.foreground
    accent: reader.foreground
    fontFamily: reader.fontFamily
    onClicked: {
      var url = Network.safeProfileUrl(reader.article ? reader.article.url : "")
      if (url) Qt.openUrlExternally(url)
    }
  }
}
