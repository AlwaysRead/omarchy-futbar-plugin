import os
import tempfile
import io
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lib'))
import aggregate_stats
import fetch_json
import http_client

URL = 'https://sports.core.api.espn.com/v2/sports/soccer/athletes/1'


class NetworkTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        environment = patch.dict(os.environ, {'XDG_RUNTIME_DIR': directory.name})
        environment.start()
        self.addCleanup(environment.stop)

    def test_api_url_policy(self):
        self.assertEqual(http_client.checked_url(URL), URL)
        for value in [URL.replace('https:', 'http:'), URL.replace('sports.core.api.espn.com', 'evil.test'),
                      'https://sports.core.api.espn.com@evil.test/apis/x',
                      'https://sports.core.api.espn.com:444/apis/x',
                      'https://sports.core.api.espn.com/private', URL + '#fragment',
                      URL + '\n', URL + '\\evil', URL + ' ']:
            with self.subTest(url=value), self.assertRaises(ValueError):
                http_client.checked_url(value)

    def test_json_structure_limits(self):
        self.assertEqual(http_client.parse_json(b'{"events": []}'), {'events': []})
        values = [b'null', b'{broken', b'{"value":NaN}', b'{"value":1e999}', b'[' * 70 + b'0' + b']' * 70,
                  json.dumps(['x'] * 5001).encode(), json.dumps({'x': 'y' * 65537}).encode()]
        for value in values:
            with self.subTest(length=len(value)), self.assertRaises((ValueError, RecursionError)):
                http_client.parse_json(value)

    def test_compressed_response_rejected(self):
        response = io.BytesIO(b'compressed')
        response.headers = {'Content-Encoding': 'gzip'}
        with patch('urllib.request.OpenerDirector.open', return_value=response), self.assertRaises(ValueError):
            http_client.fetch_bytes(URL, 10)

    def test_body_read_is_bounded(self):
        response = io.BytesIO(b'x' * 20)
        response.headers = {}
        with patch.object(response, 'read', wraps=response.read) as read:
            with patch('urllib.request.OpenerDirector.open', return_value=response), self.assertRaises(ValueError):
                http_client.fetch_bytes(URL, 10)
            read.assert_called_once_with(11)

    def test_batch_rejects_excess_urls_before_network(self):
        with patch('fetch_json.fetch_bytes') as fetch, self.assertRaises(ValueError):
            fetch_json.main(['10', '100', *([URL] * 65)])
        fetch.assert_not_called()

    def test_batch_validates_all_urls_before_network(self):
        with patch('fetch_json.fetch_bytes') as fetch, self.assertRaises(ValueError):
            fetch_json.main(['10', '100', URL, 'file:///etc/passwd'])
        fetch.assert_not_called()

    def test_batch_budget_and_concatenated_results(self):
        from types import SimpleNamespace
        output = io.BytesIO()
        with patch('fetch_json.constrain_process'), patch('fetch_json.sys.stdout', SimpleNamespace(buffer=output)):
            with patch('fetch_json.fetch_bytes', side_effect=[b'{"a":1}', b'{"b":2}']) as fetch:
                fetch_json.main(['10', '20', URL, URL])
                self.assertEqual([call.args[1] for call in fetch.call_args_list], [20, 13])
        self.assertEqual(output.getvalue(), b'{"a":1}{"b":2}')

    def test_stats_url_validation(self):
        with patch('aggregate_stats.fetch_bytes') as fetch, self.assertRaises(ValueError):
            aggregate_stats.aggregate('club', ['file:///etc/passwd'])
        fetch.assert_not_called()

    def test_stats_aggregation(self):
        data = json.dumps({'splits': {'categories': [{'stats': [
            {'name': 'totalGoals', 'value': 3}, {'name': 'goalAssists', 'displayValue': '2'},
            {'name': 'passPct', 'displayValue': '85%'},
            {'name': 'appearances', 'value': 7}, {'name': 'badValue', 'value': 'nan'},
            {'name': 'constructor', 'value': 1}
        ]}]}}).encode()
        with patch('aggregate_stats.fetch_bytes', return_value=data):
            self.assertEqual(aggregate_stats.aggregate('career', [URL]),
                             {'totalGoals': 3, 'goalAssists': 2, 'appearances': 7})
            club = aggregate_stats.aggregate('club', [URL])
            self.assertEqual(club['stats']['totalGoals'], '3')
            self.assertNotIn('badValue', club['stats'])


if __name__ == '__main__':
    unittest.main()
