import QtQuick
import Quickshell.Io
import "../services/FutNetwork.js" as Network

// Compatibility adapter for existing parsers: shared lifecycle and failure state.
Process {
  id: worker
  property string requestContext: ""
  property int contextVersion: 0
  property int launchedVersion: -1
  readonly property bool responseCurrent: launchedVersion === contextVersion
  property string errorText: ""
  property double lastSucceededAt: 0
  property double retryAt: 0
  property int failures: 0
  property bool timedOut: false
  function retry() {
    if (running || Date.now() < retryAt || !command.length) return false
    running = true
    return true
  }
  onRequestContextChanged: {
    contextVersion++
    lastSucceededAt = 0; errorText = ""; retryAt = 0; failures = 0
    if (running) running = false
  }
  onRunningChanged: {
    if (running) {
      launchedVersion = contextVersion; errorText = ""; timedOut = false
      watchdog.restart()
    } else watchdog.stop()
  }
  property Timer watchdog: Timer {
    interval: 32000
    onTriggered: {
      worker.timedOut = true
      if (worker.running) worker.signal(9)
      else worker.errorText = "Could not start the request helper. Check python3."
    }
  }
  onExited: function(code, status) {
    watchdog.stop()
    if (!responseCurrent) return
    var output = worker.stdout && typeof worker.stdout.text === "string" ? worker.stdout.text : ""
    var detail = worker.stderr && typeof worker.stderr.text === "string" ? worker.stderr.text : ""
    if (code === 0 && output.length > 0 && output.length <= 8388608) {
      lastSucceededAt = Date.now(); failures = 0; retryAt = 0; errorText = ""
    } else {
      failures = Math.min(6,failures+1)
      retryAt = Date.now()+Math.min(60000,1000*Math.pow(2,failures))+Math.floor(Math.random()*500)
      errorText = Network.requestError(timedOut ? "timeout" : detail,code)
    }
  }
}
