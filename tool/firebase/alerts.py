"""Sets up the alerts that tell Quincena's owner when Gemini use looks wrong.

    python3 tool/firebase/alerts.py admin@example.com

Creates, once, an email channel and three alert policies in Cloud Monitoring:
a burst of questions, requests refused for going over a limit, and a Gemini
quota of the project running out. Alerts only warn: what stops spending is
in caps.py and the spend cap (docs/PRODUCTION.md).
"""
import json
import subprocess
import sys
import urllib.error
import urllib.request

PROJECT = 'quincena-dlsoft'
BASE = f'https://monitoring.googleapis.com/v3/projects/{PROJECT}'
AI_LOGIC = 'firebasevertexai.googleapis.com'
GEMINI = 'generativelanguage.googleapis.com'


def rest(method, path, body=None):
    token = subprocess.check_output(
        ['gcloud', 'auth', 'print-access-token']).decode().strip()
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header('Authorization', f'Bearer {token}')
    req.add_header('X-Goog-User-Project', PROJECT)
    req.add_header('Content-Type', 'application/json')
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read() or b'{}')
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b'{}')


def channel(email):
    _, b = rest('GET', '/notificationChannels')
    for c in b.get('notificationChannels', []):
        if c.get('labels', {}).get('email_address') == email:
            return c['name']
    status, c = rest('POST', '/notificationChannels', {
        'type': 'email',
        'displayName': f'Quincena: {email}',
        'labels': {'email_address': email},
    })
    if status != 200:
        sys.exit(f'Could not create the channel: {c}')
    return c['name']


def requests(service, extra=''):
    return (
        'metric.type="serviceruntime.googleapis.com/api/request_count" '
        'AND resource.type="consumed_api" '
        f'AND resource.label.service="{service}"{extra}'
    )


def threshold(name, metric_filter, value, reducer='REDUCE_SUM'):
    return {
        'displayName': name,
        'conditionThreshold': {
            'filter': metric_filter,
            'aggregations': [{
                'alignmentPeriod': '600s',
                'perSeriesAligner': 'ALIGN_SUM',
                'crossSeriesReducer': reducer,
            }],
            'comparison': 'COMPARISON_GT',
            'thresholdValue': value,
            'duration': '0s',
            'trigger': {'count': 1},
        },
    }


POLICIES = [
    (
        'Gemini: muchas preguntas en poco tiempo',
        threshold('Más de 150 llamadas a Firebase AI Logic en 10 minutos',
                  requests(AI_LOGIC), 150),
        'Una pregunta son dos o tres llamadas: esto son unas 50 preguntas en '
        '10 minutos. Revisa en Firebase > AI Logic quién pregunta, y en '
        'Facturación cuánto lleva el mes.',
    ),
    (
        'Gemini: llamadas rechazadas por un límite',
        threshold('Más de 10 respuestas 429 de Firebase AI Logic en 10 minutos',
                  requests(AI_LOGIC, ' AND metric.label.response_code="429"'),
                  10),
        'Alguien llegó al límite por persona o el proyecto a uno de sus topes '
        '(tool/firebase/caps.py). Las llamadas rechazadas no cuestan.',
    ),
    (
        'Gemini: se agotó una cuota del proyecto',
        {
            'displayName': 'Una cuota de la API de Gemini llegó a su tope',
            'conditionThreshold': {
                'filter': (
                    'metric.type="serviceruntime.googleapis.com/quota/exceeded" '
                    'AND resource.type="consumer_quota" '
                    f'AND resource.label.service="{GEMINI}"'
                ),
                'aggregations': [{
                    'alignmentPeriod': '600s',
                    'perSeriesAligner': 'ALIGN_COUNT_TRUE',
                    'crossSeriesReducer': 'REDUCE_SUM',
                }],
                'comparison': 'COMPARISON_GT',
                'thresholdValue': 0,
                'duration': '0s',
                'trigger': {'count': 1},
            },
        },
        'Uno de los topes diarios o por minuto se cumplió y Gemini dejó de '
        'responder hasta que se renueve. Si es uso real, sube el tope en '
        'tool/firebase/caps.py; si no, revisa de dónde vienen las llamadas.',
    ),
]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    to = channel(sys.argv[1])
    _, b = rest('GET', '/alertPolicies')
    existing = {p['displayName'] for p in b.get('alertPolicies', [])}
    for name, condition, doc in POLICIES:
        if name in existing:
            print(f'{name}: already there')
            continue
        status, p = rest('POST', '/alertPolicies', {
            'displayName': name,
            'combiner': 'OR',
            'conditions': [condition],
            'notificationChannels': [to],
            'documentation': {'content': doc, 'mimeType': 'text/markdown'},
        })
        print(f'{name}: {"created" if status == 200 else p}')


if __name__ == '__main__':
    main()
