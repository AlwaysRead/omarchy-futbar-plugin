import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../components"
import "../controllers"
import "../data/FutPreferences.js" as Preferences
import "../data/FutComparison.js" as Comparison
import "../data/FutData.js" as FutData
import "../services/FutNetwork.js" as FutNetwork
import "../services/FutPollingPolicy.js" as Polling


KeyboardPanel {
  property var root: null
  readonly property var panelScrollArea: internalPanelScrollArea
  readonly property var newsView: internalNewsView
  readonly property var trendingView: internalTrendingView
  readonly property var standingsView: internalStandingsView

  component LoadingOverlay: FutLoadingOverlay { root: popup.root }

  component SettingToggleRow: Item {
    id: sRow
    property string title: ""
    property string description: ""
    property bool checked: false
    signal toggled()
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: sRow.title
    Accessible.checkable: true
    Accessible.checked: sRow.checked
    Accessible.onPressAction: sRow.toggled()
    Keys.onSpacePressed: sRow.toggled()
    Keys.onReturnPressed: sRow.toggled()

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
      accent: root.favoriteTeamAccent || Commons.Color.accent
      onToggled: sRow.toggled()
    }

    FutActionArea {
    actionLabel: "Open details"

      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onActivated: sRow.toggled()
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
              textFormat: Text.PlainText
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
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: scCard.expanded ? "󰅃" : "󰅂"
            font.pixelSize: Style.font.caption
            color: Qt.darker(root.contentForeground, 1.5)
          }
        }

        FutActionArea {
    actionLabel: "Open details"

          id: headerMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onActivated: scCard.expanded = !scCard.expanded
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

    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // Keep the card tied to its bar button instead of centering it on the bar.
    centerOnBar: false
    contentWidth: popup.fittedContentWidth(root.showTrending ? Style.space(440) : Style.space(410))
    contentHeight: popup.fittedContentHeight((pinnedHeader.visible ? pinnedHeader.implicitHeight + Style.space(14) : 0) + content.implicitHeight, (root.showMatchDetail || root.selectedPlayerProfile !== null || root.selectedClubProfile !== null) ? Style.space(720) : Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // While a club-picker dropdown or search field is open/focused, let it handle the
      // keys (Escape/arrows/Enter) instead of the panel's close/switch keys.
      blocked: !!((leagueDropdown && (leagueDropdown.popupOpen || leagueDropdown.activeFocus))
        || (teamDropdown && (teamDropdown.popupOpen || teamDropdown.activeFocus))
        || (searchBarInput && searchBarInput.activeFocus)
        || (internalTrendingView && internalTrendingView.searchFocused))
      onCloseRequested: {
        if (root.showNews && internalNewsView.selectedArticle !== null) internalNewsView.closeReader()
        else if (root.showNews) root.showNews = false
        else if (root.showSettings) root.showSettings = false
        else if (root.showMatchDetail) root.showMatchDetail = false
        else if (root.selectedPlayerProfile !== null) root.selectedPlayerProfile = null
        else if (root.selectedClubProfile !== null) root.selectedClubProfile = null
        else if (root.showSearch) root.showSearch = false
        else if (root.showTrending) root.showTrending = false
        else if (root.editingTeam) { root.editingTeam = false; root.addingTeam = false }
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dx < 0) {
          if (matchWeekNav && matchWeekNav.visible && prevWeekButton) prevWeekButton.clicked()
        } else if (dx > 0) {
          if (matchWeekNav && matchWeekNav.visible && nextWeekButton) nextWeekButton.clicked()
        } else if (dy !== 0) {
          if (root.showTrending && internalTrendingView && internalTrendingView.navigateMatch) {
            internalTrendingView.navigateMatch(dy > 0 ? 1 : -1)
          } else if (!root.customViewActive) {
            root.navigateMainMatches(dy > 0 ? 1 : -1)
          } else if (internalPanelScrollArea && internalPanelScrollArea.flickableItem) {
            internalPanelScrollArea.flickableItem.flick(0, dy > 0 ? -600 : 600)
          }
        }
      }
      onActivateRequested: {
        if (root.showTrending && internalTrendingView && internalTrendingView.activateSelectedMatch) {
          internalTrendingView.activateSelectedMatch()
        } else if (!root.customViewActive) {
          root.activateSelectedMainMatch()
        }
      }
      onTextKey: function(t) {
        if (!t) return
        var c = t.toLowerCase()
        if (root.showTrending && internalTrendingView && (c >= "1" && c <= "4")) {
          internalTrendingView.activeCategory = c === "1" ? "all" : (c === "2" ? "live" : (c === "3" ? "international" : "club"))
        } else if (t >= "1" && t <= "9") {
          var idx = parseInt(t, 10) - 1
          var tabs = root.allFollowedTabs()
          if (tabs && idx < tabs.length) {
            root.switchActiveItem(tabs[idx].teamName, tabs[idx].league, tabs[idx].teamId, tabs[idx].followLeague)
          }
        } else if (c === "r") {
          root.refresh()
          if (root.leagueMode || root.showMatches) root.loadMatchList(true)
        } else if (t === "/") {
          if (searchButton) searchButton.clicked()
        } else if (c === "l") {
          if (trendingButton && trendingButton.visible) trendingButton.clicked()
        } else if (c === "t") {
          if (standingsButton && standingsButton.visible) standingsButton.clicked()
        } else if (c === "s") {
          if (statsButton && statsButton.visible) statsButton.clicked()
        } else if (c === "m") {
          if (matchesButton) matchesButton.clicked()

        } else if (c === "n") {
          if (newsButton) newsButton.clicked()
        } else if (c === "p") {
          if (settingsButton) settingsButton.clicked()
        }
      }

      Column {
        id: pinnedHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root.needsTeam && !root.editingTeam
        spacing: Style.space(14)

        // Followed tabs bar
        Flow {
          visible: !root.needsTeam && !root.editingTeam
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.allFollowedTabs()
            delegate: Button {
    focusable: true
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText || text || "Action"

              readonly property bool isLeagueTab: modelData.followLeague === true
              readonly property string displayName: {
                var _ = root.tabLabelStyle
                return root.tabDisplayName(modelData)
              }
              readonly property string fullLabel: isLeagueTab ? root.leagueLabel(modelData.league) : (modelData.teamName + " (" + root.leagueLabel(modelData.league) + ")")
              readonly property bool isItemActive: root.itemKey(modelData.followLeague ? "" : modelData.teamName, modelData.league, modelData.followLeague === true) === root.itemKey(root.leagueMode ? "" : root.teamName, root.league, root.leagueMode)
              readonly property bool isFirstSlot: index === 0
              iconText: isFirstSlot ? "" : ""
              iconSize: Style.space(9)
              text: displayName
              tooltipText: isFirstSlot
                ? (fullLabel + " · Primary Bar Club" + (isItemActive ? "" : " (Click to view)"))
                : (isItemActive ? fullLabel : ("Switch to " + fullLabel + " · right-click / middle-click to remove"))
              selected: isItemActive
              fontFamily: root.contentFontFamily
              foreground: isFirstSlot ? "#f59e0b" : root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: root.tabLabelStyle === "abbrev" ? Style.space(8) : Style.space(10)
              verticalPadding: Style.space(4)
              onClicked: {
                if (!isItemActive) {
                  root.switchActiveItem(modelData.teamName, modelData.league, modelData.teamId, modelData.followLeague)
                }
              }
              onRightClicked: {
                if (!isFirstSlot || root.allFollowedTabs().length > 1) {
                  root.removeFollowedItem(modelData.teamName, modelData.league, modelData.followLeague)
                }
              }
              TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: {
                  if (!isFirstSlot || root.allFollowedTabs().length > 1) {
                    root.removeFollowedItem(modelData.teamName, modelData.league, modelData.followLeague)
                  }
                }
              }
            }
          }

          Button {
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: tooltipText || text || "Action"

            iconText: "󰐕"
            tooltipText: "Add another club or league to follow"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.font.caption
            horizontalPadding: Style.space(8)
            verticalPadding: Style.space(4)
            onClicked: root.openAddTeamPicker()
          }
        }
        Row {
          width: parent.width
          spacing: Style.space(8)

          FutRemoteImage {
            id: tournamentLogoImage
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(30)
            height: width
            remoteSource: root.showClubFixtures
              ? (root.clubLogoUrl() !== "" ? root.clubLogoUrl() : root.leagueLogoUrl())
              : ((root.showMatches || root.showStats || root.showStandings || root.leagueMode)
                ? (root.leagueLogoUrl() !== "" ? root.leagueLogoUrl() : root.clubLogoUrl())
                : (root.clubLogoUrl() !== "" ? root.clubLogoUrl() : root.leagueLogoUrl()))
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            mipmap: true
            smooth: true
            visible: !root.showTrending
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(Style.space(80), parent.width
              - (tournamentLogoImage.visible ? tournamentLogoImage.width + parent.spacing : 0)
              - (headerActionButtons.visible ? headerActionButtons.implicitWidth + parent.spacing : 0))
            spacing: Style.space(1)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.showTrending
                ? "Trending Matches"
                : (root.showClubFixtures
                  ? (root.teamName + " Fixtures")
                  : ((root.showMatches || root.showStats || root.showStandings || root.leagueMode)
                    ? (root.tournamentName || root.leagueLabel())
                    : (root.teamName || root.tournamentName || root.leagueLabel())))
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: text.length > 22 ? Style.font.caption : (text.length > 15 ? Style.font.bodySmall : Style.font.body)
              font.bold: true
              wrapMode: Text.Wrap
              maximumLineCount: 3
              elide: Text.ElideNone
              lineHeight: 0.95
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.showTrending
                ? "Live & Marquee Global Matches"
                : (root.showClubFixtures
                  ? root.leagueLabel()
                  : ((root.showMatches || root.showStats || root.showStandings || root.leagueMode)
                    ? (root.leagueMode ? "" : root.teamName)
                    : root.leagueLabel()))
              color: Qt.darker(root.contentForeground, 1.25)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideNone
              lineHeight: 0.95
              visible: text !== ""
            }
          }

          Row {
            id: headerActionButtons
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
          Button {
            id: searchButton
            focusable: true
            Accessible.name: tooltipText
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            height: Style.space(28)
            iconText: "󰍉"
            tooltipText: "Search Players & Clubs (/)"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.space(13)
            horizontalPadding: 0
            verticalPadding: 0
            selected: root.showSearch
            onClicked: {
              root.showMatchDetail = false
              root.showClubFixtures = false
              root.showSettings = false
              root.showNews = false
              root.showTrending = false
              root.showSearch = !root.showSearch
              if (root.showSearch) {
                root.showMatches = false
                root.showStandings = false
                root.showStats = false
                Qt.callLater(function() {
                  if (searchBarInput) searchBarInput.forceActiveFocus()
                })
              }
            }
          }


          Button {
            id: newsButton
            focusable: true
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28); height: Style.space(28)
            iconText: "󰎕"
            tooltipText: "News (n)"
            Accessible.name: "News"
            foreground: root.contentForeground; accent: root.contentForeground
            horizontalPadding: 0; verticalPadding: 0
            selected: root.showNews
            onClicked: {
              root.showSettings = false
              root.showNews = !root.showNews
              if (root.showNews) {
                root.showMatchDetail = false
                root.showSearch = false
                root.showTrending = false
                root.showMatches = false
                root.showStandings = false
                root.showStats = false
                root.showClubFixtures = false
              }
            }
          }

          Button {
            id: trendingButton
            focusable: true
            Accessible.name: tooltipText
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            height: Style.space(28)
            iconText: "󰈸"
            tooltipText: "Trending & Live Matches (l)"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.space(13)
            horizontalPadding: 0
            verticalPadding: 0
            visible: root.enableTrending
            selected: root.showTrending
            onClicked: {
              root.showMatchDetail = false
              root.showClubFixtures = false
              root.showSearch = false
              root.showSettings = false
              root.showMatches = false
              root.showStandings = false
              root.showStats = false
              root.showNews = false
              root.showTrending = !root.showTrending
              if (root.showTrending && internalTrendingView) {
                internalTrendingView.refresh(true)
              }
            }
          }

          Button {
            id: matchesButton
            focusable: true
            Accessible.name: tooltipText
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            height: Style.space(28)
            iconText: "󰕲"
            tooltipText: "Fixtures (m)"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.space(13)
            horizontalPadding: 0
            verticalPadding: 0
            selected: root.leagueMode ? (!root.showStandings && !root.showStats && (root.leagueBrowseAll || root.matchesSeasonOffset > 0)) : (root.showMatches && !root.showStandings && !root.showStats && !root.showClubFixtures)
            onClicked: {
              root.showMatchDetail = false
              root.showClubFixtures = false
              root.showSearch = false
              root.showSettings = false
              root.showNews = false
              root.showTrending = false
              if (root.leagueMode) {
                if (root.showStandings || root.showStats) {
                  root.showStandings = false
                  root.showStats = false
                  root.leagueBrowseAll = true
                } else if (root.matchesSeasonOffset > 0) {
                  root.matchesSeasonOffset = 0
                  root.leagueBrowseAll = true
                } else {
                  root.leagueBrowseAll = !root.leagueBrowseAll
                }
                root.matchWindowOffset = 0
                root.pendingEdge = ""
                root.navAnchorDay = ""
                if (root.matchClusters && root.matchClusters.length > 0) {
                  root.matchClusterIndex = root.currentMatchWeekIndex(root.matchClusters)
                }
                root.loadMatchList(true)
                return
              }
              if (root.showStandings || root.showStats) {
                root.showStandings = false
                root.showStats = false
                root.showMatches = true
                root.matchWindowOffset = 0
                root.pendingEdge = ""
                root.navAnchorDay = ""
                if (root.matchClusters && root.matchClusters.length > 0) {
                  root.matchClusterIndex = root.currentMatchWeekIndex(root.matchClusters)
                }
                root.loadMatchList(true)
                return
              }
              root.showMatches = !root.showMatches
              if (root.showMatches) {
                root.matchWindowOffset = 0
                root.pendingEdge = ""
                root.navAnchorDay = ""
                if (root.matchClusters && root.matchClusters.length > 0) {
                  root.matchClusterIndex = root.currentMatchWeekIndex(root.matchClusters)
                }
                root.loadMatchList(true)
              }
            }
          }

          Button {
            id: standingsButton
            focusable: true
            Accessible.name: tooltipText
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.isFriendlyLeague
            width: Style.space(28)
            height: Style.space(28)
            iconText: "󰕶"
            tooltipText: "Standings (t)"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.space(13)
            horizontalPadding: 0
            verticalPadding: 0
            selected: root.showStandings
            onClicked: {
              root.showMatchDetail = false
              root.showClubFixtures = false
              root.showSearch = false
              root.showSettings = false
              root.showNews = false
              root.showTrending = false
              if (root.showStandings) {
                root.showMatches = false
                root.showStats = false
                root.loadStandings(true)
              } else {
                // Open the table in both club and tournament-follow mode.
                root.showStandings = true
                root.showStats = false
                root.showMatches = false
                root.matchWindowOffset = 0
                root.pendingEdge = ""
                root.navAnchorDay = ""
                root.loadStandings(true)
              }
            }
          }

          Button {
            id: statsButton
            focusable: true
            Accessible.name: tooltipText
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            visible: !root.isFriendlyLeague
            height: Style.space(28)
            iconText: "󰄪"
            tooltipText: "Player & Club Stats (s)"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.space(13)
            horizontalPadding: 0
            verticalPadding: 0
            selected: root.showStats
            onClicked: {
              root.showMatchDetail = false
              root.showClubFixtures = false
              root.showSearch = false
              root.showSettings = false
              root.showNews = false
              root.showTrending = false
              if (root.showStats) {
                root.showMatches = false
                root.showStandings = false
                root.loadStats(true)
              } else {
                // Open the leaderboard in both club and tournament-follow mode.
                root.showStats = true
                root.showMatches = false
                root.showStandings = false
                root.loadStats(true)
              }
            }
          }

          Button {
            id: settingsButton
            focusable: true
            Accessible.name: tooltipText
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            height: Style.space(28)
            iconText: "󰒓"
            tooltipText: "Settings & Preferences (p)"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.space(13)
            horizontalPadding: 0
            verticalPadding: 0
            selected: root.showSettings
            onClicked: {
              root.showSearch = false
              root.showClubFixtures = false
              root.showMatchDetail = false
              root.showStandings = false
              root.showStats = false
              root.showNews = false
              root.showTrending = false
              root.showSettings = !root.showSettings
            }
          }
        }
      }

      Text {
        width: parent.width
        visible: root.networkError !== ""
        textFormat: Text.PlainText
        text: root.networkError + (root.networkLastSuccess || root.lastRefresh ? " Last good data: " + Qt.formatDateTime(new Date(root.networkLastSuccess || root.lastRefresh),"hh:mm") + "." : "")
        wrapMode: Text.WordWrap; color: root.contentForeground
        font.family: root.contentFontFamily; font.pixelSize: Style.font.caption
      }
      Rectangle {
        width: parent.width
        height: Style.spacing.hairline
        color: root.contentForeground
        opacity: 0.15
      }
      }

      Column {
        anchors.top: pinnedHeader.bottom
        anchors.topMargin: Style.space(20)
        anchors.left: parent.left; anchors.right: parent.right
        spacing: Style.space(12)
        visible: root.spoilerGuardActive
        Text {
          width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
          text: "Spoiler protection is on. News, form, standings, statistics and match details can reveal results."
          color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall
        }
        Button {
          Accessible.role: Accessible.Button
          Accessible.name: tooltipText || text || "Action"

          text: "Reveal for this panel session"
          focusable: true; foreground: root.contentForeground; accent: root.contentForeground
          onClicked: root.spoilerSessionRevealed = true
        }
      }
      ScrollView {
        id: internalPanelScrollArea
        visible: !root.spoilerGuardActive
        anchors.top: pinnedHeader.visible ? pinnedHeader.bottom : parent.top
        anchors.topMargin: pinnedHeader.visible ? Style.space(14) : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: availableWidth
        contentHeight: content.implicitHeight
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

        Column {
          id: content
          width: internalPanelScrollArea.width
          spacing: Style.space(14)

        Column {
          visible: root.needsTeam || root.editingTeam
          width: parent.width
          spacing: Style.space(14)

          // Settings Header with Back Navigation
          Row {
            width: parent.width
            spacing: Style.space(10)

            Button {
              focusable: true
              Accessible.role: Accessible.Button
              Accessible.name: tooltipText || text || "Action"

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
              text: root.needsTeam ? "Pick Your Club" : (root.addingTeam ? "Follow Club or Tournament" : "Change Club or Tournament")
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
            title: root.needsTeam ? "Select Club to Track" : (root.addingTeam ? "Add Club or Tournament" : "Change Club or Tournament")
            expanded: true

            Column {
              width: parent.width
              spacing: Style.space(12)

              FutSearchableDropdown {
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
                focusable: true
                Accessible.role: Accessible.Button
                Accessible.name: tooltipText || text || "Action"

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

              FutSearchableDropdown {
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

                LoadingOverlay {
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

                FutRemoteImage {
                  width: Style.space(32)
                  height: width
                  remoteSource: root.selectedTeam ? root.selectedTeam.logo : ""
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: 64
                  sourceSize.height: 64
                  mipmap: true
                  smooth: true
                  anchors.verticalCenter: parent.verticalCenter
                  visible: true
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
                focusable: true
                Accessible.role: Accessible.Button
                Accessible.name: tooltipText || text || "Action"

                visible: root.selectedTeam || root.pickerLeagueOnly
                width: parent.width
                text: {
                  if (root.addingTeam) {
                    var alreadyFollowed = root.pickerLeagueOnly
                      ? root.isLeagueFollowed(root.selectedLeague)
                      : (root.selectedTeam ? root.isTeamFollowed(root.selectedTeam.value, root.selectedTeam.id) : false)
                    return alreadyFollowed ? "Already Followed (Switch to Tab)" : "Add to Followed Tabs"
                  }
                  return "Confirm Selection"
                }
                fontFamily: root.contentFontFamily
                foreground: root.contentForeground
                accent: root.contentForeground
                onClicked: root.pickerLeagueOnly ? root.confirmLeague() : root.confirmTeam()
              }
            }
          }
        }

        FutSettingsView {
          id: settingsView
          root: popup.root
        }


      FutNewsView {
        id: internalNewsView
        root: popup.root
        visible: root.showNews && !root.needsTeam && !root.editingTeam && !root.showSettings
      }
      Column {
        visible: !root.showNews && !root.needsTeam && !root.editingTeam && !root.showSettings
        width: parent.width
        spacing: Style.space(14)

      // Match Details View: In-depth information for finished matches
      // Unified Search & Info View: Player profile & Club search center
      Column {
        id: unifiedSearchView
        width: parent.width
        spacing: Style.space(12)
        visible: root.showSearch && !root.showMatchDetail

        // Search Section: Shown when neither player nor club profile is active
        Column {
          id: searchMainSection
          width: parent.width
          spacing: Style.space(12)
          visible: !root.selectedPlayerProfile && !root.selectedClubProfile

        // Search Bar Input Field
        Rectangle {
          width: parent.width
          height: Style.space(38)
          radius: Style.cornerRadius
          color: Util.alpha(root.contentForeground, 0.07)
          border.width: Style.spacing.hairline
          border.color: searchBarInput.activeFocus ? root.favoriteTeamAccent : Util.alpha(root.contentForeground, 0.15)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "󰍉"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              color: Qt.darker(root.contentForeground, 1.4)
            }

            TextField {
              id: searchBarInput
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(30) - (clearSearchBtn.visible ? clearSearchBtn.width + parent.spacing : 0)
              height: parent.height
              verticalPadding: 0
              horizontalPadding: 0
              maximumLength: 100
              readOnly: true
              cursorVisible: activeFocus
              placeholderText: "Search players (e.g. Messi, Yamal) or clubs..."
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              foreground: root.contentForeground
              background: null
              text: root.searchQuery

              function edit(start, end, insert) {
                var next = FutData.spliceInputText(text, start, end, insert, 100)
                text = next.text
                cursorPosition = next.cursor
              }

              onTextChanged: root.triggerSearch(text)

              Keys.onPressed: function(event) {
                var from = selectionStart
                var to = selectionEnd

                if (event.key === Qt.Key_Escape) {
                  if (root.searchQuery !== "") {
                    root.searchQuery = ""
                    searchBarInput.text = ""
                    event.accepted = true
                  } else {
                    searchBarInput.focus = false
                    event.accepted = false
                  }
                  return
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  event.accepted = true
                  return
                }
                if (event.key === Qt.Key_Backspace) {
                  edit(from === to ? from - 1 : from, to, "")
                  event.accepted = true
                  return
                }
                if (event.key === Qt.Key_Delete) {
                  edit(from, from === to ? to + 1 : to, "")
                  event.accepted = true
                  return
                }
                if (event.matches(StandardKey.Cut)) {
                  copy()
                  edit(from, to, "")
                  event.accepted = true
                  return
                }
                if (event.matches(StandardKey.Paste)
                    || event.key === Qt.Key_Paste
                    || ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_V || event.key === Qt.Key_Insert))
                    || ((event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_Insert)
                    || ((event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) && event.key === Qt.Key_V)) {
                  event.accepted = true
                  return
                }
                if (event.text !== "" && !/[\u0000-\u001f\u007f]/.test(event.text)
                    && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                  edit(from, to, event.text)
                  event.accepted = true
                  return
                }
              }

              DropArea {
                anchors.fill: parent
                onEntered: function(drag) { drag.accept(Qt.IgnoreAction) }
                onDropped: function(drop) { drop.accept(Qt.IgnoreAction) }
              }

              MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.IBeamCursor
                onPressed: function(mouse) { mouse.accepted = true }
                onReleased: function(mouse) { mouse.accepted = true }
                onClicked: function(mouse) { mouse.accepted = true }
              }
            }

            Button {
              focusable: true
              Accessible.role: Accessible.Button
              Accessible.name: tooltipText || text || "Action"

              id: clearSearchBtn
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(22)
              height: Style.space(22)
              iconText: "󰅖"
              iconSize: Style.font.caption
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              horizontalPadding: 0
              verticalPadding: 0
              visible: searchBarInput.text.length > 0
              onClicked: {
                searchBarInput.text = ""
                root.searchQuery = ""
                root.searchResults = []
                root.selectedPlayerProfile = null
                root.selectedClubProfile = null
                searchBarInput.forceActiveFocus()
              }
            }
          }
        }

        // Active Search Loading Indicator
        Item {
          width: parent.width
          height: Style.space(28)
          visible: root.searchLoading
          Row {
            anchors.centerIn: parent
            spacing: Style.space(8)
            Text {
              textFormat: Text.PlainText
              text: "󰑮"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              color: root.favoriteTeamAccent
              opacity: 0.5 + 0.5 * root._pulse
            }
            Text {
              textFormat: Text.PlainText
              text: "Searching ESPN database…"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.contentForeground, 1.4)
            }
          }
        }

        // Active Club Fetch Loading Indicator
        Item {
          width: parent.width
          height: Style.space(36)
          visible: root.searchClubLoading && !root.selectedClubProfile
          Row {
            anchors.centerIn: parent
            spacing: Style.space(8)
            Text {
              textFormat: Text.PlainText
              text: "󰑮"
              font.family: "Symbols Nerd Font, " + root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              color: root.favoriteTeamAccent
              opacity: 0.5 + 0.5 * root._pulse
            }
            Text {
              textFormat: Text.PlainText
              text: "Loading club profile…"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.contentForeground, 1.4)
            }
          }
        }

        // Search Error or Empty Text
        Text {
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: root.searchError
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          visible: !root.searchLoading && !root.searchClubLoading && root.searchError !== "" && !root.selectedPlayerProfile && !root.selectedClubProfile
        }

        // Search Results List (Shown when neither player nor club is selected and not loading)
        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: !root.selectedPlayerProfile && !root.selectedClubProfile && !root.searchClubLoading && root.searchResults.length > 0

          Text {
            textFormat: Text.PlainText
            text: "Results (" + root.searchResults.length + ")"
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.left: parent.left
            anchors.leftMargin: Style.space(4)
          }

          Repeater {
            model: root.searchResults
            delegate: Rectangle {
              id: searchResultRow
              width: parent.width
              height: Style.space(46)
              radius: Style.cornerRadius
              color: searchResultArea.containsMouse ? Util.alpha(root.contentForeground, 0.08) : Util.alpha(root.contentForeground, 0.03)

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(10)

                // Image (Player headshot or Club crest)
                FutRemoteImage {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(32)
                  height: width
                  remoteSource: modelData.image
                  fillMode: Image.PreserveAspectFit
                  mipmap: true
                  smooth: true
                  visible: true
                }

                // Fallback icon if no image
                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(32)
                  height: width
                  verticalAlignment: Text.AlignVCenter
                  horizontalAlignment: Text.AlignHCenter
                  visible: !modelData.image || String(modelData.image) === ""
                  text: modelData.type === "player" ? "" : "󰕲"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  color: Qt.darker(root.contentForeground, 1.4)
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(70)
                  spacing: Style.space(2)

                  Row {
                    spacing: Style.space(6)
                    Text {
                      textFormat: Text.PlainText
                      text: modelData.displayName
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                      elide: Text.ElideRight
                    }
                    Text {
                      textFormat: Text.PlainText
                      anchors.verticalCenter: parent.verticalCenter
                      text: "· " + (modelData.type === "player" ? "Player" : "Club")
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: Qt.darker(root.contentForeground, 1.45)
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: modelData.subtitle
                    color: Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    visible: text !== ""
                  }
                }

                Text {
                  textFormat: Text.PlainText
                  anchors.verticalCenter: parent.verticalCenter
                  text: ""
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  color: Qt.darker(root.contentForeground, 1.6)
                }
              }

              FutActionArea {
    actionLabel: "Open player profile"

                id: searchResultArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onActivated: {
                  if (modelData.type === "player") {
                    root.openPlayerSearchDetail(modelData)
                  } else {
                    root.openClubSearchDetail(modelData)
                  }
                }
              }
            }
          }
        }
        } // searchMainSection

        // Dedicated Profile View: Shown when a player or club profile is selected
        FutProfileView {
          id: profileDedicatedView
          root: popup.root
        }
}

      MatchDetailView {
        id: matchDetailView
        root: popup.root
      }

      FutTrendingView {
        id: internalTrendingView
        root: popup.root
      }

      FutStandingsView {
        id: internalStandingsView
        root: popup.root
      }

      // League Matches: what matters for the selected league — everything
      // live, the next few upcoming fixtures, and the last few results.
      Component {
        id: matchRowDelegate

          Item {
            id: matchRow
            required property var modelData
            width: parent ? parent.width : 0

            readonly property int rowVPadding: Style.space(5)
            readonly property int rowHPadding: Style.space(8)

            readonly property string cardDateText: {
              var d = ""
              if (matchRow.modelData.dateText && matchRow.modelData.dateText !== "") d = matchRow.modelData.dateText
              else if (matchRow.modelData.kickoff) d = root.sanitizePlainText(Qt.formatDate(new Date(matchRow.modelData.kickoff), "ddd d MMM yyyy"))
              else if (matchRow.modelData.date) d = root.sanitizePlainText(Qt.formatDate(new Date(matchRow.modelData.date), "ddd d MMM yyyy"))
              return d
            }

            readonly property string cardStageText: {
              if (root.showClubFixtures && matchRow.modelData && matchRow.modelData.competitionName) {
                return matchRow.modelData.competitionName.toUpperCase()
              }
              if (matchRow.modelData && matchRow.modelData.roundName) {
                return matchRow.modelData.roundName
              }
              return ""
            }

            readonly property bool hasSubText: matchRow.modelData.state === "in" || matchRow.modelData.state === "post" || (matchRow.modelData.shootoutNote && matchRow.modelData.shootoutNote !== "") || (matchRow.modelData.seriesNote && matchRow.modelData.seriesNote !== "")

            // Slim compact card height preserving original thickness with match date included
            height: matchColumn.implicitHeight + rowVPadding * 2 + (hasSubText ? Style.space(4) : 0)

            readonly property bool rowFollowable: root.leagueMode && !root.leagueBrowseAll && modelData.id !== ""
              && (modelData.state === "in"
                  || (modelData.state === "pre"
                      && modelData.kickoff - Date.now() <= root.followLeadMs))
            readonly property bool rowFollowed: root.leagueMode && !root.leagueBrowseAll
              && root.isLeagueMatchFollowed(modelData.id)

            readonly property bool isKeyboardSelected: {
              if (root.keyboardSelectedMainMatchIndex < 0) return false
              var matches = root.getVisibleMainMatches()
              return matches[root.keyboardSelectedMainMatchIndex] && matchRow.modelData && (String(matches[root.keyboardSelectedMainMatchIndex].id) === String(matchRow.modelData.id))
            }

            Rectangle {
              anchors.fill: parent
              radius: Style.space(6)
              color: root.contentForeground
              opacity: matchRow.modelData.state === "in" ? 0.07 : ((rowMouseArea.containsMouse || matchRow.isKeyboardSelected) ? 0.06 : 0.03)
              border.width: matchRow.isKeyboardSelected ? 2 : 0
              border.color: (root.favoriteTeamAccent && root.favoriteTeamAccent !== "") ? root.favoriteTeamAccent : Commons.Color.accent
              Behavior on opacity { NumberAnimation { duration: root && root.reducedMotion ? 0 : 120 } }
            }

            FutActionArea {
    actionLabel: "Open match details"

              id: rowMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onActivated: root.openMatchDetail(matchRow.modelData)
              onDoubleClicked: root.openMatchDetail(matchRow.modelData)
            }

            Column {
              id: matchColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.leftMargin: matchRow.rowHPadding
              anchors.rightMargin: matchRow.rowHPadding
              anchors.topMargin: matchRow.rowVPadding
              spacing: Style.space(2)

              // Top Line: Follow button + Match date/time on top left, Competition/Round on top right
              Item {
                width: parent.width
                height: Style.space(12)
                visible: matchRow.cardDateText !== "" || matchRow.rowFollowable || matchRow.cardStageText !== ""

                Button {
                  focusable: true
                  Accessible.role: Accessible.Button
                  Accessible.name: tooltipText || text || "Action"

                  id: matchFollowBtn
                  z: 2
                  visible: matchRow.rowFollowable
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: matchRow.rowFollowed ? "󰴅" : "󰡬"
                  text: matchRow.rowFollowed ? "Following" : "Follow"
                  tooltipText: matchRow.rowFollowed ? "Stop notifications for this match" : "Notify on goals, cards, half-time and full-time"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.space(8)
                  iconSize: Style.space(8)
                  horizontalPadding: Style.space(5)
                  verticalPadding: 0
                  height: Style.space(13)
                  selected: matchRow.rowFollowed
                  onClicked: root.toggleLeagueMatchFollow(matchRow.modelData.id)
                }

                // Match Date & Time on top left
                Text {
                  id: matchCardDate
                  textFormat: Text.PlainText
                  anchors.left: matchFollowBtn.visible ? matchFollowBtn.right : parent.left
                  anchors.leftMargin: matchFollowBtn.visible ? Style.space(6) : 0
                  anchors.right: matchCardStage.visible ? matchCardStage.left : parent.right
                  anchors.rightMargin: matchCardStage.visible ? Style.space(6) : 0
                  anchors.verticalCenter: parent.verticalCenter
                  text: matchRow.cardDateText
                  color: Qt.darker(root.contentForeground, 1.55)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.space(8.5)
                  font.bold: true
                  elide: Text.ElideRight
                  visible: text !== ""
                }

                // Stage / Round or Competition Tag on top right
                Text {
                  id: matchCardStage
                  textFormat: Text.PlainText
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  visible: text !== ""
                  text: matchRow.cardStageText
                  color: (root.showClubFixtures && root.favoriteTeamAccent && root.favoriteTeamAccent !== "")
                    ? root.favoriteTeamAccent
                    : (root.showClubFixtures ? Commons.Color.accent : Qt.darker(root.contentForeground, 1.7))
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.space(8.5)
                  font.letterSpacing: 0.5
                  font.bold: true
                  horizontalAlignment: Text.AlignRight
                  elide: Text.ElideRight
                }
              }

              // Matchup Row: Home Crest & Name - Center Score / Status - Away Name & Crest
              Row {
                id: panelMatchupRow
                width: parent.width
                height: Math.max(root.matchLogoSize, panelHomeNameText.implicitHeight, panelAwayNameText.implicitHeight, centerScoreItem.height)
                spacing: Style.space(6)

                Item {
                  width: root.matchLogoSize
                  height: root.matchLogoSize
                  anchors.verticalCenter: parent.verticalCenter

                  FutRemoteImage {
                    anchors.centerIn: parent
                    width: root.matchLogoSize
                    height: root.matchLogoSize
                    remoteSource: matchRow.modelData.homeLogo
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 96
                    sourceSize.height: 96
                    mipmap: true
                    cache: true
                    asynchronous: true
                    smooth: true
                    visible: true
                  }
                }

                Text {
                  id: panelHomeNameText
                  textFormat: Text.PlainText
                  width: (parent.width - parent.spacing * 4 - root.matchScoreWidth - root.matchLogoSize * 2) / 2
                  anchors.verticalCenter: parent.verticalCenter
                  text: matchRow.modelData.homeName
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: text.length > 22 ? Style.space(10) : (text.length > 15 ? Style.font.bodySmall : Style.font.body)
                  font.bold: matchRow.modelData.state === "in"
                  wrapMode: Text.Wrap
                  elide: Text.ElideNone
                  lineHeight: 1.1
                  horizontalAlignment: Text.AlignHCenter
                }

                // Center Score, Kickoff Time, and Status (FT, 67', etc.)
                Item {
                  id: centerScoreItem
                  width: root.matchScoreWidth
                  height: Math.max(root.matchLogoSize, panelScoreCol.implicitHeight)
                  anchors.verticalCenter: parent.verticalCenter

                  Column {
                    id: panelScoreCol
                    anchors.centerIn: parent
                    spacing: Style.space(1)

                    Text {
                      id: matchScoreText
                      textFormat: Text.PlainText
                      anchors.horizontalCenter: parent.horizontalCenter
                      property bool revealed: false
                      text: matchRow.modelData.state === "pre"
                        ? (matchRow.modelData.timeText || "VS")
                        : ((root.spoilersHidden && !revealed)
                          ? (matchRow.modelData.state === "post" ? "FT · 󰈈" : "Live · 󰈈")
                          : (matchRow.modelData.homeScore + "–" + matchRow.modelData.awayScore))
                      color: (root.spoilersHidden && !revealed && matchRow.modelData.state !== "pre")
                        ? (root.favoriteTeamAccent || root.contentForeground)
                        : root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: (root.spoilersHidden && !revealed && matchRow.modelData.state !== "pre")
                        ? Style.font.caption
                        : Style.font.body
                      font.bold: matchRow.modelData.state !== "post"
                      horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                      id: matchRowSubText
                      textFormat: Text.PlainText
                      anchors.horizontalCenter: parent.horizontalCenter
                      visible: text !== "" && !(root.spoilersHidden && !matchScoreText.revealed)
                      text: {
                        if (matchRow.modelData.state === "in") {
                          return matchRow.modelData.status || "Live"
                        }
                        if (matchRow.modelData.state === "post") {
                          var s = matchRow.modelData.status || "FT"
                          var sLower = s.toLowerCase()
                          if (sLower.indexOf("won") !== -1 || sLower.indexOf("advance") !== -1 || sLower.indexOf("pen") !== -1 || sLower.indexOf("win") !== -1) {
                            return "FT"
                          }
                          return s
                        }
                        return ""
                      }
                      color: matchRow.modelData.state === "in"
                        ? "#4ade80" : Qt.darker(root.contentForeground, 1.6)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.space(8)
                      font.bold: true
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                      width: root.matchScoreWidth
                    }
                  }

                  FutActionArea {
    actionLabel: "Reveal score"

                    anchors.fill: parent
                    enabled: root.spoilersHidden && !matchScoreText.revealed && matchRow.modelData.state !== "pre"
                    cursorShape: Qt.PointingHandCursor
                    onActivated: matchScoreText.revealed = true
                  }
                }

                Text {
                  id: panelAwayNameText
                  textFormat: Text.PlainText
                  width: (parent.width - parent.spacing * 4 - root.matchScoreWidth - root.matchLogoSize * 2) / 2
                  anchors.verticalCenter: parent.verticalCenter
                  text: matchRow.modelData.awayName
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: text.length > 22 ? Style.space(10) : (text.length > 15 ? Style.font.bodySmall : Style.font.body)
                  font.bold: matchRow.modelData.state === "in"
                  wrapMode: Text.Wrap
                  elide: Text.ElideNone
                  lineHeight: 1.1
                  horizontalAlignment: Text.AlignHCenter
                }

                Item {
                  width: root.matchLogoSize
                  height: root.matchLogoSize
                  anchors.verticalCenter: parent.verticalCenter

                  FutRemoteImage {
                    anchors.centerIn: parent
                    width: root.matchLogoSize
                    height: root.matchLogoSize
                    remoteSource: matchRow.modelData.awayLogo
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 96
                    sourceSize.height: 96
                    mipmap: true
                    cache: true
                    asynchronous: true
                    smooth: true
                    visible: true
                  }
                }
              }

              // Bottom outcome / penalty / series note across full card width
              Text {
                id: matchCardBottomNote
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Style.space(16)
                visible: text !== "" && !(root.spoilersHidden && !matchScoreText.revealed)
                text: {
                  var shoot = matchRow.modelData.shootoutNote || ""
                  var ser = matchRow.modelData.seriesNote || ""
                  if (ser !== "") return ser
                  if (shoot !== "") return shoot
                  return ""
                }
                color: Qt.darker(root.contentForeground, 1.45)
                font.family: root.contentFontFamily
                font.pixelSize: Style.space(8.5)
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
              }
            }
          }
      }

      FutStatsView {
        id: statsView
        root: popup.root
      }

      // Selected club's own full fixtures list (5 matches per view with Earlier/Later navigation)
      Column {
        id: clubFixturesView
        width: parent.width
        spacing: Style.space(12)
        visible: !root.leagueMode && root.showClubFixtures && !root.showStandings && !root.showStats && !root.showMatchDetail && !root.showTrending

        Item {
          width: parent.width
          height: Math.max(Style.space(220), clubFixturesInnerCol.implicitHeight)

          Column {
            id: clubFixturesInnerCol
            width: parent.width
            spacing: Style.space(12)
            opacity: (root.loading && root.teamFixtureRows.length === 0) ? 0.15 : (root.loading ? 0.85 : 1.0)
            Behavior on opacity { NumberAnimation { duration: root && root.reducedMotion ? 0 : 180 } }

            Item {
              width: parent.width
              height: clubFixturesTitleText.implicitHeight

          Text {
            id: clubFixturesTitleText
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            opacity: root.loading ? 0.4 + 0.6 * root._pulse : 1.0
            text: root.loading
              ? ("Fetching " + root.teamName + " fixtures…")
              : (root.teamFixtureRows.length > 0 ? (root.teamName + " Fixtures") : ("No fixtures found for " + root.teamName))
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
          }
        }

        Column {
          width: parent.width
          spacing: 0
          visible: root.teamFixtureRows.length > 0

          Repeater {
            model: root.pagedClubRows
            delegate: matchRowDelegate
          }
        }

        // Navigation arrows below the 5 fixtures
        Item {
          width: parent.width
          height: Style.space(32)
          visible: root.clubPageCount > 1

          Button {
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: tooltipText || text || "Action"

            id: clubPrevPageBtn
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(85)
            height: Style.space(28)
            iconText: ""
            text: "Earlier"
            enabled: root.clubFixturePage > 0
            opacity: root.clubFixturePage > 0 ? 1.0 : 0.4
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            iconSize: Style.font.caption
            horizontalPadding: Style.space(8)
            verticalPadding: 0
            onClicked: {
              if (root.clubFixturePage > 0) root.clubFixturePage--
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: (root.clubFixturePage * root.clubPageSize + 1) + "–" + Math.min((root.clubFixturePage + 1) * root.clubPageSize, root.teamFixtureRows.length) + " of " + root.teamFixtureRows.length
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Button {
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: tooltipText || text || "Action"

            id: clubNextPageBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(85)
            height: Style.space(28)
            iconText: ""
            text: "Later"
            enabled: root.clubFixturePage < root.clubPageCount - 1
            opacity: root.clubFixturePage < root.clubPageCount - 1 ? 1.0 : 0.4
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            iconSize: Style.font.caption
            horizontalPadding: Style.space(8)
            verticalPadding: 0
            onClicked: {
              if (root.clubFixturePage < root.clubPageCount - 1) root.clubFixturePage++
            }
          }
        }
          }

          LoadingOverlay {
            active: root.loading && root.teamFixtureRows.length === 0
            text: root.sanitizePlainText("Fetching " + root.teamName + " fixtures…")
          }
        }
      }

      // League Matchweek Fixtures and Daily Slate container
      Column {
        id: leagueMatchesView
        width: parent.width
        spacing: Style.space(12)
        visible: (root.leagueMode ? (!root.showStandings && !root.showStats && !root.showMatchDetail && !root.showSearch && !root.showTrending) : (root.showMatches && !root.showStandings && !root.showStats && !root.showMatchDetail && !root.showClubFixtures && !root.showSearch && !root.showTrending))

        Item {
          width: parent.width
          height: Math.max(Style.space(240), leagueMatchesInnerCol.implicitHeight)

          Column {
            id: leagueMatchesInnerCol
            width: parent.width
            spacing: Style.space(12)
            FutRequestStatus {
              request: root.matchListRequest
              error: root.matchListError
              hasData: root.matchWeekRows.length > 0
              foreground: root.contentForeground; fontFamily: root.contentFontFamily
              onRetryRequested: root.loadMatchList(true)
            }

            opacity: (root.matchListLoading && root.matchWeekRows.length === 0 && (root.leagueLive.length + root.leagueRecent.length + root.leagueUpcoming.length) === 0) ? 0.15 : (root.matchListLoading ? 0.85 : 1.0)
            Behavior on opacity { NumberAnimation { duration: root && root.reducedMotion ? 0 : 180 } }

            // Title and live indicator row
            Item {
              width: parent.width
              height: Math.max(matchTitleText.implicitHeight, (liveBadge.visible ? liveBadge.implicitHeight : 0))

              Text {
                id: matchTitleText
                textFormat: Text.PlainText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (liveBadge.visible ? liveBadge.width + Style.space(6) : 0)
                opacity: root.matchListLoading ? 0.4 + 0.6 * root._pulse : 1.0
                text: root.matchListError !== "" ? "Could not load matches"
                  : (root.leagueBrowseAll || !root.leagueMode || root.matchesSeasonOffset > 0
                    ? (root.matchWeekRows.length > 0 ? root.leagueLabel() : (root.matchListLoading ? "Fetching matches…" : "No fixtures for season"))
                    : ((root.leagueLive.length + root.leagueRecent.length + root.leagueUpcoming.length) > 0
                      ? root.leagueLabel() : (root.matchListLoading ? "Fetching matches…" : "No matches today")))
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                id: liveBadge
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                text: root.leagueMode ? (root.leagueLive.length + " live") : "Live"
                color: "#4ade80"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                visible: (root.matchesSeasonOffset === 0) && (root.leagueMode ? (root.leagueLive.length > 0) : (root.liveMatch !== null))
              }
            }

            // Controls row: Season Selector on left, Matchweek Nav on right
            Item {
              id: matchWeekControlsRow
              width: parent.width
              height: Math.max(seasonControlsRow.height, matchWeekNav.height)
              visible: !root.leagueMode || root.leagueBrowseAll || root.matchesSeasonOffset > 0

              Row {
                id: seasonControlsRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Button {
                  focusable: true
                  Accessible.role: Accessible.Button
                  Accessible.name: tooltipText || text || "Action"

                  id: prevMatchesSeasonBtn
                  width: Style.space(22)
                  height: Style.space(22)
                  iconText: ""
                  tooltipText: "Older season"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  iconSize: Style.font.caption
                  horizontalPadding: 0
                  verticalPadding: 0
                  onClicked: {
                    root.matchesSeasonOffset += (root.seasonStep ? root.seasonStep() : 1)
                    root.matchWindowOffset = 0
                    root.pendingEdge = ""
                    root.navAnchorDay = ""
                    root.matchClusters = []
                    root.matchClusterIndex = 0
                    root.loadMatchList(true)
                  }
                }

                Button {
                  focusable: true
                  Accessible.role: Accessible.Button
                  Accessible.name: tooltipText || text || "Action"

                  id: matchesSeasonChip
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(52)
                  height: Style.space(22)
                  text: root.seasonChipLabel(root.matchesSeasonOffset)
                  tooltipText: "Match season (click to return to current season)"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  fontSize: Style.font.caption
                  selected: root.matchesSeasonOffset > 0
                  horizontalPadding: 0
                  verticalPadding: 0
                  onClicked: {
                    if (root.matchesSeasonOffset > 0) {
                      root.matchesSeasonOffset = 0
                      root.matchWindowOffset = 0
                      root.pendingEdge = ""
                      root.navAnchorDay = ""
                      root.matchClusters = []
                      root.matchClusterIndex = 0
                      root.loadMatchList(true)
                    }
                  }
                }

                Button {
                  focusable: true
                  Accessible.role: Accessible.Button
                  Accessible.name: tooltipText || text || "Action"

                  id: nextMatchesSeasonBtn
                  width: Style.space(22)
                  height: Style.space(22)
                  iconText: ""
                  tooltipText: "Newer season"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  iconSize: Style.font.caption
                  horizontalPadding: 0
                  verticalPadding: 0
                  enabled: root.matchesSeasonOffset > 0
                  opacity: enabled ? 1.0 : 0.35
                  onClicked: {
                    root.matchesSeasonOffset = Math.max(0, root.matchesSeasonOffset - (root.seasonStep ? root.seasonStep() : 1))
                    root.matchWindowOffset = 0
                    root.pendingEdge = ""
                    root.navAnchorDay = ""
                    root.matchClusters = []
                    root.matchClusterIndex = 0
                    root.loadMatchList(true)
                  }
                }
              }

              Row {
                id: matchWeekNav
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Button {
                  focusable: true
                  Accessible.role: Accessible.Button
                  Accessible.name: tooltipText || text || "Action"

                  id: prevWeekButton
                  width: Style.space(24)
                  height: Style.space(24)
                  iconText: ""
                  tooltipText: "Previous matchweek"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  iconSize: Style.font.caption
                  horizontalPadding: 0
                  verticalPadding: 0
                  enabled: {
                    if (root.matchListLoading) return false
                    var calW = root.currentLeagueCalendarWeeks()
                    if (calW && calW.length > 0) {
                      var isPastSeason = root.matchesSeasonOffset > 0
                      var baseIdx = isPastSeason ? (calW.length - 1) : root.matchWeekBaseIndex(calW)
                      var activeIdx = baseIdx + root.matchWindowOffset
                      return activeIdx > 0
                    }
                    if (root.matchClusters.length > 1) {
                      return root.matchClusterIndex > 0
                    }
                    return true
                  }
                  opacity: enabled ? 1.0 : 0.35
                  onClicked: {
                    if (root.pendingEdge !== "") return
                    var calW = root.currentLeagueCalendarWeeks()
                    if (calW && calW.length > 0) {
                      if (matchListRequest.running) matchListRequest.running = false
                      root.matchWindowOffset--
                      root.pendingEdge = "prev"
                      root.resetPanelScroll()
                      root.loadMatchList(true)
                      return
                    }
                    if (root.matchClusters.length > 1 && root.matchClusterIndex > 0) {
                      root.matchClusterIndex--
                      root.resetPanelScroll()
                      return
                    }
                    if (matchListRequest.running) matchListRequest.running = false
                    root.matchWindowOffset--
                    root.pendingEdge = "prev"
                    root.resetPanelScroll()
                    root.loadMatchList(true)
                  }
                }

                Text {
                  id: matchWeekLabelText
                  textFormat: Text.PlainText
                  text: {
                    var wn = root.matchWeekNumber()
                    if (wn !== "") {
                      return (root.matchWeekLabel !== "" ? (root.matchWeekLabel + " · " + wn) : ("MW " + wn))
                    }
                    return root.matchWeekLabel
                  }
                  height: Style.space(24)
                  verticalAlignment: Text.AlignVCenter
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 0.5
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, Math.max(Style.space(60), matchWeekControlsRow.width - seasonControlsRow.width - prevWeekButton.width - nextWeekButton.width - Style.space(24)))
                }

                Button {
                  focusable: true
                  Accessible.role: Accessible.Button
                  Accessible.name: tooltipText || text || "Action"

                  id: nextWeekButton
                  width: Style.space(24)
                  height: Style.space(24)
                  iconText: ""
                  tooltipText: "Next matchweek"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  iconSize: Style.font.caption
                  horizontalPadding: 0
                  verticalPadding: 0
                  enabled: {
                    if (root.matchListLoading) return false
                    var calW = root.currentLeagueCalendarWeeks()
                    if (calW && calW.length > 0) {
                      var isPastSeason = root.matchesSeasonOffset > 0
                      var baseIdx = isPastSeason ? (calW.length - 1) : root.matchWeekBaseIndex(calW)
                      var activeIdx = baseIdx + root.matchWindowOffset
                      return activeIdx < calW.length - 1
                    }
                    if (root.matchClusters.length > 1) {
                      return root.matchClusterIndex < root.matchClusters.length - 1
                    }
                    return true
                  }
                  opacity: enabled ? 1.0 : 0.35
                  onClicked: {
                    if (root.pendingEdge !== "") return
                    var calW = root.currentLeagueCalendarWeeks()
                    if (calW && calW.length > 0) {
                      if (matchListRequest.running) matchListRequest.running = false
                      root.matchWindowOffset++
                      root.pendingEdge = "next"
                      root.resetPanelScroll()
                      root.loadMatchList(true)
                      return
                    }
                    if (root.matchClusters.length > 1 && root.matchClusterIndex < root.matchClusters.length - 1) {
                      root.matchClusterIndex++
                      root.resetPanelScroll()
                      return
                    }
                    if (matchListRequest.running) matchListRequest.running = false
                    root.matchWindowOffset++
                    root.pendingEdge = "next"
                    root.resetPanelScroll()
                    root.loadMatchList(true)
                  }
                }
              }
            }

                    Text {
          textFormat: Text.PlainText
          width: parent.width
          text: ((root.leagueLive.length + root.leagueRecent.length + root.leagueUpcoming.length) > 0)
            ? (root.formatCachedTimeAgo(root.lastMatchListRefresh) + " · " + root.matchListError)
            : root.matchListError
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          visible: root.matchListError !== ""
        }

        // Full league fixtures by matchweek
        Column {
          width: parent.width
          spacing: 0
          visible: ((root.leagueMode && (root.leagueBrowseAll || root.matchesSeasonOffset > 0)) || (!root.leagueMode && root.showMatches)) && root.matchWeekRows.length > 0

          Repeater {
            model: root.matchWeekRows
            delegate: matchRowDelegate
          }
        }

        // League-follow board: live now, then recent results, then what's
        // coming up — all from the same window fetch.
        Repeater {
          model: [
            { label: "Live Matches", rows: root.leagueLive },
            { label: "Recent Results", rows: root.leagueRecent },
            { label: "Scheduled Fixtures", rows: root.leagueUpcoming }
          ]

          delegate: Column {
            required property var modelData
            readonly property bool listIdle: root.matchListError === ""
            width: parent ? parent.width : 0
            spacing: Style.space(4)
            visible: root.leagueMode && !root.leagueBrowseAll && root.matchesSeasonOffset === 0 && listIdle && modelData.rows.length > 0

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: modelData.label
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Repeater {
              model: modelData.rows
              delegate: matchRowDelegate
            }
          }
        }

        Item {
          width: parent.width
          height: Style.space(32)
          visible: root.leagueMode && !root.leagueBrowseAll && !root.matchListLoading && root.matchListError === "" && (root.leagueLive.length + root.leagueRecent.length + root.leagueUpcoming.length) === 0

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: "No matches scheduled for today"
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // Daily slate option: navigate to all fixtures window. Always
        // available, even on load errors -- it is the way out of an
        // empty/failed slate into the matchweek view, and tapping it
        // retries the fetch (loadMatchList clears the error on start).
        Item {
          id: seeFixturesRow
          width: parent.width
          height: Style.space(38)
          visible: root.leagueMode && !root.leagueBrowseAll
          opacity: root.matchListLoading ? 0.5 : 1.0

          Rectangle {
            anchors.fill: parent
            radius: Style.space(6)
            color: root.contentForeground
            opacity: seeFixturesMouseArea.containsMouse ? 0.08 : 0.04
          }

          FutActionArea {
    actionLabel: "Open details"

            id: seeFixturesMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onActivated: root.showAllFixtures()
          }

          Row {
            anchors.centerIn: parent
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "󰕲"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: "Show full fixtures"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: ""
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
          }

          LoadingOverlay {
            active: root.matchListLoading && root.matchWeekRows.length === 0 && (root.leagueLive.length + root.leagueRecent.length + root.leagueUpcoming.length) === 0
            text: "Fetching fixtures…"
          }
        }
      }

      Item {
        id: overviewContainer
        width: parent.width
        height: Math.max(overviewInnerCol.implicitHeight, (root.loading && !root.liveMatch && !root.nextMatch && !root.previousMatch) ? Style.space(240) : 0)
        visible: !root.customViewActive

        Column {
          id: overviewInnerCol
          width: parent.width
          spacing: Style.space(14)
          opacity: (root.loading && !root.liveMatch && !root.nextMatch && !root.previousMatch) ? 0.15 : (root.loading ? 0.85 : 1.0)
          Behavior on opacity { NumberAnimation { duration: root && root.reducedMotion ? 0 : 180 } }

          Item {
            width: parent.width
            height: Style.space(20)
            visible: root.liveMatch && !root.customViewActive

        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "LIVE MATCH"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "LIVE"
          color: "#4ade80"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Item {
        id: liveMatchCard
        width: parent.width
        height: liveColumn.implicitHeight + Style.space(8)
        // The dedicated live card is redundant inside the League Matches / Stats
        // views and below the standings table.
        visible: root.liveMatch && !root.customViewActive
        readonly property bool isKeyboardSelected: {
          if (root.keyboardSelectedMainMatchIndex < 0) return false
          var matches = root.getVisibleMainMatches()
          return matches[root.keyboardSelectedMainMatchIndex] && root.liveMatch && (String(matches[root.keyboardSelectedMainMatchIndex].id) === String(root.liveMatch.id))
        }

        Rectangle {
          anchors.fill: parent
          radius: Style.space(6)
          color: root.contentForeground
          opacity: (liveCardArea.containsMouse || liveMatchCard.isKeyboardSelected) ? 0.09 : 0.07
          border.width: liveMatchCard.isKeyboardSelected ? 2 : 0
          border.color: (root.favoriteTeamAccent && root.favoriteTeamAccent !== "") ? root.favoriteTeamAccent : Commons.Color.accent
        }

        FutActionArea {
    actionLabel: "Open match details"

          id: liveCardArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onActivated: if (root.liveMatch) root.openMatchDetail(root.liveMatch)
          onDoubleClicked: if (root.liveMatch) root.openMatchDetail(root.liveMatch)
        }

        Column {
          id: liveColumn
          width: Style.space(348)
          anchors.centerIn: parent
          spacing: Style.space(6)
          topPadding: Style.space(8)
          bottomPadding: Style.space(8)

          Button {
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: tooltipText || text || "Action"

            id: liveFollowBtn
            z: 2
            anchors.horizontalCenter: parent.horizontalCenter
            iconText: root.liveActivity ? "󰴅" : "󰡬"
            text: root.liveActivity ? "Following" : "Follow"
            tooltipText: root.liveActivity ? "Stop match notifications" : "Notify on goals, cards, half-time, full-time and extra time"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            iconSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: Style.space(3)
            selected: root.liveActivity
            onClicked: root.liveActivity ? root.stopLiveActivity() : root.startLiveActivity()
          }

          Row {
            id: liveTeamsScoreRow
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            spacing: Style.space(8)

            FutRemoteImage { width: Style.space(50); height: width; remoteSource: root.teamLogoFor(root.liveMatch, "home"); fillMode: Image.PreserveAspectFit; asynchronous: true; cache: true; mipmap: true; smooth: true; anchors.verticalCenter: parent.verticalCenter; visible: true }
            Text {
              textFormat: Text.PlainText
              width: (parent.width - Style.space(50) * 2 - Style.space(90) - parent.spacing * 4) / 2
              anchors.verticalCenter: parent.verticalCenter
              text: root.teamNameFor(root.liveMatch, "home")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              elide: Text.ElideNone
            }
            Column {
              width: Style.space(90)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)
              clip: true

              Text {
                textFormat: Text.PlainText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                property bool revealed: false
                text: (root.spoilersHidden && !revealed) ? "Live · 󰈈" : (root.scoreFor(root.liveMatch, "home") + " – " + root.scoreFor(root.liveMatch, "away"))
                color: (root.spoilersHidden && !revealed) ? (root.favoriteTeamAccent || root.contentForeground) : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: (root.spoilersHidden && !revealed) ? Style.font.body : Style.font.title
                font.bold: true

                FutActionArea {
    actionLabel: "Reveal score"

                  anchors.fill: parent
                  enabled: root.spoilersHidden && !parent.revealed
                  cursorShape: Qt.PointingHandCursor
                  onActivated: parent.revealed = true
                }
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.statusFor(root.liveMatch)
                color: "#4ade80"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: text !== ""
              }
            }
            Text {
              textFormat: Text.PlainText
              width: (parent.width - Style.space(50) * 2 - Style.space(90) - parent.spacing * 4) / 2
              anchors.verticalCenter: parent.verticalCenter
              text: root.teamNameFor(root.liveMatch, "away")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              elide: Text.ElideNone
            }
            FutRemoteImage { width: Style.space(50); height: width; remoteSource: root.teamLogoFor(root.liveMatch, "away"); fillMode: Image.PreserveAspectFit; asynchronous: true; cache: true; mipmap: true; smooth: true; anchors.verticalCenter: parent.verticalCenter; visible: true }
          }

          Item {
            width: 1
            height: Style.space(6)
            visible: root.liveHasGoals()
          }

          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.liveHasGoals()

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing) / 2
              text: root.liveGoalsFor("home")
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignLeft
              wrapMode: Text.WordWrap
            }

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing) / 2
              text: root.liveGoalsFor("away")
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
              wrapMode: Text.WordWrap
            }
          }

          Row {
            id: liveCompRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(5)
            FutRemoteImage { id: competitionLogo; width: Style.space(14); height: width; remoteSource: root.competitionLogoFor(root.liveMatch); fillMode: Image.PreserveAspectFit; asynchronous: true; cache: true; mipmap: true; smooth: true; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 2; visible: true }
            Text {
              textFormat: Text.PlainText
              text: root.competitionNameFor(root.liveMatch)
              anchors.verticalCenter: competitionLogo.verticalCenter
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // Bottom spacer to equalize distance from center to top and bottom
          Item {
            width: 1
            height: Math.max(0, liveFollowBtn.implicitHeight - liveCompRow.implicitHeight)
            visible: !root.liveHasGoals()
          }
        }
      }

      Rectangle {
        width: parent.width
        height: Style.spacing.hairline
        color: root.contentForeground
        opacity: 0.15
        // Only separate the live card from the next card; without a live match
        // the header's own hairline is the single separator at the top.
        visible: root.liveMatch && !root.customViewActive
      }

      Item {
        width: parent.width
        height: Style.space(20)
        visible: !root.customViewActive && !!root.nextMatch

        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "NEXT MATCH"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.kickoffDay(root.nextMatch) + " · " + root.kickoffTime(root.nextMatch)
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Item {
        id: nextMatchCard
        width: parent.width
        height: nextMatchCol.implicitHeight + Style.space(16)
        visible: !root.customViewActive && !!root.nextMatch
        readonly property bool isKeyboardSelected: {
          if (root.keyboardSelectedMainMatchIndex < 0) return false
          var matches = root.getVisibleMainMatches()
          return matches[root.keyboardSelectedMainMatchIndex] && root.nextMatch && (String(matches[root.keyboardSelectedMainMatchIndex].id) === String(root.nextMatch.id))
        }

        Rectangle {
          anchors.fill: parent
          radius: Style.space(6)
          color: root.contentForeground
          opacity: (nextCardArea.containsMouse || nextMatchCard.isKeyboardSelected) ? 0.08 : 0.03
          border.width: nextMatchCard.isKeyboardSelected ? 2 : 0
          border.color: (root.favoriteTeamAccent && root.favoriteTeamAccent !== "") ? root.favoriteTeamAccent : Commons.Color.accent
        }

        FutActionArea {
    actionLabel: "Open match details"

          id: nextCardArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onActivated: if (root.nextMatch) root.openMatchDetail(root.nextMatch)
          onDoubleClicked: if (root.nextMatch) root.openMatchDetail(root.nextMatch)
        }

        Column {
          id: nextMatchCol
          anchors.fill: parent
          anchors.topMargin: Style.space(8)
          anchors.bottomMargin: Style.space(8)
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(6)

          Row {
            width: parent.width
            spacing: Style.space(8)

            FutRemoteImage {
              width: Style.space(36)
              height: width
              remoteSource: root.teamLogoFor(root.nextMatch, "home")
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              anchors.verticalCenter: parent.verticalCenter
              visible: true
            }

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing * 4 - Style.space(36) * 2 - Style.space(36)) / 2
              anchors.verticalCenter: parent.verticalCenter
              text: root.teamNameFor(root.nextMatch, "home")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              elide: Text.ElideNone
            }

            Text {
              textFormat: Text.PlainText
              width: Style.space(36)
              anchors.verticalCenter: parent.verticalCenter
              horizontalAlignment: Text.AlignHCenter
              text: "vs"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing * 4 - Style.space(36) * 2 - Style.space(36)) / 2
              anchors.verticalCenter: parent.verticalCenter
              text: root.teamNameFor(root.nextMatch, "away")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              elide: Text.ElideNone
            }

            FutRemoteImage {
              width: Style.space(36)
              height: width
              remoteSource: root.teamLogoFor(root.nextMatch, "away")
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              anchors.verticalCenter: parent.verticalCenter
              visible: true
            }
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(5)
            FutRemoteImage {
              width: Style.space(18)
              height: width
              remoteSource: root.competitionLogoFor(root.nextMatch)
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              anchors.verticalCenter: parent.verticalCenter
              visible: true
            }
            Text {
              textFormat: Text.PlainText
              text: root.competitionNameFor(root.nextMatch)
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: Style.spacing.hairline
        color: root.contentForeground
        opacity: 0.15
        visible: !root.customViewActive && !!root.nextMatch && !!root.previousMatch
      }

      Item {
        width: parent.width
        height: Style.space(20)
        visible: !root.customViewActive && !!root.previousMatch

        Text {
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "PREVIOUS MATCH"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.kickoffDay(root.previousMatch) + " · " + root.statusFor(root.previousMatch)
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Item {
        id: prevMatchCard
        width: parent.width
        height: prevMatchCol.implicitHeight + Style.space(16)
        visible: !root.customViewActive && !!root.previousMatch
        readonly property bool isKeyboardSelected: {
          if (root.keyboardSelectedMainMatchIndex < 0) return false
          var matches = root.getVisibleMainMatches()
          return matches[root.keyboardSelectedMainMatchIndex] && root.previousMatch && (String(matches[root.keyboardSelectedMainMatchIndex].id) === String(root.previousMatch.id))
        }

        Rectangle {
          anchors.fill: parent
          radius: Style.space(6)
          color: root.contentForeground
          opacity: (prevCardArea.containsMouse || prevMatchCard.isKeyboardSelected) ? 0.08 : 0.03
          border.width: prevMatchCard.isKeyboardSelected ? 2 : 0
          border.color: (root.favoriteTeamAccent && root.favoriteTeamAccent !== "") ? root.favoriteTeamAccent : Commons.Color.accent
        }

        FutActionArea {
    actionLabel: "Open match details"

          id: prevCardArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onActivated: if (root.previousMatch) root.openMatchDetail(root.previousMatch)
          onDoubleClicked: if (root.previousMatch) root.openMatchDetail(root.previousMatch)
        }

        Column {
          id: prevMatchCol
          anchors.fill: parent
          anchors.topMargin: Style.space(8)
          anchors.bottomMargin: Style.space(8)
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(6)

          Row {
            width: parent.width
            spacing: Style.space(8)

            FutRemoteImage {
              width: Style.space(36)
              height: width
              remoteSource: root.teamLogoFor(root.previousMatch, "home")
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              anchors.verticalCenter: parent.verticalCenter
              visible: true
            }

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing * 4 - Style.space(36) * 2 - Style.space(60)) / 2
              anchors.verticalCenter: parent.verticalCenter
              text: root.teamNameFor(root.previousMatch, "home")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              elide: Text.ElideNone
            }

            Text {
              textFormat: Text.PlainText
              width: Style.space(60)
              anchors.verticalCenter: parent.verticalCenter
              horizontalAlignment: Text.AlignHCenter
              property bool revealed: false
              text: (root.spoilersHidden && !revealed) ? "FT · 󰈈" : (root.scoreFor(root.previousMatch, "home") + " – " + root.scoreFor(root.previousMatch, "away"))
              color: (root.spoilersHidden && !revealed) ? (root.favoriteTeamAccent || root.contentForeground) : root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true

              FutActionArea {
    actionLabel: "Reveal score"

                anchors.fill: parent
                enabled: root.spoilersHidden && !parent.revealed
                cursorShape: Qt.PointingHandCursor
                onActivated: parent.revealed = true
              }
            }

            Text {
              textFormat: Text.PlainText
              width: (parent.width - parent.spacing * 4 - Style.space(36) * 2 - Style.space(60)) / 2
              anchors.verticalCenter: parent.verticalCenter
              horizontalAlignment: Text.AlignHCenter
              text: root.teamNameFor(root.previousMatch, "away")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
              elide: Text.ElideNone
            }

            FutRemoteImage {
              width: Style.space(36)
              height: width
              remoteSource: root.teamLogoFor(root.previousMatch, "away")
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              anchors.verticalCenter: parent.verticalCenter
              visible: true
            }
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(5)
            FutRemoteImage {
              width: Style.space(18)
              height: width
              remoteSource: root.competitionLogoFor(root.previousMatch)
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              anchors.verticalCenter: parent.verticalCenter
              visible: true
            }
            Text {
              textFormat: Text.PlainText
              text: root.competitionNameFor(root.previousMatch)
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      Item {
        id: clubSeeFixturesRow
        width: parent.width
        height: Style.space(38)
        visible: !root.customViewActive && !root.loading && root.requestError === "" && (root.nextMatch || root.previousMatch)

        Rectangle {
          anchors.fill: parent
          radius: Style.space(6)
          color: root.contentForeground
          opacity: clubSeeFixturesMouseArea.containsMouse ? 0.08 : 0.04
        }

        FutActionArea {
    actionLabel: "Open details"

          id: clubSeeFixturesMouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onActivated: root.showClubAllFixtures()
        }

        Row {
          anchors.centerIn: parent
          spacing: Style.space(8)

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: "󰕲"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: "Show full fixtures"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Rectangle {
        visible: !root.customViewActive && root.requestError !== ""
        width: parent.width
        implicitHeight: staleErrCol.implicitHeight + Style.space(12)
        radius: Style.cornerRadius
        color: Util.alpha(Commons.Color.accent, 0.12)

        Column {
          id: staleErrCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          Row {
            spacing: Style.space(6)
            Text {
              textFormat: Text.PlainText
              text: "󰅢"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              textFormat: Text.PlainText
              text: (root.nextMatch || root.previousMatch || root.liveMatch) ? root.formatCachedTimeAgo(root.lastRefresh) : "Network Offline"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.requestError
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.space(10)
            wrapMode: Text.WordWrap
          }
        }
      }
        }

        LoadingOverlay {
          active: root.loading && !root.liveMatch && !root.nextMatch && !root.previousMatch
          text: root.sanitizePlainText("Fetching " + (root.teamName || "fixtures") + "…")
        }
      }

    }

          FutUpdatedLabel {
            updatedAt: (root.showMatches || root.showClubFixtures || root.leagueMode) ? root.matchListRequest.lastSucceededAt : Number(root.lastRefresh || 0)
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            visible: recent && !root.showNews && !root.showStandings && !root.showStats && !root.showTrending && !root.showMatchDetail && !root.showSearch && !root.showSettings && !root.needsTeam && !root.editingTeam
          }
        }
  }
}
}
