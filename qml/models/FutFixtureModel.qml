import QtQuick

// State owner; the panel exposes compatibility aliases to existing views.
QtObject {
  property bool loading: false
  property real _pulse: 0.0
  property var lastRefresh: 0
  property string requestError: ""
  property string tournamentName: ""
  property string tournamentLogo: ""
  property var nextMatch: null
  property var previousMatch: null
  property var liveMatch: null
  property var liveEvents: []
  property string summaryMatchId: ""
  property bool liveActivity: false
  property string activityMatchId: ""
  property var activityFlags: ({ started: false, halftime: false, secondhalf: false, fulltime: false })
  property bool activityInitialized: false
  property bool activityWasHT: false
  property bool activityET: false
  property var activityEvents: []
  property var activityPending: ({})
  property var fetchQueue: []
  property var collectedEvents: []
  property string fetchStage: ""
  property bool fixtureCycleReceived: false
  property int clubFixturePage: 0
  property string _fixtureTeamKey: ""
  property var _teamStateCache: ({})
  property var _leagueStateCache: ({})
}
