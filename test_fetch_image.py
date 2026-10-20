import io
import struct
import unittest
import zlib
from unittest.mock import patch

import fetch_image as image


def chunk(kind, body):
    return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body))


def png(width=1, height=1):
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(b'\0\xff\0\0\xff')) + chunk(b'IEND', b''))


class FetchTests(unittest.TestCase):
    def test_valid_png(self):
        self.assertEqual(image.validate_png(png()), png())

    def test_reject_dimensions(self):
        for width, height in [(0, 1), (1, 0), (1025, 1), (1, 1025), (2**31, 2**31)]:
            with self.subTest(size=(width, height)), self.assertRaises(ValueError):
                image.validate_png(png(width, height))

    def test_reject_bad_png(self):
        for data in [b'<svg/>', png()[:-1], png() + b'x', png()[:33] + chunk(b'acTL', b'12345678') + png()[33:], b'x' * (image.MAX_BYTES + 1)]:
            with self.subTest(length=len(data)), self.assertRaises(ValueError):
                image.validate_png(data)

    def test_reject_bad_checksum(self):
        data = bytearray(png())
        data[29] ^= 1
        with self.assertRaises(ValueError):
            image.validate_png(bytes(data))

    def test_url_allowlist(self):
        image.checked_url('https://a.espncdn.com/i/teamlogos/soccer/500/83.png')
        for url in ['http://a.espncdn.com/x', 'file:///tmp/x', 'https://evil.test/x',
                    'https://a.espncdn.com.evil.test/x', 'https://a.espncdn.com@evil.test/x',
                    'https://user@a.espncdn.com/x', 'https://a.espncdn.com:444/x']:
            with self.subTest(url=url), self.assertRaises(ValueError):
                image.checked_url(url)

    def test_redirect_rejected(self):
        with self.assertRaises(ValueError):
            image.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://evil.test/')

    def run_response(self, body, headers):
        response = io.BytesIO(body)
        response.headers = headers
        with patch('urllib.request.OpenerDirector.open', return_value=response):
            return image.fetch('https://a.espncdn.com/test.png')

    def test_reject_content_length(self):
        with self.assertRaises(ValueError):
            self.run_response(png(), {'Content-Length': str(image.MAX_BYTES + 1)})

    def test_reject_oversized_without_length(self):
        with self.assertRaises(ValueError):
            self.run_response(png() + b'x' * image.MAX_BYTES, {})

    def test_reject_lying_content_length(self):
        with self.assertRaises(ValueError):
            self.run_response(png() + b'x' * image.MAX_BYTES, {'Content-Length': '1'})

    def test_data_url(self):
        self.assertTrue(self.run_response(png(), {}).startswith('data:image/png;base64,'))


if __name__ == '__main__':
    unittest.main()
