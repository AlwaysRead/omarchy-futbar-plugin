"""Load the packaged QML entry point against the installed Omarchy shell."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHELL = Path('/usr/share/omarchy/shell')


@unittest.skipUnless(shutil.which('quickshell') and os.environ.get('WAYLAND_DISPLAY')
                     and (SHELL / 'Ui').is_dir(), 'An Omarchy Wayland session is required')
class PluginLoadingTests(unittest.TestCase):
    def test_widget_and_panel_load_from_packaged_directories(self):
        with tempfile.TemporaryDirectory(prefix='futbar-plugin-test-') as directory:
            work = Path(directory)
            plugin = work / 'plugin'
            shutil.copytree(ROOT / 'qml', plugin / 'qml')
            shutil.copytree(ROOT / 'lib', plugin / 'lib', ignore=shutil.ignore_patterns('__pycache__'))
            for name in ('Commons', 'Ui', 'services'):
                (work / name).symlink_to(SHELL / name, target_is_directory=True)
            # Keep favorite state isolated without altering the user's HOME or desktop.
            for relative in ('qml/FutBar.qml', 'qml/panels/FutBarPanel.qml'):
                path = plugin / relative
                path.write_text(path.read_text().replace(
                    'Quickshell.env("HOME") + "/.local/state/omarchy/futbar.json"',
                    json.dumps(str(work / 'favorite.json'))))
            entry = json.loads((ROOT / 'manifest.json').read_text())['entryPoints']['barWidget']
            (work / 'shell.qml').write_text('''
import QtQuick
import Quickshell
import "plugin/qml" as Fut
import "plugin/qml/panels" as Panels
ShellRoot {
  Loader { id: widget; source: "plugin/ENTRY" }
  Loader { id: panel; sourceComponent: Panels.FutBarPanel { manageIpc: false } }
  Timer {
    running: true; interval: 1500
    onTriggered: {
      if (widget.status === Loader.Ready && panel.status === Loader.Ready)
        console.log("PLUGIN_LOAD_PASS")
      else console.error("PLUGIN_LOAD_FAILED", widget.status, panel.status)
      Qt.quit()
    }
  }
}
'''.replace('ENTRY', entry))
            result = subprocess.run(['quickshell', '--no-color', '-p', str(work / 'shell.qml')],
                                    env={**os.environ, 'QT_QPA_PLATFORM': 'wayland'},
                                    capture_output=True, text=True, timeout=20)
            output = result.stdout + result.stderr
            self.assertIn('PLUGIN_LOAD_PASS', output, output)
            for error in ('ReferenceError', 'TypeError', 'is not a type', 'unavailable', 'Failed to load'):
                self.assertNotIn(error, output, output)


if __name__ == '__main__':
    unittest.main()
