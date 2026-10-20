import QtQuick

// State owner; the panel exposes compatibility aliases to existing views.
QtObject {
  property bool showSearch: false
  property string searchQuery: ""
  property bool searchLoading: false
  property var searchResults: []
  property string searchError: ""
  property var selectedPlayerProfile: null
  property bool searchPlayerLoading: false
  property string searchPlayerStatsTab: "all"
  property string searchPlayerCardTab: "info"
  property string statsPlayerKey: ""
  property string statsPlayerLeague: ""
  property bool playerStatsLoading: false
  property var playerCompStatQueue: []
  property var playerCompStatCache: ({})
  property string clubNamesResolvedFor: ""
  property var clubNameQueue: []
  property var teamNameCache: ({})
  property var teamAbbrevCache: ({})
  property var teamShortCache: ({})
  property var transferTeamQueue: []
  property string _transferTeamInFlight: ""
  property string compStatInFlightUrl: ""
  property int _compStatRequestGen: 0
  property int compStatInFlightGen: 0
  property bool _statsMinAnimActive: false
  property var clubAggQueue: []
  property var clubAggSums: ({})
  property string clubAggTarget: ""
  property var careerAggQueue: []
  property var careerAggSums: ({})
  property string careerAggTarget: ""
  property var selectedClubProfile: null
  property var clubProfileHistory: null
  property bool searchClubLoading: false
  property var _pendingClubProfile: null
  property int _clubFetchPending: 0
  property var clubLeaderQueue: []
  property var matchDetailJerseyUrls: []
  property string searchClubCardTab: "overview"
  property string clubSquadPositionFilter: "all"
  property int clubFixtureCarouselIndex: 0
  property string clubFixtureViewMode: "upcoming"
  property var _clubCache: ({})
  property var _playerCache: ({})
  property var _leagueStandingsCache: ({})
  property bool clubStandingsExpanded: false
  property var _teamAbbrevCache: ({})
  property var _teamShortCache: ({})
}
