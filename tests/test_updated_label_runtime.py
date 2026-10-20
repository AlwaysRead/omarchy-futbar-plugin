"""Success timestamps expire after five seconds and reappear on a fresh update."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

@unittest.skipUnless(shutil.which('quickshell'),'Quickshell is required')
class UpdatedLabelTests(unittest.TestCase):
    def test_expiry_and_refresh(self):
        with tempfile.TemporaryDirectory(prefix='futbar-time-') as directory:
            work=Path(directory)
            shutil.copy(ROOT/'qml/components/FutUpdatedLabel.qml',work/'FutUpdatedLabel.qml')
            (work/'Commons').mkdir()
            (work/'Commons/qmldir').write_text('module qs.Commons\nsingleton Style 1.0 Style.qml\n')
            (work/'Commons/Style.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {property var font: ({family:"Sans",caption:12})}\n')
            (work/'shell.qml').write_text('''
import QtQuick
import QtQuick.Window
import Quickshell
ShellRoot {
 Window {visible:true;width:240;height:60;FutUpdatedLabel {id:label}}
 Component.onCompleted: {
  label.updatedAt=Date.now()-6000
  if(label.visible) {console.error("OLD_TIMESTAMP_FAILURE");Qt.quit();return}
  label.updatedAt=Date.now()
  if(!label.visible || label.opacity>0.4) {console.error("TIMESTAMP_STYLE_FAILURE");Qt.quit();return}
 }
 Timer {interval:5200;running:true;onTriggered:{
  if(label.visible){console.error("TIMESTAMP_EXPIRY_FAILURE");Qt.quit();return}
  label.updatedAt=Date.now()
  if(!label.visible){console.error("TIMESTAMP_REFRESH_FAILURE");Qt.quit();return}
  console.log("TIMESTAMP_PASS");Qt.quit()
 }}
}
''')
            result=subprocess.run(['quickshell','--no-color','-p',str(work/'shell.qml')],env={**os.environ,'QT_QPA_PLATFORM':'offscreen'},capture_output=True,text=True,timeout=10)
            output=result.stdout+result.stderr
            self.assertIn('TIMESTAMP_PASS',output,output)
            for error in ('ReferenceError','TypeError','FAILURE','Binding loop'):
                self.assertNotIn(error,output,output)
