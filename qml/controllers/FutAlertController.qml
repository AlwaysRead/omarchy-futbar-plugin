import QtQuick
import Quickshell.Io
import "../data/FutMatches.js" as Matches

Item {
  id: controller
  visible: false
  property string statePath: ""
  property bool enabled: false
  property int reminderMinutes: 0
  property bool scheduleAlerts: false
  property var matches: []
  property var tabs: []
  readonly property string identity: JSON.stringify(tabs)
  property string scope: "primary"
  property double sourceUpdatedAt: 0
  property bool sourcePartial: false
  property bool loaded: false
  property var sent: ({})
  property var scheduleSnapshot: ({})
  property string serialized: ""
  signal notification(string title, string body, string glyph, var teamIds)
  FileView {
    id: store
    path: controller.statePath
    atomicWrites: true; printErrors: false
    onLoaded: {
      try {
        var raw = text()
        if (raw.length > 65536) throw new Error("size")
        var data = JSON.parse(raw), clean = {}, now = Date.now()
        if (data && data.version === 1 && data.sent && typeof data.sent === "object") {
          Object.keys(data.sent).slice(-256).forEach(function(key) {
            var stamp = data.sent[key]
            if (key.length <= 160 && typeof stamp === "number" && stamp <= now && now-stamp < 8*86400000) clean[key] = stamp
          })
        }
        controller.sent = clean
      } catch(e) { controller.sent = ({}) }
      controller.loaded = true
      controller.check()
    }
    onLoadFailed: { controller.loaded = true; controller.check() }
  }
  function inScope(match) {
    return scope !== "primary" || tabs.length > 0 && Matches.followed(match,[tabs[0]])
  }
  function check() {
    if (!enabled || !loaded || sourcePartial || !sourceUpdatedAt || Date.now()-sourceUpdatedAt > 10*60000) return
    var now = Date.now(), sent = Object.assign({},controller.sent)
    Matches.dueReminders(matches,reminderMinutes,sent,now).filter(inScope).forEach(function(m) {
      sent[Matches.reminderKey(m,reminderMinutes)] = now
      controller.notification("Kickoff reminder",m.homeName+" vs "+m.awayName+" · "+reminderMinutes+" minutes before kickoff","󱎫",[m.homeId,m.awayId])
    })
    var clean = {}, keys = Object.keys(sent).filter(function(k) { return now-sent[k] < 8*86400000 }).slice(-256)
    keys.forEach(function(k) { clean[k] = sent[k] }); controller.sent = clean
    var encoded = JSON.stringify({version:1,sent:clean})+"\n"
    if (encoded !== serialized) { serialized = encoded; store.setText(encoded) }
  }
  function observe() {
    if (!sourceUpdatedAt || sourcePartial) return
    var previous = scheduleSnapshot, next = Object.create(null), now = Date.now()
    matches.slice(0,1000).forEach(function(m) {
      var old = Object.prototype.hasOwnProperty.call(previous,m.id) ? previous[m.id] : null
      if (enabled && scheduleAlerts && old && inScope(m) && m.kickoff >= now-86400000 &&
          (old.date !== m.date || old.statusName !== m.statusName && (Matches.cancelled(m) || /POSTPON|CANCEL|SUSPEND|ABANDON/i.test(old.statusName)))) {
        controller.notification("Fixture update",m.homeName+" vs "+m.awayName+" · "+m.status+" · "+Qt.formatDateTime(new Date(m.date),"ddd d MMM hh:mm"),"󰃭",[m.homeId,m.awayId])
      }
      next[m.id] = {date:m.date,statusName:m.statusName}
    })
    scheduleSnapshot = next
    check()
  }
  onSourceUpdatedAtChanged: observe()
  onIdentityChanged: scheduleSnapshot = ({})
  onEnabledChanged: if (enabled) check()
  Timer { interval: 30000; repeat: true; running: controller.enabled && controller.reminderMinutes > 0; onTriggered: controller.check() }
}
