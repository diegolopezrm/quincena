import 'package:flutter/material.dart';

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
  late final Session _session = widget.session ?? Session();

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
        home: HomePage(session: _session, settings: _settings),
      ),
    );
  }
}
