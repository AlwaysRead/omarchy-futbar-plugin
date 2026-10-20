.pragma library

function text(value, limit) {
  return typeof value === "string" ? value.replace(/[\u0000-\u001f\u007f]/g, " ").slice(0, limit || 160) : ""
}
function identifier(value) {
  if (typeof value === "number" && Number.isSafeInteger(value) && value >= 0) value = String(value)
  return typeof value === "string" && value !== "." && value !== ".." && /^[A-Za-z0-9_.-]{1,80}$/.test(value) ? value : ""
}
function score(value) {
  return typeof value === "string" && /^\d{1,3}$/.test(value) ? value :
    typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 999 ? String(value) : ""
}
function relevant(matches, now) {
  return matches.filter(function(m) { return m.kickoff >= now-60*86400000 && m.kickoff < now+8*86400000 })
}
function normalize(event, league) {
  if (!event || typeof event !== "object") return null
  var competition = Array.isArray(event.competitions) ? event.competitions[0] : null
  if (!competition || !Array.isArray(competition.competitors)) return null
  var home = competition.competitors.find(function(c) { return c && c.homeAway === "home" })
  var away = competition.competitors.find(function(c) { return c && c.homeAway === "away" })
  var id = identifier(event.id), date = typeof event.date === "string" && event.date.length <= 64 ? Date.parse(event.date) : NaN
  if (!id || !isFinite(date) || !home || !away || !home.team || !away.team) return null
  var status = event.status || competition.status || {}, type = status.type || {}
  var slug = identifier(event.competitionSlug || (event.league && event.league.slug) || league || "all")
  var venue = competition.venue || {}
  return {id: id, date: new Date(date).toISOString(), kickoff: date, competitionSlug: slug,
    competitionName: text(event.competitionName || (event.league && event.league.name) || competition.altGameNote || slug),
    homeId: identifier(home.team.id), awayId: identifier(away.team.id),
    homeName: text(home.team.displayName || home.team.name), awayName: text(away.team.displayName || away.team.name),
    homeScore: score(home.score), awayScore: score(away.score),
    state: text(type.state, 12), statusName: text(type.name, 80), status: text(type.shortDetail || type.description, 100),
    location: text(venue.fullName), timeValid: competition.timeValid !== false,
    started: type.state === "in" || type.state === "post", isLive: type.state === "in"}
}
function matches(data, league) {
  if (!data || !Array.isArray(data.events)) return []
  return data.events.slice(0, 500).map(function(e) { return normalize(e, league) }).filter(function(e) { return e !== null })
}
function merge(existing, incoming) {
  var indexed = Object.create(null)
  existing.concat(incoming).slice(-2000).forEach(function(e) { indexed[e.id] = e })
  return Object.keys(indexed).map(function(id) { return indexed[id] }).sort(function(a,b) { return a.kickoff-b.kickoff }).slice(0, 1000)
}
function followed(match, tabs) {
  return tabs.slice(0, 24).some(function(t) {
    if (!t || typeof t !== "object") return false
    return t.followLeague ? identifier(t.league) === match.competitionSlug :
      !!identifier(t.teamId) && (identifier(t.teamId) === match.homeId || identifier(t.teamId) === match.awayId)
  })
}
function dayKey(date) {
  return String(date.getFullYear()) + String(date.getMonth()+1).padStart(2,"0") + String(date.getDate()).padStart(2,"0")
}
function plan(tabs, now) {
  var urls = [], seen = Object.create(null)
  tabs.slice(0,24).forEach(function(t) {
    if (!t || typeof t !== "object") return
    var team = identifier(t.teamId), league = identifier(t.league)
    if (team && !t.followLeague) {
      ["?fixture=true"].forEach(function(suffix) {
        var url = "https://site.web.api.espn.com/apis/site/v2/sports/soccer/all/teams/" + encodeURIComponent(team) + "/schedule" + suffix
        if (!seen[url]) { urls.push({url: url, league: league}); seen[url] = true }
      })
    } else if (t.followLeague && league) {
      for (var i=0; i<7; i++) {
        var day = new Date(now); day.setDate(day.getDate()+i)
        var url = "https://site.api.espn.com/apis/site/v2/sports/soccer/" + encodeURIComponent(league) + "/scoreboard?dates=" + dayKey(day) + "&limit=300"
        if (!seen[url]) { urls.push({url: url, league: league}); seen[url] = true }
      }
    }
  })
  return urls.slice(0,96)
}
function cancelled(match) { return /POSTPON|CANCEL|SUSPEND|ABANDON/i.test(match.statusName) }
function reminderKey(match, minutes) { return match.id + ":" + match.date + ":" + minutes }
function dueReminders(matches, minutes, sent, now) {
  if ([5,15,30].indexOf(minutes) < 0) return []
  return matches.filter(function(m) {
    var delta = m.kickoff-now
    return m.state === "pre" && !cancelled(m) && m.timeValid && delta > 0 &&
      delta <= minutes*60000 && delta > (minutes-2)*60000 && !sent[reminderKey(m,minutes)]
  })
}
