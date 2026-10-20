"""Exercise cancellation and last-known-good handling in the real Qt runtime."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell is not installed')
class ApiRuntimeTests(unittest.TestCase):
    def test_context_cancellation_and_failed_refresh(self):
        with tempfile.TemporaryDirectory(prefix='futbar-api-test-') as directory:
            work = Path(directory)
            for relative in ('qml/controllers/FutApiRequest.qml', 'qml/services/FutNetwork.js'):
                dest = work / relative
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(ROOT / relative, dest)
            (work / 'lib').mkdir()
            (work / 'lib/fetch_json.py').write_text('''
import json, pathlib, sys, time
url = sys.argv[-1]
if url.endswith('slow'):
    time.sleep(1)
else:
    time.sleep(.05)
marker = pathlib.Path(__file__).with_name('requested')
if url.endswith('new') and marker.exists():
    print('FutBar rate_limited', file=sys.stderr)
    sys.exit(1)
if url.endswith('new'):
    marker.write_text('1')
print(json.dumps({'articles': [], 'context': url}))
''')
            (work / 'shell.qml').write_text('''
import QtQuick
import Quickshell
import "qml/controllers"
ShellRoot {
  id: test
  property int phase: 0
  property int ticks: 0
  FutApiRequest { id: api; active: true; responseKind: "news"; url: "https://site.api.espn.com/slow" }
  Timer { interval: 200; running: true; onTriggered: api.url = "https://site.api.espn.com/new" }
  Timer {
    interval: 20; repeat: true; running: true
    onTriggered: {
      test.ticks++
      if (test.ticks > 250) { console.error("API_TIMEOUT", test.phase, api.error); Qt.quit() }
      if (api.result && api.result.context.endsWith("slow")) { console.error("STALE_CONTEXT"); Qt.quit() }
      if (test.phase === 0 && api.result && api.result.context.endsWith("new")) {
        test.phase = 1
        api.refresh()
      } else if (test.phase === 1 && api.error) {
        if (!api.stale || !api.result.context.endsWith("new") || api.error.indexOf("rate limiting") < 0 || api.retryAt <= Date.now()) {
          console.error("STALE_DATA_FAILED"); Qt.quit(); return
        }
        api.active = false
        api.url = "https://site.api.espn.com/hidden"
        test.phase = 2
      } else if (test.phase === 2 && !api.loading && !api.result) {
        console.log("API_RUNTIME_PASS")
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
            self.assertIn('API_RUNTIME_PASS', output, output)
            for error in ('ReferenceError', 'TypeError', 'STALE_CONTEXT', 'STALE_DATA_FAILED'):
                self.assertNotIn(error, output, output)


if __name__ == '__main__':
    unittest.main()
