import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

Column {
  id: matchDetailView
  property var root: null
  visible: root ? root.showMatchDetail : false
  width: parent ? parent.width : 0
  spacing: Style.space(12)

  component LoadingOverlay: FutLoadingOverlay { root: matchDetailView.root }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            width: Style.space(26)
            height: Style.space(26)
            iconText: ""
            tooltipText: "Back to matches"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            iconSize: Style.font.caption
            horizontalPadding: 0
            verticalPadding: 0
            onClicked: root.showMatchDetail = false
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: root.matchDetail ? (root.matchDetail.competitionName || "Match Details") : "Match Details"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            elide: Text.ElideRight
            width: parent.width - Style.space(26 + 8)
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
          height: Math.max(Style.space(114), dateTextHeader.implicitHeight + Math.max(scoreCenterCol.implicitHeight, Math.max(homeSideCol.implicitHeight, awaySideCol.implicitHeight)) + (shootoutBottomCol.visible ? shootoutBottomCol.implicitHeight + Style.space(8) : 0) + Style.space(24))

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
              width: parent.width
              height: Style.space(50)

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
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

              Text {
                id: seriesText
                textFormat: Text.PlainText
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.matchDetail ? (root.matchDetail.shootoutNote === "" ? (root.matchDetail.seriesNote || "") : "") : ""
                color: Qt.darker(root.contentForeground, 1.6)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
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

          // Penalty Shootout Result (bottom middle)
          Column {
            id: shootoutBottomCol
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(8)
            spacing: Style.space(1)
            visible: !!(root.matchDetail && (root.matchDetail.shootoutNote !== "" || root.matchDetail.shootoutScore !== "" || (root.matchDetail.shootoutText && root.matchDetail.shootoutText !== "")))

            Text {
              textFormat: Text.PlainText
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.matchDetail ? (root.matchDetail.shootoutText || "After Penalties") : "After Penalties"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              textFormat: Text.PlainText
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.matchDetail ? (root.matchDetail.shootoutScore !== "" ? root.matchDetail.shootoutScore : root.matchDetail.shootoutNote) : ""
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              visible: text !== ""
            }
          }
        }

        // Section Tabs
        Row {
          width: parent.width
          spacing: Style.space(8)
          visible: !!root.matchDetail

          Button {
            height: Style.space(24)
            text: "Stats"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            visible: !!(root.matchDetail && root.matchDetail.started)
            selected: root.matchDetailTab === "stats"
            onClicked: root.matchDetailTab = "stats"
          }

          Button {
            height: Style.space(24)
            text: "Timeline"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            visible: !!(root.matchDetail && root.matchDetail.started && !root.matchDetail.isLive)
            selected: root.matchDetailTab === "events"
            onClicked: root.matchDetailTab = "events"
          }

          Button {
            height: Style.space(24)
            text: "Commentary"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            visible: !!(root.matchDetail && root.matchDetail.isLive && root.matchDetail.commentary && root.matchDetail.commentary.length > 0)
            selected: root.matchDetailTab === "commentary"
            onClicked: root.matchDetailTab = "commentary"
          }

          Button {
            height: Style.space(24)
            text: "Lineups"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            visible: !!root.matchDetail
            selected: root.matchDetailTab === "lineups"
            onClicked: root.matchDetailTab = "lineups"
          }

          Button {
            height: Style.space(24)
            text: "H2H & Form"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            visible: !!(root.matchDetail && ((root.matchDetail.h2h && root.matchDetail.h2h.length > 0) || (root.matchDetail.homeForm && root.matchDetail.homeForm.length > 0) || (root.matchDetail.awayForm && root.matchDetail.awayForm.length > 0)))
            selected: root.matchDetailTab === "h2h"
            onClicked: root.matchDetailTab = "h2h"
          }

          Button {
            height: Style.space(24)
            text: "Info"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            selected: root.matchDetailTab === "info"
            onClicked: root.matchDetailTab = "info"
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
            model: root.matchDetail ? (root.matchDetail.stats || []) : []

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
        }

        // Commentary Tab
        Column {
          width: parent.width
          spacing: Style.space(6)
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

          Flickable {
            id: commFlickable
            width: parent.width
            height: Math.min(commCol.implicitHeight, Style.space(320))
            contentHeight: commCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: root.matchDetail && root.matchDetail.commentary && root.matchDetail.commentary.length > 0

            Column {
              id: commCol
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.matchDetail ? (root.matchDetail.commentary || []) : []

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

                  // 3. Substitute Out Badge (Bottom-Right - White ▼)
                  Rectangle {
                    id: subBadge
                    width: Style.space(13)
                    height: Style.space(13)
                    radius: width / 2
                    anchors.bottom: jerseyContainer.bottom
                    anchors.right: jerseyContainer.right
                    anchors.bottomMargin: -Style.space(2)
                    anchors.rightMargin: -Style.space(3)
                    color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
                    border.color: Qt.rgba(1, 1, 1, 0.3)
                    border.width: 0.7
                    z: 20
                    visible: !!pitchPlayerItem.modelData.subbedOut

                    Text {
                      textFormat: Text.PlainText
                      anchors.centerIn: parent
                      text: "▼"
                      color: "#ffffff"
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption - 2
                      font.bold: true
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
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
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
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
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
        }
          }

          LoadingOverlay {
            active: root.matchDetailLoading && !root.matchDetail
            text: "Fetching match details…"
          }
        }
      }
