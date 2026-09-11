import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: overlay
  property var root: null
  property bool active: false
  property string text: "Fetching data…"
  property int spinnerSize: Style.space(36)

  readonly property color foregroundColor: (root && root.contentForeground !== undefined) ? root.contentForeground : Color.foreground
  readonly property string fontFamily: (root && root.contentFontFamily !== undefined) ? root.contentFontFamily : ""
  readonly property real pulse: (root && root._pulse !== undefined) ? root._pulse : 0.0

  anchors.fill: parent
  visible: opacity > 0
  opacity: active ? 1.0 : 0.0
  z: 99

  Behavior on opacity {
    NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Color.popups.background
    opacity: 0.90
  }

  Column {
    anchors.centerIn: parent
    spacing: Style.space(12)

    Item {
      id: spinnerContainer
      anchors.horizontalCenter: parent.horizontalCenter
      width: overlay.spinnerSize
      height: overlay.spinnerSize

      Canvas {
        id: spinnerCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var cx = width / 2
          var cy = height / 2
          var radius = Math.min(width, height) / 2 - Style.space(3)

          ctx.beginPath()
          ctx.arc(cx, cy, radius, 0, 2 * Math.PI)
          ctx.lineWidth = Style.space(3)
          ctx.strokeStyle = Util.alpha(overlay.foregroundColor, 0.15)
          ctx.stroke()

          ctx.beginPath()
          ctx.arc(cx, cy, radius, -Math.PI / 2, Math.PI / 4)
          ctx.lineWidth = Style.space(3.5)
          ctx.lineCap = "round"
          ctx.strokeStyle = overlay.foregroundColor
          ctx.stroke()
        }
      }

      RotationAnimator on rotation {
        running: overlay.active && overlay.visible
        from: 0
        to: 360
        duration: 850
        loops: Animation.Infinite
      }
    }

    Text {
      textFormat: Text.PlainText
      anchors.horizontalCenter: parent.horizontalCenter
      text: overlay.text
      color: overlay.foregroundColor
      font.family: overlay.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignHCenter
      opacity: 0.6 + 0.4 * overlay.pulse
    }
  }
}
