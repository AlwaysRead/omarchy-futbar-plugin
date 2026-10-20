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
            shutil.copy(ROOT/'qml/components/FutWindowFeedback.qml',work/'FutWindowFeedback.qml')
            shutil.copy(ROOT/'qml/components/FutWindowFooter.qml',work/'FutWindowFooter.qml')
            (work/'Commons').mkdir()
            (work/'Commons/qmldir').write_text('module qs.Commons\nsingleton Style 1.0 Style.qml\n')
            (work/'Commons/Style.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {property var font: ({family:"Sans",caption:12});function space(value){return value}}\n')
            (work/'shell.qml').write_text('''
import QtQuick
import QtQuick.Window
import Quickshell
ShellRoot {
 property double startedAt: 0
 QtObject {id:request;property bool loading:false;property string error:"";property double updatedAt:0}
 Window {
  visible:true;width:300;height:120
  Rectangle {id:content;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.bottom:label.top;anchors.bottomMargin:10}
  FutWindowFooter {id:label;requests:[request];anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom}
 }
 Component.onCompleted: {
  startedAt=Date.now()
  request.updatedAt=Date.now()-6000
  if(label.active) {console.error("OLD_TIMESTAMP_FAILURE");Qt.quit();return}
  request.updatedAt=Date.now()
  request.loading=true
  if(label.text!=="Refreshing cached data…"){console.error("REFRESH_FOOTER_FAILURE");Qt.quit();return}
  request.loading=false;request.error="Offline"
  if(label.text.indexOf("Showing cached data")!==0){console.error("CACHE_FOOTER_FAILURE");Qt.quit();return}
  request.error=""
  if(!label.active || label.textOpacity>0.4) {console.error("TIMESTAMP_STYLE_FAILURE");Qt.quit();return}
 }
 Timer {interval:50;running:true;onTriggered:{if(Math.abs(label.y+label.height-120)>0.1 || content.y+content.height+10>label.y){console.error("FOOTER_POSITION_FAILURE");Qt.quit()}}}
 Timer {interval:25;running:true;repeat:true;onTriggered:{
  if(label.active && Date.now()-startedAt<7000)return
  if(label.active){console.error("TIMESTAMP_EXPIRY_FAILURE");Qt.quit();return}
  if(Date.now()-startedAt<4800){console.error("TIMESTAMP_EARLY_EXPIRY_FAILURE");Qt.quit();return}
  request.updatedAt=Date.now()
  if(!label.active){console.error("TIMESTAMP_REFRESH_FAILURE");Qt.quit();return}
  console.log("TIMESTAMP_PASS");Qt.quit()
 }}
}
''')
            result=subprocess.run(['quickshell','--no-color','-p',str(work/'shell.qml')],env={**os.environ,'QT_QPA_PLATFORM':'offscreen'},capture_output=True,text=True,timeout=10)
            output=result.stdout+result.stderr
            self.assertIn('TIMESTAMP_PASS',output,output)
            for error in ('ReferenceError','TypeError','FAILURE','Binding loop'):
                self.assertNotIn(error,output,output)
