import QtQuick
import "../data/FutPreferences.js" as Preferences

Item {
  visible: false
  property var root: null
  property var storage: null
  property var saveFeedbackTimer: null
  property var resetFeedbackTimer: null
  function setSettingValue(key, val) {
    var payload = {}
    if (root.savedFavorite && typeof root.savedFavorite === "object") {
      for (var k in root.savedFavorite) payload[k] = root.savedFavorite[k]
    }
    payload[key] = val
    root.savedFavorite = payload
    if (root.hostWidget && typeof root.hostWidget === "object") root.hostWidget.savedFavorite = payload
    storage.setText(JSON.stringify(payload, null, 2) + "\n")
    root._queueSetBarWidget(key, val)
    root.settingsJustSaved = true
    if (saveFeedbackTimer) saveFeedbackTimer.restart()
  }

  function restoreSettings(raw) {
    var payload = Preferences.restore(raw)
    root.savedFavorite = payload
    if (root.hostWidget) root.hostWidget.savedFavorite = payload
    storage.setText(JSON.stringify(payload,null,2)+"\n")
    Object.keys(payload).forEach(function(key) {
      if (Preferences.booleans.indexOf(key) >= 0 || Preferences.enums[key]) root._queueSetBarWidget(key,payload[key])
    })
    root.refresh()
  }

  function saveAllSettings() {
    var payload = {}
    if (root.savedFavorite && typeof root.savedFavorite === "object") {
      for (var k in root.savedFavorite) payload[k] = root.savedFavorite[k]
    }
    payload.tabLabelStyle = root.tabLabelStyle
    payload.barWidgetMode = root.barWidgetMode
    payload.kickoffTimeFormat = root.kickoffTimeFormat
    payload.timeFormat = root.timeFormat
    payload.enableNotifications = root.enableNotifications
    payload.notifyAudio = root.notifyAudio
    payload.notifyGoals = root.notifyGoals
    payload.notifyEvents = root.notifyEvents
    payload.notifyScope = root.notifyScope
    payload.antiSpoiler = root.antiSpoiler
    payload.showOdds = root.showOdds
    payload.livePollRate = root.livePollRate
    payload.enableTrending = root.enableTrending
    if (!Array.isArray(payload.tabOrder) || payload.tabOrder.length === 0) {
      var currentTabs = root.allFollowedTabs()
      if (currentTabs.length > 0) {
        payload.tabOrder = currentTabs
        payload.followedTeams = currentTabs
      }
    }
    root.savedFavorite = payload
    if (root.hostWidget && typeof root.hostWidget === "object") root.hostWidget.savedFavorite = payload
    storage.setText(JSON.stringify(payload, null, 2) + "\n")
    var keys = ["tabLabelStyle", "barWidgetMode", "kickoffTimeFormat", "timeFormat",
      "enableNotifications", "notifyGoals", "notifyEvents", "notifyAudio", "notifyScope",
      "antiSpoiler", "showOdds", "livePollRate", "enableTrending"]
    for (var i = 0; i < keys.length; i++) {
      root._queueSetBarWidget(keys[i], payload[keys[i]])
    }
    root.settingsJustSaved = true
    saveFeedbackTimer.restart()
    root.notify("Settings Confirmed", "Preferences saved and applied to desktop bar", "󰄬")
  }

  function confirmAllSettings() {
    root.saveAllSettings()
    if (!root.needsTeam) {
      root.editingTeam = false
      root.addingTeam = false
    }
  }

  function resetAllSettings() {
    var payload = {}
    if (root.savedFavorite && typeof root.savedFavorite === "object") {
      for (var k in root.savedFavorite) payload[k] = root.savedFavorite[k]
    }
    payload.tabLabelStyle = "abbrev"
    payload.barWidgetMode = "icon"
    payload.kickoffTimeFormat = "24h"
    payload.timeFormat = "24h"
    payload.enableNotifications = true
    payload.notifyAudio = false
    payload.snoozeUntil = 0
    payload.notifyGoals = true
    payload.notifyEvents = true
    payload.notifyScope = "primary"
    payload.antiSpoiler = false
    payload.showOdds = true
    payload.livePollRate = 10
    payload.enableTrending = true
    payload.reducedMotion = false; payload.density = "comfortable"
    payload.reminderMinutes = 0; payload.quietHours = false
    payload.quietStart = 22; payload.quietEnd = 8
    payload.notifySchedule = false; payload.notifyLineups = false; payload.mutedClubs = []
    root.savedFavorite = payload
    if (root.hostWidget && typeof root.hostWidget === "object") root.hostWidget.savedFavorite = payload
    storage.setText(JSON.stringify(payload, null, 2) + "\n")
    var keys = ["tabLabelStyle", "barWidgetMode", "kickoffTimeFormat", "timeFormat",
      "enableNotifications", "notifyGoals", "notifyEvents", "notifyAudio", "notifyScope",
      "antiSpoiler", "showOdds", "livePollRate", "enableTrending"]
    for (var i = 0; i < keys.length; i++) {
      root._queueSetBarWidget(keys[i], payload[keys[i]])
    }
    root.settingsJustReset = true
    resetFeedbackTimer.restart()
    root.notify("Settings Reset", "All preferences have been restored to defaults", "󰦛")
  }
}
