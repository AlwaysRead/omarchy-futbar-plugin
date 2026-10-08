import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "FutData.js" as FutData

Column {
  id: trendingView
  property var root: null
  width: parent ? parent.width : 0
  spacing: Style.space(8)
  visible: root ? (root.showTrending && !root.showMatchDetail) : false

  // Public state exposed to panel header
  readonly property bool hasLiveMatches: liveMatchesCount > 0
  readonly property int liveMatchesCount: {
    var c = 0
    for (var i = 0; i < rawMatches.length; i++) {
      if (rawMatches[i].isLive) c++
    }
    return c
  }
  readonly property bool searchFocused: trendingSearchInput ? trendingSearchInput.activeFocus : false
  property string trendingFilterText: ""

  readonly property var followedNamesMap: {
    var map = {}
    if (root && root.allFollowedTabs) {
      var tabs = root.allFollowedTabs()
      for (var i = 0; i < tabs.length; i++) {
        if (tabs[i].teamName) map[String(tabs[i].teamName).trim().toLowerCase()] = true
      }
    }
    return map
  }
  function isFollowedTeam(name) {
    if (!name) return false
    return !!followedNamesMap[String(name).trim().toLowerCase()]
  }

  // Internal state
  property bool trendingLoading: false
  property string trendingError: ""
  property var rawMatches: []
  property string activeCategory: "all"
  property real lastRefreshTime: 0
  property var collapsedMap: ({})
  property var expandedMap: ({})
  property int dayOffset: 0

  function dateParamForOffset(offset) {
    if (offset === 0) return ""
    var d = new Date()
    d.setDate(d.getDate() + offset)
    var y = d.getFullYear()
    var m = String(d.getMonth() + 1)
    if (m.length < 2) m = "0" + m
    var day = String(d.getDate())
    if (day.length < 2) day = "0" + day
    return "" + y + m + day
  }

  function toggleCollapse(key) {
    var next = Object.assign({}, collapsedMap)
    next[key] = !next[key]
    collapsedMap = next
  }

  function toggleExpand(key) {
    var next = Object.assign({}, expandedMap)
    next[key] = !next[key]
    expandedMap = next
  }

  readonly property var flatVisibleMatches: {
    var list = []
    var groups = groupedTournaments
    for (var i = 0; i < groups.length; i++) {
      var g = groups[i]
      if (collapsedMap[g.key]) continue
      var ms = g.matches || []
      for (var j = 0; j < ms.length; j++) {
        list.push(ms[j])
      }
    }
    return list
  }
  property int keyboardSelectedMatchIndex: -1

  function navigateMatch(delta) {
    var total = flatVisibleMatches.length
    if (total === 0) {
      keyboardSelectedMatchIndex = -1
      return
    }
    if (keyboardSelectedMatchIndex === -1) {
      keyboardSelectedMatchIndex = delta > 0 ? 0 : total - 1
    } else {
      keyboardSelectedMatchIndex = Math.max(0, Math.min(total - 1, keyboardSelectedMatchIndex + delta))
    }
  }

  function activateSelectedMatch() {
    if (keyboardSelectedMatchIndex >= 0 && keyboardSelectedMatchIndex < flatVisibleMatches.length) {
      var m = flatVisibleMatches[keyboardSelectedMatchIndex]
      if (m && root && root.openMatchDetail) {
        root.openMatchDetail({
          id: m.id,
          competitionSlug: m.competitionSlug || m.leagueSlug,
          competitionName: m.tournamentName,
          status: m.statusDetail,
          isLive: m.isLive,
          started: m.state !== "pre",
          seriesNote: m.seriesNote || "",
          roundName: m.roundName || "",
          shootoutNote: m.shootoutNote || "",
          home: { name: m.homeName, logo: m.homeLogo, score: m.homeScore },
          away: { name: m.awayName, logo: m.awayLogo, score: m.awayScore }
        })
      }
    }
  }

  function refresh(showLoading) {
    if (trendingLoading) return
    if (showLoading && rawMatches.length === 0) trendingLoading = true
    trendingError = ""
    var dStr = dateParamForOffset(dayOffset)
    var url = "https://site.web.api.espn.com/apis/site/v2/sports/soccer/all/scoreboard?limit=300"
    if (dStr !== "") {
      url += "&dates=" + dStr
    }
    trendingRequest.running = false
    trendingRequest.command = ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "5242880", url]
    trendingRequest.running = true
  }

  onVisibleChanged: {
    if (visible) {
      if (rawMatches.length === 0 || Date.now() - lastRefreshTime > 20000) {
        refresh(rawMatches.length === 0)
      }
    }
  }

  Timer {
    id: trendingPollTimer
    interval: Math.max(10, (root ? root.livePollRate : 10)) * 1000
    repeat: true
    running: trendingView.visible && !trendingView.trendingLoading
    onTriggered: {
      if (trendingView.visible) {
        trendingView.refresh(false)
      }
    }
  }

  Process {
    id: trendingRequest
    command: ["curl", "--compressed", "-fsSL", "--max-time", "20", "--max-filesize", "5242880",
      "https://site.web.api.espn.com/apis/site/v2/sports/soccer/all/scoreboard?limit=300"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        trendingView.trendingLoading = false
        if (typeof text !== "string" || text.length === 0 || text.length > 5242880) {
          if (trendingView.rawMatches.length === 0) {
            trendingView.trendingError = "Unable to load trending matches."
          }
          return
        }
        try {
          var data = root ? root.parseScoreboardPayload(text) : JSON.parse(text)
          if (!data) throw new Error("Invalid payload")
          trendingView.parseEvents(data.events || [])
          trendingView.trendingError = ""
          trendingView.lastRefreshTime = Date.now()
        } catch (e) {
          if (trendingView.rawMatches.length === 0) {
            trendingView.trendingError = "Failed to parse scoreboard data."
          }
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text && text.trim().length > 0) {
          console.warn("futbar-trending", text)
        }
      }
    }
  }

  function parseEvents(events) {
    if (!Array.isArray(events)) {
      rawMatches = []
      return
    }

    var parsed = []
    for (var i = 0; i < events.length; i++) {
      var e = events[i]
      var comp = (e.competitions && e.competitions[0]) || {}
      var competitors = comp.competitors || []
      if (competitors.length < 2) continue

      var home = competitors[0].homeAway === "home" ? competitors[0] : (competitors[1].homeAway === "home" ? competitors[1] : competitors[0])
      var away = competitors[0].homeAway === "away" ? competitors[0] : (competitors[1].homeAway === "away" ? competitors[1] : competitors[1])

      var hTeam = home.team || {}
      var aTeam = away.team || {}
      var homeName = root ? root.sanitizePlainText(hTeam.displayName || hTeam.name || "Home") : (hTeam.displayName || "Home")
      var awayName = root ? root.sanitizePlainText(aTeam.displayName || aTeam.name || "Away") : (aTeam.displayName || "Away")

      var m = (e.uid || "").match(/~l:(\d+)/)
      var lid = m ? m[1] : ""
      var slug = ""
      if (Array.isArray(comp.odds)) {
        for (var oi = 0; oi < comp.odds.length; oi++) {
          var o = comp.odds[oi]
          if (o && o.moneyline && o.moneyline.home && o.moneyline.home.close && o.moneyline.home.close.link && o.moneyline.home.close.link.tracking && o.moneyline.home.close.link.tracking.tags && o.moneyline.home.close.link.tracking.tags.league) {
            slug = o.moneyline.home.close.link.tracking.tags.league
            break
          }
        }
      }
      if (!slug && lid) slug = FutData.leagueSlugForId(lid)
      if (!slug) slug = "all"

      var leagueName = ""
      var label = FutData.leagueLabelForSlug(slug)
      if (label && label !== slug) {
        leagueName = label
      } else if (e.season && e.season.slug && String(e.season.slug).indexOf("group") === -1) {
        var cleanSeason = String(e.season.slug).replace(/^\d{4}-/, "").replace(/-/g, " ")
        if (cleanSeason.indexOf("ncaa") !== -1) {
          cleanSeason = cleanSeason.replace(/ncaa/gi, "NCAA")
        }
        leagueName = cleanSeason.charAt(0).toUpperCase() + cleanSeason.slice(1)
      } else if (slug && slug !== "all") {
        leagueName = slug.toUpperCase()
      } else if (lid) {
        leagueName = "Tournament (" + lid + ")"
      } else {
        leagueName = "Global Matches"
      }
      if (root) leagueName = root.sanitizePlainText(leagueName)

      var leagueLogo = ""
      if (slug && FutData.leagueLogoMap[slug]) {
        leagueLogo = FutData.leagueLogoMap[slug]
      } else if (lid) {
        var mappedSlug = FutData.leagueSlugForId(lid)
        if (mappedSlug && FutData.leagueLogoMap[mappedSlug]) {
          leagueLogo = FutData.leagueLogoMap[mappedSlug]
        }
      }

      var statusType = (e.status && e.status.type) || {}
      var state = String(statusType.state || "pre")
      var detail = String(statusType.shortDetail || statusType.description || "")

      var isLive = state === "in" || detail === "Live" || detail.indexOf("'") !== -1 || detail === "HT"

      var hScore = (home.score !== undefined && home.score !== null) ? String(home.score) : "0"
      var aScore = (away.score !== undefined && away.score !== null) ? String(away.score) : "0"

      var isIntl = FutData.isInternationalCompetition(slug, lid)
      var isMajor = FutData.isMajorLeagueCompetition(slug)

      var shootoutNote = ""
      if (comp.shootout) {
        var sH = comp.shootout.homeScore !== undefined ? String(comp.shootout.homeScore) : ""
        var sA = comp.shootout.awayScore !== undefined ? String(comp.shootout.awayScore) : ""
        if (sH !== "" && sA !== "") shootoutNote = sH + "–" + sA + " Pens"
      }
      if (shootoutNote === "" && home && away) {
        var shH = home.shootoutScore !== undefined ? String(home.shootoutScore) : ""
        var shA = away.shootoutScore !== undefined ? String(away.shootoutScore) : ""
        if (shH !== "" && shA !== "") shootoutNote = shH + "–" + shA + " Pens"
      }
      var roundName = ""
      if (Array.isArray(comp.notes)) {
        for (var ni = 0; ni < comp.notes.length; ni++) {
          var nt = comp.notes[ni] && comp.notes[ni].headline ? String(comp.notes[ni].headline) : ""
          var mPen = nt.match(/(\d+)\s*[-–]\s*(\d+)\s*(?:on\s+)?penalties/i)
          if (mPen && shootoutNote === "") {
            shootoutNote = mPen[1] + "–" + mPen[2] + " Pens"
          } else if (roundName === "" && nt !== "" && nt.toLowerCase().indexOf("penalty") === -1 && nt.toLowerCase().indexOf("pens") === -1) {
            roundName = root ? root.sanitizePlainText(nt) : nt
          }
        }
      }
      var seriesNote = FutData.extractSeriesOutcome(comp, hTeam, aTeam)
      if (seriesNote === "") {
        if (comp.series && comp.series.summary) {
          var sumText = String(comp.series.summary).trim()
          if (/advance|aggregate|win|won/i.test(sumText)) seriesNote = sumText
        }
      }

      var kTime = ""
      var kDate = ""
      if (e.date) {
        var dObj = new Date(e.date)
        kTime = (root && root.kickoffTime) ? root.kickoffTime({ date: dObj }) : Qt.formatTime(dObj, "HH:mm")
        kDate = Qt.formatDate(dObj, "ddd d MMM yyyy")
      }

      parsed.push({
        id: String(e.id || ""),
        name: String(e.name || ""),
        date: String(e.date || ""),
        kickoffMs: e.date ? new Date(e.date).getTime() : 0,
        timeText: kTime,
        dateText: kDate,
        state: state,
        isLive: isLive,
        statusDetail: detail || (isLive ? "Live" : (state === "post" ? "FT" : kTime)),
        shootoutNote: shootoutNote,
        seriesNote: seriesNote,
        roundName: roundName,
        homeName: homeName,
        homeLogo: root ? root.sanitizeImageUrl(hTeam.logo || (hTeam.logos && hTeam.logos[0] ? hTeam.logos[0].href : "")) : (hTeam.logo || ""),
        homeScore: hScore,
        awayName: awayName,
        awayLogo: root ? root.sanitizeImageUrl(aTeam.logo || (aTeam.logos && aTeam.logos[0] ? aTeam.logos[0].href : "")) : (aTeam.logo || ""),
        awayScore: aScore,
        competitionSlug: slug,
        competitionName: leagueName,
        competitionLogo: root ? root.sanitizeImageUrl(leagueLogo) : leagueLogo,
        isInternational: isIntl,
        isMajorLeague: isMajor
      })
    }

    // Sort matches: Live first, then upcoming (kickoff ascending), then completed (kickoff descending)
    parsed.sort(function(a, b) {
      if (a.isLive && !b.isLive) return -1
      if (!a.isLive && b.isLive) return 1
      if (a.state === "pre" && b.state === "pre") return a.kickoffMs - b.kickoffMs
      if (a.state === "pre" && b.state !== "pre") return -1
      if (a.state !== "pre" && b.state === "pre") return 1
      return b.kickoffMs - a.kickoffMs
    })

    rawMatches = parsed
  }

  readonly property var filteredMatches: {
    var list = rawMatches || []
    if (activeCategory === "live") {
      list = list.filter(function(m) { return m.isLive })
    } else if (activeCategory === "international") {
      list = list.filter(function(m) { return m.isInternational })
    } else if (activeCategory === "club") {
      list = list.filter(function(m) { return !m.isInternational })
    }
    if (trendingFilterText.trim() !== "") {
      var q = trendingFilterText.trim().toLowerCase()
      list = list.filter(function(m) {
        return m.homeName.toLowerCase().indexOf(q) !== -1 ||
               m.awayName.toLowerCase().indexOf(q) !== -1 ||
               m.competitionName.toLowerCase().indexOf(q) !== -1 ||
               (m.roundName && m.roundName.toLowerCase().indexOf(q) !== -1)
      })
    }
    return list
  }

  // Group filtered matches by tournament/competition
  readonly property var groupedTournaments: {
    var list = filteredMatches || []
    if (list.length === 0) return []

    var map = {}
    var groups = []

    for (var i = 0; i < list.length; i++) {
      var m = list[i]
      var compKey = m.competitionSlug && m.competitionSlug !== "all" ? m.competitionSlug : m.competitionName
      if (!map[compKey]) {
        var grp = {
          key: compKey,
          name: m.competitionName,
          logo: m.competitionLogo,
          slug: m.competitionSlug,
          isMajor: m.isMajorLeague,
          isInternational: m.isInternational,
          hasLive: false,
          liveCount: 0,
          earliestKickoff: 9999999999999,
          matches: []
        }
        map[compKey] = grp
        groups.push(grp)
      }
      var g = map[compKey]
      g.matches.push(m)
      if (m.isLive) {
        g.hasLive = true
        g.liveCount++
      }
      if (m.state === "pre" && m.kickoffMs > 0 && m.kickoffMs < g.earliestKickoff) {
        g.earliestKickoff = m.kickoffMs
      }
    }

    // Sort tournament groups:
    // 1. Tournaments with live matches come first
    // 2. Tournaments with upcoming matches (by earliest kickoff)
    // 3. Major leagues / international tournaments
    // 4. Alphabetical by name
    groups.sort(function(a, b) {
      if (a.hasLive && !b.hasLive) return -1
      if (!a.hasLive && b.hasLive) return 1
      if (a.hasLive && b.hasLive) return b.liveCount - a.liveCount

      var aHasPre = a.matches.some(function(m) { return m.state === "pre" })
      var bHasPre = b.matches.some(function(m) { return m.state === "pre" })
      if (aHasPre && !bHasPre) return -1
      if (!aHasPre && bHasPre) return 1
      if (aHasPre && bHasPre && a.earliestKickoff !== b.earliestKickoff) {
        return a.earliestKickoff - b.earliestKickoff
      }

      if (a.isMajor && !b.isMajor) return -1
      if (!a.isMajor && b.isMajor) return 1

      return a.name.localeCompare(b.name)
    })

    return groups
  }

  // Search Filter Input Field
  Rectangle {
    width: parent.width
    height: Style.space(38)
    radius: Style.cornerRadius
    color: Util.alpha(root ? root.contentForeground : ShellColor.foreground, 0.07)
    border.width: Style.spacing.hairline
    border.color: trendingSearchInput.activeFocus
      ? (root ? root.favoriteTeamAccent : ShellColor.accent)
      : Util.alpha(root ? root.contentForeground : ShellColor.foreground, 0.15)

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: "󰍉"
        font.family: root ? root.contentFontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
        color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.4)
      }

      TextField {
        id: trendingSearchInput
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(30) - (clearTrendingSearchBtn.visible ? clearTrendingSearchBtn.width + parent.spacing : 0)
        height: parent.height
        verticalPadding: 0
        horizontalPadding: 0
        placeholderText: "Filter matches by team, league, or round…"
        font.family: root ? root.contentFontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
        foreground: root ? root.contentForeground : ShellColor.foreground
        background: null
        text: trendingView.trendingFilterText
        onTextChanged: trendingView.trendingFilterText = text
        Keys.onEscapePressed: function(event) {
          if (trendingView.trendingFilterText !== "") {
            trendingView.trendingFilterText = ""
            trendingSearchInput.text = ""
            event.accepted = true
          } else {
            trendingSearchInput.focus = false
            event.accepted = false
          }
        }
      }

      Button {
        id: clearTrendingSearchBtn
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(22)
        height: Style.space(22)
        iconText: "󰅖"
        iconSize: Style.font.caption
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : ShellColor.foreground
        accent: root ? root.contentForeground : ShellColor.foreground
        horizontalPadding: 0
        verticalPadding: 0
        visible: trendingSearchInput.text.length > 0
        onClicked: {
          trendingSearchInput.text = ""
          trendingView.trendingFilterText = ""
          trendingSearchInput.forceActiveFocus()
        }
      }
    }
  }

  // CONTROLS BAR: Day Selector (Yesterday, Today, Tomorrow)
  Row {
    width: parent.width
    spacing: Style.space(4)

    Button {
      height: Style.space(22)
      text: "Yesterday"
      tooltipText: "View yesterday's completed matches"
      fontFamily: root ? root.contentFontFamily : Style.font.family
      foreground: root ? root.contentForeground : ShellColor.foreground
      accent: root ? root.contentForeground : ShellColor.foreground
      fontSize: Style.font.caption - 1
      selected: trendingView.dayOffset === -1
      horizontalPadding: Style.space(10)
      verticalPadding: 0
      onClicked: {
        if (trendingView.dayOffset !== -1) {
          trendingView.dayOffset = -1
          trendingView.rawMatches = []
          trendingView.refresh(true)
        }
      }
    }

    Button {
      height: Style.space(22)
      text: "Today"
      tooltipText: "View today's live & upcoming matches"
      fontFamily: root ? root.contentFontFamily : Style.font.family
      foreground: root ? root.contentForeground : ShellColor.foreground
      accent: root ? root.contentForeground : ShellColor.foreground
      fontSize: Style.font.caption - 1
      selected: trendingView.dayOffset === 0
      horizontalPadding: Style.space(10)
      verticalPadding: 0
      onClicked: {
        if (trendingView.dayOffset !== 0) {
          trendingView.dayOffset = 0
          trendingView.rawMatches = []
          trendingView.refresh(true)
        }
      }
    }

    Button {
      height: Style.space(22)
      text: "Tomorrow"
      tooltipText: "View tomorrow's upcoming fixtures"
      fontFamily: root ? root.contentFontFamily : Style.font.family
      foreground: root ? root.contentForeground : ShellColor.foreground
      accent: root ? root.contentForeground : ShellColor.foreground
      fontSize: Style.font.caption - 1
      selected: trendingView.dayOffset === 1
      horizontalPadding: Style.space(10)
      verticalPadding: 0
      onClicked: {
        if (trendingView.dayOffset !== 1) {
          trendingView.dayOffset = 1
          trendingView.rawMatches = []
          trendingView.refresh(true)
        }
      }
    }
  }

  // CONTROLS BAR: Clean Category Pills + Refresh Button
  Item {
    width: parent.width
    height: Style.space(26)

    Flickable {
      anchors.left: parent.left
      anchors.right: refreshBtn.left
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height
      contentWidth: categoryRow.implicitWidth
      contentHeight: height
      flickableDirection: Flickable.HorizontalFlick
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentWidth > width

      Row {
        id: categoryRow
        height: parent.height
        spacing: Style.space(4)

        Button {
          height: Style.space(24)
          text: "All"
          tooltipText: "All Matches (1)"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : ShellColor.foreground
          accent: root ? root.contentForeground : ShellColor.foreground
          fontSize: Style.font.caption
          selected: trendingView.activeCategory === "all"
          horizontalPadding: Style.space(12)
          verticalPadding: 0
          onClicked: trendingView.activeCategory = "all"
        }

        Button {
          height: Style.space(24)
          text: "Live"
          tooltipText: "Live Matches (2)"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : ShellColor.foreground
          accent: root ? root.contentForeground : ShellColor.foreground
          fontSize: Style.font.caption
          selected: trendingView.activeCategory === "live"
          horizontalPadding: Style.space(12)
          verticalPadding: 0
          onClicked: trendingView.activeCategory = "live"
        }

        Button {
          height: Style.space(24)
          text: "International"
          tooltipText: "International Tournaments (3)"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : ShellColor.foreground
          accent: root ? root.contentForeground : ShellColor.foreground
          fontSize: Style.font.caption
          selected: trendingView.activeCategory === "international"
          horizontalPadding: Style.space(12)
          verticalPadding: 0
          onClicked: trendingView.activeCategory = "international"
        }

        Button {
          height: Style.space(24)
          text: "Club Leagues"
          tooltipText: "Club Leagues & Tournaments (4)"
          fontFamily: root ? root.contentFontFamily : Style.font.family
          foreground: root ? root.contentForeground : ShellColor.foreground
          accent: root ? root.contentForeground : ShellColor.foreground
          fontSize: Style.font.caption
          selected: trendingView.activeCategory === "club"
          horizontalPadding: Style.space(12)
          verticalPadding: 0
          onClicked: trendingView.activeCategory = "club"
        }
      }
    }

    Button {
      id: refreshBtn
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(24)
      height: Style.space(24)
      iconText: "󰑐"
      tooltipText: "Refresh trending matches"
      fontFamily: root ? root.contentFontFamily : Style.font.family
      foreground: root ? root.contentForeground : ShellColor.foreground
      accent: root ? root.contentForeground : ShellColor.foreground
      iconSize: Style.font.caption
      iconSpinning: trendingView.trendingLoading
      horizontalPadding: 0
      verticalPadding: 0
      onClicked: trendingView.refresh(true)
    }
  }

  // LOADING STATE
  Item {
    width: parent.width
    height: Style.space(120)
    visible: trendingView.trendingLoading && trendingView.rawMatches.length === 0

    FutLoadingOverlay {
      root: trendingView.root
      active: trendingView.trendingLoading && trendingView.rawMatches.length === 0
      text: "Loading trending matches…"
    }
  }

  // EMPTY STATE
  Item {
    width: parent.width
    height: Style.space(90)
    visible: !trendingView.trendingLoading && trendingView.trendingError === "" && ((trendingView.rawMatches.length > 0 && trendingView.groupedTournaments.length === 0) || (trendingView.rawMatches.length === 0))

    Column {
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: "󰈸"
        color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.8)
        font.family: root ? root.contentFontFamily : Style.font.family
        font.pixelSize: Style.space(26)
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: {
          if (trendingView.rawMatches.length === 0) return "No trending matches scheduled right now"
          if (trendingView.trendingFilterText.trim() !== "") return "No matches matching \"" + trendingView.trendingFilterText.trim() + "\""
          if (trendingView.activeCategory === "live") return "No live matches at the moment"
          return "No matches in this category"
        }
        color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.4)
        font.family: root ? root.contentFontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  // ERROR STATE
  Item {
    width: parent.width
    height: Style.space(90)
    visible: trendingView.trendingError !== "" && trendingView.rawMatches.length === 0

    Column {
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: "󰅚"
        color: "#ef4444"
        font.family: root ? root.contentFontFamily : Style.font.family
        font.pixelSize: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: trendingView.trendingError || "Failed to load matches"
        color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.4)
        font.family: root ? root.contentFontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
      }

      Button {
        anchors.horizontalCenter: parent.horizontalCenter
        height: Style.space(24)
        text: "Retry"
        iconText: "󰑐"
        fontFamily: root ? root.contentFontFamily : Style.font.family
        foreground: root ? root.contentForeground : ShellColor.foreground
        accent: root ? root.contentForeground : ShellColor.foreground
        fontSize: Style.font.caption
        iconSize: Style.font.caption
        horizontalPadding: Style.space(12)
        verticalPadding: 0
        onClicked: trendingView.refresh(true)
      }
    }
  }

  // STALE / CACHED STATUS (Subtle banner when refresh failed but cache exists)
  Rectangle {
    width: parent.width
    height: Style.space(22)
    radius: Style.cornerRadius
    color: Util.alpha(ShellColor.foreground, 0.05)
    visible: trendingView.trendingError !== "" && trendingView.rawMatches.length > 0

    Row {
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: "󰒲"
        font.pixelSize: Style.font.caption
        color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.5)
      }

      Text {
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: (root && root.formatCachedTimeAgo) ? root.formatCachedTimeAgo(trendingView.lastRefreshTime) : "Cached · Updated recently"
        font.family: root ? root.contentFontFamily : Style.font.family
        font.pixelSize: Style.font.caption - 1
        color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.5)
      }
    }
  }

  // TOURNAMENT-GROUPED MATCHES LIST
  Column {
    id: tournamentGroupsCol
    width: parent.width
    spacing: Style.space(12)
    visible: trendingView.groupedTournaments.length > 0

    Repeater {
      model: trendingView.groupedTournaments
      delegate: Column {
        id: tournamentSection
        required property var modelData
        required property int index
        width: tournamentGroupsCol.width
        spacing: Style.space(4)

        readonly property int defaultLimit: 3
        readonly property int threshold: 4
        readonly property bool isExpanded: !!trendingView.expandedMap[tournamentSection.modelData.key]
        readonly property var visibleMatches: {
          if (isExpanded || tournamentSection.modelData.matches.length <= threshold) {
            return tournamentSection.modelData.matches
          }
          var count = Math.max(defaultLimit, tournamentSection.modelData.liveCount)
          return tournamentSection.modelData.matches.slice(0, count)
        }

        // Tournament Section Header
        Item {
          width: parent.width
          height: Style.space(24)

          Rectangle {
            anchors.fill: parent
            radius: Style.space(4)
            color: root ? root.contentForeground : ShellColor.foreground
            opacity: headerMouseArea.containsMouse ? 0.05 : 0.0
          }

          MouseArea {
            id: headerMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: trendingView.toggleCollapse(tournamentSection.modelData.key)
          }

          Row {
            anchors.left: parent.left
            anchors.right: chevronText.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Image {
              id: tournamentSectionLogo
              anchors.verticalCenter: parent.verticalCenter
              width: visible ? Style.space(16) : 0
              height: Style.space(16)
              source: tournamentSection.modelData.logo || ""
              fillMode: Image.PreserveAspectFit
              sourceSize.width: 32
              sourceSize.height: 32
              mipmap: true
              asynchronous: true
              cache: true
              smooth: true
              visible: String(source) !== "" && status === Image.Ready
            }

            Text {
              id: tournamentTitleText
              textFormat: Text.PlainText
              width: parent.width - (tournamentSectionLogo.visible ? tournamentSectionLogo.width + parent.spacing : 0)
              anchors.verticalCenter: parent.verticalCenter
              text: tournamentSection.modelData.name
              color: root ? root.contentForeground : ShellColor.foreground
              font.family: root ? root.contentFontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              elide: Text.ElideRight
            }
          }

          Text {
            id: chevronText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: trendingView.collapsedMap[tournamentSection.modelData.key] ? "󰅂" : "󰅃"
            color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.6)
            font.family: root ? root.contentFontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        // Matches in this tournament
        Column {
          id: tournamentMatchesCol
          width: parent.width
          spacing: Style.space(4)
          visible: !trendingView.collapsedMap[tournamentSection.modelData.key]

          Repeater {
            model: tournamentSection.visibleMatches
            delegate: Item {
              id: matchRow
              required property var modelData
              required property int index
              width: tournamentMatchesCol.width
              height: matchInnerCol.implicitHeight + Style.space(12)
              readonly property bool hasFollowedTeam: trendingView.isFollowedTeam(matchRow.modelData.homeName) || trendingView.isFollowedTeam(matchRow.modelData.awayName)
              readonly property bool isKeyboardSelected: !!(trendingView.flatVisibleMatches && trendingView.keyboardSelectedMatchIndex >= 0 && trendingView.flatVisibleMatches[trendingView.keyboardSelectedMatchIndex] && matchRow.modelData && (trendingView.flatVisibleMatches[trendingView.keyboardSelectedMatchIndex].id === matchRow.modelData.id))

              Rectangle {
                anchors.fill: parent
                radius: Style.space(6)
                color: root ? root.contentForeground : ShellColor.foreground
                opacity: matchRow.isKeyboardSelected
                  ? 0.12
                  : (matchRow.modelData.isLive
                    ? 0.08
                    : (rowMouseArea.containsMouse ? 0.06 : 0.03))
                border.color: matchRow.isKeyboardSelected
                  ? ((root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : ShellColor.accent)
                  : (matchRow.hasFollowedTeam ? (root ? root.favoriteTeamAccent : "#facc15") : "transparent")
                border.width: matchRow.isKeyboardSelected ? 1.5 : (matchRow.hasFollowedTeam ? 1 : 0)
                Behavior on opacity { NumberAnimation { duration: 120 } }
              }

              MouseArea {
                id: rowMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root) {
                    root.returnToTrendingAfterDetail = true
                    root.openMatchDetail({
                      id: matchRow.modelData.id,
                      competitionSlug: matchRow.modelData.competitionSlug,
                      competitionName: matchRow.modelData.competitionName,
                      competitionLogo: matchRow.modelData.competitionLogo,
                      homeName: matchRow.modelData.homeName,
                      homeLogo: matchRow.modelData.homeLogo,
                      homeScore: matchRow.modelData.homeScore,
                      awayName: matchRow.modelData.awayName,
                      awayLogo: matchRow.modelData.awayLogo,
                      awayScore: matchRow.modelData.awayScore,
                      status: matchRow.modelData.statusDetail,
                      shootoutNote: matchRow.modelData.shootoutNote,
                      seriesNote: matchRow.modelData.seriesNote,
                      roundName: matchRow.modelData.roundName,
                      state: matchRow.modelData.state,
                      date: matchRow.modelData.date,
                      dateText: matchRow.modelData.dateText,
                      timeText: matchRow.modelData.timeText
                    })
                  }
                }
              }

              Column {
                id: matchInnerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                anchors.topMargin: Style.space(6)
                spacing: Style.space(3)

                // Match Header info (Followed star, Round/stage name, Date & relative kickoff countdown, 1-click notification toggle)
                Item {
                  width: parent.width
                  height: visible ? Style.space(13) : 0
                  visible: matchFollowedStar.visible || matchTopLeftText.text !== "" || matchTopRightText.visible || matchNotifyBtn.visible

                  Row {
                    id: matchTopLeftRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: matchTopRightRow.left
                    anchors.rightMargin: Style.space(4)
                    spacing: Style.space(3)

                    Text {
                      id: matchFollowedStar
                      visible: matchRow.hasFollowedTeam
                      textFormat: Text.PlainText
                      text: ""
                      color: root ? root.favoriteTeamAccent : "#facc15"
                      font.family: root ? root.contentFontFamily : Style.font.family
                      font.pixelSize: Style.space(8.5)
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      id: matchTopLeftText
                      textFormat: Text.PlainText
                      visible: text !== ""
                      text: matchRow.modelData.roundName || ""
                      color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.45)
                      font.family: root ? root.contentFontFamily : Style.font.family
                      font.pixelSize: Style.space(8.5)
                      font.bold: true
                      elide: Text.ElideRight
                      anchors.verticalCenter: parent.verticalCenter
                      width: Math.min(implicitWidth, Math.max(0, parent.width - (matchFollowedStar.visible ? (matchFollowedStar.implicitWidth + parent.spacing) : 0)))
                    }
                  }

                  Row {
                    id: matchTopRightRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Text {
                      id: matchTopRightText
                      textFormat: Text.PlainText
                      anchors.verticalCenter: parent.verticalCenter
                      text: {
                        if (matchRow.modelData.isLive) return ""
                        var d = matchRow.modelData.dateText || ""
                        if (matchRow.modelData.state === "pre") {
                          var rel = root && matchRow.modelData.kickoffMs ? root.relativeKickoffText(matchRow.modelData.kickoffMs) : ""
                          if (rel !== "") {
                            return d !== "" ? (d + " (" + rel + ")") : rel
                          }
                        }
                        return d
                      }
                      color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.55)
                      font.family: root ? root.contentFontFamily : Style.font.family
                      font.pixelSize: Style.space(8.5)
                      font.bold: true
                      visible: text !== ""
                    }

                    Button {
                      id: matchNotifyBtn
                      z: 5
                      visible: matchRow.modelData.state !== "post"
                      anchors.verticalCenter: parent.verticalCenter
                      iconText: (root && root.isLeagueMatchFollowed && root.isLeagueMatchFollowed(matchRow.modelData.id)) ? "󰴅" : "󰡬"
                      text: (root && root.isLeagueMatchFollowed && root.isLeagueMatchFollowed(matchRow.modelData.id)) ? "Following" : "Notify"
                      tooltipText: (root && root.isLeagueMatchFollowed && root.isLeagueMatchFollowed(matchRow.modelData.id))
                        ? "Stop notifications for this match" : "Notify on goals, cards, and match events"
                      fontFamily: root ? root.contentFontFamily : Style.font.family
                      foreground: root ? root.contentForeground : ShellColor.foreground
                      accent: (root && root.favoriteTeamAccent) ? root.favoriteTeamAccent : ShellColor.accent
                      fontSize: Style.space(7.5)
                      iconSize: Style.space(7.5)
                      horizontalPadding: Style.space(4)
                      verticalPadding: 0
                      height: Style.space(13)
                      selected: root && root.isLeagueMatchFollowed && root.isLeagueMatchFollowed(matchRow.modelData.id)
                      onClicked: {
                        if (root && root.toggleLeagueMatchFollow) {
                          root.toggleLeagueMatchFollow(matchRow.modelData.id)
                        }
                      }
                    }
                  }
                }

                // Matchup Row: Home Crest & Name - Center Score / Status - Away Name & Crest
                Row {
                  id: matchupRow
                  width: parent.width
                  height: Math.max(root ? root.matchLogoSize : Style.space(24), homeNameText.implicitHeight, awayNameText.implicitHeight, centerScoreItem.height)
                  spacing: Style.space(6)

                  // Home Crest (Outer Left)
                  Item {
                    width: root ? root.matchLogoSize : Style.space(24)
                    height: root ? root.matchLogoSize : Style.space(24)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                      anchors.centerIn: parent
                      width: parent.width
                      height: parent.height
                      source: matchRow.modelData.homeLogo
                      fillMode: Image.PreserveAspectFit
                      sourceSize.width: 64
                      sourceSize.height: 64
                      mipmap: true
                      asynchronous: true
                      cache: true
                      smooth: true
                      visible: String(source) !== ""
                    }
                  }

                  // Home Name (Right-aligned)
                  Text {
                    id: homeNameText
                    textFormat: Text.PlainText
                    width: (parent.width - parent.spacing * 4 - (root ? root.matchScoreWidth : Style.space(80)) - (root ? root.matchLogoSize : Style.space(24)) * 2) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: matchRow.modelData.homeName
                    color: root ? root.contentForeground : ShellColor.foreground
                    font.family: root ? root.contentFontFamily : Style.font.family
                    font.pixelSize: text.length > 22 ? Style.space(10) : (text.length > 15 ? Style.font.bodySmall : Style.font.body)
                    font.bold: matchRow.modelData.isLive
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    lineHeight: 0.95
                    horizontalAlignment: Text.AlignRight
                  }

                  // Center Score / Status
                  Item {
                    id: centerScoreItem
                    width: root ? root.matchScoreWidth : Style.space(80)
                    height: Math.max(root ? root.matchLogoSize : Style.space(24), scoreCol.implicitHeight)
                    anchors.verticalCenter: parent.verticalCenter

                    Column {
                      id: scoreCol
                      anchors.centerIn: parent
                      spacing: Style.space(1)

                      Text {
                        id: matchScoreText
                        textFormat: Text.PlainText
                        anchors.horizontalCenter: parent.horizontalCenter
                        property bool revealed: false
                        text: matchRow.modelData.state === "pre"
                          ? (matchRow.modelData.timeText || "VS")
                          : ((root && root.antiSpoiler && !revealed)
                            ? (matchRow.modelData.state === "post" ? "FT · 󰈈" : "Live · 󰈈")
                            : (matchRow.modelData.homeScore + "–" + matchRow.modelData.awayScore))
                        color: (root && root.antiSpoiler && !revealed && matchRow.modelData.state !== "pre")
                          ? (root.favoriteTeamAccent || (root ? root.contentForeground : ShellColor.foreground))
                          : (matchRow.modelData.isLive ? "#4ade80" : (root ? root.contentForeground : ShellColor.foreground))
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: (root && root.antiSpoiler && !revealed && matchRow.modelData.state !== "pre")
                          ? Style.font.caption
                          : ((matchRow.modelData.state === "pre" && !matchRow.modelData.isLive) ? Style.font.caption : Style.font.body)
                        font.bold: matchRow.modelData.state !== "post" || matchRow.modelData.isLive
                        horizontalAlignment: Text.AlignHCenter
                      }

                      Text {
                        id: matchRowSubText
                        textFormat: Text.PlainText
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: text !== "" && !(root && root.antiSpoiler && !matchScoreText.revealed)
                        text: {
                          if (matchRow.modelData.isLive) {
                            var lt = matchRow.modelData.statusDetail || "Live"
                            if (matchRow.modelData.seriesNote) lt += " · " + matchRow.modelData.seriesNote
                            return lt
                          }
                          if (matchRow.modelData.state === "post") {
                            var s = matchRow.modelData.statusDetail || "FT"
                            if (matchRow.modelData.shootoutNote) s += " (" + matchRow.modelData.shootoutNote + ")"
                            else if (matchRow.modelData.seriesNote) s += " (" + matchRow.modelData.seriesNote + ")"
                            return s
                          }
                          if (matchRow.modelData.shootoutNote) return matchRow.modelData.shootoutNote
                          if (matchRow.modelData.seriesNote) return matchRow.modelData.seriesNote
                          return ""
                        }
                        color: matchRow.modelData.isLive
                          ? "#4ade80" : Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.6)
                        font.family: root ? root.contentFontFamily : Style.font.family
                        font.pixelSize: Style.space(8)
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        width: centerScoreItem.width
                      }
                    }

                    MouseArea {
                      anchors.fill: parent
                      enabled: root && root.antiSpoiler && !matchScoreText.revealed && matchRow.modelData.state !== "pre"
                      cursorShape: Qt.PointingHandCursor
                      onClicked: matchScoreText.revealed = true
                    }
                  }

                  // Away Name (Left-aligned)
                  Text {
                    id: awayNameText
                    textFormat: Text.PlainText
                    width: (parent.width - parent.spacing * 4 - (root ? root.matchScoreWidth : Style.space(80)) - (root ? root.matchLogoSize : Style.space(24)) * 2) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: matchRow.modelData.awayName
                    color: root ? root.contentForeground : ShellColor.foreground
                    font.family: root ? root.contentFontFamily : Style.font.family
                    font.pixelSize: text.length > 22 ? Style.space(10) : (text.length > 15 ? Style.font.bodySmall : Style.font.body)
                    font.bold: matchRow.modelData.isLive
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    lineHeight: 0.95
                    horizontalAlignment: Text.AlignLeft
                  }

                  // Away Crest (Outer Right)
                  Item {
                    width: root ? root.matchLogoSize : Style.space(24)
                    height: root ? root.matchLogoSize : Style.space(24)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                      anchors.centerIn: parent
                      width: parent.width
                      height: parent.height
                      source: matchRow.modelData.awayLogo
                      fillMode: Image.PreserveAspectFit
                      sourceSize.width: 64
                      sourceSize.height: 64
                      mipmap: true
                      cache: true
                      asynchronous: true
                      smooth: true
                      visible: String(source) !== ""
                    }
                  }
                }
              }
            }
          }

          // Show more / Show less button
          Item {
            id: showMoreBtn
            width: parent.width
            height: Style.space(24)
            visible: tournamentSection.modelData.matches.length > tournamentSection.threshold

            Rectangle {
              anchors.fill: parent
              radius: Style.space(4)
              color: root ? root.contentForeground : ShellColor.foreground
              opacity: showMoreMouseArea.containsMouse ? 0.08 : 0.03
            }

            MouseArea {
              id: showMoreMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: trendingView.toggleExpand(tournamentSection.modelData.key)
            }

            Row {
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: tournamentSection.isExpanded
                  ? "Show less"
                  : ("Show " + (tournamentSection.modelData.matches.length - tournamentSection.visibleMatches.length) + " more")
                color: root ? root.contentForeground : ShellColor.foreground
                font.family: root ? root.contentFontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: tournamentSection.isExpanded ? "󰅃" : "󰅂"
                color: Qt.darker(root ? root.contentForeground : ShellColor.foreground, 1.5)
                font.family: root ? root.contentFontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
      }
    }
  }

  // BOTTOM PADDING
  Item {
    width: parent.width
    height: Style.space(12)
  }
}
