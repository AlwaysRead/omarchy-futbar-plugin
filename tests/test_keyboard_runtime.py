"""Real Tab/Return/Space input for legacy clickable rows."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
RUNNER='/usr/lib/qt6/bin/qmltestrunner' if Path('/usr/lib/qt6/bin/qmltestrunner').is_file() else shutil.which('qmltestrunner')

@unittest.skipUnless(Path(RUNNER).is_file(),'Qt Quick Test is required')
class KeyboardTests(unittest.TestCase):
    def test_keyboard_activation_and_focus(self):
        with tempfile.TemporaryDirectory(prefix='futbar-keys-') as directory:
            work=Path(directory)
            shutil.copy(ROOT/'qml/components/FutActionArea.qml',work/'FutActionArea.qml')
            (work/'tst_keyboard.qml').write_text('''
import QtQuick
import QtTest
Item {
 width:300;height:120
 FutActionArea {id:first;width:100;height:40;actionLabel:"Open match";property int presses:0;onActivated:presses++}
 FutActionArea {id:second;y:50;width:100;height:40;actionLabel:"Open player"}
 TestCase {
  name:"LegacyRows";when:windowShown
  function test_activateAndTab() {
   first.forceActiveFocus();verify(first.activeFocus)
   keyClick(Qt.Key_Return);keyClick(Qt.Key_Space);compare(first.presses,2)
   keyClick(Qt.Key_Tab);verify(second.activeFocus)
   keyClick(Qt.Key_Backtab);verify(first.activeFocus)
   second.enabled=false;keyClick(Qt.Key_Tab);verify(!second.activeFocus)
   compare(first.Accessible.name,"Open match")
  }
 }
}
''')
            result=subprocess.run([RUNNER,'-input',str(work),'-platform','offscreen','-o','-,txt'],env={**os.environ,'QT_QUICK_BACKEND':'software','QT_QPA_PLATFORM':'offscreen','QT_QPA_PLATFORMTHEME':'','QT_STYLE_OVERRIDE':'','QT_IM_MODULE':''},capture_output=True,text=True,timeout=10)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
