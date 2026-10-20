"""Network policy shared by FutBar's data and image subprocesses."""
import json
import math
import os
import resource
import signal
import urllib.parse
import urllib.request

API_HOSTS = frozenset({'site.web.api.espn.com', 'site.api.espn.com', 'sports.core.api.espn.com'})
IMAGE_HOSTS = frozenset({'a.espncdn.com'})


def checked_url(url, hosts=API_HOSTS):
    if not isinstance(url, str) or len(url) > 2048 or any(ord(c) < 33 or ord(c) > 126 for c in url):
        raise ValueError('Invalid URL')
    parsed = urllib.parse.urlsplit(url)
    if (parsed.scheme != 'https' or parsed.hostname not in hosts
            or parsed.port not in (None, 443) or parsed.username is not None
            or parsed.password is not None or parsed.fragment or '\\' in url):
        raise ValueError('Unsupported URL')
    if hosts == API_HOSTS and not parsed.path.startswith(('/apis/', '/v2/sports/soccer/')):
        raise ValueError('Unsupported API path')
    return url


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError('Redirects are disabled')


def fetch_bytes(url, limit, timeout=5, hosts=API_HOSTS):
    checked_url(url, hosts)
    request = urllib.request.Request(url, headers={'Accept-Encoding': 'identity', 'User-Agent': 'FutBar/2.5'})
    # Do not consult proxy environment variables or local curl configuration.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect)
    with opener.open(request, timeout=timeout) as response:
        if response.headers.get('Content-Encoding', 'identity').lower() != 'identity':
            raise ValueError('Compressed responses are disabled')
        length = response.headers.get('Content-Length')
        if length is not None and not 0 <= int(length) <= limit:
            raise ValueError('Response exceeds limit')
        body = response.read(limit + 1)
    if len(body) > limit:
        raise ValueError('Response exceeds limit')
    return body


def constrain_process(seconds):
    """Linux subprocess limits backstop parser, TLS, and scheduling failures."""
    def timed_out(signum, frame):
        try:
            os.write(2, b'FutBar request timed out\n')
        finally:
            os._exit(124)
    signal.signal(signal.SIGALRM, timed_out)
    signal.alarm(seconds)
    resource.setrlimit(resource.RLIMIT_AS, (256 * 1024 * 1024, 256 * 1024 * 1024))
    resource.setrlimit(resource.RLIMIT_CPU, (seconds, seconds))


def parse_json(body):
    """Reject pathological nesting and collections before data reaches QML."""
    data = json.loads(body)
    if not isinstance(data, (dict, list)):
        raise ValueError('Expected JSON object or array')
    pending = [(data, 0)]
    visited = 0
    while pending:
        value, depth = pending.pop()
        visited += 1
        if depth > 64 or visited > 300000:
            raise ValueError('JSON structure exceeds limit')
        if isinstance(value, dict):
            if len(value) > 1024 or any(len(key) > 128 for key in value):
                raise ValueError('JSON object exceeds limit')
            pending.extend((item, depth + 1) for item in value.values())
        elif isinstance(value, list):
            if len(value) > 5000:
                raise ValueError('JSON array exceeds limit')
            pending.extend((item, depth + 1) for item in value)
        elif isinstance(value, float) and not math.isfinite(value):
            raise ValueError('Non-finite JSON number')
        elif isinstance(value, str) and len(value) > 65536:
            raise ValueError('JSON string exceeds limit')
    return data
