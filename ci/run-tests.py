"""CI must execute runtime tests, rather than quietly skipping missing Qt."""
import sys
import unittest
suite = unittest.defaultTestLoader.discover('tests')
result = unittest.TextTestRunner(verbosity=2).run(suite)
if result.skipped:
    print('Runtime CI may not skip tests:', result.skipped, file=sys.stderr)
sys.exit(0 if result.wasSuccessful() and not result.skipped else 1)
