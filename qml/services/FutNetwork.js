.pragma library

function helperPath(name) {
  return decodeURIComponent(Qt.resolvedUrl("../../lib/" + name).toString().replace(/^file:\/\//, ""))
}
function jsonCommand(urls, limit, timeout) {
  return ["python3", "-E", "-s", helperPath("fetch_json.py"), String(timeout), String(limit)].concat(urls)
}
function imageCommand(url) {
  return ["python3", "-E", "-s", helperPath("fetch_image.py"), url]
}
function statsCommand(mode, urls) {
  return ["python3", "-E", "-s", helperPath("aggregate_stats.py"), mode, JSON.stringify(urls)]
}
function safeProfileUrl(value) {
  if (typeof value !== "string" || value.length > 2048) return ""
  return /^https:\/\/(?:www\.)?espn\.com\/[a-zA-Z0-9_./?=&%+~-]*$/.test(value) ? value : ""
}
