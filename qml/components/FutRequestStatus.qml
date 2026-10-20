import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: status
  property var request: null
  property string error: ""
  property bool hasData: false
  property color foreground: "#eeeeee"
  property string fontFamily: Style.font.family
  property double now: Date.now()
  readonly property string failure: error || (request ? request.errorText || "" : "")
  readonly property int retrySeconds: request ? Math.max(0,Math.ceil((request.retryAt-now)/1000)) : 0
  signal retryRequested()
  width: parent ? parent.width : 0
  spacing: Style.space(6)
  visible: !!failure || !!(request && (request.running || request.lastSucceededAt))
  Text {
    width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
    text: status.request && status.request.running ? (status.hasData ? "Refreshing cached data…" : "Loading…") : status.failure ? status.failure + (status.hasData ? " Showing cached data." : "") :
      status.request && status.request.lastSucceededAt ? "Updated " + Qt.formatDateTime(new Date(status.request.lastSucceededAt),"hh:mm") : ""
    color: status.foreground; font.family: status.fontFamily; font.pixelSize: Style.font.caption
    Accessible.role: Accessible.StaticText
    Accessible.name: text
  }
  Button {
    visible: !!status.failure
    text: status.request && status.request.running ? "Loading…" : status.retrySeconds ? "Retry in " + status.retrySeconds + "s" : "Retry"
    enabled: !!status.request && !status.request.running && status.retrySeconds === 0
    focusable: true; foreground: status.foreground; accent: status.foreground
    fontFamily: status.fontFamily; fontSize: Style.font.caption
    onClicked: status.retryRequested()
  }
  Timer { interval: 1000; repeat: true; running: status.visible && !!status.failure; onTriggered: status.now = Date.now() }
}
