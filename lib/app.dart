import 'package:flutter/material.dart';

import 'l10n/l10n.dart';
import 'session/session.dart';
import 'theme/theme.dart';
import 'ui/home_page.dart';

/// What the person chose in settings.
class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    notifyListeners();
  }

  Locale? _locale;

  /// The interface language the person chose, or null to follow the device.
  Locale? get locale => _locale;
  set locale(Locale? value) {
    if (value == _locale) return;
    _locale = value;
    notifyListeners();
  }

  bool _developer = false;

  /// Whether the genui_gen inspector is drawn over the conversation.
  bool get developer => _developer;
  set developer(bool value) {
    if (value == _developer) return;
    _developer = value;
    notifyListeners();
  }
}

class QuincenaApp extends StatefulWidget {
  const QuincenaApp({super.key, this.session});

  /// The conversation to show. Tests pass one with no thinking pause.
  final Session? session;

  @override
  State<QuincenaApp> createState() => _QuincenaAppState();
}

class _QuincenaAppState extends State<QuincenaApp> {
  final AppSettings _settings = AppSettings();

  /// A key passed at build time starts the app with Gemini answering.
  ///
  /// For running locally only: a web build made with the key defined carries
  /// it in its JavaScript, so a build for publishing must never define it.
  static const String _buildKey = String.fromEnvironment('GEMINI_API_KEY');

  late final Session _session =
      widget.session ??
      Session(
        mode: _buildKey.isEmpty ? AgentMode.demo : AgentMode.live,
        apiKey: _buildKey.isEmpty ? null : _buildKey,
      );

  @override
  void dispose() {
    _settings.dispose();
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (BuildContext context, _) => MaterialApp(
        title: 'Quincena',
        debugShowCheckedModeBanner: false,
        theme: quincenaTheme(Brightness.light),
        darkTheme: quincenaTheme(Brightness.dark),
        themeMode: _settings.themeMode,
        locale: _settings.locale,
        supportedLocales: appLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        // Spanish when the device speaks neither language: the app is
        // Colombian before it is anything else.
        localeResolutionCallback:
            (Locale? device, Iterable<Locale> supported) =>
                supported.firstWhere(
                  (Locale l) => l.languageCode == device?.languageCode,
                  orElse: () => const Locale('es'),
                ),
        home: HomePage(session: _session, settings: _settings),
      ),
    );
  }
}
