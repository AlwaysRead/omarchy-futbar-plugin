import QtQuick
import "../data/FutMatches.js" as Matches

Item {
  id: controller
  visible: false
  property bool active: false
  property var matches: []
  property var queue: []
  property var seen: ({})
  property int index: 0
  property bool loading: false
  property string identity: ""
  signal lineupAvailable(var match)
  function refresh() {
    if (!active || loading) return
    var now = Date.now()
    queue = matches.filter(function(m) { return m.state === "pre" && !Matches.cancelled(m) && m.kickoff > now && m.kickoff-now < 2*3600000 }).slice(0,6)
    index = 0; loading = queue.length > 0
    if (loading) next.restart()
  }
  function advance() { index++; loading = index < queue.length; if (loading) next.restart() }
  function available(data) {
    if (!data || !Array.isArray(data.rosters) || data.rosters.length !== 2) return false
    return data.rosters.every(function(team) {
      return team && Array.isArray(team.roster) && team.roster.slice(0,64).filter(function(p) { return p && p.starter === true }).length >= 11
    })
  }
  onActiveChanged: {
    request.url = ""; loading = false
    if (active) refresh()
  }
  onIdentityChanged: { seen = ({}); request.url = ""; loading = false; if (active) refresh() }
  Timer { interval: 60000; repeat: true; running: controller.active; onTriggered: controller.refresh() }
  Timer {
    id: next; interval: 30
    onTriggered: {
      if (!controller.active || !controller.loading) return
      var m = controller.queue[controller.index]
      request.url = "https://site.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(m.competitionSlug) + "/summary?event=" + encodeURIComponent(m.id)
      request.refresh()
    }
  }
  FutApiRequest {
    id: request
    active: controller.active && controller.loading
    onUpdatedAtChanged: {
      if (!updatedAt || !controller.loading) return
      var m = controller.queue[controller.index], ready = controller.available(result)
      var key = m.id+":"+m.date, old = controller.seen[key]
      var seen = Object.assign({},controller.seen)
      // Initial snapshots are silent; alert only on an observed transition.
      if (old === false && ready) controller.lineupAvailable(m)
      seen[key] = old === true || ready
      var keys = Object.keys(seen).slice(-128), keep = {}
      keys.forEach(function(k) { keep[k] = seen[k] }); controller.seen = keep
      controller.advance()
    }
    onErrorChanged: if (error && controller.loading) controller.advance()
  }
}
