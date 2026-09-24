import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

Column {
  id: standingsView
  property var root: null
  width: parent ? parent.width : 0
  spacing: Style.space(12)
  visible: root ? (root.showStandings && !root.showMatchDetail && !root.showTrending) : false

  component LoadingOverlay: FutLoadingOverlay { root: standingsView.root }

  readonly property real standingsRowHeight: root ? root.standingsRowHeight : Style.space(28)
  readonly property real standingsStatWidth: root ? root.standingsStatWidth : Style.space(26)
  readonly property real standingsRankWidth: root ? root.standingsRankWidth : Style.space(24)
  readonly property real standingsRankGap: root ? root.standingsRankGap : Style.space(10)
  readonly property real standingsLogoWidth: root ? root.standingsLogoWidth : Style.space(16)
  readonly property real standingsRowWidth: standingsTable ? standingsTable.width : Style.space(348)
  readonly property real standingsTeamWidth: standingsRowWidth - standingsRankWidth - standingsRankGap - standingsLogoWidth - 8 * standingsStatWidth

  Item {
    width: parent.width
    height: Math.max(Style.space(260), standingsInnerCol.implicitHeight)

    Column {
      id: standingsInnerCol
      width: parent.width
      spacing: Style.space(12)
      opacity: (root && root.standingsLoading && root.standings.length === 0) ? 0.15 : ((root && root.standingsLoading) ? 0.85 : 1.0)
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
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          iconSize: Style.font.caption
          horizontalPadding: 0
          verticalPadding: 0
          onClicked: {
            if (root) {
              root.standingsSeasonOffset++
              root.loadStandings()
            }
          }
        }

        Button {
          id: seasonChip
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(52)
          height: Style.space(22)
          text: root ? root.seasonChipLabel(root.standingsSeasonOffset) : ""
          tooltipText: "Standings season"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          fontSize: Style.font.caption
          horizontalPadding: 0
          verticalPadding: 0
          onClicked: {
            if (root) {
              root.standingsSeasonOffset = 0
              root.loadStandings()
            }
          }
        }

        Button {
          id: nextSeasonButton
          width: Style.space(22)
          height: Style.space(22)
          iconText: ""
          tooltipText: "Newer season"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : Color.foreground
          accent: root ? root.contentForeground : Color.foreground
          iconSize: Style.font.caption
          horizontalPadding: 0
          verticalPadding: 0
          enabled: root ? root.standingsSeasonOffset > 0 : false
          opacity: enabled ? 1 : 0.35
          onClicked: {
            if (root) {
              root.standingsSeasonOffset--
              root.loadStandings()
            }
          }
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(6)
        visible: root ? root.standingsGroups.length > 1 : false

        Repeater {
          model: root ? root.standingsGroups : []

          Button {
            height: Style.space(24)
            text: root ? root.sanitizePlainText(String(modelData.name || modelData.shortName || "")) : ""
            tooltipText: root ? root.sanitizePlainText(String(modelData.name || "")) : ""
            fontFamily: root ? root.contentFontFamily : Style.font.family
            foreground: root ? root.contentForeground : Color.foreground
            accent: root ? root.contentForeground : Color.foreground
            fontSize: Style.font.caption
            horizontalPadding: Style.space(10)
            verticalPadding: 0
            selected: root ? root.standingsGroupIndex === index : false
            onClicked: if (root) root.standingsGroupIndex = index
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        opacity: root ? (root.standingsLoading ? 0.4 + 0.6 * root._pulse : 1.0) : 1.0
        text: root ? (root.standingsLoading ? "Fetching standings…"
          : (root.standingsError !== "" ? root.standingsError
          : (root.standings.length === 0 ? "No standings available" : ""))) : ""
        color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.5)
        font.family: root ? root.contentFontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        visible: text !== ""
      }

      Flickable {
        id: standingsTable
        width: parent.width
        height: headerRow.implicitHeight + (root ? root.standings.length : 0) * standingsView.standingsRowHeight
        clip: true
        interactive: false
        contentHeight: headerRow.implicitHeight + (root ? root.standings.length : 0) * standingsView.standingsRowHeight
        visible: root ? root.standings.length > 0 : false

        Column {
          width: parent.width
          spacing: 0

          Row {
            id: headerRow
            width: parent.width
            height: Style.space(26)
            Text {
              textFormat: Text.PlainText
              width: standingsView.standingsRankWidth
              height: parent.height
              text: "#"
              color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.6)
              font.family: root ? root.contentFontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignRight
              verticalAlignment: Text.AlignVCenter
            }
            Item { width: standingsView.standingsRankGap; height: 1 }
            Item { width: standingsView.standingsLogoWidth; height: 1 }
            Text {
              textFormat: Text.PlainText
              width: standingsView.standingsTeamWidth
              height: parent.height
              text: "Team"
              color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.6)
              font.family: root ? root.contentFontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              verticalAlignment: Text.AlignVCenter
            }
            Repeater {
              model: root ? root.standingsColumns : []
              Text {
                textFormat: Text.PlainText
                width: standingsView.standingsStatWidth
                height: parent.height
                text: modelData.label
                color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.6)
                font.family: root ? root.contentFontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
              }
            }
          }

          Repeater {
            model: root ? root.standings : []
            width: parent.width

            Rectangle {
              id: rowRect
              readonly property var entry: modelData
              readonly property bool favorite: root ? root.isFavoriteStanding(modelData) : false
              readonly property color zoneColor: root ? root.standingsZoneColor(modelData) : "transparent"
              readonly property bool hasZone: root ? root.standingsZoneFor(modelData) !== "" : false
              readonly property color rowAccent: favorite
                ? (hasZone ? zoneColor : (root ? root.favoriteTeamAccent : Color.accent)) : "transparent"
              readonly property color rowTint: favorite
                ? (hasZone ? Util.alpha(zoneColor, 0.45) : (root ? root.favoriteTeamTint : "transparent")) : "transparent"
              width: parent.width
              height: standingsView.standingsRowHeight
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
                color: root ? root.favoriteTeamAccent : Color.accent
              }

              Row {
                width: parent.width
                height: parent.height

                Text {
                  textFormat: Text.PlainText
                  width: standingsView.standingsRankWidth
                  height: parent.height
                  text: rowRect.entry.rank
                  color: rowRect.favorite ? rowRect.rowAccent : Qt.darker(root ? root.contentForeground : Color.foreground, 1.5)
                  font.family: root ? root.contentFontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: rowRect.favorite
                  horizontalAlignment: Text.AlignRight
                  verticalAlignment: Text.AlignVCenter
                }
                Item { width: standingsView.standingsRankGap; height: 1 }
                Image {
                  width: standingsView.standingsLogoWidth
                  height: width
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
                  width: standingsView.standingsTeamWidth
                  height: parent.height
                  text: rowRect.entry.teamName
                  color: rowRect.favorite ? rowRect.rowAccent : (root ? root.contentForeground : Color.foreground)
                  font.family: root ? root.contentFontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: rowRect.favorite
                  elide: Text.ElideRight
                  verticalAlignment: Text.AlignVCenter
                }
                Repeater {
                  model: root ? root.standingsColumns : []
                  Text {
                    textFormat: Text.PlainText
                    width: standingsView.standingsStatWidth
                    height: rowRect.height
                    text: root ? root.statFor(rowRect.entry.stats, modelData.name) : ""
                    color: rowRect.favorite ? rowRect.rowAccent : Qt.darker(root ? root.contentForeground : Color.foreground, 1.5)
                    font.family: root ? root.contentFontFamily : Style.font.family
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
        visible: root ? (root.standings.length > 0 && root.standingsLegend.length > 0) : false
        Repeater {
          model: root ? root.standingsLegend : []
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
              color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.8)
              font.family: root ? root.contentFontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }

    LoadingOverlay {
      active: root ? (root.standingsLoading && root.standings.length === 0) : false
      text: "Fetching standings…"
    }
  }
}
