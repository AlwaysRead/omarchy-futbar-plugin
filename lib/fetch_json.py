"""Fetch bounded ESPN responses; stdout retains the scoreboard concatenation format."""
import sys
import socket
import urllib.error

from http_client import constrain_process, checked_url, fetch_bytes, parse_json


def main(args):
    timeout, limit = int(args[0]), int(args[1])
    urls = args[2:]
    if not (1 <= timeout <= 30 and 1 <= limit <= 8 * 1024 * 1024 and 1 <= len(urls) <= 64):
        raise ValueError('Invalid request limits')
    for url in urls:
        checked_url(url)
    constrain_process(timeout)
    # Bound the entire batch, not just each URL. No partial response on failure.
    parts = []
    remaining = limit
    for url in urls:
        data = fetch_bytes(url, remaining, timeout=min(5, timeout))
        parse_json(data)
        remaining -= len(data)
        parts.append(data)
    sys.stdout.buffer.write(b''.join(parts))


def error_category(error):
    if isinstance(error, urllib.error.HTTPError):
        if error.code in (404, 410):
            return 'not_found'
        return 'rate_limited' if error.code == 429 else 'http_error'
    if isinstance(error, (TimeoutError, socket.timeout)):
        return 'timeout'
    if 'FutBar busy:' in str(error):
        return 'busy'
    if isinstance(error, urllib.error.URLError):
        return 'timeout' if isinstance(error.reason, (TimeoutError, socket.timeout)) else 'offline'
    if isinstance(error, (ValueError, UnicodeError, RecursionError)):
        return 'invalid_data'
    return 'request_failed'


if __name__ == '__main__':
    try:
        main(sys.argv[1:])
    except Exception as error:
        print('FutBar ' + error_category(error), file=sys.stderr)
        sys.exit(1)
