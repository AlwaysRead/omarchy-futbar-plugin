import QtQuick
import qs.Commons
import qs.Ui
import "../data/FutComparison.js" as Comparison

Column {
  id: view
  property var root: null
  property string message: ""
  readonly property var profiles: root ? root.comparisonProfiles : []
  width: parent ? parent.width : 0
  spacing: Style.space(8)
  Flow {
    width: parent.width; spacing: Style.space(6)
    Button {
      Accessible.role: Accessible.Button
      Accessible.name: tooltipText || text || "Action"

      text: "Pin for comparison"
      focusable: true; foreground: root.contentForeground; accent: root.contentForeground
      enabled: !root.searchClubLoading && !root.searchPlayerLoading && !root.playerStatsLoading
      onClicked: view.message = root.pinComparison()
    }
    Button {
      Accessible.role: Accessible.Button
      Accessible.name: tooltipText || text || "Action"
 text: "Clear comparison"; visible: view.profiles.length > 0; focusable: true; foreground: root.contentForeground; accent: root.contentForeground; onClicked: { root.comparisonProfiles = []; view.message = "" } }
  }
  Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: view.message; visible: text !== ""; color: root.contentForeground; font.pixelSize: Style.font.caption }
  Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: "Pinned snapshots · " + view.profiles.length + "/2. Open another profile and pin it to compare."; visible: view.profiles.length > 0; color: root.contentForeground; font.pixelSize: Style.font.caption; opacity: 0.65 }
  Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: "The season/competition contexts differ or are unknown. Values are shown separately; no rankings or per-90 estimates are calculated."; visible: view.profiles.length === 2 && !Comparison.compatible(view.profiles[0],view.profiles[1]); color: root.contentForeground; font.pixelSize: Style.font.caption }
  Row {
    width: parent.width; spacing: Style.space(8)
    Repeater {
      model: view.profiles
      delegate: Rectangle {
        required property var modelData
        width: (view.width-Style.space(8))/2
        implicitHeight: column.implicitHeight+Style.space(20)
        radius: Style.space(8); color: Util.alpha(root.contentForeground,0.04)
        Column {
          id: column
          anchors.centerIn: parent; width: parent.width-Style.space(16); spacing: Style.space(6)
          Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: modelData.name; color: root.contentForeground; font.bold: true; font.pixelSize: Style.font.caption }
          Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: modelData.context || "Context unavailable"; color: root.contentForeground; opacity: 0.6; font.pixelSize: Style.font.caption }
          Repeater {
            model: modelData.values
            delegate: Text { required property var modelData; width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: modelData.label+": "+modelData.value; color: root.contentForeground; font.pixelSize: Style.font.caption }
          }
          Text { width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText; text: modelData.form ? "Recent form: "+modelData.form.split("").join(" · ") : ""; visible: text !== ""; color: root.contentForeground; font.pixelSize: Style.font.caption }
        }
      }
    }
  }
}
