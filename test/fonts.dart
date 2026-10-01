import 'package:flutter/services.dart';

/// Loads the app's real typefaces into the test.
///
/// A widget test draws text in a stand-in font where every glyph is a square
/// as wide as the font is tall, which makes every line much longer than it
/// is on a device. Layout checks against that are checks against a font no
/// one will see.
Future<void> loadAppFonts() async {
  const Map<String, String> fonts = <String, String>{
    'Geist': 'assets/fonts/Geist.ttf',
    'Bricolage': 'assets/fonts/BricolageGrotesque.ttf',
    'Phosphor': 'assets/icons/Phosphor.ttf',
  };
  for (final MapEntry<String, String> font in fonts.entries) {
    await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
  }
}
