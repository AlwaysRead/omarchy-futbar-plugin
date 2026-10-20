.pragma library

function plain(value, limit) {
  return typeof value === "string" ? value.replace(/[\u0000-\u001f\u007f]/g, " ").slice(0, limit || 512) : ""
}
function webLink(value) {
  return typeof value === "string" && value.length <= 2048 && /^https:\/\/(?:www\.)?espn\.com\/[a-zA-Z0-9_./?=&%+~-]*$/.test(value) ? value : ""
}
function news(data) {
  if (!data || !Array.isArray(data.articles)) return []
  var seen = Object.create(null), result = []
  data.articles.slice(0, 100).forEach(function(article) {
    if (!article || typeof article !== "object") return
    var link = webLink(article.links && article.links.web && article.links.web.href)
    var headline = plain(article.headline)
    if (!link || !headline || seen[link]) return
    var categories = Array.isArray(article.categories) ? article.categories.slice(0, 100) : []
    seen[link] = true
    var images = Array.isArray(article.images) ? article.images.slice(0, 20) : []
    var photo = null
    for (var i = 0; i < images.length; i++) {
      if (images[i] && imageLink(images[i].url)) { photo = images[i]; break }
    }
    result.push({description: plain(article.description, 4000),
      image: photo ? imageLink(photo.url) : "", credit: photo ? plain(photo.credit, 160) : "",
      title: headline, url: link, published: plain(article.published, 40),
      byline: plain(article.byline, 120), premium: article.premium === true,
      transfer: categories.some(function(c) { return c && c.type === "topic" && /transfer/i.test(c.description || "") })})
  })
  return result
}
function imageLink(value) {
  return typeof value === "string" && value.length <= 2048 && /^https:\/\/a\.espncdn\.com\/[a-zA-Z0-9_./?=&%+~,;:@!-]*$/.test(value) ? value : ""
}
