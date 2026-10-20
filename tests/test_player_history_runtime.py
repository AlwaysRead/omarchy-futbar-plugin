"""Season/competition changes cancel old output; failed refreshes keep the selected history."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

@unittest.skipUnless(shutil.which('quickshell'),'Quickshell is required')
class PlayerHistoryTests(unittest.TestCase):
    def test_filters_and_failed_refresh(self):
        with tempfile.TemporaryDirectory(prefix='futbar-history-') as directory:
            work=Path(directory)
            for relative in ('qml/controllers/FutPlayerHistory.qml','qml/controllers/FutApiRequest.qml','qml/data/FutPlayerHistory.js','qml/services/FutNetwork.js'):
                dest=work/relative;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy(ROOT/relative,dest)
            (work/'lib').mkdir()
            shutil.copy(ROOT/'tests/fixtures/player-gamelog.json',work/'lib/data.json')
            (work/'lib/fetch_json.py').write_text('''
import json,pathlib,sys,time
from urllib.parse import urlsplit,parse_qs
p=pathlib.Path(__file__).parent
query=parse_qs(urlsplit(sys.argv[-1]).query)
season=query['season'][0]
time.sleep(.4 if season=='2026' else .05)
if query.get('league') == ['eng.1']:
 if (p/'requested').exists():
  print('FutBar rate_limited',file=sys.stderr);sys.exit(1)
 (p/'requested').write_text('1')
data=json.loads((p/'data.json').read_text())
for e in data['events'].values():e['leagueName']=season+':'+query.get('league',['default'])[0]
print(json.dumps(data))
''')
            (work/'shell.qml').write_text('''
import QtQuick
import Quickshell
import "qml/controllers"
ShellRoot {
 id: test
 property int phase: 0
 property int ticks: 0
 FutPlayerHistory { id: history; athleteId: "123"; active: true; season: 2026 }
 Timer { interval: 160; running: true; onTriggered: { history.season=2025; history.competition="eng.1" } }
 Timer {
  interval: 20; running: true; repeat: true
  onTriggered: {
   test.ticks++
   if (test.ticks>200) { console.error("HISTORY_TIMEOUT",test.phase,history.error);Qt.quit();return }
   if (history.matches.length && history.matches[0].leagueName !== "2025:eng.1") {console.error("HISTORY_STALE_CONTEXT");Qt.quit();return}
   if (test.phase===0 && history.matches.length===3) {test.phase=1;history.refresh()}
   else if (test.phase===1 && history.error) {
    if (history.matches.length!==3 || history.retryInSeconds===0) {console.error("HISTORY_CACHE_FAILURE");Qt.quit();return}
    history.athleteId="456";test.phase=2
   } else if (test.phase===2 && history.matches.length===0 && history.competition==="") {console.log("HISTORY_PASS");Qt.quit()}
  }
 }
}
''')
            result=subprocess.run(['quickshell','--no-color','-p',str(work/'shell.qml')],env={**os.environ,'QT_QPA_PLATFORM':'offscreen'},capture_output=True,text=True,timeout=10)
            output=result.stdout+result.stderr
            self.assertIn('HISTORY_PASS',output,output)
            for error in ('ReferenceError','TypeError','FAILURE','STALE_CONTEXT','Binding loop'):
                self.assertNotIn(error,output,output)
