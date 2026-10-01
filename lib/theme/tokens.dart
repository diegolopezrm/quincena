import 'package:flutter/material.dart';

/// The colors Quincena uses beyond what a [ColorScheme] has room for.
///
/// A finance app needs three meanings that Material does not name: money that
/// came in or stayed (positive), money that went over (negative), and money
/// worth a second look (caution). It also needs one color per spending
/// category that stays the same everywhere the category appears: in the
/// donut, in a transaction row, in a budget meter.
@immutable
class QuincenaColors extends ThemeExtension<QuincenaColors> {
  const QuincenaColors({
    required this.canvas,
    required this.surface,
    required this.sunken,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.brand,
    required this.brandSoft,
    required this.onBrand,
    required this.positive,
    required this.negative,
    required this.caution,
    required this.cautionSoft,
    required this.negativeSoft,
    required this.categories,
  });

  final Color canvas;
  final Color surface;
  final Color sunken;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color line;
  final Color brand;
  final Color brandSoft;
  final Color onBrand;
  final Color positive;
  final Color negative;
  final Color caution;
  final Color cautionSoft;
  final Color negativeSoft;

  /// One color per category, keyed by the category's name.
  final Map<String, Color> categories;

  Color category(String name) => categories[name] ?? inkFaint;

  static const QuincenaColors light = QuincenaColors(
    canvas: Color(0xFFF2F4F1),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFE9EDE8),
    ink: Color(0xFF111513),
    inkSoft: Color(0xFF4A5450),
    inkFaint: Color(0xFF7A857F),
    line: Color(0xFFDCE2DC),
    brand: Color(0xFF0B7552),
    brandSoft: Color(0xFFD5EEE2),
    onBrand: Color(0xFFFFFFFF),
    positive: Color(0xFF0B7552),
    negative: Color(0xFFC8402F),
    caution: Color(0xFF9A6A00),
    cautionSoft: Color(0xFFFBEFCF),
    negativeSoft: Color(0xFFFBE3DF),
    categories: <String, Color>{
      'housing': Color(0xFF4F5DDB),
      'groceries': Color(0xFF1F9A6B),
      'restaurants': Color(0xFFE07A2E),
      'transport': Color(0xFF2386C4),
      'utilities': Color(0xFF8A6AD8),
      'subscriptions': Color(0xFFD24E84),
      'health': Color(0xFF16A3A3),
      'shopping': Color(0xFFC79113),
      'leisure': Color(0xFFB45CC7),
      'debt': Color(0xFF5E6B8C),
      'other': Color(0xFF7A857F),
    },
  );

  static const QuincenaColors dark = QuincenaColors(
    canvas: Color(0xFF0C0F0E),
    surface: Color(0xFF151A18),
    sunken: Color(0xFF1C2220),
    ink: Color(0xFFE8EEEA),
    inkSoft: Color(0xFFA7B2AC),
    inkFaint: Color(0xFF75817B),
    line: Color(0xFF252D2A),
    brand: Color(0xFF3FCB93),
    brandSoft: Color(0xFF16382A),
    onBrand: Color(0xFF04231A),
    positive: Color(0xFF3FCB93),
    negative: Color(0xFFFF7A68),
    caution: Color(0xFFF2B93F),
    cautionSoft: Color(0xFF372B10),
    negativeSoft: Color(0xFF3A1D18),
    categories: <String, Color>{
      'housing': Color(0xFF8A95FF),
      'groceries': Color(0xFF4CCB98),
      'restaurants': Color(0xFFFF9B57),
      'transport': Color(0xFF55B6EE),
      'utilities': Color(0xFFB39BFF),
      'subscriptions': Color(0xFFFF7FB0),
      'health': Color(0xFF4FD3CF),
      'shopping': Color(0xFFF2C14E),
      'leisure': Color(0xFFDB8BEB),
      'debt': Color(0xFF93A0C4),
      'other': Color(0xFF8E9A94),
    },
  );

  @override
  QuincenaColors copyWith() => this;

  @override
  QuincenaColors lerp(ThemeExtension<QuincenaColors>? other, double t) {
    if (other is! QuincenaColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return QuincenaColors(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      sunken: mix(sunken, other.sunken),
      ink: mix(ink, other.ink),
      inkSoft: mix(inkSoft, other.inkSoft),
      inkFaint: mix(inkFaint, other.inkFaint),
      line: mix(line, other.line),
      brand: mix(brand, other.brand),
      brandSoft: mix(brandSoft, other.brandSoft),
      onBrand: mix(onBrand, other.onBrand),
      positive: mix(positive, other.positive),
      negative: mix(negative, other.negative),
      caution: mix(caution, other.caution),
      cautionSoft: mix(cautionSoft, other.cautionSoft),
      negativeSoft: mix(negativeSoft, other.negativeSoft),
      categories: <String, Color>{
        for (final String key in categories.keys)
          key: mix(categories[key]!, other.categories[key] ?? categories[key]!),
      },
    );
  }
}

/// Shorthand for the extension, which every widget in the catalog reads.
extension QuincenaTheme on BuildContext {
  /// The app's colors, or the matching built-in set when the widget is drawn
  /// under someone else's theme.
  ///
  /// Catalog components are not only drawn inside this app: genui's debug
  /// view, a test harness or another host can render them under a plain
  /// Material theme, and a component that crashes there is a component the
  /// agent can break by being shown somewhere new.
  QuincenaColors get colors {
    final ThemeData theme = Theme.of(this);
    return theme.extension<QuincenaColors>() ??
        (theme.brightness == Brightness.dark
            ? QuincenaColors.dark
            : QuincenaColors.light);
  }

  TextTheme get type => Theme.of(this).textTheme;
}
