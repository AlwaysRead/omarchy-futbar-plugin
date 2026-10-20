import QtQuick

// State owner; the panel exposes compatibility aliases to existing views.
QtObject {
  property var matchDetail: null
  property bool matchDetailLoading: false
  property string matchDetailError: ""
  property string matchDetailTab: "stats"
  property string matchDetailLineupTeam: "home"
  property string matchDetailLineupView: "pitch"
  property bool matchDetailCrestsLoaded: false
  property bool showMatchDetail: false
}
