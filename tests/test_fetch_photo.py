import shutil
import struct
import subprocess
import unittest
from unittest.mock import patch

from test_fetch_image import png
import fetch_photo as photo


class PhotoTests(unittest.TestCase):
    def test_reject_other_formats_and_bad_jpeg(self):
        for data in [b'<svg/>', b'GIF89a', b'\xff\xd8\xff\xe0\xff\xff\xff\xd9', b'x' * (photo.MAX_BYTES + 1)]:
            with self.subTest(data=data[:8]), self.assertRaises(ValueError):
                photo.convert_photo(data)

    def test_dimensions_rejected_before_decoder(self):
        for width, height in [(0, 1), (5000, 1), (4096, 4096)]:
            data = b'\xff\xd8\xff\xc0' + struct.pack('>HBHHB', 8, 8, height, width, 3) + b'\xff\xd9'
            with patch('subprocess.run') as decoder, self.assertRaises(ValueError):
                photo.convert_photo(data)
            decoder.assert_not_called()

    def test_png_uses_existing_validation(self):
        self.assertEqual(photo.convert_photo(png()), png())
        with self.assertRaises(ValueError):
            photo.convert_photo(png() + b'invalid')

    @unittest.skipUnless(shutil.which('magick'), 'ImageMagick is required for JPEG conversion')
    def test_jpeg_decoded_resized_and_reencoded(self):
        original = subprocess.run(['magick', '-size', '1296x729', 'xc:#345678', '-set', 'comment', 'secret metadata', 'jpeg:-'],
                                  capture_output=True, check=True, timeout=5).stdout
        output = photo.convert_photo(original)
        self.assertEqual(struct.unpack('>II', output[16:24]), (512, 288))
        self.assertNotIn(b'secret metadata', output)
        self.assertEqual(photo.validate_png(output), output)

    @unittest.skipUnless(shutil.which('magick'), 'ImageMagick is required for JPEG conversion')
    def test_truncated_jpeg_rejected(self):
        original = subprocess.run(['magick', '-size', '16x16', 'xc:red', 'jpeg:-'],
                                  capture_output=True, check=True, timeout=5).stdout
        with self.assertRaises(ValueError):
            photo.convert_photo(original[:-2])
