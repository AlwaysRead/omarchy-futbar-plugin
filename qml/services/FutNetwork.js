.pragma library

function helperPath(name) {
  return decodeURIComponent(Qt.resolvedUrl("../../lib/" + name).toString().replace(/^file:\/\//, ""))
}
function jsonCommand(urls, limit, timeout) {
  return ["python3", "-B", "-E", "-s", helperPath("fetch_json.py"), String(timeout), String(limit)].concat(urls)
}
function imageSource(url) {
  // ESPN jerseys are 1440px stitcher images. Route only this exact endpoint
  // through the already permitted CDN resizer; the PNG helper keeps its limits.
  if (typeof url === "string" && url.length <= 2048 && /^https:\/\/stitcher\.espn\.com\/sports\/soccer\/leagues\/[a-z0-9_.-]{1,64}\/events\/\d{1,16}\/athletes\/\d{1,16}\/jersey\.png\?darkMode=(?:true|false)$/.test(url)) {
    return "https://a.espncdn.com/combiner/i?img=" + encodeURIComponent(url) + "&w=128&h=128"
  }
  return url
}
function imageCommand(url) {
  return ["python3", "-B", "-E", "-s", helperPath("fetch_image.py"), imageSource(url)]
}
function statsCommand(mode, urls) {
  return ["python3", "-B", "-E", "-s", helperPath("aggregate_stats.py"), mode, JSON.stringify(urls)]
}
function safeProfileUrl(value) {
  if (typeof value !== "string" || value.length > 2048) return ""
  return /^https:\/\/(?:www\.)?espn\.com\/[a-zA-Z0-9_./?=&%+~-]*$/.test(value) ? value : ""
}
function requestError(stderr, code) {
  if (/not_found/.test(stderr || "")) return "ESPN has no data for this selection."
  if (code === 124 || /timed out|timeout/i.test(stderr || "")) return "Request timed out. Retry shortly."
  if (/busy/.test(stderr || "")) return "Request queue is busy. Retry shortly."
  if (/rate_limited/.test(stderr || "")) return "ESPN is rate limiting requests. Retry later."
  if (/offline/.test(stderr || "")) return "Connection unavailable. Check your network and retry."
  if (/invalid_data/.test(stderr || "")) return "ESPN returned unsupported data. Retry later."
  return "Could not load ESPN data. Retry shortly."
}
function photoCommand(url) {
  return ["python3", "-B", "-E", "-s", helperPath("fetch_photo.py"), url]
}
