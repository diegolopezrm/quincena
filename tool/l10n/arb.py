"""Edits the app's .arb files line by line, keeping their compact style and
the blank lines between sections. One entry per line; "@key" metadata on
its own line right after its key.

    import sys; sys.path.insert(0, 'tool/l10n')
    import arb
    S = lambda *names: {'placeholders': {n: {'type': t} for n, t in names}}
    arb.edit('app_es.arb', add={'key': ('Texto {n}', S(('n', 'int')))})
    arb.edit('app_en.arb', add={'key': ('Text {n}', None)})

New keys go at the end of the file; app_es.arb is the template, so it
carries the "@key" metadata. Run `flutter gen-l10n` afterwards."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'lib' / 'l10n'


def _line(key, value):
    return '  ' + json.dumps(key, ensure_ascii=False) + ': ' + json.dumps(
        value, ensure_ascii=False, separators=(', ', ': '))


def _key_of(line):
    s = line.strip()
    if not s.startswith('"'):
        return None
    return json.loads(s[:s.index('":') + 1])


def edit(name, add=None, replace=None, remove=()):
    p = ROOT / name
    lines = p.read_text().rstrip('\n').split('\n')
    assert lines[0] == '{' and lines[-1] == '}'
    body = lines[1:-1]

    def find(k):
        for i, l in enumerate(body):
            if _key_of(l) == k:
                return i
        return None

    for k in remove:
        for kk in (k, '@' + k):
            i = find(kk)
            if i is not None:
                del body[i]
    for k, (text, meta) in (replace or {}).items():
        i = find(k)
        assert i is not None, f'{name}: no {k}'
        body[i] = _line(k, text) + ','
        if meta is not None:
            j = find('@' + k)
            if j is None:
                body.insert(i + 1, _line('@' + k, meta) + ',')
            else:
                body[j] = _line('@' + k, meta) + ','
    for k, (text, meta) in (add or {}).items():
        assert find(k) is None, f'{name}: {k} exists'
        body.append(_line(k, text) + ',')
        if meta is not None:
            body.append(_line('@' + k, meta) + ',')
    # Every entry ends in a comma but the last one.
    entries = [i for i, l in enumerate(body) if l.strip()]
    for i in entries:
        body[i] = body[i].rstrip().rstrip(',') + ','
    body[entries[-1]] = body[entries[-1]].rstrip(',')
    text = '\n'.join(['{'] + body + ['}']) + '\n'
    json.loads(text)
    p.write_text(text)
