import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'generated/app_localizations.dart';

/// The app's localizations: its own, and Flutter's Material and Cupertino
/// ones, Material's Spanish with its accept button written as the others.
const List<LocalizationsDelegate<Object?>> appLocalizationsDelegates =
    <LocalizationsDelegate<Object?>>[
      _MaterialEsDelegate(),
      ...AppLocalizations.localizationsDelegates,
    ];

/// Material's words in Spanish, with «Aceptar» written as the buttons
/// around it: Flutter's Spanish has «ACEPTAR», in capitals, beside
/// «Cancelar» in every calendar.
class _MaterialEs extends MaterialLocalizationEs {
  _MaterialEs(String localeName)
    : super(
        localeName: localeName,
        fullYearFormat: intl.DateFormat.y(localeName),
        compactDateFormat: intl.DateFormat.yMd(localeName),
        shortDateFormat: intl.DateFormat.yMMMd(localeName),
        mediumDateFormat: intl.DateFormat.MMMEd(localeName),
        longDateFormat: intl.DateFormat.yMMMMEEEEd(localeName),
        yearMonthFormat: intl.DateFormat.yMMMM(localeName),
        shortMonthDayFormat: intl.DateFormat.MMMd(localeName),
        decimalFormat: intl.NumberFormat.decimalPattern(localeName),
        twoDigitZeroPaddedFormat: intl.NumberFormat('00', localeName),
      );

  @override
  String get okButtonLabel => 'Aceptar';
}

/// Loads [_MaterialEs] for Spanish, ahead of Flutter's own: the first
/// delegate of a kind that takes a language is the one used.
class _MaterialEsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialEsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'es';

  /// After Flutter's own, which loads the words and formats of dates the
  /// calendars need; synchronously, as it does, so no frame goes without.
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate
          .load(locale)
          .then<MaterialLocalizations>(
            (MaterialLocalizations _) =>
                _MaterialEs(intl.Intl.canonicalizedLocale(locale.toString())),
          );

  @override
  bool shouldReload(_MaterialEsDelegate old) => false;
}
