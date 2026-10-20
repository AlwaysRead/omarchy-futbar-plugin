"""Fetch a bounded ESPN PNG without exposing the shell's decoder to remote URLs."""
import base64
import struct
import sys
import signal
import zlib
import urllib.parse
import urllib.request

MAX_BYTES = 512 * 1024
MAX_DIMENSION = 1024


def checked_url(url):
    parsed = urllib.parse.urlsplit(url)
    if (len(url) > 2048 or parsed.scheme != 'https'
            or parsed.hostname != 'a.espncdn.com' or parsed.port not in (None, 443)
            or parsed.username is not None or parsed.password is not None):
        raise ValueError('Unsupported image URL')
    return url


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError('Image redirects are disabled')


def validate_png(data):
    if len(data) > MAX_BYTES or len(data) < 33 or data[:16] != b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR':
        raise ValueError('Unsupported image')
    width, height = struct.unpack('>II', data[16:24])
    if not (0 < width <= MAX_DIMENSION and 0 < height <= MAX_DIMENSION):
        raise ValueError('Image dimensions exceed limit')
    # Reject animation and malformed chunk boundaries before Qt decodes the PNG.
    offset = 8
    while offset + 12 <= len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + length
        if end > len(data) or kind == b'acTL' or (kind == b'IHDR' and offset != 8):
            raise ValueError('Invalid or animated PNG')
        expected_crc = struct.unpack('>I', data[end - 4:end])[0]
        if zlib.crc32(data[offset + 4:end - 4]) != expected_crc:
            raise ValueError('Invalid PNG checksum')
        if kind == b'IEND':
            if length != 0 or end != len(data):
                raise ValueError('Invalid PNG end')
            return data
        offset = end
    raise ValueError('Incomplete PNG')


def fetch(url):
    request = urllib.request.Request(checked_url(url), headers={'Accept-Encoding': 'identity'})
    with urllib.request.build_opener(NoRedirect).open(request, timeout=5) as response:
        length = response.headers.get('Content-Length')
        if length is not None and (int(length) < 0 or int(length) > MAX_BYTES):
            raise ValueError('Image response exceeds limit')
        data = response.read(MAX_BYTES + 1)
    return 'data:image/png;base64,' + base64.b64encode(validate_png(data)).decode('ascii')


if __name__ == '__main__':
    # Bound total wall time, including slow trickle responses and DNS lookup.
    signal.alarm(10)
    try:
        print(fetch(sys.argv[1]))
    except Exception:
        sys.exit(1)
