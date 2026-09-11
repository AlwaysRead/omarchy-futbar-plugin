import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

Column {
  id: profileDedicatedView
  property var root: null
  width: parent ? parent.width : 0
  spacing: Style.space(12)
  visible: root && (root.selectedPlayerProfile !== null || root.selectedClubProfile !== null)

          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              height: Math.max(profileBackButton.implicitHeight, profileBreadcrumbRow.implicitHeight, Style.space(26))

              Button {
                id: profileBackButton
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(26)
                iconText: ""
                text: "Back"
                tooltipText: root.profileNavBackLabel
                fontFamily: root.contentFontFamily
                foreground: root.contentForeground
                accent: root.favoriteTeamAccent
                fontSize: Style.font.caption
                iconSize: Style.space(10)
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(2)
                onClicked: root.navigateBackFromProfile()
              }

              // Breadcrumb Navigation (right-aligned, constrained within panel)
              Row {
                id: profileBreadcrumbRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                MouseArea {
                  id: bSearchArea
                  width: bSearchText.implicitWidth
                  height: bSearchText.implicitHeight
                  anchors.verticalCenter: parent.verticalCenter
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  onClicked: {
                    root.clubProfileHistory = null
                    root.selectedPlayerProfile = null
                    root.selectedClubProfile = null
                    root.resetPanelScroll()
                  }
                  Text {
                    id: bSearchText
                    text: "Search"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption - 1
                    color: bSearchArea.containsMouse ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.5)
                    font.bold: true
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "›"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption - 1
                  color: Qt.darker(root.contentForeground, 1.9)
                }

                MouseArea {
                  id: bClubHistArea
                  visible: root.clubProfileHistory !== null
                  width: visible ? bClubHistText.implicitWidth : 0
                  height: bClubHistText.implicitHeight
                  anchors.verticalCenter: parent.verticalCenter
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  onClicked: {
                    root.selectedClubProfile = root.clubProfileHistory
                    root.clubProfileHistory = null
                    root.selectedPlayerProfile = null
                    root.searchClubCardTab = "overview"
                    root.resetPanelScroll()
                  }
                  Text {
                    id: bClubHistText
                    text: root.clubProfileHistory ? (root.clubProfileHistory.displayName || root.clubProfileHistory.shortDisplayName || "Club") : ""
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption - 1
                    color: bClubHistArea.containsMouse ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.5)
                    font.bold: true
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, Style.space(70))
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "›"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption - 1
                  color: Qt.darker(root.contentForeground, 1.9)
                  visible: root.clubProfileHistory !== null
                }

                Text {
                  id: bCurrentTargetText
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.selectedPlayerProfile ? (root.selectedPlayerProfile.shortName || root.selectedPlayerProfile.fullName) : (root.selectedClubProfile ? (root.selectedClubProfile.shortDisplayName || root.selectedClubProfile.displayName) : "")
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                  color: root.favoriteTeamAccent
                  elide: Text.ElideRight
                  width: Math.min(implicitWidth, Math.max(Style.space(40), parent.width - profileBackButton.width - (bSearchArea.width + Style.space(24) + (root.clubProfileHistory ? (bClubHistArea.width + Style.space(16)) : 0))))
                }
              }
            }

            // Header Title
            Text {
              width: parent.width
              text: root.selectedPlayerProfile ? root.selectedPlayerProfile.fullName : (root.selectedClubProfile ? root.selectedClubProfile.displayName : "")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
            }
          }

          // Selected Player Card
          Column {
            width: parent.width
            spacing: Style.space(12)
            visible: root.selectedPlayerProfile !== null

            Rectangle {
              id: playerProfileHeaderCard
              width: parent.width
              height: playerProfileInnerCol.implicitHeight + Style.space(24)
              radius: Style.cornerRadius
              color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.65)
              clip: true
              readonly property color playerBrandColor: root.safeClubAccent("", root.favoriteTeamAccent)
              readonly property real brandLuminance: {
                var c = Qt.color(playerBrandColor)
                return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
              }
              readonly property real glowIntensity: brandLuminance > 0.70 ? 0.18 : 0.30
              border.width: Style.spacing.hairline
              border.color: Util.alpha(playerBrandColor, 0.20)

              // Subtle specular glass rim on top edge
              Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Style.space(1.5)
                radius: Style.cornerRadius
                color: Util.alpha(playerProfileHeaderCard.playerBrandColor, 0.40)
              }

              // Ambient brand glow banner (luminance-aware smooth natural fade)
              Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Style.space(128)
                gradient: Gradient {
                  GradientStop { position: 0.00; color: Util.alpha(playerProfileHeaderCard.playerBrandColor, playerProfileHeaderCard.glowIntensity) }
                  GradientStop { position: 0.25; color: Util.alpha(playerProfileHeaderCard.playerBrandColor, playerProfileHeaderCard.glowIntensity * 0.6) }
                  GradientStop { position: 0.50; color: Util.alpha(playerProfileHeaderCard.playerBrandColor, playerProfileHeaderCard.glowIntensity * 0.27) }
                  GradientStop { position: 0.75; color: Util.alpha(playerProfileHeaderCard.playerBrandColor, playerProfileHeaderCard.glowIntensity * 0.07) }
                  GradientStop { position: 1.00; color: "transparent" }
                }
              }

              // High-depth blurred club crest watermark (toned down & desaturated)
              Item {
                anchors.right: parent.right
                anchors.rightMargin: -Style.space(16)
                anchors.top: parent.top
                anchors.topMargin: -Style.space(6)
                width: Style.space(145)
                height: width
                opacity: 0.12
                visible: root.selectedPlayerProfile && root.selectedPlayerProfile.teamCrest !== ""

                Image {
                  id: playerWatermarkImg
                  anchors.fill: parent
                  source: root.selectedPlayerProfile ? root.selectedPlayerProfile.teamCrest : ""
                  fillMode: Image.PreserveAspectFit
                  mipmap: true
                  smooth: true
                  visible: false
                }

                MultiEffect {
                  anchors.fill: parent
                  source: playerWatermarkImg
                  blurEnabled: true
                  blur: 0.50
                  blurMax: 32
                  saturation: -0.75
                  colorization: 0.35
                  colorizationColor: playerProfileHeaderCard.playerBrandColor
                  autoPaddingEnabled: false
                }
              }

            Column {
              id: playerProfileInnerCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(12)
              spacing: Style.space(10)

              Row {
                width: parent.width
                spacing: Style.space(12)

                // Headshot with subtle backdrop circle
                // Headshot with clean circular clip (no placeholder behind when valid)
                Item {
                  width: Style.space(64)
                  height: width

                  readonly property bool hasHeadshot: root.selectedPlayerProfile && root.selectedPlayerProfile.headshot && String(root.selectedPlayerProfile.headshot) !== "" && playerHeadshotImg.status === Image.Ready

                  // Placeholder avatar shown ONLY when player has NO headshot or while failing
                  Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Util.alpha(root.contentForeground, 0.06)
                    border.width: Style.spacing.hairline
                    border.color: Util.alpha(root.contentForeground, 0.15)
                    visible: !parent.hasHeadshot

                    Text {
                      anchors.centerIn: parent
                      text: ""
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.space(32)
                      color: Util.alpha(root.contentForeground, 0.25)
                    }
                  }

                  Image {
                    id: playerHeadshotImg
                    anchors.fill: parent
                    source: root.selectedPlayerProfile ? root.selectedPlayerProfile.headshot : ""
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    smooth: true
                    visible: String(source) !== "" && status === Image.Ready
                  }
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(78)
                  spacing: Style.space(3)

                  Row {
                    width: parent.width
                    spacing: Style.space(6)
                    Text {
                      text: root.selectedPlayerProfile ? root.selectedPlayerProfile.fullName : ""
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                      width: Math.min(implicitWidth, parent.width - (jerseyText.visible ? jerseyText.implicitWidth + parent.spacing : 0))
                    }
                    Text {
                      id: jerseyText
                      text: root.selectedPlayerProfile && root.selectedPlayerProfile.jersey !== "" ? ("#" + root.selectedPlayerProfile.jersey) : ""
                      color: root.favoriteTeamAccent
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      visible: text !== ""
                    }
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Item {
                      width: Style.space(20)
                      height: Style.space(16)
                      anchors.verticalCenter: parent.verticalCenter
                      visible: !!(root.selectedPlayerProfile && root.selectedPlayerProfile.teamCrest && root.selectedPlayerProfile.teamCrest !== "")

                      Image {
                        anchors.centerIn: parent
                        width: Style.space(16)
                        height: Style.space(16)
                        source: root.selectedPlayerProfile ? root.selectedPlayerProfile.teamCrest : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(128, 128)
                        mipmap: true
                        smooth: true
                      }
                    }

                    Text {
                      width: Math.max(0, parent.width - Style.space(26))
                      text: {
                        if (!root.selectedPlayerProfile) return ""
                        var cName = root.selectedPlayerProfile.teamName || ""
                        var pos = root.selectedPlayerProfile.position || ""
                        return cName !== "" ? (pos !== "" ? (cName + " · " + pos) : cName) : pos
                      }
                      color: Qt.darker(root.contentForeground, 1.25)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      elide: Text.ElideRight
                      visible: text !== ""
                    }
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Item {
                      width: Style.space(20)
                      height: Style.space(16)
                      anchors.verticalCenter: parent.verticalCenter
                      visible: !!(root.selectedPlayerProfile && root.selectedPlayerProfile.flag && root.selectedPlayerProfile.flag !== "")

                      Image {
                        anchors.centerIn: parent
                        width: Style.space(20)
                        height: Style.space(14)
                        source: root.selectedPlayerProfile ? root.selectedPlayerProfile.flag : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(120, 80)
                        mipmap: true
                        smooth: true
                      }
                    }

                    Text {
                      width: Math.max(0, parent.width - Style.space(26))
                      text: {
                        if (!root.selectedPlayerProfile) return ""
                        var nat = root.selectedPlayerProfile.citizenship || ""
                        var st = root.selectedPlayerProfile.status || ""
                        return nat !== "" ? (st !== "" ? (nat + " · " + st) : nat) : st
                      }
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      visible: text !== ""
                    }
                  }
                }
              }

              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: Util.alpha(root.contentForeground, 0.12)
              }

              // Player Card Tabs: Info | Stats | Matches
              Row {
                width: parent.width
                spacing: Style.space(4)

                Button {
                  height: Style.space(20)
                  fontSize: Style.space(9)
                  horizontalPadding: Style.space(8)
                  verticalPadding: 0
                  text: "Info"
                  selected: root.searchPlayerCardTab === "info"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.searchPlayerCardTab = "info"
                }
                Button {
                  height: Style.space(20)
                  fontSize: Style.space(9)
                  horizontalPadding: Style.space(8)
                  verticalPadding: 0
                  text: "Stats"
                  selected: root.searchPlayerCardTab === "stats"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: { root.searchPlayerCardTab = "stats"; root.ensurePlayerStats(); root.ensureClubNames() }
                }
                Button {
                  height: Style.space(20)
                  fontSize: Style.space(9)
                  horizontalPadding: Style.space(8)
                  verticalPadding: 0
                  text: "Matches"
                  selected: root.searchPlayerCardTab === "matches"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.searchPlayerCardTab = "matches"
                }
              }

              // Bio Stats Card
              Rectangle {
                width: parent.width
                height: bioGridCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: root.searchPlayerCardTab === "info"

                Column {
                  id: bioGridCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Column {
                      width: (parent.width - Style.space(12)) / 3
                      spacing: Style.space(2)
                      Text { text: "AGE"; font.pixelSize: Style.space(9); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text { text: root.selectedPlayerProfile && root.selectedPlayerProfile.age !== "" ? root.selectedPlayerProfile.age : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 3
                      spacing: Style.space(2)
                      Text { text: "HEIGHT"; font.pixelSize: Style.space(9); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text { text: root.selectedPlayerProfile && root.selectedPlayerProfile.displayHeight !== "" ? root.selectedPlayerProfile.displayHeight : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 3
                      spacing: Style.space(2)
                      Text { text: "WEIGHT"; font.pixelSize: Style.space(9); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text { text: root.selectedPlayerProfile && root.selectedPlayerProfile.displayWeight !== "" ? root.selectedPlayerProfile.displayWeight : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                    }
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(6)
                    visible: !!(root.selectedPlayerProfile && (root.selectedPlayerProfile.dateOfBirth !== "" || root.selectedPlayerProfile.birthplace !== ""))

                    Column {
                      width: (parent.width - Style.space(6)) / 2
                      spacing: Style.space(2)
                      visible: !!(root.selectedPlayerProfile && root.selectedPlayerProfile.dateOfBirth !== "")
                      Text { text: "BORN"; font.pixelSize: Style.space(9); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text { text: (root.selectedPlayerProfile && root.selectedPlayerProfile.dateOfBirth) ? String(root.selectedPlayerProfile.dateOfBirth) : ""; font.pixelSize: Style.font.caption; color: root.contentForeground; font.family: root.contentFontFamily; elide: Text.ElideRight }
                    }

                    Column {
                      width: (parent.width - Style.space(6)) / 2
                      spacing: Style.space(2)
                      visible: !!(root.selectedPlayerProfile && root.selectedPlayerProfile.birthplace !== "")
                      Text { text: "BIRTHPLACE"; font.pixelSize: Style.space(9); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text { text: (root.selectedPlayerProfile && root.selectedPlayerProfile.birthplace) ? String(root.selectedPlayerProfile.birthplace) : ""; font.pixelSize: Style.font.caption; color: root.contentForeground; font.family: root.contentFontFamily; elide: Text.ElideRight }
                    }
                  }
                }
              }

              // Recent Match Log & Form (Last 5 Games)
              Rectangle {
                width: parent.width
                height: playerMatchesCol.implicitHeight + Style.space(20)
                radius: Style.space(8)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: root.searchPlayerCardTab === "matches"

                Column {
                  id: playerMatchesCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(10)
                  spacing: Style.space(8)

                  Item {
                    width: parent.width
                    height: recentMatchesHeaderTitle.implicitHeight

                    Text {
                      id: recentMatchesHeaderTitle
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      text: "RECENT MATCHES"
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      font.letterSpacing: 0.5
                      color: Qt.darker(root.contentForeground, 1.3)
                      font.family: root.contentFontFamily
                    }
                  }

                  // If empty or loading
                  Text {
                    width: parent.width
                    text: root.searchPlayerOverviewRequest && root.searchPlayerOverviewRequest.running ? "Loading recent matches…" : "No recent matches available"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    color: Qt.darker(root.contentForeground, 1.6)
                    visible: !root.selectedPlayerProfile || !root.selectedPlayerProfile.recentMatches || root.selectedPlayerProfile.recentMatches.length === 0
                  }

                  // Match rows
                  Repeater {
                    model: root.selectedPlayerProfile ? root.selectedPlayerProfile.recentMatches : []
                    delegate: Rectangle {
                      width: parent.width
                      height: (modelData.leagueName && modelData.leagueName !== "") ? Style.space(64) : Style.space(52)
                      radius: Style.space(6)
                      color: Util.alpha(root.contentForeground, 0.035)
                      border.width: Style.spacing.hairline
                      border.color: Util.alpha(root.contentForeground, 0.08)

                      Column {
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        spacing: Style.space(3)

                        // Top line: League / Competition Name & Date
                        Item {
                          width: parent.width
                          height: Style.space(12)
                          visible: !!(modelData.leagueName && modelData.leagueName !== "")

                          Text {
                            anchors.left: parent.left
                            anchors.right: matchDateText.left
                            anchors.rightMargin: Style.space(6)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.leagueName || ""
                            color: Qt.darker(root.contentForeground, 1.55)
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption - 2
                            font.bold: true
                            elide: Text.ElideRight
                          }

                          Text {
                            id: matchDateText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.date || ""
                            color: Qt.darker(root.contentForeground, 1.7)
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption - 2
                            visible: text !== ""
                          }
                        }

                        // Match line: Team A vs Team B (left) and Score (right)
                        Item {
                          width: parent.width
                          height: Style.space(16)

                          Text {
                            id: matchScoreText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.score || "—"
                            color: root.contentForeground
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }

                          Text {
                            anchors.left: parent.left
                            anchors.right: matchScoreText.left
                            anchors.rightMargin: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.matchTitle || (modelData.opponentName ? ("vs " + modelData.opponentName) : "Match")
                            color: root.contentForeground
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            elide: Text.ElideRight
                          }
                        }

                        // Bottom line: Goals & Assists (left) and Player Rating (right)
                        Item {
                          width: parent.width
                          height: Style.space(16)

                          Row {
                            id: matchRatingRow
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(4)

                            Text {
                              anchors.verticalCenter: parent.verticalCenter
                              text: "Rating:"
                              color: Qt.darker(root.contentForeground, 1.4)
                              font.family: root.contentFontFamily
                              font.pixelSize: Style.font.caption - 1
                            }

                            Text {
                              anchors.verticalCenter: parent.verticalCenter
                              text: (modelData.rating && modelData.rating !== "" && modelData.rating !== "—") ? modelData.rating : "—"
                              color: (modelData.rating && modelData.rating !== "" && modelData.rating !== "—") ? root.ratingColor(modelData.rating) : Qt.darker(root.contentForeground, 1.4)
                              font.family: root.contentFontFamily
                              font.pixelSize: Style.font.caption - 1
                              font.bold: true
                            }
                          }

                          Row {
                            anchors.left: parent.left
                            anchors.right: matchRatingRow.left
                            anchors.rightMargin: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(6)

                            Text {
                              anchors.verticalCenter: parent.verticalCenter
                              text: "Goals: " + (modelData.goals !== undefined ? modelData.goals : "0")
                              color: parseInt(modelData.goals) > 0 ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.3)
                              font.family: root.contentFontFamily
                              font.pixelSize: Style.font.caption - 1
                              font.bold: parseInt(modelData.goals) > 0
                            }

                            Text {
                              anchors.verticalCenter: parent.verticalCenter
                              text: "·"
                              color: Qt.darker(root.contentForeground, 1.6)
                              font.pixelSize: Style.font.caption - 1
                            }

                            Text {
                              anchors.verticalCenter: parent.verticalCenter
                              text: "Assists: " + (modelData.assists !== undefined ? modelData.assists : "0")
                              color: parseInt(modelData.assists) > 0 ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.3)
                              font.family: root.contentFontFamily
                              font.pixelSize: Style.font.caption - 1
                              font.bold: parseInt(modelData.assists) > 0
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }

              // All-teams Career/Season Stats Card
              Rectangle {
                width: parent.width
                height: careerStatsCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: root.selectedPlayerProfile && (root.selectedPlayerProfile.careerAppearances !== "" || root.selectedPlayerProfile.careerGoals !== "" || root.selectedPlayerProfile.seasonAppearances !== "" || (root.selectedPlayerProfile.availableSeasons && root.selectedPlayerProfile.availableSeasons.length > 0)) && root.searchPlayerCardTab === "stats"

                Column {
                  id: careerStatsCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(6)

                  // Header Row: STATISTICS on Left, Season Navigator on Right
                  Item {
                    width: parent.width
                    height: Style.space(20)

                    Text {
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      text: "STATISTICS"
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                    }

                    // Season Year and Prev/Next Toggle Buttons (Right-aligned)
                    Row {
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(4)
                      visible: root.searchPlayerStatsTab !== "career" && !!(root.selectedPlayerProfile && root.selectedPlayerProfile.availableSeasons && root.selectedPlayerProfile.availableSeasons.length > 0)

                      // Older Season (◀)
                      Button {
                        height: Style.space(20)
                        fontSize: Style.space(8)
                        horizontalPadding: Style.space(6)
                        verticalPadding: 0
                        text: "◀"
                        enabled: root.selectedPlayerProfile && root.selectedPlayerProfile.availableSeasons && ((root.selectedPlayerProfile.selectedSeasonIndex || 0) < (root.selectedPlayerProfile.availableSeasons.length - 1))
                        opacity: enabled ? 1.0 : 0.35
                        fontFamily: root.contentFontFamily
                        foreground: root.contentForeground
                        accent: root.contentForeground
                        onClicked: root.changePlayerSeason(1)
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                          var prof = root.selectedPlayerProfile
                          if (!prof || !prof.availableSeasons || prof.availableSeasons.length === 0) return ""
                          var sIdx = prof.selectedSeasonIndex || 0
                          var s = prof.availableSeasons[sIdx]
                          return s ? (s.seasonYear || String(s.year)) : ""
                        }
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.favoriteTeamAccent
                        font.family: root.contentFontFamily
                      }

                      // Newer Season (▶)
                      Button {
                        height: Style.space(20)
                        fontSize: Style.space(8)
                        horizontalPadding: Style.space(6)
                        verticalPadding: 0
                        text: "▶"
                        enabled: root.selectedPlayerProfile && (root.selectedPlayerProfile.selectedSeasonIndex || 0) > 0
                        opacity: enabled ? 1.0 : 0.35
                        fontFamily: root.contentFontFamily
                        foreground: root.contentForeground
                        accent: root.contentForeground
                        onClicked: root.changePlayerSeason(-1)
                      }
                    }
                  }

                  // Filter Row: All Stats | Club | Country | Tournament | Career
                  Row {
                    width: parent.width
                    spacing: Style.space(4)

                    Button {
                      height: Style.space(20)
                      fontSize: Style.space(8)
                      horizontalPadding: Style.space(6)
                      verticalPadding: 0
                      text: "All Stats"
                      selected: root.searchPlayerStatsTab === "all"
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.contentForeground
                      onClicked: root.setPlayerStatsTab("all")
                    }

                    Button {
                      height: Style.space(20)
                      fontSize: Style.space(8)
                      horizontalPadding: Style.space(6)
                      verticalPadding: 0
                      text: "Club"
                      selected: root.searchPlayerStatsTab === "club"
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.contentForeground
                      onClicked: root.setPlayerStatsTab("club")
                    }

                    Button {
                      height: Style.space(20)
                      fontSize: Style.space(8)
                      horizontalPadding: Style.space(6)
                      verticalPadding: 0
                      text: "Country"
                      selected: root.searchPlayerStatsTab === "country"
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.contentForeground
                      onClicked: root.setPlayerStatsTab("country")
                    }

                    Button {
                      height: Style.space(20)
                      fontSize: Style.space(8)
                      horizontalPadding: Style.space(6)
                      verticalPadding: 0
                      text: "Tournament"
                      selected: root.searchPlayerStatsTab === "tournament"
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.contentForeground
                      onClicked: root.setPlayerStatsTab("tournament")
                    }

                    Button {
                      height: Style.space(20)
                      fontSize: Style.space(8)
                      horizontalPadding: Style.space(6)
                      verticalPadding: 0
                      text: "Career"
                      selected: root.searchPlayerStatsTab === "career"
                      fontFamily: root.contentFontFamily
                      foreground: root.contentForeground
                      accent: root.contentForeground
                      onClicked: root.setPlayerStatsTab("career")
                    }
                  }

                  // Tournament selector row (visible when Tournament filter is selected)
                  Item {
                    id: tournamentRowContainer
                    width: parent.width
                    height: Style.space(24)
                    visible: root.searchPlayerStatsTab === "tournament" && root.currentSeasonComps().length > 0
                    clip: true

                    Flickable {
                      id: tournamentFlick
                      anchors.fill: parent
                      contentWidth: tournamentRow.implicitWidth
                      contentHeight: height
                      boundsBehavior: Flickable.StopAtBounds
                      flickableDirection: Flickable.HorizontalFlick

                      Row {
                        id: tournamentRow
                        spacing: Style.space(4)

                        Repeater {
                          model: root.currentSeasonComps()
                          delegate: Button {
                            height: Style.space(20)
                            fontSize: Style.space(8)
                            horizontalPadding: Style.space(6)
                            verticalPadding: 0
                            text: modelData.shortName || modelData.leagueName || modelData.league
                            selected: (root.selectedPlayerProfile && (root.selectedPlayerProfile.selectedCompIndex || 0) === index)
                            fontFamily: root.contentFontFamily
                            foreground: root.contentForeground
                            accent: root.contentForeground
                            onClicked: root.selectPlayerTournament(index)
                          }
                        }
                      }
                    }
                  }

                  Item {
                    width: parent.width
                    height: Style.space(18)
                    visible: root.searchPlayerStatsTab === "tournament" && root.currentSeasonComps().length === 0
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "No tournament data for this season"
                      font.pixelSize: Style.space(8)
                      font.italic: true
                      color: Qt.darker(root.contentForeground, 1.8)
                      font.family: root.contentFontFamily
                    }
                  }

                  // Main 4 Stats row
                  Row {
                    width: parent.width
                    spacing: Style.space(4)

                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "APPS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.searchPlayerStatsTab !== "career" && root.selectedPlayerProfile.seasonAppearances !== undefined)
                          ? String(root.selectedPlayerProfile.seasonAppearances)
                          : ((root.selectedPlayerProfile && root.selectedPlayerProfile.careerAppearances) ? String(root.selectedPlayerProfile.careerAppearances) : "—")
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "GOALS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.searchPlayerStatsTab !== "career" && root.selectedPlayerProfile.seasonGoals !== undefined)
                          ? String(root.selectedPlayerProfile.seasonGoals)
                          : ((root.selectedPlayerProfile && root.selectedPlayerProfile.careerGoals) ? String(root.selectedPlayerProfile.careerGoals) : "—")
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.favoriteTeamAccent
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "ASSISTS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.searchPlayerStatsTab !== "career" && root.selectedPlayerProfile.seasonAssists !== undefined)
                          ? String(root.selectedPlayerProfile.seasonAssists)
                          : ((root.selectedPlayerProfile && root.selectedPlayerProfile.careerAssists) ? String(root.selectedPlayerProfile.careerAssists) : "—")
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text {
                        text: root.stat4Active().label
                        font.pixelSize: Style.space(8)
                        font.bold: true
                        color: Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                      }
                      Text {
                        text: root.stat4Active().value !== "" ? root.stat4Active().value : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                  }
                }
              }

              // Shot & Passing Efficiency Card
              Rectangle {
                width: parent.width
                height: playerEfficiencyCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: root.searchPlayerCardTab === "stats" && root.selectedPlayerProfile

                Column {
                  id: playerEfficiencyCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Text {
                    text: "SHOT & PASSING EFFICIENCY"
                    font.pixelSize: Style.space(9)
                    font.bold: true
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                  }

                  Row {
                    width: parent.width
                    spacing: Style.space(4)

                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "CONVERSION"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.goalConversionRate !== "") ? root.selectedPlayerProfile.goalConversionRate : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.favoriteTeamAccent
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "SHOT ACC."; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.shotAccuracy !== "") ? root.selectedPlayerProfile.shotAccuracy : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "LONG BALLS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.longBalls !== "") ? root.selectedPlayerProfile.longBalls : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "KEY PASSES"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.keyPasses !== "") ? root.selectedPlayerProfile.keyPasses : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                  }
                }
              }

              // Discipline & Workload Card
              Rectangle {
                width: parent.width
                height: playerDisciplineCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: root.searchPlayerCardTab === "stats" && root.selectedPlayerProfile

                Column {
                  id: playerDisciplineCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Text {
                    text: "DISCIPLINE & WORKLOAD"
                    font.pixelSize: Style.space(9)
                    font.bold: true
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                  }

                  // Row 1: Cards & Fouls
                  Row {
                    width: parent.width
                    spacing: Style.space(4)

                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "YELLOWS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.seasonYellowCards !== "") ? root.selectedPlayerProfile.seasonYellowCards : "0"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: "#eab308"
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "REDS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.seasonRedCards !== "") ? root.selectedPlayerProfile.seasonRedCards : "0"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: "#ef4444"
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "FOULS C/S"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.seasonFouls !== "") ? root.selectedPlayerProfile.seasonFouls : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(12)) / 4
                      spacing: Style.space(2)
                      Text { text: "SUBS (IN/OUT)"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && (root.selectedPlayerProfile.seasonSubIns !== "" || root.selectedPlayerProfile.seasonSubOuts !== ""))
                          ? ((root.selectedPlayerProfile.seasonSubIns || "0") + " / " + (root.selectedPlayerProfile.seasonSubOuts || "0"))
                          : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                  }

                  // Row 2: Minutes & Avg min/app
                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Column {
                      width: (parent.width - Style.space(6)) / 2
                      spacing: Style.space(2)
                      Text { text: "TOTAL SEASON MINUTES"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.seasonMinutes) ? (root.selectedPlayerProfile.seasonMinutes + " mins") : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                      }
                    }
                    Column {
                      width: (parent.width - Style.space(6)) / 2
                      spacing: Style.space(2)
                      Text { text: "MINS PER APPEARANCE"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                      Text {
                        text: (root.selectedPlayerProfile && root.selectedPlayerProfile.seasonMinPerApp) ? (root.selectedPlayerProfile.seasonMinPerApp + " min/app") : "—"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.favoriteTeamAccent
                        font.family: root.contentFontFamily
                      }
                    }
                  }
                }
              }


              // International & National Team Caps Card
              Rectangle {
                width: parent.width
                height: natTeamsCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: !!(root.searchPlayerCardTab === "info" && root.selectedPlayerProfile && ((root.selectedPlayerProfile.nationalTeams && root.selectedPlayerProfile.nationalTeams.length > 0) || (root.selectedPlayerProfile.flag && root.selectedPlayerProfile.flag !== "") || (root.selectedPlayerProfile.citizenship && root.selectedPlayerProfile.citizenship !== "")))

                Column {
                  id: natTeamsCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(6)

                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "󰝨"
                      font.pixelSize: Style.space(10)
                      font.family: "Symbols Nerd Font, " + root.contentFontFamily
                      color: root.favoriteTeamAccent
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "INTERNATIONAL / NATIONAL TEAMS"
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                    }
                  }

                  // National Team Entries
                  Repeater {
                    model: (root.selectedPlayerProfile && root.selectedPlayerProfile.nationalTeams && root.selectedPlayerProfile.nationalTeams.length > 0)
                      ? root.selectedPlayerProfile.nationalTeams
                      : (root.selectedPlayerProfile && root.selectedPlayerProfile.citizenship !== "" ? [{
                          name: root.selectedPlayerProfile.citizenship,
                          type: "Senior National Team",
                          isYouth: false,
                          seasons: "",
                          seasonCount: "",
                          logo: root.selectedPlayerProfile.flag
                        }] : [])
                    delegate: Row {
                      width: parent.width
                      height: Style.space(24)
                      spacing: Style.space(6)

                      Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(24)
                        height: Style.space(16)
                        source: modelData.logo || ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(120, 80)
                        mipmap: true
                        smooth: true
                        visible: String(source) !== ""
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name || "National Team"
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, parent.width - Style.space(130))
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.isYouth ? "Youth" : "Senior"
                        font.pixelSize: Style.space(8)
                        font.bold: true
                        color: modelData.isYouth ? Qt.darker(root.contentForeground, 1.4) : root.favoriteTeamAccent
                        font.family: root.contentFontFamily
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(65)
                        horizontalAlignment: Text.AlignRight
                        text: modelData.seasons || (modelData.seasonCount ? (modelData.seasonCount + " yrs") : "")
                        color: Qt.darker(root.contentForeground, 1.6)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(9)
                        elide: Text.ElideRight
                        visible: text !== ""
                      }
                    }
                  }
                }
              }

              // Career Clubs Segmented Card (Vertical Column)
              Rectangle {
                width: parent.width
                height: careerClubsCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: !!(root.selectedPlayerProfile && root.selectedPlayerProfile.careerHistory && root.selectedPlayerProfile.careerHistory.length > 0 && root.searchPlayerCardTab === "info")

                Column {
                  id: careerClubsCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(6)

                  Text {
                    text: "CAREER CLUBS"
                    font.pixelSize: Style.space(9)
                    font.bold: true
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                  }

                  Column {
                    width: parent.width
                    spacing: Style.space(6)

                    Repeater {
                      model: root.selectedPlayerProfile ? root.selectedPlayerProfile.careerHistory : []
                      delegate: Item {
                        width: parent.width
                        height: Style.space(22)

                        Row {
                          anchors.left: parent.left
                          anchors.right: clubYearsText.left
                          anchors.rightMargin: Style.space(8)
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: Style.space(8)

                          Image {
                            width: Style.space(18)
                            height: width
                            anchors.verticalCenter: parent.verticalCenter
                            source: modelData.teamLogo
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            smooth: true
                            visible: String(source) !== ""
                          }

                          Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (String(modelData.teamLogo || "") !== "" ? Style.space(26) : 0)
                            text: ((modelData.name && modelData.name !== "") ? modelData.name : ((root.teamNameCache && root.teamNameCache[modelData.teamId]) ? root.teamNameCache[modelData.teamId] : "Club"))
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption
                            color: root.contentForeground
                            font.bold: true
                            elide: Text.ElideRight
                          }
                        }

                        Text {
                          id: clubYearsText
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          text: modelData.years || ""
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption - 1
                          color: Qt.darker(root.contentForeground, 1.45)
                          font.bold: true
                        }
                      }
                    }
                  }
                }
              }

              // Transfer History Card
              Rectangle {
                width: parent.width
                height: transferHistoryCol.implicitHeight + Style.space(16)
                radius: Style.space(6)
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: root.selectedPlayerProfile && root.selectedPlayerProfile.transferHistory && root.selectedPlayerProfile.transferHistory.length > 0 && root.searchPlayerCardTab === "info"

                Column {
                  id: transferHistoryCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "⇆"
                      font.pixelSize: Style.space(10)
                      font.family: root.contentFontFamily
                      color: root.favoriteTeamAccent
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "TRANSFER HISTORY"
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "(" + (root.selectedPlayerProfile && root.selectedPlayerProfile.transferHistory ? root.selectedPlayerProfile.transferHistory.length : 0) + ")"
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      color: Qt.darker(root.contentForeground, 1.8)
                      font.family: root.contentFontFamily
                    }
                  }

                  Column {
                    width: parent.width
                    spacing: Style.space(6)

                    Repeater {
                      model: root.selectedPlayerProfile ? root.selectedPlayerProfile.transferHistory : []
                      delegate: Rectangle {
                        id: transferItemRect
                        width: parent.width
                        height: Style.space(26)
                        radius: Style.space(4)
                        color: Util.alpha(root.contentForeground, 0.03)
                        border.width: Style.spacing.hairline
                        border.color: Util.alpha(root.contentForeground, 0.06)

                        MouseArea {
                          id: transferMouseArea
                          anchors.fill: parent
                          hoverEnabled: true
                        }

                        ToolTip {
                          visible: transferMouseArea.containsMouse
                          delay: 350
                          timeout: 4000
                          text: (modelData.fromName || "Unknown") + " → " + (modelData.toName || "Unknown") + " : " + modelData.fee + (modelData.date ? (" (" + modelData.date + ")") : "")
                        }

                        Row {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(6)
                          anchors.rightMargin: Style.space(6)
                          spacing: Style.space(5)

                          Text {
                            id: transferDateText
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.year || modelData.date || "—"
                            font.pixelSize: Style.space(9)
                            font.bold: true
                            color: root.favoriteTeamAccent
                            font.family: root.contentFontFamily
                          }

                          Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: (source && String(source) !== "") ? Style.space(14) : 0
                            height: width
                            source: modelData.fromLogo || ""
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            smooth: true
                            visible: String(source) !== ""
                          }

                          Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.fromName || "Unknown"
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            color: root.contentForeground
                            font.family: root.contentFontFamily
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: Math.min(implicitWidth, Math.max(Style.space(40), (parent.width - transferDateText.implicitWidth - feeText.implicitWidth - Style.space(56)) / 2))
                          }

                          Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "→"
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            color: root.favoriteTeamAccent
                            font.family: root.contentFontFamily
                          }

                          Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: (source && String(source) !== "") ? Style.space(14) : 0
                            height: width
                            source: modelData.toLogo || ""
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            smooth: true
                            visible: String(source) !== ""
                          }

                          Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.toName || "Unknown"
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            color: root.contentForeground
                            font.family: root.contentFontFamily
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: Math.min(implicitWidth, Math.max(Style.space(40), (parent.width - transferDateText.implicitWidth - feeText.implicitWidth - Style.space(56)) / 2))
                          }

                          Text {
                            id: feeText
                            anchors.verticalCenter: parent.verticalCenter
                            text: " : " + modelData.fee
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            color: (modelData.type === "Fee" || (modelData.rawAmount > 0)) ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.25)
                            font.family: root.contentFontFamily
                          }
                        }
                      }
                    }
                  }
                }
              }
              Button {
                width: parent.width
                iconText: "󰖟"
                text: "View Career Profile on ESPN"
                fontFamily: root.contentFontFamily
                foreground: root.contentForeground
                accent: root.contentForeground
                fontSize: Style.font.caption
                iconSize: Style.font.caption
                horizontalPadding: Style.space(8)
                verticalPadding: Style.space(4)
                visible: root.selectedPlayerProfile && root.selectedPlayerProfile.webUrl !== ""
                onClicked: {
                  if (root.selectedPlayerProfile && root.selectedPlayerProfile.webUrl !== "") {
                    Qt.openUrlExternally(root.selectedPlayerProfile.webUrl)
                  }
                }
              }
            }
          }
        }

        // Selected Club Card
        Column {
          width: parent.width
          spacing: Style.space(12)
          visible: root.selectedClubProfile !== null

          Rectangle {
            id: clubProfileHeaderCard
            width: parent.width
            height: clubProfileInnerCol.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.65)
            clip: true
            readonly property color clubBrandColor: root.safeClubAccent(root.selectedClubProfile ? root.selectedClubProfile.color : "", root.favoriteTeamAccent)
            readonly property real brandLuminance: {
              var c = Qt.color(clubBrandColor)
              return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
            }
            readonly property real glowIntensity: brandLuminance > 0.70 ? 0.18 : 0.30
            border.width: Style.spacing.hairline
            border.color: Util.alpha(clubBrandColor, 0.20)

            // Subtle specular glass rim on top edge
            Rectangle {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              height: Style.space(1.5)
              radius: Style.cornerRadius
              color: Util.alpha(clubProfileHeaderCard.clubBrandColor, 0.40)
            }

            // Ambient brand glow banner (luminance-aware smooth natural fade)
            Rectangle {
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              height: Style.space(128)
              gradient: Gradient {
                GradientStop { position: 0.00; color: Util.alpha(clubProfileHeaderCard.clubBrandColor, clubProfileHeaderCard.glowIntensity) }
                GradientStop { position: 0.25; color: Util.alpha(clubProfileHeaderCard.clubBrandColor, clubProfileHeaderCard.glowIntensity * 0.6) }
                GradientStop { position: 0.50; color: Util.alpha(clubProfileHeaderCard.clubBrandColor, clubProfileHeaderCard.glowIntensity * 0.27) }
                GradientStop { position: 0.75; color: Util.alpha(clubProfileHeaderCard.clubBrandColor, clubProfileHeaderCard.glowIntensity * 0.07) }
                GradientStop { position: 1.00; color: "transparent" }
              }
            }

            // High-depth blurred club crest watermark (toned down, desaturated to prevent multi-color bleed)
            Item {
              anchors.right: parent.right
              anchors.rightMargin: -Style.space(16)
              anchors.top: parent.top
              anchors.topMargin: -Style.space(6)
              width: Style.space(145)
              height: width
              opacity: 0.12
              visible: !!(root.selectedClubProfile && root.selectedClubProfile.logo)

              Image {
                id: clubWatermarkImg
                anchors.fill: parent
                source: (root.selectedClubProfile && root.selectedClubProfile.logo) ? root.selectedClubProfile.logo : ""
                fillMode: Image.PreserveAspectFit
                mipmap: true
                smooth: true
                visible: false
              }

              MultiEffect {
                anchors.fill: parent
                source: clubWatermarkImg
                blurEnabled: true
                blur: 0.50
                blurMax: 32
                saturation: -0.75
                colorization: 0.35
                colorizationColor: clubProfileHeaderCard.clubBrandColor
                autoPaddingEnabled: false
              }
            }

            // Top-Right Action: Pin / Favorite Club Badge
            Item {
              id: clubProfileFavBtn
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.margins: Style.space(10)
              width: Style.space(26)
              height: width
              z: 10

              readonly property bool isPrimaryFav: {
                if (!root.selectedClubProfile) return false
                var pKey = root.primaryItemKey()
                var cId = String(root.selectedClubProfile.id || "")
                var cName = String(root.selectedClubProfile.displayName || "").toLowerCase()
                var cKey = root.itemKey(cName, root.selectedClubProfile.leagueSlug || "", false)
                return pKey === cKey || (cId !== "" && pKey.indexOf(cId) !== -1)
              }

              readonly property bool isFollowedFav: {
                if (!root.selectedClubProfile) return false
                if (isPrimaryFav) return true
                var cId = String(root.selectedClubProfile.id || "")
                var cName = String(root.selectedClubProfile.displayName || "").toLowerCase()
                var list = root.allFollowedTabs()
                for (var i = 0; i < list.length; i++) {
                  var t = list[i]
                  if (t.followLeague) continue
                  if (cId !== "" && String(t.teamId || "") === cId) return true
                  if (cName !== "" && t.teamName && t.teamName.toLowerCase() === cName) return true
                }
                return false
              }

              Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: clubProfileFavBtn.isPrimaryFav
                  ? Util.alpha(clubProfileHeaderCard.clubBrandColor, 0.20)
                  : (clubProfileFavBtn.isFollowedFav
                    ? Util.alpha(root.contentForeground, 0.12)
                    : (favMouse.containsMouse ? Util.alpha(root.contentForeground, 0.08) : "transparent"))
                border.width: Style.spacing.hairline
                border.color: clubProfileFavBtn.isPrimaryFav
                  ? Util.alpha(clubProfileHeaderCard.clubBrandColor, 0.40)
                  : (clubProfileFavBtn.isFollowedFav ? Util.alpha(root.contentForeground, 0.20) : Util.alpha(root.contentForeground, 0.08))
                Behavior on color { ColorAnimation { duration: 150 } }
              }

              Text {
                anchors.centerIn: parent
                text: clubProfileFavBtn.isPrimaryFav ? "" : ""
                font.family: "Symbols Nerd Font, " + root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                color: clubProfileFavBtn.isPrimaryFav
                  ? "#f59e0b"
                  : (clubProfileFavBtn.isFollowedFav
                    ? clubProfileHeaderCard.clubBrandColor
                    : (favMouse.containsMouse ? root.contentForeground : Qt.darker(root.contentForeground, 1.5)))
                scale: favMouse.pressed ? 0.88 : (favMouse.containsMouse ? 1.12 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120 } }
              }

              MouseArea {
                id: favMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                  if (!root.selectedClubProfile) return
                  var dName = root.selectedClubProfile.displayName || ""
                  var lSlug = root.selectedClubProfile.leagueSlug || ""
                  var cId = root.selectedClubProfile.id || ""
                  if (mouse.button === Qt.RightButton) {
                    if (clubProfileFavBtn.isFollowedFav && (!clubProfileFavBtn.isPrimaryFav || root.allFollowedTabs().length > 1)) {
                      root.removeFollowedTeam(dName, lSlug)
                      root.notify("Club Unpinned", dName + " removed from followed tabs", "")
                    }
                    return
                  }
                  if (clubProfileFavBtn.isPrimaryFav) {
                    root.notify("Primary Club", dName + " is already your primary bar club", "")
                  } else if (clubProfileFavBtn.isFollowedFav) {
                    root.promoteToPrimary(dName, lSlug, cId, false)
                    root.notify("Primary Club Set", dName + " set as primary bar club", "")
                  } else {
                    root.addFollowedTeam(dName, lSlug, cId)
                    root.notify("Club Pinned", dName + " added to your followed tabs", "")
                  }
                }
              }
            }

            Column {
              id: clubProfileInnerCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(12)
              spacing: Style.space(10)

              // Header Row: Club Crest + Name + League & Meta Details
              Row {
                width: parent.width
                spacing: Style.space(12)

                // Club crest (prominent, clean, unboxed)
                Item {
                  id: clubCrestItem
                  width: Style.space(62)
                  height: width
                  anchors.verticalCenter: parent.verticalCenter

                  Image {
                    anchors.fill: parent
                    source: (root.selectedClubProfile && root.selectedClubProfile.logo) ? root.selectedClubProfile.logo : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(256, 256)
                    mipmap: true
                    smooth: true
                    visible: String(source) !== ""
                  }
                }

                // Club Info Column
                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Math.max(0, parent.width - clubCrestItem.width - parent.spacing - Style.space(32))
                  spacing: Style.space(3)

                  // Club Name + Abbreviation
                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                      text: (root.selectedClubProfile && root.selectedClubProfile.displayName) ? root.selectedClubProfile.displayName : ""
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                      width: Math.min(implicitWidth, parent.width - (abbrevText.visible ? abbrevText.implicitWidth + parent.spacing : 0))
                    }

                    Text {
                      id: abbrevText
                      text: (root.selectedClubProfile && root.selectedClubProfile.abbreviation) ? root.selectedClubProfile.abbreviation : ""
                      color: root.favoriteTeamAccent
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      visible: text !== ""
                    }
                  }

                  // Competition / Standing Summary line
                  Text {
                    width: parent.width
                    text: {
                      if (!root.selectedClubProfile) return ""
                      var base = ""
                      if (root.selectedClubProfile.standingSummary) base = root.selectedClubProfile.standingSummary
                      else if (root.selectedClubProfile.leagueSlug) base = root.leagueLabel(root.selectedClubProfile.leagueSlug)
                      else base = root.selectedClubProfile.leagueName || ""
                      if (root.selectedClubProfile.nickname && root.selectedClubProfile.nickname !== "") {
                        base = base !== "" ? (base + " · \"" + root.selectedClubProfile.nickname + "\"") : ("\"" + root.selectedClubProfile.nickname + "\"")
                      }
                      return base
                    }
                    color: Qt.darker(root.contentForeground, 1.25)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                    visible: text !== ""
                  }

                  // Meta details: Season Record, Stadium, Manager
                  Flow {
                    width: parent.width
                    spacing: Style.space(8)

                    // Season Record
                    Row {
                      spacing: Style.space(4)
                      visible: !!(root.selectedClubProfile && root.selectedClubProfile.record)
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Record:"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(9)
                        color: Qt.darker(root.contentForeground, 1.6)
                      }
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.selectedClubProfile && root.selectedClubProfile.record) ? root.selectedClubProfile.record : ""
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(9)
                        font.bold: true
                      }
                    }

                    // Venue / Stadium
                    Row {
                      spacing: Style.space(4)
                      visible: !!(root.selectedClubProfile && root.selectedClubProfile.venue)
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰿹"
                        font.family: "Symbols Nerd Font, " + root.contentFontFamily
                        font.pixelSize: Style.space(9)
                        color: Qt.darker(root.contentForeground, 1.6)
                      }
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.selectedClubProfile && root.selectedClubProfile.venue) ? root.selectedClubProfile.venue : ""
                        color: Qt.darker(root.contentForeground, 1.45)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(9)
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
              }

              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: Util.alpha(root.contentForeground, 0.12)
              }

              // Club Card Tabs: Overview | Squad | Fixtures
              Row {
                width: parent.width
                spacing: Style.space(4)

                Button {
                  height: Style.space(20)
                  fontSize: Style.space(9)
                  horizontalPadding: Style.space(8)
                  verticalPadding: 0
                  text: "Overview"
                  selected: root.searchClubCardTab === "overview"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.searchClubCardTab = "overview"
                }
                Button {
                  height: Style.space(20)
                  fontSize: Style.space(9)
                  horizontalPadding: Style.space(8)
                  verticalPadding: 0
                  text: "Squad"
                  selected: root.searchClubCardTab === "squad"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.searchClubCardTab = "squad"
                }
                Button {
                  height: Style.space(20)
                  fontSize: Style.space(9)
                  horizontalPadding: Style.space(8)
                  verticalPadding: 0
                  text: "Fixtures"
                  selected: root.searchClubCardTab === "fixtures"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.searchClubCardTab = "fixtures"
                }
              }

          Item {
            width: parent.width
            height: Style.space(20)
            visible: root.searchClubLoading
            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)
              Text {
                text: "󰑮"
                font.family: "Symbols Nerd Font, " + root.contentFontFamily
                font.pixelSize: Style.font.caption
                color: root.favoriteTeamAccent
                opacity: 0.5 + 0.5 * root._pulse
              }
              Text {
                text: "Updating stats & schedule…"
                font.family: root.contentFontFamily
                font.pixelSize: Style.space(9)
                color: Qt.darker(root.contentForeground, 1.6)
              }
            }
          }

          // ==================== OVERVIEW TAB ====================
          // Card 1: League Campaign & Standings (Unified, clean, no stacked boxes)
          Rectangle {
            width: parent.width
            height: standingsCol.implicitHeight + Style.space(18)
            radius: Style.cornerRadius
            color: Util.alpha(root.contentForeground, 0.035)
            border.width: Style.spacing.hairline
            border.color: Util.alpha(root.contentForeground, 0.08)
            visible: root.searchClubCardTab === "overview" && root.selectedClubProfile && (root.selectedClubProfile.points !== "" || root.selectedClubProfile.record !== "" || root.selectedClubProfile.form !== "")

            Column {
              id: standingsCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              // Header: League Title & Standing Summary
              Item {
                width: parent.width
                height: Style.space(14)

                Row {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)
                  width: parent.width * 0.42

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.selectedClubProfile && root.selectedClubProfile.leagueSlug) ? (root.leagueLabel(root.selectedClubProfile.leagueSlug).toUpperCase() + " STANDINGS") : "LEAGUE STANDINGS"
                    font.pixelSize: Style.space(9)
                    font.bold: true
                    font.letterSpacing: 0.5
                    color: Qt.darker(root.contentForeground, 1.3)
                    font.family: root.contentFontFamily
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - Style.space(42))
                  }

                  // Mini Table toggle button
                  MouseArea {
                    id: miniTableToggleArea
                    anchors.verticalCenter: parent.verticalCenter
                    width: miniTableToggleTxt.implicitWidth + Style.space(6)
                    height: Style.space(14)
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    visible: root.getClubStandingsSlice().length > 0
                    onClicked: root.clubStandingsExpanded = !root.clubStandingsExpanded

                    Text {
                      id: miniTableToggleTxt
                      anchors.centerIn: parent
                      text: root.clubStandingsExpanded ? "Hide" : "Table"
                      font.pixelSize: Style.space(8)
                      font.bold: true
                      color: miniTableToggleArea.containsMouse ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.6)
                      font.family: root.contentFontFamily
                    }
                  }
                }

                Text {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: {
                    if (!root.selectedClubProfile) return ""
                    var s = root.selectedClubProfile.standingSummary || ""
                    if (root.selectedClubProfile.rankChange && root.selectedClubProfile.rankChange !== "0") {
                      s = s !== "" ? (s + " (" + root.selectedClubProfile.rankChange + ")") : root.selectedClubProfile.rankChange
                    }
                    if (root.selectedClubProfile.gamesPlayed) {
                      s = s !== "" ? (s + " · " + root.selectedClubProfile.gamesPlayed + " GP") : (root.selectedClubProfile.gamesPlayed + " GP")
                    }
                    if (root.selectedClubProfile.ppg) {
                      s = s !== "" ? (s + " · " + root.selectedClubProfile.ppg + " PPG") : (root.selectedClubProfile.ppg + " PPG")
                    }
                    if (root.selectedClubProfile.deductions) {
                      s = s !== "" ? (s + " (" + root.selectedClubProfile.deductions + ")") : root.selectedClubProfile.deductions
                    }
                    return s
                  }
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  color: root.favoriteTeamAccent
                  font.family: root.contentFontFamily
                  elide: Text.ElideRight
                  width: parent.width * 0.56
                  horizontalAlignment: Text.AlignRight
                }
              }

              // Standings Table Row (PTS | W | D | L | DIFF | GF:GA)
              Row {
                width: parent.width
                spacing: Style.space(4)

                Column {
                  width: (parent.width - Style.space(20)) / 6
                  spacing: Style.space(2)
                  Text { text: "PTS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.points !== undefined && root.selectedClubProfile.points !== "") ? String(root.selectedClubProfile.points) : "0"; font.pixelSize: Style.font.body; font.bold: true; color: root.favoriteTeamAccent; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(20)) / 6
                  spacing: Style.space(2)
                  Text { text: "W"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.wins !== undefined && root.selectedClubProfile.wins !== "") ? String(root.selectedClubProfile.wins) : "0"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(20)) / 6
                  spacing: Style.space(2)
                  Text { text: "D"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.ties !== undefined && root.selectedClubProfile.ties !== "") ? String(root.selectedClubProfile.ties) : "0"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(20)) / 6
                  spacing: Style.space(2)
                  Text { text: "L"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.losses !== undefined && root.selectedClubProfile.losses !== "") ? String(root.selectedClubProfile.losses) : "0"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(20)) / 6
                  spacing: Style.space(2)
                  Text { text: "DIFF"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.diff !== undefined && root.selectedClubProfile.diff !== "") ? String(root.selectedClubProfile.diff) : "0"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(20)) / 6
                  spacing: Style.space(2)
                  Text { text: "GF:GA"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.goalsFor !== undefined && root.selectedClubProfile.goalsAgainst !== undefined && root.selectedClubProfile.goalsFor !== "") ? (root.selectedClubProfile.goalsFor + ":" + root.selectedClubProfile.goalsAgainst) : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
              }

              // Mini Table (Neighbors / Slice around club)
              Column {
                width: parent.width
                spacing: Style.space(2)
                visible: root.clubStandingsExpanded && root.getClubStandingsSlice().length > 0

                // Mini Table Header
                Row {
                  width: parent.width
                  height: Style.space(14)

                  Text { width: Style.space(22); text: "#"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.8); font.family: root.contentFontFamily }
                  Text { width: parent.width - Style.space(126); text: "CLUB"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.8); font.family: root.contentFontFamily }
                  Text { width: Style.space(24); text: "GP"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.8); font.family: root.contentFontFamily; horizontalAlignment: Text.AlignHCenter }
                  Text { width: Style.space(38); text: "W-D-L"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.8); font.family: root.contentFontFamily; horizontalAlignment: Text.AlignHCenter }
                  Text { width: Style.space(20); text: "GD"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.8); font.family: root.contentFontFamily; horizontalAlignment: Text.AlignRight }
                  Text { width: Style.space(22); text: "PTS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.8); font.family: root.contentFontFamily; horizontalAlignment: Text.AlignRight }
                }

                Repeater {
                  model: root.clubStandingsExpanded ? root.getClubStandingsSlice() : []
                  delegate: Rectangle {
                    id: miniTableRowRect
                    width: parent.width
                    height: Style.space(22)
                    radius: Style.space(3)
                    readonly property bool isSelectedClub: (root.selectedClubProfile && (String(modelData.id) === String(root.selectedClubProfile.id) || (modelData.name && root.selectedClubProfile.displayName && modelData.name.toLowerCase() === root.selectedClubProfile.displayName.toLowerCase())))
                    color: isSelectedClub ? Util.alpha(root.favoriteTeamAccent, 0.12) : (miniTableRowMouse.containsMouse ? Util.alpha(root.contentForeground, 0.05) : "transparent")

                    // Left qualification zone strip
                    Rectangle {
                      anchors.left: parent.left
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      width: Style.space(2.5)
                      radius: Style.space(1)
                      readonly property string zClr: root.standingsZoneColor(modelData)
                      color: zClr !== "" ? zClr : "transparent"
                    }

                    MouseArea {
                      id: miniTableRowMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: !miniTableRowRect.isSelectedClub ? Qt.PointingHandCursor : Qt.ArrowCursor
                      onClicked: {
                        if (!miniTableRowRect.isSelectedClub && modelData.id) {
                          root.openClubSearchDetail({
                            id: modelData.id,
                            displayName: modelData.name,
                            image: modelData.logo,
                            leagueSlug: root.selectedClubProfile.leagueSlug
                          })
                        }
                      }
                    }

                    Row {
                      anchors.fill: parent
                      anchors.leftMargin: Style.space(5)
                      anchors.rightMargin: Style.space(4)
                      anchors.verticalCenter: parent.verticalCenter

                      // Rank
                      Text {
                        width: Style.space(17)
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(modelData.rank)
                        font.pixelSize: Style.space(8)
                        font.bold: true
                        color: miniTableRowRect.isSelectedClub ? root.favoriteTeamAccent : Qt.darker(root.contentForeground, 1.5)
                        font.family: root.contentFontFamily
                      }

                      // Club Logo + Name
                      Row {
                        width: parent.width - Style.space(121)
                        height: parent.height
                        spacing: Style.space(5)
                        clip: true

                        Image {
                          anchors.verticalCenter: parent.verticalCenter
                          width: Style.space(14)
                          height: width
                          source: modelData.logo || ""
                          fillMode: Image.PreserveAspectFit
                          mipmap: true
                          smooth: true
                        }

                        Text {
                          anchors.verticalCenter: parent.verticalCenter
                          width: parent.width - Style.space(20)
                          text: modelData.name
                          font.pixelSize: Style.space(9)
                          font.bold: miniTableRowRect.isSelectedClub
                          color: miniTableRowRect.isSelectedClub ? root.favoriteTeamAccent : (miniTableRowMouse.containsMouse ? root.contentForeground : Qt.darker(root.contentForeground, 1.25))
                          font.family: root.contentFontFamily
                          elide: Text.ElideRight
                        }
                      }

                      // GP
                      Text {
                        width: Style.space(24)
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(modelData.gamesPlayed || "0")
                        font.pixelSize: Style.space(8)
                        color: Qt.darker(root.contentForeground, 1.4)
                        font.family: root.contentFontFamily
                        horizontalAlignment: Text.AlignHCenter
                      }

                      // W-D-L
                      Text {
                        width: Style.space(38)
                        anchors.verticalCenter: parent.verticalCenter
                        text: (modelData.wins || "0") + "-" + (modelData.ties || "0") + "-" + (modelData.losses || "0")
                        font.pixelSize: Style.space(8)
                        color: Qt.darker(root.contentForeground, 1.4)
                        font.family: root.contentFontFamily
                        horizontalAlignment: Text.AlignHCenter
                      }

                      // GD
                      Text {
                        width: Style.space(20)
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(modelData.diff || "0")
                        font.pixelSize: Style.space(8)
                        color: Qt.darker(root.contentForeground, 1.4)
                        font.family: root.contentFontFamily
                        horizontalAlignment: Text.AlignRight
                      }

                      // PTS
                      Text {
                        width: Style.space(22)
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(modelData.points || "0")
                        font.pixelSize: Style.space(9)
                        font.bold: true
                        color: miniTableRowRect.isSelectedClub ? root.favoriteTeamAccent : root.contentForeground
                        font.family: root.contentFontFamily
                        horizontalAlignment: Text.AlignRight
                      }
                    }
                  }
                }
              }

              // Divider between table and form/splits
              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: Util.alpha(root.contentForeground, 0.06)
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.form || root.selectedClubProfile.homeRecord || root.selectedClubProfile.awayRecord || root.selectedClubProfile.streak))
              }

              // Recent Form & Home / Away Splits Row (Clean typography, no box container)
              Item {
                width: parent.width
                implicitHeight: Math.max(formRow.implicitHeight, splitsRow.implicitHeight, Style.space(16))
                height: implicitHeight
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.form || root.selectedClubProfile.homeRecord || root.selectedClubProfile.awayRecord || root.selectedClubProfile.streak))

                // Left: Form badges
                Row {
                  id: formRow
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)
                  visible: !!(root.selectedClubProfile && root.selectedClubProfile.form)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "FORM"
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                  }

                  Repeater {
                    model: root.selectedClubProfile ? root.selectedClubProfile.form.split("") : []
                    delegate: Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(16)
                      height: width
                      radius: Style.space(3)
                      readonly property color badgeClr: modelData === "W" ? "#22c55e" : (modelData === "D" ? "#eab308" : "#ef4444")
                      color: Util.alpha(badgeClr, 0.18)

                      Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.bold: true
                        font.pixelSize: Style.space(8)
                        font.family: root.contentFontFamily
                        color: "#ffffff"
                      }
                    }
                  }
                }

                // Right: Home & Away Splits & Streak (clean inline text, no container box)
                Row {
                  id: splitsRow
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)
                  visible: !!(root.selectedClubProfile && (root.selectedClubProfile.homeRecord || root.selectedClubProfile.awayRecord || root.selectedClubProfile.streak))

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selectedClubProfile && root.selectedClubProfile.streak ? ("Streak: " + root.selectedClubProfile.streak) : ""
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    color: (root.selectedClubProfile && root.selectedClubProfile.streak && root.selectedClubProfile.streak.indexOf("W") !== -1) ? "#22c55e" : ((root.selectedClubProfile && root.selectedClubProfile.streak && root.selectedClubProfile.streak.indexOf("L") !== -1) ? "#ef4444" : root.favoriteTeamAccent)
                    font.family: root.contentFontFamily
                    visible: text !== ""
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "·"
                    font.pixelSize: Style.space(8)
                    color: Qt.darker(root.contentForeground, 1.8)
                    visible: !!(root.selectedClubProfile && root.selectedClubProfile.streak && (root.selectedClubProfile.homeRecord || root.selectedClubProfile.awayRecord))
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selectedClubProfile && root.selectedClubProfile.homeRecord ? ("Home: " + root.selectedClubProfile.homeRecord) : ""
                    font.pixelSize: Style.space(8)
                    color: Qt.darker(root.contentForeground, 1.45)
                    font.family: root.contentFontFamily
                    visible: text !== ""
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "·"
                    font.pixelSize: Style.space(8)
                    color: Qt.darker(root.contentForeground, 1.8)
                    visible: !!(root.selectedClubProfile && root.selectedClubProfile.homeRecord && root.selectedClubProfile.awayRecord)
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selectedClubProfile && root.selectedClubProfile.awayRecord ? ("Away: " + root.selectedClubProfile.awayRecord) : ""
                    font.pixelSize: Style.space(8)
                    color: Qt.darker(root.contentForeground, 1.45)
                    font.family: root.contentFontFamily
                    visible: text !== ""
                  }
                }
              }
            }
          }

          // Card 2: Team Performance & Discipline (Clean unified card, no choppy boxes)
          Rectangle {
            width: parent.width
            height: metricsCol.implicitHeight + Style.space(18)
            radius: Style.cornerRadius
            color: Util.alpha(root.contentForeground, 0.035)
            border.width: Style.spacing.hairline
            border.color: Util.alpha(root.contentForeground, 0.08)
            visible: root.searchClubCardTab === "overview" && !!(root.selectedClubProfile && (root.selectedClubProfile.possession || root.selectedClubProfile.shotsPerGame || root.selectedClubProfile.expectedGoals || root.selectedClubProfile.yellowCards !== undefined))

            Column {
              id: metricsCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              // Header
              Item {
                width: parent.width
                height: Style.space(14)
                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "TEAM PERFORMANCE & DISCIPLINE"
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  font.letterSpacing: 0.5
                  color: Qt.darker(root.contentForeground, 1.3)
                  font.family: root.contentFontFamily
                }
              }

              // Optional Season Leaders Row (if available)
              Row {
                width: parent.width
                spacing: Style.space(6)
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.topScorer || root.selectedClubProfile.topAssister || root.selectedClubProfile.topCarder))

                Item {
                  id: topScorerBox
                  width: (parent.width - Style.space(12)) / 3
                  height: topScorerCol.implicitHeight
                  visible: !!(root.selectedClubProfile && root.selectedClubProfile.topScorer)

                  Column {
                    id: topScorerCol
                    anchors.fill: parent
                    spacing: Style.space(2)
                    Text { text: "TOP SCORER"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                    Text {
                      text: (root.selectedClubProfile && root.selectedClubProfile.topScorer) ? root.selectedClubProfile.topScorer : "—"
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: topScorerMouse.containsMouse ? Qt.lighter(root.favoriteTeamAccent, 1.2) : root.favoriteTeamAccent
                      font.family: root.contentFontFamily
                      wrapMode: Text.Wrap
                      width: parent.width
                    }
                  }

                  MouseArea {
                    id: topScorerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: (root.selectedClubProfile && root.selectedClubProfile.topScorerId) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: !!(root.selectedClubProfile && root.selectedClubProfile.topScorerId)
                    onClicked: {
                      if (root.selectedClubProfile && root.selectedClubProfile.topScorerId) {
                        var pName = root.selectedClubProfile.topScorer.split(" (")[0]
                        root.openPlayerSearchDetail({
                          id: root.selectedClubProfile.topScorerId,
                          displayName: pName,
                          leagueSlug: root.selectedClubProfile.leagueSlug
                        })
                      }
                    }
                  }
                }
                Item {
                  id: topAssisterBox
                  width: (parent.width - Style.space(12)) / 3
                  height: topAssisterCol.implicitHeight
                  visible: !!(root.selectedClubProfile && root.selectedClubProfile.topAssister)

                  Column {
                    id: topAssisterCol
                    anchors.fill: parent
                    spacing: Style.space(2)
                    Text { text: "TOP ASSISTER"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                    Text {
                      text: (root.selectedClubProfile && root.selectedClubProfile.topAssister) ? root.selectedClubProfile.topAssister : "—"
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: topAssisterMouse.containsMouse ? root.favoriteTeamAccent : root.contentForeground
                      font.family: root.contentFontFamily
                      wrapMode: Text.Wrap
                      width: parent.width
                    }
                  }

                  MouseArea {
                    id: topAssisterMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: (root.selectedClubProfile && root.selectedClubProfile.topAssisterId) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: !!(root.selectedClubProfile && root.selectedClubProfile.topAssisterId)
                    onClicked: {
                      if (root.selectedClubProfile && root.selectedClubProfile.topAssisterId) {
                        var pName = root.selectedClubProfile.topAssister.split(" (")[0]
                        root.openPlayerSearchDetail({
                          id: root.selectedClubProfile.topAssisterId,
                          displayName: pName,
                          leagueSlug: root.selectedClubProfile.leagueSlug
                        })
                      }
                    }
                  }
                }
                Item {
                  id: topCarderBox
                  width: (parent.width - Style.space(12)) / 3
                  height: topCarderCol.implicitHeight
                  visible: !!(root.selectedClubProfile && root.selectedClubProfile.topCarder)

                  Column {
                    id: topCarderCol
                    anchors.fill: parent
                    spacing: Style.space(2)
                    Text { text: "DISCIPLINE"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                    Text {
                      text: (root.selectedClubProfile && root.selectedClubProfile.topCarder) ? root.selectedClubProfile.topCarder : "—"
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: topCarderMouse.containsMouse ? Qt.lighter("#eab308", 1.2) : "#eab308"
                      font.family: root.contentFontFamily
                      wrapMode: Text.Wrap
                      width: parent.width
                    }
                  }

                  MouseArea {
                    id: topCarderMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: (root.selectedClubProfile && root.selectedClubProfile.topCarderId) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: !!(root.selectedClubProfile && root.selectedClubProfile.topCarderId)
                    onClicked: {
                      if (root.selectedClubProfile && root.selectedClubProfile.topCarderId) {
                        var pName = root.selectedClubProfile.topCarder.split(" (")[0]
                        root.openPlayerSearchDetail({
                          id: root.selectedClubProfile.topCarderId,
                          displayName: pName,
                          leagueSlug: root.selectedClubProfile.leagueSlug
                        })
                      }
                    }
                  }
                }
              }

              // Divider between leaders and metrics (if leaders visible)
              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: Util.alpha(root.contentForeground, 0.06)
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.topScorer || root.selectedClubProfile.topAssister || root.selectedClubProfile.topCarder))
              }

              // Row 1: Attack Metrics
              Row {
                width: parent.width
                spacing: Style.space(6)

                Column {
                  width: (parent.width - Style.space(12)) / 3
                  spacing: Style.space(2)
                  Text { text: "POSSESSION"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.possession) ? root.selectedClubProfile.possession : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.favoriteTeamAccent; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 3
                  spacing: Style.space(2)
                  Text { text: "TOTAL SHOTS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.shotsPerGame) ? root.selectedClubProfile.shotsPerGame : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 3
                  spacing: Style.space(2)
                  Text { text: "SHOTS ON TARGET"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.shotsOnTarget) ? root.selectedClubProfile.shotsOnTarget : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
              }

              // Divider between attack and advanced chance creation
              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: Util.alpha(root.contentForeground, 0.06)
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.expectedGoals || root.selectedClubProfile.bigChances || root.selectedClubProfile.goalConversion))
              }

              // Row 1.5: Advanced Chance Creation & xG (4 columns)
              Row {
                width: parent.width
                spacing: Style.space(4)
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.expectedGoals || root.selectedClubProfile.bigChances || root.selectedClubProfile.goalConversion))

                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "xG / MATCH"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.expectedGoals) ? root.selectedClubProfile.expectedGoals : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.favoriteTeamAccent; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "xGA CONCEDED"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.expectedGoalsAgainst) ? root.selectedClubProfile.expectedGoalsAgainst : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "BIG CHANCES"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.bigChances) ? root.selectedClubProfile.bigChances : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "CONVERSION"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.goalConversion) ? root.selectedClubProfile.goalConversion : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
              }

              // Divider between advanced and distribution/defense
              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: Util.alpha(root.contentForeground, 0.06)
              }

              // Row 2: Distribution, Defense & Duels (4 columns)
              Row {
                width: parent.width
                spacing: Style.space(4)

                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "PASS ACCURACY"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.passPct) ? root.selectedClubProfile.passPct : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "CLEAN SHEETS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.cleanSheets) ? root.selectedClubProfile.cleanSheets : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "TACKLES WON"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.tackles) ? root.selectedClubProfile.tackles : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "DUELS WON"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text { text: (root.selectedClubProfile && root.selectedClubProfile.duelWinPct) ? root.selectedClubProfile.duelWinPct : "—"; font.pixelSize: Style.font.caption; font.bold: true; color: root.contentForeground; font.family: root.contentFontFamily }
                }
              }

              // Divider
              Rectangle {
                width: parent.width
                height: Style.spacing.hairline
                color: Util.alpha(root.contentForeground, 0.06)
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.yellowCards !== undefined || root.selectedClubProfile.disciplinaryPoints !== undefined))
              }

              // Row 3: Disciplinary Standing
              Row {
                width: parent.width
                spacing: Style.space(4)
                visible: !!(root.selectedClubProfile && (root.selectedClubProfile.yellowCards !== undefined || root.selectedClubProfile.disciplinaryPoints !== undefined))

                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "YELLOWS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text {
                    text: (root.selectedClubProfile && root.selectedClubProfile.yellowCards !== undefined && root.selectedClubProfile.yellowCards !== "") ? String(root.selectedClubProfile.yellowCards) : "0"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: "#eab308"
                    font.family: root.contentFontFamily
                  }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "REDS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text {
                    text: (root.selectedClubProfile && root.selectedClubProfile.redCards !== undefined && root.selectedClubProfile.redCards !== "") ? String(root.selectedClubProfile.redCards) : "0"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: "#ef4444"
                    font.family: root.contentFontFamily
                  }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "FOULS"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text {
                    text: (root.selectedClubProfile && root.selectedClubProfile.foulsCommitted !== undefined && root.selectedClubProfile.foulsCommitted !== "") ? String(root.selectedClubProfile.foulsCommitted) : "—"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                  }
                }
                Column {
                  width: (parent.width - Style.space(12)) / 4
                  spacing: Style.space(2)
                  Text { text: "FAIR-PLAY"; font.pixelSize: Style.space(8); font.bold: true; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily }
                  Text {
                    text: (root.selectedClubProfile && root.selectedClubProfile.disciplinaryPoints !== undefined && root.selectedClubProfile.disciplinaryPoints !== "") ? String(root.selectedClubProfile.disciplinaryPoints) : "0"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.favoriteTeamAccent
                    font.family: root.contentFontFamily
                  }
                }
              }
            }
          }

          // ==================== SQUAD TAB ====================
          // Squad Roster Segmented by Position Card
          Rectangle {
            width: parent.width
            height: squadRosterCol.implicitHeight + Style.space(18)
            radius: Style.cornerRadius
            color: Util.alpha(root.contentForeground, 0.035)
            border.width: Style.spacing.hairline
            border.color: Util.alpha(root.contentForeground, 0.08)
            visible: root.searchClubCardTab === "squad"

            Column {
              id: squadRosterCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Item {
                width: parent.width
                height: Style.space(14)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: "SQUAD ROSTER"
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  font.letterSpacing: 0.5
                  color: Qt.darker(root.contentForeground, 1.3)
                  font.family: root.contentFontFamily
                }

                Text {
                  id: squadCountTxt
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: {
                    var count = root.activeSquadList() ? root.activeSquadList().length : 0
                    var t = count + " Players"
                    if (root.selectedClubProfile && root.selectedClubProfile.nationalitiesCount > 0) {
                      t += " · " + root.selectedClubProfile.nationalitiesCount + " Nations"
                    }
                    if (root.selectedClubProfile && root.selectedClubProfile.averageAge) {
                      t += " · Avg " + root.selectedClubProfile.averageAge + "y"
                    }
                    return t
                  }
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  color: root.favoriteTeamAccent
                  font.family: root.contentFontFamily
                }
              }

              // Position filter segmented buttons: All | GK | DEF | MID | FWD
              Row {
                width: parent.width
                spacing: Style.space(4)

                Button {
                  height: Style.space(18)
                  fontSize: Style.space(8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: 0
                  text: "All (" + (root.selectedClubProfile && root.selectedClubProfile.rosterAll ? root.selectedClubProfile.rosterAll.length : 0) + ")"
                  selected: root.clubSquadPositionFilter === "all"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.clubSquadPositionFilter = "all"
                }
                Button {
                  height: Style.space(18)
                  fontSize: Style.space(8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: 0
                  text: "GK (" + (root.selectedClubProfile && root.selectedClubProfile.rosterGoalkeepers ? root.selectedClubProfile.rosterGoalkeepers.length : 0) + ")"
                  selected: root.clubSquadPositionFilter === "gk"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.clubSquadPositionFilter = "gk"
                }
                Button {
                  height: Style.space(18)
                  fontSize: Style.space(8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: 0
                  text: "DEF (" + (root.selectedClubProfile && root.selectedClubProfile.rosterDefenders ? root.selectedClubProfile.rosterDefenders.length : 0) + ")"
                  selected: root.clubSquadPositionFilter === "def"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.clubSquadPositionFilter = "def"
                }
                Button {
                  height: Style.space(18)
                  fontSize: Style.space(8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: 0
                  text: "MID (" + (root.selectedClubProfile && root.selectedClubProfile.rosterMidfielders ? root.selectedClubProfile.rosterMidfielders.length : 0) + ")"
                  selected: root.clubSquadPositionFilter === "mid"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.clubSquadPositionFilter = "mid"
                }
                Button {
                  height: Style.space(18)
                  fontSize: Style.space(8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: 0
                  text: "FWD (" + (root.selectedClubProfile && root.selectedClubProfile.rosterForwards ? root.selectedClubProfile.rosterForwards.length : 0) + ")"
                  selected: root.clubSquadPositionFilter === "fwd"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.clubSquadPositionFilter = "fwd"
                }
              }

              // Empty / loading indicator
              Text {
                width: parent.width
                text: root.searchClubRosterRequest && root.searchClubRosterRequest.running ? "Loading squad roster…" : "No players found in this category"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                color: Qt.darker(root.contentForeground, 1.6)
                visible: !root.activeSquadList() || root.activeSquadList().length === 0
              }

              // Player list repeater (clean rows, subtle hover highlight, no stacked gray boxes)
              Repeater {
                model: root.activeSquadList()
                delegate: Rectangle {
                  width: parent.width
                  height: Style.space(34)
                  radius: Style.cornerRadius
                  color: squadItemArea.containsMouse ? Util.alpha(root.contentForeground, 0.06) : "transparent"

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(6)
                    anchors.rightMargin: Style.space(6)
                    spacing: Style.space(8)

                    // Jersey # pill
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(20)
                      horizontalAlignment: Text.AlignHCenter
                      text: modelData.jersey && modelData.jersey !== "—" ? modelData.jersey : "—"
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      color: root.favoriteTeamAccent
                      font.family: root.contentFontFamily
                    }

                    // Headshot or fallback avatar
                    Item {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(24)
                      height: width

                      Image {
                        anchors.fill: parent
                        source: modelData.headshot || ""
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        smooth: true
                        visible: String(source) !== ""
                      }

                      Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(13)
                        color: Util.alpha(root.contentForeground, 0.25)
                        visible: !modelData.headshot || String(modelData.headshot) === ""
                      }
                    }

                    // Name & Position
                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Math.max(0, parent.width - Style.space(168))
                      spacing: Style.space(1)

                      Text {
                        width: parent.width
                        text: modelData.name
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.contentForeground
                        elide: Text.ElideRight
                      }

                      Text {
                        width: parent.width
                        text: (modelData.statsSummary && modelData.statsSummary !== "") ? (modelData.position + " · " + modelData.statsSummary) : modelData.position
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(8)
                        color: Qt.darker(root.contentForeground, 1.5)
                        elide: Text.ElideRight
                      }
                    }

                    // Nationality Flag & Country
                    Row {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(64)
                      spacing: Style.space(4)

                      Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(20)
                        height: Style.space(14)
                        source: modelData.flag || ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(80, 56)
                        mipmap: true
                        smooth: true
                        visible: String(source) !== ""
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Style.space(24)
                        text: modelData.country || ""
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.space(8)
                        color: Qt.darker(root.contentForeground, 1.6)
                        elide: Text.ElideRight
                      }
                    }

                    // Age badge
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(28)
                      horizontalAlignment: Text.AlignRight
                      text: modelData.age && modelData.age !== "—" ? (modelData.age + "y") : "—"
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.space(9)
                      color: Qt.darker(root.contentForeground, 1.45)
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: squadItemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.id && modelData.id !== "") {
                        if (root.selectedClubProfile) {
                          root.clubProfileHistory = root.selectedClubProfile
                        }
                        root.openPlayerSearchDetail({
                          id: modelData.id,
                          displayName: modelData.name,
                          subtitle: root.selectedClubProfile ? root.selectedClubProfile.displayName : "",
                          description: root.selectedClubProfile ? root.selectedClubProfile.leagueName : "",
                          image: modelData.headshot,
                          type: "player",
                          webUrl: ""
                        })
                      }
                    }
                  }
                }
              }
            }
          }

          // ==================== FIXTURES TAB ====================
          // Fixture Schedule Carousel (Upcoming Fixtures)
          Rectangle {
            width: parent.width
            height: fixturesCol.implicitHeight + Style.space(18)
            radius: Style.cornerRadius
            color: Util.alpha(root.contentForeground, 0.035)
            border.width: Style.spacing.hairline
            border.color: Util.alpha(root.contentForeground, 0.08)
            visible: root.searchClubCardTab === "fixtures"

            Column {
              id: fixturesCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              // Sub-view toggle: Upcoming vs Recent Results
              Row {
                width: parent.width
                spacing: Style.space(4)

                Button {
                  height: Style.space(18)
                  fontSize: Style.space(8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: 0
                  text: "Upcoming (" + (root.selectedClubProfile && root.selectedClubProfile.upcomingFixtures ? root.selectedClubProfile.upcomingFixtures.length : 0) + ")"
                  selected: root.clubFixtureViewMode === "upcoming"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.clubFixtureViewMode = "upcoming"
                }

                Button {
                  height: Style.space(18)
                  fontSize: Style.space(8)
                  horizontalPadding: Style.space(6)
                  verticalPadding: 0
                  text: "Recent Results (" + (root.selectedClubProfile && root.selectedClubProfile.recentMatches ? root.selectedClubProfile.recentMatches.length : 0) + ")"
                  selected: root.clubFixtureViewMode === "results"
                  fontFamily: root.contentFontFamily
                  foreground: root.contentForeground
                  accent: root.contentForeground
                  onClicked: root.clubFixtureViewMode = "results"
                }
              }

              Item {
                width: parent.width
                height: Style.space(18)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.clubFixtureViewMode === "results" ? "RECENT RESULTS" : "UPCOMING FIXTURES"
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  font.letterSpacing: 0.5
                  color: Qt.darker(root.contentForeground, 1.3)
                  font.family: root.contentFontFamily
                }

                // Carousel navigation controls
                Row {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)
                  visible: root.activeClubFixturesList().length > 1

                  Button {
                    height: Style.space(18)
                    width: Style.space(18)
                    iconText: ""
                    fontFamily: root.contentFontFamily
                    foreground: root.contentForeground
                    accent: root.contentForeground
                    fontSize: Style.space(8)
                    iconSize: Style.space(8)
                    horizontalPadding: 0
                    verticalPadding: 0
                    enabled: root.clubFixtureCarouselIndex > 0
                    opacity: enabled ? 1.0 : 0.4
                    onClicked: root.clubFixtureCarouselIndex = Math.max(0, root.clubFixtureCarouselIndex - 1)
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.clubFixtureCarouselIndex + 1) + " / " + Math.max(1, root.activeClubFixturesList().length)
                    font.pixelSize: Style.space(8)
                    font.bold: true
                    color: Qt.darker(root.contentForeground, 1.6)
                    font.family: root.contentFontFamily
                  }

                  Button {
                    height: Style.space(18)
                    width: Style.space(18)
                    iconText: ""
                    fontFamily: root.contentFontFamily
                    foreground: root.contentForeground
                    accent: root.contentForeground
                    fontSize: Style.space(8)
                    iconSize: Style.space(8)
                    horizontalPadding: 0
                    verticalPadding: 0
                    enabled: root.clubFixtureCarouselIndex < root.activeClubFixturesList().length - 1
                    opacity: enabled ? 1.0 : 0.4
                    onClicked: root.clubFixtureCarouselIndex = Math.min((root.activeClubFixturesList().length - 1), root.clubFixtureCarouselIndex + 1)
                  }
                }
              }

              // Active Fixture Card
              Rectangle {
                width: parent.width
                height: activeFixtureCol.implicitHeight + Style.space(16)
                radius: Style.cornerRadius
                color: Util.alpha(root.contentForeground, 0.04)
                border.width: Style.spacing.hairline
                border.color: Util.alpha(root.contentForeground, 0.08)
                visible: !!root.activeClubFixture()

                Column {
                  id: activeFixtureCol
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.margins: Style.space(10)
                  spacing: Style.space(8)

                  // Header: Competition & Kickoff date/time
                  Item {
                    width: parent.width
                    height: Style.space(14)

                    Text {
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.activeClubFixture() ? root.activeClubFixture().competition.toUpperCase() : ""
                      font.pixelSize: Style.space(9)
                      font.bold: true
                      font.letterSpacing: 0.5
                      color: root.favoriteTeamAccent
                      font.family: root.contentFontFamily
                      elide: Text.ElideRight
                      width: parent.width * 0.5
                    }

                    Text {
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.activeClubFixture() ? (root.activeClubFixture().date + (root.activeClubFixture().time !== "" ? (" · " + root.activeClubFixture().time) : "")) : ""
                      font.pixelSize: Style.space(9)
                      color: Qt.darker(root.contentForeground, 1.45)
                      font.family: root.contentFontFamily
                      elide: Text.ElideRight
                      width: parent.width * 0.5
                      horizontalAlignment: Text.AlignRight
                    }
                  }

                  // Matchup Layout (Home Crest + Name vs Away Name + Crest)
                  Row {
                    width: parent.width
                    spacing: Style.space(8)

                    // Home Team (Clickable if opponent)
                    Item {
                      id: homeTeamBox
                      anchors.verticalCenter: parent.verticalCenter
                      width: (parent.width - Style.space(48) - parent.spacing * 2) / 2
                      height: Style.space(26)

                      readonly property bool isOpponent: {
                        var fix = root.activeClubFixture()
                        return !!(fix && !fix.isHome && fix.oppId && String(fix.oppId) !== "")
                      }

                      opacity: (isOpponent && homeTeamMouse.containsMouse) ? 0.75 : 1.0
                      Behavior on opacity { NumberAnimation { duration: 120 } }

                      Row {
                        anchors.fill: parent
                        spacing: Style.space(6)

                        Image {
                          anchors.verticalCenter: parent.verticalCenter
                          width: Style.space(24)
                          height: width
                          source: root.activeClubFixture() ? (root.activeClubFixture().homeLogo || "") : ""
                          fillMode: Image.PreserveAspectFit
                          mipmap: true
                          smooth: true
                          visible: String(source) !== ""
                        }

                        Text {
                          anchors.verticalCenter: parent.verticalCenter
                          width: parent.width - Style.space(30)
                          text: root.activeClubFixture() ? root.activeClubFixture().homeTeam : ""
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                          elide: Text.ElideRight
                        }
                      }

                      MouseArea {
                        id: homeTeamMouse
                        anchors.fill: parent
                        enabled: homeTeamBox.isOpponent
                        cursorShape: homeTeamBox.isOpponent ? Qt.PointingHandCursor : Qt.ArrowCursor
                        hoverEnabled: true
                        onClicked: {
                          var fix = root.activeClubFixture()
                          if (fix && fix.oppId) {
                            root.openClubSearchDetail({
                              id: fix.oppId,
                              displayName: fix.homeTeam || fix.oppName,
                              image: fix.homeLogo || fix.oppLogo,
                              leagueSlug: fix.oppLeagueSlug || ""
                            })
                          }
                        }
                      }
                    }

                    // Center Score or VS (clean typography, no container box or outcome badge)
                    Item {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(48)
                      height: Style.space(20)

                      Text {
                        anchors.centerIn: parent
                        text: (root.activeClubFixture() && root.activeClubFixture().isCompleted && root.activeClubFixture().score) ? root.activeClubFixture().score : "VS"
                        font.pixelSize: (root.activeClubFixture() && root.activeClubFixture().isCompleted) ? Style.font.body : Style.space(9)
                        font.bold: true
                        color: (root.activeClubFixture() && root.activeClubFixture().isCompleted) ? root.contentForeground : Qt.darker(root.contentForeground, 1.5)
                        font.family: root.contentFontFamily
                      }
                    }

                    // Away Team (Clickable if opponent)
                    Item {
                      id: awayTeamBox
                      anchors.verticalCenter: parent.verticalCenter
                      width: (parent.width - Style.space(48) - parent.spacing * 2) / 2
                      height: Style.space(26)

                      readonly property bool isOpponent: {
                        var fix = root.activeClubFixture()
                        return !!(fix && fix.isHome && fix.oppId && String(fix.oppId) !== "")
                      }

                      opacity: (isOpponent && awayTeamMouse.containsMouse) ? 0.75 : 1.0
                      Behavior on opacity { NumberAnimation { duration: 120 } }

                      Row {
                        anchors.fill: parent
                        spacing: Style.space(6)

                        Text {
                          anchors.verticalCenter: parent.verticalCenter
                          width: parent.width - Style.space(30)
                          horizontalAlignment: Text.AlignRight
                          text: root.activeClubFixture() ? root.activeClubFixture().awayTeam : ""
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                          elide: Text.ElideRight
                        }

                        Image {
                          anchors.verticalCenter: parent.verticalCenter
                          width: Style.space(24)
                          height: width
                          source: root.activeClubFixture() ? (root.activeClubFixture().awayLogo || "") : ""
                          fillMode: Image.PreserveAspectFit
                          mipmap: true
                          smooth: true
                          visible: String(source) !== ""
                        }
                      }

                      MouseArea {
                        id: awayTeamMouse
                        anchors.fill: parent
                        enabled: awayTeamBox.isOpponent
                        cursorShape: awayTeamBox.isOpponent ? Qt.PointingHandCursor : Qt.ArrowCursor
                        hoverEnabled: true
                        onClicked: {
                          var fix = root.activeClubFixture()
                          if (fix && fix.oppId) {
                            root.openClubSearchDetail({
                              id: fix.oppId,
                              displayName: fix.awayTeam || fix.oppName,
                              image: fix.awayLogo || fix.oppLogo,
                              leagueSlug: fix.oppLeagueSlug || ""
                            })
                          }
                        }
                      }
                    }
                  }

                  // Broadcast Channel Row (Only for upcoming fixtures)
                  Row {
                    width: parent.width
                    spacing: Style.space(6)
                    visible: !!(root.activeClubFixture() && !root.activeClubFixture().isCompleted && root.activeClubFixture().broadcast)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "󰢹"
                      font.family: "Symbols Nerd Font, " + root.contentFontFamily
                      font.pixelSize: Style.space(9)
                      color: root.favoriteTeamAccent
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "Broadcast: " + (root.activeClubFixture() ? root.activeClubFixture().broadcast : "")
                      font.pixelSize: Style.space(8)
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      elide: Text.ElideRight
                      width: parent.width - Style.space(20)
                    }
                  }
                }
              }

              // Empty Fixtures State
              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.clubFixtureViewMode === "results" ? "No recent match results available" : "No upcoming fixtures scheduled"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                color: Qt.darker(root.contentForeground, 1.6)
                visible: !root.activeClubFixture()
              }
            }
          }

          Button {
            width: parent.width
            height: Style.space(28)
            iconText: "󰖟"
            text: "View Official Clubhouse on ESPN"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.contentForeground
            fontSize: Style.font.caption
            iconSize: Style.font.caption
            horizontalPadding: Style.space(12)
            verticalPadding: 0
            visible: !!(root.selectedClubProfile && root.selectedClubProfile.webUrl)
            onClicked: {
              if (root.selectedClubProfile && root.selectedClubProfile.webUrl) {
                Qt.openUrlExternally(root.selectedClubProfile.webUrl)
              }
            }
          }
        }
      }
    }
  }
