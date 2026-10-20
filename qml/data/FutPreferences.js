.pragma library

var booleans = ["enableNotifications","notifyGoals","notifyEvents","notifyAudio","antiSpoiler","showOdds","enableTrending","reducedMotion","quietHours","notifySchedule","notifyLineups"]
var enums = {tabLabelStyle:["abbrev","short","full"],barWidgetMode:["icon","score","next"],timeFormat:["12h","24h","relative"],kickoffTimeFormat:["12h","24h","relative"],notifyScope:["primary","all"],livePollRate:[10,30,60],reminderMinutes:[0,5,15,30],quietStart:[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23],quietEnd:[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23],density:["compact","comfortable"]}
function cleanText(value, limit) { return typeof value === "string" ? value.replace(/[\u0000-\u001f\u007f]/g," ").slice(0,limit || 160) : "" }
function validId(value) { return typeof value === "string" && /^[A-Za-z0-9_.-]{1,80}$/.test(value) }
function tab(value) {
  if (!value || typeof value !== "object" || !validId(value.league)) throw new Error("Invalid followed league")
  if (value.followLeague === true) return {teamName:"",teamId:"",league:value.league,followLeague:true}
  if (!validId(value.teamId) || !cleanText(value.teamName)) throw new Error("Invalid followed club")
  return {teamName:cleanText(value.teamName),teamId:value.teamId,league:value.league,followLeague:false}
}
function validate(settings) {
  if (!settings || typeof settings !== "object" || Array.isArray(settings)) throw new Error("Expected settings object")
  var out = {}
  booleans.forEach(function(key) {
    if (settings[key] !== undefined) {
      if (typeof settings[key] !== "boolean") throw new Error("Invalid " + key)
      out[key] = settings[key]
    }
  })
  Object.keys(enums).forEach(function(key) {
    if (settings[key] !== undefined) {
      if (enums[key].indexOf(settings[key]) < 0) throw new Error("Invalid " + key)
      out[key] = settings[key]
    }
  })
  var tabs = settings.tabOrder || settings.followedTeams
  if (tabs !== undefined) {
    if (!Array.isArray(tabs) || tabs.length > 24) throw new Error("Too many followed tabs")
    out.tabOrder = tabs.map(tab)
    out.followedTeams = out.tabOrder
  }
  if (settings.league !== undefined) {
    var primary = tab(settings)
    out.teamName = primary.teamName; out.teamId = primary.teamId; out.league = primary.league; out.followLeague = primary.followLeague
  }
  if (settings.mutedClubs !== undefined) {
    if (!Array.isArray(settings.mutedClubs) || settings.mutedClubs.length > 24 || settings.mutedClubs.some(function(id) { return !validId(id) })) throw new Error("Invalid muted clubs")
    out.mutedClubs = settings.mutedClubs.slice()
  }
  return out
}
function backup(settings) { return JSON.stringify({format:"futbar-settings",version:1,settings:validate(settings)},null,2)+"\n" }
function restore(raw) {
  if (typeof raw !== "string" || raw.length > 65536) throw new Error("Backup exceeds 64 KiB")
  var data = JSON.parse(raw)
  if (!data || data.format !== "futbar-settings" || data.version !== 1) throw new Error("Unsupported backup version")
  return validate(data.settings)
}
function quiet(now, enabled, start, end, snoozeUntil) {
  if (now < snoozeUntil) return true
  if (!enabled || start === end) return false
  var hour = new Date(now).getHours()
  return start < end ? hour >= start && hour < end : hour >= start || hour < end
}
