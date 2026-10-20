.pragma library

function interval(live, opened, nearKickoff, failures, liveSeconds, jitter) {
  var base = live ? Math.max(10,Math.min(60,liveSeconds))*1000 : opened || nearKickoff ? 60000 : 300000
  if (!failures) return base
  return Math.min(300000,Math.max(15000,base)*Math.pow(2,Math.min(6,failures))) + Math.floor(Math.max(0,Math.min(1,jitter))*1000)
}
