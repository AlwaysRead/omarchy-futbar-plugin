import QtQuick

Item {
  id: state
  visible: false
  property var scrollItem: null
  property string viewKey: ""
  property string previousKey: ""
  property var positions: ({})
  property var order: []
  function switchView() {
    if (!scrollItem) return
    var next = Object.assign({},positions), keys = order.slice()
    if (previousKey) {
      next[previousKey] = Math.max(0,scrollItem.contentY)
      var index = keys.indexOf(previousKey)
      if (index >= 0) keys.splice(index,1)
      keys.push(previousKey)
    }
    while (keys.length > 64) delete next[keys.shift()]
    positions = next; order = keys; previousKey = viewKey
    restore.restart()
  }
  onViewKeyChanged: switchView()
  onScrollItemChanged: switchView()
  Timer {
    id: restore; interval: 40
    onTriggered: {
      if (!state.scrollItem) return
      var max = Math.max(0,state.scrollItem.contentHeight-state.scrollItem.height)
      state.scrollItem.contentY = Math.min(max,state.positions[state.viewKey] || 0)
    }
  }
}
