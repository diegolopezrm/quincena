#!/usr/bin/env python3
"""Export the canonical Q and outlined lettering to SVG, PNG and Flutter.

Run from the repo: python3 tool/brand/export.py [--install]
Requires fontTools, rsvg-convert and ImageMagick. No network or runtime deps.
"""

import argparse
import base64
import json
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

from fontTools.pens.basePen import BasePen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[2]
BRAND = ROOT / "assets/brand"
EMERALD, MINT, INK, PAPER = "#0B7552", "#42D6A4", "#111513", "#F2F4F1"
SVG_NS = "{http://www.w3.org/2000/svg}"


def number(value):
    return f"{value:.4f}".rstrip("0").rstrip(".") if value else "0"


class OutlinePen(BasePen):
    def __init__(self, glyphs, scale, x, baseline):
        super().__init__(glyphs)
        self.scale, self.x, self.baseline = scale, x, baseline
        self.commands = []

    def point(self, p):
        return (self.x + p[0] * self.scale, self.baseline - p[1] * self.scale)

    def _moveTo(self, p):
        self.commands.append(("M", *self.point(p)))

    def _lineTo(self, p):
        self.commands.append(("L", *self.point(p)))

    def _curveToOne(self, p1, p2, p3):
        self.commands.append(("C", *self.point(p1), *self.point(p2), *self.point(p3)))

    def _qCurveToOne(self, p1, p2):
        self.commands.append(("Q", *self.point(p1), *self.point(p2)))

    def _closePath(self):
        self.commands.append(("Z",))


def path_text(commands):
    return " ".join(c[0] + " " + " ".join(number(n) for n in c[1:]) for c in commands)


def parse_path(data):
    tokens = re.findall(r"[MLCQZ]|-?\d*\.?\d+", data)
    commands = []
    lengths = {"M": 2, "L": 2, "C": 6, "Q": 4, "Z": 0}
    i = 0
    while i < len(tokens):
        op = tokens[i]
        count = lengths[op]
        commands.append((op, *map(float, tokens[i + 1:i + 1 + count])))
        i += count + 1
    return commands


def dart_path(name, commands, even_odd=False):
    methods = {"M": "moveTo", "L": "lineTo", "C": "cubicTo", "Q": "quadraticBezierTo", "Z": "close"}
    lines = [f"final Path {name} = Path()"]
    if even_odd:
        lines.append("  ..fillType = PathFillType.evenOdd")
    for op, *values in commands:
        lines.append(f"  ..{methods[op]}({', '.join(number(n) for n in values)})")
    return "\n".join(lines) + ";\n"


def svg(viewbox, body, title="Quincena"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{viewbox}" '
            f'role="img" aria-label="{title}">\n{body}\n</svg>\n')


def symbol(data, left, right):
    # One continuous silhouette. Color is clipped; no independent tail is overlaid.
    return (f'<defs><clipPath id="right-half"><rect x="124" y="0" width="132" height="256"/></clipPath></defs>'
            f'<path d="{data}" fill="{left}" fill-rule="evenodd"/>'
            f'<path d="{data}" fill="{right}" fill-rule="evenodd" clip-path="url(#right-half)"/>')


def render(source, target, width):
    subprocess.run(["rsvg-convert", "-w", str(width), str(source), "-o", str(target)], check=True)


def resize(source, target, width, opaque=True):
    command = ["magick", str(source), "-filter", "Lanczos", "-resize", f"{width}x{width}", "-strip"]
    if opaque:
        command += ["-alpha", "off"]
    subprocess.run(command + [str(target)], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--install", action="store_true", help="Update the existing platform icons.")
    parser.add_argument("--social", action="store_true", help="Render the social card with the latest Flutter screenshot.")
    args = parser.parse_args()

    source = ET.parse(BRAND / "quincena-mark.svg").getroot()
    data = source.find(f"{SVG_NS}defs/{SVG_NS}path").attrib["d"]
    q_commands = parse_path(data)
    font = instantiateVariableFont(
        TTFont(ROOT / "assets/fonts/BricolageGrotesque.ttf"),
        {"wght": 650, "opsz": 48, "wdth": 100},
        inplace=True,
    )
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    font_scale = 300 / font["head"].unitsPerEm
    cursor = 217.0
    lettering = []
    letter_bounds = []
    # Fixed optical spacing becomes part of the outline, so it cannot change on
    # systems with different installed fonts or font-shaping implementations.
    for char in "uincena":
        glyph = glyphs[cmap[ord(char)]]
        pen = OutlinePen(glyphs, font_scale, cursor, 200)
        glyph.draw(pen)
        lettering.extend(pen.commands)
        bounds = BoundsPen(glyphs)
        glyph.draw(bounds)
        x0, y0, x1, y1 = bounds.bounds
        letter_bounds.append((cursor + x0 * font_scale, 200 - y1 * font_scale,
                              cursor + x1 * font_scale, 200 - y0 * font_scale))
        cursor += glyph.width * font_scale - 5.2
    xmin, ymin = 24.0, min(16, min(b[1] for b in letter_bounds) - 16)
    xmax = letter_bounds[-1][2] + 16
    ymax = max(224, max(b[3] for b in letter_bounds) + 16)
    width, height = xmax - xmin, ymax - ymin
    viewbox = " ".join(map(number, (xmin, ymin, width, height)))
    word_data = path_text(lettering)
    bodies = {}
    for name, left, right, word in [
        ("quincena-logo", EMERALD, MINT, INK),
        ("quincena-logo-on-dark", PAPER, MINT, PAPER),
        ("quincena-logo-mono", INK, INK, INK),
    ]:
        body = symbol(data, left, right) + f'<path fill="{word}" d="{word_data}"/>'
        bodies[name] = body
        (BRAND / f"{name}.svg").write_text(svg(viewbox, body))
        render(BRAND / f"{name}.svg", BRAND / f"{name}.png", 1800)

    render(BRAND / "quincena-mark.svg", BRAND / "quincena-mark.png", 1024)
    mark_dark = svg("0 0 256 256", symbol(data, PAPER, MINT))
    (BRAND / "quincena-mark-on-dark.svg").write_text(mark_dark)
    render(BRAND / "quincena-mark-on-dark.svg", BRAND / "quincena-mark-on-dark.png", 1024)

    # iOS receives full-bleed opaque art. PWA maskable art has a smaller symbol,
    # wholly inside its central safe circle. macOS gets a transparent margin.
    for name, factor, rounded in [
        ("quincena-app-icon", 4.15, False),
        ("quincena-app-icon-maskable", 3.30, False),
        ("quincena-app-icon-macos", 3.65, True),
    ]:
        tx, ty = 512 - 126.5 * factor, 512 - 119.5 * factor
        rect = ('<rect x="64" y="64" width="896" height="896" rx="198"'
                if rounded else '<rect width="1024" height="1024"')
        body = (f'{rect} fill="{EMERALD}"/><g transform="translate({number(tx)} {number(ty)}) '
                f'scale({number(factor)})">{symbol(data, PAPER, MINT)}</g>')
        (BRAND / f"{name}.svg").write_text(svg("0 0 1024 1024", body))
        render(BRAND / f"{name}.svg", BRAND / f"{name}.png", 1024)

    dart = ("// GENERATED by tool/brand/export.py. Edit the canonical SVG, then export.\n"
            "// Letter outlines derive from Bricolage Grotesque (SIL OFL).\n"
            "import 'package:flutter/rendering.dart';\n\n"
            f"const Rect quincenaLogoBounds = Rect.fromLTWH({number(xmin)}, {number(ymin)}, {number(width)}, {number(height)});\n"
            "const Rect quincenaMarkBounds = Rect.fromLTWH(24, 16, 208, 208);\n\n"
            + dart_path("quincenaQPath", q_commands, even_odd=True) + "\n"
            + dart_path("quincenaLetteringPath", lettering))
    (ROOT / "lib/ui/brand_paths.g.dart").write_text(dart)

    # A compact review image on actual light/dark surfaces, plus a large
    # close-up of the exact tail junction. Vector artwork remains transparent.
    preview_body = (
        f'<rect width="1400" height="720" fill="{PAPER}"/>'
        f'<rect x="700" width="700" height="720" fill="#0C0F0E"/>'
        f'<svg x="72" y="55" width="556" height="170" viewBox="{viewbox}">{bodies["quincena-logo"]}</svg>'
        f'<svg x="772" y="55" width="556" height="170" viewBox="{viewbox}">{bodies["quincena-logo-on-dark"]}</svg>'
        f'<svg x="157" y="300" width="386" height="340" viewBox="24 16 208 208">{symbol(data, EMERALD, MINT)}</svg>'
        f'<svg x="857" y="300" width="386" height="340" viewBox="24 16 208 208">{symbol(data, PAPER, MINT)}</svg>'
    )
    # Each nested SVG has isolated IDs when rendered as a separate embedded
    # image; embedding prevents document-global clip IDs from colliding.
    for name in ["quincena-logo", "quincena-logo-on-dark"]:
        encoded = base64.b64encode((BRAND / f"{name}.svg").read_bytes()).decode()
        x = 72 if name == "quincena-logo" else 772
        nested = f'<svg x="{x}" y="55" width="556" height="170" viewBox="{viewbox}">{bodies[name]}</svg>'
        preview_body = preview_body.replace(nested, f'<image x="{x}" y="55" width="556" height="170" href="data:image/svg+xml;base64,{encoded}"/>')
    (BRAND / "quincena-preview.svg").write_text(svg("0 0 1400 720", preview_body))
    render(BRAND / "quincena-preview.svg", BRAND / "quincena-preview.png", 1400)

    if args.social:
        screenshot = ROOT / "test_screens/goldens/answer-0-phone-light.png"
        if not screenshot.is_file():
            raise SystemExit("Render answer 0 phone-light with test_screens before --social.")
        shot_data = base64.b64encode(screenshot.read_bytes()).decode()
        logo_data = base64.b64encode((BRAND / "quincena-logo.svg").read_bytes()).decode()
        # Re-render the whole card: no erasing rectangular patches over old art.
        social = svg("0 0 1200 630", (
            f'<rect width="1200" height="630" fill="{PAPER}"/>'
            '<defs><clipPath id="screen"><rect x="865" y="31" width="259" height="560" rx="25"/></clipPath></defs>'
            f'<image x="78" y="90" width="515" height="104" href="data:image/svg+xml;base64,{logo_data}"/>'
            f'<text x="80" y="285" font-family="Arial, sans-serif" font-size="34" fill="{INK}">Finanzas personales donde</text>'
            f'<text x="80" y="333" font-family="Arial, sans-serif" font-size="34" fill="{INK}">cada respuesta es una interfaz.</text>'
            '<text x="80" y="495" font-family="Arial, sans-serif" font-size="23" fill="#4A5450">Una demo de genui y genui_gen, hecha en Flutter.</text>'
            '<text x="80" y="533" font-family="Arial, sans-serif" font-size="23" fill="#4A5450">Un agente compone cada pantalla con el catálogo de la app.</text>'
            '<rect x="855" y="21" width="279" height="580" rx="35" fill="white" stroke="#DCE2DC" stroke-width="2"/>'
            f'<image x="865" y="31" width="259" height="560" clip-path="url(#screen)" href="data:image/png;base64,{shot_data}"/>'
        ))
        docs = ROOT / "docs/brand"
        docs.mkdir(exist_ok=True)
        (docs / "social.svg").write_text(social)
        render(docs / "social.svg", ROOT / "web/og.png", 1200)

    if args.install:
        icon = BRAND / "quincena-app-icon.png"
        for density, pixels in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
            resize(icon, ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", pixels)
        ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
        for item in json.loads((ios / "Contents.json").read_text())["images"]:
            if "filename" in item:
                pixels = round(float(item["size"].split("x")[0]) * float(item["scale"].rstrip("x")))
                resize(icon, ios / item["filename"], pixels)
        macos = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
        for target in macos.glob("app_icon_*.png"):
            resize(BRAND / "quincena-app-icon-macos.png", target, int(target.stem.split("_")[-1]), opaque=False)
        resize(icon, ROOT / "web/favicon.png", 48)
        for pixels in (192, 512):
            resize(icon, ROOT / f"web/icons/Icon-{pixels}.png", pixels)
            resize(BRAND / "quincena-app-icon-maskable.png", ROOT / f"web/icons/Icon-maskable-{pixels}.png", pixels)

        # The web bootstrap loads these before Flutter's asset bundle exists.
        web_brand = ROOT / "web/brand"
        web_brand.mkdir(exist_ok=True)
        for name in ("quincena-logo.svg", "quincena-logo-on-dark.svg"):
            shutil.copyfile(BRAND / name, web_brand / name)

        # Generate native vector drawables from the same compound path.
        android = ROOT / "android/app/src/main/res"
        for name, dp, scale, offset in [
            ("quincena_mark", 144, 1, 0),
            ("quincena_splash_icon", 288, .70, 38.4),
        ]:
            vector = (
                '<vector xmlns:android="http://schemas.android.com/apk/res/android" '
                f'android:width="{dp}dp" android:height="{dp}dp" '
                'android:viewportWidth="256" android:viewportHeight="256">\n'
                f'<group android:scaleX="{scale}" android:scaleY="{scale}" '
                f'android:translateX="{offset}" android:translateY="{offset}">\n'
                f'<path android:fillColor="@color/quincena_mark_primary" android:fillType="evenOdd" android:pathData="{data}"/>\n'
                '<group><clip-path android:pathData="M124 0 H256 V256 H124 Z"/>\n'
                f'<path android:fillColor="@color/quincena_mark_mint" android:fillType="evenOdd" android:pathData="{data}"/>\n'
                '</group></group></vector>\n'
            )
            (android / f"drawable/{name}.xml").write_text(vector)

        launch = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
        images = []
        for dark in (False, True):
            source_name = "quincena-mark-on-dark.svg" if dark else "quincena-mark.svg"
            for scale in (1, 2, 3):
                name = "LaunchImage" + ("-dark" if dark else "") + (f"@{scale}x" if scale > 1 else "") + ".png"
                render(BRAND / source_name, launch / name, 144 * scale)
                item = {"idiom": "universal", "filename": name, "scale": f"{scale}x"}
                if dark:
                    item["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
                images.append(item)
        (launch / "Contents.json").write_text(json.dumps({"images": images, "info": {"version": 1, "author": "xcode"}}, indent=2) + "\n")
        colors = []
        for dark, rgb in ((False, (242, 244, 241)), (True, (12, 15, 14))):
            item = {"idiom": "universal", "color": {"color-space": "srgb", "components": {
                "red": f"{rgb[0] / 255:.10f}", "green": f"{rgb[1] / 255:.10f}",
                "blue": f"{rgb[2] / 255:.10f}", "alpha": "1.000"}}}
            if dark:
                item["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
            colors.append(item)
        background = ROOT / "ios/Runner/Assets.xcassets/LaunchBackground.colorset"
        background.mkdir(exist_ok=True)
        (background / "Contents.json").write_text(json.dumps({"colors": colors, "info": {"version": 1, "author": "xcode"}}, indent=2) + "\n")

    print(f"Exported outlined logo ({width:.1f} x {height:.1f}), continuous Q, Flutter paths and icon masters.")
    if args.install:
        print("Updated Android, iOS, macOS and web icons, plus light/dark startup artwork.")


if __name__ == "__main__":
    main()
