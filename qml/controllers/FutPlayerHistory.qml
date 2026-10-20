import QtQuick
import "../data/FutPlayerHistory.js" as History

Item {
  id: history
  visible: false
  property string athleteId: ""
  property bool active: false
  property int season: new Date().getFullYear()
  property string competition: ""
  readonly property var parsed: History.parse(request.result)
  readonly property string seasonLabel: {
    for (var i=0;i<parsed.seasons.length;i++) if(parsed.seasons[i].value===String(season)) return parsed.seasons[i].label
    return String(season)
  }
  readonly property var matches: parsed.matches
  readonly property var competitions: parsed.competitions
  readonly property bool loading: request.loading
  readonly property string error: request.error
  readonly property double updatedAt: request.updatedAt
  readonly property int retryInSeconds: request.retryInSeconds
  function refresh() { request.refresh() }
  onAthleteIdChanged: { season = new Date().getFullYear(); competition = "" }
  FutApiRequest {
    id: request
    responseKind: "gamelog"
    active: history.active && url !== ""
    url: History.requestUrl(history.athleteId, history.season, history.competition)
  }
}
