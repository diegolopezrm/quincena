import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Figures line up in columns and do not shift as they change.
const List<FontFeature> tabular = <FontFeature>[FontFeature.tabularFigures()];

const String _display = 'Bricolage';
const String _text = 'Geist';

/// A text style on one of the two variable fonts.
///
/// Flutter does not map [FontWeight] onto a variable font's `wght` axis on
/// every platform, so both are set: the weight for platforms that pick a face
/// by it, and the axis for the ones that render the variable font directly.
TextStyle _face(
  String family,
  double size,
  double weight, {
  double height = 1.3,
  double spacing = 0,
  double? opticalSize,
}) => TextStyle(
  fontFamily: family,
  fontSize: size,
  height: height,
  letterSpacing: spacing,
  fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
  fontVariations: <FontVariation>[
    FontVariation('wght', weight),
    if (opticalSize != null) FontVariation('opsz', opticalSize),
  ],
);

TextTheme _textTheme(QuincenaColors c) {
  TextStyle ink(TextStyle style, [Color? color]) =>
      style.copyWith(color: color ?? c.ink);
  return TextTheme(
    // Display sizes carry the amounts that matter, so they are Bricolage at a
    // large optical size, where its figures are at their best.
    displayLarge: ink(
      _face(_display, 52, 720, height: 1.0, spacing: -1.6, opticalSize: 72),
    ),
    displayMedium: ink(
      _face(_display, 40, 700, height: 1.05, spacing: -1.1, opticalSize: 48),
    ),
    displaySmall: ink(
      _face(_display, 30, 680, height: 1.1, spacing: -0.6, opticalSize: 36),
    ),
    headlineLarge: ink(
      _face(_display, 28, 680, height: 1.15, spacing: -0.5, opticalSize: 36),
    ),
    headlineMedium: ink(
      _face(_display, 23, 660, height: 1.2, spacing: -0.3, opticalSize: 24),
    ),
    headlineSmall: ink(
      _face(_display, 19, 640, height: 1.25, spacing: -0.2, opticalSize: 24),
    ),
    titleLarge: ink(_face(_text, 18, 600, height: 1.3, spacing: -0.2)),
    titleMedium: ink(_face(_text, 16, 600, height: 1.35, spacing: -0.1)),
    titleSmall: ink(_face(_text, 14, 600, height: 1.35)),
    bodyLarge: ink(_face(_text, 16, 420, height: 1.5)),
    bodyMedium: ink(_face(_text, 15, 420, height: 1.5), c.inkSoft),
    bodySmall: ink(_face(_text, 13, 420, height: 1.45), c.inkFaint),
    labelLarge: ink(_face(_text, 15, 560, height: 1.2)),
    labelMedium: ink(
      _face(_text, 13, 540, height: 1.2, spacing: 0.1),
      c.inkSoft,
    ),
    labelSmall: ink(
      _face(_text, 11.5, 600, height: 1.2, spacing: 0.6),
      c.inkFaint,
    ),
  );
}

ThemeData quincenaTheme(Brightness brightness) {
  final QuincenaColors c = brightness == Brightness.light
      ? QuincenaColors.light
      : QuincenaColors.dark;
  final TextTheme text = _textTheme(c);

  final ColorScheme scheme = ColorScheme(
    brightness: brightness,
    primary: c.brand,
    onPrimary: c.onBrand,
    primaryContainer: c.brandSoft,
    onPrimaryContainer: c.ink,
    secondary: c.inkSoft,
    onSecondary: c.surface,
    error: c.negative,
    onError: c.surface,
    errorContainer: c.negativeSoft,
    onErrorContainer: c.ink,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkSoft,
    surfaceContainerLowest: c.surface,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.sunken,
    surfaceContainerHigh: c.sunken,
    surfaceContainerHighest: c.sunken,
    outline: c.line,
    outlineVariant: c.line,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.canvas,
    fontFamily: _text,
    textTheme: text,
    extensions: <ThemeExtension<dynamic>>[c],
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    // The sparkle is a fragment shader, which Flutter only turns on for
    // Android outside the web. With it on in the web build, the frames after
    // a tap came 400 ms to a second apart, long enough for a tap to look lost.
    splashFactory: kIsWeb ? InkRipple.splashFactory : InkSparkle.splashFactory,
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.brand,
        foregroundColor: c.onBrand,
        textStyle: text.labelLarge,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        textStyle: text.labelLarge,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: BorderSide(color: c.line),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.brand,
        textStyle: text.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.sunken,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: text.labelMedium,
      floatingLabelStyle: text.labelMedium?.copyWith(color: c.brand),
      hintStyle: text.bodyMedium?.copyWith(color: c.inkFaint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.brand, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.negative, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.negative, width: 1.6),
      ),
      errorStyle: text.bodySmall?.copyWith(color: c.negative),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.brand,
      inactiveTrackColor: c.sunken,
      thumbColor: c.brand,
      overlayColor: c.brand.withValues(alpha: 0.12),
      trackHeight: 6,
      valueIndicatorColor: c.ink,
      valueIndicatorTextStyle: text.labelMedium?.copyWith(color: c.surface),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? c.onBrand : c.inkFaint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? c.brand : c.sunken,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? c.brand : c.line,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.brandSoft,
      side: BorderSide(color: c.line),
      labelStyle: text.labelMedium?.copyWith(color: c.ink),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      showCheckmark: false,
    ),
    // Back arrows and close buttons from the same icon set as everything
    // else.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (BuildContext context) =>
          const Icon(IconData(0xe058, fontFamily: 'Phosphor')),
      closeButtonIconBuilder: (BuildContext context) =>
          const Icon(IconData(0xe4f6, fontFamily: 'Phosphor')),
    ),
    // Flat, like every surface in the app: a border or a fill says what is
    // what, not a shadow.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.brand,
      foregroundColor: c.onBrand,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: text.labelLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.brandSoft,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith(
        (Set<WidgetState> s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? c.brand : c.inkSoft,
          size: 24,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (Set<WidgetState> s) => text.labelMedium?.copyWith(
          color: s.contains(WidgetState.selected) ? c.ink : c.inkSoft,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.canvas,
      indicatorColor: c.brandSoft,
      selectedIconTheme: IconThemeData(color: c.brand),
      unselectedIconTheme: IconThemeData(color: c.inkSoft),
      selectedLabelTextStyle: text.labelMedium?.copyWith(color: c.ink),
      unselectedLabelTextStyle: text.labelMedium,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        // Room for "Transferencia" in a third of a phone.
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(horizontal: 6),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.selected) ? c.brandSoft : c.surface,
        ),
        foregroundColor: WidgetStatePropertyAll<Color>(c.ink),
        side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: c.line)),
        textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelMedium),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: text.bodySmall?.copyWith(color: c.surface),
    ),
  );
}
