.pragma library
var maximumPins = 4
function number(value) {
  if (typeof value !== "string" && typeof value !== "number") return "—"
  var s = String(value)
  return /^\d+(?:\.\d+)?$/.test(s) && Number(s) <= 1e9 ? s : "—"
}
function snapshot(profile, kind, context, identity, providerStats) {
  var fields = kind === "player" ? [["Appearances","seasonAppearances","appearances"],["Minutes","seasonMinutes","minutes"],["Goals","seasonGoals","totalGoals"],["Assists","seasonAssists","goalAssists"],["Shots","seasonShots","totalShots"],["On target","seasonShotsOnTarget","shotsOnTarget"],["Key passes","seasonKeyPasses","shotAssists"],["Tackles","seasonTackles","effectiveTackles"],["Interceptions","seasonInterceptions","interceptions"],["Yellow cards","seasonYellowCards","yellowCards"],["Red cards","seasonRedCards","redCards"],["Saves","seasonSaves","saves"],["Clean sheets","seasonCleanSheets","cleanSheet"]] :
    [["Played","gamesPlayed"],["Points","points"],["Wins","wins"],["Draws","ties"],["Losses","losses"],["Goals for","goalsFor"],["Goals against","goalsAgainst"]]
  var name = typeof profile.fullName === "string" ? profile.fullName : typeof profile.displayName === "string" ? profile.displayName : ""
  var id = identity !== undefined ? identity : profile.id
  return {id:/^\d{1,16}$/.test(String(id)) ? String(id) : "",kind:kind,name:name.slice(0,160),
    context:context,values:fields.map(function(f) { return {label:f[0],value:number(providerStats !== undefined && kind === "player" ? providerStats[f[2]] : profile[f[1]])} }),
    form:kind === "club" ? (typeof profile.form === "string" ? profile.form : "").replace(/[^WDL]/g,"").slice(-5) : "",time:Date.now()}
}
function compatible(a,b) { return a && b && a.kind === b.kind && a.context !== "" && a.context === b.context }

function indexOf(profiles, kind, id) {
  if (!Array.isArray(profiles) || !id) return -1
  for (var i=0;i<profiles.length;i++) if(profiles[i].kind===kind && profiles[i].id===String(id)) return i
  return -1
}
function pin(profiles, candidate) {
  var current = Array.isArray(profiles) ? profiles.slice(0,maximumPins) : []
  if (!candidate || !/^\d{1,16}$/.test(candidate.id) || (candidate.kind!=="player" && candidate.kind!=="club")) return {profiles:current,error:"This profile has no valid ESPN ID yet."}
  if (current.length && current[0].kind!==candidate.kind) return {profiles:current,error:"Clear the current pins to compare " + (candidate.kind==="player" ? "players." : "clubs.")}
  var index=indexOf(current,candidate.kind,candidate.id)
  if(index>=0) {current[index]=candidate;return {profiles:current,error:"",updated:true}}
  if(current.length>=maximumPins) return {profiles:current,error:"All four comparison slots are full. Remove one to add another."}
  current.push(candidate)
  return {profiles:current,error:"",updated:false}
}
function remove(profiles, kind, id) {
  return Array.isArray(profiles) ? profiles.filter(function(p) {return p.kind!==kind || p.id!==String(id)}) : []
}

// Missing provider values remain unknown, including a metric absent from one player.
function rows(profiles) {
  if (!profiles || profiles.length < 2 || profiles.length > maximumPins) return []
  var labels=[]
  profiles.forEach(function(p) {p.values.forEach(function(v) {if(labels.indexOf(v.label)<0) labels.push(v.label)})})
  return labels.map(function(label) {
    var values=profiles.map(function(p) {
      for(var i=0;i<p.values.length;i++) if(p.values[i].label===label) return p.values[i].value
      return "—"
    })
    return {label:label,values:values,left:values[0],right:values[1]}
  }).filter(function(row) {return row.values.some(function(v) {return v!=="—"})})
}
function sameContext(profiles) {
  return profiles.length>=2 && profiles.every(function(p) {return compatible(profiles[0],p)})
}
