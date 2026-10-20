.pragma library

function plain(value, limit) {
  return typeof value === "string" ? value.replace(/[\u0000-\u001f\u007f]/g, " ").slice(0, limit || 512) : ""
}
function webLink(value) {
  return typeof value === "string" && value.length <= 2048 && /^https:\/\/(?:www\.)?espn\.com\/[a-zA-Z0-9_./?=&%+~-]*$/.test(value) ? value : ""
}
function news(data, teamIds) {
  if (!data || !Array.isArray(data.articles)) return []
  var seen = Object.create(null), result = []
  data.articles.slice(0, 100).forEach(function(article) {
    if (!article || typeof article !== "object") return
    var link = webLink(article.links && article.links.web && article.links.web.href)
    var headline = plain(article.headline)
    if (!link || !headline || seen[link]) return
    var categories = Array.isArray(article.categories) ? article.categories.slice(0, 100) : []
    var matches = !teamIds || !teamIds.length || categories.some(function(c) {
      return c && c.type === "team" && teamIds.indexOf(String(c.teamId)) !== -1
    })
    if (!matches) return
    seen[link] = true
    result.push({title: headline, url: link, published: plain(article.published, 40),
      byline: plain(article.byline, 120), premium: article.premium === true,
      transfer: categories.some(function(c) { return c && c.type === "topic" && /transfer/i.test(c.description || "") })})
  })
  return result
}
function videos(data) {
  if (!data || !Array.isArray(data.videos)) return []
  var seen = Object.create(null), result = []
  data.videos.slice(0, 30).forEach(function(v) {
    if (!v) return
    var url = webLink(v.links && v.links.web && v.links.web.href)
    var title = plain(v.headline)
    if (!url || !title || seen[url]) return
    seen[url] = true
    result.push({title: title, url: url, duration: typeof v.duration === "number" && isFinite(v.duration) ? Math.max(0, Math.min(86400, v.duration)) : 0})
  })
  return result
}
function gameLog(data) {
  if (!data || !Array.isArray(data.names) || !Array.isArray(data.seasonTypes)) return []
  var names = data.names.slice(0, 80), labels = Array.isArray(data.labels) ? data.labels : []
  var metadata = data.events && typeof data.events === "object" ? data.events : {}
  var seen = Object.create(null), rows = []
  data.seasonTypes.slice(0, 10).forEach(function(season) {
    if (!season || !Array.isArray(season.categories)) return
    season.categories.slice(0, 20).forEach(function(category) {
      if (!category || !Array.isArray(category.events)) return
      category.events.slice(0, 100).forEach(function(event) {
        if (!event || !/^[0-9]{1,20}$/.test(String(event.eventId)) || !Array.isArray(event.stats)) return
        var id = String(event.eventId), key = String(season.displayName) + ":" + id
        if (seen[key] || rows.length >= 100) return
        seen[key] = true
        var meta = metadata[id] || {}, stats = []
        names.forEach(function(name, index) {
          if (typeof name !== "string" || index >= event.stats.length) return
          var value = event.stats[index]
          if (typeof value !== "string" && typeof value !== "number") return
          stats.push({name: plain(name, 80), label: plain(labels[index] || name, 80), value: plain(String(value), 40)})
        })
        var links = Array.isArray(meta.links) ? meta.links : [], url = ""
        links.slice(0, 20).some(function(link) {
          if (link && Array.isArray(link.rel) && link.rel.indexOf("summary") !== -1) url = webLink(link.href)
          return url !== ""
        })
        var opponent = meta.opponent || {}
        rows.push({id: id, date: plain(meta.gameDate || meta.date, 40),
          opponent: plain(opponent.displayName || opponent.shortDisplayName || opponent.abbreviation || "Opponent unavailable", 120),
          competition: plain(season.displayName, 120), stats: stats, url: url})
      })
    })
  })
  return rows.sort(function(a, b) { return (Date.parse(b.date) || 0) - (Date.parse(a.date) || 0) })
}
