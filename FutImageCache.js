.pragma library

// Shared by all views, so large lists cannot start unbounded helper processes.
var active = 0
var entries = Object.create(null)
var order = []
var bytes = 0
function acquire() {
  if (active >= 4) return false
  active++
  return true
}
function release() { active = Math.max(0, active - 1) }
function lookup(url) {
  var entry = entries[url]
  return entry && Date.now() - entry.time < 300000 ? entry.data : undefined
}
function remember(url, data) {
  if (entries[url]) {
    bytes -= entries[url].data.length
    order.splice(order.indexOf(url), 1)
  }
  entries[url] = { data: data, time: Date.now() }
  order.push(url)
  bytes += data.length
  while (order.length > 128 || bytes > 8 * 1024 * 1024) {
    var oldest = order.shift()
    bytes -= entries[oldest].data.length
    delete entries[oldest]
  }
}
