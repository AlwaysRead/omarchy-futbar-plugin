"""A small, redacted dependency report; no paths, environment, or user data."""
import json
import shutil
import sys


def report():
    return {'python': '.'.join(map(str, sys.version_info[:3])),
            'dependencies': {name: shutil.which(name) is not None
                             for name in ('python3', 'magick', 'notify-send', 'wl-copy')}}


if __name__ == '__main__':
    print(json.dumps(report()))
