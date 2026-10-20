import QtQuick

// Keep one image slot, including while a missing or rejected image falls back.
Item {
  id: avatar
  property string imageUrl: ""
  property string resultType: "player"
  property color foreground: "#eeeeee"
  property string fontFamily: "Sans Serif"
  readonly property bool fallbackVisible: photo.status !== Image.Ready
  width: 32
  height: width
  Rectangle {
    anchors.fill: parent
    visible: avatar.fallbackVisible
    radius: width / 5
    color: Qt.rgba(avatar.foreground.r,avatar.foreground.g,avatar.foreground.b,0.07)
    border.color: Qt.rgba(avatar.foreground.r,avatar.foreground.g,avatar.foreground.b,0.12)
  }
  FutRemoteImage {
    id: photo
    anchors.fill: parent
    remoteSource: avatar.imageUrl
    showFallback: false
    fillMode: Image.PreserveAspectFit
    sourceSize: Qt.size(64,64)
    mipmap: true
    smooth: true
  }
  Text {
    anchors.centerIn: parent
    visible: avatar.fallbackVisible
    textFormat: Text.PlainText
    text: avatar.resultType === "player" ? "" : "󰕲"
    font.family: "Symbols Nerd Font, " + avatar.fontFamily
    font.pixelSize: Math.max(12,avatar.height * 0.6)
    color: avatar.foreground
    opacity: 0.7
  }
}
