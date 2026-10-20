import QtQuick
import Quickshell.Io
import "../components"
import "../data/FutData.js" as FutData
import "../services/FutNetwork.js" as FutNetwork

// Transitional controller: request/parsing lifetime is separate from panel layout.
// Existing profile models remain owned by the panel to preserve view contracts.
Item {
  id: profileRequests
  visible: false
  property var root: null
  readonly property var requests: [internalSearchRequest, internalSearchPlayerDetailRequest, internalSearchPlayerStatsRequest, internalSearchPlayerSeasonStatsRequest, internalSearchCompQueueRequest, internalSearchPlayerBioRequest, internalSearchTransferTeamRequest, internalSearchPlayerTransactionsRequest, internalSearchPlayerLogRequest, internalSearchTeamNameRequest, internalSearchClubStatRequest, internalSearchCareerAggRequest, internalSearchClubDetailRequest, internalSearchClubScheduleRequest, internalSearchClubStatsRequest, internalSearchClubCoreRequest, internalSearchClubFixturesRequest, internalSearchClubStandingsRequest, internalSearchClubRosterRequest]
  readonly property var searchRequest: internalSearchRequest
  readonly property var searchPlayerDetailRequest: internalSearchPlayerDetailRequest
  readonly property var searchPlayerStatsRequest: internalSearchPlayerStatsRequest
  readonly property var searchPlayerSeasonStatsRequest: internalSearchPlayerSeasonStatsRequest
  readonly property var searchCompQueueRequest: internalSearchCompQueueRequest
  readonly property var searchPlayerBioRequest: internalSearchPlayerBioRequest
  readonly property var searchTransferTeamRequest: internalSearchTransferTeamRequest
  readonly property var searchPlayerTransactionsRequest: internalSearchPlayerTransactionsRequest
  readonly property var searchPlayerLogRequest: internalSearchPlayerLogRequest
  readonly property var searchTeamNameRequest: internalSearchTeamNameRequest
  readonly property var searchClubStatRequest: internalSearchClubStatRequest
  readonly property var searchCareerAggRequest: internalSearchCareerAggRequest
  readonly property var clubFetchTimeoutTimer: internalClubFetchTimeoutTimer
  readonly property var playerStatsTimeoutTimer: internalPlayerStatsTimeoutTimer
  readonly property var searchClubDetailRequest: internalSearchClubDetailRequest
  readonly property var searchClubScheduleRequest: internalSearchClubScheduleRequest
  readonly property var searchClubStatsRequest: internalSearchClubStatsRequest
  readonly property var searchClubCoreRequest: internalSearchClubCoreRequest
  readonly property var searchClubFixturesRequest: internalSearchClubFixturesRequest
  readonly property var searchClubStandingsRequest: internalSearchClubStandingsRequest
  readonly property var searchClubRosterRequest: internalSearchClubRosterRequest

  FutContextProcess {
    id: internalSearchRequest
    requestContext: root.searchQuery
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchRequest.responseCurrent) return
        root.searchLoading = false
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) {
          return
        }
        try {
          var data = JSON.parse(text)
          var list = []
          var res = Array.isArray(data.results) ? data.results : []
          for (var i = 0; i < res.length; i++) {
            var group = res[i]
            var contents = Array.isArray(group.contents) ? group.contents : []
            for (var j = 0; j < contents.length; j++) {
              var item = contents[j]
              if (!item) continue
              var sport = String(item.sport || "").toLowerCase()
              if (sport !== "" && sport !== "soccer") continue
              var itemType = String(item.type || group.type || "").toLowerCase()
              if (itemType !== "player" && itemType !== "team") continue
              var rawId = ""
              var rawUid = String(item.uid || "")
              if (rawUid.indexOf("~a:") !== -1) {
                rawId = rawUid.substring(rawUid.indexOf("~a:") + 3)
              } else if (rawUid.indexOf("~t:") !== -1) {
                rawId = rawUid.substring(rawUid.indexOf("~t:") + 3)
              } else if (item.id) {
                rawId = String(item.id)
              }
              var img = ""
              if (item.image && typeof item.image === "object") {
                img = item.image.default || item.image.defaultDark || ""
              } else if (typeof item.image === "string") {
                img = item.image
              }
              list.push({
                type: itemType,
                id: rawId,
                uid: rawUid,
                displayName: root.sanitizePlainText(String(item.displayName || "")),
                subtitle: root.sanitizePlainText(String(item.subtitle || item.description || "")),
                description: root.sanitizePlainText(String(item.description || "")),
                leagueSlug: String(item.defaultLeagueSlug || ""),
                image: img,
                webUrl: item.link && item.link.web ? String(item.link.web) : ""
              })
            }
          }
          root.searchResults = list
          root.searchError = list.length === 0 ? "No players or clubs found" : ""
        } catch (e) {
          root.searchError = "Could not parse search results"
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchRequest.responseCurrent) return
        root.searchLoading = false
      }
    }
  }

  FutContextProcess {
    id: internalSearchPlayerDetailRequest
    requestContext: String(root.selectedPlayerProfile ? root.selectedPlayerProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchPlayerDetailRequest.responseCurrent) return
        root.searchPlayerLoading = false
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152) {
          return
        }
        try {
          var p = JSON.parse(text)
          if (p) {
            var teamRef = p.defaultTeam && p.defaultTeam["$ref"] ? String(p.defaultTeam["$ref"]) : ""
            var teamIdMatch = teamRef.match(/\/teams\/(\d+)/)
            var resolvedTeamId = teamIdMatch ? teamIdMatch[1] : ""
            var teamCrestUrl = resolvedTeamId !== "" ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + resolvedTeamId + ".png") : ""
            var dLgRef = p.defaultLeague && p.defaultLeague["$ref"] ? String(p.defaultLeague["$ref"]) : ""
            var dLgMatch = dLgRef.match(/\/leagues\/([a-zA-Z0-9_.-]+)/)
            if (dLgMatch && dLgMatch[1]) {
              root.statsPlayerLeague = dLgMatch[1]
            }
            var dobStr = ""
            if (p.dateOfBirth) {
              try {
                var d = new Date(p.dateOfBirth)
                dobStr = Qt.formatDate(d, "MMM d, yyyy")
              } catch (ed) { dobStr = String(p.dateOfBirth) }
            }
            var bCity = p.birthPlace && p.birthPlace.city ? String(p.birthPlace.city) : ""
            var bCountry = p.birthPlace && p.birthPlace.country ? String(p.birthPlace.country) : ""
            var birthplace = bCity !== "" ? (bCountry !== "" ? bCity + ", " + bCountry : bCity) : bCountry
            var prof = Object.assign({}, root.selectedPlayerProfile || {})
            prof.fullName = root.sanitizePlainText(String(p.fullName || p.displayName || prof.fullName || ""))
            prof.jersey = root.sanitizePlainText(p.jersey ? String(p.jersey) : (prof.jersey || ""))
            prof.age = root.sanitizePlainText(p.age ? String(p.age) : (prof.age || ""))
            prof.position = root.sanitizePlainText(p.position && p.position.displayName ? String(p.position.displayName) : (p.position && p.position.name ? String(p.position.name) : (prof.position || "")))
            prof.displayHeight = root.sanitizePlainText(p.displayHeight ? String(p.displayHeight) : (prof.displayHeight || ""))
            prof.displayWeight = root.sanitizePlainText(p.displayWeight ? String(p.displayWeight) : (prof.displayWeight || ""))
            prof.citizenship = root.sanitizePlainText(p.citizenship ? String(p.citizenship) : (p.citizenshipCountry ? String(p.citizenshipCountry) : (prof.citizenship || "")))
            prof.birthplace = root.sanitizePlainText(birthplace !== "" ? birthplace : (prof.birthplace || ""))
            prof.dateOfBirth = root.sanitizePlainText(dobStr !== "" ? dobStr : (prof.dateOfBirth || ""))
            prof.status = root.sanitizePlainText(p.status && p.status.name ? String(p.status.name) : (prof.status || "Active"))
            if (p.headshot && p.headshot.href) prof.headshot = String(p.headshot.href)
            if (p.flag && p.flag.href) prof.flag = String(p.flag.href)
            if (teamCrestUrl !== "") prof.teamCrest = teamCrestUrl
            root.selectedPlayerProfile = prof
          }
        } catch (e) {}
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchPlayerDetailRequest.responseCurrent) return
        root.searchPlayerLoading = false
      }
    }
  }

  FutContextProcess {
    id: internalSearchPlayerStatsRequest
    requestContext: String(root.selectedPlayerProfile ? root.selectedPlayerProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchPlayerStatsRequest.responseCurrent) return
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152 || !root.selectedPlayerProfile) return
        try {
          var data = JSON.parse(text)
          var cats = data && Array.isArray(data.splits && data.splits.categories) ? data.splits.categories : []
          var statMap = {}
          for (var ci = 0; ci < cats.length; ci++) {
            var stList = cats[ci].stats || []
            for (var si = 0; si < stList.length; si++) {
              statMap[stList[si].name] = String(stList[si].displayValue !== undefined ? stList[si].displayValue : stList[si].value)
            }
          }
          var prof = root.selectedPlayerProfile
          if (prof) {
            var num = function(v) { var n = parseFloat(v); return isNaN(n) ? -1 : n }
            var shotsSum = ""
            var inBox = num(statMap["attemptsInBox"])
            var outBox = num(statMap["attemptsOutBox"])
            if (inBox >= 0 && outBox >= 0) shotsSum = String(Math.round(inBox + outBox))
            else if (inBox >= 0) shotsSum = String(Math.round(inBox))
            else if (outBox >= 0) shotsSum = String(Math.round(outBox))
            prof.careerAppearances = statMap["appearances"] || ""
            prof.careerGoals = statMap["totalGoals"] || ""
            prof.careerAssists = statMap["goalAssists"] || ""
            prof.careerKeyPasses = statMap["shotAssists"] || ""
            prof.careerPasses = statMap["accuratePasses"] || statMap["totalPasses"] || ""
            prof.careerPassPct = statMap["passPct"] ? (Math.round(parseFloat(statMap["passPct"]) * 100) + "%") : ""
            prof.careerFreeKicks = statMap["freeKickGoals"] || ""
            prof.careerTackles = statMap["effectiveTackles"] || statMap["totalTackles"] || ""
            prof.careerInterceptions = statMap["interceptions"] || ""
            prof.careerShots = statMap["totalShots"] || shotsSum
            prof.careerShotsOnTarget = statMap["shotsOnTarget"] || ""
            prof.careerSaves = statMap["saves"] || ""
            prof.careerCleanSheets = statMap["cleanSheet"] || ""
            if (statMap["passPct"]) statMap["passPct"] = prof.careerPassPct
            prof.careerStatMap = statMap

            var lb = statMap["accurateLongBalls"] || statMap["totalLongBalls"] || ""
            var kp = statMap["shotAssists"] || ""
            if (lb !== "") prof.longBalls = lb
            if (kp !== "") prof.keyPasses = kp
            if (prof.longBalls && prof.keyPasses) {
              prof.passDistribution = prof.longBalls + " LB · " + prof.keyPasses + " KP"
            }
            if ((!prof.goalConversionRate || prof.goalConversionRate === "—") && prof.careerShots && prof.careerGoals) {
              var cShots = parseFloat(prof.careerShots) || 0
              var cGoals = parseFloat(prof.careerGoals) || 0
              if (cShots > 0) {
                prof.goalConversionRate = ((cGoals / cShots) * 100).toFixed(1) + "%"
              }
            }
            if ((!prof.shotAccuracy || prof.shotAccuracy === "—") && prof.careerShots && prof.careerShotsOnTarget) {
              var cShots2 = parseFloat(prof.careerShots) || 0
              var cSog = parseFloat(prof.careerShotsOnTarget) || 0
              if (cShots2 > 0) {
                prof.shotAccuracy = Math.round((cSog / cShots2) * 100) + "%"
              }
            }

            root.selectedPlayerProfile = Object.assign({}, prof)
            root.playerStatsLoading = false
            if (root.searchPlayerStatsTab === "career") {
              root.applyPlayerStatsView()
            }
          }
        } catch (e) {}
      }
    }
  }
  FutContextProcess {
    id: internalSearchPlayerSeasonStatsRequest
    requestContext: String(root.selectedPlayerProfile ? root.selectedPlayerProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchPlayerSeasonStatsRequest.responseCurrent) return
        var curCmd = internalSearchPlayerSeasonStatsRequest.command
        var curCompUrl = (curCmd && curCmd.length > 0) ? curCmd[curCmd.length - 1] : ""
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152 || !root.selectedPlayerProfile) {
          if (curCompUrl !== "") {
            if (!root.playerCompStatCache) root.playerCompStatCache = ({})
            root.playerCompStatCache[curCompUrl] = ({})
          }
          root.playerStatsLoading = false
          return
        }
        try {
          var data = JSON.parse(text)
          var cats = data && Array.isArray(data.splits && data.splits.categories) ? data.splits.categories : []
          var statMap = {}
          for (var ci = 0; ci < cats.length; ci++) {
            var stList = cats[ci].stats || []
            for (var si = 0; si < stList.length; si++) {
              statMap[stList[si].name] = String(stList[si].displayValue !== undefined ? stList[si].displayValue : stList[si].value)
            }
          }
          if (curCompUrl !== "") {
            if (!root.playerCompStatCache) root.playerCompStatCache = ({})
            root.playerCompStatCache[curCompUrl] = statMap
          }
          root.applyPlayerStatsView()
        } catch (e) {
          if (curCompUrl !== "") {
            if (!root.playerCompStatCache) root.playerCompStatCache = ({})
            root.playerCompStatCache[curCompUrl] = ({})
          }
          root.playerStatsLoading = false
        }
      }
    }
  }

  FutContextProcess {
    id: internalSearchCompQueueRequest
    requestContext: String(root.selectedPlayerProfile ? root.selectedPlayerProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchCompQueueRequest.responseCurrent) return
        var finishedUrl = root.compStatInFlightUrl
        var finishedGen = root.compStatInFlightGen
        root.compStatInFlightUrl = ""
        root.compStatInFlightGen = 0
        if (finishedUrl !== "" && finishedGen === root._compStatRequestGen) {
          var statMap = {}
          if (typeof text === "string" && text.length > 0 && text.length <= 2097152) {
            try {
              var data = JSON.parse(text)
              var cats = data && Array.isArray(data.splits && data.splits.categories) ? data.splits.categories : []
              for (var ci = 0; ci < cats.length; ci++) {
                var stList = cats[ci].stats || []
                for (var si = 0; si < stList.length; si++) {
                  statMap[stList[si].name] = String(stList[si].displayValue !== undefined ? stList[si].displayValue : stList[si].value)
                }
              }
            } catch (e) {}
          }
          if (!root.playerCompStatCache) root.playerCompStatCache = ({})
          root.playerCompStatCache[finishedUrl] = statMap
        }
        if (root._compStatRequestGen === finishedGen) {
          root.applyPlayerStatsView()
          root._fetchNextCompQueue()
        }
      }
    }
  }

  function resolveTeamNameFromRef(ref) {
    return FutData.resolveTeamNameFromRef(ref, root.teamTabLabel, {
      nameCache: root.teamNameCache,
      shortCache: root.teamShortCache,
      abbrevCache: root.teamAbbrevCache
    }, root.selectedPlayerProfile, root.teamNameForId)
  }

  function isValidEspnApiUrl(url) {
    return FutData.isValidEspnApiUrl(url)
  }

  function formatTransferValue(rawAmt, amtType, currencyObj) {
    return FutData.formatTransferValue(rawAmt, amtType, currencyObj, root.sanitizePlainText)
  }

  function updateTransferTeamNames() {
    var p = root.selectedPlayerProfile
    if (!p || !p.transferHistory || p.transferHistory.length === 0) return
    var changed = false
    var list = p.transferHistory.slice()
    for (var i = 0; i < list.length; i++) {
      var item = Object.assign({}, list[i])
      if (item.fromId) {
        var fn = (root.teamNameCache && root.teamNameCache[item.fromId]) || item.fromName
        var fShort = (root.teamShortCache && root.teamShortCache[item.fromId]) || root.teamTabLabel(fn, "", "short", item.fromId)
        var fAbbr = (root.teamAbbrevCache && root.teamAbbrevCache[item.fromId]) || root.teamTabLabel(fn, "", "abbrev", item.fromId)
        if (item.fromName !== fn || item.fromShort !== fShort || item.fromAbbr !== fAbbr) {
          item.fromName = fn
          item.fromShort = fShort
          item.fromAbbr = fAbbr
          changed = true
        }
      }
      if (item.toId) {
        var tn = (root.teamNameCache && root.teamNameCache[item.toId]) || item.toName
        var tShort = (root.teamShortCache && root.teamShortCache[item.toId]) || root.teamTabLabel(tn, "", "short", item.toId)
        var tAbbr = (root.teamAbbrevCache && root.teamAbbrevCache[item.toId]) || root.teamTabLabel(tn, "", "abbrev", item.toId)
        if (item.toName !== tn || item.toShort !== tShort || item.toAbbr !== tAbbr) {
          item.toName = tn
          item.toShort = tShort
          item.toAbbr = tAbbr
          changed = true
        }
      }
      if (!item.fromShort && item.fromName) {
        item.fromShort = root.teamTabLabel(item.fromName, "", "short", item.fromId)
        changed = true
      }
      if (!item.toShort && item.toName) {
        item.toShort = root.teamTabLabel(item.toName, "", "short", item.toId)
        changed = true
      }
      if (!item.fromAbbr && item.fromName) {
        item.fromAbbr = root.teamTabLabel(item.fromName, "", "abbrev", item.fromId)
        changed = true
      }
      if (!item.toAbbr && item.toName) {
        item.toAbbr = root.teamTabLabel(item.toName, "", "abbrev", item.toId)
        changed = true
      }
      list[i] = item
    }
    if (changed) {
      p.transferHistory = list
      if (list.length > 0) {
        var last = list[0]
        var yr = last.year ? (" (" + last.year + ")") : ""
        var fStr = last.fromShort || last.fromAbbr || last.fromName || "Unknown"
        var tStr = last.toShort || last.toAbbr || last.toName || "Unknown"
        p.transferInfo = fStr + " → " + tStr + " : " + last.fee + yr
      }
      root.selectedPlayerProfile = Object.assign({}, p)
    }
  }

  function _resolveNextTransferTeam() {
    if (internalSearchTransferTeamRequest.running) return
    if (!root.transferTeamQueue || root.transferTeamQueue.length === 0) return
    var tid = root.transferTeamQueue.shift()
    if (!tid || tid === "") return
    if (root.teamNameCache && root.teamNameCache[tid]) {
      root._resolveNextTransferTeam()
      return
    }
    root._transferTeamInFlight = tid
    internalSearchTransferTeamRequest.command = FutNetwork.jsonCommand(["https://sports.core.api.espn.com/v2/sports/soccer/teams/" + encodeURIComponent(tid)], 1048576, 10)
    internalSearchTransferTeamRequest.running = true
  }

  FutContextProcess {
    id: internalSearchPlayerBioRequest
    requestContext: String(root.selectedPlayerProfile ? root.selectedPlayerProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchPlayerBioRequest.responseCurrent) return
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152 || !root.selectedPlayerProfile) return
        try {
          var data = JSON.parse(text)
          var th = data && Array.isArray(data.teamHistory) ? data.teamHistory : []
          if (!root.teamNameCache) root.teamNameCache = ({})
          var natList = []
          for (var i = 0; i < th.length; i++) {
            var t = th[i]
            if (t && t.id) {
              var tId = String(t.id)
              var tName = String(t.displayName || t.name || "")
              root.teamNameCache[tId] = tName
              var tLogo = String(t.logo || "")
              var tSlug = String(t.slug || "").toLowerCase()
              var tLower = tName.toLowerCase()

              // Check if team is explicitly a club from its links or logo path
              var isClub = false
              if (t.links && Array.isArray(t.links)) {
                for (var li = 0; li < t.links.length; li++) {
                  var href = t.links[li] && t.links[li].href ? String(t.links[li].href) : ""
                  if (href.indexOf("/club/") !== -1) {
                    isClub = true
                    break
                  }
                }
              }
              if (tLogo.indexOf("/teamlogos/soccer/") !== -1 || tLogo.indexOf("/soccer/") !== -1) {
                isClub = true
              }

              // A team is a national team if:
              // 1. Its logo is hosted on the ESPN /countries/ CDN path, OR
              // 2. Its slug is a 2-3 letter country code (e.g. "bra", "arg", "eng", or youth "esp.u23"), OR
              // 3. Its name indicates a national team,
              // AND it is NOT an explicit club team.
              var isCountryLogo = tLogo.indexOf("/countries/") !== -1
              var isCountrySlug = (/^[a-z]{2,3}$/i.test(tSlug)) || (/^[a-z]{2,3}\.u\d+$/i.test(tSlug))
              var isNationalName = tLower.indexOf("national team") !== -1
              var isNat = !isClub && (isCountryLogo || isCountrySlug || isNationalName)

              if (isNat) {
                var isYouth = (tName.match(/\bU-?\d{1,2}\b/i) !== null) || (tSlug.indexOf(".u") !== -1) || (tLower.indexOf("youth") !== -1)
                var rawSeasons = String(t.seasons || "")
                var cleanSeasons = rawSeasons
                var yrMatches = rawSeasons.match(/\b(19\d\d|20\d\d)\b/g)
                if (yrMatches && yrMatches.length > 0) {
                  var minY = parseInt(yrMatches[0])
                  var maxY = parseInt(yrMatches[0])
                  for (var mi = 1; mi < yrMatches.length; mi++) {
                    var yVal = parseInt(yrMatches[mi])
                    if (yVal < minY) minY = yVal
                    if (yVal > maxY) maxY = yVal
                  }
                  cleanSeasons = minY === maxY ? String(minY) : (minY + "–" + maxY)
                }
                var slugCountry = tSlug.split(".")[0]
                var defaultCountryLogo = (slugCountry !== "" && slugCountry.length <= 3) ? ("https://a.espncdn.com/i/teamlogos/countries/500/" + slugCountry + ".png") : ""
                var finalLogo = root.sanitizeImageUrl(tLogo !== "" ? tLogo : (defaultCountryLogo !== "" ? defaultCountryLogo : (root.selectedPlayerProfile ? root.selectedPlayerProfile.flag : "")))

                var existing = false
                for (var ni = 0; ni < natList.length; ni++) {
                  if (natList[ni].id === tId || (natList[ni].name === tName && natList[ni].isYouth === isYouth)) {
                    existing = true
                    break
                  }
                }
                if (existing) continue

                natList.push({
                  id: tId,
                  name: tName,
                  isYouth: isYouth,
                  type: isYouth ? "Youth International" : "Senior National Team",
                  seasons: cleanSeasons,
                  seasonCount: String(t.seasonCount || "1"),
                  logo: finalLogo
                })
              }
            }
          }
          if (root.selectedPlayerProfile) {
            var prof = Object.assign({}, root.selectedPlayerProfile)
            prof.nationalTeams = natList
            root.selectedPlayerProfile = prof
          }
          root.updateTransferTeamNames()
          root._resolveNextTransferTeam()
        } catch (e) {}
      }
    }
  }

  FutContextProcess {
    id: internalSearchTransferTeamRequest
    requestContext: String(root.selectedPlayerProfile ? root.selectedPlayerProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchTransferTeamRequest.responseCurrent) return
        var tid = root._transferTeamInFlight
        root._transferTeamInFlight = ""
        if (tid !== "" && typeof text === "string" && text.length > 0 && text.length <= 1048576) {
          try {
            var data = JSON.parse(text)
            var tName = String(data.displayName || data.name || data.shortDisplayName || "")
            var tShort = String(data.shortDisplayName || data.name || "")
            var tAbbr = String(data.abbreviation || "")
            if (tName !== "") {
              if (!root.teamNameCache) root.teamNameCache = ({})
              root.teamNameCache[tid] = tName
              if (!root.teamShortCache) root.teamShortCache = ({})
              root.teamShortCache[tid] = tShort !== "" ? tShort : root.teamTabLabel(tName, "", "short", tid)
              if (tAbbr !== "") {
                if (!root.teamAbbrevCache) root.teamAbbrevCache = ({})
                root.teamAbbrevCache[tid] = tAbbr.toUpperCase()
              }
              root.updateTransferTeamNames()
            } else {
              if (!root.teamNameCache) root.teamNameCache = ({})
              root.teamNameCache[tid] = "Team " + tid
            }
          } catch (e) {
            if (!root.teamNameCache) root.teamNameCache = ({})
            root.teamNameCache[tid] = "Team " + tid
          }
        } else if (tid !== "") {
          if (!root.teamNameCache) root.teamNameCache = ({})
          root.teamNameCache[tid] = "Team " + tid
        }
        root._resolveNextTransferTeam()
      }
    }
  }

  FutContextProcess {
    id: internalSearchPlayerTransactionsRequest
    requestContext: String(root.selectedPlayerProfile ? root.selectedPlayerProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchPlayerTransactionsRequest.responseCurrent) return
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152 || !root.selectedPlayerProfile) return
        try {
          var data = JSON.parse(text)
          var items = data && Array.isArray(data.items) ? data.items : []
          var txList = []
          for (var ti = 0; ti < items.length; ti++) {
            var item = items[ti]
            if (!item) continue
            var fromRef = item.from && item.from["$ref"] ? String(item.from["$ref"]) : ""
            var toRef = item.to && item.to["$ref"] ? String(item.to["$ref"]) : ""
            var fromInfo = root.resolveTeamNameFromRef(fromRef)
            var toInfo = root.resolveTeamNameFromRef(toRef)

            var rawAmt = item.displayAmount !== undefined ? String(item.displayAmount) : (item.amount !== undefined ? String(item.amount) : "")
            var amtType = item.type ? String(item.type) : ""
            var numVal = Number(rawAmt)
            var feeVal = root.sanitizePlainText(root.formatTransferValue(rawAmt, amtType, item.currency))

            var dStr = ""
            var yStr = ""
            var timestamp = 0
            if (item.date) {
              try {
                var dObj = new Date(item.date)
                if (!isNaN(dObj.getTime())) {
                  timestamp = dObj.getTime()
                  yStr = Qt.formatDate(dObj, "yyyy")
                  dStr = Qt.formatDate(dObj, "MMM yyyy")
                } else {
                  var ym = String(item.date).match(/\b(19\d\d|20\d\d)\b/)
                  if (ym) yStr = ym[1]
                }
              } catch (ed) {
                var ym2 = String(item.date).match(/\b(19\d\d|20\d\d)\b/)
                if (ym2) yStr = ym2[1]
              }
            }

            var athRef = item.athlete && item.athlete["$ref"] ? String(item.athlete["$ref"]) : ""
            var athMatch = athRef.match(/athletes\/(\d+)/)
            var athId = athMatch ? athMatch[1] : (root.statsPlayerKey || "")

            if (fromInfo.id && (!root.teamNameCache || !root.teamNameCache[fromInfo.id])) {
              if (root.transferTeamQueue.indexOf(fromInfo.id) === -1) root.transferTeamQueue.push(fromInfo.id)
            }
            if (toInfo.id && (!root.teamNameCache || !root.teamNameCache[toInfo.id])) {
              if (root.transferTeamQueue.indexOf(toInfo.id) === -1) root.transferTeamQueue.push(toInfo.id)
            }

            txList.push({
              fromName: fromInfo.name || "Unknown",
              fromShort: fromInfo.shortName || root.teamTabLabel(fromInfo.name, "", "short", fromInfo.id) || fromInfo.name || "Unknown",
              fromAbbr: fromInfo.abbrev || root.teamTabLabel(fromInfo.name, "", "abbrev", fromInfo.id) || fromInfo.name || "Unknown",
              fromLogo: fromInfo.logo || "",
              fromId: fromInfo.id || "",
              toName: toInfo.name || "Unknown",
              toShort: toInfo.shortName || root.teamTabLabel(toInfo.name, "", "short", toInfo.id) || toInfo.name || "Unknown",
              toAbbr: toInfo.abbrev || root.teamTabLabel(toInfo.name, "", "abbrev", toInfo.id) || toInfo.name || "Unknown",
              toLogo: toInfo.logo || "",
              toId: toInfo.id || "",
              fee: root.sanitizePlainText(feeVal),
              rawAmount: !isNaN(numVal) ? numVal : 0,
              type: amtType,
              date: dStr !== "" ? dStr : yStr,
              year: yStr,
              timestamp: timestamp
            })
          }

          txList.sort(function(a, b) {
            return (b.timestamp || 0) - (a.timestamp || 0)
          })

          var info = ""
          if (txList.length > 0) {
            var latest = txList[0]
            var yr = latest.year ? (" (" + latest.year + ")") : ""
            var fTxt = latest.fromShort || latest.fromAbbr || latest.fromName || "Unknown"
            var tTxt = latest.toShort || latest.toAbbr || latest.toName || "Unknown"
            info = fTxt + " → " + tTxt + " : " + latest.fee + yr
          }

          var prof = root.selectedPlayerProfile
          if (prof) {
            prof.transferFetched = true
            prof.transferHistory = txList
            if (info !== "") prof.transferInfo = info
            root.selectedPlayerProfile = Object.assign({}, prof)
          }
          root.playerStatsLoading = false
          if (root.transferTeamQueue.length > 0) {
            root._resolveNextTransferTeam()
          }
        } catch (e) {
          root.playerStatsLoading = false
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchPlayerTransactionsRequest.responseCurrent) return
        var prof = root.selectedPlayerProfile
        if (prof && !prof.transferFetched) {
          prof.transferFetched = true
          root.selectedPlayerProfile = Object.assign({}, prof)
        }
        root.playerStatsLoading = false
      }
    }
  }

  FutContextProcess {
    id: internalSearchPlayerLogRequest
    requestContext: String(root.selectedPlayerProfile ? root.selectedPlayerProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchPlayerLogRequest.responseCurrent) return
        if (typeof text !== "string" || text.length === 0 || text.length > 2097152 || !root.selectedPlayerProfile) return
        try {
          var logData = JSON.parse(text)
          var entries = logData && Array.isArray(logData.entries) ? logData.entries : []
          var teamMap = {}
          var isIntlLeague = function(lg) {
            return root.isIntlLeague(lg)
          }
          for (var ei = 0; ei < entries.length; ei++) {
            var entry = entries[ei]
            var sRef = entry.season && entry.season["$ref"] ? String(entry.season["$ref"]) : ""
            var statSets = entry.statistics && Array.isArray(entry.statistics) ? entry.statistics : []
            var totalSet = null
            for (var sj = 0; sj < statSets.length; sj++) {
              if (statSets[sj] && statSets[sj].type === "total") { totalSet = statSets[sj]; break }
            }
            if (!totalSet && statSets.length > 0) totalSet = statSets[0]
            var tRef = totalSet && totalSet.team && totalSet.team["$ref"] ? String(totalSet.team["$ref"]) : ""
            var lRef = totalSet && totalSet.league && totalSet.league["$ref"] ? String(totalSet.league["$ref"]) : ""
            var statUrl = totalSet && totalSet.statistics && totalSet.statistics["$ref"] ? String(totalSet.statistics["$ref"]) : ""
            var sMatch = sRef.match(/\/seasons\/(\d+)/)
            var tMatch = tRef.match(/\/teams\/(\d+)/)
            var lMatch = lRef.match(/\/leagues\/([a-zA-Z0-9_.-]+)/)
            var year = sMatch ? sMatch[1] : ""
            var teamId = tMatch ? tMatch[1] : ""
            var lgSlug = lMatch ? lMatch[1] : ""
            if (teamId !== "" && year !== "") {
              if (root.isPreseasonLeague(lgSlug)) continue
              if (!teamMap[teamId]) {
                teamMap[teamId] = { teamId: teamId, start: parseInt(year), end: parseInt(year), leagues: [], urls: [] }
              } else {
                var yInt = parseInt(year)
                if (yInt < teamMap[teamId].start) teamMap[teamId].start = yInt
                if (yInt > teamMap[teamId].end) teamMap[teamId].end = yInt
              }
              if (lgSlug !== "" && teamMap[teamId].leagues.indexOf(lgSlug) === -1) {
                teamMap[teamId].leagues.push(lgSlug)
              }
              var cleanStatUrl = statUrl.replace(/^http:\/\//i, "https://")
              if (cleanStatUrl !== "" && root.isValidEspnApiUrl(cleanStatUrl) && teamMap[teamId].urls.indexOf(cleanStatUrl) === -1) {
                teamMap[teamId].urls.push(cleanStatUrl)
              }
            }
          }
          var historyList = []
          var tKeys = Object.keys(teamMap)
          for (var ki = 0; ki < tKeys.length; ki++) {
            var tInfo = teamMap[tKeys[ki]]
            // Exclude national teams: only keep teams that played in club leagues
            var hasOnlyIntl = tInfo.leagues.length > 0 && tInfo.leagues.every(isIntlLeague)
            if (hasOnlyIntl) continue
            historyList.push({
              teamId: tInfo.teamId,
              name: (root.teamNameCache && root.teamNameCache[tInfo.teamId]) ? root.teamNameCache[tInfo.teamId] : root.teamNameForId(tInfo.teamId),
              teamLogo: "https://a.espncdn.com/i/teamlogos/soccer/500/" + tInfo.teamId + ".png",
              years: tInfo.start === tInfo.end ? String(tInfo.start) : (tInfo.start + "–" + tInfo.end)
            })
          }
          historyList.sort(function(a, b) {
            var aStart = parseInt(String(a.years).split("–")[0]) || 0
            var bStart = parseInt(String(b.years).split("–")[0]) || 0
            return bStart - aStart
          })
          var prof2 = root.selectedPlayerProfile
          if (prof2) {
            prof2.careerHistory = historyList.slice(0, 10)
            prof2.teamSeasonMap = teamMap
            prof2.clubOptions = []
            prof2.clubStatMap = null
            prof2.clubAggCache = ({})
            prof2.clubFilterId = "all"
            prof2.clubFilterLoading = false
            // Group entries by season year to discover all competitions for each season
            var seasonCompsByYear = {}
            for (var ei = 0; ei < entries.length; ei++) {
              var ent = entries[ei]
              var sRef = ent.season && ent.season["$ref"] ? String(ent.season["$ref"]) : ""
              var statSets = ent.statistics && Array.isArray(ent.statistics) ? ent.statistics : []
              var tSet = null
              for (var sj = 0; sj < statSets.length; sj++) {
                if (statSets[sj] && statSets[sj].type === "total") { tSet = statSets[sj]; break }
              }
              if (!tSet && statSets.length > 0) tSet = statSets[0]
              var lRef = tSet && tSet.league && tSet.league["$ref"] ? String(tSet.league["$ref"]) : ""
              var stUrl = tSet && tSet.statistics && tSet.statistics["$ref"] ? String(tSet.statistics["$ref"]) : ""
              var sMatch = sRef.match(/\/seasons\/(\d+)/)
              var lMatch = lRef.match(/\/leagues\/([a-zA-Z0-9_.-]+)/)
              var yr = sMatch ? parseInt(sMatch[1]) : 0
              var lg = lMatch ? lMatch[1].toLowerCase() : ""
              if (stUrl !== "" && yr > 0) {
                if (root.isPreseasonLeague(lg)) continue
                var isCountryComp = root.isIntlLeague(lg)
                var score = 0
                if (isCountryComp) {
                  score = 5
                } else if (lg.indexOf("super") !== -1 || lg.indexOf("charity") !== -1 || lg.indexOf("campeon") !== -1) {
                  score = 20
                } else if (lg.indexOf("cup") !== -1 || lg.indexOf("fa") !== -1 || lg.indexOf("copa") !== -1 || lg.indexOf("dfb") !== -1 || lg.indexOf("coppa") !== -1) {
                  score = 30
                } else if (lg.indexOf("champions") !== -1 || lg.indexOf("europa") !== -1 || lg.indexOf("libertadores") !== -1) {
                  score = 50
                } else if (/\.[12]$/.test(lg) || lg === "usa.1" || lg === "esp.1" || lg === "eng.1" || lg === "ger.1" || lg === "ita.1" || lg === "fra.1") {
                  score = 100
                } else {
                  score = 40
                }
                if (root.statsPlayerLeague && lg === root.statsPlayerLeague.toLowerCase()) {
                  score += 60
                }
                if (!seasonCompsByYear[yr]) seasonCompsByYear[yr] = []
                var cInfo = root.formatCompetitionName(lg)
                var cleanUrl = stUrl.replace(/^http:\/\//i, "https://")
                if (!root.isValidEspnApiUrl(cleanUrl)) continue
                var existing = false
                for (var ci2 = 0; ci2 < seasonCompsByYear[yr].length; ci2++) {
                  if (seasonCompsByYear[yr][ci2].url === cleanUrl || (seasonCompsByYear[yr][ci2].league === lg && String(seasonCompsByYear[yr][ci2].teamId) === String(teamId))) {
                    existing = true
                    break
                  }
                }
                if (!existing) {
                  seasonCompsByYear[yr].push({
                    league: lg,
                    leagueName: cInfo.full,
                    shortName: cInfo.short,
                    url: cleanUrl,
                    isCountry: isCountryComp,
                    teamId: teamId,
                    score: score
                  })
                }
              }
            }

            var availSeasons = []
            var availYears = Object.keys(seasonCompsByYear).map(Number).sort(function(a, b) { return b - a })
            for (var yi = 0; yi < availYears.length; yi++) {
              var yNum = availYears[yi]
              var compsForYr = seasonCompsByYear[yNum] || []
              compsForYr.sort(function(a, b) { return b.score - a.score })
              var yrLabel = yNum >= 2000 ? (yNum + "–" + String(yNum + 1).slice(-2)) : String(yNum)
              availSeasons.push({
                year: yNum,
                seasonYear: yrLabel,
                label: yrLabel,
                competitions: compsForYr
              })
            }

            prof2.availableSeasons = availSeasons
            prof2.selectedSeasonIndex = 0
            prof2.selectedCompIndex = 0
            prof2.selectedSeasonYear = availSeasons.length > 0 ? availSeasons[0].seasonYear : ""
            root.selectedPlayerProfile = Object.assign({}, prof2)

            if (availSeasons.length > 0) {
              root.applyPlayerStatsView()
            }

            root.maybeStartCareerAgg()
            root.ensureClubNames()
          }
        } catch (e) {}
      }
    }
  }
  FutContextProcess {
    id: internalSearchTeamNameRequest
    requestContext: String(root.selectedPlayerProfile ? root.selectedPlayerProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchTeamNameRequest.responseCurrent) return
        try {
          var p = root.selectedPlayerProfile
          var teamId = root.clubNameQueue.length > 0 ? root.clubNameQueue[0] : ""
          root.clubNameQueue.shift()
          if (teamId !== "" && typeof text === "string" && text.length > 0 && text.length <= 2097152 && p && p.teamSeasonMap && p.teamSeasonMap[teamId]) {
            try {
              var data = JSON.parse(text)
              var t = data && data.team ? data.team : null
              if (t) {
                var info = p.teamSeasonMap[teamId]
                var yrs = info.start === info.end ? String(info.start) : (info.start + "–" + info.end)
                var opts = p.clubOptions ? p.clubOptions.slice() : []
                opts.push({
                  teamId: teamId,
                  name: String(t.displayName || t.name || ("Team " + teamId)),
                  logo: "https://a.espncdn.com/i/teamlogos/soccer/500/" + teamId + ".png",
                  years: yrs,
                  start: info.start
                })
                opts.sort(function(a, b) { return (b.start || 0) - (a.start || 0) })
                p.clubOptions = opts
                // Update careerHistory with resolved club names as well
                if (p.careerHistory && p.careerHistory.length > 0) {
                  for (var hi = 0; hi < p.careerHistory.length; hi++) {
                    if (p.careerHistory[hi].teamId === teamId) {
                      p.careerHistory[hi].name = String(t.displayName || t.name || t.shortDisplayName || "")
                      p.careerHistory[hi].shortName = String(t.shortDisplayName || t.name || "")
                    }
                  }
                }
                if (!root.teamNameCache) root.teamNameCache = ({})
                root.teamNameCache[teamId] = String(t.displayName || t.name || "")
                root.updateTransferTeamNames()
                root.selectedPlayerProfile = Object.assign({}, p)
              }
            } catch (e2) {}
          }
        } catch (e) {}
        root._resolveNextClubName()
      }
    }
  }
  FutContextProcess {
    id: internalSearchClubStatRequest
    requestContext: String(root.selectedPlayerProfile ? root.selectedPlayerProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchClubStatRequest.responseCurrent) return
        try {
          var p = root.selectedPlayerProfile
          if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && p && p.clubFilterId === root.clubAggTarget && p.clubFilterLoading) {
            try {
              var payload = JSON.parse(text)
              if (payload && payload.stats) {
                var statsObj = payload.stats
                var num = function(v) { var n = parseFloat(v); return isNaN(n) ? 0 : n }
                var keys = Object.keys(statsObj)
                for (var ki = 0; ki < keys.length; ki++) {
                  var nm = keys[ki]
                  var val = num(statsObj[nm])
                  if (!isNaN(val)) {
                    if (root.clubAggSums[nm] === undefined) root.clubAggSums[nm] = 0
                    root.clubAggSums[nm] += val
                  }
                }
              }
              if (payload && payload.cached) {
                if (!root.playerCompStatCache) root.playerCompStatCache = ({})
                var cKeys = Object.keys(payload.cached)
                for (var ci = 0; ci < cKeys.length; ci++) {
                  root.playerCompStatCache[cKeys[ci]] = payload.cached[cKeys[ci]]
                }
              }
            } catch (e2) {}
          }
          if (p && p.clubFilterId === root.clubAggTarget && p.clubFilterLoading) {
            root._finishClubAgg()
          }
        } catch (e) {}
      }
    }
  }
  FutContextProcess {
    id: internalSearchCareerAggRequest
    requestContext: String(root.selectedPlayerProfile ? root.selectedPlayerProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchCareerAggRequest.responseCurrent) return
        try {
          var p = root.selectedPlayerProfile
          if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && p && root.statsPlayerKey === root.careerAggTarget && !p.careerAggDone) {
            try {
              var sums = JSON.parse(text)
              if (sums) {
                if (sums["goalAssists"] > 0) p.careerAssists = String(Math.round(sums["goalAssists"]))
                if (sums["appearances"] > 0) p.careerAppearances = String(Math.round(sums["appearances"]))
                if (sums["totalGoals"] > 0) p.careerGoals = String(Math.round(sums["totalGoals"]))
                p.careerAggDone = true
                root.selectedPlayerProfile = Object.assign({}, p)
                if (root.searchPlayerStatsTab === "career") {
                  root.applyPlayerStatsView()
                }
              }
            } catch (e2) {}
          }
        } catch (e) {}
      }
    }
  }
  Timer {
    id: internalClubFetchTimeoutTimer
    interval: 8000
    repeat: false
    onTriggered: {
      root.searchClubLoading = false
      root._clubFetchPending = 0
    }
  }
  Timer {
    id: internalPlayerStatsTimeoutTimer
    interval: 8000
    repeat: false
    onTriggered: {
      root.playerStatsLoading = false
      root.compStatInFlightUrl = ""
      root.compStatInFlightGen = 0
      internalSearchCompQueueRequest.running = false
      root.playerCompStatQueue = []
      var p = root.selectedPlayerProfile
      if (p && p.clubFilterLoading) {
        p.clubFilterLoading = false
        root.selectedPlayerProfile = Object.assign({}, p)
      }
    }
  }

  function _onClubFetchDone() {
    root._clubFetchPending = Math.max(0, root._clubFetchPending - 1)
    if (root._clubFetchPending === 0) {
      internalClubFetchTimeoutTimer.stop()
      root.searchClubLoading = false
      if (root.selectedClubProfile && root.selectedClubProfile.id) {
        var copy = Object.assign({}, root.selectedClubProfile)
        var cMap = Object.assign({}, root._clubCache)
        cMap[root.selectedClubProfile.id] = copy
        root._clubCache = cMap
      }
    }
  }

  FutContextProcess {
    id: internalSearchClubDetailRequest
    onExited: if (internalSearchClubDetailRequest.responseCurrent) root._onClubFetchDone()
    requestContext: String(root.selectedClubProfile ? root.selectedClubProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchClubDetailRequest.responseCurrent) return
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var res = JSON.parse(text)
            var t = res && res.team ? res.team : null
            if (t) {
              var rec = t.record && t.record.items && t.record.items[0] ? t.record.items[0] : null
              var statsList = rec && Array.isArray(rec.stats) ? rec.stats : []
              var getStat = function(name) {
                for (var si = 0; si < statsList.length; si++) {
                  if (statsList[si].name === name) return String(statsList[si].value)
                }
                return ""
              }
              var pts = getStat("points")
              var wins = getStat("wins")
              var ties = getStat("ties")
              var losses = getStat("losses")
              var diff = getStat("pointDifferential")
              var gf = getStat("pointsFor")
              var ga = getStat("pointsAgainst")
              var homeW = getStat("homeWins")
              var homeD = getStat("homeTies")
              var homeL = getStat("homeLosses")
              var awayW = getStat("awayWins")
              var awayD = getStat("awayTies")
              var awayL = getStat("awayLosses")
              var homeRec = (homeW !== "" || homeD !== "" || homeL !== "") ? (homeW + "W-" + homeD + "D-" + homeL + "L") : ""
              var awayRec = (awayW !== "" || awayD !== "" || awayL !== "") ? (awayW + "W-" + awayD + "D-" + awayL + "L") : ""
              var ppg = getStat("ppg")
              var rank = getStat("rank")
              var streak = getStat("streak")
              var deductions = getStat("deductions")
              var gamesPlayed = getStat("gamesPlayed")
              var rankChange = getStat("rankChange")
              var clr = t.color ? ("#" + String(t.color).replace("#", "")) : ""
              var altClr = t.alternateColor ? ("#" + String(t.alternateColor).replace("#", "")) : ""
              var vName = t.venue && t.venue.fullName ? String(t.venue.fullName) : (t.franchise && t.franchise.venue && t.franchise.venue.fullName ? String(t.franchise.venue.fullName) : "")
              var vCity = t.venue && t.venue.address && t.venue.address.city ? String(t.venue.address.city) : ""
              var venueStr = vName !== "" ? (vCity !== "" ? vName + " (" + vCity + ")" : vName) : ""
              var webLink = ""
              if (t.links && Array.isArray(t.links)) {
                for (var li = 0; li < t.links.length; li++) {
                  if (t.links[li].href && (t.links[li].rel && (t.links[li].rel.indexOf("clubhouse") !== -1 || t.links[li].rel.indexOf("desktop") !== -1))) {
                    webLink = t.links[li].href
                    break
                  }
                }
              }

              var prof = Object.assign({}, root.selectedClubProfile)
              prof.comparisonSeason = res.season && res.season.year ? String(res.season.year) : ""
              prof.id = String(t.id || prof.id || "")
              prof.displayName = root.sanitizePlainText(String(t.displayName || t.name || prof.displayName || ""))
              if (t.nickname) prof.nickname = root.sanitizePlainText(String(t.nickname))
              if (t.abbreviation) prof.abbreviation = root.sanitizePlainText(String(t.abbreviation))
              if (t.location) prof.location = root.sanitizePlainText(String(t.location))
              if (t.standingSummary) prof.standingSummary = root.sanitizePlainText(String(t.standingSummary))
              if (rec && rec.summary) prof.record = root.sanitizePlainText(String(rec.summary))
              if (pts !== "") prof.points = pts
              if (wins !== "") prof.wins = wins
              if (ties !== "") prof.ties = ties
              if (losses !== "") prof.losses = losses
              if (diff !== "") prof.diff = diff
              if (gf !== "") prof.goalsFor = gf
              if (ga !== "") prof.goalsAgainst = ga
              if (homeRec !== "") prof.homeRecord = homeRec
              if (awayRec !== "") prof.awayRecord = awayRec
              if (gamesPlayed !== "") {
                var gpVal = parseInt(gamesPlayed)
                if (!isNaN(gpVal) && gpVal > 0) prof.gamesPlayed = String(gpVal)
              }
              if (rankChange !== "") {
                var rcVal = parseFloat(rankChange)
                if (!isNaN(rcVal)) {
                  if (rcVal > 0) prof.rankChange = "▲" + Math.round(rcVal)
                  else if (rcVal < 0) prof.rankChange = "▼" + Math.round(Math.abs(rcVal))
                  else prof.rankChange = "0"
                }
              }
              if (ppg !== "" && ppg !== "0" && ppg !== "0.0") {
                var pf = parseFloat(ppg)
                if (!isNaN(pf) && pf > 0) prof.ppg = pf.toFixed(2)
              }
              if (rank !== "" && rank !== "0" && rank !== "0.0") prof.rank = "#" + rank.replace(".0", "")
              if (streak !== "" && streak !== "0" && streak !== "0.0") {
                var sVal = parseFloat(streak)
                if (!isNaN(sVal) && sVal !== 0) {
                  prof.streak = sVal > 0 ? (sVal + "W") : (Math.abs(sVal) + "L")
                }
              }
              if (deductions !== "" && deductions !== "0" && deductions !== "0.0") {
                var dVal = parseFloat(deductions)
                if (!isNaN(dVal) && dVal !== 0) prof.deductions = "-" + Math.abs(dVal) + " pts"
              }
              if (venueStr !== "") prof.venue = venueStr
              if (t.nextEvent && t.nextEvent[0] && t.nextEvent[0].name) prof.nextEvent = String(t.nextEvent[0].name)
              if (t.nextEvent && t.nextEvent[0] && t.nextEvent[0].date) prof.nextEventDate = String(t.nextEvent[0].date)
              if (t.logos && t.logos[0] && t.logos[0].href) prof.logo = String(t.logos[0].href)
              if (clr !== "") prof.color = clr
              if (altClr !== "") prof.alternateColor = altClr
              if (t.form) prof.form = String(t.form)
              if (webLink !== "" && (!prof.webUrl || prof.webUrl === "")) prof.webUrl = webLink
              root.selectedClubProfile = prof
            }
          } catch (e) {}
        }
      }
    }
  }

  FutContextProcess {
    id: internalSearchClubScheduleRequest
    onExited: if (internalSearchClubScheduleRequest.responseCurrent) root._onClubFetchDone()
    requestContext: String(root.selectedClubProfile ? root.selectedClubProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchClubScheduleRequest.responseCurrent) return
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var sched = JSON.parse(text)
            var evs = sched && Array.isArray(sched.events) ? sched.events : []
            var mList = []
            for (var mi = 0; mi < evs.length && mList.length < 5; mi++) {
              var ev = evs[mi]
              var comp = ev.competitions && ev.competitions[0] ? ev.competitions[0] : null
              if (!comp) continue
              var comps = comp.competitors || []
              var h = (comps[0] && comps[0].homeAway === "home") ? comps[0] : ((comps[1] && comps[1].homeAway === "home") ? comps[1] : (comps[0] || {}))
              var a = (comps[1] && comps[1].homeAway === "away") ? comps[1] : ((comps[0] && comps[0].homeAway === "away") ? comps[0] : (comps[1] || {}))
              var hTeam = h.team || {}
              var aTeam = a.team || {}
              var hName = String(hTeam.displayName || hTeam.name || hTeam.shortDisplayName || "Home")
              var aName = String(aTeam.displayName || aTeam.name || aTeam.shortDisplayName || "Away")
              var hLogo = (hTeam.logos && hTeam.logos[0] && hTeam.logos[0].href) ? String(hTeam.logos[0].href) : (hTeam.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + hTeam.id + ".png") : "")
              var aLogo = (aTeam.logos && aTeam.logos[0] && aTeam.logos[0].href) ? String(aTeam.logos[0].href) : (aTeam.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + aTeam.id + ".png") : "")
              var hScore = h.score && h.score.displayValue !== undefined ? String(h.score.displayValue) : ""
              var aScore = a.score && a.score.displayValue !== undefined ? String(a.score.displayValue) : ""
              var compLabel = ""
              if (ev.league && (ev.league.name || ev.league.shortName || ev.league.abbreviation)) {
                compLabel = String(ev.league.name || ev.league.shortName || ev.league.abbreviation)
              } else if (comp && comp.league && (comp.league.name || comp.league.shortName || comp.league.abbreviation)) {
                compLabel = String(comp.league.name || comp.league.shortName || comp.league.abbreviation)
              } else {
                var lSlug = (ev.league && ev.league.slug) ? String(ev.league.slug) : (root.selectedClubProfile.leagueSlug || "")
                if (lSlug !== "" && typeof FutData !== "undefined" && FutData.formatCompetitionName) {
                  var cFmt = FutData.formatCompetitionName(lSlug)
                  if (cFmt && cFmt.full && cFmt.full !== "Competition") compLabel = cFmt.full
                }
                if (compLabel === "") compLabel = (ev.season && ev.season.displayName) ? String(ev.season.displayName) : (root.leagueLabel ? root.leagueLabel() : "Competition")
              }
              var dateObj = ev.date ? new Date(ev.date) : null
              var dStr = dateObj ? Qt.formatDate(dateObj, "ddd, MMM d") : ""

              var outcome = "D"
              var isHome = String(hTeam.id || "") === String(root.selectedClubProfile.id || "")
              var hNum = parseInt(hScore)
              var aNum = parseInt(aScore)
              if (!isNaN(hNum) && !isNaN(aNum)) {
                if (hNum === aNum) outcome = "D"
                else if (isHome) outcome = (hNum > aNum) ? "W" : "L"
                else outcome = (aNum > hNum) ? "W" : "L"
              }

              var oppTeam = isHome ? aTeam : hTeam
              var oppId = String(oppTeam.id || "")
              var oppName = String(oppTeam.displayName || oppTeam.name || oppTeam.shortDisplayName || (isHome ? aName : hName))
              var oppLogo = isHome ? aLogo : hLogo
              var oppLeague = (ev.league && (ev.league.slug || ev.league.abbreviation)) ? String(ev.league.slug || ev.league.abbreviation) : (root.selectedClubProfile.leagueSlug || "esp.1")

              mList.push({
                matchName: hName + " vs " + aName,
                homeTeam: hName,
                awayTeam: aName,
                homeLogo: hLogo,
                awayLogo: aLogo,
                homeScore: hScore,
                awayScore: aScore,
                score: (hScore !== "" && aScore !== "") ? (hScore + " – " + aScore) : "",
                competition: compLabel,
                date: dStr,
                time: "FT",
                outcome: outcome,
                isCompleted: true,
                isHome: isHome,
                oppId: oppId,
                oppName: oppName,
                oppLogo: oppLogo,
                oppLeagueSlug: oppLeague
              })
            }
            var prof = Object.assign({}, root.selectedClubProfile)
            prof.recentMatches = mList
            root.selectedClubProfile = prof
          } catch (e) {}
        }
      }
    }
  }

  FutContextProcess {
    id: internalSearchClubStatsRequest
    onExited: if (internalSearchClubStatsRequest.responseCurrent) root._onClubFetchDone()
    requestContext: String(root.selectedClubProfile ? root.selectedClubProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchClubStatsRequest.responseCurrent) return
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var sData = JSON.parse(text)
            var cats = sData && Array.isArray(sData.splits && sData.splits.categories) ? sData.splits.categories : []
            var sMap = {}
            for (var ci = 0; ci < cats.length; ci++) {
              var stList = cats[ci].stats || []
              for (var si = 0; si < stList.length; si++) {
                var sItem = stList[si]
                var rawVal = sItem.value !== undefined ? sItem.value : sItem.displayValue
                sMap[sItem.name] = rawVal
                sMap[sItem.name + "_disp"] = sItem.displayValue !== undefined ? String(sItem.displayValue) : String(rawVal)
              }
            }
            var prof = Object.assign({}, root.selectedClubProfile)
            if (sMap["possessionPct"] !== undefined) {
              var posVal = parseFloat(sMap["possessionPct"])
              prof.possession = !isNaN(posVal) ? (posVal.toFixed(1) + "%") : (String(sMap["possessionPct"]) + "%")
            }
            if (sMap["totalShots"] !== undefined) prof.shotsPerGame = String(Math.round(parseFloat(sMap["totalShots"])))
            if (sMap["shotsOnTarget"] !== undefined) prof.shotsOnTarget = String(Math.round(parseFloat(sMap["shotsOnTarget"])))
            if (sMap["passPct"] !== undefined) {
              var pp = parseFloat(sMap["passPct"])
              prof.passPct = (pp <= 1.0 ? Math.round(pp * 100) : Math.round(pp)) + "%"
            }
            if (sMap["cleanSheet"] !== undefined) prof.cleanSheets = String(Math.round(parseFloat(sMap["cleanSheet"])))
            if (sMap["totalTackles"] !== undefined) prof.tackles = String(Math.round(parseFloat(sMap["totalTackles"])))
            if (sMap["interceptions"] !== undefined) prof.interceptions = String(Math.round(parseFloat(sMap["interceptions"])))
            if (sMap["yellowCards"] !== undefined) prof.yellowCards = String(Math.round(parseFloat(sMap["yellowCards"])))
            if (sMap["redCards"] !== undefined) prof.redCards = String(Math.round(parseFloat(sMap["redCards"])))
            if (sMap["secondYellow"] !== undefined) prof.secondYellow = String(Math.round(parseFloat(sMap["secondYellow"])))
            if (sMap["foulsCommitted"] !== undefined) prof.foulsCommitted = String(Math.round(parseFloat(sMap["foulsCommitted"])))

            // Advanced metrics: Expected Goals, Expected Goals Conceded, Big Chances, Conversion Rate, Duel Win Pct
            if (sMap["avgExpectedGoals"] !== undefined && sMap["avgExpectedGoals"] !== "") {
              var xg = parseFloat(sMap["avgExpectedGoals"])
              if (!isNaN(xg)) prof.expectedGoals = xg.toFixed(2)
            }
            if (sMap["avgExpectedGoalsConceded"] !== undefined && sMap["avgExpectedGoalsConceded"] !== "") {
              var xga = parseFloat(sMap["avgExpectedGoalsConceded"])
              if (!isNaN(xga)) prof.expectedGoalsAgainst = xga.toFixed(2)
            }
            if (sMap["bigChanceCreated"] !== undefined && sMap["bigChanceCreated"] !== "") {
              var bc = Math.round(parseFloat(sMap["bigChanceCreated"]))
              if (!isNaN(bc)) prof.bigChances = String(bc)
            }
            if (sMap["goalConversion"] !== undefined && sMap["goalConversion"] !== "") {
              var gc = parseFloat(sMap["goalConversion"])
              if (!isNaN(gc) && gc > 0) prof.goalConversion = (gc <= 1.0 ? Math.round(gc * 100) : Math.round(gc)) + "%"
            }
            if (sMap["duelWinPct"] !== undefined && sMap["duelWinPct"] !== "") {
              var dw = parseFloat(sMap["duelWinPct"])
              if (!isNaN(dw) && dw > 0) prof.duelWinPct = (dw <= 1.0 ? Math.round(dw * 100) : Math.round(dw)) + "%"
            }

            var yc = parseInt(sMap["yellowCards"] || "0")
            var rc = parseInt(sMap["redCards"] || "0")
            prof.disciplinaryPoints = String((yc * 1) + (rc * 3))
            root.selectedClubProfile = prof
          } catch (e) {}
        }
      }
    }
  }

  FutContextProcess {
    id: internalSearchClubCoreRequest
    onExited: if (internalSearchClubCoreRequest.responseCurrent) root._onClubFetchDone()
    requestContext: String(root.selectedClubProfile ? root.selectedClubProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchClubCoreRequest.responseCurrent) return
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var cData = JSON.parse(text)
            var prof = Object.assign({}, root.selectedClubProfile)
            var vObj = cData && cData.venue ? cData.venue : null
            if (vObj) {
              var vName = String(vObj.fullName || vObj.name || "")
              var vCity = (vObj.address && vObj.address.city) ? String(vObj.address.city) : ""
              var vStr = vName !== "" ? (vCity !== "" ? vName + " (" + vCity + ")" : vName) : ""
              if (vStr !== "" && (!prof.venue || prof.venue === "")) {
                prof.venue = vStr
              }
            }
            if (cData && cData.form && (!prof.form || prof.form === "")) {
              prof.form = String(cData.form)
            }
            if (cData && cData.color && (!prof.color || prof.color === "")) {
              prof.color = "#" + String(cData.color).replace("#", "")
            }
            if (cData && cData.alternateColor && (!prof.alternateColor || prof.alternateColor === "")) {
              prof.alternateColor = "#" + String(cData.alternateColor).replace("#", "")
            }
            root.selectedClubProfile = prof
          } catch (e) {}
        }
      }
    }
  }

  FutContextProcess {
    id: internalSearchClubFixturesRequest
    onExited: if (internalSearchClubFixturesRequest.responseCurrent) root._onClubFetchDone()
    requestContext: String(root.selectedClubProfile ? root.selectedClubProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchClubFixturesRequest.responseCurrent) return
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var sched = JSON.parse(text)
            var evs = sched && Array.isArray(sched.events) ? sched.events : []
            var fixList = []
            for (var fi = 0; fi < evs.length && fixList.length < 3; fi++) {
              var ev = evs[fi]
              var comp = ev.competitions && ev.competitions[0] ? ev.competitions[0] : null
              if (!comp) continue
              var comps = comp.competitors || []
              var h = (comps[0] && comps[0].homeAway === "home") ? comps[0] : ((comps[1] && comps[1].homeAway === "home") ? comps[1] : (comps[0] || {}))
              var a = (comps[1] && comps[1].homeAway === "away") ? comps[1] : ((comps[0] && comps[0].homeAway === "away") ? comps[0] : (comps[1] || {}))
              var hTeam = h.team || {}
              var aTeam = a.team || {}
              var hName = String(hTeam.displayName || hTeam.name || hTeam.shortDisplayName || "Home")
              var aName = String(aTeam.displayName || aTeam.name || aTeam.shortDisplayName || "Away")
              var hLogo = (hTeam.logos && hTeam.logos[0] && hTeam.logos[0].href) ? String(hTeam.logos[0].href) : (hTeam.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + hTeam.id + ".png") : "")
              var aLogo = (aTeam.logos && aTeam.logos[0] && aTeam.logos[0].href) ? String(aTeam.logos[0].href) : (aTeam.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + aTeam.id + ".png") : "")
              var bList = []
              if (Array.isArray(comp.broadcasts)) {
                for (var bi = 0; bi < comp.broadcasts.length; bi++) {
                  var m = comp.broadcasts[bi].media
                  if (m && m.shortName) bList.push(m.shortName)
                }
              }
              var bStr = bList.join(", ")
              var compLabel = ""
              if (ev.league && (ev.league.name || ev.league.shortName || ev.league.abbreviation)) {
                compLabel = String(ev.league.name || ev.league.shortName || ev.league.abbreviation)
              } else if (comp && comp.league && (comp.league.name || comp.league.shortName || comp.league.abbreviation)) {
                compLabel = String(comp.league.name || comp.league.shortName || comp.league.abbreviation)
              } else {
                var lSlug = (ev.league && ev.league.slug) ? String(ev.league.slug) : (root.selectedClubProfile.leagueSlug || "")
                if (lSlug !== "" && typeof FutData !== "undefined" && FutData.formatCompetitionName) {
                  var cFmt = FutData.formatCompetitionName(lSlug)
                  if (cFmt && cFmt.full && cFmt.full !== "Competition") compLabel = cFmt.full
                }
                if (compLabel === "") compLabel = (ev.season && ev.season.displayName) ? String(ev.season.displayName) : (root.leagueLabel ? root.leagueLabel() : "Competition")
              }
              var dateObj = ev.date ? new Date(ev.date) : null
              var dStr = dateObj ? Qt.formatDate(dateObj, "ddd, MMM d") : ""
              var tStr = dateObj ? Qt.formatTime(dateObj, "h:mm AP") : ""
              var isHome = String(hTeam.id || "") === String(root.selectedClubProfile.id || "")
              var oppTeam = isHome ? aTeam : hTeam
              var oppId = String(oppTeam.id || "")
              var oppName = String(oppTeam.displayName || oppTeam.name || oppTeam.shortDisplayName || (isHome ? aName : hName))
              var oppLogo = isHome ? aLogo : hLogo
              var oppLeague = (ev.league && (ev.league.slug || ev.league.abbreviation)) ? String(ev.league.slug || ev.league.abbreviation) : (root.selectedClubProfile.leagueSlug || "esp.1")

              fixList.push({
                matchName: hName + " vs " + aName,
                homeTeam: hName,
                awayTeam: aName,
                homeLogo: hLogo,
                awayLogo: aLogo,
                competition: compLabel,
                date: dStr,
                time: tStr,
                broadcast: bStr !== "" ? bStr : "TBD",
                isHome: isHome,
                oppId: oppId,
                oppName: oppName,
                oppLogo: oppLogo,
                oppLeagueSlug: oppLeague
              })
            }
            var prof = Object.assign({}, root.selectedClubProfile)
            prof.upcomingFixtures = fixList
            root.selectedClubProfile = prof
          } catch (e) {}
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchClubFixturesRequest.responseCurrent) return
      }
    }
  }

  FutContextProcess {
    id: internalSearchClubStandingsRequest
    requestContext: String(root.selectedClubProfile ? root.selectedClubProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchClubStandingsRequest.responseCurrent) return
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var data = JSON.parse(text)
            var children = data && Array.isArray(data.children) ? data.children : []
            if (children.length > 0 && children[0].standings && Array.isArray(children[0].standings.entries)) {
              var rawEntries = children[0].standings.entries
              var parsed = []
              for (var i = 0; i < rawEntries.length; i++) {
                var ent = rawEntries[i]
                var tm = ent.team || {}
                var st = {}
                for (var si = 0; si < (ent.stats || []).length; si++) {
                  st[ent.stats[si].name] = ent.stats[si].displayValue !== undefined ? String(ent.stats[si].displayValue) : ""
                }
                parsed.push({
                  id: String(tm.id || ""),
                  name: String(tm.displayName || tm.name || tm.shortDisplayName || ""),
                  logo: (tm.logos && tm.logos[0] && tm.logos[0].href) ? String(tm.logos[0].href) : (tm.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + tm.id + ".png") : ""),
                  rank: parseInt(st["rank"]) || (i + 1),
                  gamesPlayed: st["gamesPlayed"] || "",
                  wins: st["wins"] || "",
                  ties: st["ties"] || "",
                  losses: st["losses"] || "",
                  diff: st["pointDifferential"] || "",
                  points: st["points"] || "",
                  note: ent.note || null
                })
              }
              var lg = root.selectedClubProfile.leagueSlug || "esp.1"
              var cache = Object.assign({}, root._leagueStandingsCache)
              cache[lg] = parsed
              root._leagueStandingsCache = cache
            }
          } catch (e) {}
        }
      }
    }
  }

  FutContextProcess {
    id: internalSearchClubRosterRequest
    onExited: if (internalSearchClubRosterRequest.responseCurrent) root._onClubFetchDone()
    requestContext: String(root.selectedClubProfile ? root.selectedClubProfile.id : "")
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchClubRosterRequest.responseCurrent) return
        if (typeof text === "string" && text.length > 0 && text.length <= 2097152 && root.selectedClubProfile) {
          try {
            var rData = JSON.parse(text)
            var aths = rData && Array.isArray(rData.athletes) ? rData.athletes : []
            var gks = [], defs = [], mids = [], fwds = [], allList = []
            var scorersList = [], assistersList = [], cardersList = []
            var ageSum = 0, ageCount = 0
            var natSet = {}

            for (var ai = 0; ai < aths.length; ai++) {
              var a = aths[ai]
              var nat = a.citizenship ? String(a.citizenship) : (a.flag && a.flag.alt ? String(a.flag.alt) : "")
              if (nat !== "") natSet[nat] = true
              var pName = a.position && a.position.displayName ? String(a.position.displayName) : (a.position && a.position.name ? String(a.position.name) : "Other")
              var pLower = pName.toLowerCase()
              var dName = String(a.displayName || a.fullName || "Player")
              var sName = String(a.shortName || dName)

              // Parse athlete season stats
              var statsMap = {}
              var cats = a.statistics && a.statistics.splits && Array.isArray(a.statistics.splits.categories) ? a.statistics.splits.categories : []
              for (var ci = 0; ci < cats.length; ci++) {
                var stList = cats[ci].stats || []
                for (var si = 0; si < stList.length; si++) {
                  statsMap[stList[si].name] = parseFloat(stList[si].value !== undefined ? stList[si].value : stList[si].displayValue) || 0
                }
              }
              var goals = statsMap["totalGoals"] || 0
              var assists = statsMap["goalAssists"] || 0
              var apps = statsMap["appearances"] || 0
              var yc = statsMap["yellowCards"] || 0
              var rc = statsMap["redCards"] || 0
              var sv = statsMap["saves"] || 0

              var aAge = parseInt(a.age)
              if (!isNaN(aAge) && aAge > 0) {
                ageSum += aAge
                ageCount++
              }

              if (goals > 0) scorersList.push({ count: goals, name: dName, shortName: sName, id: String(a.id || "") })
              if (assists > 0) assistersList.push({ count: assists, name: dName, shortName: sName, id: String(a.id || "") })
              if (yc > 0 || rc > 0) cardersList.push({ pts: (yc + rc * 2), yc: yc, rc: rc, name: dName, shortName: sName, id: String(a.id || "") })

              // Inline stat summary for squad card
              var isGk = (pLower.indexOf("goal") !== -1 || pLower === "gk" || pLower === "g")
              var statStr = ""
              if (isGk) {
                if (apps > 0) {
                  statStr = apps + " apps" + (sv > 0 ? (" · " + sv + " SV") : "")
                }
              } else {
                var parts = []
                if (goals > 0) parts.push(goals + "G")
                if (assists > 0) parts.push(assists + "A")
                var gAst = parts.join(" · ")
                if (gAst !== "") {
                  statStr = apps > 0 ? (gAst + " (" + apps + " apps)") : gAst
                } else if (apps > 0) {
                  statStr = apps + " apps"
                }
              }

              var pItem = {
                id: String(a.id || ""),
                name: dName,
                jersey: a.jersey ? String(a.jersey) : "—",
                age: a.age ? String(a.age) : "—",
                position: pName,
                flag: a.flag && a.flag.href ? String(a.flag.href) : "",
                country: a.citizenship ? String(a.citizenship) : (a.flag && a.flag.alt ? String(a.flag.alt) : ""),
                headshot: a.headshot && a.headshot.href ? String(a.headshot.href) : "",
                statsSummary: statStr
              }
              allList.push(pItem)
              if (isGk) {
                pItem.posCat = "GK"
                gks.push(pItem)
              } else if (pLower.indexOf("def") !== -1 || pLower.indexOf("back") !== -1 || pLower === "df") {
                pItem.posCat = "DF"
                defs.push(pItem)
              } else if (pLower.indexOf("mid") !== -1 || pLower === "mf") {
                pItem.posCat = "MF"
                mids.push(pItem)
              } else if (pLower.indexOf("forw") !== -1 || pLower.indexOf("attack") !== -1 || pLower.indexOf("strik") !== -1 || pLower.indexOf("wing") !== -1 || pLower === "fw") {
                pItem.posCat = "FW"
                fwds.push(pItem)
              } else {
                pItem.posCat = "MF"
                mids.push(pItem)
              }
            }

            // Calculate leaders
            var topScorerStr = ""
            var topScorerId = ""
            if (scorersList.length > 0) {
              scorersList.sort(function(x, y) { return y.count - x.count })
              var maxG = scorersList[0].count
              var tiedG = scorersList.filter(function(x) { return x.count === maxG })
              topScorerId = String(tiedG[0].id || "")
              if (tiedG.length === 1) topScorerStr = tiedG[0].name + " (" + maxG + ")"
              else if (tiedG.length === 2) topScorerStr = tiedG[0].shortName + ", " + tiedG[1].shortName + " (" + maxG + ")"
              else topScorerStr = tiedG[0].shortName + " +" + (tiedG.length - 1) + " (" + maxG + ")"
            }

            var topAssisterStr = ""
            var topAssisterId = ""
            if (assistersList.length > 0) {
              assistersList.sort(function(x, y) { return y.count - x.count })
              var maxA = assistersList[0].count
              var tiedA = assistersList.filter(function(x) { return x.count === maxA })
              topAssisterId = String(tiedA[0].id || "")
              if (tiedA.length === 1) topAssisterStr = tiedA[0].name + " (" + maxA + ")"
              else if (tiedA.length === 2) topAssisterStr = tiedA[0].shortName + ", " + tiedA[1].shortName + " (" + maxA + ")"
              else topAssisterStr = tiedA[0].shortName + " +" + (tiedA.length - 1) + " (" + maxA + ")"
            }

            var topCarderStr = ""
            var topCarderId = ""
            if (cardersList.length > 0) {
              cardersList.sort(function(x, y) { return y.pts - x.pts })
              var maxPts = cardersList[0].pts
              var tiedC = cardersList.filter(function(x) { return x.pts === maxPts })
              var c = tiedC[0]
              topCarderId = String(c.id || "")
              var badge = c.rc > 0 ? (c.yc + "Y, " + c.rc + "R") : (c.yc + "Y")
              if (tiedC.length === 1) topCarderStr = c.name + " (" + badge + ")"
              else if (tiedC.length === 2) topCarderStr = c.shortName + ", " + tiedC[1].shortName + " (" + badge + ")"
              else topCarderStr = c.shortName + " +" + (tiedC.length - 1) + " (" + badge + ")"
            }

            var avgAgeStr = ageCount > 0 ? (ageSum / ageCount).toFixed(1) : ""
            var natCount = Object.keys(natSet).length

            var coaches = rData && Array.isArray(rData.coach) ? rData.coach : []
            var mName = ""
            var staffList = []
            if (coaches.length > 0) {
              mName = String((coaches[0].firstName ? coaches[0].firstName + " " : "") + (coaches[0].lastName || coaches[0].displayName || coaches[0].name || "")).trim()
              for (var ci = 1; ci < coaches.length; ci++) {
                var s = String((coaches[ci].firstName ? coaches[ci].firstName + " " : "") + (coaches[ci].lastName || coaches[ci].displayName || coaches[ci].name || "")).trim()
                if (s !== "") staffList.push(s)
              }
            }

            var prof = Object.assign({}, root.selectedClubProfile)
            prof.rosterGoalkeepers = gks
            prof.rosterDefenders = defs
            prof.rosterMidfielders = mids
            prof.rosterForwards = fwds
            prof.rosterAll = allList
            if (topScorerStr !== "") {
              prof.topScorer = topScorerStr
              prof.topScorerId = topScorerId
            }
            if (topAssisterStr !== "") {
              prof.topAssister = topAssisterStr
              prof.topAssisterId = topAssisterId
            }
            if (topCarderStr !== "") {
              prof.topCarder = topCarderStr
              prof.topCarderId = topCarderId
            }
            prof.squadSize = aths.length
            prof.averageAge = avgAgeStr
            prof.nationalitiesCount = natCount
            if (mName !== "") prof.manager = mName
            prof.technicalStaff = staffList
            root.selectedClubProfile = prof
          } catch (e) {}
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!internalSearchClubRosterRequest.responseCurrent) return
      }
    }
  }

}
