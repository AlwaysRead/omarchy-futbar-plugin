"""Optional missing data is distinct from a network/server failure."""
import sys
from pathlib import Path
import unittest
from urllib.error import HTTPError,URLError
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'lib'))
from fetch_json import error_category

class OptionalDataTests(unittest.TestCase):
    def test_http_categories(self):
        for code, category in ((404,'not_found'),(410,'not_found'),(429,'rate_limited'),(503,'http_error')):
            error = HTTPError('https://site.api.espn.com/',code,'',None,None)
            try:
                self.assertEqual(error_category(error),category)
            finally:
                error.close()
        self.assertEqual(error_category(URLError('offline')),'offline')
