"""Fetch a bounded ESPN PNG without exposing the shell's decoder to remote URLs."""
import base64
import struct
import sys
import zlib
from http_client import constrain_process, IMAGE_HOSTS, checked_url as check_url, fetch_bytes


def checked_url(url):
    return check_url(url, IMAGE_HOSTS)

MAX_BYTES = 512 * 1024
MAX_DIMENSION = 1024


def validate_png(data):
    if len(data) > MAX_BYTES or len(data) < 33 or data[:16] != b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR':
        raise ValueError('Unsupported image')
    width, height = struct.unpack('>II', data[16:24])
    if not (0 < width <= MAX_DIMENSION and 0 < height <= MAX_DIMENSION):
        raise ValueError('Image dimensions exceed limit')
    # Reject animation and malformed chunk boundaries before Qt decodes the PNG.
    depth, color, compression, filtering, interlace = data[24:29]
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}
    depths = {0: (1, 2, 4, 8, 16), 2: (8, 16), 3: (1, 2, 4, 8), 4: (8, 16), 6: (8, 16)}
    if color not in depths or depth not in depths[color] or compression or filtering or interlace not in (0, 1):
        raise ValueError('Invalid PNG header')
    bits = channels[color] * depth
    passes = [(0, 0, 1, 1)] if not interlace else [
        (0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4),
        (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2)]
    expected = 0
    for x, y, dx, dy in passes:
        w, h = max(0, (width - x + dx - 1) // dx), max(0, (height - y + dy - 1) // dy)
        if w and h:
            expected += h * (1 + (w * bits + 7) // 8)
    image_data = []
    chunks = [data[:8]]
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
        # Drop text, ICC profiles, EXIF and other ancillary chunks: compressed
        # metadata must not become a second unbounded decompression path in Qt.
        if kind == b'IDAT':
            image_data.append(data[offset + 8:end - 4])
        if kind in (b'IHDR', b'PLTE', b'tRNS', b'IDAT', b'IEND'):
            chunks.append(data[offset:end])
        elif not kind[0] & 32:
            raise ValueError('Unsupported critical PNG chunk')
        if kind == b'IEND':
            if length != 0 or end != len(data):
                raise ValueError('Invalid PNG end')
            decoder = zlib.decompressobj()
            raw = decoder.decompress(b''.join(image_data), expected + 1)
            if len(raw) != expected or not decoder.eof or decoder.unused_data:
                raise ValueError('Invalid or oversized PNG pixel stream')
            return b''.join(chunks)
        offset = end
    raise ValueError('Incomplete PNG')


def fetch(url):
    data = fetch_bytes(checked_url(url), MAX_BYTES, hosts=IMAGE_HOSTS)
    return 'data:image/png;base64,' + base64.b64encode(validate_png(data)).decode('ascii')


if __name__ == '__main__':
    # Bound total wall time, including slow trickle responses and DNS lookup.
    constrain_process(10)
    try:
        print(fetch(sys.argv[1]))
    except Exception:
        sys.exit(1)
