import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Column {
  readonly property bool dropdownOpen: (leagueDropdown && (leagueDropdown.popupOpen || leagueDropdown.activeFocus))
    || (teamDropdown && (teamDropdown.popupOpen || teamDropdown.activeFocus))
  id: settingsView
  property var root: null
  visible: root ? (root.needsTeam || root.editingTeam) : false
  width: parent ? parent.width : 0
  spacing: Style.space(14)

  component SettingToggleRow: Item {
    id: sRow
    property string title: ""
    property string description: ""
    property bool checked: false
    signal toggled()

    width: parent ? parent.width : Style.space(300)
    implicitHeight: Math.max(Style.space(34), col.implicitHeight)

    Column {
      id: col
      anchors.left: parent.left
      anchors.right: sw.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        textFormat: Text.PlainText
        text: sRow.title
        color: root.contentForeground
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        visible: sRow.description !== ""
        text: sRow.description
        color: Qt.darker(root.contentForeground, 1.4)
        font.family: root.contentFontFamily
        font.pixelSize: Style.space(9)
      }
    }

    ToggleSwitch {
      id: sw
      anchors.right: parent.right
      anchors.rightMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
      checked: sRow.checked
      foreground: root.contentForeground
      accent: root.favoriteTeamAccent || Color.accent
      onToggled: sRow.toggled()
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: sRow.toggled()
    }
  }


  component SettingsCard: Rectangle {
    id: scCard
    property string icon: ""
    property string title: ""
    property bool expanded: true
    default property alias contentData: cardContent.data

    width: parent ? parent.width : 0
    implicitHeight: cardCol.implicitHeight
    radius: Style.cornerRadius
    color: Util.alpha(root.contentForeground, 0.04)
    border.width: Style.spacing.hairline
    border.color: Util.alpha(root.contentForeground, 0.12)

    Column {
      id: cardCol
      width: parent.width
      spacing: 0

      Rectangle {
        width: parent.width
        height: Style.space(38)
        radius: Style.cornerRadius
        color: headerMouse.containsMouse ? Util.alpha(root.contentForeground, 0.07) : "transparent"

        Item {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)

          Row {
            anchors.left: parent.left
            anchors.right: headerArrow.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: scCard.icon
              font.pixelSize: Style.font.body
              color: root.favoriteTeamAccent || root.contentForeground
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(28)
              textFormat: Text.PlainText
              text: scCard.title
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              elide: Text.ElideRight
            }
          }

          Text {
            id: headerArrow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: scCard.expanded ? "󰅃" : "󰅂"
            font.pixelSize: Style.font.caption
            color: Qt.darker(root.contentForeground, 1.5)
          }
        }

        MouseArea {
          id: headerMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: scCard.expanded = !scCard.expanded
        }
      }

      Item {
        width: parent.width
        implicitHeight: cardContent.implicitHeight + Style.space(16)
        visible: scCard.expanded

        Column {
          id: cardContent
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          anchors.top: parent.top
          anchors.topMargin: Style.space(4)
          spacing: Style.space(12)
        }
      }
    }
  }


          // Settings Header with Back Navigation
          Row {
            width: parent.width
            spacing: Style.space(10)

            Button {
              visible: !root.needsTeam
              iconText: "󰅁"
              text: "Back"
              tooltipText: "Return to match center"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(4)
              onClicked: {
                root.editingTeam = false
                root.addingTeam = false
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.addingTeam ? "Follow Club or Tournament" : "Settings & Preferences"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }

          // CARD 1: Follow New Club or Tournament (always on top)
          SettingsCard {
            id: followCard
            icon: "󰐕"
            title: root.addingTeam ? "Add Club or Tournament" : "Follow New Club or Tournament"
            expanded: true

            Column {
              width: parent.width
              spacing: Style.space(12)

              SearchableDropdown {
                id: leagueDropdown
                width: parent.width
                label: "Tournament / League"
                placeholderText: "Search league or tournament…"
                emptyText: "No leagues or tournaments found"
                fontFamily: root.contentFontFamily
                options: root.leagues
                value: root.selectedLeague
                onChanged: function(value) { root.selectLeague(value) }
              }

              Button {
                id: leagueFollowToggle
                width: parent.width
                anchors.horizontalCenter: parent.horizontalCenter
                iconText: root.pickerLeagueOnly ? "󰴆" : "󰒭"
                text: root.pickerLeagueOnly ? "Following whole tournament / league" : "Follow whole tournament instead"
                tooltipText: "Track every match in the selected tournament or league instead of one club"
                fontFamily: root.contentFontFamily
                foreground: root.contentForeground
                accent: root.contentForeground
                fontSize: Style.font.caption
                iconSize: Style.font.caption
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(4)
                selected: root.pickerLeagueOnly
                enabled: root.selectedLeague !== ""
                onClicked: root.pickerLeagueOnly = !root.pickerLeagueOnly
              }

              SearchableDropdown {
                id: teamDropdown
                width: parent.width
                visible: !root.pickerLeagueOnly
                label: root.teamsLoading ? "Fetching clubs…" : "Club"
                placeholderText: "Search club…"
                emptyText: "No clubs found"
                fontFamily: root.contentFontFamily
                options: root.teams
                value: root.selectedTeam ? String(root.selectedTeam.value) : ""
                enabled: root.selectedLeague !== "" && !root.teamsLoading
                onChanged: function(value) { root.selectTeam(value) }
              }

              Item {
                width: parent.width
                height: Style.space(50)
                visible: root.teamsLoading && !root.pickerLeagueOnly

                FutLoadingOverlay {
                  root: settingsView.root
                  active: root.teamsLoading && !root.pickerLeagueOnly
                  text: root.sanitizePlainText("Fetching " + root.selectedLeagueName + " clubs…")
                  spinnerSize: Style.space(24)
                }
              }

              Row {
                visible: root.selectedTeam && !root.pickerLeagueOnly
                width: parent.width
                height: Style.space(40)
                spacing: Style.space(10)

                Image {
                  width: Style.space(32)
                  height: width
                  source: root.selectedTeam ? root.selectedTeam.logo : ""
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: 64
                  sourceSize.height: 64
                  mipmap: true
                  smooth: true
                  anchors.verticalCenter: parent.verticalCenter
                  visible: String(source) !== ""
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)
                  Text {
                    textFormat: Text.PlainText
                    text: root.selectedTeam ? String(root.selectedTeam.value) : ""
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: root.selectedLeagueName
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }

              Button {
                visible: root.selectedTeam || root.pickerLeagueOnly
                width: parent.width
                text: root.addingTeam ? "Add to Followed Tabs" : "Confirm Selection"
                fontFamily: root.contentFontFamily
                foreground: root.contentForeground
                accent: root.contentForeground
                onClicked: root.pickerLeagueOnly ? root.confirmLeague() : root.confirmTeam()
              }
            }
          }

          // CARD 2: Display & Formats (shown when not solely adding a team)
          SettingsCard {
            visible: !root.addingTeam
            icon: "󰒓"
            title: "Display & Formats"
            expanded: true

            // Tab Labels Format
            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                text: "Tab Labels Format"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                Button {
                  width: (parent.width - Style.space(12)) / 3
                  text: "3 Letters"
                  tooltipText: "Ultra-compact 3-letter codes (e.g. BAR, UCL, WOL)"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.tabLabelStyle === "abbrev"
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setTabLabelStyle("abbrev")
                }

                Button {
                  width: (parent.width - Style.space(12)) / 3
                  text: "Short"
                  tooltipText: "Short recognizable names (e.g. Barça, UCL, Wolves)"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.tabLabelStyle === "short"
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setTabLabelStyle("short")
                }

                Button {
                  width: (parent.width - Style.space(12)) / 3
                  text: "Full"
                  tooltipText: "Full official names (e.g. Barcelona, UEFA Champions League)"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.tabLabelStyle === "full"
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setTabLabelStyle("full")
                }
              }
            }

            // Top Bar Widget Mode
            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                text: "Top Bar Widget"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                Button {
                  width: (parent.width - Style.space(12)) / 3
                  text: "Icon Only"
                  tooltipText: "Minimal ball icon on desktop bar (󰒸)"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.barWidgetMode === "icon"
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setBarWidgetMode("icon")
                }

                Button {
                  width: (parent.width - Style.space(12)) / 3
                  text: "Live Score"
                  tooltipText: "Show active live match score on desktop bar"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.barWidgetMode === "score"
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setBarWidgetMode("score")
                }

                Button {
                  width: (parent.width - Style.space(12)) / 3
                  text: "Next Match"
                  tooltipText: "Show upcoming fixture and kickoff time on desktop bar"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.barWidgetMode === "next"
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setBarWidgetMode("next")
                }
              }
            }

            // Kickoff Time Format
            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                text: "Kickoff Time Format"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                Button {
                  width: (parent.width - Style.space(12)) / 3
                  text: "24-Hour"
                  tooltipText: "24-hour clock (e.g. 20:00)"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.kickoffTimeFormat === "24h"
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setKickoffTimeFormat("24h")
                }

                Button {
                  width: (parent.width - Style.space(12)) / 3
                  text: "12-Hour"
                  tooltipText: "12-hour clock (e.g. 8:00 PM)"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.kickoffTimeFormat === "12h"
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setKickoffTimeFormat("12h")
                }

                Button {
                  width: (parent.width - Style.space(12)) / 3
                  text: "Relative"
                  tooltipText: "Relative countdown (e.g. in 2h 15m)"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.kickoffTimeFormat === "relative"
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setKickoffTimeFormat("relative")
                }
              }
            }
          }

          // CARD 3: Notifications & Alerts (shown when not solely adding a team)
          SettingsCard {
            visible: !root.addingTeam
            icon: "󰂚"
            title: "Notifications & Alerts"
            expanded: true

            SettingToggleRow {
              title: "Enable Desktop Alerts"
              description: "Send match notifications via notify-send"
              checked: root.enableNotifications
              onToggled: root.setEnableNotifications(!root.enableNotifications)
            }

            SettingToggleRow {
              visible: root.enableNotifications
              title: "Goal Alerts"
              description: "Notifications on goals with scorer and minute"
              checked: root.notifyGoals
              onToggled: root.setNotifyGoals(!root.notifyGoals)
            }

            SettingToggleRow {
              visible: root.enableNotifications
              title: "Red Cards & Match Whistles"
              description: "Alerts on red cards, kickoff, HT, and FT"
              checked: root.notifyEvents
              onToggled: root.setNotifyEvents(!root.notifyEvents)
            }

            Column {
              visible: root.enableNotifications
              width: parent.width
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                text: "Notification Scope"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                Button {
                  width: (parent.width - Style.space(6)) / 2
                  text: "Primary Club Only"
                  tooltipText: "Alerts only for your primary desktop bar club"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.notifyScope === "primary"
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setNotifyScope("primary")
                }

                Button {
                  width: (parent.width - Style.space(6)) / 2
                  text: "All Followed Tabs"
                  tooltipText: "Alerts for all followed clubs and tournaments"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.notifyScope === "all"
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setNotifyScope("all")
                }
              }
            }
          }

          // CARD 4: Match Experience (shown when not solely adding a team)
          SettingsCard {
            visible: !root.addingTeam
            icon: "󰈈"
            title: "Match Experience"
            expanded: true

            SettingToggleRow {
              title: "Anti-Spoiler Mode"
              description: "Hide match scores until revealed or clicked"
              checked: root.antiSpoiler
              onToggled: root.setAntiSpoiler(!root.antiSpoiler)
            }

            SettingToggleRow {
              title: "Show Pre-Match Odds"
              description: "Display betting odds in fixture details"
              checked: root.showOdds
              onToggled: root.setShowOdds(!root.showOdds)
            }
          }

          // CARD 5: Performance & Cache (shown when not solely adding a team)
          SettingsCard {
            visible: !root.addingTeam
            icon: "󰒲"
            title: "Performance & Cache"
            expanded: true

            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                text: "Live Match Refresh Rate"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                Button {
                  width: (parent.width - Style.space(12)) / 3
                  text: "10s (Fast)"
                  tooltipText: "Real-time live score updates"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.livePollRate === 10
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setLivePollRate(10)
                }

                Button {
                  width: (parent.width - Style.space(12)) / 3
                  text: "30s"
                  tooltipText: "Balanced polling cadence"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.livePollRate === 30
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setLivePollRate(30)
                }

                Button {
                  width: (parent.width - Style.space(12)) / 3
                  text: "60s (Saver)"
                  tooltipText: "Battery saver mode for laptops"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.livePollRate === 60
                  horizontalPadding: 0
                  verticalPadding: Style.space(4)
                  onClicked: root.setLivePollRate(60)
                }
              }
            }

            Button {
              width: parent.width
              iconText: "󰑐"
              text: "Clear Cache & Reload"
              tooltipText: "Flush cached standings, rosters, and statistics and fetch fresh data"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(10)
              verticalPadding: Style.space(6)
              onClicked: root.clearCacheAndReload()
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                width: (parent.width - parent.spacing) / 2
                iconText: "󰦛"
                text: root.settingsJustReset ? "Reset Done" : "Reset"
                tooltipText: "Reset all preferences back to default values"
                fontFamily: root.contentFontFamily
                foreground: root.contentForeground
                accent: root.contentForeground
                fontSize: Style.font.caption
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(6)
                onClicked: root.resetAllSettings()
              }

              Button {
                width: (parent.width - parent.spacing) / 2
                iconText: "󰄬"
                text: root.settingsJustSaved ? "Confirmed" : "Confirm"
                tooltipText: "Confirm and apply all preferences to the desktop bar"
                fontFamily: root.contentFontFamily
                foreground: root.contentForeground
                accent: root.favoriteTeamAccent || Color.accent
                selected: true
                fontSize: Style.font.caption
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(6)
                onClicked: root.confirmAllSettings()
              }
            }
          }
        
}
