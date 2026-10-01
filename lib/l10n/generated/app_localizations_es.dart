// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String greeting(String name) {
    return 'Hola, $name';
  }

  @override
  String freeUntil(String date) {
    return 'Libre hasta el $date';
  }

  @override
  String standingDetail(int days, String committed) {
    return 'Faltan $days días. Ya separé $committed para el arriendo, el crédito y los pagos fijos.';
  }

  @override
  String standingSemantics(String date, String free, int days, String balance) {
    return 'Libre hasta el $date: $free. Faltan $days días. En la cuenta hay $balance.';
  }

  @override
  String get legendFree => 'Libre';

  @override
  String get legendCommitted => 'Comprometido';

  @override
  String get inTheAccount => 'En la cuenta';

  @override
  String get askYourMoney => 'PREGÚNTALE A TU PLATA';

  @override
  String get seeRecorded => 'Mira lo que respondió Gemini de verdad';

  @override
  String get badgeDemo => 'DEMO';

  @override
  String get badgeLive => 'EN VIVO';

  @override
  String get newConversation => 'Nueva conversación';

  @override
  String get settings => 'Ajustes';

  @override
  String get askHint => 'Pregúntale algo a tu plata';

  @override
  String get ask => 'Preguntar';

  @override
  String get thinking => 'Revisando tus movimientos';

  @override
  String get noteSavedExpense => 'Guardaste el gasto';

  @override
  String get noteChoseMonthly => 'Elegiste cuánto apartar';

  @override
  String get noteAskedCancel => 'Pediste cancelar suscripciones';

  @override
  String get noteAskedPayments => 'Pediste ver los pagos';

  @override
  String get noteTappedAction => 'Tocaste una acción';

  @override
  String get problemKey => 'La key no funcionó. Revísala en Ajustes.';

  @override
  String get problemBusy =>
      'El modelo está recibiendo demasiadas preguntas. Prueba en un minuto.';

  @override
  String get problemOther => 'No pude responder esta vez. Prueba de nuevo.';

  @override
  String get whoAnswers => 'Quién responde';

  @override
  String get modeDemo => 'Demo';

  @override
  String get modeLive => 'Gemini en vivo';

  @override
  String get demoExplain =>
      'Las cinco preguntas del inicio, respondidas sin red con los mismos componentes que usa el modelo.';

  @override
  String liveActive(String model) {
    return 'Responde $model. Pregunta lo que quieras sobre la cuenta.';
  }

  @override
  String get liveNeedsKey =>
      'Con tu key de Gemini puedes preguntar lo que quieras. Se queda en esta pestaña: no se guarda, y solo viaja a Google.';

  @override
  String get keyLabel => 'Key de Gemini';

  @override
  String get keyHint => 'De aistudio.google.com';

  @override
  String get connect => 'Conectar';

  @override
  String get appearance => 'Apariencia';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get developerMode => 'Modo desarrollador';

  @override
  String get developerExplain =>
      'Muestra el inspector de genui_gen sobre la conversación: el árbol que armó el agente, el data model, lo que anuncia un lector de pantalla y los mensajes.';

  @override
  String get copySession => 'Copiar la sesión';

  @override
  String get sessionCopied =>
      'Sesión copiada, sin lo que escribiste. Pégala en un issue y se puede reproducir.';

  @override
  String get startOver => 'Empezar de nuevo';

  @override
  String get about =>
      'Quincena es una demo de genui y genui_gen. La cuenta, la persona y los comercios son inventados.';

  @override
  String get recordedTitle => 'Lo que respondió Gemini';

  @override
  String get recordedIntro =>
      'Estas sesiones no son del guion de la demo. Gemini recibió cada pregunta, consultó la cuenta con herramientas y compuso la pantalla con el catálogo de la app. genui_gen grabó todo lo que mandó, y aquí se reproduce paso a paso, sin red.';

  @override
  String recordedMeta(String model, int steps) {
    return '$model · $steps pasos';
  }

  @override
  String recordedSeconds(double seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String secondsString = secondsNumberFormat.format(seconds);

    return '$secondsString s';
  }

  @override
  String get stepBefore => 'Antes de la respuesta';

  @override
  String get stepCreate => 'Crea la superficie';

  @override
  String get stepComponents => 'Manda los componentes';

  @override
  String get stepData => 'Manda los datos';

  @override
  String get stepDataChanged => 'Cambian los datos';

  @override
  String get stepEvent => 'La app le responde al agente';

  @override
  String get stepMessage => 'Mensaje';

  @override
  String stepOf(int position, int length) {
    return '$position de $length';
  }

  @override
  String stepSemantics(int position, int length) {
    return 'Paso $position de $length';
  }

  @override
  String get setAsideMonthly => 'Apartar al mes';

  @override
  String get arrivesIn => 'Llegas en ';

  @override
  String beforeDeadline(String deadline) {
    return ', antes del $deadline.';
  }

  @override
  String afterDeadline(String deadline) {
    return ', después del $deadline.';
  }

  @override
  String goalProgress(int percent) {
    return 'Llevas $percent por ciento de la meta';
  }

  @override
  String goalSlider(String name) {
    return 'Apartar al mes para $name';
  }

  @override
  String perMonth(String amount) {
    return '$amount al mes';
  }

  @override
  String get cancelSaves => 'Si cancelas lo que apagaste, te ahorras';

  @override
  String used(String ago) {
    return 'usado $ago';
  }

  @override
  String get noUsage => 'sin datos de uso';

  @override
  String get limit => 'Límite';

  @override
  String more(String amount) {
    return '$amount más';
  }

  @override
  String less(String amount) {
    return '$amount menos';
  }

  @override
  String get reference => 'Referencia';

  @override
  String inTotal(String amount) {
    return '$amount en total';
  }
}
