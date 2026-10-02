"""Reads and sets consumer quota overrides on Quincena's Firebase project.

Uses the Service Usage API with the credentials of `gcloud auth`, so it acts
as whoever is signed in there; that account needs serviceusage.quotas.update
on the project.
"""
import json
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

PROJECT = 'quincena-dlsoft'
BASE = 'https://serviceusage.googleapis.com/v1beta1/'


def _token():
    return subprocess.check_output(
        ['gcloud', 'auth', 'print-access-token']).decode().strip()


def rest(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header('Authorization', f'Bearer {_token()}')
    req.add_header('X-Goog-User-Project', PROJECT)
    req.add_header('Content-Type', 'application/json')
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read() or b'{}')
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b'{}')


def limit_path(service, metric, limit):
    """The resource name of one limit, such as '/min/project/region/user'."""
    m = urllib.parse.quote(f'{service}/{metric}', safe='')
    lim = urllib.parse.quote(limit, safe='')
    return (f'projects/{PROJECT}/services/{service}'
            f'/consumerQuotaMetrics/{m}/limits/{lim}')


def _overrides(service, metric, limit):
    _, b = rest('GET', limit_path(service, metric, limit) + '/consumerOverrides')
    return b.get('overrides', [])


def _wait(op):
    for _ in range(60):
        if op.get('done') or 'name' not in op:
            return op
        time.sleep(2)
        _, op = rest('GET', op['name'])
    return op


def set_override(service, metric, limit, value, dimensions=None):
    """Sets the override for exactly these dimensions, creating it if needed.

    With no dimensions it holds for every bucket that has no override of its
    own: a model or a region with one keeps it.
    """
    dimensions = dimensions or {}
    body = {'overrideValue': str(value), 'dimensions': dimensions}
    for o in _overrides(service, metric, limit):
        if (o.get('dimensions') or {}) == dimensions:
            path = o['name'].split('v1beta1/')[-1]
            status, op = rest(
                'PATCH', f'{path}?force=true&updateMask=overrideValue', body)
            break
    else:
        status, op = rest(
            'POST',
            limit_path(service, metric, limit) + '/consumerOverrides?force=true',
            body)
    if status != 200:
        return f'failed: {op.get("error", {}).get("message", op)}'
    op = _wait(op)
    return op.get('error', {}).get('message') or 'set'


def effective(service, metric, limit):
    """{dimensions: (effective, default)} for every bucket of a limit.

    An effective limit of None is zero: the API leaves zeros out.
    """
    _, b = rest('GET', limit_path(service, metric, limit) + '?view=FULL')
    return {
        json.dumps(bucket.get('dimensions', {}), sort_keys=True):
            (bucket.get('effectiveLimit'), bucket.get('defaultLimit'))
        for bucket in b.get('quotaBuckets', [])
    }
