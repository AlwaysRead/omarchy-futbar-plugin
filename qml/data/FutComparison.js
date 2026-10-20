.pragma library
function number(value) {
  if (typeof value !== "string" && typeof value !== "number") return "—"
  var s = String(value)
  return /^\d+(?:\.\d+)?$/.test(s) && Number(s) <= 1e9 ? s : "—"
}
function snapshot(profile, kind, context) {
  var fields = kind === "player" ? [["Appearances","seasonAppearances"],["Goals","seasonGoals"],["Assists","seasonAssists"]] :
    [["Played","gamesPlayed"],["Points","points"],["Wins","wins"],["Draws","ties"],["Losses","losses"],["Goals for","goalsFor"],["Goals against","goalsAgainst"]]
  var name = typeof profile.fullName === "string" ? profile.fullName : typeof profile.displayName === "string" ? profile.displayName : ""
  return {id:typeof profile.id === "string" || typeof profile.id === "number" ? String(profile.id).slice(0,80) : "",kind:kind,name:name.slice(0,160),
    context:context,values:fields.map(function(f) { return {label:f[0],value:number(profile[f[1]])} }),
    form:kind === "club" ? (typeof profile.form === "string" ? profile.form : "").replace(/[^WDL]/g,"").slice(-5) : "",time:Date.now()}
}
function compatible(a,b) { return a && b && a.kind === b.kind && a.context !== "" && a.context === b.context }
