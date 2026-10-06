import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_mode.dart';
import 'l10n/l10n.dart';
import 'money/rate_sources.dart';
import 'portfolio/market.dart';
import 'session/session.dart';
import 'store/open.dart';
import 'store/store.dart';
import 'theme/theme.dart';
import 'theme/tokens.dart';
import 'ui/home_page.dart';
import 'ui/messages.dart';
import 'ui/own/onboarding_page.dart';
import 'ui/own/own_shell.dart';
import 'ui/own/start_page.dart';

/// What the person chose in settings.
class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    unawaited(_store?.setSetting(_themeKey, value.name));
    notifyListeners();
  }

  Locale? _locale;

  /// The interface language the person chose, or null to follow the device.
  Locale? get locale => _locale;
  set locale(Locale? value) {
    if (value == _locale) return;
    _locale = value;
    unawaited(_store?.setSetting(_languageKey, value?.languageCode ?? ''));
    notifyListeners();
  }

  QuincenaStore? _store;
  static const String _themeKey = 'app.theme';
  static const String _languageKey = 'app.language';

  /// Takes the theme and the language chosen last time from [store], and
  /// keeps every new choice there. They belong to this device: neither
  /// travels in an export or to another device.
  Future<void> keepIn(QuincenaStore store) async {
    final String? theme = await store.setting(_themeKey);
    final String? language = await store.setting(_languageKey);
    _store = store;
    for (final ThemeMode mode in ThemeMode.values) {
      if (mode.name == theme) _themeMode = mode;
    }
    if (language != null && language.isNotEmpty) _locale = Locale(language);
    notifyListeners();
  }

  /// Back to the phone's theme and language, as when everything was
  /// deleted: what was kept of them went with the rest.
  void forget() {
    _themeMode = ThemeMode.system;
    _locale = null;
    _developer = false;
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
  const QuincenaApp({
    super.key,
    this.session,
    this.store,
    this.startInDemo = kIsWeb,
    this.fetcher,
    this.now,
    this.market,
  });

  /// The conversation to show. Tests pass one with no thinking pause, and
  /// get the sample account and nothing else.
  final Session? session;

  /// Where the person's own accounts are kept. Tests pass one in memory;
  /// otherwise the app opens its own where the build can keep one.
  final QuincenaStore? store;

  /// Open on the sample unless the person already chose their own
  /// accounts, as the published web demo does.
  final bool startInDemo;

  /// Where rates come from, for tests.
  final RateFetcher? fetcher;

  /// The clock, for tests.
  final DateTime Function()? now;

  /// Where crypto prices come from, for tests and the store's screenshots.
  final MarketData? market;

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
        allowance: _modes?.allowance,
      );

  /// Null when a test passed a session: the sample is all there is.
  late final AppModeController? _modes = widget.session != null
      ? null
      : (AppModeController(
          store: widget.store ?? (storageAvailable ? openStore() : null),
          startInDemo: widget.startInDemo,
          fetcher: widget.fetcher,
          now: widget.now,
          market: widget.market,
        )..start());

  @override
  void initState() {
    super.initState();
    if (_modes?.store case final QuincenaStore store) {
      unawaited(_settings.keepIn(store));
    }
  }

  @override
  void dispose() {
    _settings.dispose();
    _modes?.dispose();
    if (widget.store == null) _modes?.store?.close();
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  Widget _home() {
    final AppModeController? modes = _modes;
    if (modes == null) return HomePage(session: _session, settings: _settings);
    return ListenableBuilder(
      listenable: modes,
      builder: (BuildContext context, _) => switch (modes.mode) {
        AppMode.loading => Scaffold(backgroundColor: context.colors.canvas),
        AppMode.choosing => StartPage(
          onOwn: modes.useOwn,
          onDemo: modes.useDemo,
        ),
        AppMode.onboarding => OnboardingPage(
          store: modes.store!,
          onDone: modes.finishedOnboarding,
          onCancel: modes.cancelOnboarding,
          newOwn: () => modes.newOwn(readNative: false),
          now: modes.now,
        ),
        AppMode.demo => HomePage(
          session: _session,
          settings: _settings,
          onUseOwn: modes.canUseOwn ? modes.useOwn : null,
          hasOwn: modes.hasOwn,
        ),
        AppMode.own => OwnShell(
          own: modes.own!,
          modes: modes,
          settings: _settings,
        ),
      },
    );
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
        // Amounts and dates are written in the language the interface
        // resolved to, in every mode, not only where a conversation sets it.
        builder: (BuildContext context, Widget? child) {
          Intl.defaultLocale = intlLocaleFor(
            Localizations.localeOf(context).languageCode,
          );
          return LatestMessenger(child: child!);
        },
        home: _home(),
      ),
    );
  }
}
