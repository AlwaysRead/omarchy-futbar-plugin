.pragma library

function requestUrl(athlete, season, competition) {
  if (!/^\d{1,12}$/.test(String(athlete)) || !/^\d{4}$/.test(String(season)) || Number(season) < 1980 || Number(season) > new Date().getFullYear()+1) return ""
  if (competition && !/^[a-z0-9_.-]{1,64}$/.test(competition)) return ""
  return "https://site.web.api.espn.com/apis/common/v3/sports/soccer/athletes/" + athlete + "/gamelog?season=" + season + (competition ? "&league=" + encodeURIComponent(competition) : "")
}
function text(value) { return typeof value === "string" ? value.slice(0,160) : "" }
function parse(data) {
  var result = {matches: [], competitions: [], seasons: []}
  if (!data || typeof data !== "object") return result
  var filters = Array.isArray(data.filters) ? data.filters.slice(0,16) : []
  filters.forEach(function(f) {
    if (!f || !Array.isArray(f.options)) return
    f.options.slice(0,100).forEach(function(o) {
      if (!o) return
      var v = text(o.value), label = text(o.displayValue) || v
      if (f.name === "league" && /^[a-z0-9_.-]{1,64}$/.test(v)) result.competitions.push({value:v,label:label})
      if (f.name === "season" && /^\d{4}$/.test(v)) result.seasons.push({value:v,label:label})
    })
  })
  var names = Array.isArray(data.names) ? data.names.slice(0,80) : []
  var events = data.events && typeof data.events === "object" ? data.events : {}
  var groups = Array.isArray(data.seasonTypes) ? data.seasonTypes.slice(0,32) : []
  var seen = Object.create(null)
  groups.forEach(function(group) {
    var cats = group && Array.isArray(group.categories) ? group.categories.slice(0,32) : []
    cats.forEach(function(cat) {
      var rows = cat && Array.isArray(cat.events) ? cat.events.slice(0,200) : []
      rows.forEach(function(row) {
        if (!row || result.matches.length >= 200) return
        var id = String(row.eventId || ""), e = events[id]
        if (!/^\d{1,16}$/.test(id) || seen[id] || !e || typeof e !== "object") return
        seen[id] = true
        var stats = Array.isArray(row.stats) ? row.stats : []
        function stat(name) {
          var i = names.indexOf(name), value = i >= 0 ? String(stats[i]) : ""
          return /^\d{1,3}(\.\d{1,2})?$/.test(value) ? value : "—"
        }
        var goals=stat("totalGoals"), assists=stat("goalAssists"), shots=stat("shotsOnTarget")
        var rating="—"
        if (goals !== "—" && assists !== "—") rating = Math.min(10,6+Number(goals)*1.1+Number(assists)*0.7+(shots === "—" ? 0 : Number(shots)*0.1)).toFixed(1)
        var opponent = e.opponent && typeof e.opponent === "object" ? text(e.opponent.displayName) : "Opponent"
        var date = text(e.gameDate)
        result.matches.push({id:id, timestamp:Date.parse(date)||0, date:date.slice(0,10), leagueName:text(e.leagueName), matchTitle:(e.atVs === "@" ? "@ " : "vs ")+opponent, opponentName:opponent, score:text(e.score)||"—", result:text(e.gameResult), goals:goals, assists:assists, rating:rating})
      })
    })
  })
  result.matches.sort(function(a,b) { return b.timestamp-a.timestamp })
  return result
}
