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
