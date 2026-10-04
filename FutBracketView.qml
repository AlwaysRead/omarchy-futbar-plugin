import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

Column {
  id: bracketView
  property var root: null
  property var bracketData: []

  // Hide the bracket if no verified bracket data exists
  visible: !!(bracketView.bracketData && Array.isArray(bracketView.bracketData) && bracketView.bracketData.length > 0)
  width: parent ? parent.width : 0
  spacing: Style.space(8)

  readonly property real cardH: Style.space(72)
  readonly property real cardW: Style.space(190)
  readonly property real gap0: Style.space(16)
  readonly property real pitch0: cardH + gap0
  readonly property real headerH: Style.space(32)
  readonly property real connW: Style.space(20)

  readonly property int maxRoundMatches: {
    var rounds = bracketView.bracketData || []
    var maxM = 1
    for (var i = 0; i < rounds.length; i++) {
      var cnt = (rounds[i].matchups || []).length
      if (cnt > maxM) maxM = cnt
    }
    return Math.max(1, maxM)
  }

  readonly property real totalCanvasH: Math.max(Style.space(420), maxRoundMatches * pitch0)
  readonly property real treeCanvasHeight: headerH + totalCanvasH + Style.space(12)

  // Returns vertical center coordinate for match m in round with rMatches total matches
  function calcMatchCenter(rMatches, m) {
    var count = Math.max(1, rMatches)
    var step = totalCanvasH / count
    return headerH + (m + 0.5) * step
  }

  function calcMatchTop(rMatches, m) {
    return calcMatchCenter(rMatches, m) - cardH / 2.0
  }

  function isTeamAdvancing(winner, teamName) {
    if (!winner || !teamName) return false
    if (winner === teamName) return true
    var w = String(winner).trim().toLowerCase()
    var t = String(teamName).trim().toLowerCase()
    return w === t || w.indexOf(t) !== -1 || t.indexOf(w) !== -1
  }

  // Top Navigation & Scroll Controls Bar
  Row {
    width: parent.width
    height: Style.space(26)
    spacing: Style.space(6)

    Button {
      width: Style.space(26)
      height: Style.space(24)
      iconText: "◀"
      tooltipText: "Scroll left"
      fontFamily: root ? root.contentFontFamily : Style.font.family
      foreground: root ? root.contentForeground : Color.foreground
      accent: root ? root.contentForeground : Color.foreground
      fontSize: Style.space(8)
      horizontalPadding: 0
      verticalPadding: 0
      enabled: bracketFlickable.contentX > 0
      opacity: enabled ? 1 : 0.35
      onClicked: bracketFlickable.contentX = Math.max(0, bracketFlickable.contentX - Style.space(200))
    }

    Rectangle {
      width: parent.width - Style.space(64)
      height: Style.space(24)
      radius: Style.space(4)
      color: Util.alpha(root ? root.contentForeground : Color.foreground, 0.04)

      Row {
        anchors.centerIn: parent
        spacing: Style.space(6)

        Text {
          textFormat: Text.PlainText
          text: "󰒺"
          font.pixelSize: Style.space(8.5)
          color: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          textFormat: Text.PlainText
          text: "Swipe or scroll horizontally to explore full draw"
          color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.4)
          font.family: root ? root.contentFontFamily : Style.font.family
          font.pixelSize: Style.space(7.5)
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    Button {
      width: Style.space(26)
      height: Style.space(24)
      iconText: "▶"
      tooltipText: "Scroll right"
      fontFamily: root ? root.contentFontFamily : Style.font.family
      foreground: root ? root.contentForeground : Color.foreground
      accent: root ? root.contentForeground : Color.foreground
      fontSize: Style.space(8)
      horizontalPadding: 0
      verticalPadding: 0
      enabled: (bracketFlickable.contentWidth - bracketFlickable.width) > bracketFlickable.contentX
      opacity: enabled ? 1 : 0.35
      onClicked: bracketFlickable.contentX = Math.min(bracketFlickable.contentWidth - bracketFlickable.width, bracketFlickable.contentX + Style.space(200))
    }
  }

  // Smooth Horizontally Swipeable Bracket Canvas
  Flickable {
    id: bracketFlickable
    width: parent.width
    height: bracketView.treeCanvasHeight
    contentWidth: roundsRow.implicitWidth + Style.space(24)
    contentHeight: height
    clip: true
    interactive: true
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.DragOverBounds

    WheelHandler {
      id: bracketWheel
      orientation: Qt.Horizontal
      onWheel: function(event) {
        var delta = (event.angleDelta && event.angleDelta.y !== 0) ? event.angleDelta.y : (event.angleDelta ? event.angleDelta.x : 0)
        if (delta !== 0) {
          bracketFlickable.contentX = Math.max(0, Math.min(bracketFlickable.contentWidth - bracketFlickable.width, bracketFlickable.contentX - delta * 1.5))
        }
      }
    }

    Row {
      id: roundsRow
      spacing: 0
      height: bracketView.treeCanvasHeight

      Repeater {
        model: bracketView.bracketData || []

        delegate: Row {
          id: roundTreeBranch
          required property var modelData
          required property int index
          spacing: 0
          height: bracketView.treeCanvasHeight

          readonly property int curMatchCount: (roundTreeBranch.modelData && roundTreeBranch.modelData.matchups) ? roundTreeBranch.modelData.matchups.length : 1
          readonly property var prevRound: roundTreeBranch.index > 0 ? bracketView.bracketData[roundTreeBranch.index - 1] : null
          readonly property int prevMatchCount: (prevRound && prevRound.matchups) ? prevRound.matchups.length : 1

          // Visual Progression Connector Column
          Item {
            id: incomingConnectors
            width: bracketView.connW
            height: bracketView.treeCanvasHeight
            implicitWidth: width
            implicitHeight: height
            visible: roundTreeBranch.index > 0

            Repeater {
              model: roundTreeBranch.curMatchCount

              delegate: Item {
                id: connPair
                required property int index
                anchors.fill: parent

                readonly property bool isFeederPair: (roundTreeBranch.prevMatchCount === roundTreeBranch.curMatchCount * 2)
                readonly property int f1Idx: isFeederPair ? (connPair.index * 2) : connPair.index
                readonly property int f2Idx: connPair.index * 2 + 1

                readonly property real c1Y: bracketView.calcMatchCenter(roundTreeBranch.prevMatchCount, f1Idx)
                readonly property real c2Y: isFeederPair ? bracketView.calcMatchCenter(roundTreeBranch.prevMatchCount, f2Idx) : c1Y
                readonly property real outY: bracketView.calcMatchCenter(roundTreeBranch.curMatchCount, connPair.index)

                // Feeder 1 stem
                Rectangle {
                  x: 0
                  y: Math.round(connPair.c1Y - Style.space(1))
                  width: connPair.isFeederPair ? bracketView.connW / 2 : bracketView.connW
                  height: Style.space(1.5)
                  color: Util.alpha(root ? root.contentForeground : Color.foreground, 0.25)
                }

                // Feeder 2 stem (when two feeders merge into one)
                Rectangle {
                  x: 0
                  y: Math.round(connPair.c2Y - Style.space(1))
                  width: bracketView.connW / 2
                  height: Style.space(1.5)
                  visible: connPair.isFeederPair
                  color: Util.alpha(root ? root.contentForeground : Color.foreground, 0.25)
                }

                // Vertical joining crossbar
                Rectangle {
                  x: Math.round(bracketView.connW / 2 - Style.space(1))
                  y: Math.round(connPair.c1Y)
                  width: Style.space(1.5)
                  height: Math.max(0, Math.round(connPair.c2Y - connPair.c1Y))
                  visible: connPair.isFeederPair
                  color: Util.alpha(root ? root.contentForeground : Color.foreground, 0.25)
                }

                // Output stem into current card
                Rectangle {
                  x: Math.round(bracketView.connW / 2)
                  y: Math.round(connPair.outY - Style.space(1))
                  width: bracketView.connW / 2
                  height: Style.space(1.5)
                  visible: connPair.isFeederPair
                  color: Util.alpha(root ? root.contentForeground : Color.foreground, 0.25)
                }
              }
            }
          }

          // Round Column Canvas
          Item {
            id: colCanvas
            width: bracketView.cardW
            height: bracketView.treeCanvasHeight
            implicitWidth: width
            implicitHeight: height

            // Stage Header (Pinned at y = 0, clean & simple)
            Rectangle {
              id: stageHeader
              x: 0
              y: 0
              width: parent.width
              height: Style.space(26)
              radius: Style.space(4)
              color: roundTreeBranch.modelData.isCurrentRound
                ? Util.alpha((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent, 0.15)
                : Qt.rgba(root ? root.contentForeground.r : 1, root ? root.contentForeground.g : 1, root ? root.contentForeground.b : 1, 0.05)
              border.color: roundTreeBranch.modelData.isCurrentRound
                ? ((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent) : "transparent"
              border.width: roundTreeBranch.modelData.isCurrentRound ? 1 : 0

              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: roundTreeBranch.modelData.roundName
                color: roundTreeBranch.modelData.isCurrentRound
                  ? ((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent)
                  : (root ? root.contentForeground : Color.foreground)
                font.family: root ? root.contentFontFamily : Style.font.family
                font.pixelSize: Style.space(8.5)
                font.bold: true
              }
            }

            // Cards positioned at exact calculated midpoints
            Repeater {
              model: roundTreeBranch.modelData.matchups || []

              delegate: Rectangle {
                id: mCard
                required property var modelData
                required property int index

                x: 0
                y: Math.round(bracketView.calcMatchTop(roundTreeBranch.curMatchCount, mCard.index))
                width: parent.width
                height: bracketView.cardH
                radius: Style.space(5)
                clip: true

                color: (mCard.modelData && mCard.modelData.isCurrent)
                  ? Util.alpha((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent, 0.12)
                  : Qt.rgba(root ? root.contentForeground.r : 1, root ? root.contentForeground.g : 1, root ? root.contentForeground.b : 1, 0.03)
                border.color: (mCard.modelData && mCard.modelData.isCurrent)
                  ? ((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent)
                  : Qt.rgba(root ? root.contentForeground.r : 1, root ? root.contentForeground.g : 1, root ? root.contentForeground.b : 1, 0.1)
                border.width: (mCard.modelData && mCard.modelData.isCurrent) ? 1.5 : 1

                Column {
                  anchors.fill: parent
                  anchors.margins: Style.space(5)
                  spacing: Style.space(2)

                  // Top Header inside card (Only for current match plus leg column labels)
                  Row {
                    width: parent.width
                    height: Style.space(11)

                    Rectangle {
                      height: Style.space(11)
                      width: bText.implicitWidth + Style.space(6)
                      radius: 2
                      visible: !!(mCard.modelData && mCard.modelData.isCurrent)
                      color: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent

                      Text {
                        id: bText
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: "THIS MATCH"
                        color: "#ffffff"
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.space(6.5)
                        font.bold: true
                      }
                    }

                    Item {
                      width: Math.max(0, parent.width - (bText.visible ? bText.implicitWidth + Style.space(6) : 0) - (mCard.modelData && mCard.modelData.hasTwoLegs ? Style.space(48) : 0))
                      height: 1
                    }

                    Row {
                      visible: !!(mCard.modelData && mCard.modelData.hasTwoLegs)
                      spacing: Style.space(3)
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        textFormat: Text.PlainText
                        text: "1st"
                        color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.8)
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.space(6.5)
                        width: Style.space(11)
                        horizontalAlignment: Text.AlignRight
                      }
                      Text {
                        textFormat: Text.PlainText
                        text: "2nd"
                        color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.8)
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.space(6.5)
                        width: Style.space(11)
                        horizontalAlignment: Text.AlignRight
                      }
                      Item { width: Style.spacing.hairline; height: 1 }
                      Text {
                        textFormat: Text.PlainText
                        text: "AGG"
                        color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.4)
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.space(6.5)
                        font.bold: true
                        width: Style.space(13)
                        horizontalAlignment: Text.AlignRight
                      }
                    }
                  }

                  // Home Team Row (Anchored to prevent score overflow)
                  Item {
                    width: parent.width
                    height: Style.space(16)

                    Image {
                      id: homeLogoImg
                      width: Style.space(15)
                      height: width
                      source: mCard.modelData ? (mCard.modelData.homeLogo || "") : ""
                      fillMode: Image.PreserveAspectFit
                      sourceSize.width: 48
                      sourceSize.height: 48
                      mipmap: true
                      smooth: true
                      asynchronous: true
                      cache: true
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      visible: status === Image.Ready
                    }

                    Row {
                      id: homeScoreRow
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(3)

                      Text {
                        textFormat: Text.PlainText
                        visible: !!(mCard.modelData && mCard.modelData.hasTwoLegs)
                        text: mCard.modelData ? (mCard.modelData.homeLeg1 || "—") : "—"
                        color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.4)
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.space(7.5)
                        width: Style.space(11)
                        horizontalAlignment: Text.AlignRight
                      }

                      Text {
                        textFormat: Text.PlainText
                        visible: !!(mCard.modelData && mCard.modelData.hasTwoLegs)
                        text: mCard.modelData ? (mCard.modelData.homeLeg2 || "—") : "—"
                        color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.4)
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.space(7.5)
                        width: Style.space(11)
                        horizontalAlignment: Text.AlignRight
                      }

                      Rectangle {
                        visible: !!(mCard.modelData && mCard.modelData.hasTwoLegs)
                        width: Style.spacing.hairline
                        height: Style.space(9)
                        color: root ? root.contentForeground : Color.foreground
                        opacity: 0.2
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Text {
                        textFormat: Text.PlainText
                        text: mCard.modelData ? (mCard.modelData.homeAgg !== undefined && mCard.modelData.homeAgg !== "" ? mCard.modelData.homeAgg : (mCard.modelData.homeScore || "")) : ""
                        color: (mCard.modelData && bracketView.isTeamAdvancing(mCard.modelData.winner, mCard.modelData.homeName))
                          ? "#4ade80" : (root ? root.contentForeground : Color.foreground)
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.space(8.5)
                        font.bold: true
                        width: Style.space(13)
                        horizontalAlignment: Text.AlignRight
                      }
                    }

                    Text {
                      id: homeNameTxt
                      textFormat: Text.PlainText
                      text: mCard.modelData ? (mCard.modelData.homeName || "TBD") : "TBD"
                      color: (mCard.modelData && bracketView.isTeamAdvancing(mCard.modelData.winner, mCard.modelData.homeName))
                        ? "#4ade80" : (root ? root.contentForeground : Color.foreground)
                      font.family: root ? root.contentFontFamily : Style.font.family
                      font.pixelSize: Style.space(8)
                      font.bold: !!(mCard.modelData && (mCard.modelData.isCurrent || bracketView.isTeamAdvancing(mCard.modelData.winner, mCard.modelData.homeName)))
                      elide: Text.ElideRight
                      anchors.left: homeLogoImg.right
                      anchors.leftMargin: Style.space(4)
                      anchors.right: homeScoreRow.left
                      anchors.rightMargin: Style.space(4)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  // Away Team Row (Anchored to prevent score overflow)
                  Item {
                    width: parent.width
                    height: Style.space(16)

                    Image {
                      id: awayLogoImg
                      width: Style.space(15)
                      height: width
                      source: mCard.modelData ? (mCard.modelData.awayLogo || "") : ""
                      fillMode: Image.PreserveAspectFit
                      sourceSize.width: 48
                      sourceSize.height: 48
                      mipmap: true
                      smooth: true
                      asynchronous: true
                      cache: true
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      visible: status === Image.Ready
                    }

                    Row {
                      id: awayScoreRow
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(3)

                      Text {
                        textFormat: Text.PlainText
                        visible: !!(mCard.modelData && mCard.modelData.hasTwoLegs)
                        text: mCard.modelData ? (mCard.modelData.awayLeg1 || "—") : "—"
                        color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.4)
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.space(7.5)
                        width: Style.space(11)
                        horizontalAlignment: Text.AlignRight
                      }

                      Text {
                        textFormat: Text.PlainText
                        visible: !!(mCard.modelData && mCard.modelData.hasTwoLegs)
                        text: mCard.modelData ? (mCard.modelData.awayLeg2 || "—") : "—"
                        color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.4)
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.space(7.5)
                        width: Style.space(11)
                        horizontalAlignment: Text.AlignRight
                      }

                      Rectangle {
                        visible: !!(mCard.modelData && mCard.modelData.hasTwoLegs)
                        width: Style.spacing.hairline
                        height: Style.space(9)
                        color: root ? root.contentForeground : Color.foreground
                        opacity: 0.2
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Text {
                        textFormat: Text.PlainText
                        text: mCard.modelData ? (mCard.modelData.awayAgg !== undefined && mCard.modelData.awayAgg !== "" ? mCard.modelData.awayAgg : (mCard.modelData.awayScore || "")) : ""
                        color: (mCard.modelData && bracketView.isTeamAdvancing(mCard.modelData.winner, mCard.modelData.awayName))
                          ? "#4ade80" : (root ? root.contentForeground : Color.foreground)
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.space(8.5)
                        font.bold: true
                        width: Style.space(13)
                        horizontalAlignment: Text.AlignRight
                      }
                    }

                    Text {
                      id: awayNameTxt
                      textFormat: Text.PlainText
                      text: mCard.modelData ? (mCard.modelData.awayName || "TBD") : "TBD"
                      color: (mCard.modelData && bracketView.isTeamAdvancing(mCard.modelData.winner, mCard.modelData.awayName))
                        ? "#4ade80" : (root ? root.contentForeground : Color.foreground)
                      font.family: root ? root.contentFontFamily : Style.font.family
                      font.pixelSize: Style.space(8)
                      font.bold: !!(mCard.modelData && (mCard.modelData.isCurrent || bracketView.isTeamAdvancing(mCard.modelData.winner, mCard.modelData.awayName)))
                      elide: Text.ElideRight
                      anchors.left: awayLogoImg.right
                      anchors.leftMargin: Style.space(4)
                      anchors.right: awayScoreRow.left
                      anchors.rightMargin: Style.space(4)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  // Who advanced status text (with first two words like "2nd Leg -" stripped)
                  Text {
                    id: statusTxt
                    textFormat: Text.PlainText
                    text: {
                      var raw = (mCard.modelData && mCard.modelData.statusText) ? String(mCard.modelData.statusText) : ""
                      return raw.replace(/^[0-9]+(st|nd|rd|th)\s+leg\s*[-–]?\s*/i, "").trim()
                    }
                    color: Qt.darker(root ? root.contentForeground : Color.foreground, 1.4)
                    font.family: root ? root.contentFontFamily : Style.font.family
                    font.pixelSize: Style.space(7)
                    visible: text !== "" && !(mCard.modelData && mCard.modelData.isCurrent)
                    elide: Text.ElideRight
                    width: parent.width
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Horizontal Scroll Progress Indicator Bar
  Item {
    width: parent.width
    height: Style.space(4)
    visible: bracketFlickable.contentWidth > bracketFlickable.width

    Rectangle {
      anchors.fill: parent
      radius: 2
      color: Util.alpha(root ? root.contentForeground : Color.foreground, 0.08)
    }

    Rectangle {
      height: parent.height
      radius: 2
      color: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : Color.accent
      width: Math.max(Style.space(24), parent.width * (bracketFlickable.width / Math.max(1, bracketFlickable.contentWidth)))
      x: Math.max(0, Math.min(parent.width - width, (bracketFlickable.contentX / Math.max(1, bracketFlickable.contentWidth - bracketFlickable.width)) * (parent.width - width)))
    }
  }
}
