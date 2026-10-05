"""Puts each flow on one image: what the person wants, what the checks
found, and every step's picture with its number and the line that says
what was done. Also writes index.html with every flow by part of the app.

    python3 tool/flows/storyboard.py capturas/flujos

Reads <folder>/pasos/, which tool/flows/run.sh fills: <step>.png, <step>.txt
and <flow>.result.json. Writes <folder>/<flow>.png and <folder>/index.html.
"""
import html
import json
import sys
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / 'assets' / 'fonts'

GROUND = (242, 244, 241)
SURFACE = (255, 255, 255)
INK = (17, 21, 19)
SOFT = (74, 84, 80)
LINE = (220, 226, 220)
BRAND = (11, 117, 82)
FAIL = (186, 46, 46)
CAUTION = (150, 100, 0)

COLS = 5
THUMB = 380
GAP = 40
MARGIN = 64
CAPTION_LINES = 7


def font(name, size, weight):
    f = ImageFont.truetype(str(FONTS / name), size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


TITLE = font('BricolageGrotesque.ttf', 60, 700)
EYEBROW = font('Geist.ttf', 24, 600)
GOAL = font('Geist.ttf', 32, 400)
BODY = font('Geist.ttf', 26, 400)
CAPTION = font('Geist.ttf', 23, 400)
NUMBER = font('Geist.ttf', 24, 700)


def wrap(text, width_chars):
    lines = []
    for para in text.split('\n'):
        lines.extend(textwrap.wrap(para, width_chars) or [''])
    return lines


def check_icon(draw, x, y, ok):
    """A drawn mark: a tick in green or a cross in red, 26 px square."""
    color = BRAND if ok else FAIL
    draw.ellipse([x, y, x + 26, y + 26], outline=color, width=3)
    if ok:
        draw.line([(x + 7, y + 13), (x + 12, y + 18), (x + 20, y + 8)], fill=color, width=3)
    else:
        draw.line([(x + 8, y + 8), (x + 18, y + 18)], fill=color, width=3)
        draw.line([(x + 18, y + 8), (x + 8, y + 18)], fill=color, width=3)


def header_lines(result):
    """The header's rows as (kind, text) pairs, to measure and then draw."""
    rows = [('eyebrow', result['area'].upper()), ('title', result['title'])]
    for line in wrap(result['goal'], 95):
        rows.append(('goal', line))
    checks = result.get('checks', [])
    if checks:
        ok = sum(1 for c in checks if c['ok'])
        rows.append(('space', ''))
        rows.append(('label', f'Comprobaciones: {ok} de {len(checks)} se cumplen'))
        for c in checks:
            text = c['what'] + ('' if c['ok'] else f" — {c.get('detail', '')[:160]}")
            for i, line in enumerate(wrap(text, 110)):
                rows.append(('check-ok' if c['ok'] else 'check-fail', line) if i == 0 else ('check-more', line))
    if result.get('error'):
        rows.append(('space', ''))
        for line in wrap('El recorrido se detuvo aquí: ' + result['error'][:300], 110):
            rows.append(('error', line))
    manual = result.get('manual') or []
    if manual:
        rows.append(('space', ''))
        rows.append(('label', 'Para probar a mano en un teléfono:'))
        for m in manual:
            for i, line in enumerate(wrap(m, 110)):
                rows.append(('manual', ('· ' if i == 0 else '  ') + line))
    return rows


ROW_HEIGHT = {
    'eyebrow': 40, 'title': 80, 'goal': 44, 'space': 20, 'label': 42,
    'check-ok': 38, 'check-fail': 38, 'check-more': 34, 'error': 36, 'manual': 36,
}


def compose(folder, result):
    steps = sorted(folder.glob(result['id'] + '-[0-9][0-9].png'))
    width = MARGIN * 2 + COLS * THUMB + (COLS - 1) * GAP
    rows = header_lines(result)
    header_h = sum(ROW_HEIGHT[k] for k, _ in rows) + 48
    thumbs = []
    for png in steps:
        im = Image.open(png).convert('RGB')
        h = round(im.height * THUMB / im.width)
        thumbs.append((im.resize((THUMB, h), Image.LANCZOS), (folder / (png.stem + '.txt'))))
    thumb_h = max((t.height for t, _ in thumbs), default=0)
    cell_h = 56 + thumb_h + 16 + CAPTION_LINES * 30 + 24
    grid_rows = (len(thumbs) + COLS - 1) // COLS
    height = MARGIN + header_h + 40 + grid_rows * cell_h + MARGIN
    board = Image.new('RGB', (width, height), GROUND)
    d = ImageDraw.Draw(board)

    # Header card.
    d.rounded_rectangle([MARGIN, MARGIN, width - MARGIN, MARGIN + header_h], 28, fill=SURFACE, outline=LINE, width=2)
    y = MARGIN + 28
    x = MARGIN + 36
    for kind, text in rows:
        if kind == 'eyebrow':
            d.text((x, y), text, font=EYEBROW, fill=BRAND)
        elif kind == 'title':
            d.text((x, y), text, font=TITLE, fill=INK)
        elif kind == 'goal':
            d.text((x, y), text, font=GOAL, fill=SOFT)
        elif kind == 'label':
            d.text((x, y + 6), text, font=BODY, fill=INK)
        elif kind in ('check-ok', 'check-fail'):
            check_icon(d, x, y + 4, kind == 'check-ok')
            d.text((x + 40, y), text, font=BODY, fill=INK if kind == 'check-ok' else FAIL)
        elif kind == 'check-more':
            d.text((x + 40, y), text, font=BODY, fill=FAIL)
        elif kind == 'error':
            d.text((x, y), text, font=BODY, fill=FAIL)
        elif kind == 'manual':
            d.text((x, y), text, font=BODY, fill=CAUTION)
        y += ROW_HEIGHT[kind]

    # Steps.
    top = MARGIN + header_h + 40
    for i, (im, caption_file) in enumerate(thumbs):
        col, row = i % COLS, i // COLS
        cx = MARGIN + col * (THUMB + GAP)
        cy = top + row * cell_h
        d.ellipse([cx, cy, cx + 44, cy + 44], fill=BRAND)
        n = str(i + 1)
        tw = d.textlength(n, font=NUMBER)
        d.text((cx + 22 - tw / 2, cy + 8), n, font=NUMBER, fill=SURFACE)
        ty = cy + 56
        mask = Image.new('L', im.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1], 34, fill=255)
        board.paste(im, (cx, ty), mask)
        d.rounded_rectangle([cx, ty, cx + im.width - 1, ty + im.height - 1], 34, outline=LINE, width=2)
        caption = caption_file.read_text(encoding='utf-8') if caption_file.exists() else ''
        if caption.startswith('(sigue)'):
            caption = '(sigue)'
        lines = wrap(caption, 30)
        if len(lines) > CAPTION_LINES:
            lines = lines[:CAPTION_LINES - 1] + [lines[CAPTION_LINES - 1].rstrip() + '…']
        cy2 = ty + thumb_h + 16
        for line in lines:
            d.text((cx, cy2), line, font=CAPTION, fill=INK)
            cy2 += 30
    out = folder.parent / (result['id'] + '.png')
    board.save(out, optimize=True)
    return out, len(thumbs)


def index(base, results):
    by_area = {}
    for r in results:
        by_area.setdefault(r['area'], []).append(r)
    parts = []
    for area, rs in by_area.items():
        cards = []
        for r in rs:
            checks = r.get('checks', [])
            ok = sum(1 for c in checks if c['ok'])
            state = 'falla' if (r.get('error') or ok < len(checks)) else 'bien'
            summary = f'{ok} de {len(checks)} comprobaciones' if checks else 'Sin comprobaciones'
            if r.get('error'):
                summary += ' · se detuvo'
            cards.append(
                f'<article class="{state}"><a href="{html.escape(r["id"])}.png">'
                f'<img src="{html.escape(r["id"])}.png" alt="{html.escape(r["title"])}" loading="lazy"></a>'
                f'<h3>{html.escape(r["title"])}</h3><p>{html.escape(r["goal"])}</p>'
                f'<p class="meta">{len(r.get("steps", []))} pasos · {summary}</p></article>'
            )
        parts.append(f'<section><h2>{html.escape(area)}</h2><div class="grid">{"".join(cards)}</div></section>')
    page = f'''<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Quincena, flujo por flujo</title>
<style>
:root {{ --ground:#f2f4f1; --surface:#fff; --ink:#111513; --soft:#4a5450; --line:#dce2dc; --brand:#0b7552; --fail:#ba2e2e; }}
body {{ margin:0; padding:24px 16px 48px; background:var(--ground); color:var(--ink); font:15px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
main {{ max-width:1240px; margin:0 auto; }}
h2 {{ margin:36px 0 12px; }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(280px,1fr)); gap:16px; }}
article {{ background:var(--surface); border:1px solid var(--line); border-radius:16px; padding:12px; }}
article.falla {{ border-color:var(--fail); }}
img {{ width:100%; height:auto; border-radius:10px; display:block; }}
h3 {{ font-size:16px; margin:10px 0 4px; }}
p {{ margin:0 0 6px; color:var(--soft); }}
.meta {{ font-size:13px; }}
.falla .meta {{ color:var(--fail); }}
</style></head><body><main>
<h1>Quincena, flujo por flujo</h1>
<p>{len(results)} flujos en el simulador, iPhone 17 Pro. Cada imagen muestra lo que la persona quiere, cada paso con su foto y lo que se comprobó.</p>
{"".join(parts)}
</main></body></html>'''
    (base / 'index.html').write_text(page, encoding='utf-8')


def main(base):
    folder = base / 'pasos'
    results = []
    for f in sorted(folder.glob('*.result.json')):
        r = json.loads(f.read_text(encoding='utf-8'))
        out, n = compose(folder, r)
        results.append(r)
        checks = r.get('checks', [])
        ok = sum(1 for c in checks if c['ok'])
        print(f"{r['id']}: {n} pasos, {ok}/{len(checks)} comprobaciones{' · se detuvo' if r.get('error') else ''} -> {out.name}")
    index(base, results)
    print(f'{len(results)} flujos: {base / "index.html"}')


if __name__ == '__main__':
    main(Path(sys.argv[1] if len(sys.argv) > 1 else 'capturas/flujos').resolve())
