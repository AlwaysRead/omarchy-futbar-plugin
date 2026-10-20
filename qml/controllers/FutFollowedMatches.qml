import QtQuick
import "../data/FutMatches.js" as Matches

Item {
  id: controller
  visible: false
  property var tabs: []
  property bool active: false
  property var matches: []
  property var queue: []
  property var pending: []
  property int index: 0
  property bool loading: false
  property string error: ""
  property double updatedAt: 0
  property int failedRequests: 0
  property string identity: JSON.stringify(tabs)
  signal refreshed()
  function refresh() {
    if (!active || loading) return
    queue = Matches.plan(tabs, Date.now())
    pending = []; index = 0; failedRequests = 0; error = ""
    loading = queue.length > 0
    if (loading) next.restart()
    else { matches = []; updatedAt = Date.now(); refreshed() }
  }
  function advance(failed) {
    if (failed) failedRequests++
    index++
    if (index >= queue.length) {
      if (failedRequests === 0) matches = pending
      else matches = Matches.relevant(Matches.merge(matches, pending),Date.now()).filter(function(m) { return Matches.followed(m, controller.tabs) })
      loading = false
      if (failedRequests) error = "Some schedules could not be refreshed. Showing available and cached matches."
      updatedAt = Date.now()
      refreshed()
    } else next.restart()
  }
  onIdentityChanged: {
    request.url = ""; loading = false; matches = []; updatedAt = 0
    if (active) refresh()
  }
  onActiveChanged: {
    if (active) { if (!updatedAt || Date.now()-updatedAt > 300000) refresh() }
    else { request.url = ""; loading = false }
  }
  Component.onCompleted: if (active) refresh()
  Timer { id: next; interval: 20; onTriggered: if (controller.active && controller.loading) { request.url = controller.queue[controller.index].url; request.refresh() } }
  Timer { interval: 300000; repeat: true; running: controller.active; onTriggered: controller.refresh() }
  FutApiRequest {
    id: request
    active: controller.active && controller.loading && url !== ""
    responseKind: "events"
    byteLimit: 5242880
    onUpdatedAtChanged: {
      if (!updatedAt || !controller.loading) return
      var league = controller.queue[controller.index].league
      var incoming = Matches.relevant(Matches.matches(result, league),Date.now()).filter(function(m) { return Matches.followed(m, controller.tabs) })
      controller.pending = Matches.merge(controller.pending, incoming)
      controller.advance(false)
    }
    onErrorChanged: if (error && controller.loading) controller.advance(true)
  }
}
