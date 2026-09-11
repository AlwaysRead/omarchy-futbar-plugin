import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

Column {
  id: statsView
  property var root: null
  width: parent ? parent.width : 0
  spacing: Style.space(12)
  visible: root ? (root.showStats && !root.showMatchDetail) : false

  component LoadingOverlay: FutLoadingOverlay { root: statsView.root }

        Item {
          width: parent.width
          height: Math.max(Style.space(260), statsInnerCol.implicitHeight)

          Column {
            id: statsInnerCol
            width: parent.width
            spacing: Style.space(12)
            opacity: (root.statsLoading && root.statsGoals.length === 0 && root.statsAssists.length === 0 && root.statsYellow.length === 0) ? 0.15 : (root.statsLoading ? 0.85 : 1.0)
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Row {
              width: parent.width
              spacing: Style.space(8)

          Button {
            id: prevStatsSeasonButton
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
              root.statsSeasonOffset++
              root.loadStats(true)
            }
          }

          Button {
            id: statsSeasonChip
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(52)
            height: Style.space(22)
            text: root.seasonChipLabel(root.statsSeasonOffset)
            tooltipText: "Stats season"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: 0
            verticalPadding: 0
            onClicked: {
              root.statsSeasonOffset = 0
              root.loadStats(true)
            }
          }

          Button {
            id: nextStatsSeasonButton
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
            enabled: root.statsSeasonOffset > 0
            opacity: enabled ? 1 : 0.35
            onClicked: {
              root.statsSeasonOffset--
              root.loadStats(true)
            }
          }
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)

          Button {
            id: goalsTabButton
            height: Style.space(22)
            text: "Goals"
            tooltipText: "Top goal scorers"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            selected: root.statsCategory === "goals"
            onClicked: root.statsCategory = "goals"
          }

          Button {
            id: assistsTabButton
            height: Style.space(22)
            text: "Assists"
            tooltipText: "Top assists leaders"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            selected: root.statsCategory === "assists"
            onClicked: root.statsCategory = "assists"
          }

          Button {
            id: yellowTabButton
            height: Style.space(22)
            text: "Yellow Cards"
            tooltipText: "Yellow cards leaders"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            selected: root.statsCategory === "yellow"
            onClicked: root.statsCategory = "yellow"
          }

          Button {
            id: redTabButton
            height: Style.space(22)
            text: "Red Cards"
            tooltipText: "Red cards leaders"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            selected: root.statsCategory === "red"
            onClicked: root.statsCategory = "red"
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          opacity: root.statsLoading ? 0.4 + 0.6 * root._pulse : 1.0
          text: root.statsLoading ? "Fetching statistics…"
            : (root.statsError !== "" ? root.statsError
            : ((root.statsCategory === "goals" ? root.statsGoals.length : (root.statsCategory === "assists" ? root.statsAssists.length : (root.statsCategory === "yellow" ? root.statsYellow.length : root.statsRed.length))) === 0 ? "No stats available" : ""))
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          visible: text !== ""
        }

        Column {
          width: parent.width
          spacing: 0
          visible: (root.statsCategory === "goals" ? root.statsGoals.length : (root.statsCategory === "assists" ? root.statsAssists.length : (root.statsCategory === "yellow" ? root.statsYellow.length : root.statsRed.length))) > 0

          Row {
            width: parent.width
            height: Style.space(26)

            Text {
              textFormat: Text.PlainText
              width: Style.space(20)
              height: parent.height
              text: "#"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignRight
              verticalAlignment: Text.AlignVCenter
            }
            Item { width: Style.space(8); height: 1 }
            Item { width: Style.space(20); height: 1 }
            Item { width: Style.space(6); height: 1 }
            Text {
              textFormat: Text.PlainText
              width: parent.width - Style.space(20 + 8 + 20 + 6 + (root.showStatsMatchesColumn ? 48 : 0) + 48)
              height: parent.height
              text: "Player"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              verticalAlignment: Text.AlignVCenter
            }
            Text {
              textFormat: Text.PlainText
              width: root.showStatsMatchesColumn ? Style.space(48) : 0
              height: parent.height
              text: "Matches"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              visible: root.showStatsMatchesColumn
            }
            Text {
              textFormat: Text.PlainText
              width: Style.space(48)
              height: parent.height
              text: root.statsCategory === "goals" ? "Goals" : (root.statsCategory === "assists" ? "Assists" : (root.statsCategory === "yellow" ? "Yellow" : "Red"))
              color: root.statsCategory === "yellow" ? "#eab308" : (root.statsCategory === "red" ? "#ef4444" : root.favoriteTeamAccent)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }

          Repeater {
            model: (root.statsCategory === "goals" ? root.statsGoals : (root.statsCategory === "assists" ? root.statsAssists : (root.statsCategory === "yellow" ? root.statsYellow : root.statsRed))).slice(0, 15)

            delegate: Item {
              id: statRow
              required property var modelData
              width: parent ? parent.width : 0
              height: Style.space(32)

              Rectangle {
                anchors.fill: parent
                color: root.contentForeground
                opacity: statRow.modelData.rank % 2 === 1 ? 0.03 : 0.0
                radius: Style.space(4)
              }

              Row {
                anchors.fill: parent

                Text {
                  textFormat: Text.PlainText
                  width: Style.space(20)
                  height: parent.height
                  text: statRow.modelData.rank
                  color: statRow.modelData.rank <= 3 ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: statRow.modelData.rank <= 3
                  horizontalAlignment: Text.AlignRight
                  verticalAlignment: Text.AlignVCenter
                }

                Item { width: Style.space(8); height: 1 }

                Image {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(20)
                  height: Style.space(20)
                  source: statRow.modelData.teamLogo
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: 64
                  sourceSize.height: 64
                  mipmap: true
                  asynchronous: true
                  smooth: true
                  visible: String(source) !== ""
                }

                Item { width: Style.space(6); height: 1 }

                Column {
                  width: parent.width - Style.space(20 + 8 + 20 + 6 + (root.showStatsMatchesColumn ? 48 : 0) + 48)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 0

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: statRow.modelData.name
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: statRow.modelData.teamName
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    visible: text !== ""
                  }
                }

                Text {
                  textFormat: Text.PlainText
                  width: root.showStatsMatchesColumn ? Style.space(48) : 0
                  height: parent.height
                  text: statRow.modelData.appearances !== "" ? statRow.modelData.appearances : "—"
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  visible: root.showStatsMatchesColumn
                }

                Text {
                  textFormat: Text.PlainText
                  width: Style.space(48)
                  height: parent.height
                  text: statRow.modelData.value
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
              }
            }
          }
        }
          }

          LoadingOverlay {
            active: root.statsLoading && root.statsGoals.length === 0 && root.statsAssists.length === 0 && root.statsYellow.length === 0
            text: "Fetching statistics…"
          }
        }
      }
