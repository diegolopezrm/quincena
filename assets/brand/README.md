# Quincena brand assets

The initial `Q` is one continuous silhouette, including the diagonal stroke and
tail. Its two colors represent the halves of a pay cycle. In the horizontal logo
it is followed by `uincena`, with optical spacing and outlined lettering, so the
name reads once and renders identically without an installed font.

- `quincena-mark.svg`: transparent standalone mark.
- `quincena-logo.svg`: horizontal logo for light backgrounds.
- `quincena-logo-on-dark.svg`: horizontal logo for dark backgrounds.
- `quincena-logo-mono.svg`: one-color version.
- `quincena-app-icon.svg`: full-bleed master app icon.
- `quincena-app-icon-maskable.svg`: PWA icon with extra mask-safe padding.
- `quincena-app-icon-macos.svg`: macOS tile with transparent outer margins.
- `quincena-preview.png`: side-by-side review on light and dark surfaces.

Every SVG has a PNG export. The lettering is derived from the bundled Bricolage
Grotesque font (weight 650, optical size 48), licensed under the SIL OFL. The
license is in `../fonts/OFL-BricolageGrotesque.txt`.

The core colors are emerald `#0B7552`, mint `#42D6A4`, ink `#111513`, and
off-white `#F2F4F1`. Keep clear space around the mark equal to at least one
quarter of its diameter and do not add shadows, gradients, or outlines.

## Reproduce the exports

`quincena-mark.svg` is the canonical silhouette. Edit its single compound path;
do not overlay a separate tail or edit the generated Flutter paths manually.

```sh
python3 tool/brand/export.py --install
dart format lib/ui/brand_paths.g.dart
```

This uses fontTools, rsvg-convert and ImageMagick to rebuild the outlined logos,
PNG exports, Flutter paths (`lib/ui/brand_paths.g.dart`) and platform icons. It
does not contact a service. Flutter draws those same paths for both the small
mark and complete logo, including its fixed kerning and light/dark colors.

To rebuild the social card too, first render `answer 0 phone-light` with the
existing `test_screens/screens_test.dart` capture and add `--social` to the export
command. The resulting self-contained source lives in `docs/brand/social.svg`.
