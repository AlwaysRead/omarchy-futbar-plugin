import QtQuick
import Quickshell.Io
import "../services/FutNetwork.js" as Network

// On-demand, single-flight requests. Context changes invalidate all old output.
Item {
  id: request
  visible: false
  property string url: ""
  property bool active: false
  property string responseKind: ""
  property var result: null
  property string error: ""
  property bool loading: false
  property bool timedOut: false
  property double updatedAt: 0
  property int generation: 0
  property int launchedGeneration: -1
  property int failures: 0
  property string launchedUrl: ""
  property double retryAt: 0
  property double now: Date.now()
  readonly property int retryInSeconds: Math.max(0, Math.ceil((retryAt - now) / 1000))
  readonly property bool stale: result !== null && error !== ""
  function invalidate() {
    generation++
    result = null
    error = ""
    updatedAt = 0
    failures = 0
    retryAt = 0
    loading = false
    if (worker.running) worker.running = false
    wake.restart()
  }
  function refresh() {
    if (!active || !url || worker.running || Date.now() < retryAt) return
    launchedGeneration = generation
    launchedUrl = url
    loading = true
    timedOut = false
    worker.command = Network.jsonCommand([url], 2097152, 15)
    worker.running = true
    deadline.restart()
  }
  onUrlChanged: invalidate()
  onActiveChanged: {
    if (active) wake.restart()
    else { generation++; loading = false; worker.running = false }
  }
  Component.onCompleted: wake.restart()
  Timer { interval: 1000; repeat: true; running: request.active && request.error !== ""; onTriggered: request.now = Date.now() }
  Timer { interval: 65000; repeat: true; running: request.active && request.error !== ""; onTriggered: request.refresh() }
  Timer { id: wake; interval: 100; onTriggered: { if (worker.running) restart(); else if (!request.updatedAt || Date.now() - request.updatedAt > 300000) request.refresh() } }
  Timer { interval: 300000; repeat: true; running: request.active; onTriggered: request.refresh() }
  Timer {
    id: deadline
    interval: 17000
    onTriggered: {
      if (request.launchedGeneration !== request.generation || !request.active) return
      request.timedOut = true
      if (worker.running) worker.signal(9)
      else if (request.loading) {
        request.loading = false
        request.error = "Could not start the Python request helper. Check that python3 is installed."
      }
    }
  }
  Process {
    id: worker
    stdout: StdioCollector { id: output }
    stderr: StdioCollector { id: errors }
    onExited: function(code, status) {
      deadline.stop()
      if (request.launchedGeneration !== request.generation || request.launchedUrl !== request.url || !request.active) return
      request.loading = false
      try {
        if (code !== 0 || !output.text || output.text.length > 2097152) throw new Error("request")
        var parsed = JSON.parse(output.text)
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("shape")
        if (request.responseKind === "news" && !Array.isArray(parsed.articles)) throw new Error("shape")
        if (request.responseKind === "gamelog" && (!Array.isArray(parsed.names) || !Array.isArray(parsed.seasonTypes))) throw new Error("shape")
        request.result = parsed
        request.updatedAt = Date.now()
        request.error = ""
        request.failures = 0
        request.retryAt = 0
      } catch (e) {
        request.failures = Math.min(request.failures + 1, 6)
        request.now = Date.now()
        request.retryAt = request.now + Math.min(60000, 1000 * Math.pow(2, request.failures)) + Math.floor(Math.random() * 500)
        request.error = e.message === "shape" ? "ESPN returned unsupported data. Retry later." : Network.requestError(request.timedOut ? "timeout" : errors.text, code)
      }
    }
  }
}
