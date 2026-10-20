import QtQuick
import qs.Commons

// Reserve a separate strip below the scroll viewport, even after text expires.
Item {
  id: footer
  property alias requests: feedback.requests
  property alias fallbackUpdatedAt: feedback.fallbackUpdatedAt
  property alias contextKey: feedback.contextKey
  property alias foreground: feedback.foreground
  property alias fontFamily: feedback.fontFamily
  readonly property bool active: feedback.visible
  readonly property string text: feedback.text
  readonly property real textOpacity: feedback.opacity
  height: Style.space(30)
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 1
    color: feedback.foreground
    opacity: 0.08
    visible: footer.active
  }
  FutWindowFeedback {
    id: feedback
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(5)
  }
}
