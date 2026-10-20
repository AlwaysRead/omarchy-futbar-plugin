"""Convert a bounded ESPN news photo to a small, metadata-free PNG out of process."""
import base64
import os
import math
import resource
import struct
import subprocess
import sys
import tempfile
import zlib
import urllib.parse

from fetch_image import MAX_BYTES, checked_url, validate_png
from http_client import IMAGE_HOSTS, constrain_process, fetch_bytes


def jpeg_dimensions(data):
    if len(data) > MAX_BYTES or not data.startswith(b'\xff\xd8') or not data.endswith(b'\xff\xd9'):
        raise ValueError('Unsupported JPEG')
    offset = 2
    while offset + 4 <= len(data):
        if data[offset] != 255:
            raise ValueError('Invalid JPEG marker')
        while offset < len(data) and data[offset] == 255:
            offset += 1
        if offset >= len(data):
            break
        marker = data[offset]
        offset += 1
        if marker in (0, 0xd8, 0xd9, 0xda) or 0xd0 <= marker <= 0xd7:
            break
        size = int.from_bytes(data[offset:offset + 2], 'big')
        if size < 2 or offset + size > len(data):
            raise ValueError('Invalid JPEG segment')
        if marker in (0xc0, 0xc1, 0xc2):
            if size < 8 or data[offset + 2] != 8:
                raise ValueError('Unsupported JPEG precision')
            height, width = struct.unpack('>HH', data[offset + 3:offset + 7])
            if not (0 < width <= 4096 and 0 < height <= 4096 and width * height <= 8000000):
                raise ValueError('Photo dimensions exceed limit')
            return width, height
        offset += size
    raise ValueError('Missing JPEG dimensions')


def png_chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


def convert_photo(data):
    if data.startswith(b'\x89PNG'):
        return validate_png(data)
    width, height = jpeg_dimensions(data)
    scale = min(1, 512 / max(width, height), math.sqrt(160000 / (width * height)))
    width, height = max(1, int(width * scale)), max(1, int(height * scale))
    expected = width * height * 3

    def limits():
        resource.setrlimit(resource.RLIMIT_AS, (256 * 1024 * 1024,) * 2)
        resource.setrlimit(resource.RLIMIT_CPU, (4, 4))
        resource.setrlimit(resource.RLIMIT_FSIZE, (expected, expected))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

    # Explicit decoder and stdin prevent a remote name from selecting a URL,
    # file, SVG delegate or command. Raw RGB output cannot carry image metadata.
    command = ['magick', '-limit', 'thread', '1', '-limit', 'memory', '64MiB',
               '-limit', 'map', '0', '-limit', 'disk', '0', 'jpeg:-', '-strip',
               '-colorspace', 'sRGB', '-alpha', 'off', '-resize', f'{width}x{height}!',
               '-depth', '8', 'rgb:-']
    with tempfile.TemporaryFile() as output:
        subprocess.run(command, input=data, stdout=output, stderr=subprocess.DEVNULL,
                       timeout=5, check=True, preexec_fn=limits,
                       env={'PATH': os.defpath, 'OMP_NUM_THREADS': '1', 'MAGICK_THREAD_LIMIT': '1'})
        output.seek(0)
        pixels = output.read(expected + 1)
    if len(pixels) != expected:
        raise ValueError('Unexpected decoded photo size')
    rows = b''.join(b'\0' + pixels[i:i + width * 3] for i in range(0, expected, width * 3))
    png = (b'\x89PNG\r\n\x1a\n' + png_chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
           + png_chunk(b'IDAT', zlib.compress(rows)) + png_chunk(b'IEND', b''))
    return validate_png(png)


def fetch(url):
    checked_url(url)
    parsed = urllib.parse.urlsplit(url)
    if parsed.path.startswith('/photo/'):
        # Request a thumbnail from the same allowed CDN; still enforce all local
        # byte/dimension limits in case the CDN ignores the resize parameters.
        url = 'https://a.espncdn.com/combiner/i?' + urllib.parse.urlencode({
            'img': parsed.path, 'w': 512, 'h': 288, 'scale': 'crop', 'cquality': 80})
    photo = fetch_bytes(url, MAX_BYTES, hosts=IMAGE_HOSTS)
    return 'data:image/png;base64,' + base64.b64encode(convert_photo(photo)).decode('ascii')


if __name__ == '__main__':
    constrain_process(10)
    try:
        print(fetch(sys.argv[1]))
    except Exception:
        sys.exit(1)
