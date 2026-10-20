import QtQuick

// State owner; the panel exposes compatibility aliases to existing views.
QtObject {
  property bool showMatches: false
  property bool showClubFixtures: false
  property bool matchListLoading: false
  property string matchListError: ""
  property var matchClusters: []
  property int matchClusterIndex: 0
  property var leagueLive: []
  property var leagueRecent: []
  property var leagueUpcoming: []
  property string leagueBoardSummary: ""
  property bool leagueBrowseAll: false
  property bool showStats: false
  property int statsSeasonOffset: 0
  property string statsCategory: "goals"
  property var statsGoals: []
  property var statsAssists: []
  property var statsYellow: []
  property var statsRed: []
  property var statsSaves: []
  property var rawYellowLeaders: []
  property var rawRedLeaders: []
  property var rawSavesLeaders: []
  property var athleteMap: ({})
  property bool statsLoading: false
  property string statsError: ""
  property real lastStandingsRefresh: 0
  property string _lastStandingsKey: ""
  property real lastStatsRefresh: 0
  property string _lastStatsKey: ""
  property real lastMatchListRefresh: 0
  property string _lastMatchListKey: ""
  property int standingsSeasonOffset: 0
  property int matchesSeasonOffset: 0
  property bool standingsLoading: false
  property string standingsError: ""
  property var standingsGroups: []
  property int standingsGroupIndex: 0
  property var followedLeagueMatches: []
  property var leagueSummaryQueue: []
  property string leagueCurrentId: ""
  property int matchWindowOffset: 0
  property string pendingEdge: ""
  property string navAnchorDay: ""
  property var competitionSlugs: []
  property var competitionRefresh: 0
  property var scoreboardQueue: []
  property var sbSlugs: ["", "", ""]
  property var _sbRetry: ({})
  property var _tournamentBracketCache: ({})
  property var tournamentSeasonBracket: []
  property bool tournamentBracketLoading: false
  property string tournamentBracketError: ""
  property string _tournamentBracketRequestKey: ""
  property string _tournamentBracketRequestLeague: ""
  property int _tournamentBracketRequestSeasonYear: 0
  property string _leagueCalendarRequestKey: ""
}
