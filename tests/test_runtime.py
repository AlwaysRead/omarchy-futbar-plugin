"""Exercise the real Qt 6 component with deterministic, local image responses."""
import base64
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_fetch_image import png

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell is not installed')
class RuntimeTests(unittest.TestCase):
    def test_image_queue_cancellation_and_cleanup(self):
        with tempfile.TemporaryDirectory(prefix='futbar-image-test-') as directory:
            work = Path(directory)
            for name in ('FutRemoteImage.qml', 'FutImageCache.js', 'FutNetwork.js'):
                shutil.copy(ROOT / name, work / name)
            (work / 'lib').mkdir()
            data = 'data:image/png;base64,' + base64.b64encode(png()).decode()
            (work / 'lib' / 'fetch_image.py').write_text(
                'import sys, time\ntime.sleep(1 if "slow" in sys.argv[1] else .05)\nprint(' + repr(data) + ')\n')
            (work / 'shell.qml').write_text('''
import QtQuick
import Quickshell
import "."
import "FutImageCache.js" as Cache
ShellRoot {
  id: test
  property var images: []
  property var cancelled: null
  property var destroyed: null
  property int peak: 0
  property int ticks: 0
  Item { id: container }
  Component.onCompleted: {
    var component = Qt.createComponent("FutRemoteImage.qml")
    if (component.status !== Component.Ready) { console.error(component.errorString()); Qt.quit(); return }
    cancelled = component.createObject(container, {remoteSource: "https://a.espncdn.com/slow-cancel"})
    destroyed = component.createObject(container, {remoteSource: "https://a.espncdn.com/slow-destroy"})
    for (var i = 0; i < 12; i++) images.push(component.createObject(container, {remoteSource: "https://a.espncdn.com/" + i}))
  }
  Timer { interval: 250; running: true; onTriggered: { test.cancelled.remoteSource = "https://a.espncdn.com/replacement"; test.destroyed.destroy() } }
  Timer {
    interval: 20; repeat: true; running: true
    onTriggered: {
      test.ticks++
      test.peak = Math.max(test.peak, Cache.active)
      if (Cache.active > 4) { console.error("CONCURRENCY_FAILED"); Qt.quit(); return }
      var ready = test.cancelled && test.cancelled.status === Image.Ready
      for (var i = 0; i < test.images.length; i++) ready = ready && test.images[i].status === Image.Ready
      if (test.ticks > 40 && ready && Cache.active === 0) {
        if (Cache.lookup("https://a.espncdn.com/slow-cancel") !== undefined) { console.error("CANCELLED_RESULT_CACHED"); Qt.quit(); return }
        console.log("RUNTIME_PASS", test.peak, test.images.length)
        Qt.quit()
      }
      if (test.ticks > 250) { console.error("RUNTIME_TIMEOUT", Cache.active); Qt.quit() }
    }
  }
}
''')
            result = subprocess.run(['quickshell', '--no-color', '-p', str(work / 'shell.qml')],
                                    env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen'},
                                    capture_output=True, text=True, timeout=15)
            output = result.stdout + result.stderr
            self.assertIn('RUNTIME_PASS', output, output)
            self.assertNotIn('ReferenceError', output, output)
            self.assertNotIn('TypeError', output, output)


if __name__ == '__main__':
    unittest.main()
