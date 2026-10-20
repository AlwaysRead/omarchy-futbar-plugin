import QtQuick

// Keyboard equivalent for legacy clickable rows, with a visible focus ring.
MouseArea {
  id: action
  property string actionLabel: "Open details"
  signal activated()
  activeFocusOnTab: enabled && visible
  Accessible.role: Accessible.Button
  Accessible.name: actionLabel
  Accessible.onPressAction: activated()
  Keys.onReturnPressed: activated()
  Keys.onEnterPressed: activated()
  Keys.onSpacePressed: activated()
  onClicked: activated()
  Rectangle {
    anchors.fill: parent
    visible: action.activeFocus
    color: "transparent"
    border.width: 2
    border.color: "#8ab4f8"
    radius: 4
  }
}
