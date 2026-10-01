import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// The languages the app speaks.
const List<Locale> appLocales = <Locale>[Locale('es'), Locale('en')];

/// Whether formatting should follow English rather than Spanish.
///
/// Read from intl's current locale, which the app keeps in step with the
/// interface language, so plain functions such as the catalog's `money`
/// format the way the screen around them reads.
bool get englishFormatting => Intl.getCurrentLocale().startsWith('en');

/// The locale intl formats with for an interface language.
String intlLocaleFor(String languageCode) =>
    languageCode == 'en' ? 'en_US' : 'es_CO';

extension L10n on BuildContext {
  /// The interface strings, or Spanish when the widget is drawn somewhere
  /// that never set up the app's localizations, such as genui's debug view
  /// or a test harness. A catalog component has to render there too.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('es'));
}
