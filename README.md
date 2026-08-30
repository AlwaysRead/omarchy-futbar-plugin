# FutBar — Football Widget for Omarchy

![Omarchy Plugin](https://img.shields.io/badge/Omarchy-Plugin-blue)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version: 2.1.2](https://img.shields.io/badge/Version-2.1.2-green.svg)](manifest.json)

**FutBar** is a live football companion and match center engineered for Omarchy. Track live fixtures, tactical pitch formations with athlete kits, minute-by-minute match timelines, head-to-head records, league standings, player leaderboards, and real-time desktop event notifications seamlessly from your top bar. Powered directly by ESPN's public endpoints with zero API costs, no authentication keys, and no account setup required.

![FutBar Preview](preview.png)

---

## Screenshots

| Club Overview | Tactical Pitch & Lineups |
| :---: | :---: |
| <img src="assets/Club%20Overview.png" width="400" alt="Club Overview"> | <img src="assets/Tactical%20Lineups.png" width="400" alt="Tactical Pitch and Lineups"> |

| Match Statistics & Leaders | League Matchweek Fixtures |
| :---: | :---: |
| <img src="assets/Match%20Statistics.png" width="400" alt="Match Statistics and Leaders"> | <img src="assets/League%20Fixtures.png" width="400" alt="League Matchweek Fixtures"> |

| Player Stats & Leaderboards | Searchable Club Picker |
| :---: | :---: |
| <img src="assets/League%20Stats.png" width="400" alt="Player Stats and Leaderboards"> | <img src="assets/Club%20Picker.png" width="400" alt="Searchable Club Picker"> |

---

## Features

- **Top Bar Integration**: Minimalist soccer icon with live match state indicators, pulse animations during updates, and rich tooltip summaries on hover.
- **Comprehensive Match Center**: Live match scorecard, match status (pre-match, live, half-time, extra-time, penalties, full-time), goal scorers, and series notes.
- **Tactical Pitch & Lineups**: Full tactical pitch view featuring starting XI formations, athlete jersey kit numbers/graphics, substitutes, and live player ratings.
- **Match Timeline & Events**: Visual minute-by-minute timeline tracking goals, penalties, yellow/red cards, substitutions, and half-time/full-time milestones.
- **Head-to-Head & Team Form**: Detailed past encounter history, win/draw/loss counts, and recent form guide.
- **Live Text Commentary**: Reverse-chronological commentary feed with highlighted key match moments.
- **League Standings & Round Fixtures**: Comprehensive league tables with qualification and relegation zone highlights, plus matchweek round browsing.
- **Player Leaderboards**: Top scorers, assist leaders, and disciplinary card rankings.
- **Live Activity Match Tracking**: Toggle match following to receive instant desktop notifications (`notify-send`) on goals, cards, and period changes.
- **Seamless Club & League Switching**: In-panel search and dropdown picker to switch followed teams or browse across global competitions.

---

## Installation & Setup

### Install Plugin
```bash
omarchy plugin add https://github.com/AlwaysRead/omarchy-futbar-plugin.git --enable
```

### Position on Bar (Optional)
```bash
omarchy bar move devbook.futbar --section right
```

### Set Default Club & League (Optional)
You can choose your favorite team and league directly in the panel UI, or configure via CLI:
```bash
omarchy plugin config devbook.futbar set teamName "Barcelona" league "esp.1"
```

### Remove Plugin
```bash
omarchy plugin remove devbook.futbar
```

---

## Controls & Shortcuts

| Action | Shortcut / Control |
| :--- | :--- |
| **Open / Close Panel** | Click bar icon or configure custom Hyprland keybind |
| **Quick Tooltip** | Hover over bar icon for live scores & kickoff times |
| **Instant Refresh** | Middle-click bar icon |
| **Close Panel** | <kbd>Escape</kbd> |
| **Cycle Panels** | <kbd>Tab</kbd> / <kbd>Shift</kbd> + <kbd>Tab</kbd> |
| **Follow Match** | Click "Follow" button in match card or detail header |

---

## Optional Dependencies

- **`libnotify` (`notify-send`)**: Required for desktop match event notifications (goals, cards, half-time, full-time). Pre-installed on standard Linux desktop distributions (e.g. `libnotify` package).

---

## Popular League Codes

| League | ESPN Code |
| :--- | :--- |
| **Premier League** | `eng.1` |
| **LaLiga** | `esp.1` |
| **Serie A** | `ita.1` |
| **Bundesliga** | `ger.1` |
| **Ligue 1** | `fra.1` |
| **UEFA Champions League** | `uefa.champions` |
| **UEFA Europa League** | `uefa.europa` |
| **Major League Soccer (MLS)** | `usa.1` |
| **Brasileirão** | `bra.1` |
| **Eredivisie** | `ned.1` |
| **Liga Portugal** | `por.1` |

---

## License

This project is licensed under the [MIT License](LICENSE).