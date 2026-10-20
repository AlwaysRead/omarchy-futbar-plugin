import QtQuick
import qs.Commons

// Brief success feedback at the end of a section; failures stay in its status row.
Text {
  id: label
  property double updatedAt: 0
  property color foreground: "#eeeeee"
  property string fontFamily: Style.font.family
  property bool recent: false
  width: parent ? parent.width : 0
  visible: recent && updatedAt > 0
  text: updatedAt > 0 ? "Updated " + Qt.formatDateTime(new Date(updatedAt), "hh:mm:ss") : ""
  textFormat: Text.PlainText
  color: foreground
  opacity: 0.35
  font.family: fontFamily
  font.pixelSize: Math.max(1, Style.font.caption - 1)
  horizontalAlignment: Text.AlignRight
  function updateVisibility() {
    var remaining = updatedAt + 5000 - Date.now()
    recent = updatedAt > 0 && remaining > 0
    expiry.stop()
    if (recent) { expiry.interval = Math.max(1,remaining); expiry.start() }
  }
  onUpdatedAtChanged: updateVisibility()
  Component.onCompleted: updateVisibility()
  Timer { id: expiry; onTriggered: label.recent = false }
}
