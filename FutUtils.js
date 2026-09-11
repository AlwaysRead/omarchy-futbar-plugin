.pragma library

// Shared utility and sanitization functions for FutBar plugin
function parseFavorite(txt) {
  if (!txt || typeof txt !== "string" || txt.length > 65536) return ({})
  try {
    var parsed = JSON.parse(txt)
    return parsed && typeof parsed === "object" ? parsed : ({})
  } catch (e) { return ({}) }
}

function toBool(val, fallback) {
  if (val === true || val === 1) return true
  if (val === false || val === 0) return false
  if (typeof val === "string") {
    var s = val.trim().toLowerCase()
    if (s === "true" || s === "1") return true
    if (s === "false" || s === "0" || s === "") return false
  }
  return fallback
}

function safeIdentifier(val) {
  if (!val || typeof val !== "string") return ""
  var trimmed = val.trim()
  return /^[a-zA-Z0-9_.\-]+$/.test(trimmed) ? trimmed : ""
}

function sanitizePlainText(raw) {
  if (raw === undefined || raw === null) return ""
  var str = String(raw)
  str = str.replace(/&#(?:60|0*60|x0*3c|x0*3C);/gi, '<')
           .replace(/&#(?:62|0*62|x0*3e|x0*3E);/gi, '>')
           .replace(/&lt;/gi, '<')
           .replace(/&gt;/gi, '>')
           .replace(/&quot;/gi, '"')
           .replace(/&apos;/gi, "'")
           .replace(/&#39;/gi, "'")
           .replace(/&amp;/gi, '&')
  str = str.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]/g, '')
  var prev = ""
  while (prev !== str) {
    prev = str
    str = str.replace(/<[^<>]*>/g, '')
  }
  str = str.replace(/[<>]/g, '')
  str = str.replace(/&(?:[a-zA-Z0-9]+|#\d+|#x[0-9a-fA-F]+);/g, '')
  return str.trim()
}

function sanitizeImageUrl(raw) {
  if (!raw || typeof raw !== "string") return ""
  var url = raw.trim()
  if (url.indexOf("http://") === 0) {
    url = "https://" + url.substring(7)
  }
  if (!/^https:\/\/[a-zA-Z0-9\-\._~:\/\?#\[\]@!\$&'\(\)\*\+,;=%]+$/.test(url)) {
    return ""
  }
  // Automatically upgrade lower-resolution ESPN CDN URLs to crisp 500px high-res assets
  url = url.replace(/\/soccer\/(?:50|100|200)\//g, "/soccer/500/")
           .replace(/\/leaguelogos\/soccer\/(?:50|100|200)\//g, "/leaguelogos/soccer/500/")
           .replace(/\/teamlogos\/soccer\/(?:50|100|200)\//g, "/teamlogos/soccer/500/")
           .replace(/\/teamlogos\/countries\/(?:50|100|200)\//g, "/teamlogos/countries/500/")
           .replace(/\/countries\/(?:50|100|200)\//g, "/countries/500/")
           .replace(/&w=\d+/g, "&w=500")
           .replace(/&h=\d+/g, "&h=500")
  return url
}
