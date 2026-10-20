import QtQuick
import qs.Commons

Rectangle {
  id: photo
  property string imageUrl: ""
  property bool fetchingEnabled: true
  property color foreground: "#eeeeee"
  color: Util.alpha(foreground, 0.06)
  radius: Style.space(8)
  clip: true
  Text {
    anchors.centerIn: parent
    text: "▧"
    textFormat: Text.PlainText
    color: photo.foreground
    opacity: 0.35
    font.pixelSize: Math.min(photo.height / 3, Style.space(30))
    visible: image.status !== Image.Ready
  }
  FutRemoteImage {
    id: image
    anchors.fill: parent
    newsPhoto: true
    showFallback: false
    remoteSource: photo.visible && photo.fetchingEnabled ? photo.imageUrl : ""
    sourceSize: Qt.size(640, 640)
    fillMode: Image.PreserveAspectCrop
  }
}
