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
  /// **'Puedes gastar hasta el {date}'**
  String freeUntil(String date);

  /// No description provided for @standingSemantics.
  ///
  /// In es, this message translates to:
  /// **'Puedes gastar {free} hasta el {date}; {when}.'**
  String standingSemantics(String free, String date, String when);

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
  /// **'Guardaste el plan'**
  String get noteChoseMonthly;

  /// No description provided for @noteAskedCancel.
  ///
  /// In es, this message translates to:
  /// **'Marcaste lo que ya cancelaste'**
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

  /// No description provided for @problemOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión a internet. Tus cuentas y movimientos siguen funcionando; vuelve a preguntar cuando tengas red.'**
  String get problemOffline;

  /// No description provided for @problemOther.
  ///
  /// In es, this message translates to:
  /// **'No pude responder esta vez. Prueba de nuevo.'**
  String get problemOther;

  /// No description provided for @problemLimit.
  ///
  /// In es, this message translates to:
  /// **'Ya usaste las preguntas de hoy. Mañana puedes seguir preguntando.'**
  String get problemLimit;

  /// No description provided for @askTitle.
  ///
  /// In es, this message translates to:
  /// **'Pregúntale a tu plata'**
  String get askTitle;

  /// No description provided for @askYourMoneyLabel.
  ///
  /// In es, this message translates to:
  /// **'Pregúntale a tu plata'**
  String get askYourMoneyLabel;

  /// No description provided for @ownAskFree.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto puedo gastar antes de que me paguen?'**
  String get ownAskFree;

  /// No description provided for @ownAskMonth.
  ///
  /// In es, this message translates to:
  /// **'¿En qué se me fue la plata este mes?'**
  String get ownAskMonth;

  /// No description provided for @ownAskAll.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto tengo en total, con dólares y cripto?'**
  String get ownAskAll;

  /// No description provided for @ownAskCompare.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo voy comparado con el mes pasado?'**
  String get ownAskCompare;

  /// No description provided for @ownAskRecord.
  ///
  /// In es, this message translates to:
  /// **'Quiero anotar un gasto'**
  String get ownAskRecord;

  /// No description provided for @askOther.
  ///
  /// In es, this message translates to:
  /// **'Otra pregunta'**
  String get askOther;

  /// No description provided for @askLeft.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Ya no te quedan preguntas hoy} =1{Te queda una pregunta hoy} other{Te quedan {count} preguntas hoy}}'**
  String askLeft(int count);

  /// No description provided for @askWhatSees.
  ///
  /// In es, this message translates to:
  /// **'Qué ve Gemini'**
  String get askWhatSees;

  /// No description provided for @geminiNoteHow.
  ///
  /// In es, this message translates to:
  /// **'Cuando le preguntas algo a tu plata, la pregunta va a Gemini, el modelo de Google, a través del proyecto de Quincena en Firebase. No necesitas una key ni una cuenta: Quincena te identifica con un usuario anónimo, solo para contar tus preguntas.'**
  String get geminiNoteHow;

  /// No description provided for @geminiNoteSends.
  ///
  /// In es, this message translates to:
  /// **'Gemini no recibe tu base de datos. Pide las cifras que necesita a herramientas que corren en tu teléfono o tu computador, y lo que viaja son sus respuestas: tus totales por categoría y por mes, lo que puedes gastar hasta el pago, tus suscripciones, tu meta de ahorro, tus cuentas con su saldo y, cuando la pregunta lo pide, los pagos más grandes de un mes con su comercio.'**
  String get geminiNoteSends;

  /// No description provided for @geminiNoteNot.
  ///
  /// In es, this message translates to:
  /// **'No viajan tus otros movimientos uno por uno, ni tus notas, ni las alertas de tu banco, ni tu ubicación.'**
  String get geminiNoteNot;

  /// No description provided for @geminiNoteTerms.
  ///
  /// In es, this message translates to:
  /// **'Quincena usa Gemini en Agent Platform, de Google Cloud, como cliente que paga: Google no entrena sus modelos con lo que se envía ni lo guarda en caché, y solo conserva una pregunta si sus filtros la marcan como abuso. Aun así, no escribas en una pregunta nada que no quieras compartir, como un número de cuenta.'**
  String get geminiNoteTerms;

  /// No description provided for @geminiNoteLimit.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Cada persona tiene una pregunta al día.} other{Cada persona tiene {count} preguntas al día.}} Firebase App Check comprueba que vienen de la app de Quincena y no de otro programa.'**
  String geminiNoteLimit(int count);

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

  /// No description provided for @modeGemini.
  ///
  /// In es, this message translates to:
  /// **'Gemini'**
  String get modeGemini;

  /// No description provided for @modeOwnKey.
  ///
  /// In es, this message translates to:
  /// **'Tu key'**
  String get modeOwnKey;

  /// No description provided for @geminiExplain.
  ///
  /// In es, this message translates to:
  /// **'Responde {model} a través de Quincena, sin key. Pregunta lo que quieras sobre la cuenta.'**
  String geminiExplain(String model);

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
  /// **'Si apartas al mes'**
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
  /// **'Si cancelas las que marcaste, te ahorras'**
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

  /// No description provided for @startTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo quieres empezar?'**
  String get startTitle;

  /// No description provided for @startOwnTitle.
  ///
  /// In es, this message translates to:
  /// **'Con mis cuentas'**
  String get startOwnTitle;

  /// No description provided for @startOwnBody.
  ///
  /// In es, this message translates to:
  /// **'Agrega tus cuentas en pesos, dólares o cripto y registra lo que entra y lo que sale.'**
  String get startOwnBody;

  /// No description provided for @startDemoTitle.
  ///
  /// In es, this message translates to:
  /// **'Con datos de ejemplo'**
  String get startDemoTitle;

  /// No description provided for @startDemoBody.
  ///
  /// In es, this message translates to:
  /// **'Recorre toda la app con la cuenta de Valentina, una diseñadora en Medellín. Es inventada y no toca tus datos; puedes pasar a tus cuentas cuando quieras.'**
  String get startDemoBody;

  /// No description provided for @privacyNote.
  ///
  /// In es, this message translates to:
  /// **'Tus cuentas y movimientos se guardan solo en este dispositivo.'**
  String get privacyNote;

  /// No description provided for @onboardingStep.
  ///
  /// In es, this message translates to:
  /// **'Paso {step} de {total}'**
  String onboardingStep(int step, int total);

  /// No description provided for @onboardingNameTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo te llamas?'**
  String get onboardingNameTitle;

  /// No description provided for @onboardingNameHint.
  ///
  /// In es, this message translates to:
  /// **'Tu nombre'**
  String get onboardingNameHint;

  /// No description provided for @onboardingBaseTitle.
  ///
  /// In es, this message translates to:
  /// **'¿En qué moneda quieres ver tus totales?'**
  String get onboardingBaseTitle;

  /// No description provided for @onboardingBaseBody.
  ///
  /// In es, this message translates to:
  /// **'Cada cuenta conserva su propia moneda; los totales se convierten a esta.'**
  String get onboardingBaseBody;

  /// No description provided for @onboardingPayTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo te pagan?'**
  String get onboardingPayTitle;

  /// No description provided for @onboardingPayBody.
  ///
  /// In es, this message translates to:
  /// **'Con esto Quincena calcula cuánto puedes gastar hasta el próximo pago.'**
  String get onboardingPayBody;

  /// No description provided for @onboardingAccountsTitle.
  ///
  /// In es, this message translates to:
  /// **'Agrega tus cuentas'**
  String get onboardingAccountsTitle;

  /// No description provided for @onboardingAccountsBody.
  ///
  /// In es, this message translates to:
  /// **'Bancos, billeteras, efectivo, tarjetas o cripto. Puedes agregar más después.'**
  String get onboardingAccountsBody;

  /// No description provided for @onboardingSuggestions.
  ///
  /// In es, this message translates to:
  /// **'Para empezar rápido'**
  String get onboardingSuggestions;

  /// No description provided for @onboardingNeedAccount.
  ///
  /// In es, this message translates to:
  /// **'Agrega al menos una cuenta para empezar.'**
  String get onboardingNeedAccount;

  /// No description provided for @next.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get next;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get back;

  /// No description provided for @finish.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get finish;

  /// No description provided for @payTwiceMonthly.
  ///
  /// In es, this message translates to:
  /// **'Quincenal'**
  String get payTwiceMonthly;

  /// No description provided for @payTwiceMonthlyDetail.
  ///
  /// In es, this message translates to:
  /// **'Los días {first} y {second} de cada mes'**
  String payTwiceMonthlyDetail(String first, String second);

  /// No description provided for @payMonthly.
  ///
  /// In es, this message translates to:
  /// **'Mensual'**
  String get payMonthly;

  /// No description provided for @payMonthlyDetail.
  ///
  /// In es, this message translates to:
  /// **'El día {day} de cada mes'**
  String payMonthlyDetail(String day);

  /// No description provided for @payBiweekly.
  ///
  /// In es, this message translates to:
  /// **'Cada dos semanas'**
  String get payBiweekly;

  /// No description provided for @payBiweeklyDetail.
  ///
  /// In es, this message translates to:
  /// **'Cada 14 días, contando desde el {date}'**
  String payBiweeklyDetail(String date);

  /// No description provided for @payWeekly.
  ///
  /// In es, this message translates to:
  /// **'Semanal'**
  String get payWeekly;

  /// No description provided for @payWeeklyDetail.
  ///
  /// In es, this message translates to:
  /// **'Cada {weekday}'**
  String payWeeklyDetail(String weekday);

  /// No description provided for @payFirstDay.
  ///
  /// In es, this message translates to:
  /// **'Primer pago'**
  String get payFirstDay;

  /// No description provided for @paySecondDay.
  ///
  /// In es, this message translates to:
  /// **'Segundo pago'**
  String get paySecondDay;

  /// No description provided for @payDay.
  ///
  /// In es, this message translates to:
  /// **'Día de pago'**
  String get payDay;

  /// No description provided for @payLastPayday.
  ///
  /// In es, this message translates to:
  /// **'Tu último pago'**
  String get payLastPayday;

  /// No description provided for @payWeekday.
  ///
  /// In es, this message translates to:
  /// **'Día de la semana'**
  String get payWeekday;

  /// No description provided for @payDayOption.
  ///
  /// In es, this message translates to:
  /// **'Día {day}'**
  String payDayOption(int day);

  /// No description provided for @tabHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get tabHome;

  /// No description provided for @tabMovements.
  ///
  /// In es, this message translates to:
  /// **'Movimientos'**
  String get tabMovements;

  /// No description provided for @tabAccounts.
  ///
  /// In es, this message translates to:
  /// **'Cuentas'**
  String get tabAccounts;

  /// No description provided for @addAccount.
  ///
  /// In es, this message translates to:
  /// **'Agregar cuenta'**
  String get addAccount;

  /// No description provided for @editAccount.
  ///
  /// In es, this message translates to:
  /// **'Editar cuenta'**
  String get editAccount;

  /// No description provided for @accountName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get accountName;

  /// No description provided for @accountNameHint.
  ///
  /// In es, this message translates to:
  /// **'Por ejemplo, Bancolombia ahorros'**
  String get accountNameHint;

  /// No description provided for @accountKind.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get accountKind;

  /// No description provided for @kindBank.
  ///
  /// In es, this message translates to:
  /// **'Banco'**
  String get kindBank;

  /// No description provided for @kindCard.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta de crédito'**
  String get kindCard;

  /// No description provided for @kindCash.
  ///
  /// In es, this message translates to:
  /// **'Efectivo'**
  String get kindCash;

  /// No description provided for @kindWallet.
  ///
  /// In es, this message translates to:
  /// **'Billetera digital'**
  String get kindWallet;

  /// No description provided for @kindExchange.
  ///
  /// In es, this message translates to:
  /// **'Exchange de cripto'**
  String get kindExchange;

  /// No description provided for @kindInvestment.
  ///
  /// In es, this message translates to:
  /// **'Ahorro o inversión'**
  String get kindInvestment;

  /// No description provided for @kindOther.
  ///
  /// In es, this message translates to:
  /// **'Otra'**
  String get kindOther;

  /// No description provided for @accountAsset.
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get accountAsset;

  /// No description provided for @assetFiat.
  ///
  /// In es, this message translates to:
  /// **'Monedas'**
  String get assetFiat;

  /// No description provided for @assetCrypto.
  ///
  /// In es, this message translates to:
  /// **'Cripto'**
  String get assetCrypto;

  /// No description provided for @assetOther.
  ///
  /// In es, this message translates to:
  /// **'Otra cripto'**
  String get assetOther;

  /// No description provided for @assetOtherHint.
  ///
  /// In es, this message translates to:
  /// **'Símbolo, por ejemplo ADA'**
  String get assetOtherHint;

  /// No description provided for @accountInstitution.
  ///
  /// In es, this message translates to:
  /// **'Entidad (opcional)'**
  String get accountInstitution;

  /// No description provided for @accountBalanceNow.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto tiene hoy?'**
  String get accountBalanceNow;

  /// No description provided for @accountDebtNow.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto debes hoy?'**
  String get accountDebtNow;

  /// No description provided for @accountSpendable.
  ///
  /// In es, this message translates to:
  /// **'Cuenta de uso diario'**
  String get accountSpendable;

  /// No description provided for @accountSpendableHelp.
  ///
  /// In es, this message translates to:
  /// **'Su saldo cuenta en lo que puedes gastar hasta el próximo pago. Apágalo para ahorros, inversiones y cripto.'**
  String get accountSpendableHelp;

  /// No description provided for @accountAssetLocked.
  ///
  /// In es, this message translates to:
  /// **'La moneda no se puede cambiar: los movimientos de la cuenta están en ella.'**
  String get accountAssetLocked;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar {name}?'**
  String deleteAccountTitle(String name);

  /// No description provided for @deleteAccountBody.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{No tiene movimientos.} =1{Se borra también su movimiento. No se puede deshacer.} other{Se borran también sus {count} movimientos. No se puede deshacer.}}'**
  String deleteAccountBody(int count);

  /// No description provided for @groupSpendable.
  ///
  /// In es, this message translates to:
  /// **'Cuentas de uso diario'**
  String get groupSpendable;

  /// No description provided for @groupSaved.
  ///
  /// In es, this message translates to:
  /// **'Ahorros e inversiones'**
  String get groupSaved;

  /// No description provided for @netWorth.
  ///
  /// In es, this message translates to:
  /// **'Patrimonio'**
  String get netWorth;

  /// No description provided for @noAccounts.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes cuentas. Agrega la de tu banco, tu billetera o el efectivo con «Agregar cuenta».'**
  String get noAccounts;

  /// No description provided for @yourAccounts.
  ///
  /// In es, this message translates to:
  /// **'Tus cuentas'**
  String get yourAccounts;

  /// No description provided for @balanceToday.
  ///
  /// In es, this message translates to:
  /// **'Saldo hoy'**
  String get balanceToday;

  /// No description provided for @ratesTitle.
  ///
  /// In es, this message translates to:
  /// **'Tasas'**
  String get ratesTitle;

  /// No description provided for @ratesUpdated.
  ///
  /// In es, this message translates to:
  /// **'Actualizadas {when}'**
  String ratesUpdated(String when);

  /// No description provided for @ratesNever.
  ///
  /// In es, this message translates to:
  /// **'Aún sin tasas: se buscan al conectarse.'**
  String get ratesNever;

  /// No description provided for @ratesRefresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar tasas'**
  String get ratesRefresh;

  /// No description provided for @ratesFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron actualizar. Se usan las últimas guardadas.'**
  String get ratesFailed;

  /// No description provided for @ratesMissing.
  ///
  /// In es, this message translates to:
  /// **'Sin tasa para {assets}: cuenta como cero en los totales.'**
  String ratesMissing(String assets);

  /// No description provided for @rateSourceTrm.
  ///
  /// In es, this message translates to:
  /// **'TRM oficial'**
  String get rateSourceTrm;

  /// No description provided for @rateSourceBinance.
  ///
  /// In es, this message translates to:
  /// **'Binance'**
  String get rateSourceBinance;

  /// No description provided for @rateSourceEcb.
  ///
  /// In es, this message translates to:
  /// **'Banco Central Europeo'**
  String get rateSourceEcb;

  /// No description provided for @rateEdit.
  ///
  /// In es, this message translates to:
  /// **'Escribir una tasa'**
  String get rateEdit;

  /// No description provided for @rateEditBody.
  ///
  /// In es, this message translates to:
  /// **'Cuánto vale 1 {asset} en {quote}. Una tasa escrita a mano no se reemplaza al actualizar.'**
  String rateEditBody(String asset, String quote);

  /// No description provided for @rateUseFetched.
  ///
  /// In es, this message translates to:
  /// **'Volver a la tasa automática'**
  String get rateUseFetched;

  /// No description provided for @stablecoinPeg.
  ///
  /// In es, this message translates to:
  /// **'{asset} se cuenta como 1 US\$'**
  String stablecoinPeg(String asset);

  /// No description provided for @addMovement.
  ///
  /// In es, this message translates to:
  /// **'Agregar movimiento'**
  String get addMovement;

  /// No description provided for @editMovement.
  ///
  /// In es, this message translates to:
  /// **'Editar movimiento'**
  String get editMovement;

  /// No description provided for @kindExpense.
  ///
  /// In es, this message translates to:
  /// **'Gasto'**
  String get kindExpense;

  /// No description provided for @kindIncome.
  ///
  /// In es, this message translates to:
  /// **'Ingreso'**
  String get kindIncome;

  /// No description provided for @kindTransfer.
  ///
  /// In es, this message translates to:
  /// **'Transferencia'**
  String get kindTransfer;

  /// No description provided for @amount.
  ///
  /// In es, this message translates to:
  /// **'Monto'**
  String get amount;

  /// No description provided for @account.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get account;

  /// No description provided for @fromAccount.
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get fromAccount;

  /// No description provided for @toAccount.
  ///
  /// In es, this message translates to:
  /// **'Hacia'**
  String get toAccount;

  /// No description provided for @received.
  ///
  /// In es, this message translates to:
  /// **'Llegó'**
  String get received;

  /// No description provided for @receivedHelp.
  ///
  /// In es, this message translates to:
  /// **'Lo que llegó a la otra cuenta, en su moneda.'**
  String get receivedHelp;

  /// No description provided for @category.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get category;

  /// No description provided for @newCategory.
  ///
  /// In es, this message translates to:
  /// **'Nueva categoría'**
  String get newCategory;

  /// No description provided for @payee.
  ///
  /// In es, this message translates to:
  /// **'¿Dónde o a quién?'**
  String get payee;

  /// No description provided for @payeeIncome.
  ///
  /// In es, this message translates to:
  /// **'¿De dónde?'**
  String get payeeIncome;

  /// No description provided for @date.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get date;

  /// No description provided for @note.
  ///
  /// In es, this message translates to:
  /// **'Nota (opcional)'**
  String get note;

  /// No description provided for @today.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get yesterday;

  /// No description provided for @searchMovements.
  ///
  /// In es, this message translates to:
  /// **'Buscar movimientos'**
  String get searchMovements;

  /// No description provided for @noMovements.
  ///
  /// In es, this message translates to:
  /// **'Aquí aparecerá tu plata entrando y saliendo.'**
  String get noMovements;

  /// No description provided for @noMovementsBody.
  ///
  /// In es, this message translates to:
  /// **'Registra un gasto, un ingreso o una transferencia con «Movimiento».'**
  String get noMovementsBody;

  /// No description provided for @noResults.
  ///
  /// In es, this message translates to:
  /// **'Nada coincide con la búsqueda.'**
  String get noResults;

  /// No description provided for @deleteMovementTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este movimiento?'**
  String get deleteMovementTitle;

  /// No description provided for @deleteTransferBody.
  ///
  /// In es, this message translates to:
  /// **'Se eliminan las dos partes de la transferencia.'**
  String get deleteTransferBody;

  /// No description provided for @deleteSplitBody.
  ///
  /// In es, this message translates to:
  /// **'También se quita su división: lo que te deben por este gasto deja de contar.'**
  String get deleteSplitBody;

  /// No description provided for @invalidAmount.
  ///
  /// In es, this message translates to:
  /// **'Escribe un monto'**
  String get invalidAmount;

  /// No description provided for @sameAccount.
  ///
  /// In es, this message translates to:
  /// **'Elige dos cuentas distintas'**
  String get sameAccount;

  /// No description provided for @needAccountFirst.
  ///
  /// In es, this message translates to:
  /// **'Primero agrega una cuenta.'**
  String get needAccountFirst;

  /// No description provided for @recentMovements.
  ///
  /// In es, this message translates to:
  /// **'Últimos movimientos'**
  String get recentMovements;

  /// No description provided for @seeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todos'**
  String get seeAll;

  /// No description provided for @scheduled.
  ///
  /// In es, this message translates to:
  /// **'Programado'**
  String get scheduled;

  /// No description provided for @settingsProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get settingsProfile;

  /// No description provided for @settingsName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get settingsName;

  /// No description provided for @settingsBase.
  ///
  /// In es, this message translates to:
  /// **'Moneda de los totales'**
  String get settingsBase;

  /// No description provided for @settingsPay.
  ///
  /// In es, this message translates to:
  /// **'Cómo te pagan'**
  String get settingsPay;

  /// No description provided for @settingsData.
  ///
  /// In es, this message translates to:
  /// **'Tus datos'**
  String get settingsData;

  /// No description provided for @exportData.
  ///
  /// In es, this message translates to:
  /// **'Exportar mis datos'**
  String get exportData;

  /// No description provided for @exportDone.
  ///
  /// In es, this message translates to:
  /// **'Archivo guardado.'**
  String get exportDone;

  /// No description provided for @settingsPayAmount.
  ///
  /// In es, this message translates to:
  /// **'Lo que te pagan'**
  String get settingsPayAmount;

  /// No description provided for @settingsPayAmountBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que te llega cada pago. Sirve para proyectar los días que vienen; no cuenta como plata hasta que llega.'**
  String get settingsPayAmountBody;

  /// No description provided for @settingsCushion.
  ///
  /// In es, this message translates to:
  /// **'Colchón'**
  String get settingsCushion;

  /// No description provided for @settingsCushionBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que quieres guardar sin tocar. No cuenta en lo que puedes gastar hasta el pago.'**
  String get settingsCushionBody;

  /// No description provided for @settingsNotSet.
  ///
  /// In es, this message translates to:
  /// **'Sin definir'**
  String get settingsNotSet;

  /// No description provided for @settingsRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get settingsRemove;

  /// No description provided for @settingsAmountAboveZero.
  ///
  /// In es, this message translates to:
  /// **'Escribe un monto mayor que cero.'**
  String get settingsAmountAboveZero;

  /// No description provided for @freeExplainCushion.
  ///
  /// In es, this message translates to:
  /// **'Colchón que guardas'**
  String get freeExplainCushion;

  /// No description provided for @freeExplainAssumptions.
  ///
  /// In es, this message translates to:
  /// **'Lo que supone'**
  String get freeExplainAssumptions;

  /// No description provided for @freeExplainAssumeToday.
  ///
  /// In es, this message translates to:
  /// **'Cuenta lo que hay hoy en tus cuentas de uso diario y resta lo que vence hasta el {payday}.'**
  String freeExplainAssumeToday(String payday);

  /// No description provided for @freeExplainAssumePay.
  ///
  /// In es, this message translates to:
  /// **'Tu pago de {pay} del {payday} no cuenta hasta que llegue.'**
  String freeExplainAssumePay(String pay, String payday);

  /// No description provided for @freeExplainAssumeNoPay.
  ///
  /// In es, this message translates to:
  /// **'No sabe cuánto te pagan. Si lo dices en Ajustes, la proyección lo tiene en cuenta.'**
  String get freeExplainAssumeNoPay;

  /// No description provided for @freeExplainAssumeCushion.
  ///
  /// In es, this message translates to:
  /// **'Deja por fuera {cushion} de colchón.'**
  String freeExplainAssumeCushion(String cushion);

  /// No description provided for @freeExplainAssumeNoCushion.
  ///
  /// In es, this message translates to:
  /// **'No tiene colchón. Puedes elegir uno en Ajustes.'**
  String get freeExplainAssumeNoCushion;

  /// No description provided for @payLate.
  ///
  /// In es, this message translates to:
  /// **'Tu pago del {date} todavía no aparece. Si ya llegó, regístralo.'**
  String payLate(String date);

  /// No description provided for @accountExplainTitle.
  ///
  /// In es, this message translates to:
  /// **'Así se llega al saldo'**
  String get accountExplainTitle;

  /// No description provided for @accountExplainOpening.
  ///
  /// In es, this message translates to:
  /// **'Con lo que empezó'**
  String get accountExplainOpening;

  /// No description provided for @accountExplainBalance.
  ///
  /// In es, this message translates to:
  /// **'Saldo hoy'**
  String get accountExplainBalance;

  /// No description provided for @accountExplainAhead.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un movimiento con fecha más adelante ({amount}) todavía no cuenta.} other{{count} movimientos con fecha más adelante ({amount}) todavía no cuentan.}}'**
  String accountExplainAhead(int count, String amount);

  /// No description provided for @traceIncome.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un ingreso} other{{count} ingresos}}'**
  String traceIncome(int count);

  /// No description provided for @traceExpense.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un gasto} other{{count} gastos}}'**
  String traceExpense(int count);

  /// No description provided for @traceTransferIn.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Una transferencia que entró} other{{count} transferencias que entraron}}'**
  String traceTransferIn(int count);

  /// No description provided for @traceTransferOut.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Una transferencia que salió} other{{count} transferencias que salieron}}'**
  String traceTransferOut(int count);

  /// No description provided for @traceBought.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Una compra} other{{count} compras}}'**
  String traceBought(int count);

  /// No description provided for @traceSold.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Una venta} other{{count} ventas}}'**
  String traceSold(int count);

  /// No description provided for @traceAdjustment.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un ajuste} other{{count} ajustes}}'**
  String traceAdjustment(int count);

  /// No description provided for @totalExplainTitle.
  ///
  /// In es, this message translates to:
  /// **'Así se calcula tu patrimonio'**
  String get totalExplainTitle;

  /// No description provided for @totalExplainUnpriced.
  ///
  /// In es, this message translates to:
  /// **'Sin tasa todavía, no suman: {names}.'**
  String totalExplainUnpriced(String names);

  /// No description provided for @computedOnPhone.
  ///
  /// In es, this message translates to:
  /// **'Calculado en tu teléfono'**
  String get computedOnPhone;

  /// No description provided for @computedTitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo se calculó'**
  String get computedTitle;

  /// No description provided for @computedFooter.
  ///
  /// In es, this message translates to:
  /// **'Cada cifra de la respuesta salió de estos cálculos, hechos en tu teléfono con tus datos de {time}, y Gemini solo los explica.'**
  String computedFooter(String time);

  /// No description provided for @computedOverview.
  ///
  /// In es, this message translates to:
  /// **'Tus saldos, lo comprometido, el colchón y lo que puedes gastar hasta el pago'**
  String get computedOverview;

  /// No description provided for @computedMonth.
  ///
  /// In es, this message translates to:
  /// **'Gastos de {month} por categoría, frente al mes anterior'**
  String computedMonth(String month);

  /// No description provided for @computedCategory.
  ///
  /// In es, this message translates to:
  /// **'Pagos de {category} en {month}'**
  String computedCategory(String category, String month);

  /// No description provided for @computedTotals.
  ///
  /// In es, this message translates to:
  /// **'Ingresos y gastos de los últimos meses'**
  String get computedTotals;

  /// No description provided for @computedSubscriptions.
  ///
  /// In es, this message translates to:
  /// **'Tus suscripciones y lo que cuestan al mes'**
  String get computedSubscriptions;

  /// No description provided for @computedGoal.
  ///
  /// In es, this message translates to:
  /// **'Tu meta de ahorro y lo que falta'**
  String get computedGoal;

  /// No description provided for @computedRecord.
  ///
  /// In es, this message translates to:
  /// **'El gasto que se registró'**
  String get computedRecord;

  /// No description provided for @computedAccounts.
  ///
  /// In es, this message translates to:
  /// **'Tus cuentas, cada una en su moneda'**
  String get computedAccounts;

  /// No description provided for @computedPortfolio.
  ///
  /// In es, this message translates to:
  /// **'Tu portafolio cripto con precios del mercado'**
  String get computedPortfolio;

  /// No description provided for @computedSeeFree.
  ///
  /// In es, this message translates to:
  /// **'Ver cómo se calcula lo que puedes gastar'**
  String get computedSeeFree;

  /// No description provided for @comingTitle.
  ///
  /// In es, this message translates to:
  /// **'Próximos 30 días'**
  String get comingTitle;

  /// No description provided for @comingLowest.
  ///
  /// In es, this message translates to:
  /// **'Saldo mínimo estimado antes del pago: {amount} el {date}'**
  String comingLowest(String amount, String date);

  /// No description provided for @comingTight.
  ///
  /// In es, this message translates to:
  /// **'El {date} quedarías bajo tu colchón.'**
  String comingTight(String date);

  /// No description provided for @comingRunsOut.
  ///
  /// In es, this message translates to:
  /// **'El {date} te quedarías sin plata.'**
  String comingRunsOut(String date);

  /// No description provided for @comingRunsOutBadge.
  ///
  /// In es, this message translates to:
  /// **'Sin plata'**
  String get comingRunsOutBadge;

  /// No description provided for @comingNoTight.
  ///
  /// In es, this message translates to:
  /// **'Ningún día bajo tu colchón en estos 30 días.'**
  String get comingNoTight;

  /// No description provided for @comingNoTightZero.
  ///
  /// In es, this message translates to:
  /// **'No te quedas sin plata en estos 30 días.'**
  String get comingNoTightZero;

  /// No description provided for @comingLegendSure.
  ///
  /// In es, this message translates to:
  /// **'Lo seguro'**
  String get comingLegendSure;

  /// No description provided for @comingLegendLikely.
  ///
  /// In es, this message translates to:
  /// **'Con tu pago y lo que pruebas'**
  String get comingLegendLikely;

  /// No description provided for @comingLegendCushion.
  ///
  /// In es, this message translates to:
  /// **'Colchón de {amount}'**
  String comingLegendCushion(String amount);

  /// No description provided for @comingLeft.
  ///
  /// In es, this message translates to:
  /// **'Quedan {amount}'**
  String comingLeft(String amount);

  /// No description provided for @comingLeftTrying.
  ///
  /// In es, this message translates to:
  /// **'con lo que pruebas, {amount}'**
  String comingLeftTrying(String amount);

  /// No description provided for @comingLeftExpected.
  ///
  /// In es, this message translates to:
  /// **'si llega lo que esperas, {amount}'**
  String comingLeftExpected(String amount);

  /// No description provided for @comingUnderCushion.
  ///
  /// In es, this message translates to:
  /// **'Bajo tu colchón'**
  String get comingUnderCushion;

  /// No description provided for @comingPay.
  ///
  /// In es, this message translates to:
  /// **'Tu pago'**
  String get comingPay;

  /// No description provided for @comingLatePay.
  ///
  /// In es, this message translates to:
  /// **'Tu pago atrasado'**
  String get comingLatePay;

  /// No description provided for @comingTryOut.
  ///
  /// In es, this message translates to:
  /// **'Lo que pruebas'**
  String get comingTryOut;

  /// No description provided for @comingMove.
  ///
  /// In es, this message translates to:
  /// **'Mover en la simulación'**
  String get comingMove;

  /// No description provided for @comingSimulation.
  ///
  /// In es, this message translates to:
  /// **'Estás probando: nada de esto se guarda ni cambia tus pagos.'**
  String get comingSimulation;

  /// No description provided for @comingClearSimulation.
  ///
  /// In es, this message translates to:
  /// **'Quitar lo que pruebas'**
  String get comingClearSimulation;

  /// No description provided for @comingNoEvents.
  ///
  /// In es, this message translates to:
  /// **'Nada programado en estos días.'**
  String get comingNoEvents;

  /// No description provided for @comingClose.
  ///
  /// In es, this message translates to:
  /// **'Cierre de la quincena'**
  String get comingClose;

  /// No description provided for @buyTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Me alcanza?'**
  String get buyTitle;

  /// No description provided for @buyPrice.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto cuesta?'**
  String get buyPrice;

  /// No description provided for @buyWhat.
  ///
  /// In es, this message translates to:
  /// **'¿Qué es? (opcional)'**
  String get buyWhat;

  /// No description provided for @buyToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get buyToday;

  /// No description provided for @buyAfterPay.
  ///
  /// In es, this message translates to:
  /// **'Después del pago'**
  String get buyAfterPay;

  /// No description provided for @buyOther.
  ///
  /// In es, this message translates to:
  /// **'Otra fecha'**
  String get buyOther;

  /// No description provided for @buyFits.
  ///
  /// In es, this message translates to:
  /// **'Te alcanza, según lo que sabe la app'**
  String get buyFits;

  /// No description provided for @buyFitsBody.
  ///
  /// In es, this message translates to:
  /// **'Tu saldo mínimo estimado sería {amount} el {date}, por encima de tu colchón.'**
  String buyFitsBody(String amount, String date);

  /// No description provided for @buyFitsBodyNoCushion.
  ///
  /// In es, this message translates to:
  /// **'Tu saldo mínimo estimado sería {amount} el {date}.'**
  String buyFitsBodyNoCushion(String amount, String date);

  /// No description provided for @buyBelow.
  ///
  /// In es, this message translates to:
  /// **'Quedarías por debajo de tu colchón'**
  String get buyBelow;

  /// No description provided for @buyBelowBody.
  ///
  /// In es, this message translates to:
  /// **'El {date} quedarías con {amount}; tu colchón es {cushion}.'**
  String buyBelowBody(String date, String amount, String cushion);

  /// No description provided for @buyShort.
  ///
  /// In es, this message translates to:
  /// **'No alcanza antes del pago'**
  String get buyShort;

  /// No description provided for @buyShortBody.
  ///
  /// In es, this message translates to:
  /// **'El {date} te faltarían {amount}.'**
  String buyShortBody(String date, String amount);

  /// No description provided for @buyReliesOnPay.
  ///
  /// In es, this message translates to:
  /// **'Cuenta con tu pago de {amount} del {date}, que todavía no llega.'**
  String buyReliesOnPay(String amount, String date);

  /// No description provided for @buyPayUnknown.
  ///
  /// In es, this message translates to:
  /// **'No sé cuánto te pagan, así que no lo cuento. Puedes decirlo en Ajustes.'**
  String get buyPayUnknown;

  /// No description provided for @buyEstimate.
  ///
  /// In es, this message translates to:
  /// **'Es una estimación con lo que está programado, no una garantía.'**
  String get buyEstimate;

  /// No description provided for @buyCompareToday.
  ///
  /// In es, this message translates to:
  /// **'Si compras hoy'**
  String get buyCompareToday;

  /// No description provided for @buyCompareAfter.
  ///
  /// In es, this message translates to:
  /// **'Si esperas al {date}'**
  String buyCompareAfter(String date);

  /// No description provided for @buyLowest.
  ///
  /// In es, this message translates to:
  /// **'saldo mínimo: {amount}'**
  String buyLowest(String amount);

  /// No description provided for @closeTitle.
  ///
  /// In es, this message translates to:
  /// **'Cierre de la quincena'**
  String get closeTitle;

  /// No description provided for @closeRange.
  ///
  /// In es, this message translates to:
  /// **'Del {from} al {to}'**
  String closeRange(String from, String to);

  /// No description provided for @closeChanged.
  ///
  /// In es, this message translates to:
  /// **'Qué cambió'**
  String get closeChanged;

  /// No description provided for @closeComing.
  ///
  /// In es, this message translates to:
  /// **'Qué viene'**
  String get closeComing;

  /// No description provided for @closeAction.
  ///
  /// In es, this message translates to:
  /// **'Una acción posible'**
  String get closeAction;

  /// No description provided for @closeSpentMore.
  ///
  /// In es, this message translates to:
  /// **'Gastaste {spent}, {difference} más que la quincena anterior.'**
  String closeSpentMore(String spent, String difference);

  /// No description provided for @closeSpentLess.
  ///
  /// In es, this message translates to:
  /// **'Gastaste {spent}, {difference} menos que la quincena anterior.'**
  String closeSpentLess(String spent, String difference);

  /// No description provided for @closeSpentSame.
  ///
  /// In es, this message translates to:
  /// **'Gastaste {spent}, lo mismo que la quincena anterior.'**
  String closeSpentSame(String spent);

  /// No description provided for @closeSpentFirst.
  ///
  /// In es, this message translates to:
  /// **'Gastaste {spent}. Es tu primera quincena completa registrada: todavía no hay con qué compararla.'**
  String closeSpentFirst(String spent);

  /// No description provided for @closeNone.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay una quincena completa registrada. El cierre aparece cuando haya una, de un pago al siguiente.'**
  String get closeNone;

  /// No description provided for @closeComingTotal.
  ///
  /// In es, this message translates to:
  /// **'Hasta el {date} hay {amount} comprometidos.'**
  String closeComingTotal(String date, String amount);

  /// No description provided for @closeComingNone.
  ///
  /// In es, this message translates to:
  /// **'No hay nada comprometido hasta el {date}.'**
  String closeComingNone(String date);

  /// No description provided for @closeComingMore.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Y uno más.} other{Y {count} más.}}'**
  String closeComingMore(int count);

  /// No description provided for @closeFree.
  ///
  /// In es, this message translates to:
  /// **'Puedes gastar hasta el pago: {amount}'**
  String closeFree(String amount);

  /// No description provided for @closeShort.
  ///
  /// In es, this message translates to:
  /// **'Te faltan {amount} para llegar al pago'**
  String closeShort(String amount);

  /// No description provided for @closeSeeDays.
  ///
  /// In es, this message translates to:
  /// **'Ver los próximos 30 días'**
  String get closeSeeDays;

  /// No description provided for @closeActionRunsOut.
  ///
  /// In es, this message translates to:
  /// **'El {date} te quedarías sin plata. Mira qué cobro podrías mover de fecha.'**
  String closeActionRunsOut(String date);

  /// No description provided for @closeActionTight.
  ///
  /// In es, this message translates to:
  /// **'El {date} quedarías bajo tu colchón. Mira qué cobro podrías mover de fecha.'**
  String closeActionTight(String date);

  /// No description provided for @closeActionCategory.
  ///
  /// In es, this message translates to:
  /// **'{category} pasó de {before} a {now} frente a la quincena anterior. Mira esos pagos.'**
  String closeActionCategory(String category, String before, String now);

  /// No description provided for @closeActionGoal.
  ///
  /// In es, this message translates to:
  /// **'Puedes gastar {amount} hasta el pago. Si quieres, una parte puede ir a tu meta.'**
  String closeActionGoal(String amount);

  /// No description provided for @closeActionNone.
  ///
  /// In es, this message translates to:
  /// **'Nada que ajustar esta vez.'**
  String get closeActionNone;

  /// No description provided for @closePaymentsNone.
  ///
  /// In es, this message translates to:
  /// **'En esta quincena no hubo pagos de {category}. Estos son los de la anterior:'**
  String closePaymentsNone(String category);

  /// No description provided for @closeSeePayments.
  ///
  /// In es, this message translates to:
  /// **'Ver los pagos'**
  String get closeSeePayments;

  /// No description provided for @closePaymentsTitle.
  ///
  /// In es, this message translates to:
  /// **'{category} del {from} al {to}'**
  String closePaymentsTitle(String category, String from, String to);

  /// No description provided for @homeComing.
  ///
  /// In es, this message translates to:
  /// **'Próximos días'**
  String get homeComing;

  /// No description provided for @homeSeeDays.
  ///
  /// In es, this message translates to:
  /// **'Ver 30 días'**
  String get homeSeeDays;

  /// No description provided for @buyWithoutPay.
  ///
  /// In es, this message translates to:
  /// **'sin contar tu pago'**
  String get buyWithoutPay;

  /// No description provided for @closeSpentNone.
  ///
  /// In es, this message translates to:
  /// **'No registraste gastos en esta quincena.'**
  String get closeSpentNone;

  /// No description provided for @comingLowestWithout.
  ///
  /// In es, this message translates to:
  /// **'Sin lo que pruebas, saldo mínimo estimado antes del pago: {amount} el {date}'**
  String comingLowestWithout(String amount, String date);

  /// No description provided for @computedBuy.
  ///
  /// In es, this message translates to:
  /// **'Cómo quedaría tu plata con esa compra hasta el pago, hoy y después del pago'**
  String get computedBuy;

  /// No description provided for @computedComing.
  ///
  /// In es, this message translates to:
  /// **'Tu plata en los próximos 30 días, día por día'**
  String get computedComing;

  /// No description provided for @computedClose.
  ///
  /// In es, this message translates to:
  /// **'El cierre de tu última quincena, frente a la anterior'**
  String get computedClose;

  /// No description provided for @remindersTitle.
  ///
  /// In es, this message translates to:
  /// **'Avisos'**
  String get remindersTitle;

  /// No description provided for @remindersClose.
  ///
  /// In es, this message translates to:
  /// **'Avisarme el día de pago'**
  String get remindersClose;

  /// No description provided for @remindersCloseHelp.
  ///
  /// In es, this message translates to:
  /// **'Un aviso sin montos para ver el cierre de la quincena. Nada de tu plata aparece en la pantalla bloqueada.'**
  String get remindersCloseHelp;

  /// No description provided for @remindersDenied.
  ///
  /// In es, this message translates to:
  /// **'Para los avisos, permite las notificaciones de Quincena en los ajustes del teléfono.'**
  String get remindersDenied;

  /// No description provided for @reminderTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu cierre de quincena está listo'**
  String get reminderTitle;

  /// No description provided for @reminderBody.
  ///
  /// In es, this message translates to:
  /// **'Ábrelo para ver qué cambió y qué viene.'**
  String get reminderBody;

  /// No description provided for @tabPlan.
  ///
  /// In es, this message translates to:
  /// **'Plan'**
  String get tabPlan;

  /// No description provided for @goalIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Ponle un nombre y cuánto quieres juntar.'**
  String get goalIncomplete;

  /// No description provided for @goalDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar «{name}»?'**
  String goalDeleteTitle(String name);

  /// No description provided for @goalDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se borra la meta. Tus cuentas y movimientos no cambian.'**
  String get goalDeleteBody;

  /// No description provided for @goalDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar meta'**
  String get goalDelete;

  /// No description provided for @goalAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar meta'**
  String get goalAdd;

  /// No description provided for @goalEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar meta'**
  String get goalEdit;

  /// No description provided for @goalName.
  ///
  /// In es, this message translates to:
  /// **'¿Para qué es?'**
  String get goalName;

  /// No description provided for @goalTarget.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto quieres juntar?'**
  String get goalTarget;

  /// No description provided for @goalSaved.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto llevas?'**
  String get goalSaved;

  /// No description provided for @goalMonthly.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto pones al mes?'**
  String get goalMonthly;

  /// No description provided for @goalNoDeadline.
  ///
  /// In es, this message translates to:
  /// **'Sin fecha límite'**
  String get goalNoDeadline;

  /// No description provided for @goalBy.
  ///
  /// In es, this message translates to:
  /// **'Para el {date}'**
  String goalBy(String date);

  /// No description provided for @goalSavedOf.
  ///
  /// In es, this message translates to:
  /// **'Llevas {saved} de {target}'**
  String goalSavedOf(String saved, String target);

  /// No description provided for @goalArrives.
  ///
  /// In es, this message translates to:
  /// **'llega en {date}'**
  String goalArrives(String date);

  /// No description provided for @goalNoMonthly.
  ///
  /// In es, this message translates to:
  /// **'sin aporte al mes, no tiene fecha'**
  String get goalNoMonthly;

  /// No description provided for @envelopeAside.
  ///
  /// In es, this message translates to:
  /// **'Apartar para algo'**
  String get envelopeAside;

  /// No description provided for @envelopeAsideHint.
  ///
  /// In es, this message translates to:
  /// **'Regalo, matrícula, viaje…'**
  String get envelopeAsideHint;

  /// No description provided for @envelopesOverTitle.
  ///
  /// In es, this message translates to:
  /// **'Asignas más de lo que hay'**
  String get envelopesOverTitle;

  /// No description provided for @envelopesOver.
  ///
  /// In es, this message translates to:
  /// **'Los sobres suman {amount} más de lo que tienes para repartir. Puedes guardarlos así, pero esa plata no existe todavía.'**
  String envelopesOver(String amount);

  /// No description provided for @envelopesFix.
  ///
  /// In es, this message translates to:
  /// **'Ajustar'**
  String get envelopesFix;

  /// No description provided for @envelopesSaveAnyway.
  ///
  /// In es, this message translates to:
  /// **'Guardar así'**
  String get envelopesSaveAnyway;

  /// No description provided for @envelopesTitle.
  ///
  /// In es, this message translates to:
  /// **'Reparte tu quincena'**
  String get envelopesTitle;

  /// No description provided for @envelopesPeriod.
  ///
  /// In es, this message translates to:
  /// **'Del {from} al {to}.'**
  String envelopesPeriod(String from, String to);

  /// No description provided for @envelopesToSplit.
  ///
  /// In es, this message translates to:
  /// **'Para repartir'**
  String get envelopesToSplit;

  /// No description provided for @envelopesToSplitBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que hay para gastar, menos {committed} comprometidos hasta el pago y {cushion} de colchón.'**
  String envelopesToSplitBody(String committed, String cushion);

  /// No description provided for @envelopesToSplitBodyReserve.
  ///
  /// In es, this message translates to:
  /// **'Lo que hay para gastar, menos {committed} comprometidos hasta el pago, {cushion} de colchón y {reserve} de la reserva de ingresos variables.'**
  String envelopesToSplitBodyReserve(
    String committed,
    String cushion,
    String reserve,
  );

  /// No description provided for @envelopeDaily.
  ///
  /// In es, this message translates to:
  /// **'Día a día'**
  String get envelopeDaily;

  /// No description provided for @envelopeDailyHelp.
  ///
  /// In es, this message translates to:
  /// **'Mercado, transporte, salidas: lo que se gasta hasta el pago.'**
  String get envelopeDailyHelp;

  /// No description provided for @envelopeGoalHelp.
  ///
  /// In es, this message translates to:
  /// **'Apartado para tu meta: deja de contar en lo que puedes gastar.'**
  String get envelopeGoalHelp;

  /// No description provided for @envelopeAsideHelp.
  ///
  /// In es, this message translates to:
  /// **'Apartado: deja de contar en lo que puedes gastar.'**
  String get envelopeAsideHelp;

  /// No description provided for @envelopeRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar sobre'**
  String get envelopeRemove;

  /// No description provided for @envelopesOverShort.
  ///
  /// In es, this message translates to:
  /// **'Te pasas por'**
  String get envelopesOverShort;

  /// No description provided for @envelopesFree.
  ///
  /// In es, this message translates to:
  /// **'Sin asignar'**
  String get envelopesFree;

  /// No description provided for @envelopesOnPaper.
  ///
  /// In es, this message translates to:
  /// **'Los sobres no mueven plata: tu banco no se entera. Solo dicen qué parte de lo que tienes es para qué, y lo apartado sale de lo que puedes gastar hasta el pago.'**
  String get envelopesOnPaper;

  /// No description provided for @envelopesSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar el reparto'**
  String get envelopesSave;

  /// No description provided for @cushionDaysTitle.
  ///
  /// In es, this message translates to:
  /// **'Colchón en días'**
  String get cushionDaysTitle;

  /// No description provided for @cushionDaysCovers.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, =1{Cubre un día de gastos esenciales} other{Cubre unos {days} días de gastos esenciales}}'**
  String cushionDaysCovers(int days);

  /// No description provided for @cushionDaysNoReserve.
  ///
  /// In es, this message translates to:
  /// **'Elige abajo las cuentas donde guardas tu fondo de emergencia.'**
  String get cushionDaysNoReserve;

  /// No description provided for @cushionDaysShortHistory.
  ///
  /// In es, this message translates to:
  /// **'Con menos de un mes de movimientos todavía no hay un promedio confiable. Vuelve en unas semanas.'**
  String get cushionDaysShortHistory;

  /// No description provided for @cushionDaysNoEssential.
  ///
  /// In es, this message translates to:
  /// **'No hay gastos en las categorías esenciales que elegiste, así que no se puede contar en días. Revisa las categorías.'**
  String get cushionDaysNoEssential;

  /// No description provided for @cushionDaysHow.
  ///
  /// In es, this message translates to:
  /// **'{reserve} entre {daily} al día, lo que promediaron tus gastos esenciales del {from} al {to}.'**
  String cushionDaysHow(String reserve, String daily, String from, String to);

  /// No description provided for @cushionDaysReached.
  ///
  /// In es, this message translates to:
  /// **'Llegaste a los {days} días que te propusiste.'**
  String cushionDaysReached(int days);

  /// No description provided for @cushionDaysToGo.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, =1{Te falta un día: {amount}.} other{Te faltan {days} días: {amount}.}}'**
  String cushionDaysToGo(int days, String amount);

  /// No description provided for @cushionDaysEstimate.
  ///
  /// In es, this message translates to:
  /// **'Es un promedio: un mes con gastos distintos cambia la cuenta.'**
  String get cushionDaysEstimate;

  /// No description provided for @cushionDaysAccounts.
  ///
  /// In es, this message translates to:
  /// **'Dónde está tu colchón'**
  String get cushionDaysAccounts;

  /// No description provided for @cushionDaysEssentials.
  ///
  /// In es, this message translates to:
  /// **'Qué es esencial para ti'**
  String get cushionDaysEssentials;

  /// No description provided for @cushionDaysTarget.
  ///
  /// In es, this message translates to:
  /// **'Cuántos días quieres cubrir'**
  String get cushionDaysTarget;

  /// No description provided for @cushionDaysNoTarget.
  ///
  /// In es, this message translates to:
  /// **'Sin meta'**
  String get cushionDaysNoTarget;

  /// No description provided for @cushionDaysOption.
  ///
  /// In es, this message translates to:
  /// **'{days} días'**
  String cushionDaysOption(int days);

  /// No description provided for @cushionDaysTargetNote.
  ///
  /// In es, this message translates to:
  /// **'No hay una cifra correcta para todos: elige la que te dé tranquilidad.'**
  String get cushionDaysTargetNote;

  /// No description provided for @wishesTitle.
  ///
  /// In es, this message translates to:
  /// **'Lo quiero, pero después'**
  String get wishesTitle;

  /// No description provided for @wishAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar deseo'**
  String get wishAdd;

  /// No description provided for @wishesBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que quieres comprar más adelante, con el precio que tú pones. Nada se compra ni se sigue en ninguna tienda.'**
  String get wishesBody;

  /// No description provided for @wishesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay deseos.'**
  String get wishesEmpty;

  /// No description provided for @wishPriorityHigh.
  ///
  /// In es, this message translates to:
  /// **'Muy deseado'**
  String get wishPriorityHigh;

  /// No description provided for @wishPriorityMedium.
  ///
  /// In es, this message translates to:
  /// **'Deseado'**
  String get wishPriorityMedium;

  /// No description provided for @wishPriorityLow.
  ///
  /// In es, this message translates to:
  /// **'Si sobra'**
  String get wishPriorityLow;

  /// No description provided for @wishRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar deseo'**
  String get wishRemove;

  /// No description provided for @wishWaiting.
  ///
  /// In es, this message translates to:
  /// **'Esperas hasta el {date} para decidir.'**
  String wishWaiting(String date);

  /// No description provided for @wishAgainstGoal.
  ///
  /// In es, this message translates to:
  /// **'Si lo compras, {goal} llegaría en {after} en vez de {before}.'**
  String wishAgainstGoal(String goal, String after, String before);

  /// No description provided for @wishIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Ponle un nombre y un precio.'**
  String get wishIncomplete;

  /// No description provided for @wishName.
  ///
  /// In es, this message translates to:
  /// **'¿Qué quieres?'**
  String get wishName;

  /// No description provided for @wishPrice.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto cuesta?'**
  String get wishPrice;

  /// No description provided for @wishWait.
  ///
  /// In es, this message translates to:
  /// **'Esperar 30 días antes de decidir'**
  String get wishWait;

  /// No description provided for @wishWaitHelp.
  ///
  /// In es, this message translates to:
  /// **'Si en un mes lo sigues queriendo, decides con calma.'**
  String get wishWaitHelp;

  /// No description provided for @whatIfTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Y si…?'**
  String get whatIfTitle;

  /// No description provided for @whatIfSaveMore.
  ///
  /// In es, this message translates to:
  /// **'Ahorro más'**
  String get whatIfSaveMore;

  /// No description provided for @whatIfChargeUp.
  ///
  /// In es, this message translates to:
  /// **'Sube un gasto'**
  String get whatIfChargeUp;

  /// No description provided for @whatIfPayLate.
  ///
  /// In es, this message translates to:
  /// **'Pago tarde'**
  String get whatIfPayLate;

  /// No description provided for @whatIfSaveMoreSaid.
  ///
  /// In es, this message translates to:
  /// **'Apartar {amount} más en cada pago'**
  String whatIfSaveMoreSaid(String amount);

  /// No description provided for @whatIfChargeUpSaid.
  ///
  /// In es, this message translates to:
  /// **'{charge} sube {amount}'**
  String whatIfChargeUpSaid(String charge, String amount);

  /// No description provided for @whatIfPayLateSaid.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, =1{El pago llega un día tarde} other{El pago llega {days} días tarde}}'**
  String whatIfPayLateSaid(int days);

  /// No description provided for @whatIfApplyTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Aplicar el cambio?'**
  String get whatIfApplyTitle;

  /// No description provided for @whatIfApplyCharge.
  ///
  /// In es, this message translates to:
  /// **'{charge} quedará en {amount} desde su próximo cobro. Lo ya registrado no cambia.'**
  String whatIfApplyCharge(String charge, String amount);

  /// No description provided for @whatIfApplySave.
  ///
  /// In es, this message translates to:
  /// **'Esto cambia tu plan desde ahora.'**
  String get whatIfApplySave;

  /// No description provided for @whatIfApply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get whatIfApply;

  /// No description provided for @whatIfNoCharges.
  ///
  /// In es, this message translates to:
  /// **'No tienes cobros programados en las próximas semanas.'**
  String get whatIfNoCharges;

  /// No description provided for @whatIfSaveMoreAmount.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto más en cada pago?'**
  String get whatIfSaveMoreAmount;

  /// No description provided for @whatIfChargeUpAmount.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto sube?'**
  String get whatIfChargeUpAmount;

  /// No description provided for @whatIfNeedsPay.
  ///
  /// In es, this message translates to:
  /// **'Para probar un pago tarde, di en Ajustes cuánto te pagan.'**
  String get whatIfNeedsPay;

  /// No description provided for @whatIfPayLateDays.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, =1{Un día tarde} other{{days} días tarde}}'**
  String whatIfPayLateDays(int days);

  /// No description provided for @whatIfFewerDays.
  ///
  /// In es, this message translates to:
  /// **'Menos días'**
  String get whatIfFewerDays;

  /// No description provided for @whatIfMoreDays.
  ///
  /// In es, this message translates to:
  /// **'Más días'**
  String get whatIfMoreDays;

  /// No description provided for @whatIfLowest.
  ///
  /// In es, this message translates to:
  /// **'Saldo mínimo en 45 días'**
  String get whatIfLowest;

  /// No description provided for @whatIfTight.
  ///
  /// In es, this message translates to:
  /// **'Primer día bajo tu colchón'**
  String get whatIfTight;

  /// No description provided for @whatIfNoTight.
  ///
  /// In es, this message translates to:
  /// **'ninguno'**
  String get whatIfNoTight;

  /// No description provided for @whatIfEnd.
  ///
  /// In es, this message translates to:
  /// **'Al {date}'**
  String whatIfEnd(String date);

  /// No description provided for @whatIfGoal.
  ///
  /// In es, this message translates to:
  /// **'{goal} llega en'**
  String whatIfGoal(String goal);

  /// No description provided for @whatIfGoalNever.
  ///
  /// In es, this message translates to:
  /// **'sin fecha'**
  String get whatIfGoalNever;

  /// No description provided for @whatIfAssumes.
  ///
  /// In es, this message translates to:
  /// **'Cuenta tu pago esperado y lo programado; nada de esto cambia tus cuentas.'**
  String get whatIfAssumes;

  /// No description provided for @whatIfSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar el escenario'**
  String get whatIfSave;

  /// No description provided for @whatIfSaved.
  ///
  /// In es, this message translates to:
  /// **'Escenarios guardados'**
  String get whatIfSaved;

  /// No description provided for @whatIfSavedOutcome.
  ///
  /// In es, this message translates to:
  /// **'Saldo mínimo: {amount} el {date}'**
  String whatIfSavedOutcome(String amount, String date);

  /// No description provided for @whatIfRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar escenario'**
  String get whatIfRemove;

  /// No description provided for @whatIfToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get whatIfToday;

  /// No description provided for @whatIfWith.
  ///
  /// In es, this message translates to:
  /// **'Con el cambio'**
  String get whatIfWith;

  /// No description provided for @planPeriod.
  ///
  /// In es, this message translates to:
  /// **'Presupuesto hasta el {date}'**
  String planPeriod(String date);

  /// No description provided for @planGoals.
  ///
  /// In es, this message translates to:
  /// **'Metas'**
  String get planGoals;

  /// No description provided for @planNoGoals.
  ///
  /// In es, this message translates to:
  /// **'Todavía no tienes metas. Una meta con aporte al mes te dice cuándo llegas.'**
  String get planNoGoals;

  /// No description provided for @planTools.
  ///
  /// In es, this message translates to:
  /// **'Herramientas'**
  String get planTools;

  /// No description provided for @planCushionChoose.
  ///
  /// In es, this message translates to:
  /// **'Elige dónde está tu fondo de emergencia'**
  String get planCushionChoose;

  /// No description provided for @planCushionSoon.
  ///
  /// In es, this message translates to:
  /// **'Todavía no se puede contar en días'**
  String get planCushionSoon;

  /// No description provided for @planWishesNone.
  ///
  /// In es, this message translates to:
  /// **'Guarda lo que quieres para después'**
  String get planWishesNone;

  /// No description provided for @planWishes.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un deseo} other{{count} deseos}}'**
  String planWishes(int count);

  /// No description provided for @planWhatIf.
  ///
  /// In es, this message translates to:
  /// **'Prueba un cambio sin aplicarlo'**
  String get planWhatIf;

  /// No description provided for @planComing.
  ///
  /// In es, this message translates to:
  /// **'Los días que vienen, con los apretados marcados'**
  String get planComing;

  /// No description provided for @planSplitTitle.
  ///
  /// In es, this message translates to:
  /// **'Reparte esta quincena'**
  String get planSplitTitle;

  /// No description provided for @planSplitBody.
  ///
  /// In es, this message translates to:
  /// **'Tienes {amount} para repartir entre el día a día, tus metas y lo que quieras apartar.'**
  String planSplitBody(String amount);

  /// No description provided for @planSplit.
  ///
  /// In es, this message translates to:
  /// **'Repartir en sobres'**
  String get planSplit;

  /// No description provided for @planDailySpent.
  ///
  /// In es, this message translates to:
  /// **'Llevas {spent} de {daily}'**
  String planDailySpent(String spent, String daily);

  /// No description provided for @planDailyOver.
  ///
  /// In es, this message translates to:
  /// **'Te pasaste por {amount}'**
  String planDailyOver(String amount);

  /// No description provided for @planAdjust.
  ///
  /// In es, this message translates to:
  /// **'Ajustar el reparto'**
  String get planAdjust;

  /// No description provided for @freeExplainSetAside.
  ///
  /// In es, this message translates to:
  /// **'Apartado en sobres'**
  String get freeExplainSetAside;

  /// No description provided for @paydayArrived.
  ///
  /// In es, this message translates to:
  /// **'Te llegó la quincena'**
  String get paydayArrived;

  /// No description provided for @freeExplainAction.
  ///
  /// In es, this message translates to:
  /// **'¿De dónde sale?'**
  String get freeExplainAction;

  /// No description provided for @freeExplainTitle.
  ///
  /// In es, this message translates to:
  /// **'Así se calcula lo que puedes gastar'**
  String get freeExplainTitle;

  /// No description provided for @freeExplainSpendable.
  ///
  /// In es, this message translates to:
  /// **'En tus cuentas de uso diario'**
  String get freeExplainSpendable;

  /// No description provided for @freeExplainCommitted.
  ///
  /// In es, this message translates to:
  /// **'Pagos hasta el {date}'**
  String freeExplainCommitted(String date);

  /// No description provided for @freeExplainNothingCommitted.
  ///
  /// In es, this message translates to:
  /// **'Nada programado hasta el {date}.'**
  String freeExplainNothingCommitted(String date);

  /// No description provided for @freeExplainLeftOut.
  ///
  /// In es, this message translates to:
  /// **'No cuentan'**
  String get freeExplainLeftOut;

  /// No description provided for @freeExplainLeftOutBody.
  ///
  /// In es, this message translates to:
  /// **'{names}: las marcaste como ahorro o inversión, no como plata para gastar. Puedes cambiarlo en cada cuenta.'**
  String freeExplainLeftOutBody(String names);

  /// No description provided for @freeExplainUnpriced.
  ///
  /// In es, this message translates to:
  /// **'Sin tasa todavía, cuentan como cero: {codes}.'**
  String freeExplainUnpriced(String codes);

  /// No description provided for @freeExplainEstimate.
  ///
  /// In es, this message translates to:
  /// **'Es una estimación: cuenta lo que ya pasó y lo que está programado hasta el pago. Lo que gastes o recibas sin programarlo la cambia.'**
  String get freeExplainEstimate;

  /// No description provided for @freeExplainHeldAt.
  ///
  /// In es, this message translates to:
  /// **'{held} a {rate}'**
  String freeExplainHeldAt(String held, String rate);

  /// No description provided for @importData.
  ///
  /// In es, this message translates to:
  /// **'Importar un archivo'**
  String get importData;

  /// No description provided for @importConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Reemplazar todo con este archivo?'**
  String get importConfirmTitle;

  /// No description provided for @importConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que tienes ahora en Quincena se borra y queda lo del archivo.'**
  String get importConfirmBody;

  /// No description provided for @importConfirm.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar'**
  String get importConfirm;

  /// No description provided for @importDone.
  ///
  /// In es, this message translates to:
  /// **'Datos importados.'**
  String get importDone;

  /// No description provided for @importNotQuincena.
  ///
  /// In es, this message translates to:
  /// **'Ese archivo no lo exportó Quincena. No se cambió nada.'**
  String get importNotQuincena;

  /// No description provided for @importNewer.
  ///
  /// In es, this message translates to:
  /// **'Ese archivo viene de una versión más nueva de Quincena. Actualiza la app y vuelve a intentarlo; no se cambió nada.'**
  String get importNewer;

  /// No description provided for @importDamaged.
  ///
  /// In es, this message translates to:
  /// **'Ese archivo está dañado o incompleto. No se cambió nada.'**
  String get importDamaged;

  /// No description provided for @deleteAll.
  ///
  /// In es, this message translates to:
  /// **'Borrar todo'**
  String get deleteAll;

  /// No description provided for @deleteAllTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar todos tus datos?'**
  String get deleteAllTitle;

  /// No description provided for @deleteAllBody.
  ///
  /// In es, this message translates to:
  /// **'Cuentas, movimientos y ajustes se borran de este dispositivo. No se puede deshacer; exporta primero si quieres conservarlos.'**
  String get deleteAllBody;

  /// No description provided for @useDemo.
  ///
  /// In es, this message translates to:
  /// **'Ver los datos de ejemplo'**
  String get useDemo;

  /// No description provided for @useOwn.
  ///
  /// In es, this message translates to:
  /// **'Usar con mis cuentas'**
  String get useOwn;

  /// No description provided for @backToOwn.
  ///
  /// In es, this message translates to:
  /// **'Volver a mis cuentas'**
  String get backToOwn;

  /// No description provided for @privacyTitle.
  ///
  /// In es, this message translates to:
  /// **'Privacidad'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In es, this message translates to:
  /// **'Tus cuentas y movimientos se guardan solo en este dispositivo. Quincena no tiene un servidor con tus finanzas, no muestra publicidad y no vende tus datos. La política explica qué va a Gemini, a Binance o a las fuentes de precios, y cuándo.'**
  String get privacyBody;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @inboxTitle.
  ///
  /// In es, this message translates to:
  /// **'Por revisar'**
  String get inboxTitle;

  /// No description provided for @inboxBanner.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Revisa 1 movimiento para actualizar tu saldo} other{Revisa {count} movimientos para actualizar tu saldo}}'**
  String inboxBanner(int count);

  /// No description provided for @inboxBannerBody.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Aún no cuenta en lo que puedes gastar.} other{Aún no cuentan en lo que puedes gastar.}}'**
  String inboxBannerBody(int count);

  /// No description provided for @inboxEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todo al día.'**
  String get inboxEmpty;

  /// No description provided for @inboxEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'No tienes movimientos pendientes. Cuando llegue un pago de tu banco, aparece aquí para registrarlo.'**
  String get inboxEmptyBody;

  /// No description provided for @edit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get edit;

  /// No description provided for @dismiss.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get dismiss;

  /// No description provided for @dismissAndMute.
  ///
  /// In es, this message translates to:
  /// **'Descartar y no leer más {app}'**
  String dismissAndMute(String app);

  /// No description provided for @chooseAccount.
  ///
  /// In es, this message translates to:
  /// **'Elegir la cuenta'**
  String get chooseAccount;

  /// No description provided for @noMerchant.
  ///
  /// In es, this message translates to:
  /// **'Sin comercio'**
  String get noMerchant;

  /// No description provided for @sourceWallet.
  ///
  /// In es, this message translates to:
  /// **'Apple Pay'**
  String get sourceWallet;

  /// No description provided for @sourceNotification.
  ///
  /// In es, this message translates to:
  /// **'Notificación'**
  String get sourceNotification;

  /// No description provided for @sourceSms.
  ///
  /// In es, this message translates to:
  /// **'SMS'**
  String get sourceSms;

  /// No description provided for @sourceEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get sourceEmail;

  /// No description provided for @sourceScreenshot.
  ///
  /// In es, this message translates to:
  /// **'Captura de pantalla'**
  String get sourceScreenshot;

  /// No description provided for @sourcePaste.
  ///
  /// In es, this message translates to:
  /// **'Pegado'**
  String get sourcePaste;

  /// No description provided for @nearbyPlace.
  ///
  /// In es, this message translates to:
  /// **'Cerca: {name}, a {metres} m · © colaboradores de OpenStreetMap'**
  String nearbyPlace(String name, int metres);

  /// No description provided for @possibleDuplicates.
  ///
  /// In es, this message translates to:
  /// **'Posibles repetidos'**
  String get possibleDuplicates;

  /// No description provided for @duplicateLine.
  ///
  /// In es, this message translates to:
  /// **'El mismo pago ya llegó por otra vía.'**
  String get duplicateLine;

  /// No description provided for @notDuplicate.
  ///
  /// In es, this message translates to:
  /// **'No es repetido'**
  String get notDuplicate;

  /// No description provided for @whyLabel.
  ///
  /// In es, this message translates to:
  /// **'Sugerido porque {reasons}.'**
  String whyLabel(String reasons);

  /// No description provided for @whyCard.
  ///
  /// In es, this message translates to:
  /// **'la tarjeta *{digits} es de {account}'**
  String whyCard(String digits, String account);

  /// No description provided for @whyInstitution.
  ///
  /// In es, this message translates to:
  /// **'las alertas de {institution} van a {account}'**
  String whyInstitution(String institution, String account);

  /// No description provided for @whyInstitutionSame.
  ///
  /// In es, this message translates to:
  /// **'llegó de tu cuenta de {institution}'**
  String whyInstitutionSame(String institution);

  /// No description provided for @whyCurrency.
  ///
  /// In es, this message translates to:
  /// **'es tu única cuenta en {asset}'**
  String whyCurrency(String asset);

  /// No description provided for @whyOnly.
  ///
  /// In es, this message translates to:
  /// **'es tu única cuenta de uso diario en {asset}; revísala'**
  String whyOnly(String asset);

  /// No description provided for @whyLearned.
  ///
  /// In es, this message translates to:
  /// **'así registraste {merchant} antes'**
  String whyLearned(String merchant);

  /// No description provided for @whyMerchant.
  ///
  /// In es, this message translates to:
  /// **'reconocimos {merchant}'**
  String whyMerchant(String merchant);

  /// No description provided for @whyWords.
  ///
  /// In es, this message translates to:
  /// **'el mensaje dice de qué es'**
  String get whyWords;

  /// No description provided for @ruleLearnedMerchant.
  ///
  /// In es, this message translates to:
  /// **'Desde ahora, «{merchant}» va a {category}.'**
  String ruleLearnedMerchant(String merchant, String category);

  /// No description provided for @ruleLearnedCard.
  ///
  /// In es, this message translates to:
  /// **'Desde ahora, la tarjeta *{digits} va a {account}.'**
  String ruleLearnedCard(String digits, String account);

  /// No description provided for @ruleLearnedInstitution.
  ///
  /// In es, this message translates to:
  /// **'Desde ahora, lo de {institution} va a {account}.'**
  String ruleLearnedInstitution(String institution, String account);

  /// No description provided for @ruleLearnedMore.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Y una regla más.} other{Y {count} reglas más.}}'**
  String ruleLearnedMore(int count);

  /// No description provided for @ruleMissingAccount.
  ///
  /// In es, this message translates to:
  /// **'una cuenta que ya no está'**
  String get ruleMissingAccount;

  /// No description provided for @ruleCardKey.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta *{digits}'**
  String ruleCardKey(String digits);

  /// No description provided for @rulesTitle.
  ///
  /// In es, this message translates to:
  /// **'Reglas aprendidas'**
  String get rulesTitle;

  /// No description provided for @rulesBody.
  ///
  /// In es, this message translates to:
  /// **'Se crean cuando registras algo en Por revisar. Una regla cambia lo que llegue después y lo que aún espera ahí: lo ya registrado se queda como está.'**
  String get rulesBody;

  /// No description provided for @rulesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay reglas. Aparecen cuando registras tus primeros movimientos.'**
  String get rulesEmpty;

  /// No description provided for @rulesMerchants.
  ///
  /// In es, this message translates to:
  /// **'Comercios'**
  String get rulesMerchants;

  /// No description provided for @rulesCards.
  ///
  /// In es, this message translates to:
  /// **'Tarjetas'**
  String get rulesCards;

  /// No description provided for @rulesInstitutions.
  ///
  /// In es, this message translates to:
  /// **'Bancos y billeteras'**
  String get rulesInstitutions;

  /// No description provided for @rulesCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Ninguna todavía} =1{Una regla} other{{count} reglas}}'**
  String rulesCount(int count);

  /// No description provided for @ruleDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar regla'**
  String get ruleDelete;

  /// No description provided for @ruleOn.
  ///
  /// In es, this message translates to:
  /// **'Usar esta regla'**
  String get ruleOn;

  /// No description provided for @ruleChooseCategory.
  ///
  /// In es, this message translates to:
  /// **'¿A qué categoría va?'**
  String get ruleChooseCategory;

  /// No description provided for @ruleChooseAccount.
  ///
  /// In es, this message translates to:
  /// **'¿A qué cuenta va?'**
  String get ruleChooseAccount;

  /// No description provided for @autoRecordedBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que la app registró sola en las últimas dos semanas. Si algo no va, deshazlo y vuelve a Por revisar.'**
  String get autoRecordedBody;

  /// No description provided for @fixMovement.
  ///
  /// In es, this message translates to:
  /// **'Corregir'**
  String get fixMovement;

  /// No description provided for @recordedAutomatically.
  ///
  /// In es, this message translates to:
  /// **'Registrado automáticamente'**
  String get recordedAutomatically;

  /// No description provided for @undo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get undo;

  /// No description provided for @pasteMessage.
  ///
  /// In es, this message translates to:
  /// **'Pegar un mensaje'**
  String get pasteMessage;

  /// No description provided for @pasteHint.
  ///
  /// In es, this message translates to:
  /// **'Pega aquí el mensaje o la notificación del banco'**
  String get pasteHint;

  /// No description provided for @pasteRead.
  ///
  /// In es, this message translates to:
  /// **'Leer'**
  String get pasteRead;

  /// No description provided for @pasteAdded.
  ///
  /// In es, this message translates to:
  /// **'Quedó en Por revisar.'**
  String get pasteAdded;

  /// No description provided for @pasteRecorded.
  ///
  /// In es, this message translates to:
  /// **'Quedó registrado.'**
  String get pasteRecorded;

  /// No description provided for @pasteNothing.
  ///
  /// In es, this message translates to:
  /// **'No encontré un pago en ese texto.'**
  String get pasteNothing;

  /// No description provided for @pasteDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Ese pago ya estaba.'**
  String get pasteDuplicate;

  /// No description provided for @readScreenshot.
  ///
  /// In es, this message translates to:
  /// **'Leer un pantallazo o PDF'**
  String get readScreenshot;

  /// No description provided for @pickImages.
  ///
  /// In es, this message translates to:
  /// **'Capturas o fotos'**
  String get pickImages;

  /// No description provided for @pickPdf.
  ///
  /// In es, this message translates to:
  /// **'Un PDF'**
  String get pickPdf;

  /// No description provided for @readingImages.
  ///
  /// In es, this message translates to:
  /// **'Leyendo…'**
  String get readingImages;

  /// No description provided for @readFound.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Leí un pago. Quedó en Por revisar.} other{Leí {count} pagos. Quedaron en Por revisar.}}'**
  String readFound(int count);

  /// No description provided for @readNothing.
  ///
  /// In es, this message translates to:
  /// **'No encontré un monto con su moneda. Prueba con una captura donde se vea el valor.'**
  String get readNothing;

  /// No description provided for @captureTitle.
  ///
  /// In es, this message translates to:
  /// **'Captura automática'**
  String get captureTitle;

  /// No description provided for @captureSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Pagos que llegan solos desde tus notificaciones y mensajes'**
  String get captureSubtitle;

  /// No description provided for @captureAuto.
  ///
  /// In es, this message translates to:
  /// **'Registrar solo lo que esté claro'**
  String get captureAuto;

  /// No description provided for @captureAutoHelp.
  ///
  /// In es, this message translates to:
  /// **'Cuando la cuenta, la categoría y el monto son seguros y no es un repetido, se registra sin preguntarte. Lo demás espera en Por revisar.'**
  String get captureAutoHelp;

  /// No description provided for @captureLocation.
  ///
  /// In es, this message translates to:
  /// **'Usar la ubicación del pago'**
  String get captureLocation;

  /// No description provided for @captureLocationHelp.
  ///
  /// In es, this message translates to:
  /// **'Cuando la alerta no dice dónde fue, Quincena busca los comercios a unos metros de donde estaba el teléfono. La ubicación se guarda solo aquí; para buscar los comercios se envían únicamente las coordenadas a OpenStreetMap, a través de Photon. Los datos de los comercios son © colaboradores de OpenStreetMap, con licencia ODbL.'**
  String get captureLocationHelp;

  /// No description provided for @captureLocationDenied.
  ///
  /// In es, this message translates to:
  /// **'Quincena no tiene permiso para usar la ubicación. Puedes darlo en los ajustes del teléfono.'**
  String get captureLocationDenied;

  /// No description provided for @openPhoneSettings.
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes'**
  String get openPhoneSettings;

  /// No description provided for @captureAlwaysTitle.
  ///
  /// In es, this message translates to:
  /// **'Ubicación con la app cerrada'**
  String get captureAlwaysTitle;

  /// No description provided for @captureAlwaysBody.
  ///
  /// In es, this message translates to:
  /// **'Quincena recoge datos de ubicación para sugerir el comercio de un pago, incluso cuando la app está cerrada o no se usa. Solo mira la ubicación cuando llega una notificación de pago, la guarda en este teléfono y, para encontrar el comercio, envía únicamente las coordenadas a OpenStreetMap a través de Photon. Android te pedirá elegir «Permitir todo el tiempo».'**
  String get captureAlwaysBody;

  /// No description provided for @captureLocationOnlyOpen.
  ///
  /// In es, this message translates to:
  /// **'Por ahora solo con la app abierta. Elige «Permitir todo el tiempo» para los pagos que llegan con la app cerrada.'**
  String get captureLocationOnlyOpen;

  /// No description provided for @captureAllowAlways.
  ///
  /// In es, this message translates to:
  /// **'Permitir todo el tiempo'**
  String get captureAllowAlways;

  /// No description provided for @notNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get notNow;

  /// No description provided for @continueLabel.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueLabel;

  /// No description provided for @captureImagesTitle.
  ///
  /// In es, this message translates to:
  /// **'Capturas y comprobantes'**
  String get captureImagesTitle;

  /// No description provided for @captureImagesIos.
  ///
  /// In es, this message translates to:
  /// **'En Por revisar puedes elegir una captura, una foto o un PDF de un pago, y Quincena lo lee en el teléfono.\nPara mandarlos desde otras apps, crea un atajo con la acción «Leer comprobante» de Quincena y actívale «Mostrar en la hoja de compartir».\nCon «Hacer captura de pantalla» antes y Toque posterior (Ajustes, Accesibilidad, Tocar), lees lo que tengas en pantalla con dos toques en la parte de atrás del iPhone.'**
  String get captureImagesIos;

  /// No description provided for @captureImagesAndroid.
  ///
  /// In es, this message translates to:
  /// **'Comparte con Quincena una captura, una foto, un PDF o un texto desde cualquier app, o elígelos en Por revisar. Se leen en el teléfono y quedan ahí para que los registres.'**
  String get captureImagesAndroid;

  /// No description provided for @captureImagesDesktop.
  ///
  /// In es, this message translates to:
  /// **'Elige en Por revisar una captura, una foto o un PDF de un pago, y Quincena lo lee en este computador.'**
  String get captureImagesDesktop;

  /// No description provided for @captureIosTitle.
  ///
  /// In es, this message translates to:
  /// **'En iPhone, con Atajos'**
  String get captureIosTitle;

  /// No description provided for @captureIosSteps.
  ///
  /// In es, this message translates to:
  /// **'1. Abre Atajos y ve a Automatización.\n2. Crea una nueva con Wallet y elige tus tarjetas.\n3. Si quieres usar la ubicación, agrega «Obtener ubicación actual». Luego agrega la acción «Registrar movimiento» de Quincena, elige Apple Pay como origen y pásale el monto, el comercio y la tarjeta.\n4. Elige «Ejecutar inmediatamente».\nPara los SMS del banco, crea la automatización Mensaje con el remitente del banco, usa la misma acción con Mensaje como origen y pásale el mensaje como texto. Desde iOS 27, la automatización Notificación hace lo mismo con las apps de tus bancos.'**
  String get captureIosSteps;

  /// No description provided for @captureOpenShortcuts.
  ///
  /// In es, this message translates to:
  /// **'Abrir Atajos'**
  String get captureOpenShortcuts;

  /// No description provided for @captureIosReady.
  ///
  /// In es, this message translates to:
  /// **'Añade los que quieras. Llegan apagados: en Atajos, abre cada uno, toca Editar, despliega el primer bloque y activa «Automatización».'**
  String get captureIosReady;

  /// No description provided for @captureIos26Steps.
  ///
  /// In es, this message translates to:
  /// **'1. Añade el atajo de lo que quieras capturar.\n2. Abre Atajos y ve a Automatización.\n3. Crea una con Wallet y elige tus tarjetas, o con Mensaje y el remitente de tu banco.\n4. Elige el atajo de Quincena que añadiste y «Ejecutar inmediatamente».'**
  String get captureIos26Steps;

  /// No description provided for @captureAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get captureAdd;

  /// No description provided for @readyBankNotifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones de tus bancos'**
  String get readyBankNotifications;

  /// No description provided for @readyBankNotificationsHelp.
  ///
  /// In es, this message translates to:
  /// **'Bancolombia, Nequi y los demás, apenas llegan. Al añadirlo, revisa que estén las apps de tus bancos.'**
  String get readyBankNotificationsHelp;

  /// No description provided for @readyBankMessages.
  ///
  /// In es, this message translates to:
  /// **'SMS de tu banco'**
  String get readyBankMessages;

  /// No description provided for @readyBankMessagesHelp.
  ///
  /// In es, this message translates to:
  /// **'Los mensajes de compras y transferencias que traen un valor con \$.'**
  String get readyBankMessagesHelp;

  /// No description provided for @readyApplePay.
  ///
  /// In es, this message translates to:
  /// **'Pagos con Apple Pay'**
  String get readyApplePay;

  /// No description provided for @readyApplePayHelp.
  ///
  /// In es, this message translates to:
  /// **'Cada compra que pagas con el iPhone.'**
  String get readyApplePayHelp;

  /// No description provided for @readyScreenshots.
  ///
  /// In es, this message translates to:
  /// **'Capturas de comprobantes'**
  String get readyScreenshots;

  /// No description provided for @readyScreenshotsHelp.
  ///
  /// In es, this message translates to:
  /// **'Si la captura muestra un valor con \$, la lee en el teléfono y la deja por revisar.'**
  String get readyScreenshotsHelp;

  /// No description provided for @captureAndroidTitle.
  ///
  /// In es, this message translates to:
  /// **'En Android, con tus notificaciones'**
  String get captureAndroidTitle;

  /// No description provided for @captureAndroidBody.
  ///
  /// In es, this message translates to:
  /// **'Quincena lee las notificaciones que parecen pagos y deja pasar el resto sin guardarlo. Los códigos de verificación nunca se guardan.'**
  String get captureAndroidBody;

  /// No description provided for @captureAndroidGranted.
  ///
  /// In es, this message translates to:
  /// **'Acceso a notificaciones activado'**
  String get captureAndroidGranted;

  /// No description provided for @captureAndroidGrant.
  ///
  /// In es, this message translates to:
  /// **'Permitir acceso a notificaciones'**
  String get captureAndroidGrant;

  /// No description provided for @captureOtherTitle.
  ///
  /// In es, this message translates to:
  /// **'En este dispositivo'**
  String get captureOtherTitle;

  /// No description provided for @captureOtherBody.
  ///
  /// In es, this message translates to:
  /// **'La captura automática funciona en el teléfono. Aquí puedes pegar un mensaje del banco.'**
  String get captureOtherBody;

  /// No description provided for @mutedApps.
  ///
  /// In es, this message translates to:
  /// **'Apps que no se leen'**
  String get mutedApps;

  /// No description provided for @unmute.
  ///
  /// In es, this message translates to:
  /// **'Volver a leer'**
  String get unmute;

  /// No description provided for @learnedCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Aún no ha aprendido comercios.} =1{Ya reconoce un comercio.} other{Ya reconoce {count} comercios.}}'**
  String learnedCount(int count);

  /// No description provided for @portfolioTitle.
  ///
  /// In es, this message translates to:
  /// **'Cripto'**
  String get portfolioTitle;

  /// No description provided for @portfolioWorth.
  ///
  /// In es, this message translates to:
  /// **'Tu cripto vale'**
  String get portfolioWorth;

  /// No description provided for @portfolioToday.
  ///
  /// In es, this message translates to:
  /// **'En 24 horas'**
  String get portfolioToday;

  /// No description provided for @portfolioGain.
  ///
  /// In es, this message translates to:
  /// **'Ganancia no realizada'**
  String get portfolioGain;

  /// No description provided for @portfolioLoss.
  ///
  /// In es, this message translates to:
  /// **'Pérdida no realizada'**
  String get portfolioLoss;

  /// No description provided for @portfolioSinceBought.
  ///
  /// In es, this message translates to:
  /// **'sobre lo que pagaste'**
  String get portfolioSinceBought;

  /// No description provided for @portfolioPricedAt.
  ///
  /// In es, this message translates to:
  /// **'Precios de Binance del {when}'**
  String portfolioPricedAt(String when);

  /// No description provided for @portfolioPricing.
  ///
  /// In es, this message translates to:
  /// **'Leyendo precios…'**
  String get portfolioPricing;

  /// No description provided for @portfolioPricingFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron leer los precios: se muestran los últimos guardados.'**
  String get portfolioPricingFailed;

  /// No description provided for @portfolioNeverPriced.
  ///
  /// In es, this message translates to:
  /// **'Aún sin precios: se leen al conectarse.'**
  String get portfolioNeverPriced;

  /// No description provided for @rangeDay.
  ///
  /// In es, this message translates to:
  /// **'24 h'**
  String get rangeDay;

  /// No description provided for @rangeWeek.
  ///
  /// In es, this message translates to:
  /// **'7 d'**
  String get rangeWeek;

  /// No description provided for @rangeMonth.
  ///
  /// In es, this message translates to:
  /// **'30 d'**
  String get rangeMonth;

  /// No description provided for @rangeYear.
  ///
  /// In es, this message translates to:
  /// **'1 a'**
  String get rangeYear;

  /// No description provided for @rangeDayLong.
  ///
  /// In es, this message translates to:
  /// **'en 24 horas'**
  String get rangeDayLong;

  /// No description provided for @rangeWeekLong.
  ///
  /// In es, this message translates to:
  /// **'en 7 días'**
  String get rangeWeekLong;

  /// No description provided for @rangeMonthLong.
  ///
  /// In es, this message translates to:
  /// **'en 30 días'**
  String get rangeMonthLong;

  /// No description provided for @rangeYearLong.
  ///
  /// In es, this message translates to:
  /// **'en un año'**
  String get rangeYearLong;

  /// No description provided for @chartEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay precios para dibujar.'**
  String get chartEmpty;

  /// No description provided for @chartWithHoldings.
  ///
  /// In es, this message translates to:
  /// **'El valor con lo que tenías en cada momento: una compra lo sube de golpe.'**
  String get chartWithHoldings;

  /// No description provided for @portfolioAllocation.
  ///
  /// In es, this message translates to:
  /// **'Distribución'**
  String get portfolioAllocation;

  /// No description provided for @portfolioOtherPlace.
  ///
  /// In es, this message translates to:
  /// **'Otras'**
  String get portfolioOtherPlace;

  /// No description provided for @portfolioOtherAssets.
  ///
  /// In es, this message translates to:
  /// **'Otras'**
  String get portfolioOtherAssets;

  /// No description provided for @portfolioRealized.
  ///
  /// In es, this message translates to:
  /// **'Ya ganado en ventas y conversiones: {amount}'**
  String portfolioRealized(String amount);

  /// No description provided for @portfolioRealizedLoss.
  ///
  /// In es, this message translates to:
  /// **'Ya perdido en ventas y conversiones: {amount}'**
  String portfolioRealizedLoss(String amount);

  /// No description provided for @portfolioUncosted.
  ///
  /// In es, this message translates to:
  /// **'{amount} llegaron sin precio de compra y no cuentan en la ganancia. Puedes poner lo que costaron en su cuenta.'**
  String portfolioUncosted(String amount);

  /// No description provided for @portfolioUnpriced.
  ///
  /// In es, this message translates to:
  /// **'Binance no tiene precio para {assets}: no suman al total.'**
  String portfolioUnpriced(String assets);

  /// No description provided for @portfolioDisclaimer.
  ///
  /// In es, this message translates to:
  /// **'Precios de mercado de Binance, que cambian a cada momento. Quincena no da asesoría de inversión.'**
  String get portfolioDisclaimer;

  /// No description provided for @portfolioEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes cripto. Agrega una billetera o conecta Binance.'**
  String get portfolioEmpty;

  /// No description provided for @holdingPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio'**
  String get holdingPrice;

  /// No description provided for @holdingWorth.
  ///
  /// In es, this message translates to:
  /// **'Vale'**
  String get holdingWorth;

  /// No description provided for @holdingCost.
  ///
  /// In es, this message translates to:
  /// **'Te costó'**
  String get holdingCost;

  /// No description provided for @holdingAverage.
  ///
  /// In es, this message translates to:
  /// **'Costo promedio'**
  String get holdingAverage;

  /// No description provided for @holdingNoCost.
  ///
  /// In es, this message translates to:
  /// **'Sin costo'**
  String get holdingNoCost;

  /// No description provided for @holdingNoCostHelp.
  ///
  /// In es, this message translates to:
  /// **'Pon lo que te costó al editar la cuenta, o registra tus compras.'**
  String get holdingNoCostHelp;

  /// No description provided for @tradeBuy.
  ///
  /// In es, this message translates to:
  /// **'Registrar compra'**
  String get tradeBuy;

  /// No description provided for @tradeSell.
  ///
  /// In es, this message translates to:
  /// **'Registrar venta'**
  String get tradeSell;

  /// No description provided for @tradeBought.
  ///
  /// In es, this message translates to:
  /// **'Compra'**
  String get tradeBought;

  /// No description provided for @tradeSold.
  ///
  /// In es, this message translates to:
  /// **'Venta'**
  String get tradeSold;

  /// No description provided for @tradeQuantity.
  ///
  /// In es, this message translates to:
  /// **'Cantidad de {code}'**
  String tradeQuantity(String code);

  /// No description provided for @tradePaid.
  ///
  /// In es, this message translates to:
  /// **'Total pagado'**
  String get tradePaid;

  /// No description provided for @tradeReceived.
  ///
  /// In es, this message translates to:
  /// **'Total recibido'**
  String get tradeReceived;

  /// No description provided for @tradePaidFrom.
  ///
  /// In es, this message translates to:
  /// **'Pagado desde'**
  String get tradePaidFrom;

  /// No description provided for @tradeReceivedIn.
  ///
  /// In es, this message translates to:
  /// **'Recibido en'**
  String get tradeReceivedIn;

  /// No description provided for @tradeOutside.
  ///
  /// In es, this message translates to:
  /// **'Fuera de Quincena'**
  String get tradeOutside;

  /// No description provided for @tradeOutsideHelp.
  ///
  /// In es, this message translates to:
  /// **'En Binance P2P, en otro exchange o en efectivo. Si sale de una de tus cuentas, elígela y su saldo también cambia.'**
  String get tradeOutsideHelp;

  /// No description provided for @tradePriceEach.
  ///
  /// In es, this message translates to:
  /// **'Precio por unidad: {price}'**
  String tradePriceEach(String price);

  /// No description provided for @tradeNotEnough.
  ///
  /// In es, this message translates to:
  /// **'Esa cuenta tiene {amount}.'**
  String tradeNotEnough(String amount);

  /// No description provided for @accountOpeningCost.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto te costó?'**
  String get accountOpeningCost;

  /// No description provided for @accountOpeningCostHelp.
  ///
  /// In es, this message translates to:
  /// **'Opcional. Lo que pagaste por ese saldo; con esto Quincena calcula cuánto has ganado.'**
  String get accountOpeningCostHelp;

  /// No description provided for @binanceTitle.
  ///
  /// In es, this message translates to:
  /// **'Binance'**
  String get binanceTitle;

  /// No description provided for @binanceCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Conecta Binance'**
  String get binanceCardTitle;

  /// No description provided for @binanceCardBody.
  ///
  /// In es, this message translates to:
  /// **'Quincena solo podrá consultar tu cuenta: nunca podrá mover tus fondos.'**
  String get binanceCardBody;

  /// No description provided for @binanceConnectTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta de Binance, sola'**
  String get binanceConnectTitle;

  /// No description provided for @binanceConnectBody.
  ///
  /// In es, this message translates to:
  /// **'Quincena trae tus saldos de spot, fondos y Earn, tus compras y ventas en P2P, tus conversiones, compras en el mercado, depósitos y retiros, y con eso calcula cuánto te costó cada moneda.'**
  String get binanceConnectBody;

  /// No description provided for @binanceReadOnlyTitle.
  ///
  /// In es, this message translates to:
  /// **'Solo lectura'**
  String get binanceReadOnlyTitle;

  /// No description provided for @binanceReadOnlyBody.
  ///
  /// In es, this message translates to:
  /// **'La llave solo puede leer: no puede comprar, vender, mover ni retirar nada. Si puede hacer algo más, Quincena no la acepta.'**
  String get binanceReadOnlyBody;

  /// No description provided for @binanceKeyStoredTitle.
  ///
  /// In es, this message translates to:
  /// **'Solo en este dispositivo'**
  String get binanceKeyStoredTitle;

  /// No description provided for @binanceKeyStoredBody.
  ///
  /// In es, this message translates to:
  /// **'La llave se guarda en el llavero del dispositivo y solo se usa para hablar con Binance. No va a Gemini, ni a la copia que exportas, ni a ningún servidor de Quincena.'**
  String get binanceKeyStoredBody;

  /// No description provided for @binanceStepsTitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo crear la llave'**
  String get binanceStepsTitle;

  /// No description provided for @binanceSteps.
  ///
  /// In es, this message translates to:
  /// **'1. En la app de Binance, abre tu perfil y entra a Gestión de API.\n2. Crea una API generada por el sistema y llámala Quincena.\n3. Deja marcado solo «Habilitar lectura». Como el teléfono no tiene una IP fija, elige sin restricción de IP: con solo lectura no hay riesgo de que muevan tu plata.\n4. Copia la API Key y la Secret Key y pégalas aquí.'**
  String get binanceSteps;

  /// No description provided for @binanceApiKey.
  ///
  /// In es, this message translates to:
  /// **'API Key'**
  String get binanceApiKey;

  /// No description provided for @binanceSecretKey.
  ///
  /// In es, this message translates to:
  /// **'Secret Key'**
  String get binanceSecretKey;

  /// No description provided for @binanceConnect.
  ///
  /// In es, this message translates to:
  /// **'Conectar'**
  String get binanceConnect;

  /// No description provided for @binanceConnecting.
  ///
  /// In es, this message translates to:
  /// **'Revisando la llave con Binance…'**
  String get binanceConnecting;

  /// No description provided for @binanceNotReadOnly.
  ///
  /// In es, this message translates to:
  /// **'Esta llave puede hacer más que leer ({what}). Crea una que solo tenga «Habilitar lectura»; esta no se guardó.'**
  String binanceNotReadOnly(String what);

  /// No description provided for @binanceBadKey.
  ///
  /// In es, this message translates to:
  /// **'Binance no reconoce esa llave. Revisa que copiaste las dos completas, o que no la hayas borrado.'**
  String get binanceBadKey;

  /// No description provided for @binanceOffline.
  ///
  /// In es, this message translates to:
  /// **'No se pudo hablar con Binance. Revisa tu conexión e intenta de nuevo.'**
  String get binanceOffline;

  /// No description provided for @binanceLimited.
  ///
  /// In es, this message translates to:
  /// **'Binance pidió esperar un momento. Intenta en un minuto.'**
  String get binanceLimited;

  /// No description provided for @binanceFailed.
  ///
  /// In es, this message translates to:
  /// **'Algo salió mal al leer Binance. Intenta de nuevo.'**
  String get binanceFailed;

  /// No description provided for @binanceConnected.
  ///
  /// In es, this message translates to:
  /// **'Conectada con una llave de solo lectura'**
  String get binanceConnected;

  /// No description provided for @binanceSyncedAt.
  ///
  /// In es, this message translates to:
  /// **'Leída {when}'**
  String binanceSyncedAt(String when);

  /// No description provided for @binanceNeverSynced.
  ///
  /// In es, this message translates to:
  /// **'Aún sin leer'**
  String get binanceNeverSynced;

  /// No description provided for @binanceSyncNow.
  ///
  /// In es, this message translates to:
  /// **'Leer ahora'**
  String get binanceSyncNow;

  /// No description provided for @binanceSyncing.
  ///
  /// In es, this message translates to:
  /// **'Leyendo tu cuenta de Binance…'**
  String get binanceSyncing;

  /// No description provided for @binanceReport.
  ///
  /// In es, this message translates to:
  /// **'Listo: {movements, plural, =0{nada nuevo} =1{un movimiento nuevo} other{{movements} movimientos nuevos}}.'**
  String binanceReport(int movements);

  /// No description provided for @binanceDisconnect.
  ///
  /// In es, this message translates to:
  /// **'Desconectar'**
  String get binanceDisconnect;

  /// No description provided for @binanceDisconnectTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Desconectar Binance?'**
  String get binanceDisconnectTitle;

  /// No description provided for @binanceDisconnectBody.
  ///
  /// In es, this message translates to:
  /// **'Se borra la llave de este dispositivo. Las cuentas y los movimientos que trajo se quedan como tuyos.'**
  String get binanceDisconnectBody;

  /// No description provided for @binanceWebOnly.
  ///
  /// In es, this message translates to:
  /// **'En la web, Binance no deja que una página se conecte a tu cuenta. Conéctala desde la app del teléfono o del computador.'**
  String get binanceWebOnly;

  /// No description provided for @binanceManualAccounts.
  ///
  /// In es, this message translates to:
  /// **'También tienes cuentas de Binance que llevabas a mano: {names}. Archívalas para no contar lo mismo dos veces.'**
  String binanceManualAccounts(String names);

  /// No description provided for @binanceArchive.
  ///
  /// In es, this message translates to:
  /// **'Archivarlas'**
  String get binanceArchive;

  /// No description provided for @binanceLabelP2p.
  ///
  /// In es, this message translates to:
  /// **'Binance P2P'**
  String get binanceLabelP2p;

  /// No description provided for @binanceLabelConversion.
  ///
  /// In es, this message translates to:
  /// **'Conversión en Binance'**
  String get binanceLabelConversion;

  /// No description provided for @binanceLabelDeposit.
  ///
  /// In es, this message translates to:
  /// **'Depósito a Binance'**
  String get binanceLabelDeposit;

  /// No description provided for @binanceLabelWithdrawal.
  ///
  /// In es, this message translates to:
  /// **'Retiro de Binance'**
  String get binanceLabelWithdrawal;

  /// No description provided for @binanceLabelFee.
  ///
  /// In es, this message translates to:
  /// **'Comisión de Binance'**
  String get binanceLabelFee;

  /// No description provided for @binanceLabelAdjustment.
  ///
  /// In es, this message translates to:
  /// **'Ajuste con Binance'**
  String get binanceLabelAdjustment;

  /// No description provided for @statementTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar extracto'**
  String get statementTitle;

  /// No description provided for @statementSubtitle.
  ///
  /// In es, this message translates to:
  /// **'CSV, Excel o PDF de tu banco'**
  String get statementSubtitle;

  /// No description provided for @statementIntro.
  ///
  /// In es, this message translates to:
  /// **'Trae los movimientos de un extracto de tu banco o tarjeta: CSV, Excel (.xlsx) o PDF. Se lee en este dispositivo, y revisas cada movimiento antes de guardarlo.'**
  String get statementIntro;

  /// No description provided for @statementPick.
  ///
  /// In es, this message translates to:
  /// **'Elegir archivo'**
  String get statementPick;

  /// No description provided for @statementReading.
  ///
  /// In es, this message translates to:
  /// **'Leyendo el extracto…'**
  String get statementReading;

  /// No description provided for @statementNothing.
  ///
  /// In es, this message translates to:
  /// **'No encontré movimientos en este archivo.'**
  String get statementNothing;

  /// No description provided for @statementFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el archivo. Prueba con un CSV, un Excel (.xlsx) o un PDF.'**
  String get statementFailed;

  /// No description provided for @statementGemini.
  ///
  /// In es, this message translates to:
  /// **'Leer con Gemini'**
  String get statementGemini;

  /// No description provided for @statementGeminiNote.
  ///
  /// In es, this message translates to:
  /// **'Se envía a Gemini el texto del extracto, con sus fechas, descripciones y montos, para que lo ordene. Cuenta como una pregunta del día.'**
  String get statementGeminiNote;

  /// No description provided for @statementGeminiPdf.
  ///
  /// In es, this message translates to:
  /// **'En la web el PDF no se puede leer aquí: se envía el archivo a Gemini para que lo lea. Cuenta como una pregunta del día.'**
  String get statementGeminiPdf;

  /// No description provided for @statementSummary.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un movimiento} other{{count} movimientos}} · {range}'**
  String statementSummary(int count, String range);

  /// No description provided for @statementRecorded.
  ///
  /// In es, this message translates to:
  /// **'Ya registrado'**
  String get statementRecorded;

  /// No description provided for @statementImportedBefore.
  ///
  /// In es, this message translates to:
  /// **'Ya importado'**
  String get statementImportedBefore;

  /// No description provided for @statementFlip.
  ///
  /// In es, this message translates to:
  /// **'Invertir entradas y salidas'**
  String get statementFlip;

  /// No description provided for @statementImport.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Nada para importar} =1{Importar un movimiento} other{Importar {count} movimientos}}'**
  String statementImport(int count);

  /// No description provided for @statementDone.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Se importó un movimiento.} other{Se importaron {count} movimientos.}}'**
  String statementDone(int count);

  /// No description provided for @statementByGemini.
  ///
  /// In es, this message translates to:
  /// **'Leído por Gemini: revisa bien antes de importar.'**
  String get statementByGemini;

  /// No description provided for @walletsTitle.
  ///
  /// In es, this message translates to:
  /// **'Billeteras propias'**
  String get walletsTitle;

  /// No description provided for @walletsCardBody.
  ///
  /// In es, this message translates to:
  /// **'Ledger, MetaMask, Trust Wallet: por su dirección pública.'**
  String get walletsCardBody;

  /// No description provided for @walletsBody.
  ///
  /// In es, this message translates to:
  /// **'Sigue lo que tienes en Ledger, MetaMask, Trust Wallet o cualquier billetera, con su dirección pública. Solo se lee: con una dirección nadie puede mover nada.'**
  String get walletsBody;

  /// No description provided for @walletsChains.
  ///
  /// In es, this message translates to:
  /// **'Bitcoin, Ethereum (ETH, USDT y USDC) y TRON (TRX, USDT y USDC).'**
  String get walletsChains;

  /// No description provided for @walletsPrivacy.
  ///
  /// In es, this message translates to:
  /// **'La dirección se consulta en servicios públicos: mempool.space, un nodo público de Ethereum y TronGrid. Ellos ven la dirección, no quién eres.'**
  String get walletsPrivacy;

  /// No description provided for @walletsAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar billetera'**
  String get walletsAdd;

  /// No description provided for @walletsAddress.
  ///
  /// In es, this message translates to:
  /// **'Dirección pública'**
  String get walletsAddress;

  /// No description provided for @walletsLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre: Ledger, MetaMask…'**
  String get walletsLabel;

  /// No description provided for @walletsBadAddress.
  ///
  /// In es, this message translates to:
  /// **'Esa no parece una dirección de {chain}.'**
  String walletsBadAddress(String chain);

  /// No description provided for @walletsUnreadable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer esa dirección. Revisa tu conexión e intenta de nuevo.'**
  String get walletsUnreadable;

  /// No description provided for @walletsRemove.
  ///
  /// In es, this message translates to:
  /// **'Dejar de seguir'**
  String get walletsRemove;

  /// No description provided for @walletsRemoveBody.
  ///
  /// In es, this message translates to:
  /// **'Ya no se lee. Las cuentas que trajo se quedan como tuyas.'**
  String get walletsRemoveBody;

  /// No description provided for @walletsSyncedAt.
  ///
  /// In es, this message translates to:
  /// **'Leídas {when}'**
  String walletsSyncedAt(String when);

  /// No description provided for @walletsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no sigues ninguna billetera.'**
  String get walletsEmpty;

  /// No description provided for @walletsAdjustment.
  ///
  /// In es, this message translates to:
  /// **'Ajuste con la billetera'**
  String get walletsAdjustment;

  /// No description provided for @walletsFailed.
  ///
  /// In es, this message translates to:
  /// **'Una billetera no se pudo leer; se muestran sus últimos saldos.'**
  String get walletsFailed;

  /// No description provided for @chartWithoutTrades.
  ///
  /// In es, this message translates to:
  /// **'Por el precio, sin contar lo que compraste o vendiste en esos días.'**
  String get chartWithoutTrades;

  /// No description provided for @privacyPolicy.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get privacyPolicy;

  /// No description provided for @supportTitle.
  ///
  /// In es, this message translates to:
  /// **'Soporte'**
  String get supportTitle;

  /// No description provided for @cadencePerMonth.
  ///
  /// In es, this message translates to:
  /// **'al mes'**
  String get cadencePerMonth;

  /// No description provided for @cadencePerTwoWeeks.
  ///
  /// In es, this message translates to:
  /// **'cada dos semanas'**
  String get cadencePerTwoWeeks;

  /// No description provided for @cadencePerWeek.
  ///
  /// In es, this message translates to:
  /// **'a la semana'**
  String get cadencePerWeek;

  /// No description provided for @cadencePerYear.
  ///
  /// In es, this message translates to:
  /// **'al año'**
  String get cadencePerYear;

  /// No description provided for @cadenceMonthly.
  ///
  /// In es, this message translates to:
  /// **'Cada mes'**
  String get cadenceMonthly;

  /// No description provided for @cadenceBiweekly.
  ///
  /// In es, this message translates to:
  /// **'Cada dos semanas'**
  String get cadenceBiweekly;

  /// No description provided for @cadenceWeekly.
  ///
  /// In es, this message translates to:
  /// **'Cada semana'**
  String get cadenceWeekly;

  /// No description provided for @cadenceYearly.
  ///
  /// In es, this message translates to:
  /// **'Cada año'**
  String get cadenceYearly;

  /// No description provided for @chargeAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar pago fijo'**
  String get chargeAdd;

  /// No description provided for @chargeEdit.
  ///
  /// In es, this message translates to:
  /// **'Pago fijo'**
  String get chargeEdit;

  /// No description provided for @chargePausedNote.
  ///
  /// In es, this message translates to:
  /// **'En pausa: no se cuenta como comprometido.'**
  String get chargePausedNote;

  /// No description provided for @chargeName.
  ///
  /// In es, this message translates to:
  /// **'¿Qué es?'**
  String get chargeName;

  /// No description provided for @chargeAmount.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto cobra?'**
  String get chargeAmount;

  /// No description provided for @chargeUseLast.
  ///
  /// In es, this message translates to:
  /// **'El último cobro fue {amount}, el {date}: usar ese valor'**
  String chargeUseLast(String amount, String date);

  /// No description provided for @chargeCadence.
  ///
  /// In es, this message translates to:
  /// **'Cada cuánto'**
  String get chargeCadence;

  /// No description provided for @chargeNext.
  ///
  /// In es, this message translates to:
  /// **'Próximo cobro: {date}'**
  String chargeNext(String date);

  /// No description provided for @chargeAccount.
  ///
  /// In es, this message translates to:
  /// **'Se paga desde'**
  String get chargeAccount;

  /// No description provided for @chargeNoAccount.
  ///
  /// In es, this message translates to:
  /// **'Ninguna cuenta en particular'**
  String get chargeNoAccount;

  /// No description provided for @chargeRemind.
  ///
  /// In es, this message translates to:
  /// **'Avisarme antes de cada cobro'**
  String get chargeRemind;

  /// No description provided for @remindNever.
  ///
  /// In es, this message translates to:
  /// **'No avisarme'**
  String get remindNever;

  /// No description provided for @remindSameDay.
  ///
  /// In es, this message translates to:
  /// **'El mismo día'**
  String get remindSameDay;

  /// No description provided for @remindDayBefore.
  ///
  /// In es, this message translates to:
  /// **'Un día antes'**
  String get remindDayBefore;

  /// No description provided for @remindDaysBefore.
  ///
  /// In es, this message translates to:
  /// **'{days} días antes'**
  String remindDaysBefore(int days);

  /// No description provided for @remindWeekBefore.
  ///
  /// In es, this message translates to:
  /// **'Una semana antes'**
  String get remindWeekBefore;

  /// No description provided for @chargeSubscription.
  ///
  /// In es, this message translates to:
  /// **'Suscripción'**
  String get chargeSubscription;

  /// No description provided for @chargeTrialAsk.
  ///
  /// In es, this message translates to:
  /// **'¿Está en prueba gratis?'**
  String get chargeTrialAsk;

  /// No description provided for @chargeTrialUntil.
  ///
  /// In es, this message translates to:
  /// **'Prueba gratis hasta el {date}'**
  String chargeTrialUntil(String date);

  /// No description provided for @chargeTrialClear.
  ///
  /// In es, this message translates to:
  /// **'Quitar la prueba gratis'**
  String get chargeTrialClear;

  /// No description provided for @chargeTrialNote.
  ///
  /// In es, this message translates to:
  /// **'Te avisamos el día antes de que empiece a cobrar.'**
  String get chargeTrialNote;

  /// No description provided for @chargeInUseAsk.
  ///
  /// In es, this message translates to:
  /// **'¿La sigues usando?'**
  String get chargeInUseAsk;

  /// No description provided for @chargeInUseYes.
  ///
  /// In es, this message translates to:
  /// **'Sí, la uso'**
  String get chargeInUseYes;

  /// No description provided for @chargeInUseNo.
  ///
  /// In es, this message translates to:
  /// **'Ya no la uso'**
  String get chargeInUseNo;

  /// No description provided for @chargeInUseNote.
  ///
  /// In es, this message translates to:
  /// **'Un cobro que se repite no dice si la usas: eso solo lo sabes tú.'**
  String get chargeInUseNote;

  /// No description provided for @chargeYearly.
  ///
  /// In es, this message translates to:
  /// **'Al año son {amount}.'**
  String chargeYearly(String amount);

  /// No description provided for @chargeSaving.
  ///
  /// In es, this message translates to:
  /// **'Si la pausas, te ahorras {amount} al año. Quincena no la cancela: hazlo en la app o en la página del servicio.'**
  String chargeSaving(String amount);

  /// No description provided for @chargeIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Falta el nombre o el valor.'**
  String get chargeIncomplete;

  /// No description provided for @chargeRemindDenied.
  ///
  /// In es, this message translates to:
  /// **'Sin permiso para avisarte. Si quieres el aviso, activa las notificaciones de Quincena en los ajustes del teléfono.'**
  String get chargeRemindDenied;

  /// No description provided for @chargePause.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get chargePause;

  /// No description provided for @chargeResume.
  ///
  /// In es, this message translates to:
  /// **'Reanudar'**
  String get chargeResume;

  /// No description provided for @chargePauseNote.
  ///
  /// In es, this message translates to:
  /// **'Pausar aquí solo deja de contarlo como comprometido. Para que deje de cobrarte, cancélalo con el servicio.'**
  String get chargePauseNote;

  /// No description provided for @chargeDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar pago fijo'**
  String get chargeDelete;

  /// No description provided for @chargeDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar {name}?'**
  String chargeDeleteTitle(String name);

  /// No description provided for @chargeDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Deja de contarse como comprometido. Los cobros que ya registraste se quedan.'**
  String get chargeDeleteBody;

  /// No description provided for @fixedTitle.
  ///
  /// In es, this message translates to:
  /// **'Pagos fijos'**
  String get fixedTitle;

  /// No description provided for @fixedBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que se cobra solo cada mes o cada año: suscripciones, arriendo, servicios. Quincena lo cuenta como comprometido antes de que llegue.'**
  String get fixedBody;

  /// No description provided for @fixedEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes pagos fijos. Agrega el arriendo, el internet o una suscripción para verlos venir.'**
  String get fixedEmpty;

  /// No description provided for @fixedNext30.
  ///
  /// In es, this message translates to:
  /// **'En los próximos 30 días'**
  String get fixedNext30;

  /// No description provided for @fixedSubscriptionsYear.
  ///
  /// In es, this message translates to:
  /// **'Suscripciones al año'**
  String get fixedSubscriptionsYear;

  /// No description provided for @guessTitle.
  ///
  /// In es, this message translates to:
  /// **'Parecen pagos fijos'**
  String get guessTitle;

  /// No description provided for @guessEvidence.
  ///
  /// In es, this message translates to:
  /// **'{count} cobros parecidos, el último de {amount}: {dates}'**
  String guessEvidence(int count, String amount, String dates);

  /// No description provided for @guessAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar como pago fijo'**
  String get guessAdd;

  /// No description provided for @guessNot.
  ///
  /// In es, this message translates to:
  /// **'No es fijo'**
  String get guessNot;

  /// No description provided for @fixedSubscriptions.
  ///
  /// In es, this message translates to:
  /// **'Suscripciones'**
  String get fixedSubscriptions;

  /// No description provided for @fixedOthers.
  ///
  /// In es, this message translates to:
  /// **'Otros pagos fijos'**
  String get fixedOthers;

  /// No description provided for @fixedPausedTitle.
  ///
  /// In es, this message translates to:
  /// **'En pausa'**
  String get fixedPausedTitle;

  /// No description provided for @fixedNote.
  ///
  /// In es, this message translates to:
  /// **'Quincena no paga ni cancela nada: eso se hace con tu banco o con cada servicio.'**
  String get fixedNote;

  /// No description provided for @fixedNextOn.
  ///
  /// In es, this message translates to:
  /// **'próximo cobro el {date}'**
  String fixedNextOn(String date);

  /// No description provided for @fixedPaused.
  ///
  /// In es, this message translates to:
  /// **'en pausa'**
  String get fixedPaused;

  /// No description provided for @fixedTrial.
  ///
  /// In es, this message translates to:
  /// **'Prueba gratis hasta el {date}'**
  String fixedTrial(String date);

  /// No description provided for @fixedNotUsed.
  ///
  /// In es, this message translates to:
  /// **'Dijiste que ya no la usas: pausarla te ahorra {amount} al año'**
  String fixedNotUsed(String amount);

  /// No description provided for @fixedPriceUp.
  ///
  /// In es, this message translates to:
  /// **'Subió de {from} a {to} el {date}'**
  String fixedPriceUp(String from, String to, String date);

  /// No description provided for @fixedPriceDown.
  ///
  /// In es, this message translates to:
  /// **'Bajó de {from} a {to} el {date}'**
  String fixedPriceDown(String from, String to, String date);

  /// No description provided for @fixedFollowLast.
  ///
  /// In es, this message translates to:
  /// **'Actualizar a {amount}, como el último cobro'**
  String fixedFollowLast(String amount);

  /// No description provided for @fixedReminds.
  ///
  /// In es, this message translates to:
  /// **'Con aviso'**
  String get fixedReminds;

  /// No description provided for @instalTitle.
  ///
  /// In es, this message translates to:
  /// **'Compras a cuotas'**
  String get instalTitle;

  /// No description provided for @instalAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar compra a cuotas'**
  String get instalAdd;

  /// No description provided for @instalEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar compra a cuotas'**
  String get instalEdit;

  /// No description provided for @instalBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que compraste a cuotas, con los datos que te dio el banco o la tienda. Lo que no sepas queda como estimado, nunca como definitivo.'**
  String get instalBody;

  /// No description provided for @instalEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no registras compras a cuotas.'**
  String get instalEmpty;

  /// No description provided for @instalCardNote.
  ///
  /// In es, this message translates to:
  /// **'Si compraste con una tarjeta que tienes en Quincena, la compra cuenta una sola vez, el día que la hiciste. Pagar la tarjeta es mover plata entre tus cuentas, no un gasto nuevo.'**
  String get instalCardNote;

  /// No description provided for @instalOwed.
  ///
  /// In es, this message translates to:
  /// **'Te falta pagar'**
  String get instalOwed;

  /// No description provided for @instalOwedKnown.
  ///
  /// In es, this message translates to:
  /// **'Con los datos que diste.'**
  String get instalOwedKnown;

  /// No description provided for @instalOwedEstimated.
  ///
  /// In es, this message translates to:
  /// **'Estimado: falta algún dato del banco.'**
  String get instalOwedEstimated;

  /// No description provided for @instalOwedUnknown.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Una compra no tiene datos para calcular.} other{{count} compras no tienen datos para calcular.}}'**
  String instalOwedUnknown(int count);

  /// No description provided for @instalList.
  ///
  /// In es, this message translates to:
  /// **'Tus compras'**
  String get instalList;

  /// No description provided for @instalNoData.
  ///
  /// In es, this message translates to:
  /// **'Falta la tasa o el valor de la cuota'**
  String get instalNoData;

  /// No description provided for @instalPaidOff.
  ///
  /// In es, this message translates to:
  /// **'Pagada'**
  String get instalPaidOff;

  /// No description provided for @instalNextRow.
  ///
  /// In es, this message translates to:
  /// **'Cuota {number} de {count}: {date}'**
  String instalNextRow(int number, int count, String date);

  /// No description provided for @instalEstimated.
  ///
  /// In es, this message translates to:
  /// **'estimado'**
  String get instalEstimated;

  /// No description provided for @instalUnknown.
  ///
  /// In es, this message translates to:
  /// **'Sin datos'**
  String get instalUnknown;

  /// No description provided for @instalTotalUnknown.
  ///
  /// In es, this message translates to:
  /// **'Sin la tasa ni el valor de la cuota no se puede calcular el total.'**
  String get instalTotalUnknown;

  /// No description provided for @instalTotalKnown.
  ///
  /// In es, this message translates to:
  /// **'En total pagarás {amount}, con los datos que diste.'**
  String instalTotalKnown(String amount);

  /// No description provided for @instalTotalEstimated.
  ///
  /// In es, this message translates to:
  /// **'En total pagarás unos {amount}: es un estimado, porque falta la cuota de manejo o el seguro.'**
  String instalTotalEstimated(String amount);

  /// No description provided for @instalVsCash.
  ///
  /// In es, this message translates to:
  /// **'De contado costaba {cash}: a cuotas pagas {extra} más.'**
  String instalVsCash(String cash, String extra);

  /// No description provided for @instalVsCashAtLeast.
  ///
  /// In es, this message translates to:
  /// **'De contado costaba {cash}: a cuotas pagas al menos {extra} más.'**
  String instalVsCashAtLeast(String cash, String extra);

  /// No description provided for @instalVsCashSame.
  ///
  /// In es, this message translates to:
  /// **'De contado costaba {cash}: a cuotas no pagas más.'**
  String instalVsCashSame(String cash);

  /// No description provided for @instalProgress.
  ///
  /// In es, this message translates to:
  /// **'Llevas {covered} de {count} cuotas'**
  String instalProgress(int covered, int count);

  /// No description provided for @instalOwing.
  ///
  /// In es, this message translates to:
  /// **'A la cuota {number} le faltan {amount}.'**
  String instalOwing(int number, String amount);

  /// No description provided for @instalLate.
  ///
  /// In es, this message translates to:
  /// **'La cuota {number} era el {date}. Si ya la pagaste, regístrala para llevar la cuenta.'**
  String instalLate(int number, String date);

  /// No description provided for @instalPay.
  ///
  /// In es, this message translates to:
  /// **'Registrar un pago'**
  String get instalPay;

  /// No description provided for @instalFacts.
  ///
  /// In es, this message translates to:
  /// **'Lo que dijo el banco'**
  String get instalFacts;

  /// No description provided for @instalFinanced.
  ///
  /// In es, this message translates to:
  /// **'Valor financiado'**
  String get instalFinanced;

  /// No description provided for @instalCount.
  ///
  /// In es, this message translates to:
  /// **'Cuotas'**
  String get instalCount;

  /// No description provided for @instalRate.
  ///
  /// In es, this message translates to:
  /// **'Tasa'**
  String get instalRate;

  /// No description provided for @instalRateValue.
  ///
  /// In es, this message translates to:
  /// **'{rate} {kind} ({monthly} al mes)'**
  String instalRateValue(String rate, String kind, String monthly);

  /// No description provided for @instalNotKnown.
  ///
  /// In es, this message translates to:
  /// **'No la sabes'**
  String get instalNotKnown;

  /// No description provided for @instalPayment.
  ///
  /// In es, this message translates to:
  /// **'Cuota'**
  String get instalPayment;

  /// No description provided for @instalPaymentStated.
  ///
  /// In es, this message translates to:
  /// **'{amount}, la que dijo el banco'**
  String instalPaymentStated(String amount);

  /// No description provided for @instalPaymentWorked.
  ///
  /// In es, this message translates to:
  /// **'{amount}, calculada con la tasa'**
  String instalPaymentWorked(String amount);

  /// No description provided for @instalFee.
  ///
  /// In es, this message translates to:
  /// **'Cuota de manejo o seguro'**
  String get instalFee;

  /// No description provided for @instalNoFee.
  ///
  /// In es, this message translates to:
  /// **'No tiene'**
  String get instalNoFee;

  /// No description provided for @instalPaysFrom.
  ///
  /// In es, this message translates to:
  /// **'Con qué la pagas'**
  String get instalPaysFrom;

  /// No description provided for @instalOutside.
  ///
  /// In es, this message translates to:
  /// **'Fuera de Quincena: tienda o crédito'**
  String get instalOutside;

  /// No description provided for @instalCountedOnce.
  ///
  /// In es, this message translates to:
  /// **'La compra ya está en esa cuenta: sus cuotas no se suman otra vez a lo comprometido.'**
  String get instalCountedOnce;

  /// No description provided for @instalCountedAsComing.
  ///
  /// In es, this message translates to:
  /// **'Las cuotas que vienen se cuentan como comprometidas.'**
  String get instalCountedAsComing;

  /// No description provided for @instalPayments.
  ///
  /// In es, this message translates to:
  /// **'Pagos'**
  String get instalPayments;

  /// No description provided for @instalNoPayments.
  ///
  /// In es, this message translates to:
  /// **'Aún no registras pagos.'**
  String get instalNoPayments;

  /// No description provided for @instalPaymentRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar este pago'**
  String get instalPaymentRemove;

  /// No description provided for @instalSchedule.
  ///
  /// In es, this message translates to:
  /// **'Calendario de cuotas'**
  String get instalSchedule;

  /// No description provided for @instalNoSchedule.
  ///
  /// In es, this message translates to:
  /// **'Con la tasa o el valor de la cuota se arma el calendario.'**
  String get instalNoSchedule;

  /// No description provided for @instalRow.
  ///
  /// In es, this message translates to:
  /// **'Cuota {number} · {date}'**
  String instalRow(int number, String date);

  /// No description provided for @instalRowSplit.
  ///
  /// In es, this message translates to:
  /// **'Interés {interest} · capital {principal} · quedan {balance}'**
  String instalRowSplit(String interest, String principal, String balance);

  /// No description provided for @instalRowLeft.
  ///
  /// In es, this message translates to:
  /// **'Quedan {balance}'**
  String instalRowLeft(String balance);

  /// No description provided for @instalRowPaid.
  ///
  /// In es, this message translates to:
  /// **'Pagada'**
  String get instalRowPaid;

  /// No description provided for @instalPaymentAmount.
  ///
  /// In es, this message translates to:
  /// **'Valor pagado'**
  String get instalPaymentAmount;

  /// No description provided for @instalPaymentInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe cuánto pagaste.'**
  String get instalPaymentInvalid;

  /// No description provided for @instalPaymentPartial.
  ///
  /// In es, this message translates to:
  /// **'Puede ser menos que la cuota: lo que falte queda pendiente.'**
  String get instalPaymentPartial;

  /// No description provided for @instalDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar compra'**
  String get instalDelete;

  /// No description provided for @instalDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar {name}?'**
  String instalDeleteTitle(String name);

  /// No description provided for @instalDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se borran sus datos y pagos aquí. Tus movimientos no se tocan.'**
  String get instalDeleteBody;

  /// No description provided for @instalSheetBody.
  ///
  /// In es, this message translates to:
  /// **'Copia los datos del extracto o del contrato. Lo que no sepas, déjalo vacío.'**
  String get instalSheetBody;

  /// No description provided for @instalName.
  ///
  /// In es, this message translates to:
  /// **'¿Qué compraste?'**
  String get instalName;

  /// No description provided for @instalPrincipal.
  ///
  /// In es, this message translates to:
  /// **'Valor financiado'**
  String get instalPrincipal;

  /// No description provided for @instalCountField.
  ///
  /// In es, this message translates to:
  /// **'Número de cuotas'**
  String get instalCountField;

  /// No description provided for @instalFirstDue.
  ///
  /// In es, this message translates to:
  /// **'Primera cuota: {date}'**
  String instalFirstDue(String date);

  /// No description provided for @instalRateField.
  ///
  /// In es, this message translates to:
  /// **'Tasa de interés'**
  String get instalRateField;

  /// No description provided for @instalRateKind.
  ///
  /// In es, this message translates to:
  /// **'Cómo la dicen'**
  String get instalRateKind;

  /// No description provided for @instalRateHelp.
  ///
  /// In es, this message translates to:
  /// **'Como aparece en el extracto: efectiva anual (E.A.), nominal mes vencido (M.V.) o mensual. Una tasa de 0 también es un dato: sin interés.'**
  String get instalRateHelp;

  /// No description provided for @rateEffectiveAnnual.
  ///
  /// In es, this message translates to:
  /// **'E.A.'**
  String get rateEffectiveAnnual;

  /// No description provided for @rateNominalMonthly.
  ///
  /// In es, this message translates to:
  /// **'M.V.'**
  String get rateNominalMonthly;

  /// No description provided for @rateMonthly.
  ///
  /// In es, this message translates to:
  /// **'mensual'**
  String get rateMonthly;

  /// No description provided for @instalStated.
  ///
  /// In es, this message translates to:
  /// **'Valor de la cuota, si te lo dieron'**
  String get instalStated;

  /// No description provided for @instalStatedHelp.
  ///
  /// In es, this message translates to:
  /// **'Sin la cuota de manejo. Si no lo sabes, se calcula con la tasa.'**
  String get instalStatedHelp;

  /// No description provided for @instalFeeField.
  ///
  /// In es, this message translates to:
  /// **'Cuota de manejo o seguro, por cuota'**
  String get instalFeeField;

  /// No description provided for @instalFeeHelp.
  ///
  /// In es, this message translates to:
  /// **'Escribe 0 si no tiene. Si no lo sabes, déjalo vacío: el total quedará como estimado.'**
  String get instalFeeHelp;

  /// No description provided for @instalCash.
  ///
  /// In es, this message translates to:
  /// **'Precio de contado'**
  String get instalCash;

  /// No description provided for @instalCashHelp.
  ///
  /// In es, this message translates to:
  /// **'Para comparar cuánto cuesta pagar a cuotas.'**
  String get instalCashHelp;

  /// No description provided for @instalIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Falta el nombre, el valor financiado o el número de cuotas.'**
  String get instalIncomplete;

  /// No description provided for @detectiveTitle.
  ///
  /// In es, this message translates to:
  /// **'Cargos para revisar'**
  String get detectiveTitle;

  /// No description provided for @detectiveBody.
  ///
  /// In es, this message translates to:
  /// **'Quincena mira tus movimientos de los últimos 60 días, aquí en el teléfono, y te muestra lo que vale la pena revisar, con la evidencia. Nunca borra un movimiento ni dice que algo sea fraude.'**
  String get detectiveBody;

  /// No description provided for @detectiveEmpty.
  ///
  /// In es, this message translates to:
  /// **'Nada para revisar por ahora.'**
  String get detectiveEmpty;

  /// No description provided for @detectiveOpen.
  ///
  /// In es, this message translates to:
  /// **'Para revisar'**
  String get detectiveOpen;

  /// No description provided for @detectiveReviewing.
  ///
  /// In es, this message translates to:
  /// **'Lo vas a revisar'**
  String get detectiveReviewing;

  /// No description provided for @detectiveShowPutAway.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Ver la que marcaste} other{Ver las {count} que marcaste}}'**
  String detectiveShowPutAway(int count);

  /// No description provided for @detectiveHidePutAway.
  ///
  /// In es, this message translates to:
  /// **'Ocultar las que marcaste'**
  String get detectiveHidePutAway;

  /// No description provided for @detectiveWhat.
  ///
  /// In es, this message translates to:
  /// **'Qué revisar'**
  String get detectiveWhat;

  /// No description provided for @detectiveKindTwice.
  ///
  /// In es, this message translates to:
  /// **'Pagos repetidos'**
  String get detectiveKindTwice;

  /// No description provided for @detectiveKindPriceUp.
  ///
  /// In es, this message translates to:
  /// **'Subidas de precio'**
  String get detectiveKindPriceUp;

  /// No description provided for @detectiveKindUnusual.
  ///
  /// In es, this message translates to:
  /// **'Cargos fuera de lo común'**
  String get detectiveKindUnusual;

  /// No description provided for @detectiveRuleTwice.
  ///
  /// In es, this message translates to:
  /// **'Mismo valor, comercio y cuenta, con menos de un día y medio de diferencia.'**
  String get detectiveRuleTwice;

  /// No description provided for @detectiveRulePriceUp.
  ///
  /// In es, this message translates to:
  /// **'Un comercio que cobraba lo mismo, al menos dos días distintos, y en el último cobro subió 5 % o más.'**
  String get detectiveRulePriceUp;

  /// No description provided for @detectiveRuleUnusual.
  ///
  /// In es, this message translates to:
  /// **'Un cargo de tres veces o más lo que sueles gastar en esa categoría y esa cuenta.'**
  String get detectiveRuleUnusual;

  /// No description provided for @detectiveTwiceSeenTitle.
  ///
  /// In es, this message translates to:
  /// **'Puede ser el mismo pago visto dos veces'**
  String get detectiveTwiceSeenTitle;

  /// No description provided for @detectiveTwiceSeenWhy.
  ///
  /// In es, this message translates to:
  /// **'Mismo valor, comercio y cuenta, muy seguidos, pero llegaron por caminos distintos: {first} y {second}. Lo más probable es que sea un solo pago registrado dos veces. Si sobra uno, ábrelo y bórralo tú.'**
  String detectiveTwiceSeenWhy(String first, String second);

  /// No description provided for @detectiveTwiceTitle.
  ///
  /// In es, this message translates to:
  /// **'Dos cobros iguales, muy seguidos'**
  String get detectiveTwiceTitle;

  /// No description provided for @detectiveTwiceWhy.
  ///
  /// In es, this message translates to:
  /// **'Mismo valor, comercio y cuenta, y llegaron por el mismo camino: pueden ser dos cobros reales. Si hiciste una sola compra, revísalo con tu banco.'**
  String get detectiveTwiceWhy;

  /// No description provided for @detectivePriceUpTitle.
  ///
  /// In es, this message translates to:
  /// **'{merchant} cobra más que antes'**
  String detectivePriceUpTitle(String merchant);

  /// No description provided for @detectivePriceUpWhy.
  ///
  /// In es, this message translates to:
  /// **'Solía cobrar {before} y el último cobro fue {now}, un {percent} más. Que suba no quiere decir que esté mal: puede ser un cambio de plan o de tarifa.'**
  String detectivePriceUpWhy(String before, String now, String percent);

  /// No description provided for @detectiveUnusualTitle.
  ///
  /// In es, this message translates to:
  /// **'Mucho más de lo usual en {category}'**
  String detectiveUnusualTitle(String category);

  /// No description provided for @detectiveUnusualWhy.
  ///
  /// In es, this message translates to:
  /// **'Es unas {times} veces lo que sueles gastar por compra en {category} en esta cuenta. Puede ser una compra grande que planeaste.'**
  String detectiveUnusualWhy(String times, String category);

  /// No description provided for @detectiveExpected.
  ///
  /// In es, this message translates to:
  /// **'Es esperado'**
  String get detectiveExpected;

  /// No description provided for @detectiveReview.
  ///
  /// In es, this message translates to:
  /// **'Lo voy a revisar'**
  String get detectiveReview;

  /// No description provided for @detectiveDismiss.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get detectiveDismiss;

  /// No description provided for @detectiveShowAgain.
  ///
  /// In es, this message translates to:
  /// **'Volver a mostrar'**
  String get detectiveShowAgain;

  /// No description provided for @sourceManual.
  ///
  /// In es, this message translates to:
  /// **'A mano'**
  String get sourceManual;

  /// No description provided for @sourceStatement.
  ///
  /// In es, this message translates to:
  /// **'Extracto'**
  String get sourceStatement;

  /// No description provided for @sourceGemini.
  ///
  /// In es, this message translates to:
  /// **'Conversación con Gemini'**
  String get sourceGemini;

  /// No description provided for @sourceOther.
  ///
  /// In es, this message translates to:
  /// **'Otra fuente'**
  String get sourceOther;

  /// No description provided for @planCommitments.
  ///
  /// In es, this message translates to:
  /// **'Pagos'**
  String get planCommitments;

  /// No description provided for @planFixedNext30.
  ///
  /// In es, this message translates to:
  /// **'{amount} en los próximos 30 días'**
  String planFixedNext30(String amount);

  /// No description provided for @planFixedGuesses.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Uno parece pago fijo: revísalo} other{{count} parecen pagos fijos: revísalos}}'**
  String planFixedGuesses(int count);

  /// No description provided for @planFixedNone.
  ///
  /// In es, this message translates to:
  /// **'Arriendo, servicios, suscripciones'**
  String get planFixedNone;

  /// No description provided for @planInstalNone.
  ///
  /// In es, this message translates to:
  /// **'Ninguna registrada'**
  String get planInstalNone;

  /// No description provided for @planInstalOwed.
  ///
  /// In es, this message translates to:
  /// **'Te falta pagar {amount}'**
  String planInstalOwed(String amount);

  /// No description provided for @planInstalOwedEstimated.
  ///
  /// In es, this message translates to:
  /// **'Te falta pagar unos {amount}'**
  String planInstalOwedEstimated(String amount);

  /// No description provided for @planDetective.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un cargo para revisar} other{{count} cargos para revisar}}'**
  String planDetective(int count);

  /// No description provided for @planDetectiveNone.
  ///
  /// In es, this message translates to:
  /// **'Nada raro por ahora'**
  String get planDetectiveNone;

  /// No description provided for @computedCommitments.
  ///
  /// In es, this message translates to:
  /// **'Lo ya comprometido en los próximos 30 días'**
  String get computedCommitments;

  /// No description provided for @comingIncome.
  ///
  /// In es, this message translates to:
  /// **'Cobro esperado: {client}'**
  String comingIncome(String client);

  /// No description provided for @computedOwed.
  ///
  /// In es, this message translates to:
  /// **'Lo que te deben, tus cobros y tus viajes'**
  String get computedOwed;

  /// No description provided for @freeExplainReserved.
  ///
  /// In es, this message translates to:
  /// **'Reserva de ingresos variables'**
  String get freeExplainReserved;

  /// No description provided for @messageCopied.
  ///
  /// In es, this message translates to:
  /// **'Mensaje copiado: pégalo donde quieras enviarlo.'**
  String get messageCopied;

  /// No description provided for @rateSourceManual.
  ///
  /// In es, this message translates to:
  /// **'tu tasa'**
  String get rateSourceManual;

  /// No description provided for @planSharedNone.
  ///
  /// In es, this message translates to:
  /// **'Divide una cuenta y lleva lo que te deben'**
  String get planSharedNone;

  /// No description provided for @planShared.
  ///
  /// In es, this message translates to:
  /// **'Te deben {owed} · debes {owing}'**
  String planShared(String owed, String owing);

  /// No description provided for @planFreelanceNone.
  ///
  /// In es, this message translates to:
  /// **'Cobros pendientes, estimados y una reserva'**
  String get planFreelanceNone;

  /// No description provided for @planFreelance.
  ///
  /// In es, this message translates to:
  /// **'{amount} por cobrar'**
  String planFreelance(String amount);

  /// No description provided for @planFreelanceLate.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un cobro vencido} other{{count} cobros vencidos}}'**
  String planFreelanceLate(int count);

  /// No description provided for @planTripsNone.
  ///
  /// In es, this message translates to:
  /// **'Un presupuesto en la moneda del viaje'**
  String get planTripsNone;

  /// No description provided for @planTripLeft.
  ///
  /// In es, this message translates to:
  /// **'{trip}: te quedan {amount}'**
  String planTripLeft(String trip, String amount);

  /// No description provided for @splitTitle.
  ///
  /// In es, this message translates to:
  /// **'Dividir un gasto'**
  String get splitTitle;

  /// No description provided for @splitBody.
  ///
  /// In es, this message translates to:
  /// **'Nadie más necesita la app: escribe los nombres. Lo que te deben no cuenta como plata para gastar hasta que te paguen.'**
  String get splitBody;

  /// No description provided for @splitGroup.
  ///
  /// In es, this message translates to:
  /// **'Grupo'**
  String get splitGroup;

  /// No description provided for @splitNewGroup.
  ///
  /// In es, this message translates to:
  /// **'Un grupo nuevo'**
  String get splitNewGroup;

  /// No description provided for @splitWithWhom.
  ///
  /// In es, this message translates to:
  /// **'¿Con quién lo divides?'**
  String get splitWithWhom;

  /// No description provided for @splitWithWhomHelp.
  ///
  /// In es, this message translates to:
  /// **'Nombres separados por comas: Ana, Juan'**
  String get splitWithWhomHelp;

  /// No description provided for @splitGroupName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del grupo'**
  String get splitGroupName;

  /// No description provided for @splitWhat.
  ///
  /// In es, this message translates to:
  /// **'¿Qué fue?'**
  String get splitWhat;

  /// No description provided for @splitAmount.
  ///
  /// In es, this message translates to:
  /// **'Valor total'**
  String get splitAmount;

  /// No description provided for @splitFromEntry.
  ///
  /// In es, this message translates to:
  /// **'El del movimiento: no se cambia.'**
  String get splitFromEntry;

  /// No description provided for @splitPaidBy.
  ///
  /// In es, this message translates to:
  /// **'¿Quién pagó?'**
  String get splitPaidBy;

  /// No description provided for @splitEven.
  ///
  /// In es, this message translates to:
  /// **'En partes iguales'**
  String get splitEven;

  /// No description provided for @splitCustom.
  ///
  /// In es, this message translates to:
  /// **'Por montos'**
  String get splitCustom;

  /// No description provided for @splitPartOf.
  ///
  /// In es, this message translates to:
  /// **'Parte de {name}'**
  String splitPartOf(String name);

  /// No description provided for @splitRest.
  ///
  /// In es, this message translates to:
  /// **'Para que el total cuadre, los {amount} del redondeo quedan en la parte de {name}.'**
  String splitRest(String amount, String name);

  /// No description provided for @splitRestYou.
  ///
  /// In es, this message translates to:
  /// **'Para que el total cuadre, los {amount} del redondeo quedan en tu parte.'**
  String splitRestYou(String amount);

  /// No description provided for @splitPartYou.
  ///
  /// In es, this message translates to:
  /// **'Tu parte'**
  String get splitPartYou;

  /// No description provided for @splitMissing.
  ///
  /// In es, this message translates to:
  /// **'Faltan {amount} para el total'**
  String splitMissing(String amount);

  /// No description provided for @splitOver.
  ///
  /// In es, this message translates to:
  /// **'Sobran {amount} sobre el total'**
  String splitOver(String amount);

  /// No description provided for @splitYourPart.
  ///
  /// In es, this message translates to:
  /// **'Tu parte es {mine}; {others} te los deben.'**
  String splitYourPart(String mine, String others);

  /// No description provided for @splitIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Falta el valor o con quién dividirlo.'**
  String get splitIncomplete;

  /// No description provided for @splitDoesNotAddUp.
  ///
  /// In es, this message translates to:
  /// **'Las partes no suman el total.'**
  String get splitDoesNotAddUp;

  /// No description provided for @splitNeedsSomeone.
  ///
  /// In es, this message translates to:
  /// **'Agrega al menos a una persona más.'**
  String get splitNeedsSomeone;

  /// No description provided for @splitNeedsShare.
  ///
  /// In es, this message translates to:
  /// **'Marca al menos a otra persona con su parte.'**
  String get splitNeedsShare;

  /// No description provided for @splitRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar la división'**
  String get splitRemove;

  /// No description provided for @splitThis.
  ///
  /// In es, this message translates to:
  /// **'Dividir este gasto'**
  String get splitThis;

  /// No description provided for @splitChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar la división'**
  String get splitChange;

  /// No description provided for @splitYours.
  ///
  /// In es, this message translates to:
  /// **'Dividido: tu parte {amount}'**
  String splitYours(String amount);

  /// No description provided for @sharedTitle.
  ///
  /// In es, this message translates to:
  /// **'Gastos compartidos'**
  String get sharedTitle;

  /// No description provided for @sharedBody.
  ///
  /// In es, this message translates to:
  /// **'Divide gastos con quien sea, sin que tenga la app. Lo que te deben no es plata para gastar: vuelve a serlo cuando te pagan.'**
  String get sharedBody;

  /// No description provided for @sharedEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no divides gastos. Crea un grupo, o abre un gasto en Movimientos y toca «Dividir este gasto».'**
  String get sharedEmpty;

  /// No description provided for @sharedNewGroup.
  ///
  /// In es, this message translates to:
  /// **'Nuevo grupo'**
  String get sharedNewGroup;

  /// No description provided for @sharedEditGroup.
  ///
  /// In es, this message translates to:
  /// **'Editar grupo'**
  String get sharedEditGroup;

  /// No description provided for @sharedGroupName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del grupo'**
  String get sharedGroupName;

  /// No description provided for @sharedAddPeople.
  ///
  /// In es, this message translates to:
  /// **'Agregar personas'**
  String get sharedAddPeople;

  /// No description provided for @sharedGroupIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Falta el nombre o alguien más en el grupo.'**
  String get sharedGroupIncomplete;

  /// No description provided for @sharedOwedToYou.
  ///
  /// In es, this message translates to:
  /// **'Te deben'**
  String get sharedOwedToYou;

  /// No description provided for @sharedYouOwe.
  ///
  /// In es, this message translates to:
  /// **'Debes'**
  String get sharedYouOwe;

  /// No description provided for @sharedNotCash.
  ///
  /// In es, this message translates to:
  /// **'Lo que te deben no se suma a lo que puedes gastar hasta que llega.'**
  String get sharedNotCash;

  /// No description provided for @sharedGroups.
  ///
  /// In es, this message translates to:
  /// **'Grupos'**
  String get sharedGroups;

  /// No description provided for @sharedOwesYouShort.
  ///
  /// In es, this message translates to:
  /// **'Te deben {amount}'**
  String sharedOwesYouShort(String amount);

  /// No description provided for @sharedYouOweShort.
  ///
  /// In es, this message translates to:
  /// **'Debes {amount}'**
  String sharedYouOweShort(String amount);

  /// No description provided for @sharedEven.
  ///
  /// In es, this message translates to:
  /// **'A paz y salvo'**
  String get sharedEven;

  /// No description provided for @sharedYou.
  ///
  /// In es, this message translates to:
  /// **'Tú'**
  String get sharedYou;

  /// No description provided for @sharedDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar grupo'**
  String get sharedDelete;

  /// No description provided for @sharedDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar {name}?'**
  String sharedDeleteTitle(String name);

  /// No description provided for @sharedDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se borran el grupo, sus gastos y sus pagos aquí. Tus movimientos no se tocan.'**
  String get sharedDeleteBody;

  /// No description provided for @sharedAddExpense.
  ///
  /// In es, this message translates to:
  /// **'Agregar gasto'**
  String get sharedAddExpense;

  /// No description provided for @sharedOwedToYouIn.
  ///
  /// In es, this message translates to:
  /// **'En este grupo te deben {amount}'**
  String sharedOwedToYouIn(String amount);

  /// No description provided for @sharedYouOweIn.
  ///
  /// In es, this message translates to:
  /// **'En este grupo debes {amount}'**
  String sharedYouOweIn(String amount);

  /// No description provided for @sharedAllEven.
  ///
  /// In es, this message translates to:
  /// **'Todos están a paz y salvo'**
  String get sharedAllEven;

  /// No description provided for @sharedToSettle.
  ///
  /// In es, this message translates to:
  /// **'Para quedar a paz y salvo'**
  String get sharedToSettle;

  /// No description provided for @sharedPaysYou.
  ///
  /// In es, this message translates to:
  /// **'{name} te paga {amount}'**
  String sharedPaysYou(String name, String amount);

  /// No description provided for @sharedYouPay.
  ///
  /// In es, this message translates to:
  /// **'Le pagas a {name} {amount}'**
  String sharedYouPay(String name, String amount);

  /// No description provided for @sharedPays.
  ///
  /// In es, this message translates to:
  /// **'{from} le paga a {to} {amount}'**
  String sharedPays(String from, String to, String amount);

  /// No description provided for @sharedRemind.
  ///
  /// In es, this message translates to:
  /// **'Recordar'**
  String get sharedRemind;

  /// No description provided for @sharedReminderMessage.
  ///
  /// In es, this message translates to:
  /// **'Hola, {name}. Te escribo por los {amount} de {group}. Cuando puedas me los pasas. ¡Gracias!'**
  String sharedReminderMessage(String name, String amount, String group);

  /// No description provided for @sharedRecordPayment.
  ///
  /// In es, this message translates to:
  /// **'Registrar pago'**
  String get sharedRecordPayment;

  /// No description provided for @sharedExpenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get sharedExpenses;

  /// No description provided for @sharedNoExpenses.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay gastos en este grupo.'**
  String get sharedNoExpenses;

  /// No description provided for @sharedPaidBy.
  ///
  /// In es, this message translates to:
  /// **'pagó {name}'**
  String sharedPaidBy(String name);

  /// No description provided for @sharedPaidByYou.
  ///
  /// In es, this message translates to:
  /// **'pagaste tú'**
  String get sharedPaidByYou;

  /// No description provided for @sharedYourShare.
  ///
  /// In es, this message translates to:
  /// **'tu parte {amount}'**
  String sharedYourShare(String amount);

  /// No description provided for @sharedPayments.
  ///
  /// In es, this message translates to:
  /// **'Pagos'**
  String get sharedPayments;

  /// No description provided for @sharedPaid.
  ///
  /// In es, this message translates to:
  /// **'{from} le pagó a {to}'**
  String sharedPaid(String from, String to);

  /// No description provided for @sharedPaidYou.
  ///
  /// In es, this message translates to:
  /// **'{from} te pagó'**
  String sharedPaidYou(String from);

  /// No description provided for @sharedYouPaid.
  ///
  /// In es, this message translates to:
  /// **'Le pagaste a {to}'**
  String sharedYouPaid(String to);

  /// No description provided for @sharedLinked.
  ///
  /// In es, this message translates to:
  /// **'llegó a tu cuenta'**
  String get sharedLinked;

  /// No description provided for @sharedRemovePayment.
  ///
  /// In es, this message translates to:
  /// **'Quitar este pago'**
  String get sharedRemovePayment;

  /// No description provided for @sharedLedgerNote.
  ///
  /// In es, this message translates to:
  /// **'De un gasto que pagaste por otros, solo tu parte cuenta como gasto; el resto es plata prestada. Cuando te la devuelven no es un ingreso: es plata que vuelve.'**
  String get sharedLedgerNote;

  /// No description provided for @sharedArrivedAs.
  ///
  /// In es, this message translates to:
  /// **'¿Llegó a una de tus cuentas?'**
  String get sharedArrivedAs;

  /// No description provided for @sharedNotRecorded.
  ///
  /// In es, this message translates to:
  /// **'No, o no está en Quincena'**
  String get sharedNotRecorded;

  /// No description provided for @sharedArrivedAsHelp.
  ///
  /// In es, this message translates to:
  /// **'Si eliges el movimiento, cuenta como plata que vuelve y no como ingreso.'**
  String get sharedArrivedAsHelp;

  /// No description provided for @freelanceTitle.
  ///
  /// In es, this message translates to:
  /// **'Ingresos variables'**
  String get freelanceTitle;

  /// No description provided for @freelanceBody.
  ///
  /// In es, this message translates to:
  /// **'Para cuando tus ingresos cambian de un mes a otro. Separa lo cobrado, lo pendiente y lo estimado. Quincena no calcula impuestos: la reserva la decides tú.'**
  String get freelanceBody;

  /// No description provided for @freelanceAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar cobro'**
  String get freelanceAdd;

  /// No description provided for @freelanceEdit.
  ///
  /// In es, this message translates to:
  /// **'Cobro'**
  String get freelanceEdit;

  /// No description provided for @freelancePending.
  ///
  /// In es, this message translates to:
  /// **'Por cobrar'**
  String get freelancePending;

  /// No description provided for @freelanceEstimated.
  ///
  /// In es, this message translates to:
  /// **'Estimado'**
  String get freelanceEstimated;

  /// No description provided for @freelanceReserve.
  ///
  /// In es, this message translates to:
  /// **'Reserva'**
  String get freelanceReserve;

  /// No description provided for @freelanceOverdueNote.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un cobro vencido por {amount}.} other{{count} cobros vencidos por {amount}.}}'**
  String freelanceOverdueNote(int count, String amount);

  /// No description provided for @freelanceOverdue.
  ///
  /// In es, this message translates to:
  /// **'Vencidos'**
  String get freelanceOverdue;

  /// No description provided for @freelancePendingList.
  ///
  /// In es, this message translates to:
  /// **'Pendientes'**
  String get freelancePendingList;

  /// No description provided for @freelanceEstimatedList.
  ///
  /// In es, this message translates to:
  /// **'Estimados'**
  String get freelanceEstimatedList;

  /// No description provided for @freelanceCollectedList.
  ///
  /// In es, this message translates to:
  /// **'Cobrados'**
  String get freelanceCollectedList;

  /// No description provided for @freelanceScenario.
  ///
  /// In es, this message translates to:
  /// **'Qué contar en los próximos días'**
  String get freelanceScenario;

  /// No description provided for @scenarioCollected.
  ///
  /// In es, this message translates to:
  /// **'Lo cobrado'**
  String get scenarioCollected;

  /// No description provided for @scenarioPending.
  ///
  /// In es, this message translates to:
  /// **'Lo facturado'**
  String get scenarioPending;

  /// No description provided for @scenarioEstimated.
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get scenarioEstimated;

  /// No description provided for @scenarioCollectedBody.
  ///
  /// In es, this message translates to:
  /// **'Solo la plata que ya tienes. Lo más prudente para un mes difícil.'**
  String get scenarioCollectedBody;

  /// No description provided for @scenarioPendingBody.
  ///
  /// In es, this message translates to:
  /// **'También lo facturado, el día que lo esperas. Si se atrasa, se corre al día siguiente, y nunca cuenta en lo que puedes gastar hasta que llega.'**
  String get scenarioPendingBody;

  /// No description provided for @scenarioEstimatedBody.
  ///
  /// In es, this message translates to:
  /// **'También lo que crees que vendrá sin haberlo facturado. Lo menos prudente: úsalo con cuidado.'**
  String get scenarioEstimatedBody;

  /// No description provided for @freelanceReservePercent.
  ///
  /// In es, this message translates to:
  /// **'Apartar de cada cobro'**
  String get freelanceReservePercent;

  /// No description provided for @freelanceNoReserve.
  ///
  /// In es, this message translates to:
  /// **'Nada'**
  String get freelanceNoReserve;

  /// No description provided for @freelanceReserveNow.
  ///
  /// In es, this message translates to:
  /// **'Tienes apartados {amount} desde el {date}. No cuentan en lo que puedes gastar, pero siguen en tus cuentas.'**
  String freelanceReserveNow(String amount, String date);

  /// No description provided for @freelanceReserveOff.
  ///
  /// In es, this message translates to:
  /// **'Sin reserva: todo lo que cobras cuenta en lo que puedes gastar.'**
  String get freelanceReserveOff;

  /// No description provided for @freelanceNoTax.
  ///
  /// In es, this message translates to:
  /// **'Quincena no calcula impuestos ni sabe cuánto te toca pagar: el porcentaje es tuyo.'**
  String get freelanceNoTax;

  /// No description provided for @freelanceUse.
  ///
  /// In es, this message translates to:
  /// **'Usé de la reserva'**
  String get freelanceUse;

  /// No description provided for @freelanceUseAmount.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto usaste?'**
  String get freelanceUseAmount;

  /// No description provided for @freelanceUseHelp.
  ///
  /// In es, this message translates to:
  /// **'Por ejemplo, lo que pagaste de impuestos o seguridad social.'**
  String get freelanceUseHelp;

  /// No description provided for @freelanceExpectedOn.
  ///
  /// In es, this message translates to:
  /// **'Esperado el {date}'**
  String freelanceExpectedOn(String date);

  /// No description provided for @freelanceCollectedOn.
  ///
  /// In es, this message translates to:
  /// **'Cobrado el {date}'**
  String freelanceCollectedOn(String date);

  /// No description provided for @freelanceLate.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, =1{Vencido hace un día: era el {date}} other{Vencido hace {days} días: era el {date}}}'**
  String freelanceLate(int days, String date);

  /// No description provided for @freelanceClient.
  ///
  /// In es, this message translates to:
  /// **'¿Quién te paga?'**
  String get freelanceClient;

  /// No description provided for @freelanceAmount.
  ///
  /// In es, this message translates to:
  /// **'Valor'**
  String get freelanceAmount;

  /// No description provided for @incomeEstimated.
  ///
  /// In es, this message translates to:
  /// **'Estimado'**
  String get incomeEstimated;

  /// No description provided for @incomePending.
  ///
  /// In es, this message translates to:
  /// **'Facturado'**
  String get incomePending;

  /// No description provided for @incomeCollected.
  ///
  /// In es, this message translates to:
  /// **'Cobrado'**
  String get incomeCollected;

  /// No description provided for @incomeEstimatedHelp.
  ///
  /// In es, this message translates to:
  /// **'Crees que vendrá, pero aún no lo facturas.'**
  String get incomeEstimatedHelp;

  /// No description provided for @incomePendingHelp.
  ///
  /// In es, this message translates to:
  /// **'Ya lo facturaste y esperas el pago.'**
  String get incomePendingHelp;

  /// No description provided for @incomeCollectedHelp.
  ///
  /// In es, this message translates to:
  /// **'La plata ya llegó.'**
  String get incomeCollectedHelp;

  /// No description provided for @freelanceArrivedAs.
  ///
  /// In es, this message translates to:
  /// **'¿Con qué movimiento llegó?'**
  String get freelanceArrivedAs;

  /// No description provided for @freelanceNote.
  ///
  /// In es, this message translates to:
  /// **'Nota'**
  String get freelanceNote;

  /// No description provided for @freelanceIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Falta quién te paga o el valor.'**
  String get freelanceIncomplete;

  /// No description provided for @freelanceRemind.
  ///
  /// In es, this message translates to:
  /// **'Recordar al cliente'**
  String get freelanceRemind;

  /// No description provided for @freelanceReminderMessage.
  ///
  /// In es, this message translates to:
  /// **'Hola, {client}. Te escribo por el pago de {amount} que esperaba el {date}. ¿Me confirmas cuándo lo puedes hacer? ¡Gracias!'**
  String freelanceReminderMessage(String client, String amount, String date);

  /// No description provided for @freelanceDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar cobro'**
  String get freelanceDelete;

  /// No description provided for @tripsTitle.
  ///
  /// In es, this message translates to:
  /// **'Viajes'**
  String get tripsTitle;

  /// No description provided for @tripsBody.
  ///
  /// In es, this message translates to:
  /// **'Un presupuesto en la moneda del viaje, contado con tus mismos movimientos: nada se copia.'**
  String get tripsBody;

  /// No description provided for @tripsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes viajes.'**
  String get tripsEmpty;

  /// No description provided for @tripsNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo viaje'**
  String get tripsNew;

  /// No description provided for @tripEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar viaje'**
  String get tripEdit;

  /// No description provided for @tripDelete.
  ///
  /// In es, this message translates to:
  /// **'Borrar viaje'**
  String get tripDelete;

  /// No description provided for @tripDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar {name}?'**
  String tripDeleteTitle(String name);

  /// No description provided for @tripDeleteBody.
  ///
  /// In es, this message translates to:
  /// **'Se borra el viaje aquí. Sus gastos siguen en tus cuentas.'**
  String get tripDeleteBody;

  /// No description provided for @tripLeftShort.
  ///
  /// In es, this message translates to:
  /// **'Quedan {amount}'**
  String tripLeftShort(String amount);

  /// No description provided for @tripSpentShort.
  ///
  /// In es, this message translates to:
  /// **'Gastaste {amount}'**
  String tripSpentShort(String amount);

  /// No description provided for @tripSpent.
  ///
  /// In es, this message translates to:
  /// **'Gastaste'**
  String get tripSpent;

  /// No description provided for @tripLeft.
  ///
  /// In es, this message translates to:
  /// **'Te quedan'**
  String get tripLeft;

  /// No description provided for @tripOf.
  ///
  /// In es, this message translates to:
  /// **'de {amount}'**
  String tripOf(String amount);

  /// No description provided for @tripPerDay.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, =1{Puedes gastar {amount} hoy, el último día.} other{Puedes gastar {amount} al día los {days} días que quedan.}}'**
  String tripPerDay(String amount, int days);

  /// No description provided for @tripAverage.
  ///
  /// In es, this message translates to:
  /// **'Llevas {amount} al día en promedio.'**
  String tripAverage(String amount);

  /// No description provided for @tripOver.
  ///
  /// In es, this message translates to:
  /// **'El viaje terminó.'**
  String get tripOver;

  /// No description provided for @tripUnconverted.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un gasto no tiene tasa para convertirlo y no cuenta.} other{{count} gastos no tienen tasa para convertirlos y no cuentan.}}'**
  String tripUnconverted(int count);

  /// No description provided for @tripShared.
  ///
  /// In es, this message translates to:
  /// **'Gastos compartidos del viaje'**
  String get tripShared;

  /// No description provided for @tripShare.
  ///
  /// In es, this message translates to:
  /// **'Dividir gastos del viaje con alguien'**
  String get tripShare;

  /// No description provided for @tripExpenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos del viaje'**
  String get tripExpenses;

  /// No description provided for @tripNoExpenses.
  ///
  /// In es, this message translates to:
  /// **'Los gastos de las fechas del viaje aparecen aquí solos. Agrega los que pagaste allá en su moneda.'**
  String get tripNoExpenses;

  /// No description provided for @tripIncludeEarlier.
  ///
  /// In es, this message translates to:
  /// **'Incluir un gasto de antes'**
  String get tripIncludeEarlier;

  /// No description provided for @tripIncludeEarlierBody.
  ///
  /// In es, this message translates to:
  /// **'El vuelo o el hotel que pagaste antes de salir.'**
  String get tripIncludeEarlierBody;

  /// No description provided for @tripNothingEarlier.
  ///
  /// In es, this message translates to:
  /// **'No hay gastos en los 120 días antes del viaje.'**
  String get tripNothingEarlier;

  /// No description provided for @tripSameMovements.
  ///
  /// In es, this message translates to:
  /// **'Un viaje usa tus mismos movimientos: cambiar uno aquí lo cambia en tu cuenta.'**
  String get tripSameMovements;

  /// No description provided for @tripNoRate.
  ///
  /// In es, this message translates to:
  /// **'Sin tasa'**
  String get tripNoRate;

  /// No description provided for @tripExclude.
  ///
  /// In es, this message translates to:
  /// **'No es del viaje'**
  String get tripExclude;

  /// No description provided for @tripForeign.
  ///
  /// In es, this message translates to:
  /// **'{amount} a {rate} ({date}) más {fee} de la tarjeta: {estimate} estimado'**
  String tripForeign(
    String amount,
    String rate,
    String date,
    String fee,
    String estimate,
  );

  /// No description provided for @tripForeignNoFee.
  ///
  /// In es, this message translates to:
  /// **'{amount} a {rate} ({date}): {estimate} estimado'**
  String tripForeignNoFee(
    String amount,
    String rate,
    String date,
    String estimate,
  );

  /// No description provided for @tripConverted.
  ///
  /// In es, this message translates to:
  /// **'{amount}, convertido con {source} del {date}'**
  String tripConverted(String amount, String source, String date);

  /// No description provided for @tripChargedMore.
  ///
  /// In es, this message translates to:
  /// **'El banco cobró {charged}: {difference} más que el estimado'**
  String tripChargedMore(String charged, String difference);

  /// No description provided for @tripChargedLess.
  ///
  /// In es, this message translates to:
  /// **'El banco cobró {charged}: {difference} menos que el estimado'**
  String tripChargedLess(String charged, String difference);

  /// No description provided for @tripAdjust.
  ///
  /// In es, this message translates to:
  /// **'Ajustar al cargo real'**
  String get tripAdjust;

  /// No description provided for @tripCharged.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto te cobró el banco?'**
  String get tripCharged;

  /// No description provided for @tripAdjustHelp.
  ///
  /// In es, this message translates to:
  /// **'Cambia el movimiento a lo que dice el extracto, y queda la diferencia con el estimado.'**
  String get tripAdjustHelp;

  /// No description provided for @tripName.
  ///
  /// In es, this message translates to:
  /// **'¿A dónde vas?'**
  String get tripName;

  /// No description provided for @tripCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda del viaje'**
  String get tripCurrency;

  /// No description provided for @tripBudget.
  ///
  /// In es, this message translates to:
  /// **'Presupuesto'**
  String get tripBudget;

  /// No description provided for @tripFee.
  ///
  /// In es, this message translates to:
  /// **'Comisión de tu tarjeta en el exterior'**
  String get tripFee;

  /// No description provided for @tripFeeHelp.
  ///
  /// In es, this message translates to:
  /// **'Si la sabes: se suma al estimar lo que te cobrarán en pesos.'**
  String get tripFeeHelp;

  /// No description provided for @tripFeeShort.
  ///
  /// In es, this message translates to:
  /// **'Comisión'**
  String get tripFeeShort;

  /// No description provided for @tripIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Falta a dónde vas.'**
  String get tripIncomplete;

  /// No description provided for @tripAddExpense.
  ///
  /// In es, this message translates to:
  /// **'Agregar gasto del viaje'**
  String get tripAddExpense;

  /// No description provided for @tripWhat.
  ///
  /// In es, this message translates to:
  /// **'¿En qué?'**
  String get tripWhat;

  /// No description provided for @tripAmount.
  ///
  /// In es, this message translates to:
  /// **'Valor'**
  String get tripAmount;

  /// No description provided for @tripPaidWith.
  ///
  /// In es, this message translates to:
  /// **'Pagaste con'**
  String get tripPaidWith;

  /// No description provided for @tripRate.
  ///
  /// In es, this message translates to:
  /// **'1 {from} en {to}'**
  String tripRate(String from, String to);

  /// No description provided for @tripRateNone.
  ///
  /// In es, this message translates to:
  /// **'Sin tasa guardada: escribe la que viste.'**
  String get tripRateNone;

  /// No description provided for @tripRateFrom.
  ///
  /// In es, this message translates to:
  /// **'{source} del {date}'**
  String tripRateFrom(String source, String date);

  /// No description provided for @tripWillRecord.
  ///
  /// In es, this message translates to:
  /// **'Se registran {amount} en {account}, estimado hasta que llegue el cargo real.'**
  String tripWillRecord(String amount, String account);

  /// No description provided for @tripExpenseIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Falta el valor o la tasa.'**
  String get tripExpenseIncomplete;

  /// No description provided for @syncTitle.
  ///
  /// In es, this message translates to:
  /// **'Varios dispositivos'**
  String get syncTitle;

  /// No description provided for @syncRow.
  ///
  /// In es, this message translates to:
  /// **'Tus datos en otro teléfono o computador, cifrados'**
  String get syncRow;

  /// No description provided for @syncBody.
  ///
  /// In es, this message translates to:
  /// **'Usa Quincena en más de un dispositivo con los mismos datos. Los cambios viajan en un archivo cifrado que mueves tú, por AirDrop, Archivos o un chat contigo: solo tus dispositivos lo pueden abrir, y Quincena no lo recibe.'**
  String get syncBody;

  /// No description provided for @syncNotBackup.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar no es un respaldo: une los cambios de tus dispositivos. Para guardar una copia de todo, usa Exportar en Ajustes.'**
  String get syncNotBackup;

  /// No description provided for @syncNotOnWeb.
  ///
  /// In es, this message translates to:
  /// **'La sincronización está en la app del teléfono y del computador.'**
  String get syncNotOnWeb;

  /// No description provided for @syncStart.
  ///
  /// In es, this message translates to:
  /// **'Empezar en este dispositivo'**
  String get syncStart;

  /// No description provided for @syncJoin.
  ///
  /// In es, this message translates to:
  /// **'Unir este dispositivo'**
  String get syncJoin;

  /// No description provided for @syncHow.
  ///
  /// In es, this message translates to:
  /// **'Empieza en el dispositivo que ya tiene tus datos. En el otro, toca «Unir este dispositivo» y escribe el código.'**
  String get syncHow;

  /// No description provided for @syncYourCode.
  ///
  /// In es, this message translates to:
  /// **'Tu código'**
  String get syncYourCode;

  /// No description provided for @syncNewCode.
  ///
  /// In es, this message translates to:
  /// **'Tu código nuevo'**
  String get syncNewCode;

  /// No description provided for @syncCodeKeep.
  ///
  /// In es, this message translates to:
  /// **'Con este código unes tus otros dispositivos. Guárdalo donde guardas tus contraseñas: si pierdes todos tus dispositivos y el código, nadie podrá abrir los archivos, ni siquiera Quincena.'**
  String get syncCodeKeep;

  /// No description provided for @syncCopyCode.
  ///
  /// In es, this message translates to:
  /// **'Copiar el código'**
  String get syncCopyCode;

  /// No description provided for @syncCodeCopied.
  ///
  /// In es, this message translates to:
  /// **'Código copiado.'**
  String get syncCodeCopied;

  /// No description provided for @syncDone.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get syncDone;

  /// No description provided for @syncJoinBody.
  ///
  /// In es, this message translates to:
  /// **'Escribe el código que muestra tu otro dispositivo en Ajustes, Varios dispositivos. Los guiones no importan.'**
  String get syncJoinBody;

  /// No description provided for @syncCodeField.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get syncCodeField;

  /// No description provided for @syncJoinAction.
  ///
  /// In es, this message translates to:
  /// **'Unir'**
  String get syncJoinAction;

  /// No description provided for @syncCodeLength.
  ///
  /// In es, this message translates to:
  /// **'Al código le sobran o le faltan caracteres: son 54.'**
  String get syncCodeLength;

  /// No description provided for @syncCodeCharacter.
  ///
  /// In es, this message translates to:
  /// **'Hay un carácter que el código no usa. Revisa que no sea una U.'**
  String get syncCodeCharacter;

  /// No description provided for @syncCodeCheck.
  ///
  /// In es, this message translates to:
  /// **'El código no cuadra: revisa si hay un carácter cambiado.'**
  String get syncCodeCheck;

  /// No description provided for @syncJoined.
  ///
  /// In es, this message translates to:
  /// **'Listo. Ahora abre un archivo de tu otro dispositivo para traer tus datos.'**
  String get syncJoined;

  /// No description provided for @syncSend.
  ///
  /// In es, this message translates to:
  /// **'Guardar mis cambios en un archivo'**
  String get syncSend;

  /// No description provided for @syncOpen.
  ///
  /// In es, this message translates to:
  /// **'Abrir un archivo de otro dispositivo'**
  String get syncOpen;

  /// No description provided for @syncSendHow.
  ///
  /// In es, this message translates to:
  /// **'Guarda el archivo donde tu otro dispositivo lo encuentre, o envíatelo, y ábrelo allá. Cada archivo lleva todo, así que el más reciente basta.'**
  String get syncSendHow;

  /// No description provided for @syncSaved.
  ///
  /// In es, this message translates to:
  /// **'Archivo guardado. Ábrelo en tu otro dispositivo.'**
  String get syncSaved;

  /// No description provided for @syncMerged.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Ya estaba todo al día.} =1{Listo: un cambio.} other{Listo: {count} cambios.}}'**
  String syncMerged(int count);

  /// No description provided for @syncMergedWaiting.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un cambio} other{{count} cambios}}; {waiting, plural, =1{uno espera} other{{waiting} esperan}} a que lo revises.'**
  String syncMergedWaiting(int count, int waiting);

  /// No description provided for @syncNotSync.
  ///
  /// In es, this message translates to:
  /// **'Ese no es un archivo de sincronización de Quincena.'**
  String get syncNotSync;

  /// No description provided for @syncOtherVault.
  ///
  /// In es, this message translates to:
  /// **'Ese archivo se hizo con otro código. Abre uno de un dispositivo unido con este código.'**
  String get syncOtherVault;

  /// No description provided for @syncNewer.
  ///
  /// In es, this message translates to:
  /// **'Ese archivo es de una versión más nueva de Quincena: actualiza la app.'**
  String get syncNewer;

  /// No description provided for @syncDamaged.
  ///
  /// In es, this message translates to:
  /// **'El archivo está dañado o se cortó: guárdalo de nuevo en el otro dispositivo. No cambió nada.'**
  String get syncDamaged;

  /// No description provided for @syncWaiting.
  ///
  /// In es, this message translates to:
  /// **'Para revisar'**
  String get syncWaiting;

  /// No description provided for @syncWaitingBody.
  ///
  /// In es, this message translates to:
  /// **'Cambios que no quedaron porque otro dispositivo cambió lo mismo. Nada se perdió: puedes traerlos de vuelta.'**
  String get syncWaitingBody;

  /// No description provided for @syncWhyEditedBoth.
  ///
  /// In es, this message translates to:
  /// **'Cambiado aquí y en otro dispositivo; quedó el más reciente.'**
  String get syncWhyEditedBoth;

  /// No description provided for @syncWhyDeletedElsewhere.
  ///
  /// In es, this message translates to:
  /// **'Lo cambiaste aquí, pero se borró en otro dispositivo.'**
  String get syncWhyDeletedElsewhere;

  /// No description provided for @syncWhyDeletedHere.
  ///
  /// In es, this message translates to:
  /// **'Lo borraste aquí; así lo habían cambiado en otro dispositivo.'**
  String get syncWhyDeletedHere;

  /// No description provided for @syncWhyWithAccount.
  ///
  /// In es, this message translates to:
  /// **'Su cuenta se borró en un dispositivo.'**
  String get syncWhyWithAccount;

  /// No description provided for @syncWhatProfile.
  ///
  /// In es, this message translates to:
  /// **'Tu perfil'**
  String get syncWhatProfile;

  /// No description provided for @syncWhatSetting.
  ///
  /// In es, this message translates to:
  /// **'Un ajuste'**
  String get syncWhatSetting;

  /// No description provided for @syncRestore.
  ///
  /// In es, this message translates to:
  /// **'Traer de vuelta'**
  String get syncRestore;

  /// No description provided for @syncDismiss.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get syncDismiss;

  /// No description provided for @syncRestored.
  ///
  /// In es, this message translates to:
  /// **'De vuelta. Tus otros dispositivos lo reciben con el próximo archivo.'**
  String get syncRestored;

  /// No description provided for @syncThisDevice.
  ///
  /// In es, this message translates to:
  /// **'Este dispositivo'**
  String get syncThisDevice;

  /// No description provided for @syncShowCode.
  ///
  /// In es, this message translates to:
  /// **'Ver el código'**
  String get syncShowCode;

  /// No description provided for @syncChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar el código'**
  String get syncChange;

  /// No description provided for @syncChangeTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cambiar el código?'**
  String get syncChangeTitle;

  /// No description provided for @syncChangeBody.
  ///
  /// In es, this message translates to:
  /// **'Los archivos que guardes desde ahora solo se abren con el código nuevo; une con él los dispositivos que quieras conservar. Los archivos que ya enviaste se siguen abriendo con el anterior.'**
  String get syncChangeBody;

  /// No description provided for @syncStop.
  ///
  /// In es, this message translates to:
  /// **'Dejar de sincronizar'**
  String get syncStop;

  /// No description provided for @syncStopTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Dejar de sincronizar aquí?'**
  String get syncStopTitle;

  /// No description provided for @syncStopBody.
  ///
  /// In es, this message translates to:
  /// **'Este dispositivo olvida el código. Tus datos se quedan aquí.'**
  String get syncStopBody;

  /// No description provided for @syncWhyReplaced.
  ///
  /// In es, this message translates to:
  /// **'Lo que había antes de traer de vuelta otra versión.'**
  String get syncWhyReplaced;

  /// No description provided for @syncWhyDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Llegó dos veces del mismo extracto o de Binance; quedó una.'**
  String get syncWhyDuplicate;

  /// No description provided for @reportAnswer.
  ///
  /// In es, this message translates to:
  /// **'Reportar'**
  String get reportAnswer;

  /// No description provided for @reportSent.
  ///
  /// In es, this message translates to:
  /// **'Reportada'**
  String get reportSent;

  /// No description provided for @reportTitle.
  ///
  /// In es, this message translates to:
  /// **'Reportar esta respuesta'**
  String get reportTitle;

  /// No description provided for @reportWhy.
  ///
  /// In es, this message translates to:
  /// **'¿Qué tiene de malo?'**
  String get reportWhy;

  /// No description provided for @reportOffensive.
  ///
  /// In es, this message translates to:
  /// **'Es ofensiva o inapropiada'**
  String get reportOffensive;

  /// No description provided for @reportWrong.
  ///
  /// In es, this message translates to:
  /// **'Es incorrecta o engañosa'**
  String get reportWrong;

  /// No description provided for @reportOther.
  ///
  /// In es, this message translates to:
  /// **'Otra cosa'**
  String get reportOther;

  /// No description provided for @reportComment.
  ///
  /// In es, this message translates to:
  /// **'Cuéntanos más (opcional)'**
  String get reportComment;

  /// No description provided for @reportWhat.
  ///
  /// In es, this message translates to:
  /// **'A DL SOFT le llegan tu pregunta, esta respuesta con sus cifras y lo que escribas aquí; nada más de tu cuenta, ni un identificador tuyo. Los reportes se borran a los 90 días.'**
  String get reportWhat;

  /// No description provided for @reportSend.
  ///
  /// In es, this message translates to:
  /// **'Enviar reporte'**
  String get reportSend;

  /// No description provided for @reportSending.
  ///
  /// In es, this message translates to:
  /// **'Enviando…'**
  String get reportSending;

  /// No description provided for @reportFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar. Revisa tu conexión e inténtalo de nuevo.'**
  String get reportFailed;

  /// No description provided for @reportThanks.
  ///
  /// In es, this message translates to:
  /// **'Gracias. Vamos a revisar esta respuesta.'**
  String get reportThanks;

  /// No description provided for @standingCanSpend.
  ///
  /// In es, this message translates to:
  /// **'Puedes gastar'**
  String get standingCanSpend;

  /// No description provided for @standingShort.
  ///
  /// In es, this message translates to:
  /// **'Te faltan'**
  String get standingShort;

  /// No description provided for @standingUntil.
  ///
  /// In es, this message translates to:
  /// **'hasta el {date}'**
  String standingUntil(String date);

  /// No description provided for @standingShortUntil.
  ///
  /// In es, this message translates to:
  /// **'para llegar al {date}'**
  String standingShortUntil(String date);

  /// No description provided for @standingNextFortnight.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, =0{hoy llega tu quincena} =1{tu quincena llega mañana} other{tu quincena llega en {days} días}}'**
  String standingNextFortnight(int days);

  /// No description provided for @standingNextPay.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, =0{hoy llega tu pago} =1{tu próximo pago llega mañana} other{tu próximo pago llega en {days} días}}'**
  String standingNextPay(int days);

  /// No description provided for @standingAvailable.
  ///
  /// In es, this message translates to:
  /// **'En tus cuentas de uso diario'**
  String get standingAvailable;

  /// No description provided for @standingPaymentsBefore.
  ///
  /// In es, this message translates to:
  /// **'Pagos hasta el {date}'**
  String standingPaymentsBefore(String date);

  /// No description provided for @standingCushionLine.
  ///
  /// In es, this message translates to:
  /// **'Colchón'**
  String get standingCushionLine;

  /// No description provided for @standingEnvelopesLine.
  ///
  /// In es, this message translates to:
  /// **'Apartado en sobres'**
  String get standingEnvelopesLine;

  /// No description provided for @standingReserveLine.
  ///
  /// In es, this message translates to:
  /// **'Reserva de ingresos variables'**
  String get standingReserveLine;

  /// No description provided for @standingShortSemantics.
  ///
  /// In es, this message translates to:
  /// **'Te faltan {free} para llegar al {date}; {when}.'**
  String standingShortSemantics(String free, String date, String when);

  /// No description provided for @homeTodo.
  ///
  /// In es, this message translates to:
  /// **'Por hacer'**
  String get homeTodo;

  /// No description provided for @todoReview.
  ///
  /// In es, this message translates to:
  /// **'Revisar'**
  String get todoReview;

  /// No description provided for @todoSplit.
  ///
  /// In es, this message translates to:
  /// **'Repartir'**
  String get todoSplit;

  /// No description provided for @paydayArrivedPay.
  ///
  /// In es, this message translates to:
  /// **'Te llegó el pago'**
  String get paydayArrivedPay;

  /// No description provided for @netWorthDetail.
  ///
  /// In es, this message translates to:
  /// **'Lo que tienes menos lo que debes'**
  String get netWorthDetail;

  /// No description provided for @groupCards.
  ///
  /// In es, this message translates to:
  /// **'Tarjetas de crédito'**
  String get groupCards;

  /// No description provided for @cardOwed.
  ///
  /// In es, this message translates to:
  /// **'Debes {amount}'**
  String cardOwed(String amount);

  /// No description provided for @cardInFavor.
  ///
  /// In es, this message translates to:
  /// **'A favor {amount}'**
  String cardInFavor(String amount);

  /// No description provided for @cardClear.
  ///
  /// In es, this message translates to:
  /// **'Al día'**
  String get cardClear;

  /// No description provided for @totalExplainHave.
  ///
  /// In es, this message translates to:
  /// **'Lo que tienes'**
  String get totalExplainHave;

  /// No description provided for @totalExplainOwe.
  ///
  /// In es, this message translates to:
  /// **'Lo que debes'**
  String get totalExplainOwe;

  /// No description provided for @ratesSeeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver tasas usadas'**
  String get ratesSeeAll;

  /// No description provided for @cardOwedLabel.
  ///
  /// In es, this message translates to:
  /// **'Debes'**
  String get cardOwedLabel;

  /// No description provided for @cardInFavorLabel.
  ///
  /// In es, this message translates to:
  /// **'A favor'**
  String get cardInFavorLabel;

  /// No description provided for @whichAccountIn.
  ///
  /// In es, this message translates to:
  /// **'No sabemos a qué cuenta llegó.'**
  String get whichAccountIn;

  /// No description provided for @whichAccountOut.
  ///
  /// In es, this message translates to:
  /// **'No sabemos de qué cuenta salió.'**
  String get whichAccountOut;

  /// No description provided for @fromOwnAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Viene de otra cuenta tuya?'**
  String get fromOwnAccount;

  /// No description provided for @moreActions.
  ///
  /// In es, this message translates to:
  /// **'Más acciones'**
  String get moreActions;

  /// No description provided for @statementNew.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Ninguno nuevo} =1{1 nuevo} other{{count} nuevos}}'**
  String statementNew(int count);

  /// No description provided for @statementAlready.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{ninguno repetido} =1{1 ya estaba} other{{count} ya estaban}}'**
  String statementAlready(int count);

  /// No description provided for @statementUnsorted.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 sin categoría} other{{count} sin categoría}}'**
  String statementUnsorted(int count);

  /// No description provided for @statementAlreadyUnchecked.
  ///
  /// In es, this message translates to:
  /// **'Lo que ya estaba quedó sin marcar, para no contarlo dos veces.'**
  String get statementAlreadyUnchecked;

  /// No description provided for @statementSelectAll.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar todos'**
  String get statementSelectAll;

  /// No description provided for @statementSelectNone.
  ///
  /// In es, this message translates to:
  /// **'Quitar todos'**
  String get statementSelectNone;

  /// No description provided for @statementDoneSorted.
  ///
  /// In es, this message translates to:
  /// **'Todos quedaron con su categoría.'**
  String get statementDoneSorted;

  /// No description provided for @statementDoneUnsorted.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Uno quedó sin categoría: tócalo para ponérsela.} other{{count} quedaron sin categoría: tócalos para ponérsela.}}'**
  String statementDoneUnsorted(int count);

  /// No description provided for @statementGiveCategory.
  ///
  /// In es, this message translates to:
  /// **'Sin categoría'**
  String get statementGiveCategory;

  /// No description provided for @statementFinish.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get statementFinish;

  /// No description provided for @licensesTitle.
  ///
  /// In es, this message translates to:
  /// **'Licencias y créditos'**
  String get licensesTitle;

  /// No description provided for @licensesLegalese.
  ///
  /// In es, this message translates to:
  /// **'© 2026 DL SOFT TECHNOLOGIES SAS. Los comercios cercanos vienen de © colaboradores de OpenStreetMap (ODbL).'**
  String get licensesLegalese;

  /// No description provided for @comingLowestLine.
  ///
  /// In es, this message translates to:
  /// **'Tu saldo mínimo estimado será {amount} el {date}.'**
  String comingLowestLine(String amount, String date);

  /// No description provided for @timelineFortnight.
  ///
  /// In es, this message translates to:
  /// **'Tu quincena'**
  String get timelineFortnight;

  /// No description provided for @timelineCharge.
  ///
  /// In es, this message translates to:
  /// **'Un cobro programado'**
  String get timelineCharge;

  /// No description provided for @timelineExpected.
  ///
  /// In es, this message translates to:
  /// **'esperado'**
  String get timelineExpected;

  /// No description provided for @timelineMore.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Y un día más hasta el pago.} other{Y {count} más hasta el pago.}}'**
  String timelineMore(int count);

  /// No description provided for @buyAsk.
  ///
  /// In es, this message translates to:
  /// **'¿Me alcanza para…?'**
  String get buyAsk;

  /// No description provided for @buyAskBody.
  ///
  /// In es, this message translates to:
  /// **'Escribe el precio y te digo si te alcanza sin tocar lo comprometido.'**
  String get buyAskBody;

  /// No description provided for @buyAskHint.
  ///
  /// In es, this message translates to:
  /// **'Precio'**
  String get buyAskHint;

  /// No description provided for @buyAskGo.
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get buyAskGo;

  /// No description provided for @fabMovement.
  ///
  /// In es, this message translates to:
  /// **'Movimiento'**
  String get fabMovement;

  /// No description provided for @goalSoFar.
  ///
  /// In es, this message translates to:
  /// **'Llevas {saved}'**
  String goalSoFar(String saved);

  /// No description provided for @goalMissing.
  ///
  /// In es, this message translates to:
  /// **'faltan {missing}'**
  String goalMissing(String missing);

  /// No description provided for @goalReached.
  ///
  /// In es, this message translates to:
  /// **'Meta cumplida'**
  String get goalReached;

  /// No description provided for @goalNeedMark.
  ///
  /// In es, this message translates to:
  /// **'Necesitas {amount}'**
  String goalNeedMark(String amount);

  /// No description provided for @askExample.
  ///
  /// In es, this message translates to:
  /// **'Por ejemplo: {question}'**
  String askExample(String question);

  /// No description provided for @askExampleBuy.
  ///
  /// In es, this message translates to:
  /// **'¿Me alcanza para unos audífonos de \$350.000?'**
  String get askExampleBuy;

  /// No description provided for @askExampleGoal.
  ///
  /// In es, this message translates to:
  /// **'¿Llego a mi meta de {name}?'**
  String askExampleGoal(String name);

  /// No description provided for @askExampleWeekend.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto puedo gastar este fin de semana?'**
  String get askExampleWeekend;

  /// No description provided for @askExampleCard.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto debo en la tarjeta?'**
  String get askExampleCard;

  /// No description provided for @askExampleCrypto.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo va mi cripto esta semana?'**
  String get askExampleCrypto;

  /// No description provided for @askExampleMost.
  ///
  /// In es, this message translates to:
  /// **'¿En qué gasté más este mes?'**
  String get askExampleMost;

  /// No description provided for @chartPerformance.
  ///
  /// In es, this message translates to:
  /// **'Rendimiento'**
  String get chartPerformance;

  /// No description provided for @chartValue.
  ///
  /// In es, this message translates to:
  /// **'Valor'**
  String get chartValue;

  /// No description provided for @chartPerformanceNote.
  ///
  /// In es, this message translates to:
  /// **'Solo lo que movieron los precios de tus monedas, con el dólar de hoy: comprar o vender no cambia esta línea.'**
  String get chartPerformanceNote;

  /// No description provided for @binancePromiseRead.
  ///
  /// In es, this message translates to:
  /// **'Solo lectura'**
  String get binancePromiseRead;

  /// No description provided for @binancePromiseNoWithdraw.
  ///
  /// In es, this message translates to:
  /// **'No permite retiros'**
  String get binancePromiseNoWithdraw;

  /// No description provided for @binancePromiseNoTrade.
  ///
  /// In es, this message translates to:
  /// **'No permite órdenes de compra ni de venta'**
  String get binancePromiseNoTrade;

  /// No description provided for @binancePromiseDisconnect.
  ///
  /// In es, this message translates to:
  /// **'La desconectas cuando quieras'**
  String get binancePromiseDisconnect;

  /// No description provided for @ratesFailedAt.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron actualizar. Se usan las del {when}.'**
  String ratesFailedAt(String when);

  /// No description provided for @portfolioPricingFailedAt.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron leer los precios. Se muestran los del {when}.'**
  String portfolioPricingFailedAt(String when);

  /// No description provided for @chartLoading.
  ///
  /// In es, this message translates to:
  /// **'Actualizando la gráfica…'**
  String get chartLoading;

  /// No description provided for @loanLentAction.
  ///
  /// In es, this message translates to:
  /// **'Le presté'**
  String get loanLentAction;

  /// No description provided for @loanBorrowedAction.
  ///
  /// In es, this message translates to:
  /// **'Me prestaron'**
  String get loanBorrowedAction;

  /// No description provided for @loanLentTitle.
  ///
  /// In es, this message translates to:
  /// **'Le presté plata a alguien'**
  String get loanLentTitle;

  /// No description provided for @loanBorrowedTitle.
  ///
  /// In es, this message translates to:
  /// **'Alguien me prestó plata'**
  String get loanBorrowedTitle;

  /// No description provided for @loanLentWho.
  ///
  /// In es, this message translates to:
  /// **'¿A quién?'**
  String get loanLentWho;

  /// No description provided for @loanBorrowedWho.
  ///
  /// In es, this message translates to:
  /// **'¿Quién te prestó?'**
  String get loanBorrowedWho;

  /// No description provided for @loanWhat.
  ///
  /// In es, this message translates to:
  /// **'¿Para qué? (opcional)'**
  String get loanWhat;

  /// No description provided for @loanLabel.
  ///
  /// In es, this message translates to:
  /// **'Préstamo'**
  String get loanLabel;

  /// No description provided for @loanFromAccount.
  ///
  /// In es, this message translates to:
  /// **'¿De qué cuenta salió?'**
  String get loanFromAccount;

  /// No description provided for @loanNoAccount.
  ///
  /// In es, this message translates to:
  /// **'No salió de mis cuentas'**
  String get loanNoAccount;

  /// No description provided for @loanLentNote.
  ///
  /// In es, this message translates to:
  /// **'Queda como plata que te deben, no como gasto. Cuando te la devuelvan, regístralo en el grupo.'**
  String get loanLentNote;

  /// No description provided for @loanBorrowedNote.
  ///
  /// In es, this message translates to:
  /// **'Queda como plata que debes. Cuando la pagues, regístralo en el grupo.'**
  String get loanBorrowedNote;

  /// No description provided for @loanIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Falta a quién o el monto.'**
  String get loanIncomplete;

  /// No description provided for @statementImporting.
  ///
  /// In es, this message translates to:
  /// **'Importando…'**
  String get statementImporting;

  /// No description provided for @exportBody.
  ///
  /// In es, this message translates to:
  /// **'Un archivo con todo lo que tienes en Quincena: cuentas, movimientos, planes y ajustes. Sirve para pasarlo a otro teléfono o guardar una copia.'**
  String get exportBody;

  /// No description provided for @exportSealed.
  ///
  /// In es, this message translates to:
  /// **'Cifrado (recomendado)'**
  String get exportSealed;

  /// No description provided for @exportSealedBody.
  ///
  /// In es, this message translates to:
  /// **'Solo se abre en Quincena con tu código de respaldo. Puedes guardarlo en la nube o mandártelo sin que nadie más lo lea.'**
  String get exportSealedBody;

  /// No description provided for @exportPlain.
  ///
  /// In es, this message translates to:
  /// **'Sin cifrar (JSON)'**
  String get exportPlain;

  /// No description provided for @exportPlainBody.
  ///
  /// In es, this message translates to:
  /// **'Cualquiera que tenga el archivo puede leer tus finanzas. Sirve para llevarlas a otra herramienta.'**
  String get exportPlainBody;

  /// No description provided for @exportAction.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get exportAction;

  /// No description provided for @backupShowCode.
  ///
  /// In es, this message translates to:
  /// **'Ver mi código de respaldo'**
  String get backupShowCode;

  /// No description provided for @backupYourCode.
  ///
  /// In es, this message translates to:
  /// **'Tu código de respaldo'**
  String get backupYourCode;

  /// No description provided for @backupCodeKeep.
  ///
  /// In es, this message translates to:
  /// **'Con este código abres tus respaldos cifrados, en este teléfono o en otro. Guárdalo donde guardas tus contraseñas: sin él nadie podrá abrirlos, ni siquiera Quincena.'**
  String get backupCodeKeep;

  /// No description provided for @backupCodeKept.
  ///
  /// In es, this message translates to:
  /// **'Ya lo guardé'**
  String get backupCodeKept;

  /// No description provided for @backupCodeTitle.
  ///
  /// In es, this message translates to:
  /// **'Respaldo cifrado'**
  String get backupCodeTitle;

  /// No description provided for @backupCodeBody.
  ///
  /// In es, this message translates to:
  /// **'Escribe el código de respaldo que Quincena te mostró la primera vez que exportaste cifrado.'**
  String get backupCodeBody;

  /// No description provided for @backupOpen.
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get backupOpen;

  /// No description provided for @backupWrongCode.
  ///
  /// In es, this message translates to:
  /// **'Ese código no abre este respaldo. Si es el de sincronización, el de respaldo es otro.'**
  String get backupWrongCode;

  /// No description provided for @backupIsSync.
  ///
  /// In es, this message translates to:
  /// **'Ese es un archivo de sincronización: se abre en Ajustes, Varios dispositivos. No se cambió nada.'**
  String get backupIsSync;

  /// No description provided for @backupChangeCode.
  ///
  /// In es, this message translates to:
  /// **'Cambiar el código'**
  String get backupChangeCode;

  /// No description provided for @backupChangeTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cambiar el código de respaldo?'**
  String get backupChangeTitle;

  /// No description provided for @backupChangeBody.
  ///
  /// In es, this message translates to:
  /// **'Los respaldos que ya hiciste se siguen abriendo con el código de antes; los nuevos, con el nuevo. Guarda los dos mientras tengas respaldos viejos.'**
  String get backupChangeBody;

  /// No description provided for @backupChange.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get backupChange;

  /// No description provided for @backupNewCode.
  ///
  /// In es, this message translates to:
  /// **'Tu nuevo código de respaldo'**
  String get backupNewCode;

  /// No description provided for @widgetUpdated.
  ///
  /// In es, this message translates to:
  /// **'Actualizado: {when}'**
  String widgetUpdated(String when);

  /// No description provided for @widgetStale.
  ///
  /// In es, this message translates to:
  /// **'Abre Quincena para ver la cifra de hoy.'**
  String get widgetStale;

  /// No description provided for @widgetSection.
  ///
  /// In es, this message translates to:
  /// **'Widget de inicio'**
  String get widgetSection;

  /// No description provided for @widgetHow.
  ///
  /// In es, this message translates to:
  /// **'Para agregarlo, mantén presionado un espacio vacío de la pantalla de inicio y busca Quincena. Muestra lo que puedes gastar hasta tu próximo pago, como lo calculó la app la última vez que la abriste.'**
  String get widgetHow;

  /// No description provided for @widgetHide.
  ///
  /// In es, this message translates to:
  /// **'Ocultar montos en el widget'**
  String get widgetHide;

  /// No description provided for @widgetHideHelp.
  ///
  /// In es, this message translates to:
  /// **'Dice hasta cuándo, sin la cifra.'**
  String get widgetHideHelp;

  /// No description provided for @widgetAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar a la pantalla de inicio'**
  String get widgetAdd;

  /// No description provided for @widgetAddFailed.
  ///
  /// In es, this message translates to:
  /// **'Tu pantalla de inicio no deja agregarlo desde aquí. Mantén presionado un espacio vacío y busca Quincena.'**
  String get widgetAddFailed;

  /// No description provided for @rateManualTag.
  ///
  /// In es, this message translates to:
  /// **'Manual'**
  String get rateManualTag;

  /// No description provided for @rateManualOn.
  ///
  /// In es, this message translates to:
  /// **'Escrita a mano el {date}'**
  String rateManualOn(String date);

  /// No description provided for @rateAutomaticNow.
  ///
  /// In es, this message translates to:
  /// **'La automática hoy: {value}'**
  String rateAutomaticNow(String value);

  /// No description provided for @rateUseFetchedShort.
  ///
  /// In es, this message translates to:
  /// **'Usar la automática'**
  String get rateUseFetchedShort;

  /// No description provided for @rateRestoreFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo traer la tasa automática. Sigue la tuya; intenta de nuevo con conexión.'**
  String get rateRestoreFailed;

  /// No description provided for @rateStepPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio de mercado: 1 {asset} = {value} · {source}, {when}'**
  String rateStepPrice(String asset, String value, String source, String when);

  /// No description provided for @rateStepConvert.
  ///
  /// In es, this message translates to:
  /// **'Conversión a {base}: 1 {asset} = {value} · {source} del {date}'**
  String rateStepConvert(
    String base,
    String asset,
    String value,
    String source,
    String date,
  );

  /// No description provided for @rateStepManual.
  ///
  /// In es, this message translates to:
  /// **'1 {asset} = {value} · escrita a mano'**
  String rateStepManual(String asset, String value);

  /// No description provided for @ratesIntro.
  ///
  /// In es, this message translates to:
  /// **'Así pasamos a {base} lo que tienes en otras monedas. Solo cambian los totales, no los saldos de tus cuentas.'**
  String ratesIntro(String base);

  /// No description provided for @ratesManualCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 tasa escrita a mano} other{{count} tasas escritas a mano}}'**
  String ratesManualCount(int count);

  /// No description provided for @portfolioNoData.
  ///
  /// In es, this message translates to:
  /// **'Sin dato'**
  String get portfolioNoData;

  /// No description provided for @portfolioNoData24h.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay precio de hace 24 horas.'**
  String get portfolioNoData24h;

  /// No description provided for @portfolioNoPrice.
  ///
  /// In es, this message translates to:
  /// **'Sin precio'**
  String get portfolioNoPrice;

  /// No description provided for @portfolioDayDetail.
  ///
  /// In es, this message translates to:
  /// **'{percent} por precio'**
  String portfolioDayDetail(String percent);

  /// No description provided for @portfolioGainMeaning.
  ///
  /// In es, this message translates to:
  /// **'Lo que vale hoy lo que aún tienes menos lo que pagaste por eso, en pesos. Incluye cuánto se movió el dólar frente al peso y las comisiones de Binance; lo que ya vendiste va aparte.'**
  String get portfolioGainMeaning;

  /// No description provided for @portfolioGainUncosted.
  ///
  /// In es, this message translates to:
  /// **'Sin contar {amount} que llegó sin precio de compra.'**
  String portfolioGainUncosted(String amount);

  /// No description provided for @portfolioConvertedWith.
  ///
  /// In es, this message translates to:
  /// **'Pasados a pesos con la TRM del {day}'**
  String portfolioConvertedWith(String day);

  /// No description provided for @portfolioRefresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get portfolioRefresh;

  /// No description provided for @portfolioRefreshLabel.
  ///
  /// In es, this message translates to:
  /// **'Actualizar precios'**
  String get portfolioRefreshLabel;

  /// No description provided for @chartPerformanceNoteFx.
  ///
  /// In es, this message translates to:
  /// **'Lo que movieron los precios y el dólar frente al peso: comprar o vender no cambia esta línea.'**
  String get chartPerformanceNoteFx;

  /// No description provided for @portfolioGainMeaningPlain.
  ///
  /// In es, this message translates to:
  /// **'Lo que vale hoy lo que aún tienes menos lo que pagaste por eso. Incluye las comisiones de Binance; lo que ya vendiste va aparte.'**
  String get portfolioGainMeaningPlain;

  /// No description provided for @chartPerformanceNoteFxPlain.
  ///
  /// In es, this message translates to:
  /// **'Lo que movieron los precios y el dólar frente a tu moneda: comprar o vender no cambia esta línea.'**
  String get chartPerformanceNoteFxPlain;

  /// No description provided for @freeExplainSpendableSection.
  ///
  /// In es, this message translates to:
  /// **'Tus cuentas de uso diario'**
  String get freeExplainSpendableSection;

  /// No description provided for @standingCardDebtLine.
  ///
  /// In es, this message translates to:
  /// **'Lo que debes en tarjetas'**
  String get standingCardDebtLine;

  /// No description provided for @cardSpendableHelp.
  ///
  /// In es, this message translates to:
  /// **'Si está encendido, lo que debes en esta tarjeta se resta de lo que puedes gastar, porque lo pagas con tus cuentas de uso diario.'**
  String get cardSpendableHelp;

  /// No description provided for @freeExplainAssumePending.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{No cuenta 1 movimiento que espera en Por revisar. Cuando lo registres, la cifra puede cambiar.} other{No cuenta {count} movimientos que esperan en Por revisar. Cuando los registres, la cifra puede cambiar.}}'**
  String freeExplainAssumePending(int count);

  /// No description provided for @paydayArrivedAmount.
  ///
  /// In es, this message translates to:
  /// **'Te llegó la quincena: {amount}'**
  String paydayArrivedAmount(String amount);

  /// No description provided for @paydayArrivedPayAmount.
  ///
  /// In es, this message translates to:
  /// **'Te llegó el pago: {amount}'**
  String paydayArrivedPayAmount(String amount);

  /// No description provided for @paydayArrivedDetail.
  ///
  /// In es, this message translates to:
  /// **'El {date} en {account}. Ponle a cada parte su sobre antes de gastar.'**
  String paydayArrivedDetail(String date, String account);

  /// No description provided for @listAnd.
  ///
  /// In es, this message translates to:
  /// **'{a} {sound, select, i{e} other{y}} {b}'**
  String listAnd(String a, String b, String sound);

  /// No description provided for @comingLowestLineSure.
  ///
  /// In es, this message translates to:
  /// **'Tu saldo mínimo estimado será {amount} el {date}, sin contar lo que esperas recibir.'**
  String comingLowestLineSure(String amount, String date);

  /// No description provided for @totalExplainOwedToYou.
  ///
  /// In es, this message translates to:
  /// **'Te deben'**
  String get totalExplainOwedToYou;

  /// No description provided for @totalExplainYouOwe.
  ///
  /// In es, this message translates to:
  /// **'Les debes a otras personas'**
  String get totalExplainYouOwe;

  /// No description provided for @totalExplainShared.
  ///
  /// In es, this message translates to:
  /// **'Gastos compartidos y préstamos'**
  String get totalExplainShared;

  /// No description provided for @totalExplainInstallments.
  ///
  /// In es, this message translates to:
  /// **'Compras a cuotas'**
  String get totalExplainInstallments;

  /// No description provided for @totalExplainInstallmentsLeft.
  ///
  /// In es, this message translates to:
  /// **'Lo que falta pagar, fuera de tus tarjetas'**
  String get totalExplainInstallmentsLeft;

  /// No description provided for @paydayArrivedDetailRange.
  ///
  /// In es, this message translates to:
  /// **'Del {from} al {to} en {account}. Ponle a cada parte su sobre antes de gastar.'**
  String paydayArrivedDetailRange(String from, String to, String account);

  /// No description provided for @statementSelectNew.
  ///
  /// In es, this message translates to:
  /// **'Marcar los nuevos'**
  String get statementSelectNew;

  /// No description provided for @statementRepeatsChosen.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Marcaste 1 que ya estaba: se contaría dos veces.} other{Marcaste {count} que ya estaban: se contarían dos veces.}}'**
  String statementRepeatsChosen(int count);

  /// No description provided for @statementSelected.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Nada seleccionado} =1{1 seleccionado} other{{count} seleccionados}}'**
  String statementSelected(int count);

  /// No description provided for @statementIn.
  ///
  /// In es, this message translates to:
  /// **'entran {amount}'**
  String statementIn(String amount);

  /// No description provided for @statementOut.
  ///
  /// In es, this message translates to:
  /// **'salen {amount}'**
  String statementOut(String amount);

  /// No description provided for @statementReviewLine.
  ///
  /// In es, this message translates to:
  /// **'Revisar movimiento'**
  String get statementReviewLine;

  /// No description provided for @statementOriginal.
  ///
  /// In es, this message translates to:
  /// **'Como aparece en el extracto'**
  String get statementOriginal;

  /// No description provided for @statementCardPayment.
  ///
  /// In es, this message translates to:
  /// **'Pago de tu tarjeta {card}'**
  String statementCardPayment(String card);

  /// No description provided for @statementOwnTransferTo.
  ///
  /// In es, this message translates to:
  /// **'Pasa a {account}'**
  String statementOwnTransferTo(String account);

  /// No description provided for @statementOwnTransferFrom.
  ///
  /// In es, this message translates to:
  /// **'Viene de {account}'**
  String statementOwnTransferFrom(String account);

  /// No description provided for @statementBetweenAccounts.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 entre tus cuentas} other{{count} entre tus cuentas}}'**
  String statementBetweenAccounts(int count);

  /// No description provided for @statementTransferNote.
  ///
  /// In es, this message translates to:
  /// **'Un pago de tarjeta pasa plata de una cuenta tuya a otra: no cuenta como gasto, porque las compras ya están en la tarjeta.'**
  String get statementTransferNote;

  /// No description provided for @statementIsCardPayment.
  ///
  /// In es, this message translates to:
  /// **'¿Es el pago de una tarjeta tuya?'**
  String get statementIsCardPayment;

  /// No description provided for @statementAddCard.
  ///
  /// In es, this message translates to:
  /// **'Parece el pago de una tarjeta. Agrégala en Cuentas para que Quincena no cuente dos veces lo que compraste con ella.'**
  String get statementAddCard;

  /// No description provided for @statementDoneTransfers.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Uno quedó como movimiento entre tus cuentas: no cuenta como gasto.} other{{count} quedaron como movimientos entre tus cuentas: no cuentan como gasto.}}'**
  String statementDoneTransfers(int count);

  /// No description provided for @statementOlder.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un movimiento es de antes del {date}} other{{count} movimientos son de antes del {date}}}, cuando escribiste el saldo de {account}.'**
  String statementOlder(int count, String date, String account);

  /// No description provided for @statementOlderKeep.
  ///
  /// In es, this message translates to:
  /// **'Mi saldo ya los incluye (recomendado)'**
  String get statementOlderKeep;

  /// No description provided for @statementOlderAdd.
  ///
  /// In es, this message translates to:
  /// **'Sumarlos a mi saldo'**
  String get statementOlderAdd;

  /// No description provided for @statementOlderNote.
  ///
  /// In es, this message translates to:
  /// **'Se guardan para ver en qué se fue la plata, sin cambiar lo que tienes hoy.'**
  String get statementOlderNote;

  /// No description provided for @statementEndsAt.
  ///
  /// In es, this message translates to:
  /// **'Según el extracto, el {date} tenías {amount}.'**
  String statementEndsAt(String date, String amount);

  /// No description provided for @statementMismatch.
  ///
  /// In es, this message translates to:
  /// **'Quincena tendría {amount} ese día.'**
  String statementMismatch(String amount);

  /// No description provided for @statementUseBalance.
  ///
  /// In es, this message translates to:
  /// **'Ajustar al saldo del extracto'**
  String get statementUseBalance;

  /// No description provided for @statementBalanceEffect.
  ///
  /// In es, this message translates to:
  /// **'Saldo de {account}: {before} → {after}'**
  String statementBalanceEffect(String account, String before, String after);

  /// No description provided for @statementDebtEffect.
  ///
  /// In es, this message translates to:
  /// **'Lo que debes en {account}: {before} → {after}'**
  String statementDebtEffect(String account, String before, String after);

  /// No description provided for @statementBalanceSame.
  ///
  /// In es, this message translates to:
  /// **'El saldo de {account} sigue en {amount}: ya incluía estos movimientos.'**
  String statementBalanceSame(String account, String amount);

  /// No description provided for @statementPaidFrom.
  ///
  /// In es, this message translates to:
  /// **'¿De cuál de tus cuentas salió este pago?'**
  String get statementPaidFrom;

  /// No description provided for @statementSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo terminar de importar. Lo que sí se guardó aparece como «Ya importado».'**
  String get statementSaveFailed;

  /// No description provided for @goalTypeAmount.
  ///
  /// In es, this message translates to:
  /// **'Escribir monto'**
  String get goalTypeAmount;

  /// No description provided for @goalAmountTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cuánto quieres apartar al mes?'**
  String get goalAmountTitle;

  /// No description provided for @goalAmountUse.
  ///
  /// In es, this message translates to:
  /// **'Usar este monto'**
  String get goalAmountUse;

  /// No description provided for @goalAmountInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe un monto mayor que cero.'**
  String get goalAmountInvalid;

  /// No description provided for @goalUseNeeded.
  ///
  /// In es, this message translates to:
  /// **'Usar {amount} al mes'**
  String goalUseNeeded(String amount);

  /// No description provided for @goalSimulating.
  ///
  /// In es, this message translates to:
  /// **'Simulación · hoy apartas {current}'**
  String goalSimulating(String current);

  /// No description provided for @goalBackToCurrent.
  ///
  /// In es, this message translates to:
  /// **'Volver a {amount}'**
  String goalBackToCurrent(String amount);

  /// No description provided for @goalPlanContributions.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Es 1 aporte, el {first}.} other{Son {count} aportes de {amount}, del {first} al {last}.}}'**
  String goalPlanContributions(
    int count,
    String amount,
    String first,
    String last,
  );

  /// No description provided for @goalEffectTitle.
  ///
  /// In es, this message translates to:
  /// **'Qué cambia en lo que puedes gastar'**
  String get goalEffectTitle;

  /// No description provided for @goalEffectUntilPayday.
  ///
  /// In es, this message translates to:
  /// **'Hasta el {payday} puedes gastar {free}: el aporte sale el {day}, así que no lo toca.'**
  String goalEffectUntilPayday(String payday, String free, String day);

  /// No description provided for @goalEffectBeforePay.
  ///
  /// In es, this message translates to:
  /// **'El aporte del {day} sale antes de tu pago: hasta el {payday} podrías gastar {left}.'**
  String goalEffectBeforePay(String day, String payday, String left);

  /// No description provided for @goalEffectMore.
  ///
  /// In es, this message translates to:
  /// **'Desde la quincena del {payday} tendrías {amount} menos al mes para gastar que hoy.'**
  String goalEffectMore(String payday, String amount);

  /// No description provided for @goalEffectLess.
  ///
  /// In es, this message translates to:
  /// **'Desde la quincena del {payday} tendrías {amount} más al mes para gastar que hoy.'**
  String goalEffectLess(String payday, String amount);

  /// No description provided for @goalEffectSame.
  ///
  /// In es, this message translates to:
  /// **'Es lo que ya apartas: lo que puedes gastar no cambia.'**
  String get goalEffectSame;

  /// No description provided for @goalNeverArrives.
  ///
  /// In es, this message translates to:
  /// **'Sin aporte al mes no llegas a la meta.'**
  String get goalNeverArrives;

  /// No description provided for @goalEffectUntilPaydayShort.
  ///
  /// In es, this message translates to:
  /// **'Te faltan {short} para llegar al {payday}. El aporte sale el {day}, después de tu pago.'**
  String goalEffectUntilPaydayShort(String short, String payday, String day);

  /// No description provided for @goalEffectBeforePayShort.
  ///
  /// In es, this message translates to:
  /// **'El aporte del {day} sale antes de tu pago: te faltarían {short} para llegar al {payday}.'**
  String goalEffectBeforePayShort(String day, String short, String payday);

  /// No description provided for @newConversationShort.
  ///
  /// In es, this message translates to:
  /// **'Nueva'**
  String get newConversationShort;

  /// No description provided for @conversationCleared.
  ///
  /// In es, this message translates to:
  /// **'Empezaste una conversación nueva.'**
  String get conversationCleared;

  /// No description provided for @seeResult.
  ///
  /// In es, this message translates to:
  /// **'Ver resultado'**
  String get seeResult;

  /// No description provided for @newAnswerBelow.
  ///
  /// In es, this message translates to:
  /// **'Hay una respuesta nueva abajo'**
  String get newAnswerBelow;

  /// No description provided for @settledExpense.
  ///
  /// In es, this message translates to:
  /// **'Gasto guardado'**
  String get settledExpense;

  /// No description provided for @settledPlan.
  ///
  /// In es, this message translates to:
  /// **'Plan guardado'**
  String get settledPlan;

  /// No description provided for @settledCancelled.
  ///
  /// In es, this message translates to:
  /// **'Marcadas como canceladas'**
  String get settledCancelled;

  /// No description provided for @settledAt.
  ///
  /// In es, this message translates to:
  /// **'{what} · {time}'**
  String settledAt(String what, String time);

  /// No description provided for @cancelPickHint.
  ///
  /// In es, this message translates to:
  /// **'Marca las que quieras cancelar para ver cuánto ahorras'**
  String get cancelPickHint;

  /// No description provided for @subscriptionSelect.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar {name} para cancelar'**
  String subscriptionSelect(String name);

  /// No description provided for @subscriptionToCancel.
  ///
  /// In es, this message translates to:
  /// **'Para cancelar'**
  String get subscriptionToCancel;

  /// No description provided for @subscriptionCancelled.
  ///
  /// In es, this message translates to:
  /// **'Cancelada'**
  String get subscriptionCancelled;

  /// No description provided for @cardLimitField.
  ///
  /// In es, this message translates to:
  /// **'Cupo total (opcional)'**
  String get cardLimitField;

  /// No description provided for @cardLimitHelp.
  ///
  /// In es, this message translates to:
  /// **'Con el cupo te mostramos cuánto te queda por usar. Nunca se suma a lo que puedes gastar: es plata prestada.'**
  String get cardLimitHelp;

  /// No description provided for @cardCreditLeft.
  ///
  /// In es, this message translates to:
  /// **'Cupo libre {amount}'**
  String cardCreditLeft(String amount);

  /// No description provided for @cardCreditLeftOf.
  ///
  /// In es, this message translates to:
  /// **'Cupo libre {left} de {limit}'**
  String cardCreditLeftOf(String left, String limit);

  /// No description provided for @groupCrypto.
  ///
  /// In es, this message translates to:
  /// **'Cripto'**
  String get groupCrypto;

  /// No description provided for @cryptoPerformanceRow.
  ///
  /// In es, this message translates to:
  /// **'Rendimiento y ganancia'**
  String get cryptoPerformanceRow;

  /// No description provided for @portfolioSources.
  ///
  /// In es, this message translates to:
  /// **'Gestionar fuentes'**
  String get portfolioSources;

  /// No description provided for @binanceRowOff.
  ///
  /// In es, this message translates to:
  /// **'Sin conectar · solo lectura, nunca mueve fondos'**
  String get binanceRowOff;

  /// No description provided for @binanceCardManualBody.
  ///
  /// In es, this message translates to:
  /// **'Tus saldos de Binance están anotados a mano. Conéctala para que se actualicen solos.'**
  String get binanceCardManualBody;

  /// No description provided for @portfolioSourceManual.
  ///
  /// In es, this message translates to:
  /// **'Anotado a mano: no se actualiza solo'**
  String get portfolioSourceManual;

  /// No description provided for @portfolioSourceBinance.
  ///
  /// In es, this message translates to:
  /// **'Conectada a Binance · leída {when}'**
  String portfolioSourceBinance(String when);

  /// No description provided for @portfolioSourceBinanceNever.
  ///
  /// In es, this message translates to:
  /// **'Conectada a Binance: se actualiza sola'**
  String get portfolioSourceBinanceNever;

  /// No description provided for @portfolioSourceWallet.
  ///
  /// In es, this message translates to:
  /// **'Por dirección pública · leída {when}'**
  String portfolioSourceWallet(String when);

  /// No description provided for @portfolioSourceWalletNever.
  ///
  /// In es, this message translates to:
  /// **'Por dirección pública: se actualiza sola'**
  String get portfolioSourceWalletNever;

  /// No description provided for @chartNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get chartNow;

  /// No description provided for @chartZero.
  ///
  /// In es, this message translates to:
  /// **'0 = como empezó el periodo'**
  String get chartZero;

  /// No description provided for @chartPointGain.
  ///
  /// In es, this message translates to:
  /// **'{when}: {amount} desde el inicio'**
  String chartPointGain(String when, String amount);

  /// No description provided for @chartPointValue.
  ///
  /// In es, this message translates to:
  /// **'{when}: valía {amount}'**
  String chartPointValue(String when, String amount);

  /// No description provided for @chartTouchHint.
  ///
  /// In es, this message translates to:
  /// **'Toca la línea y desliza el dedo para ver cada momento.'**
  String get chartTouchHint;

  /// No description provided for @chartSemanticsGain.
  ///
  /// In es, this message translates to:
  /// **'Ganancia por precio {range}: {amount}, {percent}'**
  String chartSemanticsGain(String range, String amount, String percent);

  /// No description provided for @portfolioSourceBinanceOff.
  ///
  /// In es, this message translates to:
  /// **'Leída de Binance · sin conectar'**
  String get portfolioSourceBinanceOff;

  /// No description provided for @portfolioSourceWalletOff.
  ///
  /// In es, this message translates to:
  /// **'Leída por dirección pública · ya no la sigues'**
  String get portfolioSourceWalletOff;

  /// No description provided for @demoBannerTitle.
  ///
  /// In es, this message translates to:
  /// **'Estás viendo la cuenta de ejemplo de {name}'**
  String demoBannerTitle(String name);

  /// No description provided for @demoBannerBody.
  ///
  /// In es, this message translates to:
  /// **'Con tus cuentas, Quincena te dice cuánto puedes gastar tú. Se guardan solo en este dispositivo.'**
  String get demoBannerBody;

  /// No description provided for @standingNextCharge.
  ///
  /// In es, this message translates to:
  /// **'El próximo: {name}, {amount} el {date}'**
  String standingNextCharge(String name, String amount, String date);

  /// No description provided for @homeTodoThen.
  ///
  /// In es, this message translates to:
  /// **'Después'**
  String get homeTodoThen;

  /// No description provided for @todoLatePay.
  ///
  /// In es, this message translates to:
  /// **'Registra tu pago del {date}'**
  String todoLatePay(String date);

  /// No description provided for @todoLatePayBody.
  ///
  /// In es, this message translates to:
  /// **'Todavía no aparece. Si ya llegó, regístralo para que cuente.'**
  String get todoLatePayBody;

  /// No description provided for @todoRecord.
  ///
  /// In es, this message translates to:
  /// **'Registrar'**
  String get todoRecord;

  /// No description provided for @todoRates.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Falta la tasa de {codes}} other{Faltan las tasas de {codes}}}'**
  String todoRates(int count, String codes);

  /// No description provided for @todoRatesBody.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Mientras tanto cuenta como cero en tus totales.} other{Mientras tanto cuentan como cero en tus totales.}}'**
  String todoRatesBody(int count);

  /// No description provided for @todoSeeRates.
  ///
  /// In es, this message translates to:
  /// **'Ver tasas'**
  String get todoSeeRates;

  /// No description provided for @standingProvisional.
  ///
  /// In es, this message translates to:
  /// **'Provisional: faltan tus pagos fijos'**
  String get standingProvisional;

  /// No description provided for @todoFixedTitle.
  ///
  /// In es, this message translates to:
  /// **'Agrega tus pagos fijos'**
  String get todoFixedTitle;

  /// No description provided for @todoFixedBody.
  ///
  /// In es, this message translates to:
  /// **'Lo que pagues hasta el {date} sale de lo que puedes gastar.'**
  String todoFixedBody(String date);

  /// No description provided for @todoAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get todoAdd;

  /// No description provided for @noFixedPayments.
  ///
  /// In es, this message translates to:
  /// **'No tengo pagos fijos'**
  String get noFixedPayments;

  /// No description provided for @fixedNoneDone.
  ///
  /// In es, this message translates to:
  /// **'Listo. Lo que puedes gastar ya no es provisional.'**
  String get fixedNoneDone;

  /// No description provided for @freeExplainAssumeNoFixed.
  ///
  /// In es, this message translates to:
  /// **'No tiene pagos fijos: si pagas arriendo, servicios o suscripciones, agrégalos en Plan › Pagos fijos y saldrán de esta cifra antes de llegar.'**
  String get freeExplainAssumeNoFixed;

  /// No description provided for @onboardingPayAmount.
  ///
  /// In es, this message translates to:
  /// **'{kind, select, fortnight{¿Cuánto te llega cada quincena?} other{¿Cuánto te llega cada pago?}}'**
  String onboardingPayAmount(String kind);

  /// No description provided for @onboardingPayAmountHelp.
  ///
  /// In es, this message translates to:
  /// **'Opcional. No cuenta como plata hasta que llega; sirve para ver los días que vienen.'**
  String get onboardingPayAmountHelp;

  /// No description provided for @onboardingFixedTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué pagas fijo?'**
  String get onboardingFixedTitle;

  /// No description provided for @onboardingFixedBody.
  ///
  /// In es, this message translates to:
  /// **'Arriendo, servicios, celular, suscripciones. Quincena los resta de lo que puedes gastar antes de que lleguen.'**
  String get onboardingFixedBody;

  /// No description provided for @fixedSuggestRent.
  ///
  /// In es, this message translates to:
  /// **'Arriendo'**
  String get fixedSuggestRent;

  /// No description provided for @fixedSuggestAdmin.
  ///
  /// In es, this message translates to:
  /// **'Administración'**
  String get fixedSuggestAdmin;

  /// No description provided for @fixedSuggestUtilities.
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get fixedSuggestUtilities;

  /// No description provided for @fixedSuggestInternet.
  ///
  /// In es, this message translates to:
  /// **'Internet'**
  String get fixedSuggestInternet;

  /// No description provided for @fixedSuggestPhone.
  ///
  /// In es, this message translates to:
  /// **'Plan del celular'**
  String get fixedSuggestPhone;

  /// No description provided for @fixedSuggestSubscription.
  ///
  /// In es, this message translates to:
  /// **'Una suscripción'**
  String get fixedSuggestSubscription;

  /// No description provided for @inboxReadySection.
  ///
  /// In es, this message translates to:
  /// **'Listos para registrar'**
  String get inboxReadySection;

  /// No description provided for @inboxNeedsInfoSection.
  ///
  /// In es, this message translates to:
  /// **'Necesitan información'**
  String get inboxNeedsInfoSection;

  /// No description provided for @inboxReadyCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 listo} other{{count} listos}}'**
  String inboxReadyCount(int count);

  /// No description provided for @inboxNeedsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 necesita información} other{{count} necesitan información}}'**
  String inboxNeedsCount(int count);

  /// No description provided for @inboxRecordReady.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Registrar el que está listo} other{Registrar los {count} listos}}'**
  String inboxRecordReady(int count);

  /// No description provided for @inboxRecordedMany.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un movimiento registrado.} other{{count} movimientos registrados.}}'**
  String inboxRecordedMany(int count);

  /// No description provided for @recordExpense.
  ///
  /// In es, this message translates to:
  /// **'Registrar gasto'**
  String get recordExpense;

  /// No description provided for @recordIncome.
  ///
  /// In es, this message translates to:
  /// **'Registrar ingreso'**
  String get recordIncome;

  /// No description provided for @recordTransfer.
  ///
  /// In es, this message translates to:
  /// **'Registrar transferencia'**
  String get recordTransfer;

  /// No description provided for @reviewMovement.
  ///
  /// In es, this message translates to:
  /// **'Revisar movimiento'**
  String get reviewMovement;

  /// No description provided for @recordedExpenseIn.
  ///
  /// In es, this message translates to:
  /// **'Gasto registrado en {account}.'**
  String recordedExpenseIn(String account);

  /// No description provided for @recordedIncomeIn.
  ///
  /// In es, this message translates to:
  /// **'Ingreso registrado en {account}.'**
  String recordedIncomeIn(String account);

  /// No description provided for @recordedTransfer.
  ///
  /// In es, this message translates to:
  /// **'Transferencia registrada.'**
  String get recordedTransfer;

  /// No description provided for @accountMissingShort.
  ///
  /// In es, this message translates to:
  /// **'Falta la cuenta'**
  String get accountMissingShort;

  /// No description provided for @kindMissing.
  ///
  /// In es, this message translates to:
  /// **'No sabemos si es un gasto o un ingreso.'**
  String get kindMissing;

  /// No description provided for @accountGuessed.
  ///
  /// In es, this message translates to:
  /// **'Revisa la cuenta: la elegimos por ser tu única de uso diario en {asset}.'**
  String accountGuessed(String asset);

  /// No description provided for @whichAccountCard.
  ///
  /// In es, this message translates to:
  /// **'Detectamos {institution} y la tarjeta *{digits}, pero falta asociarla a una de tus cuentas.'**
  String whichAccountCard(String institution, String digits);

  /// No description provided for @whichAccountBankMany.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =2{Detectamos {institution}, pero tienes dos cuentas ahí: elige cuál fue.} other{Detectamos {institution}, pero tienes {count} cuentas ahí: elige cuál fue.}}'**
  String whichAccountBankMany(int count, String institution);

  /// No description provided for @whichAccountBankNone.
  ///
  /// In es, this message translates to:
  /// **'Detectamos {institution}, pero no tienes una cuenta de ese banco en Quincena.'**
  String whichAccountBankNone(String institution);

  /// No description provided for @pickAccountOut.
  ///
  /// In es, this message translates to:
  /// **'¿De qué cuenta salió?'**
  String get pickAccountOut;

  /// No description provided for @pickAccountIn.
  ///
  /// In es, this message translates to:
  /// **'¿A qué cuenta llegó?'**
  String get pickAccountIn;

  /// No description provided for @pickAccountCardNote.
  ///
  /// In es, this message translates to:
  /// **'La próxima vez, lo de la tarjeta *{digits} irá directo a esa cuenta.'**
  String pickAccountCardNote(String digits);

  /// No description provided for @pickAccountBankNote.
  ///
  /// In es, this message translates to:
  /// **'La próxima vez, lo de {institution} irá directo a esa cuenta.'**
  String pickAccountBankNote(String institution);

  /// No description provided for @accountRequired.
  ///
  /// In es, this message translates to:
  /// **'Elige la cuenta.'**
  String get accountRequired;

  /// No description provided for @detectionDetails.
  ///
  /// In es, this message translates to:
  /// **'Detalles de detección'**
  String get detectionDetails;

  /// No description provided for @hideDetectionDetails.
  ///
  /// In es, this message translates to:
  /// **'Ocultar detalles'**
  String get hideDetectionDetails;

  /// No description provided for @detectionHow.
  ///
  /// In es, this message translates to:
  /// **'Cómo llegó'**
  String get detectionHow;

  /// No description provided for @detectionWhy.
  ///
  /// In es, this message translates to:
  /// **'Por qué lo sugerimos'**
  String get detectionWhy;

  /// No description provided for @detectionMessage.
  ///
  /// In es, this message translates to:
  /// **'El mensaje'**
  String get detectionMessage;

  /// No description provided for @placeShort.
  ///
  /// In es, this message translates to:
  /// **'Por ubicación · © OpenStreetMap'**
  String get placeShort;

  /// No description provided for @inboxAddFrom.
  ///
  /// In es, this message translates to:
  /// **'Leer un pago'**
  String get inboxAddFrom;

  /// No description provided for @inboxAddTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Dónde está el pago?'**
  String get inboxAddTitle;

  /// No description provided for @inboxAddImage.
  ///
  /// In es, this message translates to:
  /// **'Un pantallazo, foto o PDF'**
  String get inboxAddImage;

  /// No description provided for @inboxAddImageBody.
  ///
  /// In es, this message translates to:
  /// **'Se lee en este dispositivo y queda aquí para revisar.'**
  String get inboxAddImageBody;

  /// No description provided for @inboxAddPaste.
  ///
  /// In es, this message translates to:
  /// **'Un mensaje que copiaste'**
  String get inboxAddPaste;

  /// No description provided for @inboxAddPasteBody.
  ///
  /// In es, this message translates to:
  /// **'Pega la notificación, el SMS o el correo del banco.'**
  String get inboxAddPasteBody;

  /// No description provided for @inboxWaiting.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 movimiento por revisar} other{{count} movimientos por revisar}}'**
  String inboxWaiting(int count);

  /// No description provided for @inboxRecordSome.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Registrar 1 de los {total} listos} other{Registrar {count} de los {total} listos}}'**
  String inboxRecordSome(int count, int total);

  /// No description provided for @exampleBarTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuenta de ejemplo de {name}'**
  String exampleBarTitle(String name);

  /// No description provided for @exampleUseOwn.
  ///
  /// In es, this message translates to:
  /// **'Usar mis cuentas'**
  String get exampleUseOwn;

  /// No description provided for @exampleAboutBody.
  ///
  /// In es, this message translates to:
  /// **'{name} es inventada, como todas sus cifras. Lo que hagas aquí no toca tus cuentas ni tus datos, y se borra al salir del ejemplo.'**
  String exampleAboutBody(String name);

  /// No description provided for @exampleBackToStart.
  ///
  /// In es, this message translates to:
  /// **'Volver a la primera pantalla'**
  String get exampleBackToStart;

  /// No description provided for @exampleStay.
  ///
  /// In es, this message translates to:
  /// **'Seguir en el ejemplo'**
  String get exampleStay;

  /// No description provided for @exampleOnlyBody.
  ///
  /// In es, this message translates to:
  /// **'Esta es la cuenta de ejemplo de {name}, y es inventada. Aquí esto no hace nada: no se conecta con nada, no le pide permisos a tu teléfono y no toca tus datos. Para usarlo, pasa a tus cuentas.'**
  String exampleOnlyBody(String name);

  /// No description provided for @exampleNoReminders.
  ///
  /// In es, this message translates to:
  /// **'En la cuenta de ejemplo no se programan avisos.'**
  String get exampleNoReminders;

  /// No description provided for @exampleSection.
  ///
  /// In es, this message translates to:
  /// **'Cuenta de ejemplo'**
  String get exampleSection;

  /// No description provided for @examplePricedAt.
  ///
  /// In es, this message translates to:
  /// **'Precios fijos del ejemplo, del {when}'**
  String examplePricedAt(String when);
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
