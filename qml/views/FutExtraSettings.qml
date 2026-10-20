import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../data/FutPreferences.js" as Preferences
import "../services/FutNetwork.js" as Network

Column {
  id: view
  property var root: null
  property string message: ""
  property bool restorePending: false
  property string restorePreview: ""
  property bool showDiagnostics: false
  property string diagnostics: ""
  width: parent ? parent.width : 0
  spacing: Style.space(12)
  component Action: Button {
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText || text || "Action"

    foreground: root.contentForeground; accent: root.contentForeground
    fontFamily: root.contentFontFamily; fontSize: Style.font.caption
    focusable: true
  }
  component Caption: Text {
    width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
    color: root.contentForeground; font.family: root.contentFontFamily
    font.pixelSize: Style.font.caption
  }
  FileView {
    id: backupFile
    path: root ? root.favoritePath.replace(/[^/]*$/, "futbar-settings-backup.json") : ""
    atomicWrites: true; printErrors: false
    onLoaded: {
      if (!view.restorePending) return
      view.restorePending = false
      try {
        var validated = Preferences.restore(text())
        view.restorePreview = Preferences.backup(validated)
        view.message = "Backup checked. Confirm restore to replace your followed clubs and saved preferences."
      } catch (e) { view.message = "Backup rejected: " + String(e.message).slice(0,160) }
    }
    onLoadFailed: { if (view.restorePending) view.message = "No readable backup at ~/.local/state/omarchy/futbar-settings-backup.json"; view.restorePending = false }
    onSaved: view.message = "Backup saved to ~/.local/state/omarchy/futbar-settings-backup.json"
    onSaveFailed: view.message = "Could not save the settings backup."
  }
  Caption { text: "Reminders & notification controls"; font.bold: true; font.pixelSize: Style.font.bodySmall }
  Caption { text: "Optional reminders and fixture alerts refresh followed schedules every five minutes while the shell runs. Reminders need FutBar running before their due time."; opacity: 0.65 }
  Flow {
    width: parent.width; spacing: Style.space(6)
    Repeater { model: [0,5,15,30]; delegate: Action { required property int modelData; text: modelData ? modelData+" min" : "Reminders off"; selected: root.reminderMinutes === modelData; onClicked: root.setSettingValue("reminderMinutes",modelData) } }
  }
  Action { text: "Fixture changes: " + (root.notifySchedule ? "On" : "Off"); selected: root.notifySchedule; onClicked: root.setSettingValue("notifySchedule",!root.notifySchedule) }
  Action { text: "Lineup available alerts: " + (root.notifyLineups ? "On" : "Off"); selected: root.notifyLineups; onClicked: root.setSettingValue("notifyLineups",!root.notifyLineups) }
  Caption { text: "Lineup availability is based on ESPN supplying starting players; it does not certify that the lineup is official."; opacity: 0.65 }
  Flow {
    width: parent.width; spacing: Style.space(6)
    Action { text: "Quiet hours: " + (root.quietHours ? "On" : "Off"); selected: root.quietHours; onClicked: root.setSettingValue("quietHours",!root.quietHours) }
    Action { text: "From " + String(root.quietStart).padStart(2,"0") + ":00"; enabled: root.quietHours; onClicked: root.setSettingValue("quietStart",(root.quietStart+1)%24) }
    Action { text: "Until " + String(root.quietEnd).padStart(2,"0") + ":00"; enabled: root.quietHours; onClicked: root.setSettingValue("quietEnd",(root.quietEnd+1)%24) }
  }
  Caption { text: "Times use your local timezone. Equal start/end hours disable the quiet period."; opacity: 0.65 }
  Flow {
    width: parent.width; spacing: Style.space(6)
    Action { text: "Snooze 1 hour"; onClicked: { root.setSettingValue("snoozeUntil",Date.now()+3600000); view.message = "Notifications snoozed for one hour." } }
    Action { text: "Resume alerts"; onClicked: { root.setSettingValue("snoozeUntil",0); view.message = "Snooze cleared. Quiet hours and alert preferences still apply." } }
  }
  Caption { text: "Mute individual clubs"; font.bold: true }
  Flow {
    width: parent.width; spacing: Style.space(6)
    Repeater {
      model: root.allFollowedTabs().filter(function(t) { return !t.followLeague && !!t.teamId })
      delegate: Action {
        required property var modelData
        text: root.sanitizePlainText(modelData.teamName) + (root.mutedClubs.indexOf(String(modelData.teamId)) >= 0 ? " · Muted" : " · Alerts")
        selected: root.mutedClubs.indexOf(String(modelData.teamId)) >= 0
        onClicked: root.toggleClubMute(modelData.teamId)
      }
    }
  }
  Caption { text: "Display & accessibility"; font.bold: true; font.pixelSize: Style.font.bodySmall }
  Flow {
    width: parent.width; spacing: Style.space(6)
    Action { text: "Compact"; selected: root.density === "compact"; onClicked: root.setSettingValue("density","compact") }
    Action { text: "Comfortable"; selected: root.density === "comfortable"; onClicked: root.setSettingValue("density","comfortable") }
    Action { text: "Reduced motion: " + (root.reducedMotion ? "On" : "Off"); selected: root.reducedMotion; onClicked: root.setSettingValue("reducedMotion",!root.reducedMotion) }
  }
  Caption { text: "Shortcuts: / Search · n News · l Trending · m Matches · t Standings · s Statistics · p Settings · r Refresh · 1–9 Followed tabs · arrows Navigate · Enter Open · Escape Back. Tab moves between focusable controls."; opacity: 0.75 }
  Caption { text: "Backup & diagnostics"; font.bold: true; font.pixelSize: Style.font.bodySmall }
  Flow {
    width: parent.width; spacing: Style.space(6)
    Action { text: "Save settings backup"; onClicked: { try { backupFile.setText(Preferences.backup(root.savedFavorite)) } catch(e) { view.message = "Backup could not be created: " + String(e.message).slice(0,160) } } }
    Action { text: "Check saved backup"; onClicked: { view.restorePending = true; view.restorePreview = ""; backupFile.reload() } }
    Action { text: "Confirm restore"; visible: view.restorePreview !== ""; onClicked: { try { root.restoreSettings(view.restorePreview); view.restorePreview = ""; view.message = "Settings restored." } catch(e) { view.message = "Restore rejected: " + String(e.message).slice(0,160) } } }
    Action { text: "Diagnostics"; onClicked: { view.showDiagnostics = !view.showDiagnostics; if (view.showDiagnostics) { view.diagnostics = root.diagnosticsReport(); dependencies.running = true } } }
  }
  Process {
    id: dependencies
    command: ["python3","-B","-E","-s",Network.helperPath("diagnostics.py")]
    stdout: StdioCollector { onStreamFinished: { try { var data = JSON.parse(text); view.diagnostics += "\nDependencies: " + JSON.stringify(data) } catch(e) { view.diagnostics += "\nDependency check unavailable." } } }
  }
  TextArea {
    visible: view.showDiagnostics
    width: parent.width; readOnly: true; textFormat: TextEdit.PlainText
    text: view.diagnostics; wrapMode: TextEdit.Wrap
    color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption
    background: Rectangle { color: Util.alpha(root.contentForeground,0.04); radius: Style.space(6) }
  }
  Caption { text: view.message; visible: text !== "" }
}
