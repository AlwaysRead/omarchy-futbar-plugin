import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

Column {
  id: settingsView
  property var root: null
  visible: root ? (!root.needsTeam && !root.editingTeam && root.showSettings) : false
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
        color: root ? root.contentForeground : Color.foreground
        font.family: root ? root.contentFontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        visible: sRow.description !== ""
        text: sRow.description
        color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.4)
        font.family: root ? root.contentFontFamily : Style.font.family
        font.pixelSize: Style.space(9)
      }
    }

    ToggleSwitch {
      id: sw
      anchors.right: parent.right
      anchors.rightMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
      checked: sRow.checked
      foreground: root ? root.contentForeground : Color.foreground
      accent: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
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
    color: Util.alpha(root ? root.contentForeground : Color.foreground, 0.04)
    border.width: Style.spacing.hairline
    border.color: Util.alpha(root ? root.contentForeground : Color.foreground, 0.12)

    Column {
      id: cardCol
      width: parent.width
      spacing: 0

      Rectangle {
        width: parent.width
        height: Style.space(38)
        radius: Style.cornerRadius
        color: headerMouse.containsMouse ? Util.alpha(root ? root.contentForeground : Color.foreground, 0.07) : "transparent"

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
              color: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : (root ? root.contentForeground : Color.foreground)
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(28)
              textFormat: Text.PlainText
              text: scCard.title
              color: root ? root.contentForeground : Color.foreground
              font.family: root ? root.contentFontFamily : Style.font.family
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
            color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.5)
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

  // Settings Header with Back Navigation and Status Badge
  Row {
    width: parent.width
    spacing: Style.space(10)

    Button {
      iconText: "󰅁"
      text: "Back"
      tooltipText: "Return to match center"
      fontFamily: root ? root.contentFontFamily : Style.font.family
      foreground: root ? root.contentForeground : Color.foreground
      accent: root ? root.contentForeground : Color.foreground
      fontSize: Style.font.caption
      horizontalPadding: Style.space(8)
      verticalPadding: Style.space(4)
      onClicked: if (root) root.showSettings = false
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "Settings & Preferences"
      color: root ? root.contentForeground : Color.foreground
      font.family: root ? root.contentFontFamily : Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Item {
      width: Math.max(0, parent.width - Style.space(80) - Style.space(190) - Style.space(120))
      height: 1
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      visible: root ? (root.settingsJustSaved || root.settingsJustReset) : false
      text: (root && root.settingsJustSaved) ? "Preferences Saved" : "Settings Reset"
      color: (root && root.settingsJustSaved) ? "#4ade80" : "#f59e0b"
      font.family: root ? root.contentFontFamily : Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  // CARD 1: Display & Top Bar Formats
  SettingsCard {
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
        color: root ? root.contentForeground : Color.foreground
        font.family: root ? root.contentFontFamily : Style.font.family
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
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? root.tabLabelStyle === "abbrev" : true
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setTabLabelStyle("abbrev")
        }

        Button {
          width: (parent.width - Style.space(12)) / 3
          text: "Short"
          tooltipText: "Short recognizable names (e.g. Barça, UCL, Wolves)"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? root.tabLabelStyle === "short" : false
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setTabLabelStyle("short")
        }

        Button {
          width: (parent.width - Style.space(12)) / 3
          text: "Full"
          tooltipText: "Full official names (e.g. Barcelona, UEFA Champions League)"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? root.tabLabelStyle === "full" : false
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setTabLabelStyle("full")
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
        color: root ? root.contentForeground : Color.foreground
        font.family: root ? root.contentFontFamily : Style.font.family
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
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? root.barWidgetMode === "icon" : true
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setBarWidgetMode("icon")
        }

        Button {
          width: (parent.width - Style.space(12)) / 3
          text: "Live Score"
          tooltipText: "Show active live match score on desktop bar"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? root.barWidgetMode === "score" : false
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setBarWidgetMode("score")
        }

        Button {
          width: (parent.width - Style.space(12)) / 3
          text: "Next Match"
          tooltipText: "Show upcoming fixture and kickoff time on desktop bar"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? root.barWidgetMode === "next" : false
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setBarWidgetMode("next")
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
        color: root ? root.contentForeground : Color.foreground
        font.family: root ? root.contentFontFamily : Style.font.family
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
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? (root.kickoffTimeFormat === "24h" || root.timeFormat === "24h") : true
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setTimeFormat("24h")
        }

        Button {
          width: (parent.width - Style.space(12)) / 3
          text: "12-Hour"
          tooltipText: "12-hour clock (e.g. 8:00 PM)"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? (root.kickoffTimeFormat === "12h" || root.timeFormat === "12h") : false
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setTimeFormat("12h")
        }

        Button {
          width: (parent.width - Style.space(12)) / 3
          text: "Relative"
          tooltipText: "Relative countdown (e.g. in 2h 15m)"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? (root.kickoffTimeFormat === "relative" || root.timeFormat === "relative") : false
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setTimeFormat("relative")
        }
      }
    }
  }

  // CARD 2: Notifications & Alerts
  SettingsCard {
    icon: "󰂚"
    title: "Notifications & Alerts"
    expanded: true

    SettingToggleRow {
      title: "Enable Desktop Alerts"
      description: "Send match notifications via notify-send"
      checked: root ? root.enableNotifications : true
      onToggled: if (root) root.setEnableNotifications(!root.enableNotifications)
    }

    SettingToggleRow {
      visible: root ? root.enableNotifications : true
      title: "Goal Alerts"
      description: "Notifications on goals with scorer and minute"
      checked: root ? root.notifyGoals : true
      onToggled: if (root) root.setNotifyGoals(!root.notifyGoals)
    }

    SettingToggleRow {
      visible: root ? root.enableNotifications : true
      title: "Red Cards & Match Whistles"
      description: "Alerts on red cards, kickoff, HT, and FT"
      checked: root ? root.notifyEvents : true
      onToggled: if (root) root.setNotifyEvents(!root.notifyEvents)
    }

    Column {
      visible: root ? root.enableNotifications : true
      width: parent.width
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        text: "Notification Scope"
        color: root ? root.contentForeground : Color.foreground
        font.family: root ? root.contentFontFamily : Style.font.family
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
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? root.notifyScope === "primary" : true
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setNotifyScope("primary")
        }

        Button {
          width: (parent.width - Style.space(6)) / 2
          text: "All Followed Tabs"
          tooltipText: "Alerts for all followed clubs and tournaments"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? root.notifyScope === "all" : false
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setNotifyScope("all")
        }
      }
    }
  }

  // CARD 3: Match Experience
  SettingsCard {
    icon: "󰈈"
    title: "Match Experience"
    expanded: true

    SettingToggleRow {
      title: "Trending & Live Matches"
      description: "Show trending matches page and header button for global games"
      checked: root ? root.enableTrending : true
      onToggled: if (root) root.setEnableTrending(!root.enableTrending)
    }

    SettingToggleRow {
      title: "Anti-Spoiler Mode"
      description: "Hide match scores until revealed or clicked"
      checked: root ? root.antiSpoiler : false
      onToggled: if (root) root.setAntiSpoiler(!root.antiSpoiler)
    }

    SettingToggleRow {
      title: "Show Pre-Match Odds"
      description: "Display betting odds in fixture details"
      checked: root ? root.showOdds : true
      onToggled: if (root) root.setShowOdds(!root.showOdds)
    }
  }

  // CARD 4: Performance & Cache
  SettingsCard {
    icon: "󰒲"
    title: "Performance & Cache"
    expanded: true

    Column {
      width: parent.width
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        text: "Live Match Refresh Rate"
        color: root ? root.contentForeground : Color.foreground
        font.family: root ? root.contentFontFamily : Style.font.family
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
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? root.livePollRate === 10 : true
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setLivePollRate(10)
        }

        Button {
          width: (parent.width - Style.space(12)) / 3
          text: "30s"
          tooltipText: "Balanced polling cadence"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? root.livePollRate === 30 : false
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setLivePollRate(30)
        }

        Button {
          width: (parent.width - Style.space(12)) / 3
          text: "60s (Saver)"
          tooltipText: "Battery saver mode for laptops"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          selected: root ? root.livePollRate === 60 : false
          horizontalPadding: 0
          verticalPadding: Style.space(4)
          onClicked: if (root) root.setLivePollRate(60)
        }
      }
    }

    Button {
      width: parent.width
      iconText: "󰑐"
      text: "Clear Cache & Reload"
      tooltipText: "Flush cached standings, rosters, and statistics and fetch fresh data"
      fontFamily: root ? root.contentFontFamily : Style.font.family
      foreground: root ? root.contentForeground : Color.foreground
      accent: root ? root.contentForeground : Color.foreground
      fontSize: Style.font.caption
      horizontalPadding: Style.space(10)
      verticalPadding: Style.space(6)
      onClicked: if (root) root.clearCacheAndReload()
    }

    Row {
      width: parent.width
      spacing: Style.space(8)

      Button {
        width: (parent.width - parent.spacing) / 2
        iconText: "󰦛"
        text: (root && root.settingsJustReset) ? "Reset Done" : "Reset"
        tooltipText: "Reset all preferences back to default values"
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : Color.foreground
        accent: root ? root.contentForeground : Color.foreground
        fontSize: Style.font.caption
        horizontalPadding: Style.space(8)
        verticalPadding: Style.space(6)
        onClicked: if (root) root.resetAllSettings()
      }

      Button {
        width: (parent.width - parent.spacing) / 2
        iconText: "󰄬"
        text: (root && root.settingsJustSaved) ? "Confirmed" : "Confirm"
        tooltipText: "Confirm and apply all preferences to the desktop bar"
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : Color.foreground
        accent: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
        selected: true
        fontSize: Style.font.caption
        horizontalPadding: Style.space(8)
        verticalPadding: Style.space(6)
        onClicked: if (root) root.confirmAllSettings()
      }
    }
  }

  // CARD 5: Followed Clubs & Leagues Management
  SettingsCard {
    icon: "󰐕"
    title: "Followed Clubs & Leagues"
    expanded: true

    Column {
      width: parent.width
      spacing: Style.space(8)

      Repeater {
        model: root ? root.allFollowedTabs() : []
        delegate: Rectangle {
          id: followedTabRow
          required property var modelData
          required property int index
          width: parent.width
          height: Style.space(38)
          radius: Style.cornerRadius
          color: (index === 0) ? Util.alpha((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent, 0.12) : Util.alpha(root ? root.contentForeground : Color.foreground, 0.05)
          border.width: Style.spacing.hairline
          border.color: (index === 0) ? ((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent) : Util.alpha(root ? root.contentForeground : Color.foreground, 0.1)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: index === 0 ? "" : String(index + 1)
              color: index === 0 ? "#f59e0b" : Qt.darker(root ? root.contentForeground : Color.foreground, 1.5)
              font.family: root ? root.contentFontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              width: Style.space(16)
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: modelData.followLeague
                ? ((root ? root.leagueLabel(modelData.league) : modelData.league) + " (League)")
                : (modelData.teamName + " (" + (root ? root.leagueLabel(modelData.league) : modelData.league) + ")")
              color: root ? root.contentForeground : Color.foreground
              font.family: root ? root.contentFontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: index === 0
              elide: Text.ElideRight
              width: parent.width - Style.space(16) - (index > 0 ? Style.space(72) : Style.space(36)) - parent.spacing * 3
            }

            Button {
              anchors.verticalCenter: parent.verticalCenter
              visible: index > 0
              iconText: "󰐊"
              tooltipText: "Set as Primary Bar Club"
              fontFamily: root ? root.contentFontFamily : Style.font.family
              foreground: root ? root.contentForeground : Color.foreground
              accent: root ? root.contentForeground : Color.foreground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              onClicked: if (root) root.promoteToPrimary(modelData.teamName, modelData.league, modelData.teamId, modelData.followLeague)
            }

            Button {
              anchors.verticalCenter: parent.verticalCenter
              visible: index > 0 || (root && root.allFollowedTabs().length > 1)
              iconText: "󰅖"
              tooltipText: "Remove from followed tabs"
              fontFamily: root ? root.contentFontFamily : Style.font.family
              foreground: "#ef4444"
              accent: "#ef4444"
              fontSize: Style.font.caption
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              onClicked: if (root) root.removeFollowedItem(modelData.teamName, modelData.league, modelData.followLeague)
            }
          }
        }
      }

      Button {
        width: parent.width
        iconText: "󰐕"
        text: "Follow Another Club or League"
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : Color.foreground
        accent: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
        fontSize: Style.font.caption
        horizontalPadding: Style.space(10)
        verticalPadding: Style.space(6)
        onClicked: {
          if (root) {
            root.showSettings = false
            root.openAddTeamPicker()
          }
        }
      }
    }
  }
}
