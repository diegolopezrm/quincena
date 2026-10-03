"""Writes index.html beside the tour's pictures: every screen by section, in
the order it was taken, each linking to the picture at full size.

    python3 tool/tour/index.py capturas/ios
"""
import html
import sys
from pathlib import Path

SECTIONS = {
    '01-primeros-pasos': 'Primeros pasos',
    '02-inicio': 'Inicio',
    '03-por-revisar': 'Por revisar',
    '04-movimientos': 'Movimientos',
    '05-cuentas': 'Cuentas',
    '06-plan': 'Plan: sobres y metas',
    '07-compromisos': 'Plan: compromisos',
    '08-si-te-sirve': 'Plan: si te sirve',
    '09-para-decidir': 'Plan: para decidir',
    '10-importar-extracto': 'Importar extracto',
    '11-ajustes': 'Ajustes',
    '12-varios-dispositivos': 'Varios dispositivos',
    '13-respaldo': 'Respaldo cifrado',
    '14-demo': 'Demo: Valentina y las respuestas',
    '15-modo-oscuro': 'Modo oscuro',
    '16-ingles': 'En inglés',
    '17-demo-ingles': 'Demo en inglés',
    '18-widget': 'Widget de inicio, dibujado desde su código',
}


def main(folder: Path) -> None:
    pictures = sorted(folder.glob('*.png'))
    groups: dict[str, list[Path]] = {}
    for p in pictures:
        key = next((k for k in SECTIONS if p.name.startswith(k + '-')), 'otras')
        groups.setdefault(key, []).append(p)
    parts = []
    for key in list(SECTIONS) + ['otras']:
        if key not in groups:
            continue
        title = SECTIONS.get(key, 'Otras')
        figures = []
        for p in groups[key]:
            name = p.stem[len(key) + 1:] if p.stem.startswith(key) else p.stem
            label = name.split('-', 1)[1] if name[:2].isdigit() else name
            figures.append(
                f'<figure><a href="{html.escape(p.name)}">'
                f'<img src="{html.escape(p.name)}" alt="{html.escape(label)}" loading="lazy"></a>'
                f'<figcaption>{html.escape(label.replace("-", " "))}</figcaption></figure>'
            )
        parts.append(
            f'<section id="{key}"><h2>{html.escape(title)} '
            f'<span>{len(groups[key])}</span></h2>'
            f'<div class="grid">{"".join(figures)}</div></section>'
        )
    nav = ''.join(
        f'<a href="#{k}">{html.escape(SECTIONS.get(k, "Otras"))}</a>'
        for k in list(SECTIONS) + ['otras'] if k in groups
    )
    page = f'''<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Quincena en iPhone</title>
<style>
:root {{ --ground: #f2f4f1; --surface: #ffffff; --ink: #111513; --soft: #4a5450; --line: #dce2dc; --brand: #0b7552; }}
@media (prefers-color-scheme: dark) {{
  :root {{ --ground: #0c0f0e; --surface: #151a18; --ink: #e8eeea; --soft: #a7b2ac; --line: #252d2a; --brand: #3fcb93; }}
}}
* {{ box-sizing: border-box; }}
body {{ margin: 0; padding: 24px 16px 48px; background: var(--ground); color: var(--ink);
  font: 15px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
main {{ max-width: 1240px; margin: 0 auto; }}
h1 {{ font-size: 28px; margin: 0 0 4px; }}
p.lead {{ color: var(--soft); margin: 0 0 16px; }}
nav {{ display: flex; flex-wrap: wrap; gap: 6px 14px; margin-bottom: 28px; }}
nav a {{ color: var(--brand); text-decoration: none; }}
nav a:hover {{ text-decoration: underline; }}
h2 {{ font-size: 20px; margin: 32px 0 12px; display: flex; gap: 10px; align-items: baseline; }}
h2 span {{ color: var(--soft); font-size: 14px; font-weight: 400; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 16px; }}
figure {{ margin: 0; }}
img {{ width: 100%; height: auto; display: block; border-radius: 14px; border: 1px solid var(--line); background: var(--surface); }}
figcaption {{ color: var(--soft); font-size: 13px; margin-top: 6px; }}
</style>
</head>
<body>
<main>
<h1>Quincena en iPhone</h1>
<p class="lead">{len(pictures)} pantallas del simulador, iPhone 17 Pro. Toca una para verla completa.</p>
<nav>{nav}</nav>
{''.join(parts)}
</main>
</body>
</html>
'''
    (folder / 'index.html').write_text(page, encoding='utf-8')
    print(f'{len(pictures)} pictures in {len(groups)} sections: {folder / "index.html"}')


if __name__ == '__main__':
    main(Path(sys.argv[1] if len(sys.argv) > 1 else 'capturas/ios'))
