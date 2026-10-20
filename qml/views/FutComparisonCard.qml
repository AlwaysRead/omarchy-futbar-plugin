import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "../data/FutComparison.js" as Comparison

Rectangle {
  id: view
  property var root: null
  property string message: ""
  property bool expanded: true
  readonly property var profiles: root ? root.comparisonProfiles : []
  readonly property string kind: root ? root.comparisonKind : "player"
  readonly property string currentId: root ? root.comparisonProfileId : ""
  readonly property int pinnedIndex: Comparison.indexOf(profiles,kind,currentId)
  readonly property bool busy: !!root && (root.searchClubLoading || root.searchPlayerLoading || root.playerStatsLoading)
  readonly property bool needsContext: kind === "player" && !!root && !root.comparisonContext
  readonly property bool mixed: profiles.length > 0 && profiles[0].kind !== kind
  readonly property bool full: profiles.length >= Comparison.maximumPins && currentId !== "" && pinnedIndex < 0
  width: parent ? parent.width : 0
  implicitHeight: body.implicitHeight + Style.space(20)
  height: implicitHeight
  radius: Style.space(8)
  color: root ? Util.alpha(root.contentForeground,0.025) : "transparent"
  border.width: 1
  border.color: root ? Util.alpha(root.contentForeground,0.1) : "transparent"
  onCurrentIdChanged: message = ""
  onKindChanged: message = ""
  onProfilesChanged: if(profiles.length>=2) expanded=true

  Column {
    id: body
    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
    anchors.margins: Style.space(10)
    spacing: Style.space(8)
    Item {
      width: parent.width
      implicitHeight: Math.max(title.implicitHeight,pinButton.implicitHeight)
      Column {
        id: title
        anchors.left: parent.left; anchors.right: pinButton.left; anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(3)
        Text { width:parent.width; text:"Compare "+((view.profiles.length ? view.profiles[0].kind : view.kind)==="player" ? "players" : "clubs");textFormat:Text.PlainText;color:root.contentForeground;font.family:root.contentFontFamily;font.pixelSize:Style.font.caption;font.bold:true;elide:Text.ElideRight }
        Text { width:parent.width;text:view.profiles.length+" of 4 pinned";textFormat:Text.PlainText;color:root.contentForeground;opacity:0.55;font.family:root.contentFontFamily;font.pixelSize:Style.font.caption-1 }
      }
      Button {
        id: pinButton
        visible: !!root && !!(root.selectedPlayerProfile || root.selectedClubProfile)
        objectName: "comparisonPinButton"
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        text: view.needsContext ? "Choose stats" : view.pinnedIndex>=0 ? "Update" : "Pin "+view.kind
        iconText: view.needsContext ? "" : ""
        tooltipText: view.pinnedIndex>=0 ? "Update this pinned snapshot" : "Add this "+view.kind+" to comparison"
        enabled: !view.busy && !view.mixed && !view.full && view.currentId!==""
        focusable:true;Accessible.role:Accessible.Button;Accessible.name:tooltipText
        foreground:root.contentForeground;accent:root.favoriteTeamAccent;fontFamily:root.contentFontFamily;fontSize:Style.font.caption
        onClicked: {
          if(view.needsContext) {
            root.showComparison=false;root.showSearch=true
            root.searchPlayerCardTab="stats";root.ensurePlayerStats();root.setPlayerStatsTab("tournament")
            view.message="Select a season and competition, then pin this player."
          } else view.message=root.pinComparison()
        }
      }
    }
    Text {
      width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
      text:view.mixed ? "Clear these pins to compare "+(view.kind==="player" ? "players." : "clubs.") : view.full ? "Remove a pin to add another "+view.kind+"." : view.message ? view.message : view.profiles.length===0 ? "Pin two profiles to compare their season statistics." : view.profiles.length===1 ? "Open another "+view.kind+" in Search and pin it." : "Season totals · — means ESPN has no value."
      color:root.contentForeground;opacity:0.6;font.family:root.contentFontFamily;font.pixelSize:Style.font.caption-1
    }
    Column {
      width:parent.width;spacing:Style.space(5)
      Repeater {
        model:view.profiles
        delegate: Rectangle {
          required property var modelData
          width:parent.width;implicitHeight:Math.max(pinName.implicitHeight+pinContext.implicitHeight+Style.space(15),removeButton.implicitHeight+Style.space(10));height:implicitHeight
          radius:Style.space(5);color:Util.alpha(root.contentForeground,0.035)
          Column {
            anchors.left:parent.left;anchors.right:removeButton.left;anchors.verticalCenter:parent.verticalCenter
            anchors.leftMargin:Style.space(8);anchors.rightMargin:Style.space(6);spacing:Style.space(3)
            Text {id:pinName;width:parent.width;text:modelData.name;textFormat:Text.PlainText;elide:Text.ElideRight;color:root.contentForeground;font.family:root.contentFontFamily;font.pixelSize:Style.font.caption;font.bold:true}
            Text {id:pinContext;width:parent.width;text:modelData.contextLabel || modelData.context || "Context unavailable";textFormat:Text.PlainText;elide:Text.ElideRight;color:root.contentForeground;opacity:0.5;font.family:root.contentFontFamily;font.pixelSize:Style.font.caption-1}
          }
          Button {
            id:removeButton;objectName:"comparisonRemoveButton"
            anchors.right:parent.right;anchors.rightMargin:Style.space(4);anchors.verticalCenter:parent.verticalCenter
            text:"×";tooltipText:"Remove "+modelData.name+" from comparison";focusable:true
            Accessible.role:Accessible.Button;Accessible.name:tooltipText
            foreground:root.contentForeground;accent:root.favoriteTeamAccent;fontFamily:root.contentFontFamily;fontSize:Style.font.body
            onClicked:{root.removeComparison(modelData.kind,modelData.id);view.message=""}
          }
        }
      }
    }
    Row {
      visible:view.profiles.length>0
      spacing:Style.space(6)
      Button {
        visible:view.profiles.length>=2;text:view.expanded ? "Hide comparison" : "Show comparison"
        focusable:true;Accessible.role:Accessible.Button;Accessible.name:text
        foreground:root.contentForeground;accent:root.favoriteTeamAccent;fontFamily:root.contentFontFamily;fontSize:Style.font.caption-1
        onClicked:view.expanded=!view.expanded
      }
      Button {
        text:"Clear pins";focusable:true;Accessible.role:Accessible.Button;Accessible.name:text
        foreground:root.contentForeground;accent:root.favoriteTeamAccent;fontFamily:root.contentFontFamily;fontSize:Style.font.caption-1
        onClicked:{root.comparisonProfiles=[];view.message=""}
      }
    }
    Column {
      visible:view.profiles.length>=2 && view.expanded
      width:parent.width;spacing:Style.space(8)
      Text {
        visible:view.profiles.length>=2 && !Comparison.sameContext(view.profiles)
        width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
        text:"Different or unknown seasons/competitions. Compare these values with that context in mind."
        color:root.contentForeground;opacity:0.65;font.family:root.contentFontFamily;font.pixelSize:Style.font.caption-1
      }
      Flickable {
        id: statsScroll
        objectName: "comparisonStatsScroll"
        width: parent.width
        height: statsTable.implicitHeight + Style.space(12)
        contentWidth: Math.max(width,Style.space(86)+view.profiles.length*Style.space(100))
        contentHeight: height
        clip: true
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        activeFocusOnTab: contentWidth>width
        Accessible.name: "Comparison statistics; use left and right arrows to scroll"
        Keys.onLeftPressed: contentX=Math.max(0,contentX-Style.space(100))
        Keys.onRightPressed: contentX=Math.min(contentWidth-width,contentX+Style.space(100))
        Controls.ScrollBar.horizontal: Controls.ScrollBar {policy: Controls.ScrollBar.AsNeeded}
        Column {
          id: statsTable
          width: statsScroll.contentWidth
          spacing: Style.space(8)
          readonly property real valueWidth: (width-Style.space(74)-view.profiles.length*Style.space(6))/Math.max(1,view.profiles.length)
          Row {
            width: parent.width; spacing: Style.space(6)
            Item {width:Style.space(74);height:1}
            Repeater {
              model: view.profiles
              delegate: Text {
                required property var modelData
                width: statsTable.valueWidth
                text: modelData.name; textFormat: Text.PlainText
                wrapMode: Text.WordWrap;maximumLineCount:2;elide:Text.ElideRight
                color:root.contentForeground;font.family:root.contentFontFamily
                font.pixelSize:Style.font.caption-1;font.bold:true;horizontalAlignment:Text.AlignHCenter
              }
            }
          }
          Repeater {
            model: Comparison.rows(view.profiles)
            delegate: Row {
              required property var modelData
              width: parent.width;spacing:Style.space(6)
              Text {width:Style.space(74);text:modelData.label;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:root.contentForeground;opacity:0.6;font.family:root.contentFontFamily;font.pixelSize:Style.font.caption-1}
              Repeater {
                model: modelData.values
                delegate: Text {
                  required property var modelData
                  width:statsTable.valueWidth;text:modelData;textFormat:Text.PlainText
                  color:root.contentForeground;font.family:root.contentFontFamily
                  font.pixelSize:Style.font.caption;font.bold:true;horizontalAlignment:Text.AlignHCenter
                }
              }
            }
          }
        }
      }
      Text {
        visible: Comparison.rows(view.profiles).length===0
        width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
        text:"No statistics available for these snapshots. Update pins after choosing a competition with data."
        color:root.contentForeground;opacity:0.6;font.family:root.contentFontFamily;font.pixelSize:Style.font.caption-1
      }
      Text {
        visible: statsScroll.contentWidth>statsScroll.width
        width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText
        text:"Scroll sideways to see every profile."
        color:root.contentForeground;opacity:0.5;font.family:root.contentFontFamily;font.pixelSize:Style.font.caption-1
      }
    }
  }
}
