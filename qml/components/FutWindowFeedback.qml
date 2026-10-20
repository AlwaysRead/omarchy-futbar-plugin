import QtQuick
import qs.Commons

// One transient, pinned window footer for the currently visible request context.
Text {
  id: feedback
  property var requests: []
  property double fallbackUpdatedAt: 0
  property string contextKey: ""
  property color foreground: "#eeeeee"
  property string fontFamily: Style.font.family
  property bool recent: false
  readonly property string snapshot: JSON.stringify({context:contextKey, fallback:fallbackUpdatedAt, states:requests.map(function(r) {
    return r ? {loading:!!(r.loading !== undefined ? r.loading : r.running), error:String(r.error !== undefined ? r.error : r.errorText || ""), updatedAt:Number(r.updatedAt !== undefined ? r.updatedAt : r.lastSucceededAt || 0)} : {loading:false,error:"",updatedAt:0}
  })})
  visible: enabled && recent
  textFormat: Text.PlainText
  color: foreground
  opacity: 0.35
  font.family: fontFamily
  font.pixelSize: Math.max(1, Style.font.caption - 1)
  horizontalAlignment: Text.AlignRight
  elide: Text.ElideRight
  function updateFeedback() {
    expiry.stop()
    recent = false
    if (!enabled) return
    var data = JSON.parse(snapshot)
    var latest = data.fallback
    var loading = false, cachedFailure = false
    data.states.forEach(function(s) {
      latest = Math.max(latest,s.updatedAt)
      loading = loading || s.loading
      cachedFailure = cachedFailure || !!s.error
    })
    var stamp = latest > 0 ? Qt.formatDateTime(new Date(latest),"hh:mm:ss") : ""
    var remaining = 5000
    if (loading) text = latest > 0 ? "Refreshing cached data…" : "Refreshing…"
    else if (cachedFailure && latest > 0) text = "Showing cached data · updated " + stamp
    else if (latest > 0) { text = "Updated " + stamp; remaining = latest + 5000 - Date.now() }
    else { text = ""; return }
    recent = remaining > 0
    if (recent) { expiry.interval = Math.max(1,remaining); expiry.start() }
  }
  onSnapshotChanged: updateFeedback()
  onEnabledChanged: updateFeedback()
  Component.onCompleted: updateFeedback()
  Timer { id: expiry; onTriggered: feedback.recent = false }
}
