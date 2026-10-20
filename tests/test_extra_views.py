"""Render the new views with deterministic data and exercise spoiler transitions."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHELL = Path('/usr/share/omarchy/shell')


@unittest.skipUnless(shutil.which('quickshell') and (SHELL / 'Ui').is_dir(),
                     'Quickshell and Omarchy UI components are required')
class ExtraViewTests(unittest.TestCase):
    def test_news_filter_game_log_and_spoiler_controls(self):
        with tempfile.TemporaryDirectory(prefix='futbar-views-test-') as directory:
            work = Path(directory)
            shutil.copytree(ROOT / 'qml', work / 'qml')
            for name in ('Commons', 'Ui', 'services'):
                (work / name).symlink_to(SHELL / name, target_is_directory=True)
            (work / 'lib').mkdir()
            fixture = {
                'articles': [{'headline': '<b>Plain text headline</b>', 'published': '2026-10-20',
                              'links': {'web': {'href': 'https://www.espn.com/soccer/story/_/id/1'}},
                              'categories': [{'type': 'team', 'teamId': 364}]}],
                'names': ['totalGoals'], 'labels': ['G'],
                'events': {'123': {'gameDate': '2026-10-20', 'opponent': {'displayName': 'Opponent'}}},
                'seasonTypes': [{'displayName': 'League', 'categories': [
                    {'events': [{'eventId': '123', 'stats': ['0']}]}]}],
            }
            (work / 'lib/fetch_json.py').write_text('print(' + repr(json.dumps(fixture)) + ')\n')
            (work / 'shell.qml').write_text('''
import QtQuick
import QtQuick.Window
import Quickshell
import "qml/views"
ShellRoot {
  id: test
  property int phase: 0
  property int ticks: 0
  QtObject {
    id: context
    property string league: "eng.1"
    property bool opened: true
    property bool antiSpoiler: true
    property color contentForeground: "#eeeeee"
    function safeIdentifier(s) { return s }
    function allFollowedTabs() { return [{teamId: "1"}] }
  }
  Window {
    visible: true; width: 440; height: 700
    Column {
      width: parent.width
      FutNewsView { id: news; root: context }
      FutGameLogView { id: log; root: context; athleteId: "173896" }
    }
  }
  Timer {
    interval: 50; repeat: true; running: true
    onTriggered: {
      test.ticks++
      if (test.ticks > 100) { console.error("VIEW_TIMEOUT", test.phase); Qt.quit() }
      if (test.phase === 0) {
        if (!news.hiddenSpoilers || news.articles.length) { console.error("SPOILER_FAILURE"); Qt.quit(); return }
        news.revealed = true
        test.phase = 1
      } else if (test.phase === 1 && news.articles.length === 1) {
        news.followedOnly = true
        test.phase = 2
      } else if (test.phase === 2) {
        if (news.articles.length) { console.error("FILTER_FAILURE"); Qt.quit(); return }
        context.antiSpoiler = false
        log.expanded = true
        test.phase = 3
      } else if (test.phase === 3 && log.rows.length === 1) {
        if (log.rows[0].stats[0].value !== "0") { console.error("LOG_FAILURE"); Qt.quit(); return }
        context.antiSpoiler = true
        test.phase = 4
      } else if (test.phase === 4) {
        if (!news.hiddenSpoilers || !log.hiddenSpoilers) { console.error("SPOILER_RESET_FAILURE"); Qt.quit(); return }
        console.log("VIEWS_PASS")
        Qt.quit()
      }
    }
  }
}
''')
            result = subprocess.run(['quickshell', '--no-color', '-p', str(work / 'shell.qml')],
                                    env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen'},
                                    capture_output=True, text=True, timeout=15)
            output = result.stdout + result.stderr
            self.assertIn('VIEWS_PASS', output, output)
            for error in ('ReferenceError', 'TypeError', 'FAILURE', 'Binding loop'):
                self.assertNotIn(error, output, output)


if __name__ == '__main__':
    unittest.main()
