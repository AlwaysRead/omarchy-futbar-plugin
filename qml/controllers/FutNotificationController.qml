import QtQuick
import Quickshell.Io
import "../data/FutPreferences.js" as Preferences

Item {
  id: notificationController
  visible: false
  property var root: null
  property var queue: []
  readonly property var notifyRequest: internalNotifyRequest
  readonly property var goalSoundProcess: internalGoalSoundProcess
  function notify(title, body, glyph, teamIds) {
    if (!title || root.antiSpoiler || !root.enableNotifications || Preferences.quiet(Date.now(),root.quietHours,root.quietStart,root.quietEnd,root.snoozeUntil)) return
    var muted = root.mutedClubs
    if (Array.isArray(teamIds) && teamIds.some(function(id) { return muted.indexOf(String(id)) >= 0 })) return
    if (!teamIds && root.allFollowedTabs().some(function(t) { return muted.indexOf(String(t.teamId)) >= 0 && t.teamName && String(body || "").indexOf(t.teamName) >= 0 })) return
    var t = String(title).toLowerCase()
    var isGoal = t.indexOf("goal") !== -1
    var isCardOrWhistle = t.indexOf("card") !== -1 || t.indexOf("half") !== -1 || t.indexOf("time") !== -1 || t.indexOf("started") !== -1 || t.indexOf("penalty") !== -1
    var isMatchAlert = isGoal || isCardOrWhistle
    if (isMatchAlert) {
      if (!root.enableNotifications) return
      if (isGoal && !root.notifyGoals) return
      if (isCardOrWhistle && !root.notifyEvents) return
    }
    var cleanTitle = root.sanitizePlainText(String(title)).substring(0, 512)
    var cleanBody = root.sanitizePlainText(String(body || "")).substring(0, 4096)
    if (cleanTitle === "") return
    var args = ["notify-send", "-a", "futbar"]
    var cleanGlyph = root.sanitizePlainText(String(glyph || "")).substring(0, 16)
    if (cleanGlyph !== "") args.push("-h", "string:omarchy-glyph:" + cleanGlyph)
    args.push("--", cleanTitle, cleanBody)
    var q = root._notifyQueue.slice()
    if (q.length >= 32) return
    q.push(args)
    root._notifyQueue = q
    root._runNextNotify()
    var isRedAlert = title && (title.indexOf("Red Card") !== -1 || title.indexOf("Sent Off") !== -1)
    if ((isGoal || isRedAlert) && root.notifyAudio) {
      internalGoalSoundProcess.running = false
      internalGoalSoundProcess.running = true
    }
    if (isMatchAlert) root.activityPulse()
  }

  function _runNextNotify() {
    if (root.antiSpoiler || !root.enableNotifications || Preferences.quiet(Date.now(),root.quietHours,root.quietStart,root.quietEnd,root.snoozeUntil)) { root._notifyQueue = []; return }
    if (internalNotifyRequest.running || root._notifyQueue.length === 0) return
    var q = root._notifyQueue.slice()
    var cmd = q.shift()
    root._notifyQueue = q
    internalNotifyRequest.command = cmd
    internalNotifyRequest.running = true
  }

  Process {
    id: internalNotifyRequest
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._runNextNotify()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root._runNextNotify()
    }
    onExited: function(code) {
      root._runNextNotify()
    }
  }

  Process {
    id: internalGoalSoundProcess
    running: false
    command: ["canberra-gtk-play", "-i", "message-new-instant"]
  }
}
