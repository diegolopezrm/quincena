#!/usr/bin/env python3
"""Google Play's feature graphic, 1024 by 500, in Spanish and English.

Run from the repo: python3 tool/brand/feature_graphic.py
It takes the outlined logo from docs/brand/social.svg and the home screen
from the Play screenshots, and needs rsvg-convert and ImageMagick.
"""

import base64
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORE = ROOT / "docs/store"
INK, SOFT, PAPER, EDGE = "#111513", "#4A5450", "#F2F4F1", "#DCE2DC"

LINES = {
    "es": ("Lo que te queda hasta el pago", "Tus finanzas se quedan en tu teléfono."),
    "en": ("What's left until payday", "Your finances stay on your phone."),
}


def logo() -> str:
    social = (ROOT / "docs/brand/social.svg").read_text()
    return re.search(r'href="(data:image/svg\+xml;base64,[^"]+)"', social).group(1)


def svg(language: str) -> str:
    title, line = LINES[language]
    screen = base64.b64encode(
        (STORE / f"screenshots/play/{language}/02-home.png").read_bytes()
    ).decode()
    # The phone runs off the bottom edge, like the social card's.
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="500" viewBox="0 0 1024 500">
<rect width="1024" height="500" fill="{PAPER}"/>
<defs><clipPath id="screen"><rect x="704" y="48" width="236" height="524" rx="22"/></clipPath></defs>
<image x="64" y="138" width="420" height="85" href="{logo()}"/>
<text x="66" y="290" font-family="Arial, sans-serif" font-size="34" fill="{INK}">{title}</text>
<text x="66" y="336" font-family="Arial, sans-serif" font-size="22" fill="{SOFT}">{line}</text>
<rect x="694" y="38" width="256" height="560" rx="32" fill="white" stroke="{EDGE}" stroke-width="2"/>
<image x="704" y="48" width="236" height="524" clip-path="url(#screen)" preserveAspectRatio="xMidYMin slice" href="data:image/png;base64,{screen}"/>
</svg>"""


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        for language in LINES:
            source = Path(tmp) / f"{language}.svg"
            source.write_text(svg(language))
            rendered = Path(tmp) / f"{language}.png"
            subprocess.run(
                ["rsvg-convert", "-w", "1024", "-h", "500", str(source), "-o", str(rendered)],
                check=True,
            )
            # Play takes a JPEG or a 24-bit PNG: no alpha channel.
            out = STORE / f"feature-graphic-{language}.png"
            subprocess.run(
                ["magick", str(rendered), "-background", PAPER, "-alpha", "remove", "-alpha", "off", f"PNG24:{out}"],
                check=True,
            )
            print(out.relative_to(ROOT))


if __name__ == "__main__":
    main()
