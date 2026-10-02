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
  /// **'¿Cuánto me queda libre hasta el pago?'**
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
  /// **'Gemini no recibe tu base de datos. Pide las cifras que necesita a herramientas que corren en tu teléfono o tu computador, y lo que viaja son sus respuestas: tus totales por categoría y por mes, lo libre hasta el pago, tus suscripciones, tu meta de ahorro, tus cuentas con su saldo y, cuando la pregunta lo pide, los pagos más grandes de un mes con su comercio.'**
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
  /// **'Mira cómo funciona con la cuenta de Valentina, una diseñadora en Medellín. Puedes pasar a tus cuentas cuando quieras.'**
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
  /// **'Con esto Quincena calcula cuánto tienes libre hasta el próximo pago.'**
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
  String payTwiceMonthlyDetail(int first, int second);

  /// No description provided for @payMonthly.
  ///
  /// In es, this message translates to:
  /// **'Mensual'**
  String get payMonthly;

  /// No description provided for @payMonthlyDetail.
  ///
  /// In es, this message translates to:
  /// **'El día {day} de cada mes'**
  String payMonthlyDetail(int day);

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
  /// **'Cuenta para gastar'**
  String get accountSpendable;

  /// No description provided for @accountSpendableHelp.
  ///
  /// In es, this message translates to:
  /// **'Su saldo cuenta en lo que tienes libre hasta el próximo pago. Apágalo para ahorros, inversiones y cripto.'**
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
  /// **'Para gastar'**
  String get groupSpendable;

  /// No description provided for @groupSaved.
  ///
  /// In es, this message translates to:
  /// **'Ahorros, inversiones y cripto'**
  String get groupSaved;

  /// No description provided for @netWorth.
  ///
  /// In es, this message translates to:
  /// **'Todo lo que tienes'**
  String get netWorth;

  /// No description provided for @noAccounts.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes cuentas.'**
  String get noAccounts;

  /// No description provided for @yourAccounts.
  ///
  /// In es, this message translates to:
  /// **'Tus cuentas'**
  String get yourAccounts;

  /// No description provided for @accountMovements.
  ///
  /// In es, this message translates to:
  /// **'Movimientos de la cuenta'**
  String get accountMovements;

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

  /// No description provided for @rateManual.
  ///
  /// In es, this message translates to:
  /// **'Escrita a mano'**
  String get rateManual;

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
  /// **'{asset} se cuenta como un dólar.'**
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
  /// **'Aún no hay movimientos.'**
  String get noMovements;

  /// No description provided for @noMovementsBody.
  ///
  /// In es, this message translates to:
  /// **'Registra un gasto, un ingreso o una transferencia con el botón +.'**
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

  /// No description provided for @importFailed.
  ///
  /// In es, this message translates to:
  /// **'Ese archivo no se pudo leer: {reason}'**
  String importFailed(String reason);

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
  /// **'Tus cuentas y movimientos se guardan solo en este dispositivo. Para las tasas, Quincena consulta fuentes públicas (la TRM, Binance y el Banco Central Europeo) sin enviar nada tuyo.'**
  String get privacyBody;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @standingDaysLeft.
  ///
  /// In es, this message translates to:
  /// **'{days, plural, =0{Hoy es día de pago.} =1{Falta un día para el próximo pago.} other{Faltan {days} días para el próximo pago.}}'**
  String standingDaysLeft(int days);

  /// No description provided for @standingCommittedOwn.
  ///
  /// In es, this message translates to:
  /// **'{committed} ya están comprometidos en pagos programados.'**
  String standingCommittedOwn(String committed);

  /// No description provided for @inboxTitle.
  ///
  /// In es, this message translates to:
  /// **'Por revisar'**
  String get inboxTitle;

  /// No description provided for @inboxBanner.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Un movimiento por revisar} other{{count} movimientos por revisar}}'**
  String inboxBanner(int count);

  /// No description provided for @inboxBannerBody.
  ///
  /// In es, this message translates to:
  /// **'Llegaron de tus notificaciones y mensajes.'**
  String get inboxBannerBody;

  /// No description provided for @inboxEmpty.
  ///
  /// In es, this message translates to:
  /// **'Nada por revisar.'**
  String get inboxEmpty;

  /// No description provided for @inboxEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Cuando llegue un pago de tu banco, aparece aquí para confirmarlo.'**
  String get inboxEmptyBody;

  /// No description provided for @confirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get confirm;

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
  /// **'Elige la cuenta'**
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
  /// **'Cerca: {name}, a {metres} m'**
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
  /// **'Leer una captura'**
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

  /// No description provided for @showOriginal.
  ///
  /// In es, this message translates to:
  /// **'Ver el mensaje'**
  String get showOriginal;

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
  /// **'Cuando la alerta no dice dónde fue, Quincena busca los comercios a unos metros de donde estaba el teléfono. La ubicación se guarda solo aquí; para buscar los comercios se envían únicamente las coordenadas a OpenStreetMap, a través de Photon.'**
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
  /// **'Los pagos casi siempre llegan con Quincena cerrada. Para saber dónde estabas en ese momento, Android pide elegir «Permitir todo el tiempo». Quincena solo mira la ubicación cuando llega una notificación de pago.'**
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
  /// **'Comparte con Quincena una captura, una foto, un PDF o un texto desde cualquier app, o elígelos en Por revisar. Se leen en el teléfono y quedan para que los confirmes.'**
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
