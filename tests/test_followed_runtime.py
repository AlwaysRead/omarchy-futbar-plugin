"""Exercise followed schedules, persistent reminders and lineup transitions in Qt."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell is required')
class FollowedRuntimeTests(unittest.TestCase):
    def test_followed_pipeline_reminder_dedup_and_lineup_transition(self):
        with tempfile.TemporaryDirectory(prefix='futbar-followed-test-') as directory:
            work = Path(directory)
            shutil.copytree(ROOT / 'qml', work / 'qml')
            (work / 'lib').mkdir()
            future = time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime(time.time()+15*60))
            event = {'id':'123','date':future,'league':{'slug':'esp.1','name':'La Liga'},'competitions':[{
                'timeValid':True,'status':{'type':{'state':'pre','name':'STATUS_SCHEDULED','shortDetail':'Scheduled'}},
                'competitors':[{'homeAway':'home','team':{'id':'83','displayName':'Barcelona'}},
                               {'homeAway':'away','team':{'id':'86','displayName':'Real Madrid'}}]}]}
            (work / 'lib/fetch_json.py').write_text('''
import json,pathlib,sys
url=sys.argv[-1]
if '/summary?' in url:
 marker=pathlib.Path(__file__).with_name('lineup-seen')
 ready=marker.exists()
 marker.write_text('1')
 print(json.dumps({'rosters':[{'roster':[{'starter':True}]*11 if ready else []}]*2}))
else:
 print(json.dumps({'events':[EVENT,EVENT]}))
'''.replace('EVENT',repr(event)))
            (work / 'shell.qml').write_text('''
import QtQuick
import Quickshell
import "qml/controllers"
ShellRoot {
 id: test
 property int ticks: 0
 property int reminders: 0
 property int lineups: 0
 property int phase: 0
 property var reloaded: null
 Component { id: reloadComponent; FutAlertController { onNotification: test.reminders++ } }
 FutFollowedMatches {
   id: followed; active: true
   tabs: [{teamId:"83",teamName:"Barcelona",league:"esp.1"}]
 }
 FutAlertController {
   id: alerts; statePath: STATE; enabled: true; reminderMinutes: 15
   matches: followed.matches; tabs: followed.tabs; sourceUpdatedAt: followed.updatedAt
   onNotification: function(title,body,glyph,ids) { if (title === "Kickoff reminder") test.reminders++ }
 }
 FutLineupAlerts {
   id: lineup; active: followed.updatedAt > 0; matches: followed.matches
   onLineupAvailable: test.lineups++
 }
 Timer {
   interval: 50; running: true; repeat: true
   onTriggered: {
     test.ticks++
     if (test.ticks > 180) { console.error("FOLLOWED_TIMEOUT",test.phase,followed.error,test.reminders,test.lineups); Qt.quit() }
     if (test.phase === 0 && followed.updatedAt && test.reminders === 1 && !lineup.loading && Object.keys(lineup.seen).length) {
       if (followed.matches.length !== 1) { console.error("DEDUPE_FAILURE"); Qt.quit(); return }
       alerts.check(); alerts.check()
       if (test.reminders !== 1) { console.error("REMINDER_FAILURE"); Qt.quit(); return }
       lineup.refresh(); test.phase = 1
     } else if (test.phase === 1 && test.lineups === 1 && !lineup.loading) {
       lineup.refresh(); test.phase = 2
     } else if (test.phase === 2 && !lineup.loading) {
       if (test.lineups !== 1) { console.error("LINEUP_DEDUPE_FAILURE"); Qt.quit(); return }
       test.reloaded = reloadComponent.createObject(test,{statePath:STATE,enabled:true,reminderMinutes:15,matches:followed.matches,tabs:followed.tabs,sourceUpdatedAt:followed.updatedAt})
       test.phase = 3
     } else if (test.phase === 3 && test.reloaded && test.reloaded.loaded) {
       test.reloaded.check()
       if (test.reminders !== 1) { console.error("PERSISTENT_REMINDER_FAILURE"); Qt.quit(); return }
       console.log("FOLLOWED_PASS"); Qt.quit()
     }
   }
 }
}
'''.replace('STATE',json.dumps(str(work/'alerts.json'))))
            result=subprocess.run(['quickshell','--no-color','-p',str(work/'shell.qml')],
                env={**os.environ,'QT_QPA_PLATFORM':'offscreen'},capture_output=True,text=True,timeout=15)
            output=result.stdout+result.stderr
            self.assertIn('FOLLOWED_PASS',output,output)
            for failure in ('FAILURE','ReferenceError','TypeError','Binding loop'):
                self.assertNotIn(failure,output,output)
            state=json.loads((work/'alerts.json').read_text())
            self.assertEqual(len(state['sent']),1)
