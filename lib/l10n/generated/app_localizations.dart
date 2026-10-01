import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @greeting.
  ///
  /// In es, this message translates to:
  /// **'Hola, {name}'**
  String greeting(String name);

  /// No description provided for @freeUntil.
  ///
  /// In es, this message translates to:
  /// **'Libre hasta el {date}'**
  String freeUntil(String date);

  /// No description provided for @standingDetail.
  ///
  /// In es, this message translates to:
  /// **'Faltan {days} días. Ya separé {committed} para el arriendo, el crédito y los pagos fijos.'**
  String standingDetail(int days, String committed);

  /// No description provided for @standingSemantics.
  ///
  /// In es, this message translates to:
  /// **'Libre hasta el {date}: {free}. Faltan {days} días. En la cuenta hay {balance}.'**
  String standingSemantics(String date, String free, int days, String balance);

  /// No description provided for @legendFree.
  ///
  /// In es, this message translates to:
  /// **'Libre'**
  String get legendFree;

  /// No description provided for @legendCommitted.
  ///
  /// In es, this message translates to:
  /// **'Comprometido'**
  String get legendCommitted;

  /// No description provided for @inTheAccount.
  ///
  /// In es, this message translates to:
  /// **'En la cuenta'**
  String get inTheAccount;

  /// No description provided for @askYourMoney.
  ///
  /// In es, this message translates to:
  /// **'PREGÚNTALE A TU PLATA'**
  String get askYourMoney;

  /// No description provided for @seeRecorded.
  ///
  /// In es, this message translates to:
  /// **'Mira lo que respondió Gemini de verdad'**
  String get seeRecorded;

  /// No description provided for @badgeDemo.
  ///
  /// In es, this message translates to:
  /// **'DEMO'**
  String get badgeDemo;

  /// No description provided for @badgeLive.
  ///
  /// In es, this message translates to:
  /// **'EN VIVO'**
  String get badgeLive;

  /// No description provided for @newConversation.
  ///
  /// In es, this message translates to:
  /// **'Nueva conversación'**
  String get newConversation;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @askHint.
  ///
  /// In es, this message translates to:
  /// **'Pregúntale algo a tu plata'**
  String get askHint;

  /// No description provided for @ask.
  ///
  /// In es, this message translates to:
  /// **'Preguntar'**
  String get ask;

  /// No description provided for @thinking.
  ///
  /// In es, this message translates to:
  /// **'Revisando tus movimientos'**
  String get thinking;

  /// No description provided for @noteSavedExpense.
  ///
  /// In es, this message translates to:
  /// **'Guardaste el gasto'**
  String get noteSavedExpense;

  /// No description provided for @noteChoseMonthly.
  ///
  /// In es, this message translates to:
  /// **'Elegiste cuánto apartar'**
  String get noteChoseMonthly;

  /// No description provided for @noteAskedCancel.
  ///
  /// In es, this message translates to:
  /// **'Pediste cancelar suscripciones'**
  String get noteAskedCancel;

  /// No description provided for @noteAskedPayments.
  ///
  /// In es, this message translates to:
  /// **'Pediste ver los pagos'**
  String get noteAskedPayments;

  /// No description provided for @noteTappedAction.
  ///
  /// In es, this message translates to:
  /// **'Tocaste una acción'**
  String get noteTappedAction;

  /// No description provided for @problemKey.
  ///
  /// In es, this message translates to:
  /// **'La key no funcionó. Revísala en Ajustes.'**
  String get problemKey;

  /// No description provided for @problemBusy.
  ///
  /// In es, this message translates to:
  /// **'El modelo está recibiendo demasiadas preguntas. Prueba en un minuto.'**
  String get problemBusy;

  /// No description provided for @problemOther.
  ///
  /// In es, this message translates to:
  /// **'No pude responder esta vez. Prueba de nuevo.'**
  String get problemOther;

  /// No description provided for @whoAnswers.
  ///
  /// In es, this message translates to:
  /// **'Quién responde'**
  String get whoAnswers;

  /// No description provided for @modeDemo.
  ///
  /// In es, this message translates to:
  /// **'Demo'**
  String get modeDemo;

  /// No description provided for @modeLive.
  ///
  /// In es, this message translates to:
  /// **'Gemini en vivo'**
  String get modeLive;

  /// No description provided for @demoExplain.
  ///
  /// In es, this message translates to:
  /// **'Las cinco preguntas del inicio, respondidas sin red con los mismos componentes que usa el modelo.'**
  String get demoExplain;

  /// No description provided for @liveActive.
  ///
  /// In es, this message translates to:
  /// **'Responde {model}. Pregunta lo que quieras sobre la cuenta.'**
  String liveActive(String model);

  /// No description provided for @liveNeedsKey.
  ///
  /// In es, this message translates to:
  /// **'Con tu key de Gemini puedes preguntar lo que quieras. Se queda en esta pestaña: no se guarda, y solo viaja a Google.'**
  String get liveNeedsKey;

  /// No description provided for @keyLabel.
  ///
  /// In es, this message translates to:
  /// **'Key de Gemini'**
  String get keyLabel;

  /// No description provided for @keyHint.
  ///
  /// In es, this message translates to:
  /// **'De aistudio.google.com'**
  String get keyHint;

  /// No description provided for @connect.
  ///
  /// In es, this message translates to:
  /// **'Conectar'**
  String get connect;

  /// No description provided for @appearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get languageSystem;

  /// No description provided for @developerMode.
  ///
  /// In es, this message translates to:
  /// **'Modo desarrollador'**
  String get developerMode;

  /// No description provided for @developerExplain.
  ///
  /// In es, this message translates to:
  /// **'Muestra el inspector de genui_gen sobre la conversación: el árbol que armó el agente, el data model, lo que anuncia un lector de pantalla y los mensajes.'**
  String get developerExplain;

  /// No description provided for @copySession.
  ///
  /// In es, this message translates to:
  /// **'Copiar la sesión'**
  String get copySession;

  /// No description provided for @sessionCopied.
  ///
  /// In es, this message translates to:
  /// **'Sesión copiada, sin lo que escribiste. Pégala en un issue y se puede reproducir.'**
  String get sessionCopied;

  /// No description provided for @startOver.
  ///
  /// In es, this message translates to:
  /// **'Empezar de nuevo'**
  String get startOver;

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Quincena es una demo de genui y genui_gen. La cuenta, la persona y los comercios son inventados.'**
  String get about;

  /// No description provided for @recordedTitle.
  ///
  /// In es, this message translates to:
  /// **'Lo que respondió Gemini'**
  String get recordedTitle;

  /// No description provided for @recordedIntro.
  ///
  /// In es, this message translates to:
  /// **'Estas sesiones no son del guion de la demo. Gemini recibió cada pregunta, consultó la cuenta con herramientas y compuso la pantalla con el catálogo de la app. genui_gen grabó todo lo que mandó, y aquí se reproduce paso a paso, sin red.'**
  String get recordedIntro;

  /// No description provided for @recordedMeta.
  ///
  /// In es, this message translates to:
  /// **'{model} · {steps} pasos'**
  String recordedMeta(String model, int steps);

  /// No description provided for @recordedSeconds.
  ///
  /// In es, this message translates to:
  /// **'{seconds} s'**
  String recordedSeconds(double seconds);

  /// No description provided for @stepBefore.
  ///
  /// In es, this message translates to:
  /// **'Antes de la respuesta'**
  String get stepBefore;

  /// No description provided for @stepCreate.
  ///
  /// In es, this message translates to:
  /// **'Crea la superficie'**
  String get stepCreate;

  /// No description provided for @stepComponents.
  ///
  /// In es, this message translates to:
  /// **'Manda los componentes'**
  String get stepComponents;

  /// No description provided for @stepData.
  ///
  /// In es, this message translates to:
  /// **'Manda los datos'**
  String get stepData;

  /// No description provided for @stepDataChanged.
  ///
  /// In es, this message translates to:
  /// **'Cambian los datos'**
  String get stepDataChanged;

  /// No description provided for @stepEvent.
  ///
  /// In es, this message translates to:
  /// **'La app le responde al agente'**
  String get stepEvent;

  /// No description provided for @stepMessage.
  ///
  /// In es, this message translates to:
  /// **'Mensaje'**
  String get stepMessage;

  /// No description provided for @stepOf.
  ///
  /// In es, this message translates to:
  /// **'{position} de {length}'**
  String stepOf(int position, int length);

  /// No description provided for @stepSemantics.
  ///
  /// In es, this message translates to:
  /// **'Paso {position} de {length}'**
  String stepSemantics(int position, int length);

  /// No description provided for @setAsideMonthly.
  ///
  /// In es, this message translates to:
  /// **'Apartar al mes'**
  String get setAsideMonthly;

  /// No description provided for @arrivesIn.
  ///
  /// In es, this message translates to:
  /// **'Llegas en '**
  String get arrivesIn;

  /// No description provided for @beforeDeadline.
  ///
  /// In es, this message translates to:
  /// **', antes del {deadline}.'**
  String beforeDeadline(String deadline);

  /// No description provided for @afterDeadline.
  ///
  /// In es, this message translates to:
  /// **', después del {deadline}.'**
  String afterDeadline(String deadline);

  /// No description provided for @goalProgress.
  ///
  /// In es, this message translates to:
  /// **'Llevas {percent} por ciento de la meta'**
  String goalProgress(int percent);

  /// No description provided for @goalSlider.
  ///
  /// In es, this message translates to:
  /// **'Apartar al mes para {name}'**
  String goalSlider(String name);

  /// No description provided for @perMonth.
  ///
  /// In es, this message translates to:
  /// **'{amount} al mes'**
  String perMonth(String amount);

  /// No description provided for @cancelSaves.
  ///
  /// In es, this message translates to:
  /// **'Si cancelas lo que apagaste, te ahorras'**
  String get cancelSaves;

  /// No description provided for @used.
  ///
  /// In es, this message translates to:
  /// **'usado {ago}'**
  String used(String ago);

  /// No description provided for @noUsage.
  ///
  /// In es, this message translates to:
  /// **'sin datos de uso'**
  String get noUsage;

  /// No description provided for @limit.
  ///
  /// In es, this message translates to:
  /// **'Límite'**
  String get limit;

  /// No description provided for @more.
  ///
  /// In es, this message translates to:
  /// **'{amount} más'**
  String more(String amount);

  /// No description provided for @less.
  ///
  /// In es, this message translates to:
  /// **'{amount} menos'**
  String less(String amount);

  /// No description provided for @reference.
  ///
  /// In es, this message translates to:
  /// **'Referencia'**
  String get reference;

  /// No description provided for @inTotal.
  ///
  /// In es, this message translates to:
  /// **'{amount} en total'**
  String inTotal(String amount);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
