import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

Column {
  id: settingsView
  property var root: null
  property string activeCategory: "clubs" // "clubs", "display", "matches", "alerts", "system", "all"

  visible: root ? (!root.needsTeam && !root.editingTeam && root.showSettings) : false
  width: parent ? parent.width : 0
  spacing: Style.space(12)

  // Modern setting toggle row with full-row click area
  component SettingToggleRow: Rectangle {
    id: sRow
    property string title: ""
    property string description: ""
    property bool checked: false
    signal toggled()

    width: parent ? parent.width : Style.space(300)
    implicitHeight: Math.max(Style.space(42), col.implicitHeight + Style.space(12))
    radius: Style.cornerRadius
    color: rowMouse.containsMouse ? Util.alpha(root ? root.contentForeground : Color.foreground, 0.05) : "transparent"

    Behavior on color { ColorAnimation { duration: 120 } }

    Column {
      id: col
      anchors.left: parent.left
      anchors.leftMargin: Style.space(4)
      anchors.right: sw.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: sRow.title
        color: root ? root.contentForeground : Color.foreground
        font.family: root ? root.contentFontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        wrapMode: Text.WordWrap
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        visible: sRow.description !== ""
        text: sRow.description
        color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.45)
        font.family: root ? root.contentFontFamily : Style.font.family
        font.pixelSize: Style.space(8.5)
        wrapMode: Text.WordWrap
      }
    }

    ToggleSwitch {
      id: sw
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      checked: sRow.checked
      foreground: root ? root.contentForeground : Color.foreground
      accent: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
      onToggled: sRow.toggled()
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: sRow.toggled()
    }
  }

  // Modern card container
  component SettingsCard: Rectangle {
    id: scCard
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    default property alias contentData: cardContent.data

    width: parent ? parent.width : 0
    implicitHeight: cardCol.implicitHeight + Style.space(20)
    radius: Style.cornerRadius
    color: Util.alpha(root ? root.contentForeground : Color.foreground, 0.03)
    border.width: Style.spacing.hairline
    border.color: Util.alpha(root ? root.contentForeground : Color.foreground, 0.08)

    Column {
      id: cardCol
      anchors.fill: parent
      anchors.margins: Style.space(10)
      spacing: Style.space(10)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: scCard.icon
          font.pixelSize: Style.font.body
          font.family: "Symbols Nerd Font, " + (root ? root.contentFontFamily : Style.font.family)
          color: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Style.space(28)
          spacing: 1

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: scCard.title
            color: root ? root.contentForeground : Color.foreground
            font.family: root ? root.contentFontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            visible: scCard.subtitle !== ""
            text: scCard.subtitle
            color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.5)
            font.family: root ? root.contentFontFamily : Style.font.family
            font.pixelSize: Style.space(8.5)
            elide: Text.ElideRight
          }
        }
      }

      Column {
        id: cardContent
        width: parent.width
        spacing: Style.space(10)
      }
    }
  }

  // Header: Return Button, Title & Autosave Live Status Badge
  Row {
    width: parent.width
    spacing: Style.space(8)

    Button {
      iconText: "󰁍"
      text: "Back"
      tooltipText: "Return to matches"
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
      width: Math.max(Style.space(4), parent.width - Style.space(68) - Style.space(170) - (saveStatusBadge.visible ? saveStatusBadge.implicitWidth : 0))
      height: 1
    }

    // Live auto-save / reset toast badge
    Rectangle {
      id: saveStatusBadge
      anchors.verticalCenter: parent.verticalCenter
      visible: root ? (root.settingsJustSaved || root.settingsJustReset) : false
      height: Style.space(20)
      width: statusRow.implicitWidth + Style.space(12)
      radius: Style.space(10)
      color: (root && root.settingsJustSaved) ? Qt.rgba(0.29, 0.87, 0.5, 0.15) : Qt.rgba(0.96, 0.62, 0.07, 0.15)
      border.width: Style.spacing.hairline
      border.color: (root && root.settingsJustSaved) ? "#4ade80" : "#f59e0b"

      Row {
        id: statusRow
        anchors.centerIn: parent
        spacing: Style.space(4)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: (root && root.settingsJustSaved) ? "󰄬" : "󰦛"
          color: (root && root.settingsJustSaved) ? "#4ade80" : "#f59e0b"
          font.family: "Symbols Nerd Font, " + (root ? root.contentFontFamily : Style.font.family)
          font.pixelSize: Style.space(9)
          font.bold: true
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: (root && root.settingsJustSaved) ? "Saved" : "Reset"
          color: (root && root.settingsJustSaved) ? "#4ade80" : "#f59e0b"
          font.family: root ? root.contentFontFamily : Style.font.family
          font.pixelSize: Style.space(9)
          font.bold: true
        }
      }
    }
  }

  // Category Filter Pill Navigation
  Flickable {
    id: categoryFlickable
    width: parent.width
    height: Style.space(26)
    contentWidth: categoryRow.implicitWidth
    contentHeight: height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.HorizontalFlick
    interactive: true

    WheelHandler {
      target: categoryFlickable
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function(event) {
        if (event.angleDelta.y !== 0) {
          categoryFlickable.contentX = Math.max(0, Math.min(categoryFlickable.contentWidth - categoryFlickable.width, categoryFlickable.contentX - event.angleDelta.y))
        }
      }
    }

    Row {
      id: categoryRow
      spacing: Style.space(5)
      height: parent.height

      Button {
        height: Style.space(24)
        iconText: "󰑊"
        text: "Clubs"
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : Color.foreground
        accent: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
        fontSize: Style.font.caption
        horizontalPadding: Style.space(8)
        verticalPadding: 0
        selected: settingsView.activeCategory === "clubs"
        onClicked: settingsView.activeCategory = "clubs"
      }

      Button {
        height: Style.space(24)
        iconText: "󰍹"
        text: "Display"
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : Color.foreground
        accent: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
        fontSize: Style.font.caption
        horizontalPadding: Style.space(8)
        verticalPadding: 0
        selected: settingsView.activeCategory === "display"
        onClicked: settingsView.activeCategory = "display"
      }

      Button {
        height: Style.space(24)
        iconText: "󰊴"
        text: "Matches"
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : Color.foreground
        accent: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
        fontSize: Style.font.caption
        horizontalPadding: Style.space(8)
        verticalPadding: 0
        selected: settingsView.activeCategory === "matches"
        onClicked: settingsView.activeCategory = "matches"
      }

      Button {
        height: Style.space(24)
        iconText: "󰂚"
        text: "Alerts"
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : Color.foreground
        accent: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
        fontSize: Style.font.caption
        horizontalPadding: Style.space(8)
        verticalPadding: 0
        selected: settingsView.activeCategory === "alerts"
        onClicked: settingsView.activeCategory = "alerts"
      }

      Button {
        height: Style.space(24)
        iconText: "󰒓"
        text: "System"
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : Color.foreground
        accent: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
        fontSize: Style.font.caption
        horizontalPadding: Style.space(8)
        verticalPadding: 0
        selected: settingsView.activeCategory === "system"
        onClicked: settingsView.activeCategory = "system"
      }

      Button {
        height: Style.space(24)
        iconText: "󰒋"
        text: "All"
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : Color.foreground
        accent: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
        fontSize: Style.font.caption
        horizontalPadding: Style.space(8)
        verticalPadding: 0
        selected: settingsView.activeCategory === "all"
        onClicked: settingsView.activeCategory = "all"
      }
    }
  }

  // ==========================================
  // SECTION 1: CLUBS & TOURNAMENTS MANAGEMENT
  // ==========================================
  SettingsCard {
    visible: settingsView.activeCategory === "clubs" || settingsView.activeCategory === "all"
    icon: "󰑊"
    title: "Followed Clubs & Leagues"
    subtitle: "Manage your primary bar club and fast-switching tabs"

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
          height: Style.space(42)
          radius: Style.cornerRadius
          color: (index === 0)
            ? Util.alpha((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent, 0.12)
            : Util.alpha(root ? root.contentForeground : Color.foreground, 0.04)
          border.width: (index === 0) ? 1.2 : Style.spacing.hairline
          border.color: (index === 0)
            ? ((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent)
            : Util.alpha(root ? root.contentForeground : Color.foreground, 0.08)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            // Primary star or index number
            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: index === 0 ? "󰛐" : String(index + 1)
              color: index === 0 ? "#f59e0b" : Qt.darker(root ? root.contentForeground : Color.foreground, 1.6)
              font.family: "Symbols Nerd Font, " + (root ? root.contentFontFamily : Style.font.family)
              font.pixelSize: Style.font.caption
              font.bold: true
              width: Style.space(16)
              horizontalAlignment: Text.AlignHCenter
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(24) - (index > 0 ? Style.space(78) : (allTabsCount > 1 ? Style.space(38) : 0)) - parent.spacing * 3
              spacing: 1
              readonly property int allTabsCount: root ? root.allFollowedTabs().length : 1

              Row {
                width: parent.width
                spacing: Style.space(6)

                Text {
                  textFormat: Text.PlainText
                  text: followedTabRow.modelData.followLeague
                    ? (root ? root.leagueLabel(followedTabRow.modelData.league) : followedTabRow.modelData.league)
                    : followedTabRow.modelData.teamName
                  color: root ? root.contentForeground : Color.foreground
                  font.family: root ? root.contentFontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: followedTabRow.index === 0
                  elide: Text.ElideRight
                  maximumLineCount: 1
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: followedTabRow.index === 0
                  height: Style.space(14)
                  width: primLabel.implicitWidth + Style.space(8)
                  radius: Style.space(3)
                  color: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent

                  Text {
                    id: primLabel
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "PRIMARY"
                    color: "#ffffff"
                    font.family: root ? root.contentFontFamily : Style.font.family
                    font.pixelSize: Style.space(7.5)
                    font.bold: true
                  }
                }
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: followedTabRow.modelData.followLeague
                  ? "Full Competition Tracker"
                  : (root ? root.leagueLabel(followedTabRow.modelData.league) : followedTabRow.modelData.league)
                color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.5)
                font.family: root ? root.contentFontFamily : Style.font.family
                font.pixelSize: Style.space(8.5)
                elide: Text.ElideRight
              }
            }

            // Move to Primary Action
            Button {
              anchors.verticalCenter: parent.verticalCenter
              visible: followedTabRow.index > 0
              iconText: "󰑊"
              text: "Primary"
              tooltipText: "Set as Desktop Bar Club"
              fontFamily: root ? root.contentFontFamily : Style.font.family
              foreground: root ? root.contentForeground : Color.foreground
              accent: root ? root.contentForeground : Color.foreground
              fontSize: Style.space(8.5)
              iconSize: Style.space(9)
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              height: Style.space(24)
              onClicked: if (root) root.promoteToPrimary(followedTabRow.modelData.teamName, followedTabRow.modelData.league, followedTabRow.modelData.teamId, followedTabRow.modelData.followLeague)
            }

            // Remove Action
            Button {
              anchors.verticalCenter: parent.verticalCenter
              visible: followedTabRow.index > 0 || (root && root.allFollowedTabs().length > 1)
              iconText: "󰆴"
              tooltipText: "Unfollow item"
              fontFamily: root ? root.contentFontFamily : Style.font.family
              foreground: "#ef4444"
              accent: "#ef4444"
              fontSize: Style.font.caption
              iconSize: Style.space(10)
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              height: Style.space(24)
              onClicked: if (root) root.removeFollowedItem(followedTabRow.modelData.teamName, followedTabRow.modelData.league, followedTabRow.modelData.followLeague)
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

  // ==========================================
  // SECTION 2: DISPLAY & FORMATS
  // ==========================================
  SettingsCard {
    visible: settingsView.activeCategory === "display" || settingsView.activeCategory === "all"
    icon: "󰍹"
    title: "Display & Top Bar Formats"
    subtitle: "Customize widget visibility, time display, and tab codes"

    // Desktop Bar Widget Mode
    Column {
      width: parent.width
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        text: "Desktop Top Bar Widget"
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
          tooltipText: "Minimal ball icon on desktop bar (󰎆)"
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

  // ==========================================
  // SECTION 3: MATCH EXPERIENCE
  // ==========================================
  SettingsCard {
    visible: settingsView.activeCategory === "matches" || settingsView.activeCategory === "all"
    icon: "󰊴"
    title: "Match Experience"
    subtitle: "Fine-tune score privacy, odds display, and trending games"

    SettingToggleRow {
      title: "Trending & Live Matches"
      description: "Show trending matches page and global marquee match hub"
      checked: root ? root.enableTrending : true
      onToggled: if (root) root.setEnableTrending(!root.enableTrending)
    }

    SettingToggleRow {
      title: "Anti-Spoiler Mode"
      description: "Hide live and final scores until clicked to avoid spoilers"
      checked: root ? root.antiSpoiler : false
      onToggled: if (root) root.setAntiSpoiler(!root.antiSpoiler)
    }

    SettingToggleRow {
      title: "Pre-Match Betting Odds"
      description: "Show betting spreads, moneylines, and over/under lines in match details"
      checked: root ? root.showOdds : true
      onToggled: if (root) root.setShowOdds(!root.showOdds)
    }
  }

  // ==========================================
  // SECTION 4: NOTIFICATIONS & ALERTS
  // ==========================================
  SettingsCard {
    visible: settingsView.activeCategory === "alerts" || settingsView.activeCategory === "all"
    icon: "󰂚"
    title: "Notifications & Alerts"
    subtitle: "Manage desktop goal popups, audio chimes, and whistle alerts"

    SettingToggleRow {
      title: "Enable Desktop Alerts"
      description: "Send live match notifications via notify-send"
      checked: root ? root.enableNotifications : true
      onToggled: if (root) root.setEnableNotifications(!root.enableNotifications)
    }

    SettingToggleRow {
      visible: root ? root.enableNotifications : true
      title: "Goal Notifications"
      description: "Instant goal alerts featuring scorer and match minute"
      checked: root ? root.notifyGoals : true
      onToggled: if (root) root.setNotifyGoals(!root.notifyGoals)
    }

    SettingToggleRow {
      visible: root ? (root.enableNotifications && root.notifyGoals) : true
      title: "Audio Goal Chime"
      description: "Play system notification sound chime when a goal is scored"
      checked: root ? root.notifyAudio : false
      onToggled: if (root) root.setNotifyAudio(!root.notifyAudio)
    }

    SettingToggleRow {
      visible: root ? root.enableNotifications : true
      title: "Red Cards & Whistles"
      description: "Alerts on red cards, kickoff, half-time, and full-time"
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
          text: "All Tracked Items"
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

  // ==========================================
  // SECTION 5: SYSTEM & PERFORMANCE
  // ==========================================
  SettingsCard {
    visible: settingsView.activeCategory === "system" || settingsView.activeCategory === "all"
    icon: "󰒓"
    title: "System & Cache"
    subtitle: "Refresh rate, local data cache, and factory preferences"

    Column {
      width: parent.width
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        text: "Live Match Refresh Cadence"
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

    Row {
      width: parent.width
      spacing: Style.space(8)

      Button {
        width: (parent.width - parent.spacing) / 2
        iconText: "󰑐"
        text: "Flush Cache"
        tooltipText: "Flush cached standings, rosters, and statistics and fetch fresh data"
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : Color.foreground
        accent: root ? root.contentForeground : Color.foreground
        fontSize: Style.font.caption
        horizontalPadding: Style.space(8)
        verticalPadding: Style.space(6)
        onClicked: if (root) root.clearCacheAndReload()
      }

      Button {
        width: (parent.width - parent.spacing) / 2
        iconText: "󰦛"
        text: "Reset Defaults"
        tooltipText: "Reset all preferences back to default values"
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : Color.foreground
        accent: root ? root.contentForeground : Color.foreground
        fontSize: Style.font.caption
        horizontalPadding: Style.space(8)
        verticalPadding: Style.space(6)
        onClicked: if (root) root.resetAllSettings()
      }
    }
  }
}
