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
    "river plate": "RIV", "flamengo": "FLA", "palmeiras": "PAL"
  };

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
    var intlPrefixes = ["fifa.", "uefa.euro", "uefa.nations", "conmebol.america", "concacaf.gold", "concacaf.nations", "caf.nations", "afc.asian", "fifa.friendly", "global.", "intl."];
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

      var pairKey = [hName, aName].sort().join("|") + "|" + rName;
      var noteLower = noteTexts.join(" ").toLowerCase();
      var isLeg2 = noteLower.indexOf("2nd leg") !== -1 || noteLower.indexOf("advance") !== -1;
      var isLeg1 = noteLower.indexOf("1st leg") !== -1;
      var hScore = String(h.score !== undefined ? h.score : "");
      var aScore = String(a.score !== undefined ? a.score : "");
      var hAgg = h.aggregateScore !== undefined ? String(h.aggregateScore) : "";
      var aAgg = a.aggregateScore !== undefined ? String(a.aggregateScore) : "";

      var seriesObj = comp.series ? (Array.isArray(comp.series) && comp.series.length > 0 ? comp.series[0] : comp.series) : null;
      var sCompetitors = seriesObj && Array.isArray(seriesObj.competitors) ? seriesObj.competitors : [];

      if (!acc.seenSeries[pairKey]) {
        acc.seenSeries[pairKey] = {
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
        acc.map[rName].push(acc.seenSeries[pairKey]);
      }

      var s = acc.seenSeries[pairKey];
      if (sCompetitors.length > 0) s.seriesCompetitors = sCompetitors;
      if (noteTexts.length > 0) {
        s.notes = noteTexts;
        s.statusText = noteTexts[0];
      }
      var isCompCompleted = comp.status && comp.status.type ? comp.status.type.completed === true : true;

      if (isLeg1) {
        s.isLeg1Found = true;
        if (hName === s.teamA) {
          s.leg1_A = hScore;
          s.leg1_B = aScore;
        } else {
          s.leg1_B = hScore;
          s.leg1_A = aScore;
        }
      } else if (isLeg2) {
        s.isLeg2Found = true;
        s.completed = isCompCompleted;
        if (hName === s.teamA) {
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
        if (hName === s.teamA) {
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
              var noteCombined = ((sObj.notes ? sObj.notes.join(" ") : "") + " " + String(sObj.statusText || "")).toLowerCase();
              var nameA_low = String(sObj.teamA || "").toLowerCase();
              var nameB_low = String(sObj.teamB || "").toLowerCase();
              var posA = nameA_low !== "" ? noteCombined.indexOf(nameA_low) : -1;
              var posB = nameB_low !== "" ? noteCombined.indexOf(nameB_low) : -1;
              var posAdv = noteCombined.indexOf("advance");
              var posWin = noteCombined.indexOf("win");
              var targetPos = posAdv !== -1 ? posAdv : posWin;
              if (targetPos !== -1) {
                var distA = (posA !== -1 && posA < targetPos) ? (targetPos - posA) : 999999;
                var distB = (posB !== -1 && posB < targetPos) ? (targetPos - posB) : 999999;
                if (distA < distB && distA < 60) wName = sObj.teamA;
                else if (distB < distA && distB < 60) wName = sObj.teamB;
              }
            }

            // 4. Single-leg tie fallback to match winner
            if (wName === "" && !has2Legs && sObj.matchWinner) {
              wName = sObj.matchWinner;
            }
          }

          var dispAggA = sObj.agg_A !== "" ? sObj.agg_A : (has2Legs ? String(numAggA !== null ? numAggA : "") : sObj.leg1_A);
          var dispAggB = sObj.agg_B !== "" ? sObj.agg_B : (has2Legs ? String(numAggB !== null ? numAggB : "") : sObj.leg1_B);
          if (dispAggA && dispAggA.indexOf(".0") === dispAggA.length - 2) dispAggA = dispAggA.substring(0, dispAggA.length - 2);
          if (dispAggB && dispAggB.indexOf(".0") === dispAggB.length - 2) dispAggB = dispAggB.substring(0, dispAggB.length - 2);

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
    } else if (isSeriesCompleted && curSeriesWinner === "") {
      var hN = parseFloat(curAggHome);
      var aN = parseFloat(curAggAway);
      if (!isNaN(hN) && !isNaN(aN)) {
        if (hN > aN) curSeriesWinner = (homeTeam && (homeTeam.displayName || homeTeam.name)) || "";
        else if (aN > hN) curSeriesWinner = (awayTeam && (awayTeam.displayName || awayTeam.name)) || "";
      }
      if (curSeriesWinner === "") {
        var sNoteLow = String(curSeriesSummary || seriesNote || "").toLowerCase();
        var hNameLow = String((homeTeam && (homeTeam.displayName || homeTeam.name)) || "").toLowerCase();
        var aNameLow = String((awayTeam && (awayTeam.displayName || awayTeam.name)) || "").toLowerCase();
        var pH = hNameLow !== "" ? sNoteLow.indexOf(hNameLow) : -1;
        var pA = aNameLow !== "" ? sNoteLow.indexOf(aNameLow) : -1;
        var pAdv = sNoteLow.indexOf("advance");
        if (pAdv === -1) pAdv = sNoteLow.indexOf("win");
        if (pAdv !== -1) {
          var dH = (pH !== -1 && pH < pAdv) ? (pAdv - pH) : 999999;
          var dA = (pA !== -1 && pA < pAdv) ? (pAdv - pA) : 999999;
          if (dH < dA && dH < 60) curSeriesWinner = (homeTeam && (homeTeam.displayName || homeTeam.name)) || "";
          else if (dA < dH && dA < 60) curSeriesWinner = (awayTeam && (awayTeam.displayName || awayTeam.name)) || "";
        }
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

