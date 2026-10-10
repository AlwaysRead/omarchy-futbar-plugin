import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Column {
  id: matchDetailView
  property var root: null
  visible: root ? root.showMatchDetail : false
  width: parent ? parent.width : 0
  spacing: Style.space(12)

  property bool expandAllStats: false
  property bool heroScoreRevealed: false
  property var selectedFormMatch: null
  onVisibleChanged: {
    if (!visible) {
      expandAllStats = false
      heroScoreRevealed = false
      selectedFormMatch = null
    }
  }

  function isKeyStat(statName) {
    return statName === "expectedGoals"
        || statName === "possessionPct"
        || statName === "totalShots"
        || statName === "shotsOnTarget"
        || statName === "passPct"
        || statName === "wonCorners"
        || statName === "foulsCommitted"
        || statName === "saves"
  }

  readonly property var visibleStats: {
    var all = (root && root.matchDetail && root.matchDetail.stats) ? root.matchDetail.stats : []
    if (expandAllStats || all.length <= 8) return all
    var keyList = all.filter(function(s) { return matchDetailView.isKeyStat(s.name) })
    return keyList.length >= 4 ? keyList : all.slice(0, 8)
  }

  property string commentaryFilter: "all"
  property bool copySuccess: false

  Timer {
    id: copyResetTimer
    interval: 2000
    onTriggered: matchDetailView.copySuccess = false
  }

  Process {
    id: copyProcess
    running: false
  }

  function copyMatchSummary() {
    if (!root || !root.matchDetail) return
    var md = root.matchDetail
    var hName = md.home ? (md.home.name || "Home") : "Home"
    var aName = md.away ? (md.away.name || "Away") : "Away"
    var hScore = (md.home && md.home.score !== undefined) ? String(md.home.score) : ""
    var aScore = (md.away && md.away.score !== undefined) ? String(md.away.score) : ""
    var status = md.status || (md.started ? "FT" : "Scheduled")
    var comp = md.competitionName || ""

    var summary = ""
    if (md.started) {
      summary = hName + " " + hScore + " – " + aScore + " " + aName + " (" + status + ")"
    } else {
      summary = hName + " vs " + aName + " (" + status + ")"
    }
    if (comp !== "") summary += " · " + comp
    if ((md.homeScorers && md.homeScorers.length > 0) || (md.awayScorers && md.awayScorers.length > 0)) {
      var hs = (md.homeScorers || []).join(", ")
      var as = (md.awayScorers || []).join(", ")
      summary += "\n" + hName + ": " + (hs || "None") + " | " + aName + ": " + (as || "None")
    }

    copyProcess.command = ["wl-copy", "--", summary]
    copyProcess.running = false
    copyProcess.running = true
    matchDetailView.copySuccess = true
    copyResetTimer.restart()
  }

  function filteredCommentary() {
    if (!root || !root.matchDetail || !Array.isArray(root.matchDetail.commentary)) return []
    var all = root.matchDetail.commentary
    if (matchDetailView.commentaryFilter === "all") return all
    var res = []
    for (var i = 0; i < all.length; i++) {
      var item = all[i]
      if (!item) continue
      var txt = (item.text || "").toLowerCase()
      var typ = (item.type || "").toLowerCase()
      if (matchDetailView.commentaryFilter === "goals_cards") {
        if (txt.indexOf("goal") !== -1 || txt.indexOf("penalty") !== -1 || txt.indexOf("card") !== -1 || txt.indexOf("sent off") !== -1 || typ.indexOf("goal") !== -1 || typ.indexOf("card") !== -1) {
          res.push(item)
        }
      } else if (matchDetailView.commentaryFilter === "shots") {
        if (txt.indexOf("shot") !== -1 || txt.indexOf("attempt") !== -1 || txt.indexOf("header") !== -1 || txt.indexOf("crossbar") !== -1 || txt.indexOf("post") !== -1 || typ.indexOf("shot") !== -1) {
          res.push(item)
        }
      } else if (matchDetailView.commentaryFilter === "subs") {
        if (txt.indexOf("substitution") !== -1 || txt.indexOf("replaces") !== -1 || typ.indexOf("sub") !== -1) {
          res.push(item)
        }
      }
    }
    return res
  }

  component LoadingOverlay: FutLoadingOverlay { root: matchDetailView.root }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            id: backBtn
            width: (root && root.returnToTrendingAfterDetail) ? implicitWidth : Style.space(26)
            height: Style.space(26)
            text: (root && root.returnToTrendingAfterDetail) ? "Trending" : ""
            iconText: ""
            tooltipText: (root && root.returnToTrendingAfterDetail) ? "Back to Trending (l)" : "Back to matches (m)"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            iconSize: Style.font.caption
            horizontalPadding: (root && root.returnToTrendingAfterDetail) ? Style.space(8) : 0
            verticalPadding: 0
            onClicked: root.showMatchDetail = false
          }

          Column {
            id: matchDetailTitleCol
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - backBtn.width - copyMatchBtn.width - (parent.spacing * 2)
            spacing: Style.space(1)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.matchDetail ? (root.matchDetail.competitionName || "Match Details") : "Match Details"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              visible: text !== ""
              text: (root.matchDetail && root.matchDetail.roundName) ? root.matchDetail.roundName : ""
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption - 1
              font.bold: true
              elide: Text.ElideRight
            }
          }

          Button {
            id: copyMatchBtn
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(26)
            height: Style.space(26)
            iconText: matchDetailView.copySuccess ? "\uf00c" : "\uf0c5"
            tooltipText: matchDetailView.copySuccess ? "Copied match summary!" : "Copy match summary to clipboard"
            fontFamily: root.contentFontFamily
            foreground: matchDetailView.copySuccess ? ((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : ShellColor.accent) : root.contentForeground
            accent: root.contentForeground
            iconSize: Style.font.caption
            horizontalPadding: 0
            verticalPadding: 0
            visible: !!root.matchDetail
            onClicked: matchDetailView.copyMatchSummary()
          }
        }

        Item {
          width: parent.width
          implicitHeight: Math.max(Style.space(260), matchDetailInnerCol.implicitHeight)
          height: implicitHeight

          Column {
            id: matchDetailInnerCol
            width: parent.width
            spacing: Style.space(12)
            opacity: (root.matchDetailLoading && !root.matchDetail) ? 0.15 : (root.matchDetailLoading ? 0.85 : 1.0)
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // Scoreboard Hero Card
        Item {
          id: heroCard
          width: parent.width
          readonly property real matchContentBottom: (dateTextHeader.visible && dateTextHeader.text !== "" ? dateTextHeader.implicitHeight + Style.space(6) : Style.space(10)) + Math.max(scoreCenterCol.implicitHeight, Math.max(homeSideCol.implicitHeight, awaySideCol.implicitHeight))
          height: Math.max(Style.space(114), heroCard.matchContentBottom + (matchResultBottomArea.visible ? matchResultBottomArea.implicitHeight + Style.space(24) : Style.space(14)))

          Rectangle {
            anchors.fill: parent
            radius: Style.space(8)
            color: root.contentForeground
            opacity: (root.matchDetail && root.matchDetail.isLive) ? 0.07 : 0.03
          }

          Text {
            id: dateTextHeader
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Style.space(8)
            text: root.matchDetail ? (root.matchDetail.dateFormatted || "") : ""
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.NoWrap
            visible: text !== ""
          }

          // Center Score & Status
          Column {
            id: scoreCenterCol
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: (dateTextHeader.visible && dateTextHeader.text !== "") ? dateTextHeader.bottom : parent.top
            anchors.topMargin: (dateTextHeader.visible && dateTextHeader.text !== "") ? Style.space(6) : Style.space(10)
            width: Style.space(90)
            spacing: Style.space(4)

            // Upper area: Score centered between the crests (height: Style.space(50))
            Item {
              id: heroScoreArea
              width: parent.width
              height: Style.space(50)

              // Anti-spoiler conceal badge
              Rectangle {
                anchors.centerIn: parent
                visible: !!(root && root.antiSpoiler && !matchDetailView.heroScoreRevealed && root.matchDetail && root.matchDetail.started)
                width: Style.space(76)
                height: Style.space(26)
                radius: Style.cornerRadius
                color: heroScoreMouse.containsMouse ? Util.alpha((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : ShellColor.accent, 0.25) : Util.alpha((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : ShellColor.accent, 0.12)
                border.width: Style.spacing.hairline
                border.color: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : ShellColor.accent

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰈈"
                    font.pixelSize: Style.font.caption
                    color: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : ShellColor.accent
                  }
                  Text {
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Reveal"
                    font.family: root ? root.contentFontFamily : Style.font.family
                    font.pixelSize: Style.font.caption - 1
                    font.bold: true
                    color: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : ShellColor.accent
                  }
                }

                MouseArea {
                  id: heroScoreMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: matchDetailView.heroScoreRevealed = true
                }
              }

              Text {
                id: heroScoreText
                textFormat: Text.PlainText
                anchors.centerIn: parent
                visible: !(root && root.antiSpoiler && !matchDetailView.heroScoreRevealed && root.matchDetail && root.matchDetail.started)
                text: (root.matchDetail && root.matchDetail.started && root.matchDetail.home && root.matchDetail.away)
                  ? (root.matchDetail.home.score + " – " + root.matchDetail.away.score) : "vs"
                color: (root.matchDetail && !root.matchDetail.started) ? Qt.darker(root.contentForeground, 1.5) : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: (root.matchDetail && !root.matchDetail.started) ? Style.font.body : Style.font.title
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
              }
            }

            // Lower area: Full Time / Status text below the score, aligned with club names
            Column {
              width: parent.width
              spacing: Style.space(2)

              Text {
                id: statusText
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.matchDetail ? (root.matchDetail.status || (root.matchDetail.started ? "Full Time" : "Scheduled")) : "Full Time"
                color: (root.matchDetail && root.matchDetail.isLive) ? "#4ade80" : Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
              }


            }
          }

          // Home Team (left side)
          Column {
            id: homeSideCol
            anchors.left: parent.left
            anchors.right: scoreCenterCol.left
            anchors.top: scoreCenterCol.top
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(4)

            Image {
              id: homeDetailCrestImg
              anchors.horizontalCenter: parent.horizontalCenter
              width: Style.space(50)
              height: width
              source: root.matchDetail && root.matchDetail.home ? root.matchDetail.home.logo : ""
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              visible: String(source) !== ""
              onStatusChanged: {
                if (status === Image.Ready || status === Image.Error) {
                  if (!root.matchDetailCrestsLoaded && (!awayDetailCrestImg.visible || awayDetailCrestImg.status === Image.Ready || awayDetailCrestImg.status === Image.Error)) {
                    root.matchDetailCrestsLoaded = true
                  }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.matchDetail && root.matchDetail.home ? root.matchDetail.home.name : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Repeater {
              model: (root.matchDetail && root.matchDetail.homeScorers) ? root.matchDetail.homeScorers : []
              Item {
                id: homeScorerItem
                width: parent.width
                height: Math.max(Style.space(15), homeScorerRow.implicitHeight)
                readonly property bool isRed: String(modelData).indexOf("🟥") !== -1

                Row {
                  id: homeScorerRow
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(7)
                    height: Style.space(11)
                    radius: Style.space(1.5)
                    color: "#ef4444"
                    border.width: 1
                    border.color: "#b91c1c"
                    visible: homeScorerItem.isRed
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: String(modelData).replace(/🟥\s*/g, "").trim()
                    color: Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.WordWrap
                    width: Math.max(0, homeScorerItem.width - (homeScorerItem.isRed ? Style.space(12) : 0))
                  }
                }
              }
            }
          }

          // Away Team (right side)
          Column {
            id: awaySideCol
            anchors.left: scoreCenterCol.right
            anchors.right: parent.right
            anchors.top: scoreCenterCol.top
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(4)

            Image {
              id: awayDetailCrestImg
              anchors.horizontalCenter: parent.horizontalCenter
              width: Style.space(50)
              height: width
              source: root.matchDetail && root.matchDetail.away ? root.matchDetail.away.logo : ""
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: true
              mipmap: true
              smooth: true
              visible: String(source) !== ""
              onStatusChanged: {
                if (status === Image.Ready || status === Image.Error) {
                  if (!root.matchDetailCrestsLoaded && (!homeDetailCrestImg.visible || homeDetailCrestImg.status === Image.Ready || homeDetailCrestImg.status === Image.Error)) {
                    root.matchDetailCrestsLoaded = true
                  }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.matchDetail && root.matchDetail.away ? root.matchDetail.away.name : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Repeater {
              model: (root.matchDetail && root.matchDetail.awayScorers) ? root.matchDetail.awayScorers : []
              Item {
                id: awayScorerItem
                width: parent.width
                height: Math.max(Style.space(15), awayScorerRow.implicitHeight)
                readonly property bool isRed: String(modelData).indexOf("🟥") !== -1

                Row {
                  id: awayScorerRow
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(7)
                    height: Style.space(11)
                    radius: Style.space(1.5)
                    color: "#ef4444"
                    border.width: 1
                    border.color: "#b91c1c"
                    visible: awayScorerItem.isRed
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: String(modelData).replace(/🟥\s*/g, "").trim()
                    color: Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap
                    width: Math.max(0, awayScorerItem.width - (awayScorerItem.isRed ? Style.space(12) : 0))
                  }
                }
              }
            }
          }

          // Match Result / Series Aggregate / Penalty Shootout Result (bottom center)
          Item {
            id: matchResultBottomArea
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: heroCard.matchContentBottom + Style.space(12)
            readonly property string seriesText: (root.matchDetail && (root.matchDetail.seriesResult || root.matchDetail.seriesNote)) ? (root.matchDetail.seriesResult || root.matchDetail.seriesNote) : ""
            readonly property string shootScore: (root.matchDetail && (root.matchDetail.shootoutScore !== "" || root.matchDetail.shootoutNote !== "")) ? (root.matchDetail.shootoutScore !== "" ? root.matchDetail.shootoutScore : root.matchDetail.shootoutNote) : ""
            readonly property string shootText: (root.matchDetail && root.matchDetail.shootoutText) ? root.matchDetail.shootoutText : ""
            readonly property bool hasShootout: shootScore !== "" || shootText !== ""
            readonly property bool hasSeries: seriesText !== ""
            visible: !!(root.matchDetail && (hasShootout || hasSeries))
            implicitWidth: matchResultRow.implicitWidth + Style.space(24)
            implicitHeight: matchResultRow.implicitHeight + Style.space(10)
            width: implicitWidth
            height: implicitHeight

            Rectangle {
              anchors.fill: parent
              radius: Style.space(12)
              color: root.contentForeground
              opacity: 0.08
              border.width: Style.spacing.hairline
              border.color: Util.alpha(root.contentForeground, 0.14)
            }

            Row {
              id: matchResultRow
              anchors.centerIn: parent
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: matchResultBottomArea.hasShootout ? "󰡬" : ""
                color: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : ShellColor.accent
                font.pixelSize: Style.font.caption - 1
              }

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: {
                  if (matchResultBottomArea.hasShootout && matchResultBottomArea.hasSeries) {
                    var serL = matchResultBottomArea.seriesText.toLowerCase()
                    if (serL.indexOf("penalt") !== -1 || serL.indexOf("shootout") !== -1) {
                      return matchResultBottomArea.seriesText
                    }
                    var sS = matchResultBottomArea.shootScore
                    return sS !== "" ? (matchResultBottomArea.seriesText + " (" + sS + ")") : matchResultBottomArea.seriesText
                  }
                  if (matchResultBottomArea.hasSeries) return matchResultBottomArea.seriesText
                  if (matchResultBottomArea.hasShootout) {
                    var sLabel = matchResultBottomArea.shootText !== "" ? matchResultBottomArea.shootText : "Won on Penalties"
                    var sc = matchResultBottomArea.shootScore
                    return sc !== "" ? (sLabel + " (" + sc + ")") : sLabel
                  }
                  return ""
                }
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }
        }

        // Section Tabs - Horizontally scrollable strip with mouse wheel support
        Flickable {
          id: matchDetailTabsFlickable
          width: parent.width
          height: Style.space(26)
          contentWidth: matchDetailTabsRow.implicitWidth
          contentHeight: height
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.HorizontalFlick
          interactive: true
          visible: !!root.matchDetail

          WheelHandler {
            target: matchDetailTabsFlickable
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
              if (event.angleDelta.y !== 0) {
                var delta = event.angleDelta.y
                matchDetailTabsFlickable.contentX = Math.max(0, Math.min(matchDetailTabsFlickable.contentWidth - matchDetailTabsFlickable.width, matchDetailTabsFlickable.contentX - delta))
              }
            }
          }

          Connections {
            target: root
            function onMatchDetailTabChanged() {
              Qt.callLater(function() {
                if (!matchDetailTabsFlickable || matchDetailTabsFlickable.contentWidth <= matchDetailTabsFlickable.width) return
                var targetBtn = null
                if (root.matchDetailTab === "stats") targetBtn = btnStats
                else if (root.matchDetailTab === "events") targetBtn = btnTimeline
                else if (root.matchDetailTab === "commentary") targetBtn = btnCommentary
                else if (root.matchDetailTab === "lineups") targetBtn = btnLineups
                else if (root.matchDetailTab === "h2h") targetBtn = btnH2H
                else if (root.matchDetailTab === "bracket") targetBtn = btnBracket
                else if (root.matchDetailTab === "info") targetBtn = btnInfo

                if (targetBtn && targetBtn.visible) {
                  if (targetBtn.x < matchDetailTabsFlickable.contentX) {
                    matchDetailTabsFlickable.contentX = Math.max(0, targetBtn.x - Style.space(4))
                  } else if (targetBtn.x + targetBtn.width > matchDetailTabsFlickable.contentX + matchDetailTabsFlickable.width) {
                    matchDetailTabsFlickable.contentX = Math.min(
                      matchDetailTabsFlickable.contentWidth - matchDetailTabsFlickable.width,
                      targetBtn.x + targetBtn.width - matchDetailTabsFlickable.width + Style.space(4)
                    )
                  }
                }
              })
            }
          }

          Row {
            id: matchDetailTabsRow
            spacing: Style.space(5)
            height: parent.height

            Button {
              id: btnStats
              height: Style.space(24)
              text: "Stats"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(8)
              verticalPadding: 0
              visible: !!(root.matchDetail && root.matchDetail.started)
              selected: root.matchDetailTab === "stats"
              onClicked: root.matchDetailTab = "stats"
            }

            Button {
              id: btnTimeline
              height: Style.space(24)
              text: "Timeline"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(8)
              verticalPadding: 0
              visible: !!(root.matchDetail && root.matchDetail.started && !root.matchDetail.isLive)
              selected: root.matchDetailTab === "events"
              onClicked: root.matchDetailTab = "events"
            }

            Button {
              id: btnCommentary
              height: Style.space(24)
              text: "Commentary"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(8)
              verticalPadding: 0
              visible: !!(root.matchDetail && root.matchDetail.isLive && root.matchDetail.commentary && root.matchDetail.commentary.length > 0)
              selected: root.matchDetailTab === "commentary"
              onClicked: root.matchDetailTab = "commentary"
            }

            Button {
              id: btnLineups
              height: Style.space(24)
              text: "Lineups"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(8)
              verticalPadding: 0
              visible: !!root.matchDetail
              selected: root.matchDetailTab === "lineups"
              onClicked: root.matchDetailTab = "lineups"
            }

            Button {
              id: btnH2H
              height: Style.space(24)
              text: "H2H & Form"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(8)
              verticalPadding: 0
              visible: !!(root.matchDetail && ((root.matchDetail.h2h && root.matchDetail.h2h.length > 0) || (root.matchDetail.homeForm && root.matchDetail.homeForm.length > 0) || (root.matchDetail.awayForm && root.matchDetail.awayForm.length > 0)))
              selected: root.matchDetailTab === "h2h"
              onClicked: root.matchDetailTab = "h2h"
            }

            Button {
              id: btnBracket
              height: Style.space(24)
              text: "Bracket"
              fontFamily: root ? root.contentFontFamily : Style.font.family
              foreground: root ? root.contentForeground : ShellColor.foreground
              accent: root ? root.contentForeground : ShellColor.foreground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(8)
              verticalPadding: 0
              visible: !!(root.matchDetail && root.matchDetail.bracketAvailable)
              selected: root.matchDetailTab === "bracket"
              onClicked: root.matchDetailTab = "bracket"
            }

            Button {
              id: btnInfo
              height: Style.space(24)
              text: "Info"
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(8)
              verticalPadding: 0
              selected: root.matchDetailTab === "info"
              onClicked: root.matchDetailTab = "info"
            }
          }
        }

        // Loading & Error states
        Text {
          textFormat: Text.PlainText
          width: parent.width
          opacity: root.matchDetailLoading ? 0.4 + 0.6 * root._pulse : 1.0
          text: root.matchDetailLoading ? "Fetching match details…" : (root.matchDetailError !== "" ? root.matchDetailError : "")
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          visible: text !== ""
        }

        // Stats Tab
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.matchDetail && root.matchDetail.started && root.matchDetailTab === "stats"

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "No boxscore stats recorded for this match"
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            visible: !root.matchDetail || !root.matchDetail.stats || root.matchDetail.stats.length === 0
          }

          Repeater {
            model: matchDetailView.visibleStats

            delegate: Column {
              id: statRowItem
              required property var modelData
              width: parent ? parent.width : 0
              spacing: Style.space(2)

              Row {
                width: parent.width

                Text {
                  textFormat: Text.PlainText
                  width: Style.space(50)
                  text: statRowItem.modelData.homeValue
                  color: statRowItem.modelData.homeRatio > 0.5 ? root.statsHomeColor : (statRowItem.modelData.homeRatio < 0.5 ? Qt.darker(root.contentForeground, 1.4) : root.contentForeground)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: statRowItem.modelData.homeRatio > 0.5
                  horizontalAlignment: Text.AlignLeft
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width - Style.space(100)
                  text: statRowItem.modelData.label
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  horizontalAlignment: Text.AlignHCenter
                }

                Text {
                  textFormat: Text.PlainText
                  width: Style.space(50)
                  text: statRowItem.modelData.awayValue
                  color: statRowItem.modelData.homeRatio < 0.5 ? root.statsAwayColor : (statRowItem.modelData.homeRatio > 0.5 ? Qt.darker(root.contentForeground, 1.4) : root.contentForeground)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: statRowItem.modelData.homeRatio < 0.5
                  horizontalAlignment: Text.AlignRight
                }
              }

              // Ultra-thin high-contrast comparative visual line (1.5px)
              Item {
                width: parent.width
                height: 1.5

                // Background track
                Rectangle {
                  anchors.fill: parent
                  radius: 0.75
                  color: root.contentForeground
                  opacity: 0.1
                }

                // Home Bar (Left, Sky Cyan)
                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: Math.max(0, (parent.width - 2) * statRowItem.modelData.homeRatio)
                  radius: 0.75
                  color: root.statsHomeColor
                  visible: width > 0
                }

                // Away Bar (Right, Coral Rose)
                Rectangle {
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: Math.max(0, (parent.width - 2) * (1.0 - statRowItem.modelData.homeRatio))
                  radius: 0.75
                  color: root.statsAwayColor
                  visible: width > 0
                }
              }
            }
          }

          // Expand / Collapse all stats toggle button
          Item {
            id: expandStatsBtn
            width: parent.width
            height: Style.space(24)
            visible: !!(root.matchDetail && root.matchDetail.stats && (root.matchDetail.stats.length > matchDetailView.visibleStats.length || matchDetailView.expandAllStats))

            Rectangle {
              anchors.fill: parent
              radius: Style.space(4)
              color: root ? root.contentForeground : ShellColor.foreground
              opacity: expandStatsMouseArea.containsMouse ? 0.08 : 0.03
              Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            MouseArea {
              id: expandStatsMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: matchDetailView.expandAllStats = !matchDetailView.expandAllStats
            }

            Row {
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: matchDetailView.expandAllStats
                  ? "Show less stats"
                  : "Show all stats"
                color: root ? root.contentForeground : ShellColor.foreground
                font.family: root ? root.contentFontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: matchDetailView.expandAllStats ? "󰅃" : "󰅂"
                color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.5)
                font.family: root ? root.contentFontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }

          // Match Leaders Section
          Rectangle {
            width: parent.width
            height: leadersCol.implicitHeight + Style.space(20)
            radius: Style.space(8)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
            border.width: 1
            visible: !!(root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders.length > 0)

            Column {
              id: leadersCol
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: "MATCH LEADERS"
                color: Qt.darker(root.contentForeground, 1.6)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption - 1
                font.letterSpacing: 1
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                // Home Leaders
                Column {
                  width: (parent.width - parent.spacing) / 2
                  spacing: Style.space(6)
                  visible: !!(root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders.length > 0)

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders[0] ? root.matchDetail.leaders[0].teamName : "Home"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Repeater {
                    model: (root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders[0]) ? root.matchDetail.leaders[0].categories : []
                    delegate: Column {
                      id: hLeadRow
                      required property var modelData
                      width: parent ? parent.width : 0
                      spacing: Style.space(1)

                      Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        text: hLeadRow.modelData.category
                        color: Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                      }

                      Row {
                        width: parent.width
                        spacing: Style.space(4)

                        Text {
                          textFormat: Text.PlainText
                          width: Math.max(0, parent.width - hLeadVal.implicitWidth - parent.spacing)
                          text: hLeadRow.modelData.player
                          color: Qt.darker(root.contentForeground, 1.15)
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                          elide: Text.ElideRight
                        }

                        Text {
                          id: hLeadVal
                          textFormat: Text.PlainText
                          text: hLeadRow.modelData.value
                          color: root.statsHomeColor
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                        }
                      }
                    }
                  }
                }

                // Away Leaders
                Column {
                  width: (parent.width - parent.spacing) / 2
                  spacing: Style.space(6)
                  visible: !!(root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders.length > 1)

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders[1] ? root.matchDetail.leaders[1].teamName : "Away"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Repeater {
                    model: (root.matchDetail && root.matchDetail.leaders && root.matchDetail.leaders[1]) ? root.matchDetail.leaders[1].categories : []
                    delegate: Column {
                      id: aLeadRow
                      required property var modelData
                      width: parent ? parent.width : 0
                      spacing: Style.space(1)

                      Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        text: aLeadRow.modelData.category
                        color: Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                      }

                      Row {
                        width: parent.width
                        spacing: Style.space(4)

                        Text {
                          textFormat: Text.PlainText
                          width: Math.max(0, parent.width - aLeadVal.implicitWidth - parent.spacing)
                          text: aLeadRow.modelData.player
                          color: Qt.darker(root.contentForeground, 1.15)
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                          elide: Text.ElideRight
                        }

                        Text {
                          id: aLeadVal
                          textFormat: Text.PlainText
                          text: aLeadRow.modelData.value
                          color: root.statsAwayColor
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // Live Attack Momentum Graph Card
          Rectangle {
            id: momentumCard
            width: parent.width
            height: momentumCol.implicitHeight + Style.space(20)
            radius: Style.space(8)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
            border.width: 1
            visible: !!(root.matchDetail && root.matchDetail.momentum && root.matchDetail.momentum.length > 0)

            Column {
              id: momentumCol
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              // Header
              Row {
                width: parent.width
                Text {
                  textFormat: Text.PlainText
                  text: "ATTACK MOMENTUM"
                  color: Qt.darker(root.contentForeground, 1.6)
                  font.family: root ? root.contentFontFamily : Style.font.family
                  font.pixelSize: Style.font.caption - 1
                  font.letterSpacing: 1
                  font.bold: true
                }
                Item {
                  width: Math.max(0, parent.width - Style.space(130) - legendRow.implicitWidth)
                  height: 1
                }
                Row {
                  id: legendRow
                  spacing: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  Row {
                    spacing: Style.space(4)
                    Rectangle {
                      width: 8
                      height: 8
                      radius: 2
                      color: root.statsHomeColor
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      textFormat: Text.PlainText
                      text: (root.matchDetail && root.matchDetail.home) ? root.matchDetail.home.name : "Home"
                      color: Qt.darker(root.contentForeground, 1.4)
                      font.family: root ? root.contentFontFamily : Style.font.family
                      font.pixelSize: Style.space(8.5)
                      font.bold: true
                    }
                  }
                  Row {
                    spacing: Style.space(4)
                    Rectangle {
                      width: 8
                      height: 8
                      radius: 2
                      color: root.statsAwayColor
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      textFormat: Text.PlainText
                      text: (root.matchDetail && root.matchDetail.away) ? root.matchDetail.away.name : "Away"
                      color: Qt.darker(root.contentForeground, 1.4)
                      font.family: root ? root.contentFontFamily : Style.font.family
                      font.pixelSize: Style.space(8.5)
                      font.bold: true
                    }
                  }
                }
              }

              // Momentum Chart Container
              Item {
                id: momentumChartArea
                width: parent.width
                height: Style.space(84)

                // Background grid & center zero line
                Rectangle {
                  id: zeroBaseline
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  height: 1
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.2)
                }

                // Half-Time 45' vertical guideline
                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: 1
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.space(1)
                  textFormat: Text.PlainText
                  text: "HT 45'"
                  color: Qt.darker(root.contentForeground, 2.0)
                  font.family: root ? root.contentFontFamily : Style.font.family
                  font.pixelSize: Style.space(7.5)
                  font.bold: true
                }

                // Minute Bars
                Row {
                  id: barsRow
                  anchors.fill: parent
                  spacing: 1

                  Repeater {
                    model: (root.matchDetail && root.matchDetail.momentum) ? root.matchDetail.momentum : []
                    delegate: Item {
                      id: barItem
                      required property var modelData
                      required property int index
                      width: Math.max(1, (barsRow.width - (barsRow.spacing * (barsRow.children.length - 1))) / Math.max(1, (root.matchDetail && root.matchDetail.momentum ? root.matchDetail.momentum.length : 90)))
                      height: parent.height

                      readonly property real normVal: Math.max(-1.0, Math.min(1.0, Number(modelData.value || 0) / 100.0))
                      readonly property bool isHome: normVal >= 0

                      Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: barItem.isHome ? zeroBaseline.top : undefined
                        anchors.top: barItem.isHome ? undefined : zeroBaseline.bottom
                        width: Math.max(1.5, parent.width)
                        height: Math.max(2, Math.abs(barItem.normVal) * (parent.height / 2 - Style.space(6)))
                        radius: 1
                        color: barItem.isHome ? root.statsHomeColor : root.statsAwayColor
                        opacity: mBarMouse.containsMouse ? 1.0 : 0.82
                      }

                      MouseArea {
                        id: mBarMouse
                        anchors.fill: parent
                        hoverEnabled: true
                      }

                      PanelToolTip {
                        visible: mBarMouse.containsMouse
                        text: {
                          var m = barItem.modelData.minute !== undefined ? (barItem.modelData.minute + "'") : ""
                          var team = barItem.isHome
                            ? ((root.matchDetail && root.matchDetail.home) ? root.matchDetail.home.name : "Home")
                            : ((root.matchDetail && root.matchDetail.away) ? root.matchDetail.away.name : "Away")
                          var valStr = Math.abs(Math.round(barItem.modelData.value || 0))
                          return (m !== "" ? (m + " · ") : "") + team + " Attack +" + valStr
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Timeline Tab
        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.matchDetail && root.matchDetail.started && !root.matchDetail.isLive && root.matchDetailTab === "events"

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "No key events available for this match"
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            visible: !root.matchDetail || !root.matchDetail.events || root.matchDetail.events.length === 0
          }

          Flickable {
            id: timelineFlickable
            width: parent.width
            height: Math.min(timelineCol.implicitHeight, Style.space(250))
            contentHeight: timelineCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: root.matchDetail && root.matchDetail.events && root.matchDetail.events.length > 0

            Column {
              id: timelineCol
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.matchDetail ? (root.matchDetail.events || []) : []

                delegate: Item {
                  id: eventRow
                  required property var modelData
                  width: parent ? parent.width : 0
                  height: Math.max(Style.space(28), eventTextCol.implicitHeight + Style.space(6))

                  Rectangle {
                    anchors.fill: parent
                    radius: Style.space(4)
                    color: root.contentForeground
                    opacity: eventRow.modelData.isGoal ? 0.06 : 0.02
                  }

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(4)
                    spacing: Style.space(8)

                    // Minute Pill Box
                    Rectangle {
                      width: Style.space(34)
                      height: Style.space(18)
                      radius: Style.space(3)
                      color: eventRow.modelData.minute !== ""
                        ? (eventRow.modelData.isGoal
                            ? Qt.rgba(root.favoriteTeamAccent.r, root.favoriteTeamAccent.g, root.favoriteTeamAccent.b, 0.18)
                            : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08))
                        : "transparent"
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: eventRow.modelData.minute !== "" ? eventRow.modelData.minute : "—"
                        color: eventRow.modelData.isGoal ? root.favoriteTeamAccent : root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.NoWrap
                      }
                    }

                    // Icon / Badge
                    Item {
                      width: Style.space(18)
                      height: parent.height

                      Rectangle {
                        anchors.centerIn: parent
                        width: Style.space(9)
                        height: Style.space(13)
                        radius: Style.space(2)
                        color: eventRow.modelData.cardColor || "transparent"
                        border.color: eventRow.modelData.cardColor ? (eventRow.modelData.cardColor === "#eab308" ? "#fde047" : "#fca5a5") : "transparent"
                        border.width: 1
                        visible: eventRow.modelData.isCard
                      }

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: eventRow.modelData.glyph
                        color: eventRow.modelData.isGoal ? root.favoriteTeamAccent : root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                        visible: !eventRow.modelData.isCard
                      }
                    }

                    // Description
                    Column {
                      id: eventTextCol
                      width: parent.width - Style.space(34 + 18 + 16)
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        text: eventRow.modelData.text
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                      }
                    }
                  }
                }
              }
            }
          }

          // Penalty Shootout Sequence Tracker
          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: !!(root.matchDetail && root.matchDetail.shootoutKicks && root.matchDetail.shootoutKicks.length > 0)

            Row {
              width: parent.width
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                text: "PENALTY SHOOTOUT"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.bold: true
              }

              Text {
                textFormat: Text.PlainText
                text: "(" + (root.matchDetail ? (root.matchDetail.shootoutScore || root.matchDetail.shootoutNote) : "") + ")"
                color: root.favoriteTeamAccent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                visible: text !== "()"
              }
            }

            Rectangle {
              width: parent.width
              implicitHeight: shootoutListCol.implicitHeight + Style.space(12)
              radius: Style.space(6)
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
              border.width: Style.spacing.hairline
              border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)

              Column {
                id: shootoutListCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Style.space(6)
                spacing: Style.space(4)

                Repeater {
                  model: root.matchDetail ? root.matchDetail.shootoutKicks : []
                  delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: parent ? parent.width : 0
                    height: Style.space(26)
                    radius: Style.space(4)
                    color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.02)

                    Row {
                      anchors.fill: parent
                      anchors.margins: Style.space(4)
                      spacing: Style.space(6)

                      Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(22)
                        text: "#" + (index + 1)
                        color: Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        horizontalAlignment: Text.AlignRight
                      }

                      Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.scored ? "●" : "○"
                        color: modelData.scored ? root.favoriteTeamAccent : Qt.rgba(0.9, 0.3, 0.3, 0.85)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption + 1
                      }

                      Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.scored ? "GOAL" : "MISSED"
                        color: modelData.scored ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 3
                        font.bold: true
                      }

                      Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.athlete || "Penalty"
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }

                      Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.team ? ("· " + modelData.team) : ""
                        color: Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 1
                        visible: text !== ""
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Commentary Tab
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.matchDetail && root.matchDetail.isLive && root.matchDetailTab === "commentary"

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "No live commentary available for this match"
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            visible: !root.matchDetail || !root.matchDetail.commentary || root.matchDetail.commentary.length === 0
          }

          Row {
            width: parent.width
            spacing: Style.space(6)
            visible: root.matchDetail && root.matchDetail.commentary && root.matchDetail.commentary.length > 0

            Repeater {
              model: [
                { id: "all", label: "All" },
                { id: "goals_cards", label: "Goals & Cards" },
                { id: "shots", label: "Shots" },
                { id: "subs", label: "Subs" }
              ]

              Button {
                required property var modelData
                height: Style.space(20)
                text: modelData.label
                fontFamily: root.contentFontFamily
                foreground: root.contentForeground
                accent: root.contentForeground
                fontSize: Style.font.caption - 2
                horizontalPadding: Style.space(8)
                verticalPadding: 0
                selected: matchDetailView.commentaryFilter === modelData.id
                onClicked: matchDetailView.commentaryFilter = modelData.id
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "No commentary events match the selected filter"
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            visible: root.matchDetail && root.matchDetail.commentary && root.matchDetail.commentary.length > 0 && matchDetailView.filteredCommentary().length === 0
          }

          Flickable {
            id: commFlickable
            width: parent.width
            height: Math.min(commCol.implicitHeight, Style.space(320))
            contentHeight: commCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: root.matchDetail && root.matchDetail.commentary && root.matchDetail.commentary.length > 0 && matchDetailView.filteredCommentary().length > 0

            Column {
              id: commCol
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: matchDetailView.filteredCommentary()

                delegate: Rectangle {
                  id: commItem
                  required property var modelData
                  width: parent ? parent.width : 0
                  height: commTextCol.implicitHeight + Style.space(12)
                  radius: Style.space(6)
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)

                  Row {
                    id: commTextCol
                    anchors.fill: parent
                    anchors.margins: Style.space(6)
                    spacing: Style.space(8)

                    Rectangle {
                      width: Style.space(34)
                      height: Style.space(18)
                      radius: Style.space(3)
                      color: commItem.modelData.time !== "" ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"
                      anchors.top: parent.top

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: commItem.modelData.time
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                        visible: text !== ""
                      }
                    }

                    Text {
                      textFormat: Text.PlainText
                      width: parent.width - Style.space(42)
                      anchors.top: parent.top
                      text: commItem.modelData.text
                      color: Qt.darker(root.contentForeground, 1.2)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption - 1
                      wrapMode: Text.WordWrap
                    }
                  }
                }
              }
            }
          }
        }

        // Lineups Tab
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.matchDetail && root.matchDetailTab === "lineups"

          // Team Selector Bar (Home Team vs Away Team)
          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - parent.spacing) / 2
              height: Style.space(28)
              text: {
                var name = root.matchDetail && root.matchDetail.home ? root.matchDetail.home.name : "Home"
                var form = root.matchDetail && root.matchDetail.lineups && root.matchDetail.lineups.homeFormation ? (" (" + root.matchDetail.lineups.homeFormation + ")") : ""
                return name + form
              }
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.statsHomeColor
              fontSize: Style.font.caption
              horizontalPadding: Style.space(6)
              verticalPadding: 0
              selected: root.matchDetailLineupTeam === "home"
              onClicked: root.matchDetailLineupTeam = "home"
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              height: Style.space(28)
              text: {
                var name = root.matchDetail && root.matchDetail.away ? root.matchDetail.away.name : "Away"
                var form = root.matchDetail && root.matchDetail.lineups && root.matchDetail.lineups.awayFormation ? (" (" + root.matchDetail.lineups.awayFormation + ")") : ""
                return name + form
              }
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.statsAwayColor
              fontSize: Style.font.caption
              horizontalPadding: Style.space(6)
              verticalPadding: 0
              selected: root.matchDetailLineupTeam === "away"
              onClicked: root.matchDetailLineupTeam = "away"
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "Lineups not yet announced for this match"
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            visible: !!(!root.matchDetail || !root.matchDetail.lineups || !root.matchDetail.lineups.available)
          }

          Column {
            id: lineupCol
            width: parent.width
            spacing: Style.space(8)
            visible: !!(root.matchDetail && root.matchDetail.lineups && root.matchDetail.lineups.available)

            // Tactical Pitch View
            Rectangle {
              id: pitchField
              width: parent.width
              height: Style.space(490)
              radius: Style.space(8)
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.025)
              clip: true
              border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
              border.width: 1

              // Subtle transparent zone stripes (6 alternating stripes)
              Column {
                anchors.fill: parent
                Repeater {
                  model: 6
                  Rectangle {
                    width: pitchField.width
                    height: pitchField.height / 6
                    color: index % 2 === 0 ? "transparent" : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.018)
                  }
                }
              }

              // Halfway line through the middle
              Rectangle {
                width: parent.width
                height: 1
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.15)
              }

              // Center circle
              Rectangle {
                width: Style.space(84)
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.15)
                border.width: 1
              }

              // Center spot
              Rectangle {
                width: 4
                height: 4
                radius: 2
                anchors.centerIn: parent
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.25)
              }

              // Corner arcs
              Rectangle {
                width: Style.space(18)
                height: width
                radius: width
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: -width / 2
                anchors.leftMargin: -width / 2
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                border.width: 1
              }
              Rectangle {
                width: Style.space(18)
                height: width
                radius: width
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -width / 2
                anchors.rightMargin: -width / 2
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                border.width: 1
              }
              Rectangle {
                width: Style.space(18)
                height: width
                radius: width
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.bottomMargin: -width / 2
                anchors.leftMargin: -width / 2
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                border.width: 1
              }
              Rectangle {
                width: Style.space(18)
                height: width
                radius: width
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.bottomMargin: -width / 2
                anchors.rightMargin: -width / 2
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                border.width: 1
              }

              // Bottom penalty box
              Rectangle {
                width: Style.space(170)
                height: Style.space(70)
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                border.width: 1
              }

              // Bottom goal area
              Rectangle {
                width: Style.space(80)
                height: Style.space(26)
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                border.width: 1
              }

              // Bottom penalty spot
              Rectangle {
                width: 4
                height: 4
                radius: 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(48)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.22)
              }

              // Bottom penalty arc
              Rectangle {
                width: Style.space(46)
                height: width
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(46)
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                border.width: 1
              }

              // Top penalty box
              Rectangle {
                width: Style.space(170)
                height: Style.space(70)
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                border.width: 1
              }

              // Top goal area
              Rectangle {
                width: Style.space(80)
                height: Style.space(26)
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                border.width: 1
              }

              // Top penalty spot
              Rectangle {
                width: 4
                height: 4
                radius: 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Style.space(48)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.22)
              }

              // Top penalty arc
              Rectangle {
                width: Style.space(46)
                height: width
                radius: width / 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Style.space(46)
                color: "transparent"
                border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
                border.width: 1
              }

              // Circular Player Nodes
              Repeater {
                model: (root.matchDetail && root.matchDetail.lineups) ? root.layoutPitchPlayers(
                  root.matchDetailLineupTeam === "home" ? root.matchDetail.lineups.homeFormation : root.matchDetail.lineups.awayFormation,
                  root.matchDetailLineupTeam === "home" ? root.matchDetail.lineups.homeStarters : root.matchDetail.lineups.awayStarters
                ) : []

                delegate: Item {
                  id: pitchPlayerItem
                  required property var modelData
                  width: Style.space(64)
                  height: Style.space(56)
                  z: (pitchPlayerItem.modelData.goals > 0 || pitchPlayerItem.modelData.assists > 0 ? 30 : 10) + Math.round((1.0 - pitchPlayerItem.modelData.y) * 20)
                  x: (pitchField.width * pitchPlayerItem.modelData.x) - (width / 2)
                  y: (pitchField.height * pitchPlayerItem.modelData.y) - (jerseyContainer.height / 2)

                  // Main full-resolution athlete jersey image
                  Item {
                    id: jerseyContainer
                    width: Style.space(32)
                    height: Style.space(32)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Image {
                      id: playerJerseyImg
                      anchors.fill: parent
                      source: pitchPlayerItem.modelData.jerseyImage !== "" ? pitchPlayerItem.modelData.jerseyImage : ""
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true
                      cache: true
                      sourceSize.width: Style.space(64)
                      sourceSize.height: Style.space(64)
                      mipmap: true
                      smooth: true
                      visible: status === Image.Ready
                    }

                    // Fallback: when jersey image is not loaded or missing
                    Rectangle {
                      anchors.centerIn: parent
                      width: Style.space(24)
                      height: Style.space(24)
                      radius: Style.space(5)
                      color: root.matchDetailLineupTeam === "home" ? root.statsHomeColor : root.statsAwayColor
                      border.color: Qt.lighter(root.matchDetailLineupTeam === "home" ? root.statsHomeColor : root.statsAwayColor, 1.4)
                      border.width: 1
                      visible: playerJerseyImg.status !== Image.Ready

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: pitchPlayerItem.modelData.jersey !== "" ? pitchPlayerItem.modelData.jersey : "—"
                        color: "#ffffff"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }
                  }

                  // 1. Goals (Top-Right of Jersey - Overlapping Badges, White Icon)
                  Row {
                    id: goalOverlapRow
                    anchors.top: jerseyContainer.top
                    anchors.right: jerseyContainer.right
                    anchors.topMargin: -Style.space(3)
                    anchors.rightMargin: -Style.space(4)
                    spacing: -Style.space(4)
                    z: 20
                    visible: !!(pitchPlayerItem.modelData.goals && pitchPlayerItem.modelData.goals > 0)

                    Repeater {
                      model: Math.min(5, pitchPlayerItem.modelData.goals || 0)
                      Rectangle {
                        width: Style.space(13)
                        height: Style.space(13)
                        radius: width / 2
                        color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
                        border.color: Qt.rgba(1, 1, 1, 0.3)
                        border.width: 0.7
                        z: 20 - index

                        Text {
                          textFormat: Text.PlainText
                          anchors.centerIn: parent
                          text: ""
                          color: "#ffffff"
                          font.family: "Symbols Nerd Font, " + root.contentFontFamily
                          font.pixelSize: Style.font.caption - 3
                          font.bold: true
                        }
                      }
                    }
                  }

                  // 2. Assists (Top-Left of Jersey - Overlapping Boot Badges, White Icon)
                  Row {
                    id: assistOverlapRow
                    anchors.top: jerseyContainer.top
                    anchors.left: jerseyContainer.left
                    anchors.topMargin: -Style.space(3)
                    anchors.leftMargin: -Style.space(4)
                    spacing: -Style.space(4)
                    z: 20
                    visible: !!(pitchPlayerItem.modelData.assists && pitchPlayerItem.modelData.assists > 0)

                    Repeater {
                      model: Math.min(5, pitchPlayerItem.modelData.assists || 0)
                      Rectangle {
                        width: Style.space(13)
                        height: Style.space(13)
                        radius: width / 2
                        color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
                        border.color: Qt.rgba(1, 1, 1, 0.3)
                        border.width: 0.7
                        z: 20 - index

                        Text {
                          textFormat: Text.PlainText
                          anchors.centerIn: parent
                          text: "󱗇"
                          rotation: 45
                          transformOrigin: Item.Center
                          color: "#ffffff"
                          font.family: "Symbols Nerd Font, " + root.contentFontFamily
                          font.pixelSize: Style.font.caption - 3
                          font.bold: true
                        }
                      }
                    }
                  }

                  // 3. Substitution Badge (Bottom-Right - Sub minute & in/out indicators)
                  Rectangle {
                    id: subBadge
                    width: (pitchPlayerItem.modelData.subMinute && pitchPlayerItem.modelData.subMinute !== "")
                      ? subMinuteText.implicitWidth + Style.space(12)
                      : Style.space(13)
                    height: Style.space(13)
                    radius: height / 2
                    anchors.bottom: jerseyContainer.bottom
                    anchors.right: jerseyContainer.right
                    anchors.bottomMargin: -Style.space(2)
                    anchors.rightMargin: -Style.space(3)
                    color: pitchPlayerItem.modelData.subbedIn ? "#14532d" : Qt.rgba(0.08, 0.08, 0.08, 0.95)
                    border.color: pitchPlayerItem.modelData.subbedIn ? "#22c55e" : (pitchPlayerItem.modelData.subbedOut ? "#ef4444" : Qt.rgba(1, 1, 1, 0.3))
                    border.width: 0.8
                    z: 20
                    visible: !!(pitchPlayerItem.modelData.subbedOut || pitchPlayerItem.modelData.subbedIn)

                    Row {
                      anchors.centerIn: parent
                      spacing: Style.space(2)
                      Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        text: pitchPlayerItem.modelData.subbedIn ? "▲" : "▼"
                        color: pitchPlayerItem.modelData.subbedIn ? "#4ade80" : "#ef4444"
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                      }
                      Text {
                        id: subMinuteText
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!(pitchPlayerItem.modelData.subMinute && pitchPlayerItem.modelData.subMinute !== "")
                        text: pitchPlayerItem.modelData.subMinute || ""
                        color: "#ffffff"
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.space(8)
                        font.bold: true
                      }
                    }

                    MouseArea {
                      id: subBadgeMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                    }

                    PanelToolTip {
                      visible: subBadgeMouse.containsMouse
                      text: {
                        if (pitchPlayerItem.modelData.subDesc && pitchPlayerItem.modelData.subDesc !== "") {
                          return pitchPlayerItem.modelData.subDesc
                        }
                        if (pitchPlayerItem.modelData.subPartner && pitchPlayerItem.modelData.subPartner !== "") {
                          return (pitchPlayerItem.modelData.subbedIn ? "Replaced " : "Replaced by ") + pitchPlayerItem.modelData.subPartner + (pitchPlayerItem.modelData.subMinute ? (" (" + pitchPlayerItem.modelData.subMinute + ")") : "")
                        }
                        return pitchPlayerItem.modelData.subbedIn ? "Subbed on" : "Subbed off"
                      }
                    }
                  }

                  // 4. Card Badge (Bottom-Left - Yellow / Red Card)
                  Rectangle {
                    id: cardBadge
                    width: Style.space(7)
                    height: Style.space(10)
                    radius: 1
                    anchors.bottom: jerseyContainer.bottom
                    anchors.left: jerseyContainer.left
                    anchors.bottomMargin: -Style.space(1)
                    anchors.leftMargin: -Style.space(3)
                    color: (pitchPlayerItem.modelData.redCards && pitchPlayerItem.modelData.redCards > 0) ? "#ef4444" : "#eab308"
                    border.color: "#ffffff"
                    border.width: 0.8
                    z: 20
                    visible: !!((pitchPlayerItem.modelData.redCards && pitchPlayerItem.modelData.redCards > 0) || (pitchPlayerItem.modelData.yellowCards && pitchPlayerItem.modelData.yellowCards > 0))
                  }

                  // 5. Rating Badge (Centre Bottom)
                  Rectangle {
                    id: ratingBadge
                    height: Style.space(13)
                    width: ratingText.implicitWidth + Style.space(6)
                    radius: Style.space(3)
                    anchors.top: jerseyContainer.bottom
                    anchors.topMargin: -Style.space(3)
                    anchors.horizontalCenter: jerseyContainer.horizontalCenter
                    color: root.ratingColor(pitchPlayerItem.modelData.rating)
                    border.color: "#ffffff"
                    border.width: 0.8
                    z: 20
                    visible: !!(pitchPlayerItem.modelData.rating !== null && pitchPlayerItem.modelData.rating !== undefined)

                    Text {
                      id: ratingText
                      textFormat: Text.PlainText
                      anchors.centerIn: parent
                      text: pitchPlayerItem.modelData.rating ? Number(pitchPlayerItem.modelData.rating).toFixed(1) : ""
                      color: "#ffffff"
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption - 3
                      font.bold: true
                    }
                  }

                  // Sleek dark pill for player name
                  Rectangle {
                    anchors.top: ratingBadge.visible ? ratingBadge.bottom : jerseyContainer.bottom
                    anchors.topMargin: Style.space(2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, Math.max(Style.space(32), pitchNameText.implicitWidth + Style.space(8)))
                    height: Style.space(14)
                    radius: Style.space(3)
                    color: Qt.rgba(0, 0, 0, 0.78)
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                    border.width: 0.5
                    clip: true

                    Text {
                      id: pitchNameText
                      textFormat: Text.PlainText
                      anchors.centerIn: parent
                      width: parent.width - Style.space(6)
                      text: pitchPlayerItem.modelData.shortName !== "" ? pitchPlayerItem.modelData.shortName : pitchPlayerItem.modelData.name
                      color: "#ffffff"
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption - 2
                      font.bold: true
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                    }
                  }
                }
              }
            }

              // Starting XI Section List
              Text {
                textFormat: Text.PlainText
                text: "STARTING XI (" + (root.matchDetail && root.matchDetail.lineups ? (root.matchDetailLineupTeam === "home" ? (root.matchDetail.lineups.homeStarters || []).length : (root.matchDetail.lineups.awayStarters || []).length) : 0) + ")"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.bold: true
              }

              Repeater {
                model: root.matchDetail && root.matchDetail.lineups ? (root.matchDetailLineupTeam === "home" ? root.matchDetail.lineups.homeStarters : root.matchDetail.lineups.awayStarters) : []

                delegate: Item {
                  id: starterRow
                  required property var modelData
                  width: parent ? parent.width : 0
                  height: Style.space(26)

                  Rectangle {
                    anchors.fill: parent
                    radius: Style.space(4)
                    color: root.contentForeground
                    opacity: 0.02
                  }

                  Row {
                    id: starterRowContent
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(6)
                    anchors.rightMargin: Style.space(6)
                    spacing: Style.space(6)

                    // Player Jersey Image
                    Item {
                      id: starterJerseyBox
                      width: Style.space(24)
                      height: Style.space(24)
                      anchors.verticalCenter: parent.verticalCenter

                      Image {
                        id: starterJerseyImg
                        anchors.fill: parent
                        source: starterRow.modelData.jerseyImage !== "" ? starterRow.modelData.jerseyImage : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        sourceSize.width: Style.space(48)
                        sourceSize.height: Style.space(48)
                        mipmap: true
                        smooth: true
                        visible: status === Image.Ready
                      }

                      Rectangle {
                        anchors.centerIn: parent
                        width: Style.space(20)
                        height: Style.space(20)
                        radius: Style.space(3)
                        color: root.contentForeground
                        opacity: 0.08
                        visible: starterJerseyImg.status !== Image.Ready

                        Text {
                          textFormat: Text.PlainText
                          anchors.centerIn: parent
                          text: starterRow.modelData.jersey !== "" ? starterRow.modelData.jersey : "—"
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                        }
                      }
                    }

                    // Rating Pill (if available)
                    Rectangle {
                      width: starterRatingTxt.implicitWidth + Style.space(6)
                      height: Style.space(16)
                      anchors.verticalCenter: parent.verticalCenter
                      radius: Style.space(3)
                      color: root.ratingColor(starterRow.modelData.rating)
                      visible: !!(starterRow.modelData.rating !== null && starterRow.modelData.rating !== undefined)

                      Text {
                        id: starterRatingTxt
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: starterRow.modelData.rating ? Number(starterRow.modelData.rating).toFixed(1) : ""
                        color: "#ffffff"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                      }
                    }

                    // Player Name
                    Text {
                      textFormat: Text.PlainText
                      width: Math.max(0, parent.width - starterJerseyBox.width - (starterRow.modelData.rating ? (starterRatingTxt.implicitWidth + Style.space(12)) : 0) - starterPosText.implicitWidth - parent.spacing * 3)
                      anchors.verticalCenter: parent.verticalCenter
                      text: starterRow.modelData.name
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      elide: Text.ElideRight
                    }

                    // Position
                    Text {
                      id: starterPosText
                      textFormat: Text.PlainText
                      anchors.verticalCenter: parent.verticalCenter
                      text: starterRow.modelData.position
                      color: Qt.darker(root.contentForeground, 1.4)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                    }
                  }
                }
              }

              // Substitutes Section
              Item { width: 1; height: Style.space(4) }

              Text {
                textFormat: Text.PlainText
                text: "SUBSTITUTES (" + (root.matchDetail && root.matchDetail.lineups ? (root.matchDetailLineupTeam === "home" ? (root.matchDetail.lineups.homeSubs || []).length : (root.matchDetail.lineups.awaySubs || []).length) : 0) + ")"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.bold: true
                visible: !!(root.matchDetail && root.matchDetail.lineups && ((root.matchDetailLineupTeam === "home" ? (root.matchDetail.lineups.homeSubs || []).length : (root.matchDetail.lineups.awaySubs || []).length) > 0))
              }

              Repeater {
                model: root.matchDetail && root.matchDetail.lineups ? (root.matchDetailLineupTeam === "home" ? root.matchDetail.lineups.homeSubs : root.matchDetail.lineups.awaySubs) : []

                delegate: Item {
                  id: subRow
                  required property var modelData
                  width: parent ? parent.width : 0
                  height: Style.space(26)

                  Rectangle {
                    anchors.fill: parent
                    radius: Style.space(4)
                    color: root.contentForeground
                    opacity: 0.02
                  }

                  Row {
                    id: subRowContent
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(6)
                    anchors.rightMargin: Style.space(6)
                    spacing: Style.space(6)

                    // Player Jersey Image
                    Item {
                      id: subJerseyBox
                      width: Style.space(24)
                      height: Style.space(24)
                      anchors.verticalCenter: parent.verticalCenter

                      Image {
                        id: subJerseyImg
                        anchors.fill: parent
                        source: subRow.modelData.jerseyImage !== "" ? subRow.modelData.jerseyImage : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        sourceSize.width: Style.space(48)
                        sourceSize.height: Style.space(48)
                        mipmap: true
                        smooth: true
                        visible: status === Image.Ready
                      }

                      Rectangle {
                        anchors.centerIn: parent
                        width: Style.space(20)
                        height: Style.space(20)
                        radius: Style.space(3)
                        color: root.contentForeground
                        opacity: 0.08
                        visible: subJerseyImg.status !== Image.Ready

                        Text {
                          textFormat: Text.PlainText
                          anchors.centerIn: parent
                          text: subRow.modelData.jersey !== "" ? subRow.modelData.jersey : "—"
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                        }
                      }
                    }

                    // Rating Pill (if available)
                    Rectangle {
                      width: subRatingTxt.implicitWidth + Style.space(6)
                      height: Style.space(16)
                      anchors.verticalCenter: parent.verticalCenter
                      radius: Style.space(3)
                      color: root.ratingColor(subRow.modelData.rating)
                      visible: !!(subRow.modelData.rating !== null && subRow.modelData.rating !== undefined)

                      Text {
                        id: subRatingTxt
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: subRow.modelData.rating ? Number(subRow.modelData.rating).toFixed(1) : ""
                        color: "#ffffff"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                      }
                    }

                    // Player Name
                    Text {
                      textFormat: Text.PlainText
                      width: Math.max(0, parent.width - subJerseyBox.width - (subRow.modelData.rating ? (subRatingTxt.implicitWidth + Style.space(12)) : 0) - subPosText.implicitWidth - subEventIcons.implicitWidth - parent.spacing * 4)
                      anchors.verticalCenter: parent.verticalCenter
                      text: subRow.modelData.name
                      color: Qt.darker(root.contentForeground, 1.2)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }

                    // Event Icons (Goals, Assists, Cards, Subs - ESPN Format)
                    Text {
                      id: subEventIcons
                      textFormat: Text.PlainText
                      anchors.verticalCenter: parent.verticalCenter
                      text: subRow.modelData.eventsText || ""
                      color: root.contentForeground
                      font.family: "Symbols Nerd Font, " + root.contentFontFamily
                      font.pixelSize: Style.font.caption - 2
                      visible: text !== ""
                    }

                    // Position
                    Text {
                      id: subPosText
                      textFormat: Text.PlainText
                      anchors.verticalCenter: parent.verticalCenter
                      text: subRow.modelData.position
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                    }
                  }
                }
              }
            }
          }

        // H2H & Form Tab
        Column {
          width: parent.width
          spacing: Style.space(12)
          visible: root.matchDetail && root.matchDetailTab === "h2h"

          // 0. WIN PROBABILITY CARD
          Rectangle {
            width: parent.width
            implicitHeight: winProbCol.implicitHeight + Style.space(20)
            radius: Style.space(8)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
            border.width: 1
            visible: !!(root.matchDetail && root.matchDetail.odds && root.matchDetail.odds.hasProb)

            Column {
              id: winProbCol
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: "WIN PROBABILITY"
                color: Qt.darker(root.contentForeground, 1.6)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption - 1
                font.letterSpacing: 1
                font.bold: true
              }

              Row {
                width: parent.width

                Text {
                  textFormat: Text.PlainText
                  text: (root.matchDetail && root.matchDetail.home ? root.matchDetail.home.name : "Home") + " " + (root.matchDetail && root.matchDetail.odds ? root.matchDetail.odds.homeProb : 0) + "%"
                  color: root.favoriteTeamAccent
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Item {
                  width: Math.max(Style.space(8), parent.width - (parent.children[0].implicitWidth + parent.children[2].implicitWidth + parent.children[4].implicitWidth + Style.space(16)))
                  height: 1
                }

                Text {
                  textFormat: Text.PlainText
                  text: "Draw " + (root.matchDetail && root.matchDetail.odds ? root.matchDetail.odds.drawProb : 0) + "%"
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }

                Item { width: Style.space(8); height: 1 }

                Text {
                  textFormat: Text.PlainText
                  text: (root.matchDetail && root.matchDetail.away ? root.matchDetail.away.name : "Away") + " " + (root.matchDetail && root.matchDetail.odds ? root.matchDetail.odds.awayProb : 0) + "%"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              Rectangle {
                width: parent.width
                height: Style.space(6)
                radius: Style.space(3)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                clip: true

                Row {
                  anchors.fill: parent

                  Rectangle {
                    width: parent.width * ((root.matchDetail && root.matchDetail.odds ? root.matchDetail.odds.homeProb : 0) / 100.0)
                    height: parent.height
                    color: root.favoriteTeamAccent
                  }

                  Rectangle {
                    width: parent.width * ((root.matchDetail && root.matchDetail.odds ? root.matchDetail.odds.drawProb : 0) / 100.0)
                    height: parent.height
                    color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.22)
                  }

                  Rectangle {
                    width: Math.max(0, parent.width - (parent.children[0].width + parent.children[1].width))
                    height: parent.height
                    color: Qt.darker(root.contentForeground, 1.3)
                  }
                }
              }
            }
          }

          // 1. RECENT FORM CARD
          Rectangle {
            width: parent.width
            height: formCardCol.implicitHeight + Style.space(20)
            radius: Style.space(8)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
            border.width: 1
            visible: !!(root.matchDetail && ((root.matchDetail.homeForm && root.matchDetail.homeForm.length > 0) || (root.matchDetail.awayForm && root.matchDetail.awayForm.length > 0)))

            Column {
              id: formCardCol
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(10)

              Text {
                textFormat: Text.PlainText
                text: "FORM GUIDE (LAST 5 MATCHES)"
                color: Qt.darker(root.contentForeground, 1.6)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption - 1
                font.letterSpacing: 1
                font.bold: true
              }

              // Home Form Row
              Row {
                width: parent.width
                spacing: Style.space(8)
                visible: !!(root.matchDetail && root.matchDetail.homeForm && root.matchDetail.homeForm.length > 0)

                Image {
                  width: Style.space(22)
                  height: width
                  source: (root.matchDetail && root.matchDetail.home) ? root.matchDetail.home.logo : ""
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: 64
                  sourceSize.height: 64
                  mipmap: true
                  smooth: true
                  anchors.verticalCenter: parent.verticalCenter
                  visible: String(source) !== ""
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width - (parent.spacing * 2) - Style.space(22) - Style.space(120)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.matchDetail && root.matchDetail.home ? root.matchDetail.home.name : "Home"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                }

                Row {
                  spacing: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter

                  Repeater {
                    model: root.matchDetail ? (root.matchDetail.homeForm || []) : []
                    delegate: Rectangle {
                      id: hFormPill
                      required property var modelData
                      width: Style.space(20)
                      height: Style.space(20)
                      radius: Style.space(4)
                      color: modelData.result === "W" ? "#16a34a" : (modelData.result === "D" ? "#475569" : "#dc2626")

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: hFormPill.modelData.result
                        color: "#ffffff"
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                      }

                      MouseArea {
                        id: hFormMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: matchDetailView.selectedFormMatch = hFormPill.modelData
                      }

                      PanelToolTip {
                        visible: hFormMouse.containsMouse
                        text: {
                          var parts = []
                          if (hFormPill.modelData.opponent) parts.push("vs " + hFormPill.modelData.opponent)
                          if (hFormPill.modelData.score) parts.push(hFormPill.modelData.score)
                          if (hFormPill.modelData.dateFormatted) parts.push(hFormPill.modelData.dateFormatted)
                          return parts.length > 0 ? parts.join(" · ") : (hFormPill.modelData.result || "")
                        }
                      }
                    }
                  }
                }
              }

              // Divider
              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: root.contentForeground
                opacity: 0.1
                visible: !!(root.matchDetail && root.matchDetail.homeForm && root.matchDetail.homeForm.length > 0 && root.matchDetail.awayForm && root.matchDetail.awayForm.length > 0)
              }

              // Away Form Row
              Row {
                width: parent.width
                spacing: Style.space(8)
                visible: !!(root.matchDetail && root.matchDetail.awayForm && root.matchDetail.awayForm.length > 0)

                Image {
                  width: Style.space(22)
                  height: width
                  source: (root.matchDetail && root.matchDetail.away) ? root.matchDetail.away.logo : ""
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: 64
                  sourceSize.height: 64
                  mipmap: true
                  smooth: true
                  anchors.verticalCenter: parent.verticalCenter
                  visible: String(source) !== ""
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width - (parent.spacing * 2) - Style.space(22) - Style.space(120)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.matchDetail && root.matchDetail.away ? root.matchDetail.away.name : "Away"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                }

                Row {
                  spacing: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter

                  Repeater {
                    model: root.matchDetail ? (root.matchDetail.awayForm || []) : []
                    delegate: Rectangle {
                      id: aFormPill
                      required property var modelData
                      width: Style.space(20)
                      height: Style.space(20)
                      radius: Style.space(4)
                      color: modelData.result === "W" ? "#16a34a" : (modelData.result === "D" ? "#475569" : "#dc2626")

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: aFormPill.modelData.result
                        color: "#ffffff"
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                      }

                      MouseArea {
                        id: aFormMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: matchDetailView.selectedFormMatch = aFormPill.modelData
                      }

                      PanelToolTip {
                        visible: aFormMouse.containsMouse
                        text: {
                          var parts = []
                          if (aFormPill.modelData.opponent) parts.push("vs " + aFormPill.modelData.opponent)
                          if (aFormPill.modelData.score) parts.push(aFormPill.modelData.score)
                          if (aFormPill.modelData.dateFormatted) parts.push(aFormPill.modelData.dateFormatted)
                          return parts.length > 0 ? parts.join(" · ") : (aFormPill.modelData.result || "")
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // 2. HEAD-TO-HEAD HISTORY CARD
          Rectangle {
            width: parent.width
            height: h2hCardCol.implicitHeight + Style.space(20)
            radius: Style.space(8)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
            border.width: 1
            visible: !!(root.matchDetail && root.matchDetail.h2h && root.matchDetail.h2h.length > 0)

            Column {
              id: h2hCardCol
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(10)

              Item {
                width: parent.width
                height: Math.max(h2hTitleTxt.implicitHeight, h2hSumTxt.implicitHeight)

                Text {
                  id: h2hTitleTxt
                  textFormat: Text.PlainText
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "HEAD-TO-HEAD"
                  color: Qt.darker(root.contentForeground, 1.6)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.letterSpacing: 1
                  font.bold: true
                }

                Text {
                  id: h2hSumTxt
                  textFormat: Text.PlainText
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.matchDetail ? root.h2hSummary(root.matchDetail.h2h, root.matchDetail.home ? root.matchDetail.home.name : "", root.matchDetail.away ? root.matchDetail.away.name : "") : ""
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                  visible: text !== ""
                }
              }

              // List of H2H Matches
              Column {
                width: parent.width
                spacing: Style.space(6)

                Repeater {
                  model: root.matchDetail ? (root.matchDetail.h2h || []) : []
                  delegate: Column {
                    id: h2hRow
                    required property var modelData
                    width: parent ? parent.width : 0
                    spacing: Style.space(3)

                    // Match Header (Date & Competition)
                    Text {
                      textFormat: Text.PlainText
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      text: (h2hRow.modelData.competition !== "" ? (h2hRow.modelData.competition + " · ") : "") + h2hRow.modelData.dateFormatted
                      color: Qt.darker(root.contentForeground, 1.8)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption - 2
                      elide: Text.ElideRight
                    }

                    // Match Score Line
                    Row {
                      width: parent.width
                      spacing: Style.space(8)

                      Text {
                        textFormat: Text.PlainText
                        width: (parent.width - parent.spacing * 2 - Style.space(56)) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: h2hRow.modelData.home
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                      }

                      Rectangle {
                        width: Style.space(56)
                        height: Style.space(20)
                        radius: Style.space(4)
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)

                        Text {
                          textFormat: Text.PlainText
                          anchors.centerIn: parent
                          text: h2hRow.modelData.homeScore + " – " + h2hRow.modelData.awayScore
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                      }

                      Text {
                        textFormat: Text.PlainText
                        width: (parent.width - parent.spacing * 2 - Style.space(56)) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                        text: h2hRow.modelData.away
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                      }
                    }

                    Rectangle {
                      width: parent.width
                      height: Style.spacing.hairline
                      color: root.contentForeground
                      opacity: 0.08
                    }
                  }
                }
              }
            }
          }
        }

        // Knockout Bracket Tab
        FutBracketView {
          id: matchDetailBracketView
          root: matchDetailView.root
          bracketData: (root.matchDetail && root.matchDetail.knockoutBracket) ? root.matchDetail.knockoutBracket : []
          visible: (root.matchDetailTab === "bracket")
        }

        // Info Tab (stadium, referee, broadcast, odds, editorial recap)
        Column {
          width: parent.width
          spacing: Style.space(10)
          visible: (root.matchDetailTab === "info")

          // Venue
          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.matchDetail && root.matchDetail.info && root.matchDetail.info.venue !== ""

            Text {
              textFormat: Text.PlainText
              width: Style.space(70)
              text: "Stadium"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width - Style.space(78)
              text: root.matchDetail && root.matchDetail.info ? root.matchDetail.info.venue : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // Attendance
          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.matchDetail && root.matchDetail.info && root.matchDetail.info.attendance !== ""

            Text {
              textFormat: Text.PlainText
              width: Style.space(70)
              text: "Attendance"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width - Style.space(78)
              text: root.matchDetail && root.matchDetail.info ? root.matchDetail.info.attendance : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // Officials
          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.matchDetail && root.matchDetail.info && root.matchDetail.info.officials !== ""

            Text {
              textFormat: Text.PlainText
              width: Style.space(70)
              text: "Referee"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width - Style.space(78)
              text: root.matchDetail && root.matchDetail.info ? root.matchDetail.info.officials : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // Broadcasts (normal clean text, no pills)
          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: !!(root.matchDetail && root.matchDetail.broadcasts && root.matchDetail.broadcasts.length > 0)

            Text {
              textFormat: Text.PlainText
              width: Style.space(70)
              text: "Broadcast"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width - Style.space(78)
              text: (root.matchDetail && root.matchDetail.broadcasts) ? root.matchDetail.broadcasts.join(", ") : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // Match Betting Odds (upcoming/live only, hidden once match is finished)
          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: !!(root.showOdds && root.matchDetail && root.matchDetail.odds && (!root.matchDetail.started || root.matchDetail.isLive))

            Text {
              textFormat: Text.PlainText
              text: "MATCH ODDS (" + (root.matchDetail && root.matchDetail.odds ? root.matchDetail.odds.provider : "ODDS") + ")"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Rectangle {
                width: (parent.width - Style.space(16)) / 3
                height: Style.space(42)
                radius: Style.space(6)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(2)

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Spread"
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption - 2
                  }

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (root.matchDetail && root.matchDetail.odds && root.matchDetail.odds.spread !== "") ? root.matchDetail.odds.spread : "—"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              Rectangle {
                width: (parent.width - Style.space(16)) / 3
                height: Style.space(42)
                radius: Style.space(6)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(2)

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Over/Under"
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption - 2
                  }

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (root.matchDetail && root.matchDetail.odds && root.matchDetail.odds.overUnder !== "") ? root.matchDetail.odds.overUnder : "—"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              Rectangle {
                width: (parent.width - Style.space(16)) / 3
                height: Style.space(42)
                radius: Style.space(6)
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(2)

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Line"
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption - 2
                  }

                  Text {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (root.matchDetail && root.matchDetail.odds && root.matchDetail.odds.details !== "") ? root.matchDetail.odds.details : "—"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }
          }

          // Editorial Match Story / Preview (Strictly inside Info Tab)
          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: !!(root.matchDetail && root.matchDetail.article && (root.matchDetail.article.headline !== "" || root.matchDetail.article.description !== ""))

            Text {
              textFormat: Text.PlainText
              text: (root.matchDetail && root.matchDetail.started) ? "MATCH RECAP" : "MATCH PREVIEW"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }

            Rectangle {
              width: parent.width
              implicitHeight: articleCol.implicitHeight + Style.space(16)
              radius: Style.space(6)
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
              border.width: Style.spacing.hairline
              border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)

              Column {
                id: articleCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Style.space(8)
                spacing: Style.space(6)

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: (root.matchDetail && root.matchDetail.article && root.matchDetail.article.headline) ? root.matchDetail.article.headline : ""
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption + 1
                  font.bold: true
                  wrapMode: Text.WordWrap
                  visible: text !== ""
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: (root.matchDetail && root.matchDetail.article && root.matchDetail.article.byline) ? ("By " + root.matchDetail.article.byline) : ""
                  color: Qt.darker(root.contentForeground, 1.7)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption - 2
                  font.italic: true
                  visible: text !== ""
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: (root.matchDetail && root.matchDetail.article && root.matchDetail.article.description) ? root.matchDetail.article.description : ""
                  color: Qt.darker(root.contentForeground, 1.2)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                  lineHeight: 1.2
                  visible: text !== ""
                }
              }
            }
          }
        }
      }

          LoadingOverlay {
            active: root.matchDetailLoading && !root.matchDetail
            text: "Fetching match details…"
          }

          // Form Match Detail Quick Popup Modal
          Rectangle {
            id: formMatchModal
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(20)
            visible: matchDetailView.selectedFormMatch !== null
            width: Math.min(parent.width - Style.space(24), Style.space(280))
            height: formModalCol.implicitHeight + Style.space(20)
            radius: Style.space(8)
            color: Qt.rgba(0.08, 0.08, 0.08, 0.96)
            border.color: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : ShellColor.accent
            border.width: 1
            z: 200

            Column {
              id: formModalCol
              anchors.fill: parent
              anchors.margins: Style.space(12)
              spacing: Style.space(8)

              Row {
                width: parent.width

                Text {
                  textFormat: Text.PlainText
                  text: "MATCH RESULT"
                  color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.5)
                  font.family: root ? root.contentFontFamily : Style.font.family
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                  font.letterSpacing: 0.8
                }

                Item {
                  width: Math.max(0, parent.width - Style.space(110) - closeFormBtn.implicitWidth)
                  height: 1
                }

                Button {
                  id: closeFormBtn
                  width: Style.space(16)
                  height: Style.space(16)
                  iconText: "✕"
                  fontFamily: Style.font.family
                  foreground: root ? root.contentForeground : ShellColor.foreground
                  iconSize: Style.space(8)
                  horizontalPadding: 0
                  verticalPadding: 0
                  onClicked: matchDetailView.selectedFormMatch = null
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                Rectangle {
                  width: Style.space(26)
                  height: Style.space(26)
                  radius: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter
                  color: (matchDetailView.selectedFormMatch && matchDetailView.selectedFormMatch.result === "W")
                    ? "#16a34a"
                    : ((matchDetailView.selectedFormMatch && matchDetailView.selectedFormMatch.result === "D") ? "#475569" : "#dc2626")

                  Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: matchDetailView.selectedFormMatch ? matchDetailView.selectedFormMatch.result : ""
                    color: "#ffffff"
                    font.family: root ? root.contentFontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    textFormat: Text.PlainText
                    text: matchDetailView.selectedFormMatch ? ("vs " + (matchDetailView.selectedFormMatch.opponent || "Opponent")) : ""
                    color: root ? root.contentForeground : ShellColor.foreground
                    font.family: root ? root.contentFontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: matchDetailView.selectedFormMatch ? (matchDetailView.selectedFormMatch.score + (matchDetailView.selectedFormMatch.dateFormatted ? (" · " + matchDetailView.selectedFormMatch.dateFormatted) : "")) : ""
                    color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.4)
                    font.family: root ? root.contentFontFamily : Style.font.family
                    font.pixelSize: Style.space(8.5)
                  }
                }
              }
            }
          }
        }
      }
