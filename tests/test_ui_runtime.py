"""Exercise older views with real Qt at narrow widths and larger typography."""
import os
from pathlib import Path
import shutil
import tempfile
import unittest
import importlib.util
spec=importlib.util.spec_from_file_location('futbar_ui_workload',Path(__file__).resolve().parents[1]/'ci/ui_workload.py')
workload=importlib.util.module_from_spec(spec)
spec.loader.exec_module(workload)
run=workload.run
SHELL=Path(os.environ.get('FUTBAR_SHELL_ROOT','/usr/share/omarchy/shell'))

@unittest.skipUnless(shutil.which('quickshell') and os.environ.get('WAYLAND_DISPLAY') and (SHELL/'Ui').is_dir(),'Omarchy Wayland runtime is required')
class LayoutTests(unittest.TestCase):
    def test_narrow_and_large_font_views(self):
        for width,font in ((360,12),(360,18)):
            with self.subTest(width=width,font=font), tempfile.TemporaryDirectory(prefix='futbar-layout-') as output:
                run(output,width,font)
