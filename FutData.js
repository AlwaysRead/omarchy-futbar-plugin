.pragma library

  var knownClubAbbrevs = {
    "arsenal": "ARS", "aston villa": "AVL", "afc bournemouth": "BOU", "bournemouth": "BOU",
    "brentford": "BRE", "brighton": "BHA", "brighton & hove albion": "BHA", "chelsea": "CHE",
    "crystal palace": "CRY", "everton": "EVE", "fulham": "FUL", "ipswich town": "IPS",
    "ipswich": "IPS", "leicester city": "LEI", "leicester": "LEI", "liverpool": "LIV",
    "manchester city": "MCI", "man city": "MCI", "manchester united": "MUN", "man united": "MUN",
    "man utd": "MUN", "newcastle united": "NEW", "newcastle": "NEW", "nottingham forest": "NFO",
    "southampton": "SOU", "tottenham hotspur": "TOT", "tottenham": "TOT", "spurs": "TOT",
    "west ham united": "WHU", "west ham": "WHU", "wolverhampton wanderers": "WOL", "wolves": "WOL",
    "alavés": "ALA", "deportivo alavés": "ALA", "athletic club": "ATH", "athletic bilbao": "ATH",
    "atlético madrid": "ATM", "atlético de madrid": "ATM", "atletico madrid": "ATM",
    "barcelona": "BAR", "fc barcelona": "BAR", "celta vigo": "CEL", "celta de vigo": "CEL",
    "espanyol": "ESP", "getafe": "GET", "girona": "GIR", "las palmas": "LPA", "leganés": "LEG",
    "mallorca": "MLL", "rcd mallorca": "MLL", "osasuna": "OSA", "rayo vallecano": "RAY",
    "real betis": "BET", "real madrid": "RMA", "real sociedad": "RSO", "real valladolid": "VLD",
    "valladolid": "VLD", "sevilla": "SEV", "valencia": "VAL", "villarreal": "VIL",
    "bayer leverkusen": "B04", "leverkusen": "B04", "bayern munich": "BAY", "bayern münchen": "BAY",
    "bayern": "BAY", "borussia dortmund": "BVB", "dortmund": "BVB", "borussia mönchengladbach": "BMG",
    "mönchengladbach": "BMG", "gladbach": "BMG", "eintracht frankfurt": "SGE", "frankfurt": "SGE",
    "freiburg": "SCF", "sc freiburg": "SCF", "heidenheim": "HDH", "hoffenheim": "TSG",
    "tsg hoffenheim": "TSG", "holstein kiel": "KIE", "mainz": "M05", "mainz 05": "M05",
    "rb leipzig": "RBL", "leipzig": "RBL", "st. pauli": "STP", "fc st. pauli": "STP",
    "augsburg": "FCA", "fc augsburg": "FCA", "union berlin": "FCU", "vfb stuttgart": "VFB",
    "stuttgart": "VFB", "vfl bochum": "BOC", "bochum": "BOC", "vfl wolfsburg": "WOB",
    "wolfsburg": "WOB", "werder bremen": "SVW", "bremen": "SVW", "ac milan": "MIL",
    "milan": "MIL", "atalanta": "ATA", "bologna": "BOL", "cagliari": "CAG", "como": "COM",
    "empoli": "EMP", "fiorentina": "FIO", "genoa": "GEN", "hellas verona": "VER",
    "verona": "VER", "inter": "INT", "internazionale": "INT", "inter milan": "INT",
    "juventus": "JUV", "lazio": "LAZ", "lecce": "LEC", "monza": "MON", "napoli": "NAP",
    "parma": "PAR", "roma": "ROM", "as roma": "ROM", "torino": "TOR", "udinese": "UDI",
    "venezia": "VEN", "paris saint-germain": "PSG", "psg": "PSG", "marseille": "OM",
    "olympique de marseille": "OM", "lyon": "OL", "olympique lyonnais": "OL", "monaco": "ASM",
    "as monaco": "ASM", "lille": "LIL", "losc lille": "LIL", "nice": "NIC", "ogc nice": "NIC",
    "lens": "RCL", "rc lens": "RCL", "rennes": "REN", "ajax": "AJA", "psv": "PSV",
    "psv eindhoven": "PSV", "feyenoord": "FEY", "benfica": "SLB", "sporting cp": "SCP",
    "sporting lisbon": "SCP", "porto": "FCP", "fc porto": "FCP", "celtic": "CEL",
    "rangers": "RAN", "galatasaray": "GAL", "fenerbahçe": "FEN", "beşiktaş": "BJK",
    "al hilal": "HIL", "al nassr": "NAS", "al ittihad": "ITT", "inter miami": "MIA",
    "inter miami cf": "MIA", "la galaxy": "LAG", "lafc": "LAF", "boca juniors": "BOC",
    "river plate": "RIV", "flamengo": "FLA", "palmeiras": "PAL",
    "rb salzburg": "RBS", "red bull salzburg": "RBS", "salzburg": "RBS",
    "molde": "MOL", "molde fk": "MOL", "bryne": "BRY", "bryne fk": "BRY",
    "santos": "SAN", "santos fc": "SAN", "newell's old boys": "NOB", "newells old boys": "NOB",
    "rosario central": "ROS", "dinamo zagreb": "DZG", "gnk dinamo zagreb": "DZG",
    "krc genk": "GNK", "genk": "GNK", "anderlecht": "AND", "rsc anderlecht": "AND",
    "club brugge": "CLU", "brugge": "CLU", "basel": "BAS", "fc basel": "BAS",
    "shakhtar donetsk": "SHK", "shakhtar": "SHK", "dynamo kyiv": "DYN",
    "olympiacos": "OLY", "panathinaikos": "PAO", "slavia prague": "SLA",
    "sparta prague": "SPA", "young boys": "YB", "bsc young boys": "YB",
    "red star": "RSB", "crvena zvezda": "CZV",
    "unattached": "FA", "free agent": "FA", "free transfer": "FA", "without club": "FA"
  };

  function computeClubAbbrev(rawName) {
    var clean = String(rawName || "")
      .replace(/^(FC|CF|AFC|SC|AC|CD|CA|RC|UD|RCD|VfB|VfL|TSG|FSV|1\.\s*FC|1\.\s*FSV|SSV|SV)\s+/i, "")
      .replace(/\s+(FC|CF|AFC|SC|AC|CD|CA|RC|UD|de\s+Fútbol|de\s+Futbol|FK)$/i, "")
      .replace(/&/g, " ")
      .trim()
    var words = clean.split(/[\s\-_]+/).filter(function(w) { return w.length > 0 })
    if (words.length >= 3) {
      return (words[0][0] + words[1][0] + words[2][0]).toUpperCase()
    }
    if (words.length === 2) {
      if (words[0].length >= 2) return (words[0].substring(0, 2) + words[1][0]).toUpperCase()
      return (words[0][0] + words[1].substring(0, 2)).toUpperCase()
    }
    if (clean.length >= 3) return clean.substring(0, 3).toUpperCase()
    return clean.toUpperCase()
  }

  function getClubAbbrev(name, explicitAbbrev) {
    var raw = String(name || "").trim()
    if (raw === "") return ""
    var lower = raw.toLowerCase()
    if (knownClubAbbrevs[lower]) return knownClubAbbrevs[lower]
    if (explicitAbbrev && String(explicitAbbrev).trim() !== "") {
      var ea = String(explicitAbbrev).trim().toUpperCase()
      if (ea.length <= 4) return ea
    }
    return computeClubAbbrev(raw)
  }

  function computeClubShort(rawName) {
    var clean = String(rawName || "")
      .replace(/^(FC|CF|AFC|SC|AC|CD|CA|RC|UD|RCD|VfB|VfL|TSG|FSV|1\.\s*FC|1\.\s*FSV|SSV|SV)\s+/i, "")
      .replace(/\s+(FC|CF|AFC|SC|AC|CD|CA|RC|UD|de\s+Fútbol|de\s+Futbol)$/i, "")
      .replace(/&/g, "and")
      .trim()
    var words = clean.split(/[\s\-_]+/).filter(function(w) { return w.length > 0 })
    if (words.length > 1 && clean.length > 14) {
      return words[0]
    }
    return clean
  }


  var knownClubShorts = {
    "arsenal": "Arsenal", "aston villa": "Villa", "afc bournemouth": "Bournemouth", "bournemouth": "Bournemouth",
    "brentford": "Brentford", "brighton": "Brighton", "brighton & hove albion": "Brighton", "chelsea": "Chelsea",
    "crystal palace": "Palace", "everton": "Everton", "fulham": "Fulham", "ipswich town": "Ipswich",
    "ipswich": "Ipswich", "leicester city": "Leicester", "leicester": "Leicester", "liverpool": "Liverpool",
    "manchester city": "Man City", "man city": "Man City", "manchester united": "Man Utd", "man united": "Man Utd",
    "man utd": "Man Utd", "newcastle united": "Newcastle", "newcastle": "Newcastle", "nottingham forest": "Forest",
    "southampton": "Southampton", "tottenham hotspur": "Spurs", "tottenham": "Spurs", "spurs": "Spurs",
    "west ham united": "West Ham", "west ham": "West Ham", "wolverhampton wanderers": "Wolves", "wolves": "Wolves",
    "deportivo alavés": "Alavés", "athletic club": "Athletic", "athletic bilbao": "Athletic",
    "atlético madrid": "Atlético", "atlético de madrid": "Atlético", "atletico madrid": "Atlético",
    "barcelona": "Barça", "fc barcelona": "Barça", "celta vigo": "Celta", "celta de vigo": "Celta",
    "rcd mallorca": "Mallorca", "rayo vallecano": "Rayo", "real betis": "Betis",
    "real sociedad": "Real Sociedad", "real valladolid": "Valladolid", "bayer leverkusen": "Leverkusen",
    "bayern munich": "Bayern", "bayern münchen": "Bayern", "borussia dortmund": "Dortmund",
    "borussia mönchengladbach": "Gladbach", "eintracht frankfurt": "Frankfurt", "sc freiburg": "Freiburg",
    "tsg hoffenheim": "Hoffenheim", "rb leipzig": "Leipzig", "fc st. pauli": "St. Pauli",
    "fc augsburg": "Augsburg", "union berlin": "Union Berlin", "vfb stuttgart": "Stuttgart",
    "vfl bochum": "Bochum", "vfl wolfsburg": "Wolfsburg", "werder bremen": "Bremen",
    "ac milan": "Milan", "hellas verona": "Verona", "internazionale": "Inter",
    "inter milan": "Inter", "as roma": "Roma", "paris saint-germain": "PSG",
    "olympique de marseille": "Marseille", "olympique lyonnais": "Lyon", "as monaco": "Monaco",
    "losc lille": "Lille", "ogc nice": "Nice", "rc lens": "Lens", "psv eindhoven": "PSV",
    "sporting cp": "Sporting", "sporting lisbon": "Sporting", "fc porto": "Porto",
    "inter miami cf": "Inter Miami"
  };

var leagues = [
    { value: "eng.1", label: "Premier League (England)" },
    { value: "esp.1", label: "LaLiga (Spain)" },
    { value: "ita.1", label: "Serie A (Italy)" },
    { value: "ger.1", label: "Bundesliga (Germany)" },
    { value: "fra.1", label: "Ligue 1 (France)" },
    { value: "ned.1", label: "Eredivisie (Netherlands)" },
    { value: "por.1", label: "Primeira Liga (Portugal)" },
    { value: "ksa.1", label: "Saudi Pro League" },
    { value: "usa.1", label: "MLS (USA)" },
    { value: "mex.1", label: "Liga MX (Mexico)" },
    { value: "bra.1", label: "Brasileirão Série A (Brazil)" },
    { value: "arg.1", label: "Liga Profesional (Argentina)" },
    { value: "sco.1", label: "Scottish Premiership" },
    { value: "bel.1", label: "Belgian Pro League" },
    { value: "tur.1", label: "Süper Lig (Turkey)" },
    { value: "aut.1", label: "Austrian Bundesliga" },
    { value: "gre.1", label: "Greek Super League" },
    { value: "den.1", label: "Danish Superliga" },
    { value: "swe.1", label: "Swedish Allsvenskan" },
    { value: "nor.1", label: "Norwegian Eliteserien" },
    { value: "rus.1", label: "Russian Premier League" },
    { value: "jpn.1", label: "J1 League (Japan)" },
    { value: "chn.1", label: "Chinese Super League" },
    { value: "ind.1", label: "Indian Super League" },
    { value: "aus.1", label: "A-League Men (Australia)" },
    { value: "col.1", label: "Categoría Primera A (Colombia)" },
    { value: "chi.1", label: "Primera División (Chile)" },
    { value: "per.1", label: "Liga 1 (Peru)" },
    { value: "ecu.1", label: "LigaPro Serie A (Ecuador)" },
    { value: "uru.1", label: "Primera División (Uruguay)" },
    { value: "par.1", label: "Primera División (Paraguay)" },
    { value: "bol.1", label: "División Profesional (Bolivia)" },
    { value: "ven.1", label: "Liga FUTVE (Venezuela)" },
    { value: "crc.1", label: "Liga Promerica (Costa Rica)" },
    { value: "rsa.1", label: "South African Premier Division" },
    { value: "eng.2", label: "Championship (England)" },
    { value: "eng.3", label: "League One (England)" },
    { value: "eng.4", label: "League Two (England)" },
    { value: "eng.5", label: "National League (England)" },
    { value: "esp.2", label: "LaLiga 2 (Spain)" },
    { value: "ger.2", label: "2. Bundesliga (Germany)" },
    { value: "ita.2", label: "Serie B (Italy)" },
    { value: "fra.2", label: "Ligue 2 (France)" },
    { value: "ned.2", label: "Eerste Divisie (Netherlands)" },
    { value: "sco.2", label: "Scottish Championship" },
    { value: "usa.usl.1", label: "USL Championship (USA)" },
    { value: "usa.usl.l1", label: "USL League One (USA)" },
    { value: "mex.2", label: "Liga de Expansión MX" },
    { value: "bra.2", label: "Brasileirão Série B" },
    { value: "arg.2", label: "Primera Nacional (Argentina)" },
    { value: "arg.3", label: "Primera B Metropolitana (Argentina)" },
    { value: "usa.nwsl", label: "NWSL (USA Women)" },
    { value: "eng.w.1", label: "Women's Super League (England)" },
    { value: "esp.w.1", label: "Liga F (Spain Women)" },
    { value: "fra.w.1", label: "Première Ligue (France Women)" },
    { value: "aus.w.1", label: "A-League Women (Australia)" },
    { value: "uefa.wchampions", label: "UEFA Women's Champions League" },
    { value: "concacaf.w.champions_cup", label: "CONCACAF W Champions Cup" },
    { value: "usa.w.usl.1", label: "USL Super League (USA Women)" },
    { value: "uefa.champions", label: "UEFA Champions League" },
    { value: "uefa.europa", label: "UEFA Europa League" },
    { value: "uefa.europa.conf", label: "UEFA Conference League" },
    { value: "uefa.super_cup", label: "UEFA Super Cup" },
    { value: "conmebol.libertadores", label: "CONMEBOL Copa Libertadores" },
    { value: "conmebol.sudamericana", label: "CONMEBOL Copa Sudamericana" },
    { value: "conmebol.recopa", label: "CONMEBOL Recopa Sudamericana" },
    { value: "concacaf.champions", label: "CONCACAF Champions Cup" },
    { value: "concacaf.leagues.cup", label: "Leagues Cup (MLS & Liga MX)" },
    { value: "afc.champions", label: "AFC Champions League Elite" },
    { value: "afc.cup", label: "AFC Champions League Two" },
    { value: "caf.champions", label: "CAF Champions League" },
    { value: "caf.confed", label: "CAF Confederation Cup" },
    { value: "fifa.cwc", label: "FIFA Club World Cup" },
    { value: "campeones.cup", label: "Campeones Cup" },
    { value: "eng.fa", label: "FA Cup (England)" },
    { value: "eng.league_cup", label: "Carabao Cup (England)" },
    { value: "eng.charity", label: "FA Community Shield (England)" },
    { value: "esp.copa_del_rey", label: "Copa del Rey (Spain)" },
    { value: "esp.super_cup", label: "Supercopa de España" },
    { value: "ita.coppa_italia", label: "Coppa Italia (Italy)" },
    { value: "ita.super_cup", label: "Supercoppa Italiana" },
    { value: "ger.dfb_pokal", label: "DFB-Pokal (Germany)" },
    { value: "ger.super_cup", label: "DFL-Supercup (Germany)" },
    { value: "fra.coupe_de_france", label: "Coupe de France" },
    { value: "fra.super_cup", label: "Trophée des Champions (France)" },
    { value: "usa.open", label: "US Open Cup" },
    { value: "por.taca.portugal", label: "Taça de Portugal" },
    { value: "ned.cup", label: "KNVB Beker (Netherlands)" },
    { value: "sco.tennents", label: "Scottish Cup" },
    { value: "sco.cis", label: "Scottish League Cup" },
    { value: "ksa.kings.cup", label: "King Cup of Champions (Saudi)" },
    { value: "bra.copa_do_brazil", label: "Copa do Brasil" },
    { value: "bra.supercopa_do_brazil", label: "Supercopa do Brasil" },
    { value: "arg.copa", label: "Copa Argentina" },
    { value: "arg.supercopa", label: "Supercopa Argentina" },
    { value: "col.copa", label: "Copa Colombia" },
    { value: "fifa.world", label: "FIFA World Cup" },
    { value: "fifa.wwc", label: "FIFA Women's World Cup" },
    { value: "uefa.euro", label: "UEFA European Championship (EURO)" },
    { value: "uefa.weuro", label: "UEFA Women's EURO" },
    { value: "uefa.nations", label: "UEFA Nations League" },
    { value: "uefa.w.nations", label: "UEFA Women's Nations League" },
    { value: "conmebol.america", label: "Copa América" },
    { value: "conmebol.america.femenina", label: "Copa América Femenina" },
    { value: "concacaf.gold", label: "CONCACAF Gold Cup" },
    { value: "concacaf.w.gold", label: "CONCACAF W Gold Cup" },
    { value: "concacaf.nations.league", label: "CONCACAF Nations League" },
    { value: "caf.nations", label: "Africa Cup of Nations (AFCON)" },
    { value: "afc.asian.cup", label: "AFC Asian Cup" },
    { value: "fifa.olympics", label: "Olympic Men Football" },
    { value: "fifa.w.olympics", label: "Olympic Women Football" },
    { value: "fifa.friendly", label: "International Friendlies" },
    { value: "fifa.friendly.w", label: "Women's Friendlies" },
    { value: "club.friendly", label: "Club Friendlies" },
    { value: "afc.cupq", label: "AFC Asian Cup Qualifiers" },
    { value: "afc.champions_qual", label: "AFC Champions League Elite Qualifying" },
    { value: "afc.cup_qual", label: "AFC Champions League Two Qualifying" },
    { value: "afc.w.asian.cup", label: "AFC Women's Asian Cup" },
    { value: "aff.championship", label: "ASEAN Championship" },
    { value: "caf.nations_qual", label: "Africa Cup of Nations Qualifying" },
    { value: "caf.championship", label: "African Nations Championship" },
    { value: "global.gulf_cup", label: "Arabian Gulf Cup" },
    { value: "arg.copa_de_la_superliga", label: "Argentine Copa de la Superliga" },
    { value: "arg.supercopa.internacional", label: "Argentine Supercopa Internacional" },
    { value: "arg.trofeo_de_la_campeones", label: "Argentine Trofeo de Campeones" },
    { value: "global.arnold.clark_cup", label: "Arnold Clark Cup" },
    { value: "bel.promotion.relegation", label: "Belgian Pro League Promotion/Relegation Playoffs" },
    { value: "bol.ply.rel", label: "Bolivian Liga Profesional Promotion/Relegation Playoffs" },
    { value: "bra.camp.carioca", label: "Brazilian Campeonato Carioca" },
    { value: "bra.camp.gaucho", label: "Brazilian Campeonato Gaucho" },
    { value: "bra.camp.mineiro", label: "Brazilian Campeonato Mineiro" },
    { value: "bra.camp.paulista", label: "Brazilian Campeonato Paulista" },
    { value: "concacaf.champions_cup", label: "CONCACAF Champions Cup" },
    { value: "concacaf.u23", label: "CONCACAF U23 Tournament" },
    { value: "fifa.conmebol.olympicsq", label: "CONMEBOL Pre-Olympic Tournament" },
    { value: "global.club_challenge", label: "CONMEBOL-UEFA Club Challenge" },
    { value: "global.finalissima", label: "CONMEBOL-UEFA Cup of Champions" },
    { value: "global.u20.intercontinental_cup", label: "CONMEBOL-UEFA U20 Intercontinental Cup" },
    { value: "global.w.finalissima", label: "CONMEBOL-UEFA Women's Cup of Champions" },
    { value: "caf.cosafa", label: "COSAFA Cup" },
    { value: "chi.1.promotion.relegation", label: "Chilean Primera División Promotion/Relegation Playoffs" },
    { value: "chi.super_cup", label: "Chilean Supercopa" },
    { value: "chn.1.promotion.relegation", label: "Chinese Super League Promotion/Relegation Playoffs" },
    { value: "col.superliga", label: "Colombian Superliga" },
    { value: "concacaf.central.american.cup", label: "Concacaf Central American Cup" },
    { value: "concacaf.confederations_playoff", label: "Concacaf Cup" },
    { value: "concacaf.gold_qual", label: "Concacaf Gold Cup Qualifying" },
    { value: "concacaf.womens.championship", label: "Concacaf W Championship" },
    { value: "fifa.w.concacaf.olympicsq", label: "Concacaf Women's Olympic Qualifying" },
    { value: "bol.copa", label: "Copa Bolivia" },
    { value: "chi.copa_chi", label: "Copa Chile" },
    { value: "ned.playoff.relegation", label: "Dutch Eredivisie Promotion/Relegation Playoffs" },
    { value: "ned.supercup", label: "Dutch Johan Cruyff Shield" },
    { value: "ned.w.knvb_cup", label: "Dutch KNVB Beker Vrouwen" },
    { value: "ned.3.promotion.relegation", label: "Dutch Tweede Divisie Promotion/Relegation Playoffs" },
    { value: "ned.w.1", label: "Dutch Vrouwen Eredivisie" },
    { value: "friendly.emirates_cup", label: "Emirates Cup" },
    { value: "eng.trophy", label: "English EFL Trophy" },
    { value: "eng.fa_qual", label: "English FA Cup Qualifying" },
    { value: "eng.w.fa", label: "English Women's FA Cup" },
    { value: "eng.w.league_cup", label: "English Women's League Cup" },
    { value: "eng.w.promotion.relegation", label: "English Women's Super League Promotion/Relegation Playoff" },
    { value: "fifa.intercontinental_cup", label: "FIFA Intercontinental Cup" },
    { value: "fifa.wworld.u17", label: "FIFA Under-17 Women's World Cup" },
    { value: "fifa.world.u17", label: "FIFA Under-17 World Cup" },
    { value: "fifa.world.u20", label: "FIFA Under-20 World Cup" },
    { value: "fifa.w.champions_cup", label: "FIFA Women's Champions Cup" },
    { value: "fifa.wwcq.ply", label: "FIFA Women's World Cup Qualifying - Playoff Tournament" },
    { value: "fifa.wworldq.uefa", label: "FIFA Women's World Cup Qualifying - UEFA" },
    { value: "fifa.worldq.afc", label: "FIFA World Cup Qualifying - AFC" },
    { value: "fifa.worldq.caf", label: "FIFA World Cup Qualifying - CAF" },
    { value: "fifa.worldq.conmebol", label: "FIFA World Cup Qualifying - CONMEBOL" },
    { value: "fifa.worldq.concacaf", label: "FIFA World Cup Qualifying - Concacaf" },
    { value: "fifa.worldq.ofc", label: "FIFA World Cup Qualifying - OFC" },
    { value: "fifa.wcq.ply", label: "FIFA World Cup Qualifying - Playoff Tournament" },
    { value: "fifa.worldq.uefa", label: "FIFA World Cup Qualifying - UEFA" },
    { value: "fra.1.promotion.relegation", label: "French Ligue 1 Promotion/Relegation Playoffs" },
    { value: "ger.2.promotion.relegation", label: "German Bundesliga 2. Promotion/Relegation Playoffs" },
    { value: "ger.playoff.relegation", label: "German Bundesliga Promotion/Relegation Playoff" },
    { value: "gua.1", label: "Guatemalan Liga Nacional" },
    { value: "hon.1", label: "Honduran Liga Nacional" },
    { value: "fifa.intercontinental.cup", label: "Intercontinental Cup (India)" },
    { value: "jpn.world_challenge", label: "Japanese J.League World Challenge" },
    { value: "fifa.concacaf.olympicsq", label: "Men's Olympic Qualifying Playoff" },
    { value: "mex.campeon", label: "Mexican Campeon de Campeones" },
    { value: "usa.ncaa.m.1", label: "NCAA Men's Soccer" },
    { value: "usa.ncaa.w.1", label: "NCAA Women's Soccer" },
    { value: "usa.nwsl.cup", label: "NWSL Challenge Cup" },
    { value: "can.w.nsl", label: "Northern Super League" },
    { value: "nor.1.promotion.relegation", label: "Norwegian Eliteserien Promotion/Relegation Playoffs" },
    { value: "par.1.supercopa", label: "Paraguayan Supercopa" },
    { value: "global.pinatar_cup", label: "Pinatar Cup" },
    { value: "por.1.promotion.relegation", label: "Portuguese Primeira Liga Promotion/Relegation Playoffs" },
    { value: "rus.1.promotion.relegation", label: "Russian Premier League Relegation/Promotion Playoffs" },
    { value: "afc.saff.championship", label: "SAFF Championship" },
    { value: "slv.1", label: "Salvadoran Primera Division" },
    { value: "sco.2.promotion.relegation", label: "Scottish Championship Promotion/Relegation Playoffs" },
    { value: "sco.tennents_qual", label: "Scottish Cup Qualifying" },
    { value: "sco.challenge", label: "Scottish League Challenge Cup" },
    { value: "sco.1.promotion.relegation", label: "Scottish Premiership Promotion/Relegation Playoffs" },
    { value: "fifa.shebelieves", label: "SheBelieves Cup" },
    { value: "esp.copa_de_la_reina", label: "Spanish Copa de la Reina" },
    { value: "swe.1.promotion.relegation", label: "Swedish Allsvenskan Promotion/Relegation Playoffs" },
    { value: "esp.joan_gamper", label: "Trofeo Joan Gamper" },
    { value: "uefa.champions_qual", label: "UEFA Champions League Qualifying" },
    { value: "uefa.europa.conf_qual", label: "UEFA Conference League Qualifying" },
    { value: "uefa.europa_qual", label: "UEFA Europa League Qualifying" },
    { value: "uefa.euroq", label: "UEFA European Championship Qualifying" },
    { value: "uefa.euro.u19", label: "UEFA European Under-19 Championship" },
    { value: "uefa.euro_u21", label: "UEFA European Under-21 Championship" },
    { value: "uefa.euro_u21_qual", label: "UEFA European Under-21 Championship Qualifying" },
    { value: "uefa.wchampions_qual", label: "UEFA Women's Champions League Qualifying" },
    { value: "uefa.w.europa", label: "UEFA Women's Europa Cup" },
    { value: "usa.usl.l1.cup", label: "USL Cup" },
    { value: "fifa.friendly_u21", label: "Under-21 International Friendly" },
    { value: "caf.w.nations", label: "Women's Africa Cup of Nations" }
  ];

  var leagueLogoMap = {
    "eng.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/23.png",
    "esp.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/15.png",
    "ita.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/12.png",
    "ger.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/10.png",
    "fra.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/9.png",
    "ned.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/11.png",
    "por.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/14.png",
    "ksa.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2488.png",
    "usa.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/19.png",
    "mex.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/22.png",
    "bra.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/85.png",
    "arg.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1.png",
    "sco.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/45.png",
    "bel.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/6.png",
    "tur.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/18.png",
    "aut.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/5.png",
    "gre.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/98.png",
    "den.1": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "swe.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/16.png",
    "nor.1": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "rus.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/106.png",
    "jpn.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2199.png",
    "chn.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2350.png",
    "ind.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2334.png",
    "aus.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1308.png",
    "col.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1543.png",
    "chi.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/86.png",
    "per.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1813.png",
    "ecu.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1944.png",
    "uru.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1592.png",
    "par.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1892.png",
    "bol.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1949.png",
    "ven.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/1947.png",
    "crc.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2245.png",
    "rsa.1": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "eng.2": "https://a.espncdn.com/i/leaguelogos/soccer/500/24.png",
    "eng.3": "https://a.espncdn.com/i/leaguelogos/soccer/500/25.png",
    "eng.4": "https://a.espncdn.com/i/leaguelogos/soccer/500/26.png",
    "eng.5": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "esp.2": "http://a.espncdn.com/i/leaguelogos/soccer/500/107.png",
    "ger.2": "https://a.espncdn.com/i/leaguelogos/soccer/500/97.png",
    "ita.2": "http://a.espncdn.com/i/leaguelogos/soccer/500/99.png",
    "fra.2": "http://a.espncdn.com/i/leaguelogos/soccer/500/96.png",
    "ned.2": "https://a.espncdn.com/i/leaguelogos/soccer/500/105.png",
    "sco.2": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "usa.usl.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2292.png",
    "usa.usl.l1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2452.png",
    "mex.2": "https://a.espncdn.com/i/leaguelogos/soccer/500/2306.png",
    "bra.2": "https://a.espncdn.com/i/leaguelogos/soccer/500/2299.png",
    "arg.2": "https://a.espncdn.com/i/leaguelogos/soccer/500/2294.png",
    "arg.3": "https://a.espncdn.com/i/leaguelogos/soccer/500/2308.png",
    "usa.nwsl": "https://a.espncdn.com/i/leaguelogos/soccer/500/2323.png",
    "eng.w.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2314.png",
    "esp.w.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/15.png",
    "fra.w.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/9.png",
    "aus.w.1": "http://a.espncdn.com/i/leaguelogos/soccer/500/2402.png",
    "uefa.wchampions": "https://a.espncdn.com/i/leaguelogos/soccer/500/2408.png",
    "concacaf.w.champions_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2298.png",
    "usa.w.usl.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2292.png",
    "uefa.champions": "https://a.espncdn.com/i/leaguelogos/soccer/500/2.png",
    "uefa.europa": "https://a.espncdn.com/i/leaguelogos/soccer/500/2310.png",
    "uefa.europa.conf": "https://a.espncdn.com/i/leaguelogos/soccer/500/20296.png",
    "uefa.super_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/1272.png",
    "conmebol.libertadores": "https://a.espncdn.com/i/leaguelogos/soccer/500/58.png",
    "conmebol.sudamericana": "https://a.espncdn.com/i/leaguelogos/soccer/500/1208.png",
    "conmebol.recopa": "https://a.espncdn.com/i/leaguelogos/soccer/500/2335.png",
    "concacaf.champions": "https://a.espncdn.com/i/leaguelogos/soccer/500/2298.png",
    "concacaf.leagues.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2410.png",
    "afc.champions": "https://a.espncdn.com/i/leaguelogos/soccer/500/2200.png",
    "afc.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2243.png",
    "caf.champions": "https://a.espncdn.com/i/leaguelogos/soccer/500/2391.png",
    "caf.confed": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "fifa.cwc": "https://a.espncdn.com/i/leaguelogos/soccer/500/1932.png",
    "campeones.cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "eng.fa": "https://a.espncdn.com/i/leaguelogos/soccer/500/40.png",
    "eng.league_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/41.png",
    "eng.charity": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "esp.copa_del_rey": "https://a.espncdn.com/i/leaguelogos/soccer/500/80.png",
    "esp.super_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/431.png",
    "ita.coppa_italia": "https://a.espncdn.com/i/leaguelogos/soccer/500/2192.png",
    "ita.super_cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "ger.dfb_pokal": "https://a.espncdn.com/i/leaguelogos/soccer/500/2061.png",
    "ger.super_cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "fra.coupe_de_france": "https://a.espncdn.com/i/leaguelogos/soccer/500/182.png",
    "fra.super_cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "usa.open": "https://a.espncdn.com/i/leaguelogos/soccer/500/69.png",
    "por.taca.portugal": "https://a.espncdn.com/i/leaguelogos/soccer/500/14.png",
    "ned.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2196.png",
    "sco.tennents": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "sco.cis": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "ksa.kings.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2488.png",
    "bra.copa_do_brazil": "https://a.espncdn.com/i/leaguelogos/soccer/500/528.png",
    "bra.supercopa_do_brazil": "https://a.espncdn.com/i/leaguelogos/soccer/500/85.png",
    "arg.copa": "https://a.espncdn.com/i/leaguelogos/soccer/500/2320.png",
    "arg.supercopa": "https://a.espncdn.com/i/leaguelogos/soccer/500/2343.png",
    "col.copa": "https://a.espncdn.com/i/leaguelogos/soccer/500/2332.png",
    "fifa.world": "https://a.espncdn.com/i/leaguelogos/soccer/500/4.png",
    "fifa.wwc": "https://a.espncdn.com/i/leaguelogos/soccer/500/60.png",
    "uefa.euro": "https://a.espncdn.com/i/leaguelogos/soccer/500/74.png",
    "uefa.weuro": "https://a.espncdn.com/i/leaguelogos/soccer/500/2381.png",
    "uefa.nations": "https://a.espncdn.com/i/leaguelogos/soccer/500/2395.png",
    "uefa.w.nations": "https://a.espncdn.com/i/leaguelogos/soccer/500/2395.png",
    "conmebol.america": "https://a.espncdn.com/i/leaguelogos/soccer/500/83.png",
    "conmebol.america.femenina": "https://a.espncdn.com/i/leaguelogos/soccer/500/83.png",
    "concacaf.gold": "https://a.espncdn.com/i/leaguelogos/soccer/500/59.png",
    "concacaf.w.gold": "https://a.espncdn.com/i/leaguelogos/soccer/500/59.png",
    "concacaf.nations.league": "https://a.espncdn.com/i/leaguelogos/soccer/500/2406.png",
    "caf.nations": "https://a.espncdn.com/i/leaguelogos/soccer/500/76.png",
    "afc.asian.cup": "https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/2243.png",
    "fifa.olympics": "https://a.espncdn.com/i/leaguelogos/soccer/500/71.png",
    "fifa.w.olympics": "https://a.espncdn.com/i/leaguelogos/soccer/500/84.png",
    "fifa.friendly": "https://a.espncdn.com/i/leaguelogos/soccer/500/53.png",
    "fifa.friendly.w": "https://a.espncdn.com/i/leaguelogos/soccer/500/70.png",
    "club.friendly": "https://a.espncdn.com/i/leaguelogos/soccer/500/53.png",
    "afc.cupq": "http://a.espncdn.com/i/leaguelogos/soccer/500/2246.png",
    "afc.champions_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/2200.png",
    "afc.cup_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/2243.png",
    "afc.w.asian.cup": "https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/2243.png",
    "aff.championship": "https://a.espncdn.com/i/leaguelogos/soccer/500/2261.png",
    "caf.nations_qual": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "caf.championship": "https://a.espncdn.com/i/leaguelogos/soccer/500/76.png",
    "global.gulf_cup": "https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/2243.png",
    "arg.copa_de_la_superliga": "https://a.espncdn.com/i/leaguelogos/soccer/500/2407.png",
    "arg.supercopa.internacional": "https://a.espncdn.com/i/leaguelogos/soccer/500/1.png",
    "arg.trofeo_de_la_campeones": "https://a.espncdn.com/i/leaguelogos/soccer/500/1.png",
    "global.arnold.clark_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2314.png",
    "bel.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/6.png",
    "bol.ply.rel": "https://a.espncdn.com/i/leaguelogos/soccer/500/1949.png",
    "bra.camp.carioca": "https://a.espncdn.com/i/leaguelogos/soccer/500/2265.png",
    "bra.camp.gaucho": "https://a.espncdn.com/i/leaguelogos/soccer/500/2272.png",
    "bra.camp.mineiro": "https://a.espncdn.com/i/leaguelogos/soccer/500/2360.png",
    "bra.camp.paulista": "https://a.espncdn.com/i/leaguelogos/soccer/500/2322.png",
    "concacaf.champions_cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "concacaf.u23": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "fifa.conmebol.olympicsq": "https://a.espncdn.com/i/leaguelogos/soccer/500/19727.png",
    "global.club_challenge": "https://a.espncdn.com/i/leaguelogos/soccer/500/2310.png",
    "global.finalissima": "https://a.espncdn.com/i/leaguelogos/soccer/500/74.png",
    "global.u20.intercontinental_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/58.png",
    "global.w.finalissima": "https://a.espncdn.com/i/leaguelogos/soccer/500/2381.png",
    "caf.cosafa": "https://a.espncdn.com/i/leaguelogos/soccer/500/76.png",
    "chi.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/86.png",
    "chi.super_cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "chn.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/2350.png",
    "col.superliga": "https://a.espncdn.com/i/leaguelogos/soccer/500-dark/2405.png",
    "concacaf.central.american.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2298.png",
    "concacaf.confederations_playoff": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "concacaf.gold_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/59.png",
    "concacaf.womens.championship": "https://a.espncdn.com/i/leaguelogos/soccer/500/18969.png",
    "fifa.w.concacaf.olympicsq": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "bol.copa": "https://a.espncdn.com/i/leaguelogos/soccer/500/1949.png",
    "chi.copa_chi": "http://a.espncdn.com/i/leaguelogos/soccer/500/2331.png",
    "ned.playoff.relegation": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "ned.supercup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "ned.w.knvb_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2196.png",
    "ned.3.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/11.png",
    "ned.w.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2453.png",
    "friendly.emirates_cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "eng.trophy": "https://a.espncdn.com/i/leaguelogos/soccer/500/42.png",
    "eng.fa_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/40.png",
    "eng.w.fa": "https://a.espncdn.com/i/leaguelogos/soccer/500/40.png",
    "eng.w.league_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/41.png",
    "eng.w.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/2314.png",
    "fifa.intercontinental_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/1932.png",
    "fifa.wworld.u17": "https://a.espncdn.com/i/leaguelogos/soccer/500/60.png",
    "fifa.world.u17": "https://a.espncdn.com/i/leaguelogos/soccer/500/2288.png",
    "fifa.world.u20": "https://a.espncdn.com/i/leaguelogos/soccer/500/2285.png",
    "fifa.w.champions_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/60.png",
    "fifa.wwcq.ply": "https://a.espncdn.com/i/leaguelogos/soccer/500/60.png",
    "fifa.wworldq.uefa": "https://a.espncdn.com/i/leaguelogos/soccer/500/60.png",
    "fifa.worldq.afc": "https://a.espncdn.com/i/leaguelogos/soccer/500/62.png",
    "fifa.worldq.caf": "https://a.espncdn.com/i/leaguelogos/soccer/500/63.png",
    "fifa.worldq.conmebol": "https://a.espncdn.com/i/leaguelogos/soccer/500/65.png",
    "fifa.worldq.concacaf": "https://a.espncdn.com/i/leaguelogos/soccer/500/64.png",
    "fifa.worldq.ofc": "https://a.espncdn.com/i/leaguelogos/soccer/500/66.png",
    "fifa.wcq.ply": "https://a.espncdn.com/i/leaguelogos/soccer/500/4.png",
    "fifa.worldq.uefa": "https://a.espncdn.com/i/leaguelogos/soccer/500/67.png",
    "fra.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/9.png",
    "ger.2.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/97.png",
    "ger.playoff.relegation": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "gua.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2248.png",
    "hon.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2247.png",
    "fifa.intercontinental.cup": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "jpn.world_challenge": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "fifa.concacaf.olympicsq": "https://a.espncdn.com/i/leaguelogos/soccer/500/71.png",
    "mex.campeon": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "usa.ncaa.m.1": "https://a.espncdn.com/combiner/i?img=/redesign/assets/img/icons/sports-soccer-solid.png",
    "usa.ncaa.w.1": "https://a.espncdn.com/combiner/i?img=/redesign/assets/img/icons/sports-soccer-solid.png",
    "usa.nwsl.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2445.png",
    "can.w.nsl": "https://a.espncdn.com/i/leaguelogos/soccer/500/2323.png",
    "nor.1.promotion.relegation": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "par.1.supercopa": "https://a.espncdn.com/i/leaguelogos/soccer/500/1892.png",
    "global.pinatar_cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/15.png",
    "por.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/14.png",
    "rus.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/106.png",
    "afc.saff.championship": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "slv.1": "https://a.espncdn.com/i/leaguelogos/soccer/500/2244.png",
    "sco.2.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/45.png",
    "sco.tennents_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/45.png",
    "sco.challenge": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "sco.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/45.png",
    "fifa.shebelieves": "https://a.espncdn.com/i/leaguelogos/soccer/500/60.png",
    "esp.copa_de_la_reina": "https://a.espncdn.com/i/leaguelogos/soccer/500/80.png",
    "swe.1.promotion.relegation": "https://a.espncdn.com/i/leaguelogos/soccer/500/16.png",
    "esp.joan_gamper": "https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/default-team-logo-500.png&w=100&h=100",
    "uefa.champions_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/2.png",
    "uefa.europa.conf_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/20296.png",
    "uefa.europa_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/2310.png",
    "uefa.euroq": "https://a.espncdn.com/i/leaguelogos/soccer/500/56.png",
    "uefa.euro.u19": "http://a.espncdn.com/i/leaguelogos/soccer/500/2297.png",
    "uefa.euro_u21": "http://a.espncdn.com/i/leaguelogos/soccer/500/2284.png",
    "uefa.euro_u21_qual": "http://a.espncdn.com/i/leaguelogos/soccer/500/2284.png",
    "uefa.wchampions_qual": "https://a.espncdn.com/i/leaguelogos/soccer/500/2408.png",
    "uefa.w.europa": "https://a.espncdn.com/i/leaguelogos/soccer/500/2310.png",
    "usa.usl.l1.cup": "https://a.espncdn.com/i/leaguelogos/soccer/500/2452.png",
    "fifa.friendly_u21": "https://a.espncdn.com/i/leaguelogos/soccer/500/53.png",
    "caf.w.nations": "https://a.espncdn.com/i/leaguelogos/soccer/500/76.png"
  };

  var leagueIdToSlugMap = {
    "2395": "uefa.nations",
    "3922": "fifa.friendly",
    "19834": "club.friendly",
    "20114": "uefa.euro_u21_qual",
    "8315": "caf.nations_qual",
    "8312": "chi.copa_chi",
    "650": "col.1",
    "3928": "gua.1",
    "3932": "mex.2",
    "19267": "concacaf.nations.league",
    "23107": "afc.asian.cup"
  };
  (function() {
    for (var slug in leagueLogoMap) {
      var match = String(leagueLogoMap[slug]).match(/\/(\d+)\.png$/);
      if (match && !leagueIdToSlugMap[match[1]]) {
        leagueIdToSlugMap[match[1]] = slug;
      }
    }
  })();

  function leagueSlugForId(id) {
    return leagueIdToSlugMap[String(id)] || "";
  }

  function leagueLabelForSlug(slug) {
    if (!slug) return "";
    for (var i = 0; i < leagues.length; i++) {
      if (leagues[i].value === slug) return leagues[i].label;
    }
    return slug;
  }

  function isInternationalCompetition(slug, leagueId) {
    var s = String(slug || "").toLowerCase();
    if (s.indexOf("club") !== -1) return false;
    if (s.indexOf("uefa.europa") !== -1 || s.indexOf("uefa.champions") !== -1 || s.indexOf("uefa.super_cup") !== -1) return false;
    var intlPrefixes = ["fifa.", "uefa.euro", "uefa.nations", "conmebol.america", "conmebol.copa_america", "concacaf.gold", "concacaf.nations", "caf.nations", "afc.asian", "fifa.friendly", "global.", "intl."];
    for (var i = 0; i < intlPrefixes.length; i++) {
      if (s.indexOf(intlPrefixes[i]) !== -1) return true;
    }
    var intlIds = ["2395", "3922", "8315", "20114", "19267", "23107"];
    return intlIds.indexOf(String(leagueId)) !== -1;
  }

  function isMajorLeagueCompetition(slug) {
    var s = String(slug || "").toLowerCase();
    var majorSlugs = [
      "eng.1", "esp.1", "ita.1", "ger.1", "fra.1",
      "eng.fa", "eng.league_cup", "esp.copa_del_rey", "ger.dfb_pokal", "ita.coppa_italia",
      "uefa.champions", "uefa.europa", "uefa.europa.conf", "uefa.super_cup",
      "conmebol.libertadores", "conmebol.sudamericana",
      "usa.1", "ksa.1", "bra.1", "ned.1", "por.1", "mex.1",
      "uefa.nations", "uefa.euro", "fifa.world", "fifa.cwc", "fifa.friendly"
    ];
    return majorSlugs.indexOf(s) !== -1;
  }

  function tournamentRoundName(ev) {
    if (!ev) return "";
    var comp = (ev.competitions && ev.competitions[0]) || {};
    var notes = Array.isArray(comp.notes) ? comp.notes : [];
    var season = ev.season || {};
    var series = comp.series || null;
    var noteTexts = [];
    for (var ni = 0; ni < notes.length; ni++) {
      if (notes[ni] && (notes[ni].headline || notes[ni].text)) {
        noteTexts.push(notes[ni].headline || notes[ni].text);
      }
    }
    var sTitle = series && series.title ? String(series.title) : (Array.isArray(series) && series[0] && series[0].title ? String(series[0].title) : "");
    var slug = String(season.slug || "").toLowerCase();
    var combo = (noteTexts.join(" ") + " " + sTitle + " " + String(ev.name || "") + " " + slug + " " + String(season.name || "")).toLowerCase();
    if (combo.indexOf("league phase") !== -1 || combo.indexOf("group stage") !== -1 || combo.indexOf("group phase") !== -1 || combo.indexOf("regular season") !== -1 || combo.indexOf("matchweek") !== -1 || combo.indexOf("gameweek") !== -1) {
      return "";
    }
    var earlyRounds = [
      ["preliminary", "preliminary", "Preliminary"],
      ["qualifying", "qualif", "Qualifying"],
      ["first-round", "first round", "First Round"],
      ["second-round", "second round", "Second Round"],
      ["third-round", "third round", "Third Round"],
      ["fourth-round", "fourth round", "Fourth Round"],
      ["fifth-round", "fifth round", "Fifth Round"],
      ["sixth-round", "sixth round", "Sixth Round"]
    ];
    for (var ei = 0; ei < earlyRounds.length; ei++) {
      if (slug.indexOf(earlyRounds[ei][0]) !== -1 || combo.indexOf(earlyRounds[ei][1]) !== -1) return earlyRounds[ei][2];
    }
    if (slug.indexOf("playoff") !== -1 || combo.indexOf("playoff") !== -1 || combo.indexOf("play-off") !== -1) return "Playoffs";
    var numberedRounds = [
      ["round-of-64", "round of 64", "r64", "Round of 64"],
      ["round-of-32", "round of 32", "r32", "Round of 32"],
      ["round-of-16", "round of 16", "r16", "Round of 16"],
      ["round-of-8", "round of 8", "r8", "Round of 8"],
      ["quarterfinal", "quarter", "", "Quarterfinals"],
      ["semifinal", "semi", "", "Semifinals"]
    ];
    for (var ni2 = 0; ni2 < numberedRounds.length; ni2++) {
      if (slug.indexOf(numberedRounds[ni2][0]) !== -1 || combo.indexOf(numberedRounds[ni2][1]) !== -1 ||
          (numberedRounds[ni2][2] !== "" && combo.indexOf(numberedRounds[ni2][2]) !== -1)) return numberedRounds[ni2][3];
    }
    if (combo.indexOf("third place") !== -1 || combo.indexOf("3rd place") !== -1) return "Third Place";
    if (combo.indexOf("final") !== -1) return "Final";
    return "";
  }

  function extractAdvancingTeamFromNote(noteText, teamA, teamB) {
    if (!noteText) return "";
    var n = String(noteText).toLowerCase();
    var a = String(teamA || "").toLowerCase();
    var b = String(teamB || "").toLowerCase();
    if (!a && !b) return "";

    var kwRegex = /\b(advances?|advanced|winning|wins?|won|qualifies|qualified)\b/i;

    function testTeam(tm) {
      if (!tm) return false;
      var esc = tm.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      if (new RegExp(esc + "\\s*(?:[a-z0-9]+\\s+){0,3}(?:advances?|advanced|wins?|won|qualifies|qualified)\\b", "i").test(n)) return true;
      var shortTm = tm.replace(/\s+(fc|cf|sc)\b/i, "").trim();
      if (shortTm && shortTm !== tm) {
        var escS = shortTm.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        if (new RegExp(escS + "\\s*(?:[a-z0-9]+\\s+){0,3}(?:advances?|advanced|wins?|won|qualifies|qualified)\\b", "i").test(n)) return true;
      }
      return false;
    }

    var matchA = testTeam(a);
    var matchB = testTeam(b);

    if (matchA && !matchB) return teamA;
    if (matchB && !matchA) return teamB;

    var kwMatch = kwRegex.exec(n);
    if (kwMatch) {
      var kwIdx = kwMatch.index;
      var before = n.substring(0, kwIdx);
      var posA = a ? before.lastIndexOf(a) : -1;
      var posB = b ? before.lastIndexOf(b) : -1;
      if (posA === -1 && a) {
        var shortA = a.replace(/\s+(fc|cf|sc)\b/i, "").trim();
        if (shortA) posA = before.lastIndexOf(shortA);
      }
      if (posB === -1 && b) {
        var shortB = b.replace(/\s+(fc|cf|sc)\b/i, "").trim();
        if (shortB) posB = before.lastIndexOf(shortB);
      }
      if (posA !== -1 && posB === -1) return teamA;
      if (posB !== -1 && posA === -1) return teamB;
      if (posA !== -1 && posB !== -1) {
        return posA > posB ? teamA : teamB;
      }
    }

    return "";
  }

  function extractSeriesOutcome(comp, homeTeam, awayTeam, seriesRes) {
    if (!comp) return "";

    // 1. Check comp.notes for explicit outcome text (e.g. "2nd Leg - Bayern Munich advance 3-2 on aggregate")
    if (Array.isArray(comp.notes)) {
      for (var ni = 0; ni < comp.notes.length; ni++) {
        var nItem = comp.notes[ni];
        var text = String((nItem && (nItem.headline || nItem.text)) || "").trim();
        var lower = text.toLowerCase();
        if (lower.indexOf("advance") !== -1 || lower.indexOf("aggregate") !== -1 ||
            lower.indexOf("penalt") !== -1 || lower.indexOf("won") !== -1 || lower.indexOf("win") !== -1) {
          var cleanOutcome = text.replace(/^(?:1st|2nd|first|second)\s+leg\s*[-–:]\s*/i, "").trim();
          if (cleanOutcome.length > 0) return cleanOutcome;
        }
      }
    }

    // 2. Check comp.series summary if it contains outcome words (not stage names)
    var sObj = Array.isArray(comp.series) ? (comp.series.length > 0 ? comp.series[0] : null) : comp.series;
    if (sObj && sObj.summary) {
      var sumText = String(sObj.summary).trim();
      var sumLower = sumText.toLowerCase();
      if (sumLower.indexOf("advance") !== -1 || sumLower.indexOf("aggregate") !== -1 ||
          sumLower.indexOf("win") !== -1 || sumLower.indexOf("won") !== -1) {
        return sumText;
      }
    }

    // 3. From seriesRes if available (from resolveMatchSeries)
    if (seriesRes && seriesRes.hasTwoLegs && seriesRes.isSeriesCompleted && seriesRes.curSeriesWinner) {
      var wName = seriesRes.curSeriesWinner;
      var hAgg = seriesRes.curAggHome;
      var aAgg = seriesRes.curAggAway;
      var hName = (homeTeam && (homeTeam.displayName || homeTeam.name)) || "";
      var isHomeWinner = (hName !== "" && wName.indexOf(hName) !== -1);
      var wAgg = isHomeWinner ? hAgg : aAgg;
      var lAgg = isHomeWinner ? aAgg : hAgg;
      if (wAgg !== "" && lAgg !== "") {
        if (wAgg === lAgg) {
          return wName + " advance on aggregate (agg " + wAgg + "–" + lAgg + ")";
        }
        return wName + " advance " + wAgg + "–" + lAgg + " on aggregate";
      }
    }

    // 4. From sObj.competitors directly if completed
    if (sObj && Array.isArray(sObj.competitors) && sObj.completed) {
      var winName = "";
      var winAgg = null;
      var losAgg = null;
      for (var ci = 0; ci < sObj.competitors.length; ci++) {
        var compItem = sObj.competitors[ci];
        var isHome = homeTeam && homeTeam.id && String(compItem.id) === String(homeTeam.id);
        var tName = isHome ? (homeTeam.displayName || homeTeam.name) : (awayTeam ? (awayTeam.displayName || awayTeam.name) : "");
        if (compItem.winner === true) {
          winName = tName;
          winAgg = compItem.aggregateScore;
        } else {
          losAgg = compItem.aggregateScore;
        }
      }
      if (winName !== "" && winAgg !== null && losAgg !== null && winAgg !== undefined && losAgg !== undefined) {
        if (winAgg === losAgg) {
          return winName + " advance on aggregate (agg " + winAgg + "–" + losAgg + ")";
        }
        return winName + " advance " + winAgg + "–" + losAgg + " on aggregate";
      }
    }

    return "";
  }

  function collectTournamentBracketRounds(events, acc) {
    if (!acc || !Array.isArray(events)) return;
    for (var ei = 0; ei < events.length; ei++) {
      var ev = events[ei];
      if (!ev) continue;
      var eventSeasonYear = Number(ev.season && ev.season.year);
      if (eventSeasonYear && eventSeasonYear !== acc.seasonYear) continue;
      var comp = (ev.competitions && ev.competitions[0]) || {};
      var notes = Array.isArray(comp.notes) ? comp.notes : [];
      var noteTexts = [];
      for (var ni = 0; ni < notes.length; ni++) {
        if (notes[ni] && (notes[ni].headline || notes[ni].text)) {
          noteTexts.push(notes[ni].headline || notes[ni].text);
        }
      }
      var rName = tournamentRoundName(ev);
      if (!rName) continue;
      if (!acc.map[rName]) acc.map[rName] = [];

      var comps = Array.isArray(comp.competitors) ? comp.competitors : [];
      if (comps.length < 2) continue;
      var h = comps[0].homeAway === "home" ? comps[0] : comps[1];
      var a = comps[0].homeAway === "home" ? comps[1] : comps[0];

      var hTeam = h.team || {};
      var aTeam = a.team || {};
      var hName = String(hTeam.shortDisplayName || hTeam.displayName || "Home");
      var aName = String(aTeam.shortDisplayName || aTeam.displayName || "Away");
      var hId = String(hTeam.id || h.id || "");
      var aId = String(aTeam.id || a.id || "");
      var hLogo = hId !== "" ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + hId + ".png") : String(hTeam.logo || (hTeam.logos && hTeam.logos[0] ? hTeam.logos[0].href : ""));
      var aLogo = aId !== "" ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + aId + ".png") : String(aTeam.logo || (aTeam.logos && aTeam.logos[0] ? aTeam.logos[0].href : ""));

      var nameKey = [hName, aName].sort().join("|") + "|" + rName;
      var idKey = (hId !== "" && aId !== "") ? ([hId, aId].sort().join("-") + "|" + rName) : nameKey;
      var noteLower = noteTexts.join(" ").toLowerCase();
      var seriesObj = comp.series ? (Array.isArray(comp.series) && comp.series.length > 0 ? comp.series[0] : comp.series) : null;
      var sCompetitors = seriesObj && Array.isArray(seriesObj.competitors) ? seriesObj.competitors : [];

      var isLeg2 = (seriesObj && seriesObj.leg === 2) || noteLower.indexOf("2nd leg") !== -1 || noteLower.indexOf("leg 2") !== -1 || noteLower.indexOf("second leg") !== -1 || noteLower.indexOf("advance") !== -1;
      var isLeg1 = (seriesObj && seriesObj.leg === 1) || noteLower.indexOf("1st leg") !== -1 || noteLower.indexOf("leg 1") !== -1 || noteLower.indexOf("first leg") !== -1;
      var hScore = String(h.score !== undefined ? h.score : "");
      var aScore = String(a.score !== undefined ? a.score : "");
      var hAgg = h.aggregateScore !== undefined ? String(h.aggregateScore) : "";
      var aAgg = a.aggregateScore !== undefined ? String(a.aggregateScore) : "";

      var s = acc.seenSeries[idKey] || acc.seenSeries[nameKey];
      if (!s) {
        s = {
          roundName: rName,
          teamA: hName, idA: hId, logoA: hLogo, leg1_A: "", leg2_A: "", agg_A: "",
          teamB: aName, idB: aId, logoB: aLogo, leg1_B: "", leg2_B: "", agg_B: "",
          statusText: noteTexts.length > 0 ? noteTexts[0] : "Completed",
          completed: comp.status && comp.status.type ? comp.status.type.completed === true : true,
          seriesCompetitors: [],
          notes: noteTexts,
          isLeg2Found: false,
          isLeg1Found: false,
          matchWinner: ""
        };
        acc.seenSeries[idKey] = s;
        acc.seenSeries[nameKey] = s;
        acc.map[rName].push(s);
      }

      if (sCompetitors.length > 0) s.seriesCompetitors = sCompetitors;
      if (noteTexts.length > 0) {
        s.notes = noteTexts;
        s.statusText = noteTexts[0];
      }
      var isCompCompleted = comp.status && comp.status.type ? comp.status.type.completed === true : true;
      var isHomeTeamA = (hId !== "" && s.idA !== "" && hId === s.idA) || (hName === s.teamA);

      if (isLeg1) {
        s.isLeg1Found = true;
        if (isHomeTeamA) {
          s.leg1_A = hScore;
          s.leg1_B = aScore;
        } else {
          s.leg1_B = hScore;
          s.leg1_A = aScore;
        }
      } else if (isLeg2) {
        s.isLeg2Found = true;
        s.completed = isCompCompleted;
        if (isHomeTeamA) {
          s.leg2_A = hScore;
          s.leg2_B = aScore;
          if (hAgg !== "") s.agg_A = hAgg;
          if (aAgg !== "") s.agg_B = aAgg;
        } else {
          s.leg2_B = hScore;
          s.leg2_A = aScore;
          if (hAgg !== "") s.agg_B = hAgg;
          if (aAgg !== "") s.agg_A = aAgg;
        }
      } else {
        s.completed = isCompCompleted;
        if (isHomeTeamA) {
          s.leg1_A = hScore;
          s.leg1_B = aScore;
          if (hAgg !== "") s.agg_A = hAgg;
          if (aAgg !== "") s.agg_B = aAgg;
          if (h.winner) s.matchWinner = s.teamA;
          else if (a.winner) s.matchWinner = s.teamB;
        } else {
          s.leg1_B = hScore;
          s.leg1_A = aScore;
          if (hAgg !== "") s.agg_B = hAgg;
          if (aAgg !== "") s.agg_A = aAgg;
          if (h.winner) s.matchWinner = s.teamB;
          else if (a.winner) s.matchWinner = s.teamA;
        }
      }
    }
  }

  function finishTournamentBracketRequest(acc, sanitizePlainText, sanitizeImageUrl) {
    if (!acc) return [];
    var cleanText = sanitizePlainText || function(s) { return s ? String(s) : ""; };
    var cleanUrl = sanitizeImageUrl || function(u) { return u ? String(u) : ""; };
    var roundsMap = acc.map || {};
    var orderedNames = [
      "Qualifying", "Preliminary", "Playoffs", "First Round", "Second Round", "Third Round",
      "Fourth Round", "Fifth Round", "Sixth Round", "Round of 64", "Round of 32", "Round of 16",
      "Round of 8", "Quarterfinals", "Semifinals", "Third Place", "Final"
    ];
    var knownRound = {};
    for (var ri = 0; ri < orderedNames.length; ri++) knownRound[orderedNames[ri]] = true;
    for (var rk in roundsMap) {
      if (!knownRound[rk] && roundsMap[rk] && roundsMap[rk].length > 0) orderedNames.push(rk);
    }

    var builtBracket = [];
    for (var oi = 0; oi < orderedNames.length; oi++) {
      var on = orderedNames[oi];
      if (roundsMap[on] && roundsMap[on].length > 0) {
        var roundMatchups = [];
        var seriesList = roundsMap[on];
        for (var si = 0; si < seriesList.length; si++) {
          var sObj = seriesList[si];
          var has2Legs = sObj.isLeg2Found || (sObj.leg1_A !== "" && sObj.leg2_A !== "");

          var numAggA = null;
          var numAggB = null;
          if (sObj.agg_A !== "") {
            var vA = parseFloat(sObj.agg_A);
            if (!isNaN(vA)) numAggA = vA;
          }
          if (numAggA === null) {
            if (has2Legs && sObj.leg1_A !== "" && sObj.leg2_A !== "") {
              var v1A = parseFloat(sObj.leg1_A), v2A = parseFloat(sObj.leg2_A);
              if (!isNaN(v1A) && !isNaN(v2A)) numAggA = v1A + v2A;
            } else if (!has2Legs && sObj.leg1_A !== "") {
              var v1A = parseFloat(sObj.leg1_A);
              if (!isNaN(v1A)) numAggA = v1A;
            }
          }

          if (sObj.agg_B !== "") {
            var vB = parseFloat(sObj.agg_B);
            if (!isNaN(vB)) numAggB = vB;
          }
          if (numAggB === null) {
            if (has2Legs && sObj.leg1_B !== "" && sObj.leg2_B !== "") {
              var v1B = parseFloat(sObj.leg1_B), v2B = parseFloat(sObj.leg2_B);
              if (!isNaN(v1B) && !isNaN(v2B)) numAggB = v1B + v2B;
            } else if (!has2Legs && sObj.leg1_B !== "") {
              var v1B = parseFloat(sObj.leg1_B);
              if (!isNaN(v1B)) numAggB = v1B;
            }
          }

          var isFinished = has2Legs ? (sObj.isLeg2Found && sObj.completed) : (sObj.completed && (sObj.leg1_A !== "" || sObj.leg1_B !== ""));
          var wName = "";

          if (isFinished) {
            // 1. Series winner from ESPN series competitors
            var sComps = sObj.seriesCompetitors || [];
            for (var sci = 0; sci < sComps.length; sci++) {
              if (sComps[sci] && sComps[sci].winner === true) {
                var wId = String(sComps[sci].id || "");
                if (wId === String(sObj.idA)) wName = sObj.teamA;
                else if (wId === String(sObj.idB)) wName = sObj.teamB;
                break;
              }
            }

            // 2. Winner from aggregate score difference
            if (wName === "" && numAggA !== null && numAggB !== null) {
              if (numAggA > numAggB) wName = sObj.teamA;
              else if (numAggB > numAggA) wName = sObj.teamB;
            }

            // 3. Tied on aggregate or shootout notes
            if (wName === "") {
              var noteCombined = (sObj.notes ? sObj.notes.join(" ") : "") + " " + String(sObj.statusText || "");
              wName = extractAdvancingTeamFromNote(noteCombined, sObj.teamA, sObj.teamB);
            }

            // 4. Single-leg tie fallback to match winner
            if (wName === "" && !has2Legs && sObj.matchWinner) {
              wName = sObj.matchWinner;
            }
          }

          var dispAggA = sObj.agg_A !== "" ? String(sObj.agg_A) : (numAggA !== null ? String(numAggA) : (has2Legs ? "" : (sObj.leg1_A !== undefined && sObj.leg1_A !== null ? String(sObj.leg1_A) : "")));
          var dispAggB = sObj.agg_B !== "" ? String(sObj.agg_B) : (numAggB !== null ? String(numAggB) : (has2Legs ? "" : (sObj.leg1_B !== undefined && sObj.leg1_B !== null ? String(sObj.leg1_B) : "")));
          dispAggA = dispAggA.replace(/\.0$/, "");
          dispAggB = dispAggB.replace(/\.0$/, "");

          roundMatchups.push({
            homeName: cleanText(sObj.teamA),
            homeId: sObj.idA,
            homeLogo: cleanUrl(sObj.logoA),
            homeLeg1: cleanText(sObj.leg1_A),
            homeLeg2: cleanText(sObj.leg2_A),
            homeAgg: cleanText(dispAggA),
            awayName: cleanText(sObj.teamB),
            awayId: sObj.idB,
            awayLogo: cleanUrl(sObj.logoB),
            awayLeg1: cleanText(sObj.leg1_B),
            awayLeg2: cleanText(sObj.leg2_B),
            awayAgg: cleanText(dispAggB),
            isCurrent: false,
            statusText: cleanText(sObj.statusText),
            completed: isFinished,
            winner: wName,
            hasTwoLegs: has2Legs
          });
        }

        builtBracket.push({
          roundName: on,
          roundIndex: builtBracket.length,
          isCurrentRound: false,
          matchups: roundMatchups
        });
      }
    }
    return builtBracket;
  }

  function resolveMatchSeries(comp, homeTeam, awayTeam, curHomeScore, curAwayScore, statusDesc, stageCombined, seriesNote) {
    var stage = String(stageCombined || "").toLowerCase();
    var desc = String(statusDesc || "").toLowerCase();
    var curAggHome = curHomeScore;
    var curAggAway = curAwayScore;
    var curSeriesWinner = "";
    var curSeriesSummary = seriesNote || "";

    var hasTwoLegs = false;
    var isLeg2Comp = false;

    var sObj = null;
    if (comp && comp.series) {
      sObj = Array.isArray(comp.series) ? (comp.series.length > 0 ? comp.series[0] : null) : comp.series;
    }

    if (sObj && (sObj.totalCompetitions === 2 || sObj.leg !== undefined)) {
      hasTwoLegs = true;
      isLeg2Comp = (sObj.leg === 2) || (stage.indexOf("2nd leg") !== -1) || (stage.indexOf("advance") !== -1);
    } else if (stage.indexOf("leg") !== -1) {
      hasTwoLegs = true;
      isLeg2Comp = (stage.indexOf("2nd leg") !== -1) || (stage.indexOf("advance") !== -1);
    }

    if (sObj && Array.isArray(sObj.competitors)) {
      for (var sci = 0; sci < sObj.competitors.length; sci++) {
        var scEntry = sObj.competitors[sci];
        if (!scEntry) continue;
        var scId = String(scEntry.id || "");
        if (homeTeam && homeTeam.id && scId === String(homeTeam.id)) {
          if (scEntry.aggregateScore !== undefined) curAggHome = String(scEntry.aggregateScore);
          if (scEntry.winner === true) curSeriesWinner = homeTeam.displayName || homeTeam.name || "";
        } else if (awayTeam && awayTeam.id && scId === String(awayTeam.id)) {
          if (scEntry.aggregateScore !== undefined) curAggAway = String(scEntry.aggregateScore);
          if (scEntry.winner === true) curSeriesWinner = awayTeam.displayName || awayTeam.name || "";
        }
      }
    }

    var isSeriesCompleted = (desc.indexOf("final") !== -1 || (sObj && sObj.completed === true));
    if (hasTwoLegs && !isLeg2Comp) {
      isSeriesCompleted = false;
      curSeriesWinner = "";
    } else if (!isSeriesCompleted) {
      curSeriesWinner = "";
    } else if (isSeriesCompleted && curSeriesWinner === "") {
      var hN = parseFloat(curAggHome);
      var aN = parseFloat(curAggAway);
      if (!isNaN(hN) && !isNaN(aN)) {
        if (hN > aN) curSeriesWinner = (homeTeam && (homeTeam.displayName || homeTeam.name)) || "";
        else if (aN > hN) curSeriesWinner = (awayTeam && (awayTeam.displayName || awayTeam.name)) || "";
      }
      if (curSeriesWinner === "") {
        var sNote = curSeriesSummary || seriesNote || "";
        var hName = (homeTeam && (homeTeam.displayName || homeTeam.name)) || "";
        var aName = (awayTeam && (awayTeam.displayName || awayTeam.name)) || "";
        curSeriesWinner = extractAdvancingTeamFromNote(sNote, hName, aName);
      }
    }

    var curHomeLeg1 = "";
    var curHomeLeg2 = "";
    var curAwayLeg1 = "";
    var curAwayLeg2 = "";
    if (hasTwoLegs) {
      if (isLeg2Comp) {
        curHomeLeg2 = curHomeScore;
        curAwayLeg2 = curAwayScore;
        var hA = parseFloat(curAggHome);
        var hS = parseFloat(curHomeScore);
        var aA = parseFloat(curAggAway);
        var aS = parseFloat(curAwayScore);
        curHomeLeg1 = (!isNaN(hA) && !isNaN(hS)) ? String(hA - hS) : "";
        curAwayLeg1 = (!isNaN(aA) && !isNaN(aS)) ? String(aA - aS) : "";
      } else {
        curHomeLeg1 = curHomeScore;
        curAwayLeg1 = curAwayScore;
        curHomeLeg2 = "—";
        curAwayLeg2 = "—";
      }
    }

    if (isSeriesCompleted && (!curSeriesSummary || curSeriesSummary.toLowerCase().indexOf("advance") === -1)) {
      var extOutcome = extractSeriesOutcome(comp, homeTeam, awayTeam, {
        hasTwoLegs: hasTwoLegs,
        isSeriesCompleted: isSeriesCompleted,
        curSeriesWinner: curSeriesWinner,
        curAggHome: curAggHome,
        curAggAway: curAggAway
      });
      if (extOutcome !== "") curSeriesSummary = extOutcome;
    }

    return {
      hasTwoLegs: hasTwoLegs,
      isLeg2Comp: isLeg2Comp,
      isSeriesCompleted: isSeriesCompleted,
      curSeriesWinner: curSeriesWinner,
      curAggHome: curAggHome,
      curAggAway: curAggAway,
      curHomeLeg1: curHomeLeg1,
      curHomeLeg2: curHomeLeg2,
      curAwayLeg1: curAwayLeg1,
      curAwayLeg2: curAwayLeg2,
      curSeriesSummary: curSeriesSummary
    };
  }
  function formatCompetitionName(lg) {
    if (!lg || typeof lg !== "string") return { full: "Competition", short: "Comp" };
    var l = lg.toLowerCase();
    if (l === "esp.1") return { full: "LaLiga", short: "LaLiga" };
    if (l === "esp.2") return { full: "LaLiga 2", short: "Segunda" };
    if (l === "esp.copa_del_rey") return { full: "Copa del Rey", short: "Copa" };
    if (l === "esp.super_cup") return { full: "Supercopa", short: "Supercopa" };
    if (l === "esp.joan_gamper") return { full: "Joan Gamper", short: "Gamper" };
    if (l === "eng.1") return { full: "Premier League", short: "PL" };
    if (l === "eng.2") return { full: "Championship", short: "Championship" };
    if (l === "eng.fa") return { full: "FA Cup", short: "FA Cup" };
    if (l === "eng.league_cup") return { full: "Carabao Cup", short: "EFL Cup" };
    if (l === "eng.charity") return { full: "Community Shield", short: "Shield" };
    if (l === "ger.1") return { full: "Bundesliga", short: "Bundesliga" };
    if (l === "ger.dfb_pokal") return { full: "DFB-Pokal", short: "DFB-Pokal" };
    if (l === "ger.super_cup") return { full: "DFL-Supercup", short: "Supercup" };
    if (l === "ita.1") return { full: "Serie A", short: "Serie A" };
    if (l === "ita.coppa_italia") return { full: "Coppa Italia", short: "Coppa" };
    if (l === "ita.super_cup") return { full: "Supercoppa", short: "Supercoppa" };
    if (l === "fra.1") return { full: "Ligue 1", short: "Ligue 1" };
    if (l === "fra.coupe_de_france") return { full: "Coupe de France", short: "Coupe" };
    if (l === "fra.trophee_champions") return { full: "Trophée des Champions", short: "Trophée" };
    if (l === "uefa.champions") return { full: "Champions League", short: "UCL" };
    if (l === "uefa.europa") return { full: "Europa League", short: "UEL" };
    if (l === "uefa.europa.conf") return { full: "Conference League", short: "UECL" };
    if (l === "uefa.super_cup") return { full: "UEFA Super Cup", short: "Super Cup" };
    if (l === "usa.1") return { full: "MLS", short: "MLS" };
    if (l === "usa.us_open") return { full: "US Open Cup", short: "US Open" };
    if (l === "por.1") return { full: "Liga Portugal", short: "Liga PT" };
    if (l === "ned.1") return { full: "Eredivisie", short: "Eredivisie" };
    if (l === "sau.1") return { full: "Saudi Pro League", short: "SPL" };
    if (l === "bra.1") return { full: "Brasileirão", short: "Brasileirão" };
    if (l === "uefa.euro") return { full: "Euro", short: "Euro" };
    if (l === "uefa.euroq") return { full: "Euro Qualifiers", short: "Euro Q" };
    if (l === "fifa.world") return { full: "World Cup", short: "World Cup" };
    if (l === "fifa.worldq.uefa" || l.indexOf("fifa.worldq") === 0) return { full: "World Cup Qualifiers", short: "WC Q" };
    if (l === "uefa.nations") return { full: "Nations League", short: "Nations" };
    if (l === "fifa.friendly") return { full: "Friendly", short: "Friendly" };
    if (l === "conmebol.america" || l === "conmebol.copa_america") return { full: "Copa América", short: "Copa América" };
    if (l === "fifa.cwc") return { full: "Club World Cup", short: "CWC" };
    var pretty = l.replace(/^[a-z0-9_]+\./, "").replace(/_/g, " ");
    pretty = pretty.charAt(0).toUpperCase() + pretty.slice(1);
    return { full: pretty, short: pretty.slice(0, 10) };
  }

  var statGroupDefs = {
    scoring: [
      ["Free-kick goals", ["freeKickGoals"]], ["Penalty goals", ["penaltyKickGoals"]],
      ["Penalties missed", ["penaltyKicksMissed"]], ["Game-winning goals", ["gameWinningGoals"]],
      ["Headed goals", ["headedGoals"]], ["Left-foot shots", ["leftFootedShots"]],
      ["Right-foot shots", ["rightFootedShots"]], ["Shots", ["totalShots"]],
      ["Shots on target", ["shotsOnTarget"]], ["Shot %", ["shotPct"]],
      ["In-box attempts", ["attemptsInBox"]], ["Out-box attempts", ["attemptsOutBox"]],
      ["Offsides", ["offsides"]], ["Big chances missed", ["bigChanceMissed"]],
      ["Shootout goals", ["shootOutGoals"]], ["Shootout misses", ["shootOutMisses"]]
    ],
    passing: [
      ["Accurate passes", ["accuratePasses"]], ["Total passes", ["totalPasses"]],
      ["Accurate crosses", ["accurateCrosses"]], ["Accurate long balls", ["accurateLongBalls"]],
      ["Accurate through balls", ["accurateThroughBalls"]], ["Cross %", ["crossPct"]],
      ["Long-ball %", ["longballPct"]], ["Through-ball %", ["throughBallPct"]],
      ["Key passes", ["shotAssists"]], ["Big chances created", ["bigChanceCreated"]],
      ["Second assists", ["secondAssists"]], ["Game-winning assists", ["gameWinningAssists"]]
    ],
    defending: [
      ["Tackles", ["effectiveTackles", "totalTackles"]], ["Tackle %", ["tacklePct"]],
      ["Interceptions", ["interceptions"]], ["Clearances", ["totalClearance", "effectiveClearance"]],
      ["Blocked shots", ["blockedShots"]], ["Recoveries", ["recoveries"]],
      ["Duels won", ["duelsWon"]], ["Duels lost", ["duelsLost"]],
      ["Tackles lost", ["tacklesLost"]], ["Fouls committed", ["foulsCommitted"]],
      ["Fouls suffered", ["foulsSuffered"]]
    ],
    keeper: [
      ["Saves", ["saves"]], ["Shots faced", ["shotsFaced"]], ["Goals conceded", ["goalsConceded"]],
      ["Clean sheets", ["cleanSheet"]], ["Penalty saves", ["penaltyKicksSaved"]],
      ["Penalties faced", ["penaltyKicksFaced"]], ["Crosses caught", ["crossesCaught"]],
      ["Punches", ["punches"]], ["Big-chance saves", ["bigChanceSaves"]],
      ["Shootout saves", ["shootOutKicksSaved"]]
    ],
    general: [
      ["Minutes", ["minutes"]], ["Starts", ["starts"]], ["Sub ins", ["subIns"]],
      ["Sub outs", ["subOuts"]], ["Wins", ["wins"]], ["Draws", ["draws"]],
      ["Losses", ["losses"]], ["Yellow cards", ["yellowCards"]], ["Red cards", ["redCards"]],
      ["Touches", ["touches"]], ["Touches in opp box", ["touchesInOppBox"]],
      ["Progressive carries", ["progressiveCarries"]], ["Own goals", ["ownGoals"]]
    ]
  };
  var clubAggPyScript = "import sys, json, urllib.request, concurrent.futures\nurls = json.loads(sys.argv[1])\nsums = {}\ncached_map = {}\ndef fetch(u):\n    try:\n        req = urllib.request.Request(u, headers={'User-Agent': 'curl/7.88.1', 'Accept': '*/*'})\n        with urllib.request.urlopen(req, timeout=8) as r:\n            return u, json.loads(r.read())\n    except Exception:\n        return u, None\nwith concurrent.futures.ThreadPoolExecutor(max_workers=10) as ex:\n    for u, data in ex.map(fetch, urls):\n        u_stats = {}\n        if data:\n            for c in data.get('splits', {}).get('categories', []):\n                for s in c.get('stats', []):\n                    nm = s.get('name')\n                    val = s.get('displayValue') if s.get('displayValue') is not None else s.get('value')\n                    try: raw = float(str(val).replace(',', ''))\n                    except: continue\n                    u_stats[nm] = str(val)\n                    if not any(x in nm.lower() for x in ['avg', 'time', 'pct']):\n                        sums[nm] = sums.get(nm, 0) + raw\n        cached_map[u] = u_stats\nout = {k: str(round(v)) for k, v in sums.items()}\nif sums.get('totalPasses', 0) > 0 and 'accuratePasses' in sums:\n    out['passPct'] = str(round(sums['accuratePasses'] / sums['totalPasses'] * 100)) + '%'\nprint(json.dumps({'stats': out, 'cached': {k: v for k, v in cached_map.items() if v}}))\n";

  var careerAggPyScript = "import sys, json, urllib.request, concurrent.futures\nurls = json.loads(sys.argv[1])\nsums = {}\ndef fetch(u):\n    try:\n        req = urllib.request.Request(u, headers={'User-Agent': 'curl/7.88.1', 'Accept': '*/*'})\n        with urllib.request.urlopen(req, timeout=8) as r:\n            return json.loads(r.read())\n    except Exception:\n        return None\nwith concurrent.futures.ThreadPoolExecutor(max_workers=10) as ex:\n    for data in ex.map(fetch, urls):\n        if data:\n            for c in data.get('splits', {}).get('categories', []):\n                for s in c.get('stats', []):\n                    nm = s.get('name')\n                    if nm in ['goalAssists', 'appearances', 'totalGoals']:\n                        val = s.get('displayValue') if s.get('displayValue') is not None else s.get('value')\n                        try: raw = float(str(val).replace(',', ''))\n                        except: continue\n                        sums[nm] = sums.get(nm, 0) + raw\nprint(json.dumps(sums))\n";


  var leagueShortMap = {
    "uefa.champions": "UCL",
    "uefa.europa": "UEL",
    "uefa.europa.conference": "UECL",
    "uefa.super": "Super Cup",
    "uefa.nations": "Nations League",
    "fifa.world": "World Cup",
    "fifa.cwc": "Club World Cup",
    "conmebol.libertadores": "Libertadores",
    "conmebol.sudamericana": "Sudamericana",
    "concacaf.champions": "Champions Cup",
    "eng.1": "Premier League",
    "esp.1": "LaLiga",
    "ita.1": "Serie A",
    "ger.1": "Bundesliga",
    "fra.1": "Ligue 1",
    "ned.1": "Eredivisie",
    "por.1": "Primeira Liga",
    "ksa.1": "Saudi Pro",
    "usa.1": "MLS",
    "mex.1": "Liga MX",
    "bra.1": "Brasileirão",
    "arg.1": "Liga Profesional",
    "sco.1": "Scottish Prem",
    "bel.1": "Belgian Pro",
    "tur.1": "Süper Lig",
    "eng.2": "Championship",
    "eng.fa": "FA Cup",
    "eng.league_cup": "Carabao Cup",
    "esp.copa_del_rey": "Copa del Rey",
    "ger.dfb_pokal": "DFB-Pokal",
    "ita.coppa_italia": "Coppa Italia",
    "fra.coupe_de_france": "Coupe de France"
  };

  var leagueAbbrevMap = {
    "uefa.champions": "UCL",
    "uefa.europa": "UEL",
    "uefa.europa.conference": "UECL",
    "uefa.super": "USC",
    "uefa.nations": "UNL",
    "fifa.world": "FWC",
    "fifa.cwc": "CWC",
    "conmebol.libertadores": "LIB",
    "conmebol.sudamericana": "SUD",
    "concacaf.champions": "CCC",
    "eng.1": "EPL",
    "esp.1": "LAL",
    "ita.1": "SEA",
    "ger.1": "BUN",
    "fra.1": "L1",
    "ned.1": "ERE",
    "por.1": "PRM",
    "ksa.1": "SPL",
    "usa.1": "MLS",
    "mex.1": "LMX",
    "bra.1": "BRA",
    "arg.1": "ARG",
    "sco.1": "SCO",
    "bel.1": "BEL",
    "tur.1": "TUR",
    "eng.2": "CHA",
    "eng.fa": "FAC",
    "eng.league_cup": "EFL",
    "esp.copa_del_rey": "CDR",
    "ger.dfb_pokal": "DFB",
    "ita.coppa_italia": "COP",
    "fra.coupe_de_france": "CDF"
  };

  function getLeagueTabLabel(league, style, fullLabel, shortLabel) {
    var lg = String(league || "").toLowerCase().trim();
    var s = style || "abbrev";
    if (s === "full") return fullLabel || lg;
    if (s === "short") {
      if (leagueShortMap[lg]) return leagueShortMap[lg];
      return shortLabel || lg;
    }
    if (leagueAbbrevMap[lg]) return leagueAbbrevMap[lg];
    var shortLbl = shortLabel || lg;
    if (shortLbl.length <= 4) return shortLbl.toUpperCase();
    var words = shortLbl.split(/[\s\-_]+/);
    if (words.length >= 3) {
      return (words[0][0] + words[1][0] + words[2][0]).toUpperCase();
    }
    return shortLbl.substring(0, 3).toUpperCase();
  }

  function getTacticalCoordinates(player) {
    if (!player) return { x: 0.50, y: 0.50 };
    var abbr = String(player.positionAbbr || "").toUpperCase().trim();
    var posName = String(player.position || "").toLowerCase().trim();
    var fp = typeof player.formationPlace === "number" ? player.formationPlace : parseInt(player.formationPlace, 10);
    if (isNaN(fp)) fp = 99;

    if (abbr === "G") return { x: 0.50, y: 0.88 };
    if (abbr === "LB") return { x: 0.13, y: 0.74 };
    if (abbr === "LWB") return { x: 0.13, y: 0.67 };
    if (abbr === "CD-L") return { x: 0.38, y: 0.74 };
    if (abbr === "CD") return { x: 0.50, y: 0.74 };
    if (abbr === "CD-R") return { x: 0.62, y: 0.74 };
    if (abbr === "RB") return { x: 0.87, y: 0.74 };
    if (abbr === "RWB") return { x: 0.87, y: 0.67 };

    if (abbr === "DM") return { x: 0.50, y: 0.58 };
    if (abbr === "DM-L") return { x: 0.36, y: 0.58 };
    if (abbr === "DM-R") return { x: 0.64, y: 0.58 };
    if (abbr === "CM-L") return { x: 0.34, y: 0.44 };
    if (abbr === "CM") return { x: 0.50, y: 0.44 };
    if (abbr === "CM-R") return { x: 0.66, y: 0.44 };
    if (abbr === "LM") return { x: 0.13, y: 0.44 };
    if (abbr === "RM") return { x: 0.87, y: 0.44 };

    if (abbr === "AM-L" || abbr === "LW" || abbr === "LF") return { x: 0.16, y: 0.28 };
    if (abbr === "AM") return { x: 0.50, y: 0.30 };
    if (abbr === "AM-R" || abbr === "RW" || abbr === "RF") return { x: 0.84, y: 0.28 };

    if (abbr === "CF-L") return { x: 0.35, y: 0.13 };
    if (abbr === "CF-R") return { x: 0.65, y: 0.13 };
    if (abbr === "CF" || abbr === "F" || abbr === "ST") return { x: 0.50, y: 0.13 };

    if (posName.indexOf("goal") !== -1 || fp === 1) return { x: 0.50, y: 0.88 };
    if (posName.indexOf("left back") !== -1 || (posName.indexOf("def") !== -1 && fp === 3)) return { x: 0.13, y: 0.74 };
    if (posName.indexOf("right back") !== -1 || (posName.indexOf("def") !== -1 && fp === 2)) return { x: 0.87, y: 0.74 };
    if (posName.indexOf("center left def") !== -1 || (posName.indexOf("def") !== -1 && (fp === 4 || fp === 6))) return { x: 0.38, y: 0.74 };
    if (posName.indexOf("center right def") !== -1 || (posName.indexOf("def") !== -1 && (fp === 5 || fp === 7))) return { x: 0.62, y: 0.74 };
    if (posName.indexOf("center def") !== -1 || (posName.indexOf("def") !== -1 && fp === 5)) return { x: 0.50, y: 0.74 };

    if (posName.indexOf("defensive mid") !== -1) return { x: 0.50, y: 0.58 };
    if (posName.indexOf("left mid") !== -1) return { x: 0.13, y: 0.44 };
    if (posName.indexOf("right mid") !== -1) return { x: 0.87, y: 0.44 };
    if (posName.indexOf("center left mid") !== -1 || (posName.indexOf("mid") !== -1 && fp === 8)) return { x: 0.34, y: 0.44 };
    if (posName.indexOf("center right mid") !== -1 || (posName.indexOf("mid") !== -1 && fp === 7)) return { x: 0.66, y: 0.44 };
    if (posName.indexOf("center mid") !== -1 || (posName.indexOf("mid") !== -1 && fp === 4)) return { x: 0.50, y: 0.44 };

    if (posName.indexOf("left forw") !== -1 || posName.indexOf("left wing") !== -1 || (posName.indexOf("att") !== -1 && fp === 11)) return { x: 0.16, y: 0.28 };
    if (posName.indexOf("right forw") !== -1 || posName.indexOf("right wing") !== -1 || (posName.indexOf("att") !== -1 && (fp === 7 || fp === 10))) return { x: 0.84, y: 0.28 };
    if (posName.indexOf("center left forw") !== -1) return { x: 0.35, y: 0.13 };
    if (posName.indexOf("center right forw") !== -1) return { x: 0.65, y: 0.13 };
    if (posName.indexOf("forw") !== -1 || posName.indexOf("striker") !== -1 || fp === 9) return { x: 0.50, y: 0.13 };
    if (posName.indexOf("att") !== -1 || fp === 10) return { x: 0.50, y: 0.30 };

    if (fp === 1) return { x: 0.50, y: 0.88 };
    if (fp === 3) return { x: 0.13, y: 0.74 };
    if (fp === 4) return { x: 0.38, y: 0.74 };
    if (fp === 5) return { x: 0.50, y: 0.74 };
    if (fp === 6) return { x: 0.62, y: 0.74 };
    if (fp === 2) return { x: 0.87, y: 0.74 };
    if (fp === 8) return { x: 0.34, y: 0.44 };
    if (fp === 7) return { x: 0.66, y: 0.44 };
    if (fp === 11) return { x: 0.16, y: 0.28 };
    if (fp === 10) return { x: 0.84, y: 0.28 };
    if (fp === 9) return { x: 0.50, y: 0.13 };

    return { x: 0.50, y: 0.50 };
  }

  function layoutPitchPlayers(starters) {
    if (!starters || starters.length === 0) return [];
    var result = [];
    for (var i = 0; i < starters.length; i++) {
      var pObj = starters[i];
      var coords = getTacticalCoordinates(pObj);
      var sName = pObj.shortName || "";
      if (sName === "" && pObj.name) {
        var parts = pObj.name.trim().split(" ");
        sName = parts[parts.length - 1];
      }
      result.push({
        name: pObj.name || "",
        shortName: sName,
        jersey: pObj.jersey || "",
        position: pObj.position || "",
        positionAbbr: pObj.positionAbbr || "",
        formationPlace: pObj.formationPlace,
        goals: pObj.goals || 0,
        assists: pObj.assists || 0,
        yellowCards: pObj.yellowCards || 0,
        redCards: pObj.redCards || 0,
        subbedOut: !!pObj.subbedOut,
        subbedIn: !!pObj.subbedIn,
        rating: pObj.rating !== undefined ? pObj.rating : null,
        jerseyImage: pObj.jerseyImage || pObj.headshot || "",
        headshot: pObj.headshot || "",
        x: coords.x,
        y: coords.y
      });
    }

    for (var pass = 0; pass < 6; pass++) {
      for (var a = 0; a < result.length; a++) {
        for (var b = a + 1; b < result.length; b++) {
          var dx = Math.abs(result[a].x - result[b].x);
          var dy = Math.abs(result[a].y - result[b].y);
          if (dy < 0.10 && dx < 0.18) {
            var neededX = (0.18 - dx) / 2;
            if (result[a].x <= result[b].x) {
              result[a].x = Math.max(0.12, result[a].x - neededX);
              result[b].x = Math.min(0.88, result[b].x + neededX);
            } else {
              result[a].x = Math.min(0.88, result[a].x + neededX);
              result[b].x = Math.max(0.12, result[b].x - neededX);
            }
            if (dy < 0.06) {
              var neededY = (0.06 - dy) / 2;
              if (result[a].y <= result[b].y) {
                result[a].y = Math.max(0.12, result[a].y - neededY);
                result[b].y = Math.min(0.86, result[b].y + neededY);
              } else {
                result[a].y = Math.min(0.86, result[a].y + neededY);
                result[b].y = Math.max(0.12, result[b].y - neededY);
              }
            }
          }
        }
      }
    }
    return result;
  }

  function applySingleStatMap(prof, statMap, label) {
    if (!prof || !statMap) return prof;
    var p = Object.assign({}, prof);

    p.seasonAppearances = (statMap["appearances"] || statMap["starts"]) ? String(statMap["appearances"] || statMap["starts"]) : "0";
    p.seasonGoals = statMap["totalGoals"] !== undefined ? String(statMap["totalGoals"]) : "0";
    p.seasonAssists = statMap["goalAssists"] !== undefined ? String(statMap["goalAssists"]) : "0";
    p.seasonKeyPasses = statMap["shotAssists"] !== undefined ? String(statMap["shotAssists"]) : "0";
    p.seasonPassPct = statMap["passPct"] ? (Math.round(parseFloat(statMap["passPct"]) * 100) + "%") : "";
    p.seasonTackles = (statMap["effectiveTackles"] || statMap["totalTackles"]) ? String(statMap["effectiveTackles"] || statMap["totalTackles"]) : "";
    p.seasonInterceptions = statMap["interceptions"] ? String(statMap["interceptions"]) : "";
    p.seasonShots = statMap["totalShots"] !== undefined ? String(statMap["totalShots"]) : "0";
    p.seasonShotsOnTarget = statMap["shotsOnTarget"] !== undefined ? String(statMap["shotsOnTarget"]) : "0";
    p.seasonSaves = statMap["saves"] ? String(statMap["saves"]) : "";
    p.seasonCleanSheets = statMap["cleanSheet"] ? String(statMap["cleanSheet"]) : "";
    p.seasonChances = statMap["bigChanceCreated"] ? String(statMap["bigChanceCreated"]) : "";

    p.seasonYellowCards = statMap["yellowCards"] !== undefined ? String(statMap["yellowCards"]) : "0";
    p.seasonRedCards = statMap["redCards"] !== undefined ? String(statMap["redCards"]) : "0";

    var fc = statMap["foulsCommitted"] !== undefined ? statMap["foulsCommitted"] : "0";
    var fs = statMap["foulsSuffered"] !== undefined ? statMap["foulsSuffered"] : "0";
    p.seasonFouls = fc + " / " + fs;
    p.seasonFoulsCommitted = String(fc);
    p.seasonFoulsSuffered = String(fs);

    if (statMap["minutes"] !== undefined && parseInt(statMap["minutes"]) > 0) {
      p.seasonMinutes = String(statMap["minutes"]);
      var aInt = parseInt(p.seasonAppearances || "0");
      var mInt = parseInt(statMap["minutes"]);
      if (mInt > 0 && aInt > 0) {
        p.seasonMinPerApp = Math.round(mInt / aInt) + "'";
      } else {
        p.seasonMinPerApp = "—";
      }
    } else {
      p.seasonMinutes = "0";
      p.seasonMinPerApp = "—";
    }

    var subIn = statMap["subIns"] || "0";
    var subOut = statMap["subOuts"] || "0";
    p.seasonSubIns = String(subIn);
    p.seasonSubOuts = String(subOut);
    p.seasonSubs = String((parseInt(subIn) || 0) + (parseInt(subOut) || 0));

    var curGoals = parseFloat(p.seasonGoals || "0");
    var curShots = parseFloat(p.seasonShots || "0");
    var curSog = parseFloat(p.seasonShotsOnTarget || "0");
    if (curShots > 0 && curGoals >= 0) {
      p.goalConversionRate = ((curGoals / curShots) * 100).toFixed(1) + "%";
    } else {
      p.goalConversionRate = "—";
    }
    if (curShots > 0 && curSog >= 0) {
      p.shotAccuracy = Math.round((curSog / curShots) * 100) + "%";
    } else if (statMap["shotPct"]) {
      p.shotAccuracy = Math.round(parseFloat(statMap["shotPct"])) + "%";
    } else {
      p.shotAccuracy = "—";
    }

    var lb = statMap["accurateLongBalls"] || statMap["totalLongBalls"];
    var kp = statMap["shotAssists"];
    p.longBalls = (lb !== undefined && lb !== "") ? String(lb) : "0";
    p.keyPasses = (kp !== undefined && kp !== "") ? String(kp) : "0";
    if (p.longBalls && p.keyPasses && (p.longBalls !== "0" || p.keyPasses !== "0")) {
      p.passDistribution = p.longBalls + " LB · " + p.keyPasses + " KP";
    } else {
      p.passDistribution = "—";
    }

    if (statMap["passPct"]) statMap["passPct"] = p.seasonPassPct;
    p.seasonStatMap = statMap;
    if (label) p.selectedSeasonYear = label;

    return p;
  }

  function formatGroupedScorers(items, sanitizePlainText) {
    var cleanText = sanitizePlainText || function(s) { return s ? String(s) : ""; };
    var grouped = {};
    var order = [];
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      if (!it || !it.name) continue;
      var nameKey = it.name;
      var clkPart = String(it.clock || "").trim();
      while (clkPart.endsWith("''")) clkPart = clkPart.substring(0, clkPart.length - 1);
      if (clkPart !== "" && !clkPart.endsWith("'") && !isNaN(Number(clkPart))) clkPart += "'";
      if (it.ownGoal) clkPart += (clkPart !== "" ? " " : "") + "(OG)";
      else if (it.penaltyKick) clkPart += (clkPart !== "" ? " " : "") + "(P)";
      if (!grouped[nameKey]) {
        grouped[nameKey] = [];
        order.push(nameKey);
      }
      if (clkPart !== "") grouped[nameKey].push(clkPart);
    }
    var res = [];
    for (var j = 0; j < order.length; j++) {
      var n = order[j];
      var clkList = grouped[n].join(", ");
      var line = (n + " " + clkList).trim();
      if (line !== "") res.push(cleanText(line));
    }
    return res;
  }

  var matchStatDefs = [
    { name: "expectedGoals", label: "Expected Goals (xG)", suffix: "" },
    { name: "expectedGoalsConceded", label: "xG Conceded (xGC)", suffix: "" },
    { name: "possessionPct", label: "Possession", suffix: "%" },
    { name: "totalShots", altName: "shots", label: "Total Shots", suffix: "" },
    { name: "shotsOnTarget", label: "Shots on Target", suffix: "" },
    { name: "accuratePasses", label: "Accurate Passes", suffix: "" },
    { name: "totalPasses", label: "Total Passes", suffix: "" },
    { name: "passPct", label: "Pass Accuracy", suffix: "%" },
    { name: "wonCorners", altName: "cornerKicks", label: "Corner Kicks", suffix: "" },
    { name: "crossPct", label: "Cross Accuracy", suffix: "%" },
    { name: "longballPct", label: "Long Ball Accuracy", suffix: "%" },
    { name: "blockedShots", label: "Blocked Shots", suffix: "" },
    { name: "effectiveTackles", altName: "totalTackles", label: "Tackles Won", suffix: "" },
    { name: "tacklePct", label: "Tackles Won %", suffix: "%" },
    { name: "interceptions", label: "Interceptions", suffix: "" },
    { name: "effectiveClearance", altName: "totalClearance", label: "Clearances", suffix: "" },
    { name: "foulsCommitted", label: "Fouls", suffix: "" },
    { name: "yellowCards", label: "Yellow Cards", suffix: "" },
    { name: "redCards", label: "Red Cards", suffix: "" },
    { name: "offsides", label: "Offsides", suffix: "" },
    { name: "saves", label: "Goalkeeper Saves", suffix: "" }
  ];

  function parseBoxscoreStats(data, homeTeam, sanitizePlainText) {
    var cleanText = sanitizePlainText || function(s) { return s ? String(s) : ""; };
    var parsedStats = [];
    var boxTeams = (data.boxscore && Array.isArray(data.boxscore.teams)) ? data.boxscore.teams : [];
    if (boxTeams.length < 2) return parsedStats;

    var hBox = boxTeams[0];
    var aBox = boxTeams[1];
    if (homeTeam && homeTeam.id && hBox.team && String(hBox.team.id) !== String(homeTeam.id)) {
      hBox = boxTeams[1];
      aBox = boxTeams[0];
    }

    var hStatsList = Array.isArray(hBox.statistics) ? hBox.statistics : [];
    var aStatsList = Array.isArray(aBox.statistics) ? aBox.statistics : [];
    var hMap = {};
    var aMap = {};
    for (var si = 0; si < hStatsList.length; si++) {
      if (hStatsList[si] && hStatsList[si].name) hMap[hStatsList[si].name] = hStatsList[si].displayValue;
    }
    for (var sj = 0; sj < aStatsList.length; sj++) {
      if (aStatsList[sj] && aStatsList[sj].name) aMap[aStatsList[sj].name] = aStatsList[sj].displayValue;
    }
    if (Array.isArray(data.leaders)) {
      for (var ldi = 0; ldi < data.leaders.length; ldi++) {
        var ldt = data.leaders[ldi];
        if (!ldt) continue;
        var isHld = (homeTeam && homeTeam.id && ldt.team && String(ldt.team.id) === String(homeTeam.id)) || (ldi === 0);
        var clist = Array.isArray(ldt.leaders) ? ldt.leaders : [];
        for (var ci = 0; ci < clist.length; ci++) {
          var alist = Array.isArray(clist[ci].leaders) ? clist[ci].leaders : [];
          for (var ai = 0; ai < alist.length; ai++) {
            var slist = Array.isArray(alist[ai].statistics) ? alist[ai].statistics : [];
            for (var sli = 0; sli < slist.length; sli++) {
              var so = slist[sli];
              if (so && (so.name === "expectedGoals" || so.name === "expectedGoalsConceded")) {
                (isHld ? hMap : aMap)[so.name] = so.displayValue;
              }
            }
          }
        }
      }
    }

    for (var sd = 0; sd < matchStatDefs.length; sd++) {
      var def = matchStatDefs[sd];
      var hV = hMap[def.name] !== undefined ? hMap[def.name] : (def.altName ? hMap[def.altName] : undefined);
      var aV = aMap[def.name] !== undefined ? aMap[def.name] : (def.altName ? aMap[def.altName] : undefined);
      if (hV !== undefined || aV !== undefined) {
        var hNum = parseFloat(hV) || 0;
        var aNum = parseFloat(aV) || 0;
        var total = hNum + aNum;
        var hRatio = total > 0 ? (hNum / total) : 0.5;
        parsedStats.push({
          name: def.name,
          label: def.label,
          homeValue: cleanText(String(hV !== undefined ? hV : "0") + def.suffix),
          awayValue: cleanText(String(aV !== undefined ? aV : "0") + def.suffix),
          homeRatio: hRatio
        });
      }
    }
    return parsedStats;
  }

  function buildKnockoutBracket(comp, hdr, data, homeTeam, awayTeam, isActuallyStarted, statusDesc, roundName, seriesNote, helpers) {
    var sanitizePlainText = (helpers && helpers.sanitizePlainText) || function(s) { return s ? String(s) : ""; };
    var sanitizeImageUrl = (helpers && helpers.sanitizeImageUrl) || function(s) { return s ? String(s) : ""; };
    var safeIdentifier = (helpers && helpers.safeIdentifier) || function(s) { return s ? String(s) : ""; };

    var slugLower = String((helpers && helpers.competitionSlug) || (hdr.league && hdr.league.slug) || "").toLowerCase();
    var stageTextParts = [
      String(comp.altGameNote || ""),
      String(hdr.season && (hdr.season.name || hdr.season.displayName) || ""),
      String(data.season && data.season.name || ""),
      roundName, seriesNote,
      String(comp.series && (comp.series.title || (Array.isArray(comp.series) && comp.series[0] ? comp.series[0].title : "")) || "")
    ];
    if (Array.isArray(comp.notes)) {
      for (var cni = 0; cni < comp.notes.length; cni++) {
        var cnItem = comp.notes[cni];
        if (cnItem && (cnItem.headline || cnItem.text)) stageTextParts.push(String(cnItem.headline || cnItem.text));
      }
    }
    var stageCombined = stageTextParts.join(" ").toLowerCase();

    var isDomesticLeague = /^[a-z]{3}\.[1-4]$/.test(slugLower) || slugLower.indexOf(".1") !== -1 ||
      slugLower === "eng.1" || slugLower === "esp.1" || slugLower === "ita.1" || slugLower === "ger.1" || slugLower === "fra.1" || slugLower === "usa.1";

    var isNonKnockoutStage = stageCombined.indexOf("league phase") !== -1 || stageCombined.indexOf("group stage") !== -1 ||
      stageCombined.indexOf("group phase") !== -1 || stageCombined.indexOf("regular season") !== -1 ||
      stageCombined.indexOf("matchweek") !== -1 || stageCombined.indexOf("gameweek") !== -1 ||
      stageCombined.indexOf("round robin") !== -1 || /group\s+([a-l]|[1-9])/i.test(stageCombined);

    var hasConfirmedKnockoutText = /(round of (16|32|64|8)|rd of 16|r16|quarter|semi|final|third place|3rd place|knockout)/i.test(stageCombined);
    var isDomesticCup = /(fa|league_cup|copa_del_rey|coppa_italia|dfb_pokal|coupe_de_france|open_cup)/i.test(slugLower);
    var hasCupRoundText = isDomesticCup && /(round|proper|qualifying)/i.test(stageCombined);
    var hasExplicitSeries = !!(comp.series && (comp.series.title || (Array.isArray(comp.series) && comp.series.length > 0 && comp.series[0].title)));

    var isConfirmedKnockout = !isNonKnockoutStage && (!isDomesticLeague || hasExplicitSeries) &&
      (hasConfirmedKnockoutText || hasCupRoundText || hasExplicitSeries);

    var parsedBracket = [];
    if (!isConfirmedKnockout) {
      return { available: false, bracket: [], seriesNote: seriesNote };
    }

    var activeRoundTitle = "Quarterfinals";
    if (stageCombined.indexOf("round of 16") !== -1 || stageCombined.indexOf("rd of 16") !== -1 || stageCombined.indexOf("r16") !== -1) {
      activeRoundTitle = "Round of 16";
    } else if (stageCombined.indexOf("quarter") !== -1) {
      activeRoundTitle = "Quarterfinals";
    } else if (stageCombined.indexOf("semi") !== -1) {
      activeRoundTitle = "Semifinals";
    } else if (stageCombined.indexOf("final") !== -1) activeRoundTitle = "Final";
    else if (comp.series && comp.series.title) activeRoundTitle = String(comp.series.title);
    else if (roundName !== "") activeRoundTitle = roundName;

    var isUclSwiss = (slugLower.indexOf("champions") !== -1 || slugLower.indexOf("europa") !== -1) && (stageCombined.indexOf("playoff") !== -1 || (data.season && data.season.year >= 2024));
    var roundOrder = (isUclSwiss || stageCombined.indexOf("playoff") !== -1) ? ["Playoffs", "Round of 16", "Quarterfinals", "Semifinals", "Final"] : (stageCombined.indexOf("round of 32") !== -1 ? ["Round of 32", "Round of 16", "Quarterfinals", "Semifinals", "Final"] : ["Round of 16", "Quarterfinals", "Semifinals", "Final"]);
    var activeRoundIdx = 1;
    for (var roi = 0; roi < roundOrder.length; roi++) {
      if (activeRoundTitle.toLowerCase().indexOf(roundOrder[roi].toLowerCase().replace("round of 16", "16").replace("quarterfinals", "quarter").replace("semifinals", "semi")) !== -1) {
        activeRoundIdx = roi;
        break;
      }
    }

    var curHomeScore = isActuallyStarted ? String(helpers && helpers.homeComp && helpers.homeComp.score !== undefined ? helpers.homeComp.score : "0") : "";
    var curAwayScore = isActuallyStarted ? String(helpers && helpers.awayComp && helpers.awayComp.score !== undefined ? helpers.awayComp.score : "0") : "";
    var seriesRes = resolveMatchSeries(comp, homeTeam, awayTeam, curHomeScore, curAwayScore, statusDesc, stageCombined, seriesNote);
    var hasTwoLegs = seriesRes.hasTwoLegs;
    var isSeriesCompleted = seriesRes.isSeriesCompleted;
    var curSeriesWinner = String(seriesRes.curSeriesWinner || "");
    var curAggHome = String(seriesRes.curAggHome || "");
    var curAggAway = String(seriesRes.curAggAway || "");
    var curHomeLeg1 = String(seriesRes.curHomeLeg1 || "");
    var curHomeLeg2 = String(seriesRes.curHomeLeg2 || "");
    var curAwayLeg1 = String(seriesRes.curAwayLeg1 || "");
    var curAwayLeg2 = String(seriesRes.curAwayLeg2 || "");
    var curSeriesSummary = String(seriesRes.curSeriesSummary || "");
    if (seriesNote === "" && curSeriesSummary !== "") {
      seriesNote = sanitizePlainText(curSeriesSummary);
    }

    var currentMatchup = {
      homeName: sanitizePlainText(String(homeTeam.displayName || homeTeam.name || "Home")),
      homeLogo: sanitizeImageUrl(String((homeTeam.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + safeIdentifier(String(homeTeam.id)) + ".png") : "") || homeTeam.logo || (homeTeam.logos && homeTeam.logos[0] ? homeTeam.logos[0].href : ""))),
      homeScore: sanitizePlainText(curHomeScore),
      homeLeg1: sanitizePlainText(curHomeLeg1),
      homeLeg2: sanitizePlainText(curHomeLeg2),
      homeAgg: sanitizePlainText(curAggHome),
      awayName: sanitizePlainText(String(awayTeam.displayName || awayTeam.name || "Away")),
      awayLogo: sanitizeImageUrl(String((awayTeam.id ? ("https://a.espncdn.com/i/teamlogos/soccer/500/" + safeIdentifier(String(awayTeam.id)) + ".png") : "") || awayTeam.logo || (awayTeam.logos && awayTeam.logos[0] ? awayTeam.logos[0].href : ""))),
      awayScore: sanitizePlainText(curAwayScore),
      awayLeg1: sanitizePlainText(curAwayLeg1),
      awayLeg2: sanitizePlainText(curAwayLeg2),
      awayAgg: sanitizePlainText(curAggAway),
      hasTwoLegs: hasTwoLegs,
      isCurrent: true,
      statusText: curSeriesSummary !== "" ? curSeriesSummary : (isActuallyStarted ? (statusDesc || "In Progress") : "Upcoming"),
      completed: isSeriesCompleted,
      winner: curSeriesWinner
    };

    for (var ri = 0; ri < roundOrder.length; ri++) {
      var rName = roundOrder[ri];
      var isCurrentRound = (ri === activeRoundIdx);
      var matchupsCount = rName === "Round of 16" ? 8 : (rName === "Quarterfinals" ? 4 : (rName === "Semifinals" ? 2 : 1));
      var matchups = [];

      for (var mi = 0; mi < matchupsCount; mi++) {
        if (isCurrentRound && mi === 0) {
          matchups.push(currentMatchup);
        } else if (ri > activeRoundIdx && mi === 0) {
          var advTeamName = curSeriesWinner !== "" ? curSeriesWinner : ("Winner of " + currentMatchup.homeName + " vs " + currentMatchup.awayName);
          var advTeamLogo = curSeriesWinner !== "" ? ((curSeriesWinner === currentMatchup.homeName || (currentMatchup.homeName && currentMatchup.homeName.indexOf(curSeriesWinner) !== -1) || curSeriesWinner.indexOf(currentMatchup.homeName) !== -1) ? currentMatchup.homeLogo : currentMatchup.awayLogo) : "";
          var advStatus = curSeriesWinner !== "" ? "Advanced" : "Next Round";
          matchups.push({
            homeName: sanitizePlainText(advTeamName),
            homeLogo: sanitizeImageUrl(advTeamLogo),
            homeScore: "",
            homeAgg: "",
            awayName: "TBD",
            awayLogo: "",
            awayScore: "",
            awayAgg: "",
            isCurrent: false,
            statusText: advStatus,
            completed: false,
            winner: ""
          });
        }
      }

      parsedBracket.push({
        roundName: rName,
        roundIndex: ri,
        isCurrentRound: isCurrentRound,
        matchups: matchups
      });
    }

    return { available: true, bracket: parsedBracket, seriesNote: seriesNote };
  }

  function resolveTeamNameFromRef(ref, teamTabLabelFn, caches, selectedPlayerProfile, teamNameForIdFn) {
    if (!ref || typeof ref !== "string") return { name: "", shortName: "", abbrev: "", logo: "", id: "" };
    var labelFn = teamTabLabelFn || function(n, l, s) { return n; };
    var nameCache = (caches && caches.nameCache) || {};
    var shortCache = (caches && caches.shortCache) || {};
    var abbrevCache = (caches && caches.abbrevCache) || {};

    if (ref.indexOf("/faux") !== -1 || ref.indexOf("faux?") !== -1) {
      var dMatch = ref.match(/[?&]displayName=([^&]+)/);
      if (dMatch) {
        try {
          var dn = decodeURIComponent(dMatch[1].replace(/\+/g, " "));
          var dShort = labelFn(dn, "", "short");
          var dAbbr = labelFn(dn, "", "abbrev");
          return { name: dn, shortName: dShort || dn, abbrev: dAbbr || dn, logo: "", id: "" };
        } catch (e) {
          var dn2 = dMatch[1].replace(/\+/g, " ");
          var dShort2 = labelFn(dn2, "", "short");
          var dAbbr2 = labelFn(dn2, "", "abbrev");
          return { name: dn2, shortName: dShort2 || dn2, abbrev: dAbbr2 || dn2, logo: "", id: "" };
        }
      }
      var nMatch = ref.match(/[?&]name=([^&]+)/);
      if (nMatch) {
        try {
          var nn = decodeURIComponent(nMatch[1].replace(/\+/g, " "));
          return { name: nn, shortName: labelFn(nn, "", "short") || nn, abbrev: labelFn(nn, "", "abbrev") || nn, logo: "", id: "" };
        } catch (e) {
          var nn2 = nMatch[1].replace(/\+/g, " ");
          return { name: nn2, shortName: labelFn(nn2, "", "short") || nn2, abbrev: labelFn(nn2, "", "abbrev") || nn2, logo: "", id: "" };
        }
      }
      var lMatch = ref.match(/[?&]location=([^&]+)/);
      if (lMatch) {
        try {
          var ln = decodeURIComponent(lMatch[1].replace(/\+/g, " "));
          return { name: ln, shortName: labelFn(ln, "", "short") || ln, abbrev: labelFn(ln, "", "abbrev") || ln, logo: "", id: "" };
        } catch (e) {
          var ln2 = lMatch[1].replace(/\+/g, " ");
          return { name: ln2, shortName: labelFn(ln2, "", "short") || ln2, abbrev: labelFn(ln2, "", "abbrev") || ln2, logo: "", id: "" };
        }
      }
      var slugM = ref.match(/[?&]slug=([^&]+)/);
      if (slugM) {
        try {
          var s = decodeURIComponent(slugM[1].replace(/[-_]/g, " "));
          var sName = s.charAt(0).toUpperCase() + s.slice(1);
          return { name: sName, shortName: labelFn(sName, "", "short") || sName, abbrev: labelFn(sName, "", "abbrev") || sName, logo: "", id: "" };
        } catch (e) {
          return { name: slugM[1], shortName: slugM[1], abbrev: "FA", logo: "", id: "" };
        }
      }
      return { name: "Unattached", shortName: "Free Agent", abbrev: "FA", logo: "", id: "" };
    }
    var tMatch = ref.match(/\/teams\/(\d+)/);
    if (tMatch) {
      var tid = tMatch[1];
      var knownName = "";
      var knownShort = "";
      var knownAbbr = "";
      if (nameCache[tid]) {
        knownName = nameCache[tid];
      } else if (teamNameForIdFn) {
        knownName = teamNameForIdFn(tid);
      }
      if (shortCache[tid]) {
        knownShort = shortCache[tid];
      }
      if (abbrevCache[tid]) {
        knownAbbr = abbrevCache[tid];
      }
      if (selectedPlayerProfile) {
        var p = selectedPlayerProfile;
        if (p.clubOptions && Array.isArray(p.clubOptions)) {
          for (var ci = 0; ci < p.clubOptions.length; ci++) {
            if (String(p.clubOptions[ci].teamId) === String(tid)) {
              if (!knownName && p.clubOptions[ci].name) knownName = p.clubOptions[ci].name;
              if (!knownShort && p.clubOptions[ci].shortName) knownShort = p.clubOptions[ci].shortName;
              if (!knownAbbr && p.clubOptions[ci].abbreviation) knownAbbr = p.clubOptions[ci].abbreviation;
              break;
            }
          }
        }
        if (p.careerHistory && Array.isArray(p.careerHistory)) {
          for (var chi = 0; chi < p.careerHistory.length; chi++) {
            if (String(p.careerHistory[chi].teamId) === String(tid)) {
              if (!knownName && p.careerHistory[chi].name) knownName = p.careerHistory[chi].name;
              if (!knownShort && p.careerHistory[chi].shortName) knownShort = p.careerHistory[chi].shortName;
              if (!knownAbbr && p.careerHistory[chi].abbreviation) knownAbbr = p.careerHistory[chi].abbreviation;
              break;
            }
          }
        }
      }
      var finalName = knownName !== "" ? knownName : ("Team " + tid);
      if (!knownShort && finalName) {
        knownShort = labelFn(finalName, "", "short", tid);
      }
      if (!knownAbbr && finalName) {
        knownAbbr = labelFn(finalName, "", "abbrev", tid);
      }
      return {
        id: tid,
        name: finalName,
        shortName: knownShort || finalName,
        abbrev: knownAbbr || finalName,
        logo: "https://a.espncdn.com/i/teamlogos/soccer/500/" + tid + ".png"
      };
    }
    return { name: "", shortName: "", abbrev: "", logo: "", id: "" };
  }

  function parseStats(data, helpers) {
    var sanitizePlainText = (helpers && helpers.sanitizePlainText) || function(s) { return s ? String(s) : ""; };
    var sanitizeImageUrl = (helpers && helpers.sanitizeImageUrl) || function(s) { return s ? String(s) : ""; };
    var safeIdentifier = (helpers && helpers.safeIdentifier) || function(s) { return s ? String(s) : ""; };
    var sortLeaders = (helpers && helpers.sortLeaders) || function(l) { return l; };

    var goals = [];
    var assists = [];
    var statsList = data && Array.isArray(data.stats) ? data.stats : [];
    for (var i = 0; i < statsList.length; i++) {
      var cat = statsList[i];
      if (!cat) continue;
      var catName = String(cat.name || "");
      var leaders = Array.isArray(cat.leaders) ? cat.leaders : [];
      var out = [];
      for (var j = 0; j < leaders.length; j++) {
        var l = leaders[j];
        if (!l) continue;
        var ath = l.athlete || {};
        var team = ath.team || l.team || {};
        var disp = String(l.displayValue || "");
        var matchRegex = disp.match(/Matches:\s*(\d+)/i);
        var apps = matchRegex ? matchRegex[1] : "";
        if (apps === "") {
          var athStats = Array.isArray(ath.statistics) ? ath.statistics : [];
          for (var s = 0; s < athStats.length; s++) {
            if (athStats[s] && athStats[s].name === "appearances") {
              apps = String(athStats[s].displayValue !== undefined ? athStats[s].displayValue : (athStats[s].value !== undefined ? Math.round(Number(athStats[s].value)) : ""));
              break;
            }
          }
        }
        var statVal = "";
        if (l.value !== undefined && l.value !== null && l.value !== "") {
          statVal = String(Math.round(Number(l.value)));
        } else {
          var statRegex = disp.match(/(?:Goals|Assists):\s*(\d+)/i);
          statVal = statRegex ? statRegex[1] : disp;
        }
        var teamLogo = "";
        if (team.logos && team.logos[0]) {
          teamLogo = sanitizeImageUrl(String(team.logos[0].href || ""));
        } else if (team.logo) {
          teamLogo = sanitizeImageUrl(String(team.logo));
        } else if (team.id) {
          var safeTid = safeIdentifier(String(team.id));
          if (safeTid !== "") teamLogo = "https://a.espncdn.com/i/teamlogos/soccer/500/" + safeTid + ".png";
        }
        var entry = {
          rank: j + 1,
          name: sanitizePlainText(String(ath.displayName || ath.shortName || "Unknown")),
          jersey: sanitizePlainText(String(ath.jersey || "")),
          teamName: sanitizePlainText(String(team.displayName || team.name || "")),
          teamLogo: teamLogo,
          appearances: sanitizePlainText(apps),
          value: sanitizePlainText(statVal)
        };
        if (entry.name !== "") out.push(entry);
      }
      if (catName.indexOf("goals") !== -1) goals = sortLeaders(out);
      else if (catName.indexOf("assists") !== -1) assists = sortLeaders(out);
    }
    return { goals: goals, assists: assists };
  }

  function mergeRows(existing, incoming) {
    if (!existing || existing.length === 0 || !incoming || incoming.length === 0) return incoming;
    if (existing.length !== incoming.length) return incoming;
    var changed = false;
    var merged = [];
    for (var i = 0; i < incoming.length; i++) {
      var inR = incoming[i];
      var exR = existing[i];
      if (inR.id !== exR.id || inR.state !== exR.state || inR.homeScore !== exR.homeScore || inR.awayScore !== exR.awayScore || inR.status !== exR.status || inR.timeText !== exR.timeText || inR.dateText !== exR.dateText) {
        changed = true;
        merged.push(inR);
      } else {
        merged.push(exR);
      }
    }
    return changed ? merged : existing;
  }

  function mergeMatchClusters(existing, incoming) {
    if (!existing || existing.length === 0 || !incoming || incoming.length === 0) return incoming;
    if (existing.length !== incoming.length) return incoming;
    var changed = false;
    var merged = [];
    for (var c = 0; c < incoming.length; c++) {
      var inCluster = incoming[c];
      var exCluster = existing[c];
      if (inCluster.label !== exCluster.label || inCluster.rows.length !== exCluster.rows.length) {
        return incoming;
      }
      var rows = mergeRows(exCluster.rows, inCluster.rows);
      if (rows !== exCluster.rows) {
        changed = true;
        merged.push({ label: inCluster.label, rows: rows });
      } else {
        merged.push(exCluster);
      }
    }
    return changed ? merged : existing;
  }

  function formatTransferValue(rawAmt, amtType, currencyObj) {
    var currSign = "€";
    if (currencyObj) {
      if (currencyObj.sign) {
        currSign = currencyObj.sign;
      } else if (currencyObj.code === "GBP") {
        currSign = "£";
      } else if (currencyObj.code === "USD") {
        currSign = "$";
      } else if (currencyObj.code === "EUR") {
        currSign = "€";
      }
    }
    var numVal = Number(rawAmt);
    if (!isNaN(numVal) && numVal > 0) {
      if (numVal >= 1000000) {
        var mVal = Math.round((numVal / 1000000) * 10) / 10;
        return currSign + (mVal === Math.floor(mVal) ? Math.floor(mVal) : mVal) + "M";
      } else if (numVal >= 1000) {
        var kVal = Math.round((numVal / 1000) * 10) / 10;
        return currSign + (kVal === Math.floor(kVal) ? Math.floor(kVal) : kVal) + "K";
      } else {
        return currSign + Math.round(numVal);
      }
    }
    var strAmt = String(rawAmt || "").toLowerCase().trim();
    var strType = String(amtType || "").toLowerCase().trim();
    if (strAmt === "free" || strType === "free") return "Free Transfer";
    if (strAmt === "loan" || strType === "loan") return "Loan";
    if (strAmt === "undisclosed" || strType === "undisclosed") return "Undisclosed";
    if (strType === "fee" && (rawAmt === "" || numVal === 0)) return "Undisclosed Fee";
    if (rawAmt !== "" && isNaN(numVal)) return String(rawAmt);
    if (amtType !== "") return String(amtType);
    return "Undisclosed";
  }
