import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Column {
  readonly property real standingsTableWidth: standingsTable ? standingsTable.width : Style.space(348)
  id: standingsView
  property var root: null

        width: parent.width
        spacing: Style.space(12)
        visible: root.showStandings && !root.showMatchDetail

        Item {
          width: parent.width
          height: Math.max(Style.space(260), standingsInnerCol.implicitHeight)

          Column {
            id: standingsInnerCol
            width: parent.width
            spacing: Style.space(12)
            opacity: (root.standingsLoading && root.standings.length === 0) ? 0.15 : (root.standingsLoading ? 0.85 : 1.0)
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Row {
              width: parent.width
              spacing: Style.space(8)

          Button {
            id: prevSeasonButton
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
              root.standingsSeasonOffset++
              root.loadStandings()
            }
          }

          Button {
            id: seasonChip
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(52)
            height: Style.space(22)
            text: root.seasonChipLabel(root.standingsSeasonOffset)
            tooltipText: "Standings season"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            horizontalPadding: 0
            verticalPadding: 0
            onClicked: {
              root.standingsSeasonOffset = 0
              root.loadStandings()
            }
          }

          Button {
            id: nextSeasonButton
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
            enabled: root.standingsSeasonOffset > 0
            opacity: enabled ? 1 : 0.35
            onClicked: {
              root.standingsSeasonOffset--
              root.loadStandings()
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(6)
          visible: root.standingsGroups.length > 1

          Repeater {
            model: root.standingsGroups

            Button {
              height: Style.space(24)
              text: root.sanitizePlainText(String(modelData.name || modelData.shortName || ""))
              tooltipText: root.sanitizePlainText(String(modelData.name || ""))
              fontFamily: root.contentFontFamily
              foreground: root.contentForeground
              accent: root.contentForeground
              fontSize: Style.font.caption
              horizontalPadding: Style.space(10)
              verticalPadding: 0
              selected: root.standingsGroupIndex === index
              onClicked: root.standingsGroupIndex = index
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          opacity: root.standingsLoading ? 0.4 + 0.6 * root._pulse : 1.0
          text: root.standingsLoading ? "Fetching standings…"
            : (root.standingsError !== "" ? root.standingsError
            : (root.standings.length === 0 ? "No standings available" : ""))
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          visible: text !== ""
        }

        Flickable {
          id: standingsTable
          width: parent.width
          // Full table, no internal scrolling: every position visible.
          height: headerRow.implicitHeight + root.standings.length * standingsRowHeight
          clip: true
          interactive: false
          contentHeight: headerRow.implicitHeight + root.standings.length * standingsRowHeight
          visible: root.standings.length > 0

          Column {
            width: parent.width
            spacing: 0

            Row {
              id: headerRow
              width: parent.width
              height: Style.space(26)
              Text { textFormat: Text.PlainText; width: standingsRankWidth; height: parent.height; text: "#"; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
              Item { width: standingsRankGap; height: 1 }
              Item { width: standingsLogoWidth; height: 1 }
              Text { textFormat: Text.PlainText; width: standingsTeamWidth; height: parent.height; text: "Team"; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true; verticalAlignment: Text.AlignVCenter }
              Repeater {
                model: root.standingsColumns
                Text {
                  textFormat: Text.PlainText
                  width: root.standingsStatWidth; height: parent.height
                  text: modelData.label
                  color: Qt.darker(root.contentForeground, 1.6)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  horizontalAlignment: Text.AlignRight
                  verticalAlignment: Text.AlignVCenter
                }
              }
            }

            Repeater {
              model: root.standings
              width: parent.width

              Rectangle {
                id: rowRect
                readonly property var entry: modelData
                readonly property bool favorite: root.isFavoriteStanding(modelData)
                readonly property color zoneColor: root.standingsZoneColor(modelData)
                readonly property bool hasZone: root.standingsZoneFor(modelData) !== ""
                // A zoned row is tinted with its zone color; otherwise the
                // favorite theme accent is used. The zone bar is the single
                // left indicator — the theme bar only shows for a favorite
                // that has no qualification zone (avoiding two stacked bars).
                readonly property color rowAccent: favorite
                  ? (hasZone ? zoneColor : root.favoriteTeamAccent) : "transparent"
                readonly property color rowTint: favorite
                  ? (hasZone ? Util.alpha(zoneColor, 0.45) : root.favoriteTeamTint) : "transparent"
                width: parent.width
                height: standingsRowHeight
                radius: Style.cornerRadius
                color: rowTint

                Rectangle {
                  id: zoneBar
                  visible: rowRect.hasZone
                  width: 3
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left
                  radius: 1
                  color: rowRect.zoneColor
                }

                Rectangle {
                  id: zoneFavoriteThemeBar
                  visible: rowRect.favorite && !rowRect.hasZone
                  width: 3
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left
                  radius: 1
                  color: root.favoriteTeamAccent
                }

                Row {
                  width: parent.width
                  height: parent.height

                  Text {
                    textFormat: Text.PlainText
                    width: standingsRankWidth; height: parent.height
                    text: rowRect.entry.rank
                    color: rowRect.favorite ? rowRect.rowAccent : Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: rowRect.favorite
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                  }
                  Item { width: standingsRankGap; height: 1 }
                  Image {
                    width: standingsLogoWidth; height: width
                    anchors.verticalCenter: parent.verticalCenter
                    source: rowRect.entry.logo
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 64
                    sourceSize.height: 64
                    asynchronous: true
                    cache: true
                    mipmap: true
                    smooth: true
                    visible: String(source) !== ""
                  }
                  Text {
                    textFormat: Text.PlainText
                    width: standingsTeamWidth; height: parent.height
                    text: rowRect.entry.teamName
                    color: rowRect.favorite ? rowRect.rowAccent : root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: rowRect.favorite
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                  }
                  Repeater {
                    model: root.standingsColumns
                    Text {
                      textFormat: Text.PlainText
                      width: root.standingsStatWidth; height: rowRect.height
                      text: root.statFor(rowRect.entry.stats, modelData.name)
                      color: rowRect.favorite ? rowRect.rowAccent : Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: rowRect.favorite
                      horizontalAlignment: Text.AlignRight
                      verticalAlignment: Text.AlignVCenter
                    }
                  }
                }
              }
            }
          }
        }

        Flow {
          width: parent.width
          spacing: Style.space(14)
          visible: root.standings.length > 0 && root.standingsLegend.length > 0
          Repeater {
            model: root.standingsLegend
            Row {
              spacing: Style.space(5)
              Rectangle {
                width: 8
                height: 8
                anchors.verticalCenter: parent.verticalCenter
                radius: 2
                color: modelData.color
              }
              Text {
                textFormat: Text.PlainText
                text: modelData.label
                color: Qt.darker(root.contentForeground, 1.8)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
          }

          FutLoadingOverlay {
            root: standingsView.root
            active: root.standingsLoading && root.standings.length === 0
            text: "Fetching standings…"
          }
        }
      }

      // League Matches: what matters for the selected league — everything
      // live, the next few upcoming fixtures, and the last few results.
