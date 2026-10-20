"""Cancelled legacy processes must not apply output to a newer selection."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'),'Quickshell is required')
class ContextProcessTests(unittest.TestCase):
    def test_context_change_cancels_and_next_context_can_finish(self):
        with tempfile.TemporaryDirectory(prefix='futbar-context-test-') as directory:
            work=Path(directory)
            (work/'qml/components').mkdir(parents=True)
            (work/'qml/services').mkdir()
            shutil.copy(ROOT/'qml/components/FutContextProcess.qml',work/'qml/components/FutContextProcess.qml')
            shutil.copy(ROOT/'qml/services/FutNetwork.js',work/'qml/services/FutNetwork.js')
            (work/'shell.qml').write_text('''
import QtQuick
import Quickshell
import Quickshell.Io
import "qml/components"
ShellRoot {
 id: test
 property string selection: "old"
 property int received: 0
 FutContextProcess {
   id: worker
   requestContext: test.selection
   command: ["python3","-E","-s","-c","import sys,time; time.sleep(.3); print(sys.argv[1])",test.selection]
   running: true
   stdout: StdioCollector {
     onStreamFinished: {
       if (!worker.responseCurrent || !text.trim()) return
       if (text.trim() !== "new") { console.error("OBSOLETE_OUTPUT"); Qt.quit(); return }
       test.received++
     }
   }
 }
 Timer { interval: 50; running: true; onTriggered: { test.selection = "new"; start.restart() } }
 Timer { id: start; interval: 50; onTriggered: worker.running = true }
 Timer { interval: 900; running: true; onTriggered: { if (test.received === 1) console.log("CONTEXT_PASS"); else console.error("CONTEXT_FAILURE",test.received); Qt.quit() } }
}
''')
            result=subprocess.run(['quickshell','--no-color','-p',str(work/'shell.qml')],
                env={**os.environ,'QT_QPA_PLATFORM':'offscreen'},capture_output=True,text=True,timeout=10)
            output=result.stdout+result.stderr
            self.assertIn('CONTEXT_PASS',output,output)
            for failure in ('OBSOLETE_OUTPUT','FAILURE','ReferenceError','TypeError'):
                self.assertNotIn(failure,output,output)
