import QtQuick

// Navigation and picker state, exposed through the panel compatibility facade.
QtObject {
  property bool showNews: false
  property bool showSettings: false
  property bool showStandings: false
  property bool showTrending: false
  property bool returnToTrendingAfterDetail: false
  property bool returnToMatchesAfterDetail: false
  property int keyboardSelectedMainMatchIndex: -1
  property var teams: []
  property string resolvedTeamId: ""
  property var leagueInfo: ({})
  property string selectedLeague: ""
  property string selectedLeagueName: ""
  property var selectedTeam: null
  property bool editingTeam: false
  property bool pickerLeagueOnly: false
  property bool addingTeam: false
}
