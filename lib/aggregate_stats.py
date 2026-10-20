"""Bounded career/club aggregation; remote values are data, never Python source."""
import concurrent.futures
import json
import math
import re
import sys

from http_client import constrain_process, checked_url, fetch_bytes, parse_json

MAX_URLS = 128


def fetch_stats(url):
    try:
        data = parse_json(fetch_bytes(url, 1024 * 1024, timeout=5))
        stats = {}
        for category in data.get('splits', {}).get('categories', [])[:64]:
            for stat in category.get('stats', [])[:256]:
                name = stat.get('name')
                value = stat.get('displayValue') if stat.get('displayValue') is not None else stat.get('value')
                if (not isinstance(name, str) or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,63}', name)
                        or name in ('constructor', 'prototype')):
                    continue
                if not isinstance(value, (str, int, float)) or len(str(value)) > 64:
                    continue
                try:
                    number = float(str(value).replace(',', ''))
                except ValueError:
                    continue
                if math.isfinite(number) and abs(number) <= 1e12:
                    stats[name] = (str(value), number)
        return stats
    except (ValueError, TypeError, KeyError, AttributeError, OSError):
        return {}


def aggregate(mode, urls):
    if mode not in ('club', 'career') or not isinstance(urls, list) or not 0 < len(urls) <= MAX_URLS:
        raise ValueError('Invalid statistics request')
    urls = list(dict.fromkeys(checked_url(url) for url in urls))
    sums, cached = {}, {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        for url, stats in zip(urls, executor.map(fetch_stats, urls)):
            if mode == 'club' and stats:
                cached[url] = {name: value for name, (value, _) in stats.items()}
            for name, (_, number) in stats.items():
                if mode == 'career':
                    included = name in ('goalAssists', 'appearances', 'totalGoals')
                else:
                    included = not any(part in name.lower() for part in ('avg', 'time', 'pct'))
                if included:
                    sums[name] = sums.get(name, 0) + number
    if mode == 'career':
        return sums
    out = {name: str(round(number)) for name, number in sums.items()}
    if sums.get('totalPasses', 0) > 0 and 'accuratePasses' in sums:
        out['passPct'] = str(round(sums['accuratePasses'] / sums['totalPasses'] * 100)) + '%'
    return {'stats': out, 'cached': cached}


if __name__ == '__main__':
    constrain_process(30)
    try:
        if len(sys.argv[2]) > 131072:
            raise ValueError('Statistics request exceeds limit')
        print(json.dumps(aggregate(sys.argv[1], json.loads(sys.argv[2])), allow_nan=False))
    except Exception:
        print("FutBar statistics request failed", file=sys.stderr)
        sys.exit(1)
