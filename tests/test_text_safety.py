"""Provider season captions must stay plain text in the actual Qt Text sink."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'), 'Quickshell is required')
class TextSafetyTests(unittest.TestCase):
    def test_provider_season_caption_is_plain_text(self):
        source = (ROOT / 'qml/views/FutProfileView.qml').read_text()
        block = re.search(r'Text\s*\{[^{}]*text: playerHistory\.seasonLabel[^{}]*\}', source).group()
        # Exercise the production Text object; stub only the surrounding theme.
        block = block.replace('Text {', 'Text { id: caption;', 1).replace('Style.font.caption', '12')
        shell = '''
import QtQuick
import Quickshell
ShellRoot {
  id: root
  property color contentForeground: "white"
  property string contentFontFamily: "sans-serif"
  property var playerHistory: ({seasonLabel: '<b>Season</b><img src="https://example.invalid/image">'})
  Item {
    width: 360; height: 40
    %s
  }
  Timer {
    interval: 20; running: true
    onTriggered: {
      if (caption.textFormat === Text.PlainText && caption.text === root.playerHistory.seasonLabel) console.log("PLAIN_TEXT_PASS")
      else console.error("PLAIN_TEXT_FAILED")
      Qt.quit()
    }
  }
}
''' % block
        with tempfile.TemporaryDirectory(prefix='futbar-text-') as directory:
            config = Path(directory) / 'shell.qml'
            config.write_text(shell)
            result = subprocess.run(['quickshell', '--no-color', '-p', str(config)],
                                    env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen'},
                                    capture_output=True, text=True, timeout=10)
        output = result.stdout + result.stderr
        self.assertIn('PLAIN_TEXT_PASS', output, output)
        self.assertNotIn('PLAIN_TEXT_FAILED', output, output)
