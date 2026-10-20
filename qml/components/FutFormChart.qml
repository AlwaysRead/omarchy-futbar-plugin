import QtQuick
import qs.Commons

Column {
  id: chart
  property var matches: []
  property color foreground: "#eeeeee"
  property string fontFamily: Style.font.family
  readonly property var series: Array.isArray(matches) ? matches.slice(0,5).reverse() : []
  width: parent ? parent.width : 0
  visible: series.length > 0
  spacing: Style.space(6)
  Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: "Estimated rating trend · oldest → latest"; color: chart.foreground; font.family: chart.fontFamily; font.pixelSize: Style.font.caption; opacity: 0.65 }
  Row {
    width: parent.width; spacing: Style.space(8)
    Repeater {
      model: chart.series
      delegate: Column {
        required property var modelData
        readonly property real rating: /^\d+(\.\d+)?\*?$/.test(String(modelData.rating)) ? Number(String(modelData.rating).replace("*","")) : -1
        width: (chart.width-Style.space(8)*(chart.series.length-1))/chart.series.length
        spacing: Style.space(4)
        Accessible.role: Accessible.StaticText
        Accessible.name: String(modelData.date || "") + ": estimated rating " + (rating >= 0 && rating <= 10 ? rating : "unavailable")
        Item {
          width: parent.width; height: Style.space(42)
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: rating >= 0 && rating <= 10 ? parent.height*rating/10 : Style.space(2); radius: Style.space(2); color: chart.foreground; opacity: rating < 0 ? 0.15 : 0.45 }
        }
        Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; textFormat: Text.PlainText; text: rating >= 0 && rating <= 10 ? rating.toFixed(1)+"*" : "—"; color: chart.foreground; font.family: chart.fontFamily; font.pixelSize: Style.font.caption }
      }
    }
  }
}
