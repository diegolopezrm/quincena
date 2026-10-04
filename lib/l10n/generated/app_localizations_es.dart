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
    return 'Puedes gastar hasta el $date';
  }

  @override
  String standingSemantics(String free, String date, String when) {
    return 'Puedes gastar $free hasta el $date; $when.';
  }

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
  String get noteChoseMonthly => 'Guardaste el plan';

  @override
  String get noteAskedCancel => 'Marcaste lo que ya cancelaste';

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
  String get problemOffline =>
      'Sin conexión a internet. Tus cuentas y movimientos siguen funcionando; vuelve a preguntar cuando tengas red.';

  @override
  String get problemOther => 'No pude responder esta vez. Prueba de nuevo.';

  @override
  String get problemLimit =>
      'Ya usaste las preguntas de hoy. Mañana puedes seguir preguntando.';

  @override
  String get askTitle => 'Pregúntale a tu plata';

  @override
  String get askYourMoneyLabel => 'Pregúntale a tu plata';

  @override
  String get ownAskFree => '¿Cuánto puedo gastar antes de que me paguen?';

  @override
  String get ownAskMonth => '¿En qué se me fue la plata este mes?';

  @override
  String get ownAskAll => '¿Cuánto tengo en total, con dólares y cripto?';

  @override
  String get ownAskCompare => '¿Cómo voy comparado con el mes pasado?';

  @override
  String get ownAskRecord => 'Quiero anotar un gasto';

  @override
  String get askOther => 'Otra pregunta';

  @override
  String askLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Te quedan $count preguntas hoy',
      one: 'Te queda una pregunta hoy',
      zero: 'Ya no te quedan preguntas hoy',
    );
    return '$_temp0';
  }

  @override
  String get askWhatSees => 'Qué ve Gemini';

  @override
  String get geminiNoteHow =>
      'Cuando le preguntas algo a tu plata, la pregunta va a Gemini, el modelo de Google, a través del proyecto de Quincena en Firebase. No necesitas una key ni una cuenta: Quincena te identifica con un usuario anónimo, solo para contar tus preguntas.';

  @override
  String get geminiNoteSends =>
      'Gemini no recibe tu base de datos. Pide las cifras que necesita a herramientas que corren en tu teléfono o tu computador, y lo que viaja son sus respuestas: tus totales por categoría y por mes, lo que puedes gastar hasta el pago, tus suscripciones, tu meta de ahorro, tus cuentas con su saldo y, cuando la pregunta lo pide, los pagos más grandes de un mes con su comercio.';

  @override
  String get geminiNoteNot =>
      'No viajan tus otros movimientos uno por uno, ni tus notas, ni las alertas de tu banco, ni tu ubicación.';

  @override
  String get geminiNoteTerms =>
      'Quincena usa Gemini en Agent Platform, de Google Cloud, como cliente que paga: Google no entrena sus modelos con lo que se envía ni lo guarda en caché, y solo conserva una pregunta si sus filtros la marcan como abuso. Aun así, no escribas en una pregunta nada que no quieras compartir, como un número de cuenta.';

  @override
  String geminiNoteLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada persona tiene $count preguntas al día.',
      one: 'Cada persona tiene una pregunta al día.',
    );
    return '$_temp0 Firebase App Check comprueba que vienen de la app de Quincena y no de otro programa.';
  }

  @override
  String get whoAnswers => 'Quién responde';

  @override
  String get modeDemo => 'Demo';

  @override
  String get modeLive => 'Gemini en vivo';

  @override
  String get modeGemini => 'Gemini';

  @override
  String get modeOwnKey => 'Tu key';

  @override
  String geminiExplain(String model) {
    return 'Responde $model a través de Quincena, sin key. Pregunta lo que quieras sobre la cuenta.';
  }

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
  String get setAsideMonthly => 'Si apartas al mes';

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
  String get cancelSaves => 'Si cancelas las que marcaste, te ahorras';

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

  @override
  String get startTitle => '¿Cómo quieres empezar?';

  @override
  String get startOwnTitle => 'Con mis cuentas';

  @override
  String get startOwnBody =>
      'Agrega tus cuentas en pesos, dólares o cripto y registra lo que entra y lo que sale.';

  @override
  String get startDemoTitle => 'Con datos de ejemplo';

  @override
  String get startDemoBody =>
      'Mira cómo funciona con la cuenta de Valentina, una diseñadora en Medellín. Puedes pasar a tus cuentas cuando quieras.';

  @override
  String get privacyNote =>
      'Tus cuentas y movimientos se guardan solo en este dispositivo.';

  @override
  String onboardingStep(int step, int total) {
    return 'Paso $step de $total';
  }

  @override
  String get onboardingNameTitle => '¿Cómo te llamas?';

  @override
  String get onboardingNameHint => 'Tu nombre';

  @override
  String get onboardingBaseTitle => '¿En qué moneda quieres ver tus totales?';

  @override
  String get onboardingBaseBody =>
      'Cada cuenta conserva su propia moneda; los totales se convierten a esta.';

  @override
  String get onboardingPayTitle => '¿Cómo te pagan?';

  @override
  String get onboardingPayBody =>
      'Con esto Quincena calcula cuánto puedes gastar hasta el próximo pago.';

  @override
  String get onboardingAccountsTitle => 'Agrega tus cuentas';

  @override
  String get onboardingAccountsBody =>
      'Bancos, billeteras, efectivo, tarjetas o cripto. Puedes agregar más después.';

  @override
  String get onboardingSuggestions => 'Para empezar rápido';

  @override
  String get onboardingNeedAccount =>
      'Agrega al menos una cuenta para empezar.';

  @override
  String get next => 'Siguiente';

  @override
  String get back => 'Atrás';

  @override
  String get finish => 'Empezar';

  @override
  String get payTwiceMonthly => 'Quincenal';

  @override
  String payTwiceMonthlyDetail(int first, int second) {
    return 'Los días $first y $second de cada mes';
  }

  @override
  String get payMonthly => 'Mensual';

  @override
  String payMonthlyDetail(int day) {
    return 'El día $day de cada mes';
  }

  @override
  String get payBiweekly => 'Cada dos semanas';

  @override
  String payBiweeklyDetail(String date) {
    return 'Cada 14 días, contando desde el $date';
  }

  @override
  String get payWeekly => 'Semanal';

  @override
  String payWeeklyDetail(String weekday) {
    return 'Cada $weekday';
  }

  @override
  String get payFirstDay => 'Primer pago';

  @override
  String get paySecondDay => 'Segundo pago';

  @override
  String get payDay => 'Día de pago';

  @override
  String get payLastPayday => 'Tu último pago';

  @override
  String get payWeekday => 'Día de la semana';

  @override
  String payDayOption(int day) {
    return 'Día $day';
  }

  @override
  String get tabHome => 'Inicio';

  @override
  String get tabMovements => 'Movimientos';

  @override
  String get tabAccounts => 'Cuentas';

  @override
  String get addAccount => 'Agregar cuenta';

  @override
  String get editAccount => 'Editar cuenta';

  @override
  String get accountName => 'Nombre';

  @override
  String get accountNameHint => 'Por ejemplo, Bancolombia ahorros';

  @override
  String get accountKind => 'Tipo';

  @override
  String get kindBank => 'Banco';

  @override
  String get kindCard => 'Tarjeta de crédito';

  @override
  String get kindCash => 'Efectivo';

  @override
  String get kindWallet => 'Billetera digital';

  @override
  String get kindExchange => 'Exchange de cripto';

  @override
  String get kindInvestment => 'Ahorro o inversión';

  @override
  String get kindOther => 'Otra';

  @override
  String get accountAsset => 'Moneda';

  @override
  String get assetFiat => 'Monedas';

  @override
  String get assetCrypto => 'Cripto';

  @override
  String get assetOther => 'Otra cripto';

  @override
  String get assetOtherHint => 'Símbolo, por ejemplo ADA';

  @override
  String get accountInstitution => 'Entidad (opcional)';

  @override
  String get accountBalanceNow => '¿Cuánto tiene hoy?';

  @override
  String get accountDebtNow => '¿Cuánto debes hoy?';

  @override
  String get accountSpendable => 'Cuenta de uso diario';

  @override
  String get accountSpendableHelp =>
      'Su saldo cuenta en lo que puedes gastar hasta el próximo pago. Apágalo para ahorros, inversiones y cripto.';

  @override
  String get accountAssetLocked =>
      'La moneda no se puede cambiar: los movimientos de la cuenta están en ella.';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get cancel => 'Cancelar';

  @override
  String deleteAccountTitle(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String deleteAccountBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se borran también sus $count movimientos. No se puede deshacer.',
      one: 'Se borra también su movimiento. No se puede deshacer.',
      zero: 'No tiene movimientos.',
    );
    return '$_temp0';
  }

  @override
  String get groupSpendable => 'Cuentas de uso diario';

  @override
  String get groupSaved => 'Ahorros e inversiones';

  @override
  String get netWorth => 'Patrimonio';

  @override
  String get noAccounts =>
      'Aún no tienes cuentas. Agrega la de tu banco, tu billetera o el efectivo con «Agregar cuenta».';

  @override
  String get yourAccounts => 'Tus cuentas';

  @override
  String get accountMovements => 'Movimientos de la cuenta';

  @override
  String get balanceToday => 'Saldo hoy';

  @override
  String get ratesTitle => 'Tasas';

  @override
  String ratesUpdated(String when) {
    return 'Actualizadas $when';
  }

  @override
  String get ratesNever => 'Aún sin tasas: se buscan al conectarse.';

  @override
  String get ratesRefresh => 'Actualizar tasas';

  @override
  String get ratesFailed =>
      'No se pudieron actualizar. Se usan las últimas guardadas.';

  @override
  String ratesMissing(String assets) {
    return 'Sin tasa para $assets: cuenta como cero en los totales.';
  }

  @override
  String get rateSourceTrm => 'TRM oficial';

  @override
  String get rateSourceBinance => 'Binance';

  @override
  String get rateSourceEcb => 'Banco Central Europeo';

  @override
  String get rateEdit => 'Escribir una tasa';

  @override
  String rateEditBody(String asset, String quote) {
    return 'Cuánto vale 1 $asset en $quote. Una tasa escrita a mano no se reemplaza al actualizar.';
  }

  @override
  String get rateUseFetched => 'Volver a la tasa automática';

  @override
  String stablecoinPeg(String asset) {
    return '$asset se cuenta como 1 US\$';
  }

  @override
  String get addMovement => 'Agregar movimiento';

  @override
  String get editMovement => 'Editar movimiento';

  @override
  String get kindExpense => 'Gasto';

  @override
  String get kindIncome => 'Ingreso';

  @override
  String get kindTransfer => 'Transferencia';

  @override
  String get amount => 'Monto';

  @override
  String get account => 'Cuenta';

  @override
  String get fromAccount => 'Desde';

  @override
  String get toAccount => 'Hacia';

  @override
  String get received => 'Llegó';

  @override
  String get receivedHelp => 'Lo que llegó a la otra cuenta, en su moneda.';

  @override
  String get category => 'Categoría';

  @override
  String get newCategory => 'Nueva categoría';

  @override
  String get payee => '¿Dónde o a quién?';

  @override
  String get payeeIncome => '¿De dónde?';

  @override
  String get date => 'Fecha';

  @override
  String get note => 'Nota (opcional)';

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get searchMovements => 'Buscar movimientos';

  @override
  String get noMovements => 'Aquí aparecerá tu plata entrando y saliendo.';

  @override
  String get noMovementsBody =>
      'Registra un gasto, un ingreso o una transferencia con «Movimiento».';

  @override
  String get noResults => 'Nada coincide con la búsqueda.';

  @override
  String get deleteMovementTitle => '¿Eliminar este movimiento?';

  @override
  String get deleteTransferBody =>
      'Se eliminan las dos partes de la transferencia.';

  @override
  String get invalidAmount => 'Escribe un monto';

  @override
  String get sameAccount => 'Elige dos cuentas distintas';

  @override
  String get needAccountFirst => 'Primero agrega una cuenta.';

  @override
  String get recentMovements => 'Últimos movimientos';

  @override
  String get seeAll => 'Ver todos';

  @override
  String get scheduled => 'Programado';

  @override
  String get settingsProfile => 'Perfil';

  @override
  String get settingsName => 'Nombre';

  @override
  String get settingsBase => 'Moneda de los totales';

  @override
  String get settingsPay => 'Cómo te pagan';

  @override
  String get settingsData => 'Tus datos';

  @override
  String get exportData => 'Exportar mis datos';

  @override
  String get exportDone => 'Archivo guardado.';

  @override
  String get settingsPayAmount => 'Lo que te pagan';

  @override
  String get settingsPayAmountBody =>
      'Lo que te llega cada pago. Sirve para proyectar los días que vienen; no cuenta como plata hasta que llega.';

  @override
  String get settingsCushion => 'Colchón';

  @override
  String get settingsCushionBody =>
      'Lo que quieres guardar sin tocar. No cuenta en lo que puedes gastar hasta el pago.';

  @override
  String get settingsNotSet => 'Sin definir';

  @override
  String get settingsRemove => 'Quitar';

  @override
  String get freeExplainCushion => 'Colchón que guardas';

  @override
  String get freeExplainAssumptions => 'Lo que supone';

  @override
  String freeExplainAssumeToday(String payday) {
    return 'Cuenta lo que hay hoy en tus cuentas de uso diario y resta lo que vence hasta el $payday.';
  }

  @override
  String freeExplainAssumePay(String pay, String payday) {
    return 'Tu pago de $pay del $payday no cuenta hasta que llegue.';
  }

  @override
  String get freeExplainAssumeNoPay =>
      'No sabe cuánto te pagan. Si lo dices en Ajustes, la proyección lo tiene en cuenta.';

  @override
  String freeExplainAssumeCushion(String cushion) {
    return 'Deja por fuera $cushion de colchón.';
  }

  @override
  String get freeExplainAssumeNoCushion =>
      'No tiene colchón. Puedes elegir uno en Ajustes.';

  @override
  String payLate(String date) {
    return 'Tu pago del $date todavía no aparece. Si ya llegó, regístralo.';
  }

  @override
  String get accountExplainTitle => 'Así se llega al saldo';

  @override
  String get accountExplainOpening => 'Con lo que empezó';

  @override
  String get accountExplainBalance => 'Saldo hoy';

  @override
  String accountExplainAhead(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count movimientos con fecha más adelante ($amount) todavía no cuentan.',
      one: 'Un movimiento con fecha más adelante ($amount) todavía no cuenta.',
    );
    return '$_temp0';
  }

  @override
  String traceIncome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ingresos',
      one: 'Un ingreso',
    );
    return '$_temp0';
  }

  @override
  String traceExpense(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gastos',
      one: 'Un gasto',
    );
    return '$_temp0';
  }

  @override
  String traceTransferIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transferencias que entraron',
      one: 'Una transferencia que entró',
    );
    return '$_temp0';
  }

  @override
  String traceTransferOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transferencias que salieron',
      one: 'Una transferencia que salió',
    );
    return '$_temp0';
  }

  @override
  String traceBought(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count compras',
      one: 'Una compra',
    );
    return '$_temp0';
  }

  @override
  String traceSold(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ventas',
      one: 'Una venta',
    );
    return '$_temp0';
  }

  @override
  String traceAdjustment(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ajustes',
      one: 'Un ajuste',
    );
    return '$_temp0';
  }

  @override
  String get totalExplainTitle => 'Así se calcula tu patrimonio';

  @override
  String totalExplainUnpriced(String names) {
    return 'Sin tasa todavía, no suman: $names.';
  }

  @override
  String get computedOnPhone => 'Calculado en tu teléfono';

  @override
  String get computedTitle => 'Cómo se calculó';

  @override
  String computedFooter(String time) {
    return 'Cada cifra de la respuesta salió de estos cálculos, hechos en tu teléfono con tus datos de $time. Gemini solo los explica.';
  }

  @override
  String get computedOverview =>
      'Tus saldos, lo comprometido, el colchón y lo que puedes gastar hasta el pago';

  @override
  String computedMonth(String month) {
    return 'Gastos de $month por categoría, frente al mes anterior';
  }

  @override
  String computedCategory(String category, String month) {
    return 'Pagos de $category en $month';
  }

  @override
  String get computedTotals => 'Ingresos y gastos de los últimos meses';

  @override
  String get computedSubscriptions =>
      'Tus suscripciones y lo que cuestan al mes';

  @override
  String get computedGoal => 'Tu meta de ahorro y lo que falta';

  @override
  String get computedRecord => 'El gasto que se registró';

  @override
  String get computedAccounts => 'Tus cuentas, cada una en su moneda';

  @override
  String get computedPortfolio =>
      'Tu portafolio cripto con precios del mercado';

  @override
  String get computedSeeFree => 'Ver cómo se calcula lo que puedes gastar';

  @override
  String get comingTitle => 'Próximos 30 días';

  @override
  String comingLowest(String amount, String date) {
    return 'Saldo mínimo estimado antes del pago: $amount el $date';
  }

  @override
  String comingTight(String date) {
    return 'El $date quedarías bajo tu colchón.';
  }

  @override
  String get comingNoTight => 'Ningún día bajo tu colchón en estos 30 días.';

  @override
  String get comingNoTightZero => 'No te quedas sin plata en estos 30 días.';

  @override
  String get comingLegendSure => 'Lo seguro';

  @override
  String get comingLegendLikely => 'Con tu pago y lo que pruebas';

  @override
  String comingLegendCushion(String amount) {
    return 'Colchón de $amount';
  }

  @override
  String comingLeft(String amount) {
    return 'Quedan $amount';
  }

  @override
  String comingLeftTrying(String amount) {
    return 'con lo que pruebas, $amount';
  }

  @override
  String get comingUnderCushion => 'Bajo tu colchón';

  @override
  String get comingPay => 'Tu pago';

  @override
  String get comingLatePay => 'Tu pago atrasado';

  @override
  String get comingTryOut => 'Lo que pruebas';

  @override
  String get comingMove => 'Mover en la simulación';

  @override
  String get comingSimulation =>
      'Estás probando: nada de esto se guarda ni cambia tus pagos.';

  @override
  String get comingClearSimulation => 'Quitar lo que pruebas';

  @override
  String get comingNoEvents => 'Nada programado en estos días.';

  @override
  String get comingClose => 'Cierre de la quincena';

  @override
  String get buyTitle => '¿Me alcanza?';

  @override
  String get buyPrice => '¿Cuánto cuesta?';

  @override
  String get buyWhat => '¿Qué es? (opcional)';

  @override
  String get buyToday => 'Hoy';

  @override
  String get buyAfterPay => 'Después del pago';

  @override
  String get buyOther => 'Otra fecha';

  @override
  String get buyFits => 'Te alcanza, según lo que sabe la app';

  @override
  String buyFitsBody(String amount, String date) {
    return 'Tu saldo mínimo estimado sería $amount el $date, por encima de tu colchón.';
  }

  @override
  String buyFitsBodyNoCushion(String amount, String date) {
    return 'Tu saldo mínimo estimado sería $amount el $date.';
  }

  @override
  String get buyBelow => 'Quedarías por debajo de tu colchón';

  @override
  String buyBelowBody(String date, String amount, String cushion) {
    return 'El $date quedarías con $amount; tu colchón es $cushion.';
  }

  @override
  String get buyShort => 'No alcanza antes del pago';

  @override
  String buyShortBody(String date, String amount) {
    return 'El $date te faltarían $amount.';
  }

  @override
  String buyReliesOnPay(String amount, String date) {
    return 'Cuenta con tu pago de $amount del $date, que todavía no llega.';
  }

  @override
  String get buyPayUnknown =>
      'No sé cuánto te pagan, así que no lo cuento. Puedes decirlo en Ajustes.';

  @override
  String get buyEstimate =>
      'Es una estimación con lo que está programado, no una garantía.';

  @override
  String get buyCompareToday => 'Si compras hoy';

  @override
  String buyCompareAfter(String date) {
    return 'Si esperas al $date';
  }

  @override
  String buyLowest(String amount) {
    return 'saldo mínimo: $amount';
  }

  @override
  String get closeTitle => 'Cierre de la quincena';

  @override
  String closeRange(String from, String to) {
    return 'Del $from al $to';
  }

  @override
  String get closeChanged => 'Qué cambió';

  @override
  String get closeComing => 'Qué viene';

  @override
  String get closeAction => 'Una acción posible';

  @override
  String closeSpentMore(String spent, String difference) {
    return 'Gastaste $spent, $difference más que la quincena anterior.';
  }

  @override
  String closeSpentLess(String spent, String difference) {
    return 'Gastaste $spent, $difference menos que la quincena anterior.';
  }

  @override
  String closeSpentSame(String spent) {
    return 'Gastaste $spent, lo mismo que la quincena anterior.';
  }

  @override
  String closeSpentFirst(String spent) {
    return 'Gastaste $spent. Es tu primera quincena completa registrada: todavía no hay con qué compararla.';
  }

  @override
  String get closeNone =>
      'Todavía no hay una quincena completa registrada. El cierre aparece cuando haya una, de un pago al siguiente.';

  @override
  String closeComingTotal(String date, String amount) {
    return 'Hasta el $date hay $amount comprometidos.';
  }

  @override
  String closeComingNone(String date) {
    return 'No hay nada comprometido hasta el $date.';
  }

  @override
  String closeComingMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Y $count más.',
      one: 'Y uno más.',
    );
    return '$_temp0';
  }

  @override
  String closeFree(String amount) {
    return 'Puedes gastar hasta el pago: $amount';
  }

  @override
  String get closeSeeDays => 'Ver los próximos 30 días';

  @override
  String closeActionTight(String date) {
    return 'El $date quedarías bajo tu colchón. Mira qué cobro podrías mover de fecha.';
  }

  @override
  String closeActionCategory(String category, String before, String now) {
    return '$category pasó de $before a $now frente a la quincena anterior. Mira esos pagos.';
  }

  @override
  String closeActionGoal(String amount) {
    return 'Puedes gastar $amount hasta el pago. Si quieres, una parte puede ir a tu meta.';
  }

  @override
  String get closeActionNone => 'Nada que ajustar esta vez.';

  @override
  String get closeSeePayments => 'Ver los pagos';

  @override
  String closePaymentsTitle(String category, String from, String to) {
    return '$category del $from al $to';
  }

  @override
  String get homeComing => 'Próximos días';

  @override
  String get homeSeeDays => 'Ver 30 días';

  @override
  String get buyWithoutPay => 'sin contar tu pago';

  @override
  String get closeSpentNone => 'No registraste gastos en esta quincena.';

  @override
  String comingLowestWithout(String amount, String date) {
    return 'Sin lo que pruebas, saldo mínimo estimado antes del pago: $amount el $date';
  }

  @override
  String get computedBuy =>
      'Cómo quedaría tu plata con esa compra hasta el pago, hoy y después del pago';

  @override
  String get computedComing => 'Tu plata en los próximos 30 días, día por día';

  @override
  String get computedClose =>
      'El cierre de tu última quincena, frente a la anterior';

  @override
  String get remindersTitle => 'Avisos';

  @override
  String get remindersClose => 'Avisarme el día de pago';

  @override
  String get remindersCloseHelp =>
      'Un aviso sin montos para ver el cierre de la quincena. Nada de tu plata aparece en la pantalla bloqueada.';

  @override
  String get remindersDenied =>
      'Para los avisos, permite las notificaciones de Quincena en los ajustes del teléfono.';

  @override
  String get reminderTitle => 'Tu cierre de quincena está listo';

  @override
  String get reminderBody => 'Ábrelo para ver qué cambió y qué viene.';

  @override
  String get tabPlan => 'Plan';

  @override
  String get goalIncomplete => 'Ponle un nombre y cuánto quieres juntar.';

  @override
  String goalDeleteTitle(String name) {
    return '¿Borrar «$name»?';
  }

  @override
  String get goalDeleteBody =>
      'Se borra la meta. Tus cuentas y movimientos no cambian.';

  @override
  String get goalDelete => 'Borrar meta';

  @override
  String get goalAdd => 'Agregar meta';

  @override
  String get goalEdit => 'Editar meta';

  @override
  String get goalName => '¿Para qué es?';

  @override
  String get goalTarget => '¿Cuánto quieres juntar?';

  @override
  String get goalSaved => '¿Cuánto llevas?';

  @override
  String get goalMonthly => '¿Cuánto pones al mes?';

  @override
  String get goalNoDeadline => 'Sin fecha límite';

  @override
  String goalBy(String date) {
    return 'Para el $date';
  }

  @override
  String goalSavedOf(String saved, String target) {
    return 'Llevas $saved de $target';
  }

  @override
  String goalArrives(String date) {
    return 'llega en $date';
  }

  @override
  String get goalNoMonthly => 'sin aporte al mes, no tiene fecha';

  @override
  String get envelopeAside => 'Apartar para algo';

  @override
  String get envelopeAsideHint => 'Regalo, matrícula, viaje…';

  @override
  String get envelopesOverTitle => 'Asignas más de lo que hay';

  @override
  String envelopesOver(String amount) {
    return 'Los sobres suman $amount más de lo que tienes para repartir. Puedes guardarlos así, pero esa plata no existe todavía.';
  }

  @override
  String get envelopesFix => 'Ajustar';

  @override
  String get envelopesSaveAnyway => 'Guardar así';

  @override
  String get envelopesTitle => 'Reparte tu quincena';

  @override
  String envelopesPeriod(String from, String to) {
    return 'Del $from al $to.';
  }

  @override
  String get envelopesToSplit => 'Para repartir';

  @override
  String envelopesToSplitBody(String committed, String cushion) {
    return 'Lo que hay para gastar, menos $committed comprometidos hasta el pago y $cushion de colchón.';
  }

  @override
  String get envelopeDaily => 'Día a día';

  @override
  String get envelopeDailyHelp =>
      'Mercado, transporte, salidas: lo que se gasta hasta el pago.';

  @override
  String get envelopeGoalHelp =>
      'Apartado para tu meta: deja de contar en lo que puedes gastar.';

  @override
  String get envelopeAsideHelp =>
      'Apartado: deja de contar en lo que puedes gastar.';

  @override
  String get envelopeRemove => 'Quitar sobre';

  @override
  String get envelopesOverShort => 'Te pasas por';

  @override
  String get envelopesFree => 'Sin asignar';

  @override
  String get envelopesOnPaper =>
      'Los sobres no mueven plata: tu banco no se entera. Solo dicen qué parte de lo que tienes es para qué, y lo apartado sale de lo que puedes gastar hasta el pago.';

  @override
  String get envelopesSave => 'Guardar el reparto';

  @override
  String get cushionDaysTitle => 'Colchón en días';

  @override
  String cushionDaysCovers(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Cubre unos $days días de gastos esenciales',
      one: 'Cubre un día de gastos esenciales',
    );
    return '$_temp0';
  }

  @override
  String get cushionDaysNoReserve =>
      'Elige abajo las cuentas donde guardas tu fondo de emergencia.';

  @override
  String get cushionDaysShortHistory =>
      'Con menos de un mes de movimientos todavía no hay un promedio confiable. Vuelve en unas semanas.';

  @override
  String get cushionDaysNoEssential =>
      'No hay gastos en las categorías esenciales que elegiste, así que no se puede contar en días. Revisa las categorías.';

  @override
  String cushionDaysHow(String reserve, String daily, String from, String to) {
    return '$reserve entre $daily al día, lo que promediaron tus gastos esenciales del $from al $to.';
  }

  @override
  String cushionDaysReached(int days) {
    return 'Llegaste a los $days días que te propusiste.';
  }

  @override
  String cushionDaysToGo(int days, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Te faltan $days días: $amount.',
      one: 'Te falta un día: $amount.',
    );
    return '$_temp0';
  }

  @override
  String get cushionDaysEstimate =>
      'Es un promedio: un mes con gastos distintos cambia la cuenta.';

  @override
  String get cushionDaysAccounts => 'Dónde está tu colchón';

  @override
  String get cushionDaysEssentials => 'Qué es esencial para ti';

  @override
  String get cushionDaysTarget => 'Cuántos días quieres cubrir';

  @override
  String get cushionDaysNoTarget => 'Sin meta';

  @override
  String cushionDaysOption(int days) {
    return '$days días';
  }

  @override
  String get cushionDaysTargetNote =>
      'No hay una cifra correcta para todos: elige la que te dé tranquilidad.';

  @override
  String get wishesTitle => 'Lo quiero, pero después';

  @override
  String get wishAdd => 'Agregar deseo';

  @override
  String get wishesBody =>
      'Lo que quieres comprar más adelante, con el precio que tú pones. Nada se compra ni se sigue en ninguna tienda.';

  @override
  String get wishesEmpty => 'Todavía no hay deseos.';

  @override
  String get wishPriorityHigh => 'Muy deseado';

  @override
  String get wishPriorityMedium => 'Deseado';

  @override
  String get wishPriorityLow => 'Si sobra';

  @override
  String get wishRemove => 'Quitar deseo';

  @override
  String wishWaiting(String date) {
    return 'Esperas hasta el $date para decidir.';
  }

  @override
  String wishAgainstGoal(String goal, String after, String before) {
    return 'Si lo compras, $goal llegaría en $after en vez de $before.';
  }

  @override
  String get wishIncomplete => 'Ponle un nombre y un precio.';

  @override
  String get wishName => '¿Qué quieres?';

  @override
  String get wishPrice => '¿Cuánto cuesta?';

  @override
  String get wishWait => 'Esperar 30 días antes de decidir';

  @override
  String get wishWaitHelp =>
      'Si en un mes lo sigues queriendo, decides con calma.';

  @override
  String get whatIfTitle => '¿Y si…?';

  @override
  String get whatIfSaveMore => 'Ahorro más';

  @override
  String get whatIfChargeUp => 'Sube un gasto';

  @override
  String get whatIfPayLate => 'Pago tarde';

  @override
  String whatIfSaveMoreSaid(String amount) {
    return 'Apartar $amount más en cada pago';
  }

  @override
  String whatIfChargeUpSaid(String charge, String amount) {
    return '$charge sube $amount';
  }

  @override
  String whatIfPayLateSaid(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'El pago llega $days días tarde',
      one: 'El pago llega un día tarde',
    );
    return '$_temp0';
  }

  @override
  String get whatIfApplyTitle => '¿Aplicar el cambio?';

  @override
  String whatIfApplyCharge(String charge, String amount) {
    return '$charge quedará en $amount desde su próximo cobro. Lo ya registrado no cambia.';
  }

  @override
  String get whatIfApplySave => 'Esto cambia tu plan desde ahora.';

  @override
  String get whatIfApply => 'Aplicar';

  @override
  String get whatIfNoCharges =>
      'No tienes cobros programados en las próximas semanas.';

  @override
  String get whatIfSaveMoreAmount => '¿Cuánto más en cada pago?';

  @override
  String get whatIfChargeUpAmount => '¿Cuánto sube?';

  @override
  String get whatIfNeedsPay =>
      'Para probar un pago tarde, di en Ajustes cuánto te pagan.';

  @override
  String whatIfPayLateDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días tarde',
      one: 'Un día tarde',
    );
    return '$_temp0';
  }

  @override
  String get whatIfFewerDays => 'Menos días';

  @override
  String get whatIfMoreDays => 'Más días';

  @override
  String get whatIfLowest => 'Saldo mínimo en 45 días';

  @override
  String get whatIfTight => 'Primer día bajo tu colchón';

  @override
  String get whatIfNoTight => 'ninguno';

  @override
  String whatIfEnd(String date) {
    return 'Al $date';
  }

  @override
  String whatIfGoal(String goal) {
    return '$goal llega en';
  }

  @override
  String get whatIfGoalNever => 'sin fecha';

  @override
  String get whatIfAssumes =>
      'Cuenta tu pago esperado y lo programado; nada de esto cambia tus cuentas.';

  @override
  String get whatIfSave => 'Guardar el escenario';

  @override
  String get whatIfSaved => 'Escenarios guardados';

  @override
  String whatIfSavedOutcome(String amount, String date) {
    return 'Saldo mínimo: $amount el $date';
  }

  @override
  String get whatIfRemove => 'Quitar escenario';

  @override
  String get whatIfToday => 'Hoy';

  @override
  String get whatIfWith => 'Con el cambio';

  @override
  String planPeriod(String date) {
    return 'Presupuesto hasta el $date';
  }

  @override
  String get planGoals => 'Metas';

  @override
  String get planNoGoals =>
      'Todavía no tienes metas. Una meta con aporte al mes te dice cuándo llegas.';

  @override
  String get planTools => 'Herramientas';

  @override
  String get planCushionChoose => 'Elige dónde está tu fondo de emergencia';

  @override
  String get planCushionSoon => 'Todavía no se puede contar en días';

  @override
  String get planWishesNone => 'Guarda lo que quieres para después';

  @override
  String planWishes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deseos',
      one: 'Un deseo',
    );
    return '$_temp0';
  }

  @override
  String get planWhatIf => 'Prueba un cambio sin aplicarlo';

  @override
  String get planComing => 'Los días que vienen, con los apretados marcados';

  @override
  String get planSplitTitle => 'Reparte esta quincena';

  @override
  String planSplitBody(String amount) {
    return 'Tienes $amount para repartir entre el día a día, tus metas y lo que quieras apartar.';
  }

  @override
  String get planSplit => 'Repartir en sobres';

  @override
  String planDailySpent(String spent, String daily) {
    return 'Llevas $spent de $daily';
  }

  @override
  String planDailyOver(String amount) {
    return 'Te pasaste por $amount';
  }

  @override
  String get planAdjust => 'Ajustar el reparto';

  @override
  String get freeExplainSetAside => 'Apartado en sobres';

  @override
  String get paydayArrived => 'Te llegó la quincena';

  @override
  String get freeExplainAction => '¿De dónde sale?';

  @override
  String get freeExplainTitle => 'Así se calcula lo que puedes gastar';

  @override
  String get freeExplainSpendable => 'En tus cuentas de uso diario';

  @override
  String freeExplainCommitted(String date) {
    return 'Pagos hasta el $date';
  }

  @override
  String freeExplainNothingCommitted(String date) {
    return 'Nada programado hasta el $date.';
  }

  @override
  String get freeExplainLeftOut => 'No cuentan';

  @override
  String freeExplainLeftOutBody(String names) {
    return '$names: las marcaste como ahorro o inversión, no como plata para gastar. Puedes cambiarlo en cada cuenta.';
  }

  @override
  String freeExplainUnpriced(String codes) {
    return 'Sin tasa todavía, cuentan como cero: $codes.';
  }

  @override
  String get freeExplainEstimate =>
      'Es una estimación: cuenta lo que ya pasó y lo que está programado hasta el pago. Lo que gastes o recibas sin programarlo la cambia.';

  @override
  String freeExplainHeldAt(String held, String rate) {
    return '$held a $rate';
  }

  @override
  String get importData => 'Importar un archivo';

  @override
  String get importConfirmTitle => '¿Reemplazar todo con este archivo?';

  @override
  String get importConfirmBody =>
      'Lo que tienes ahora en Quincena se borra y queda lo del archivo.';

  @override
  String get importConfirm => 'Reemplazar';

  @override
  String get importDone => 'Datos importados.';

  @override
  String get importNotQuincena =>
      'Ese archivo no lo exportó Quincena. No se cambió nada.';

  @override
  String get importNewer =>
      'Ese archivo viene de una versión más nueva de Quincena. Actualiza la app y vuelve a intentarlo; no se cambió nada.';

  @override
  String get importDamaged =>
      'Ese archivo está dañado o incompleto. No se cambió nada.';

  @override
  String get deleteAll => 'Borrar todo';

  @override
  String get deleteAllTitle => '¿Borrar todos tus datos?';

  @override
  String get deleteAllBody =>
      'Cuentas, movimientos y ajustes se borran de este dispositivo. No se puede deshacer; exporta primero si quieres conservarlos.';

  @override
  String get useDemo => 'Ver los datos de ejemplo';

  @override
  String get useOwn => 'Usar con mis cuentas';

  @override
  String get backToOwn => 'Volver a mis cuentas';

  @override
  String get privacyTitle => 'Privacidad';

  @override
  String get privacyBody =>
      'Tus cuentas y movimientos se guardan solo en este dispositivo. Quincena no tiene un servidor con tus finanzas, no muestra publicidad y no vende tus datos. La política explica qué va a Gemini, a Binance o a las fuentes de precios, y cuándo.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get inboxTitle => 'Por revisar';

  @override
  String inboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Revisa $count movimientos para actualizar tu saldo',
      one: 'Revisa 1 movimiento para actualizar tu saldo',
    );
    return '$_temp0';
  }

  @override
  String inboxBannerBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aún no cuentan en lo que puedes gastar.',
      one: 'Aún no cuenta en lo que puedes gastar.',
    );
    return '$_temp0';
  }

  @override
  String get inboxEmpty => 'Todo al día.';

  @override
  String get inboxEmptyBody =>
      'No tienes movimientos pendientes. Cuando llegue un pago de tu banco, aparece aquí para confirmarlo.';

  @override
  String get confirm => 'Confirmar';

  @override
  String get edit => 'Editar';

  @override
  String get dismiss => 'Descartar';

  @override
  String dismissAndMute(String app) {
    return 'Descartar y no leer más $app';
  }

  @override
  String get chooseAccount => 'Elegir la cuenta';

  @override
  String get noMerchant => 'Sin comercio';

  @override
  String get sourceWallet => 'Apple Pay';

  @override
  String get sourceNotification => 'Notificación';

  @override
  String get sourceSms => 'SMS';

  @override
  String get sourceEmail => 'Correo';

  @override
  String get sourceScreenshot => 'Captura de pantalla';

  @override
  String get sourcePaste => 'Pegado';

  @override
  String nearbyPlace(String name, int metres) {
    return 'Cerca: $name, a $metres m · © colaboradores de OpenStreetMap';
  }

  @override
  String get possibleDuplicates => 'Posibles repetidos';

  @override
  String get duplicateLine => 'El mismo pago ya llegó por otra vía.';

  @override
  String get notDuplicate => 'No es repetido';

  @override
  String whyLabel(String reasons) {
    return 'Sugerido porque $reasons.';
  }

  @override
  String whyCard(String digits, String account) {
    return 'la tarjeta *$digits es de $account';
  }

  @override
  String whyInstitution(String institution, String account) {
    return 'las alertas de $institution van a $account';
  }

  @override
  String whyInstitutionSame(String institution) {
    return 'llegó de tu cuenta de $institution';
  }

  @override
  String whyCurrency(String asset) {
    return 'es tu única cuenta en $asset';
  }

  @override
  String whyOnly(String asset) {
    return 'es tu única cuenta de uso diario en $asset; revísala';
  }

  @override
  String whyLearned(String merchant) {
    return 'así registraste $merchant antes';
  }

  @override
  String whyMerchant(String merchant) {
    return 'reconocimos $merchant';
  }

  @override
  String get whyWords => 'el mensaje dice de qué es';

  @override
  String ruleLearnedMerchant(String merchant, String category) {
    return 'Desde ahora, «$merchant» va a $category.';
  }

  @override
  String ruleLearnedCard(String digits, String account) {
    return 'Desde ahora, la tarjeta *$digits va a $account.';
  }

  @override
  String ruleLearnedInstitution(String institution, String account) {
    return 'Desde ahora, lo de $institution va a $account.';
  }

  @override
  String ruleLearnedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Y $count reglas más.',
      one: 'Y una regla más.',
    );
    return '$_temp0';
  }

  @override
  String get ruleMissingAccount => 'una cuenta que ya no está';

  @override
  String ruleCardKey(String digits) {
    return 'Tarjeta *$digits';
  }

  @override
  String get rulesTitle => 'Reglas aprendidas';

  @override
  String get rulesBody =>
      'Se crean cuando confirmas algo en Por revisar. Una regla solo cambia lo que llegue después: lo ya registrado se queda como está.';

  @override
  String get rulesEmpty =>
      'Todavía no hay reglas. Aparecen cuando confirmas tus primeros movimientos.';

  @override
  String get rulesMerchants => 'Comercios';

  @override
  String get rulesCards => 'Tarjetas';

  @override
  String get rulesInstitutions => 'Bancos y billeteras';

  @override
  String rulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reglas',
      one: 'Una regla',
      zero: 'Ninguna todavía',
    );
    return '$_temp0';
  }

  @override
  String get ruleDelete => 'Borrar regla';

  @override
  String get ruleOn => 'Usar esta regla';

  @override
  String get ruleChooseCategory => '¿A qué categoría va?';

  @override
  String get ruleChooseAccount => '¿A qué cuenta va?';

  @override
  String get autoRecordedBody =>
      'Lo que la app registró sola en las últimas dos semanas. Si algo no va, deshazlo y vuelve a Por revisar.';

  @override
  String get fixMovement => 'Corregir';

  @override
  String get recordedAutomatically => 'Registrado automáticamente';

  @override
  String get undo => 'Deshacer';

  @override
  String get pasteMessage => 'Pegar un mensaje';

  @override
  String get pasteHint => 'Pega aquí el mensaje o la notificación del banco';

  @override
  String get pasteRead => 'Leer';

  @override
  String get pasteAdded => 'Quedó en Por revisar.';

  @override
  String get pasteRecorded => 'Quedó registrado.';

  @override
  String get pasteNothing => 'No encontré un pago en ese texto.';

  @override
  String get pasteDuplicate => 'Ese pago ya estaba.';

  @override
  String get readScreenshot => 'Leer una captura';

  @override
  String get pickImages => 'Capturas o fotos';

  @override
  String get pickPdf => 'Un PDF';

  @override
  String get readingImages => 'Leyendo…';

  @override
  String readFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Leí $count pagos. Quedaron en Por revisar.',
      one: 'Leí un pago. Quedó en Por revisar.',
    );
    return '$_temp0';
  }

  @override
  String get readNothing =>
      'No encontré un monto con su moneda. Prueba con una captura donde se vea el valor.';

  @override
  String get showOriginal => 'Ver el mensaje';

  @override
  String get captureTitle => 'Captura automática';

  @override
  String get captureSubtitle =>
      'Pagos que llegan solos desde tus notificaciones y mensajes';

  @override
  String get captureAuto => 'Registrar solo lo que esté claro';

  @override
  String get captureAutoHelp =>
      'Cuando la cuenta, la categoría y el monto son seguros y no es un repetido, se registra sin preguntarte. Lo demás espera en Por revisar.';

  @override
  String get captureLocation => 'Usar la ubicación del pago';

  @override
  String get captureLocationHelp =>
      'Cuando la alerta no dice dónde fue, Quincena busca los comercios a unos metros de donde estaba el teléfono. La ubicación se guarda solo aquí; para buscar los comercios se envían únicamente las coordenadas a OpenStreetMap, a través de Photon. Los datos de los comercios son © colaboradores de OpenStreetMap, con licencia ODbL.';

  @override
  String get captureLocationDenied =>
      'Quincena no tiene permiso para usar la ubicación. Puedes darlo en los ajustes del teléfono.';

  @override
  String get openPhoneSettings => 'Abrir ajustes';

  @override
  String get captureAlwaysTitle => 'Ubicación con la app cerrada';

  @override
  String get captureAlwaysBody =>
      'Quincena recoge datos de ubicación para sugerir el comercio de un pago, incluso cuando la app está cerrada o no se usa. Solo mira la ubicación cuando llega una notificación de pago, la guarda en este teléfono y, para encontrar el comercio, envía únicamente las coordenadas a OpenStreetMap a través de Photon. Android te pedirá elegir «Permitir todo el tiempo».';

  @override
  String get captureLocationOnlyOpen =>
      'Por ahora solo con la app abierta. Elige «Permitir todo el tiempo» para los pagos que llegan con la app cerrada.';

  @override
  String get captureAllowAlways => 'Permitir todo el tiempo';

  @override
  String get notNow => 'Ahora no';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get captureImagesTitle => 'Capturas y comprobantes';

  @override
  String get captureImagesIos =>
      'En Por revisar puedes elegir una captura, una foto o un PDF de un pago, y Quincena lo lee en el teléfono.\nPara mandarlos desde otras apps, crea un atajo con la acción «Leer comprobante» de Quincena y actívale «Mostrar en la hoja de compartir».\nCon «Hacer captura de pantalla» antes y Toque posterior (Ajustes, Accesibilidad, Tocar), lees lo que tengas en pantalla con dos toques en la parte de atrás del iPhone.';

  @override
  String get captureImagesAndroid =>
      'Comparte con Quincena una captura, una foto, un PDF o un texto desde cualquier app, o elígelos en Por revisar. Se leen en el teléfono y quedan para que los confirmes.';

  @override
  String get captureImagesDesktop =>
      'Elige en Por revisar una captura, una foto o un PDF de un pago, y Quincena lo lee en este computador.';

  @override
  String get captureIosTitle => 'En iPhone, con Atajos';

  @override
  String get captureIosSteps =>
      '1. Abre Atajos y ve a Automatización.\n2. Crea una nueva con Wallet y elige tus tarjetas.\n3. Si quieres usar la ubicación, agrega «Obtener ubicación actual». Luego agrega la acción «Registrar movimiento» de Quincena, elige Apple Pay como origen y pásale el monto, el comercio y la tarjeta.\n4. Elige «Ejecutar inmediatamente».\nPara los SMS del banco, crea la automatización Mensaje con el remitente del banco, usa la misma acción con Mensaje como origen y pásale el mensaje como texto. Desde iOS 27, la automatización Notificación hace lo mismo con las apps de tus bancos.';

  @override
  String get captureOpenShortcuts => 'Abrir Atajos';

  @override
  String get captureIosReady =>
      'Añade los que quieras. Llegan apagados: en Atajos, abre cada uno, toca Editar, despliega el primer bloque y activa «Automatización».';

  @override
  String get captureIos26Steps =>
      '1. Añade el atajo de lo que quieras capturar.\n2. Abre Atajos y ve a Automatización.\n3. Crea una con Wallet y elige tus tarjetas, o con Mensaje y el remitente de tu banco.\n4. Elige el atajo de Quincena que añadiste y «Ejecutar inmediatamente».';

  @override
  String get captureAdd => 'Añadir';

  @override
  String get readyBankNotifications => 'Notificaciones de tus bancos';

  @override
  String get readyBankNotificationsHelp =>
      'Bancolombia, Nequi y los demás, apenas llegan. Al añadirlo, revisa que estén las apps de tus bancos.';

  @override
  String get readyBankMessages => 'SMS de tu banco';

  @override
  String get readyBankMessagesHelp =>
      'Los mensajes de compras y transferencias que traen un valor con \$.';

  @override
  String get readyApplePay => 'Pagos con Apple Pay';

  @override
  String get readyApplePayHelp => 'Cada compra que pagas con el iPhone.';

  @override
  String get readyScreenshots => 'Capturas de comprobantes';

  @override
  String get readyScreenshotsHelp =>
      'Si la captura muestra un valor con \$, la lee en el teléfono y la deja por revisar.';

  @override
  String get captureAndroidTitle => 'En Android, con tus notificaciones';

  @override
  String get captureAndroidBody =>
      'Quincena lee las notificaciones que parecen pagos y deja pasar el resto sin guardarlo. Los códigos de verificación nunca se guardan.';

  @override
  String get captureAndroidGranted => 'Acceso a notificaciones activado';

  @override
  String get captureAndroidGrant => 'Permitir acceso a notificaciones';

  @override
  String get captureOtherTitle => 'En este dispositivo';

  @override
  String get captureOtherBody =>
      'La captura automática funciona en el teléfono. Aquí puedes pegar un mensaje del banco.';

  @override
  String get mutedApps => 'Apps que no se leen';

  @override
  String get unmute => 'Volver a leer';

  @override
  String learnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ya reconoce $count comercios.',
      one: 'Ya reconoce un comercio.',
      zero: 'Aún no ha aprendido comercios.',
    );
    return '$_temp0';
  }

  @override
  String get portfolioTitle => 'Cripto';

  @override
  String get portfolioWorth => 'Tu cripto vale';

  @override
  String get portfolioToday => 'En 24 horas';

  @override
  String get portfolioGain => 'Ganancia no realizada';

  @override
  String get portfolioLoss => 'Pérdida no realizada';

  @override
  String get portfolioSinceBought => 'sobre lo que pagaste';

  @override
  String portfolioPricedAt(String when) {
    return 'Precios de Binance del $when';
  }

  @override
  String get portfolioPricing => 'Leyendo precios…';

  @override
  String get portfolioPricingFailed =>
      'No se pudieron leer los precios: se muestran los últimos guardados.';

  @override
  String get portfolioNeverPriced => 'Aún sin precios: se leen al conectarse.';

  @override
  String get rangeDay => '24 h';

  @override
  String get rangeWeek => '7 d';

  @override
  String get rangeMonth => '30 d';

  @override
  String get rangeYear => '1 a';

  @override
  String get rangeDayLong => 'en 24 horas';

  @override
  String get rangeWeekLong => 'en 7 días';

  @override
  String get rangeMonthLong => 'en 30 días';

  @override
  String get rangeYearLong => 'en un año';

  @override
  String get chartEmpty => 'Aún no hay precios para dibujar.';

  @override
  String get chartWithHoldings =>
      'El valor con lo que tenías en cada momento: una compra lo sube de golpe.';

  @override
  String get portfolioAllocation => 'Distribución';

  @override
  String get portfolioOtherPlace => 'Otras';

  @override
  String get portfolioOtherAssets => 'Otras';

  @override
  String portfolioRealized(String amount) {
    return 'Ya ganado en ventas y conversiones: $amount';
  }

  @override
  String portfolioRealizedLoss(String amount) {
    return 'Ya perdido en ventas y conversiones: $amount';
  }

  @override
  String portfolioUncosted(String amount) {
    return '$amount llegaron sin precio de compra y no cuentan en la ganancia. Puedes poner lo que costaron en su cuenta.';
  }

  @override
  String portfolioUnpriced(String assets) {
    return 'Binance no tiene precio para $assets: no suman al total.';
  }

  @override
  String get portfolioDisclaimer =>
      'Precios de mercado de Binance, que cambian a cada momento. Quincena no da asesoría de inversión.';

  @override
  String get portfolioOpen => 'Ver cripto';

  @override
  String get portfolioEmpty =>
      'Aún no tienes cripto. Agrega una billetera o conecta Binance.';

  @override
  String get holdingQuantity => 'Tienes';

  @override
  String get holdingPrice => 'Precio';

  @override
  String get holdingWorth => 'Vale';

  @override
  String get holdingCost => 'Te costó';

  @override
  String get holdingAverage => 'Costo promedio';

  @override
  String get holdingNoCost => 'Sin costo';

  @override
  String get holdingNoCostHelp =>
      'Pon lo que te costó al editar la cuenta, o registra tus compras.';

  @override
  String get tradeBuy => 'Registrar compra';

  @override
  String get tradeSell => 'Registrar venta';

  @override
  String get tradeBought => 'Compra';

  @override
  String get tradeSold => 'Venta';

  @override
  String tradeQuantity(String code) {
    return 'Cantidad de $code';
  }

  @override
  String get tradePaid => 'Total pagado';

  @override
  String get tradeReceived => 'Total recibido';

  @override
  String get tradePaidFrom => 'Pagado desde';

  @override
  String get tradeReceivedIn => 'Recibido en';

  @override
  String get tradeOutside => 'Fuera de Quincena';

  @override
  String get tradeOutsideHelp =>
      'En Binance P2P, en otro exchange o en efectivo. Si sale de una de tus cuentas, elígela y su saldo también cambia.';

  @override
  String get tradeCurrency => 'Moneda';

  @override
  String tradePriceEach(String price) {
    return 'Precio por unidad: $price';
  }

  @override
  String tradeNotEnough(String amount) {
    return 'Esa cuenta tiene $amount.';
  }

  @override
  String get accountOpeningCost => '¿Cuánto te costó?';

  @override
  String get accountOpeningCostHelp =>
      'Opcional. Lo que pagaste por ese saldo; con esto Quincena calcula cuánto has ganado.';

  @override
  String get binanceTitle => 'Binance';

  @override
  String get binanceCardTitle => 'Conecta Binance';

  @override
  String get binanceCardBody =>
      'Quincena solo podrá consultar tu cuenta: nunca podrá mover tus fondos.';

  @override
  String get binanceConnectTitle => 'Tu cuenta de Binance, sola';

  @override
  String get binanceConnectBody =>
      'Quincena trae tus saldos de spot, fondos y Earn, tus compras y ventas en P2P, tus conversiones, compras en el mercado, depósitos y retiros, y con eso calcula cuánto te costó cada moneda.';

  @override
  String get binanceReadOnlyTitle => 'Solo lectura';

  @override
  String get binanceReadOnlyBody =>
      'La llave solo puede leer: no puede comprar, vender, mover ni retirar nada. Si puede hacer algo más, Quincena no la acepta.';

  @override
  String get binanceKeyStoredTitle => 'Solo en este dispositivo';

  @override
  String get binanceKeyStoredBody =>
      'La llave se guarda en el llavero del dispositivo y solo se usa para hablar con Binance. No va a Gemini, ni a la copia que exportas, ni a ningún servidor de Quincena.';

  @override
  String get binanceStepsTitle => 'Cómo crear la llave';

  @override
  String get binanceSteps =>
      '1. En la app de Binance, abre tu perfil y entra a Gestión de API.\n2. Crea una API generada por el sistema y llámala Quincena.\n3. Deja marcado solo «Habilitar lectura». Como el teléfono no tiene una IP fija, elige sin restricción de IP: con solo lectura no hay riesgo de que muevan tu plata.\n4. Copia la API Key y la Secret Key y pégalas aquí.';

  @override
  String get binanceApiKey => 'API Key';

  @override
  String get binanceSecretKey => 'Secret Key';

  @override
  String get binanceConnect => 'Conectar';

  @override
  String get binanceConnecting => 'Revisando la llave con Binance…';

  @override
  String binanceNotReadOnly(String what) {
    return 'Esta llave puede hacer más que leer ($what). Crea una que solo tenga «Habilitar lectura»; esta no se guardó.';
  }

  @override
  String get binanceBadKey =>
      'Binance no reconoce esa llave. Revisa que copiaste las dos completas, o que no la hayas borrado.';

  @override
  String get binanceOffline =>
      'No se pudo hablar con Binance. Revisa tu conexión e intenta de nuevo.';

  @override
  String get binanceLimited =>
      'Binance pidió esperar un momento. Intenta en un minuto.';

  @override
  String get binanceFailed =>
      'Algo salió mal al leer Binance. Intenta de nuevo.';

  @override
  String get binanceConnected => 'Conectada con una llave de solo lectura';

  @override
  String binanceSyncedAt(String when) {
    return 'Leída $when';
  }

  @override
  String get binanceNeverSynced => 'Aún sin leer';

  @override
  String get binanceSyncNow => 'Leer ahora';

  @override
  String get binanceSyncing => 'Leyendo tu cuenta de Binance…';

  @override
  String binanceReport(int movements) {
    String _temp0 = intl.Intl.pluralLogic(
      movements,
      locale: localeName,
      other: '$movements movimientos nuevos',
      one: 'un movimiento nuevo',
      zero: 'nada nuevo',
    );
    return 'Listo: $_temp0.';
  }

  @override
  String get binanceDisconnect => 'Desconectar';

  @override
  String get binanceDisconnectTitle => '¿Desconectar Binance?';

  @override
  String get binanceDisconnectBody =>
      'Se borra la llave de este dispositivo. Las cuentas y los movimientos que trajo se quedan como tuyos.';

  @override
  String get binanceWebOnly =>
      'En la web, Binance no deja que una página se conecte a tu cuenta. Conéctala desde la app del teléfono o del computador.';

  @override
  String binanceManualAccounts(String names) {
    return 'También tienes cuentas de Binance que llevabas a mano: $names. Archívalas para no contar lo mismo dos veces.';
  }

  @override
  String get binanceArchive => 'Archivarlas';

  @override
  String get binanceLabelP2p => 'Binance P2P';

  @override
  String get binanceLabelConversion => 'Conversión en Binance';

  @override
  String get binanceLabelDeposit => 'Depósito a Binance';

  @override
  String get binanceLabelWithdrawal => 'Retiro de Binance';

  @override
  String get binanceLabelFee => 'Comisión de Binance';

  @override
  String get binanceLabelAdjustment => 'Ajuste con Binance';

  @override
  String get statementTitle => 'Importar extracto';

  @override
  String get statementSubtitle => 'CSV, Excel o PDF de tu banco';

  @override
  String get statementIntro =>
      'Trae los movimientos de un extracto de tu banco o tarjeta: CSV, Excel (.xlsx) o PDF. Se lee en este dispositivo, y revisas cada movimiento antes de guardarlo.';

  @override
  String get statementPick => 'Elegir archivo';

  @override
  String get statementReading => 'Leyendo el extracto…';

  @override
  String get statementNothing => 'No encontré movimientos en este archivo.';

  @override
  String get statementFailed =>
      'No se pudo leer el archivo. Prueba con un CSV, un Excel (.xlsx) o un PDF.';

  @override
  String get statementGemini => 'Leer con Gemini';

  @override
  String get statementGeminiNote =>
      'Se envía a Gemini el texto del extracto, con sus fechas, descripciones y montos, para que lo ordene. Cuenta como una pregunta del día.';

  @override
  String get statementGeminiPdf =>
      'En la web el PDF no se puede leer aquí: se envía el archivo a Gemini para que lo lea. Cuenta como una pregunta del día.';

  @override
  String statementSummary(int count, String range) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimientos',
      one: 'Un movimiento',
    );
    return '$_temp0 · $range';
  }

  @override
  String get statementRecorded => 'Ya registrado';

  @override
  String get statementImportedBefore => 'Ya importado';

  @override
  String get statementFlip => 'Invertir entradas y salidas';

  @override
  String statementImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importar $count movimientos',
      one: 'Importar un movimiento',
      zero: 'Nada para importar',
    );
    return '$_temp0';
  }

  @override
  String statementDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se importaron $count movimientos.',
      one: 'Se importó un movimiento.',
    );
    return '$_temp0';
  }

  @override
  String get statementByGemini =>
      'Leído por Gemini: revisa bien antes de importar.';

  @override
  String get walletsTitle => 'Billeteras propias';

  @override
  String get walletsCardBody =>
      'Ledger, MetaMask, Trust Wallet: por su dirección pública.';

  @override
  String get walletsBody =>
      'Sigue lo que tienes en Ledger, MetaMask, Trust Wallet o cualquier billetera, con su dirección pública. Solo se lee: con una dirección nadie puede mover nada.';

  @override
  String get walletsChains =>
      'Bitcoin, Ethereum (ETH, USDT y USDC) y TRON (TRX, USDT y USDC).';

  @override
  String get walletsPrivacy =>
      'La dirección se consulta en servicios públicos: mempool.space, un nodo público de Ethereum y TronGrid. Ellos ven la dirección, no quién eres.';

  @override
  String get walletsAdd => 'Agregar billetera';

  @override
  String get walletsAddress => 'Dirección pública';

  @override
  String get walletsLabel => 'Nombre: Ledger, MetaMask…';

  @override
  String walletsBadAddress(String chain) {
    return 'Esa no parece una dirección de $chain.';
  }

  @override
  String get walletsUnreadable =>
      'No se pudo leer esa dirección. Revisa tu conexión e intenta de nuevo.';

  @override
  String get walletsRemove => 'Dejar de seguir';

  @override
  String get walletsRemoveBody =>
      'Ya no se lee. Las cuentas que trajo se quedan como tuyas.';

  @override
  String walletsSyncedAt(String when) {
    return 'Leídas $when';
  }

  @override
  String get walletsEmpty => 'Aún no sigues ninguna billetera.';

  @override
  String get walletsAdjustment => 'Ajuste con la billetera';

  @override
  String get walletsFailed =>
      'Una billetera no se pudo leer; se muestran sus últimos saldos.';

  @override
  String get chartWithoutTrades =>
      'Por el precio, sin contar lo que compraste o vendiste en esos días.';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get supportTitle => 'Soporte';

  @override
  String get cadencePerMonth => 'al mes';

  @override
  String get cadencePerTwoWeeks => 'cada dos semanas';

  @override
  String get cadencePerWeek => 'a la semana';

  @override
  String get cadencePerYear => 'al año';

  @override
  String get cadenceMonthly => 'Cada mes';

  @override
  String get cadenceBiweekly => 'Cada dos semanas';

  @override
  String get cadenceWeekly => 'Cada semana';

  @override
  String get cadenceYearly => 'Cada año';

  @override
  String get chargeAdd => 'Agregar pago fijo';

  @override
  String get chargeEdit => 'Pago fijo';

  @override
  String get chargePausedNote => 'En pausa: no se cuenta como comprometido.';

  @override
  String get chargeName => '¿Qué es?';

  @override
  String get chargeAmount => '¿Cuánto cobra?';

  @override
  String chargeUseLast(String amount, String date) {
    return 'El último cobro fue $amount, el $date: usar ese valor';
  }

  @override
  String get chargeCadence => 'Cada cuánto';

  @override
  String chargeNext(String date) {
    return 'Próximo cobro: $date';
  }

  @override
  String get chargeAccount => 'Se paga desde';

  @override
  String get chargeNoAccount => 'Ninguna cuenta en particular';

  @override
  String get chargeRemind => 'Avisarme antes de cada cobro';

  @override
  String get remindNever => 'No avisarme';

  @override
  String get remindSameDay => 'El mismo día';

  @override
  String get remindDayBefore => 'Un día antes';

  @override
  String remindDaysBefore(int days) {
    return '$days días antes';
  }

  @override
  String get remindWeekBefore => 'Una semana antes';

  @override
  String get chargeSubscription => 'Suscripción';

  @override
  String get chargeTrialAsk => '¿Está en prueba gratis?';

  @override
  String chargeTrialUntil(String date) {
    return 'Prueba gratis hasta el $date';
  }

  @override
  String get chargeTrialClear => 'Quitar la prueba gratis';

  @override
  String get chargeTrialNote =>
      'Te avisamos el día antes de que empiece a cobrar.';

  @override
  String get chargeInUseAsk => '¿La sigues usando?';

  @override
  String get chargeInUseYes => 'Sí, la uso';

  @override
  String get chargeInUseNo => 'Ya no la uso';

  @override
  String get chargeInUseNote =>
      'Un cobro que se repite no dice si la usas: eso solo lo sabes tú.';

  @override
  String chargeYearly(String amount) {
    return 'Al año son $amount.';
  }

  @override
  String chargeSaving(String amount) {
    return 'Si la pausas, te ahorras $amount al año. Quincena no la cancela: hazlo en la app o en la página del servicio.';
  }

  @override
  String get chargeIncomplete => 'Falta el nombre o el valor.';

  @override
  String get chargeRemindDenied =>
      'Sin permiso para avisarte. Si quieres el aviso, activa las notificaciones de Quincena en los ajustes del teléfono.';

  @override
  String get chargePause => 'Pausar';

  @override
  String get chargeResume => 'Reanudar';

  @override
  String get chargePauseNote =>
      'Pausar aquí solo deja de contarlo como comprometido. Para que deje de cobrarte, cancélalo con el servicio.';

  @override
  String get chargeDelete => 'Borrar pago fijo';

  @override
  String chargeDeleteTitle(String name) {
    return '¿Borrar $name?';
  }

  @override
  String get chargeDeleteBody =>
      'Deja de contarse como comprometido. Los cobros que ya registraste se quedan.';

  @override
  String get fixedTitle => 'Pagos fijos';

  @override
  String get fixedBody =>
      'Lo que se cobra solo cada mes o cada año: suscripciones, arriendo, servicios. Quincena lo cuenta como comprometido antes de que llegue.';

  @override
  String get fixedEmpty =>
      'Aún no tienes pagos fijos. Agrega el arriendo, el internet o una suscripción para verlos venir.';

  @override
  String get fixedNext30 => 'En los próximos 30 días';

  @override
  String get fixedSubscriptionsYear => 'Suscripciones al año';

  @override
  String get guessTitle => 'Parecen pagos fijos';

  @override
  String guessEvidence(int count, String amount, String dates) {
    return '$count cobros parecidos, el último de $amount: $dates';
  }

  @override
  String get guessAdd => 'Agregar como pago fijo';

  @override
  String get guessNot => 'No es fijo';

  @override
  String get fixedSubscriptions => 'Suscripciones';

  @override
  String get fixedOthers => 'Otros pagos fijos';

  @override
  String get fixedPausedTitle => 'En pausa';

  @override
  String get fixedNote =>
      'Quincena no paga ni cancela nada: eso se hace con tu banco o con cada servicio.';

  @override
  String fixedNextOn(String date) {
    return 'próximo cobro el $date';
  }

  @override
  String get fixedPaused => 'en pausa';

  @override
  String fixedTrial(String date) {
    return 'Prueba gratis hasta el $date';
  }

  @override
  String fixedNotUsed(String amount) {
    return 'Dijiste que ya no la usas: pausarla te ahorra $amount al año';
  }

  @override
  String fixedPriceUp(String from, String to, String date) {
    return 'Subió de $from a $to el $date';
  }

  @override
  String fixedPriceDown(String from, String to, String date) {
    return 'Bajó de $from a $to el $date';
  }

  @override
  String fixedFollowLast(String amount) {
    return 'Actualizar a $amount, como el último cobro';
  }

  @override
  String get fixedReminds => 'Con aviso';

  @override
  String get instalTitle => 'Compras a cuotas';

  @override
  String get instalAdd => 'Agregar compra a cuotas';

  @override
  String get instalEdit => 'Editar compra a cuotas';

  @override
  String get instalBody =>
      'Lo que compraste a cuotas, con los datos que te dio el banco o la tienda. Lo que no sepas queda como estimado, nunca como definitivo.';

  @override
  String get instalEmpty => 'Aún no registras compras a cuotas.';

  @override
  String get instalCardNote =>
      'Si compraste con una tarjeta que tienes en Quincena, la compra cuenta una sola vez, el día que la hiciste. Pagar la tarjeta es mover plata entre tus cuentas, no un gasto nuevo.';

  @override
  String get instalOwed => 'Te falta pagar';

  @override
  String get instalOwedKnown => 'Con los datos que diste.';

  @override
  String get instalOwedEstimated => 'Estimado: falta algún dato del banco.';

  @override
  String instalOwedUnknown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count compras no tienen datos para calcular.',
      one: 'Una compra no tiene datos para calcular.',
    );
    return '$_temp0';
  }

  @override
  String get instalList => 'Tus compras';

  @override
  String get instalNoData => 'Falta la tasa o el valor de la cuota';

  @override
  String get instalPaidOff => 'Pagada';

  @override
  String instalNextRow(int number, int count, String date) {
    return 'Cuota $number de $count: $date';
  }

  @override
  String get instalEstimated => 'estimado';

  @override
  String get instalUnknown => 'Sin datos';

  @override
  String get instalTotalUnknown =>
      'Sin la tasa ni el valor de la cuota no se puede calcular el total.';

  @override
  String instalTotalKnown(String amount) {
    return 'En total pagarás $amount, con los datos que diste.';
  }

  @override
  String instalTotalEstimated(String amount) {
    return 'En total pagarás unos $amount: es un estimado, porque falta la cuota de manejo o el seguro.';
  }

  @override
  String instalVsCash(String cash, String extra) {
    return 'De contado costaba $cash: a cuotas pagas $extra más.';
  }

  @override
  String instalVsCashAtLeast(String cash, String extra) {
    return 'De contado costaba $cash: a cuotas pagas al menos $extra más.';
  }

  @override
  String instalVsCashSame(String cash) {
    return 'De contado costaba $cash: a cuotas no pagas más.';
  }

  @override
  String instalProgress(int covered, int count) {
    return 'Llevas $covered de $count cuotas';
  }

  @override
  String instalOwing(int number, String amount) {
    return 'A la cuota $number le faltan $amount.';
  }

  @override
  String instalLate(int number, String date) {
    return 'La cuota $number era el $date. Si ya la pagaste, regístrala para llevar la cuenta.';
  }

  @override
  String get instalPay => 'Registrar un pago';

  @override
  String get instalFacts => 'Lo que dijo el banco';

  @override
  String get instalFinanced => 'Valor financiado';

  @override
  String get instalCount => 'Cuotas';

  @override
  String get instalRate => 'Tasa';

  @override
  String instalRateValue(String rate, String kind, String monthly) {
    return '$rate $kind ($monthly al mes)';
  }

  @override
  String get instalNotKnown => 'No la sabes';

  @override
  String get instalPayment => 'Cuota';

  @override
  String instalPaymentStated(String amount) {
    return '$amount, la que dijo el banco';
  }

  @override
  String instalPaymentWorked(String amount) {
    return '$amount, calculada con la tasa';
  }

  @override
  String get instalFee => 'Cuota de manejo o seguro';

  @override
  String get instalNoFee => 'No tiene';

  @override
  String get instalPaysFrom => 'Con qué la pagas';

  @override
  String get instalOutside => 'Fuera de Quincena: tienda o crédito';

  @override
  String get instalCountedOnce =>
      'La compra ya está en esa cuenta: sus cuotas no se suman otra vez a lo comprometido.';

  @override
  String get instalCountedAsComing =>
      'Las cuotas que vienen se cuentan como comprometidas.';

  @override
  String get instalPayments => 'Pagos';

  @override
  String get instalNoPayments => 'Aún no registras pagos.';

  @override
  String get instalPaymentRemove => 'Quitar este pago';

  @override
  String get instalSchedule => 'Calendario de cuotas';

  @override
  String get instalNoSchedule =>
      'Con la tasa o el valor de la cuota se arma el calendario.';

  @override
  String instalRow(int number, String date) {
    return 'Cuota $number · $date';
  }

  @override
  String instalRowSplit(String interest, String principal, String balance) {
    return 'Interés $interest · capital $principal · quedan $balance';
  }

  @override
  String instalRowLeft(String balance) {
    return 'Quedan $balance';
  }

  @override
  String get instalRowPaid => 'Pagada';

  @override
  String get instalPaymentAmount => 'Valor pagado';

  @override
  String get instalPaymentInvalid => 'Escribe cuánto pagaste.';

  @override
  String get instalPaymentPartial =>
      'Puede ser menos que la cuota: lo que falte queda pendiente.';

  @override
  String get instalDelete => 'Borrar compra';

  @override
  String instalDeleteTitle(String name) {
    return '¿Borrar $name?';
  }

  @override
  String get instalDeleteBody =>
      'Se borran sus datos y pagos aquí. Tus movimientos no se tocan.';

  @override
  String get instalSheetBody =>
      'Copia los datos del extracto o del contrato. Lo que no sepas, déjalo vacío.';

  @override
  String get instalName => '¿Qué compraste?';

  @override
  String get instalPrincipal => 'Valor financiado';

  @override
  String get instalCountField => 'Número de cuotas';

  @override
  String instalFirstDue(String date) {
    return 'Primera cuota: $date';
  }

  @override
  String get instalRateField => 'Tasa de interés';

  @override
  String get instalRateKind => 'Cómo la dicen';

  @override
  String get instalRateHelp =>
      'Como aparece en el extracto: efectiva anual (E.A.), nominal mes vencido (M.V.) o mensual. Una tasa de 0 también es un dato: sin interés.';

  @override
  String get rateEffectiveAnnual => 'E.A.';

  @override
  String get rateNominalMonthly => 'M.V.';

  @override
  String get rateMonthly => 'mensual';

  @override
  String get instalStated => 'Valor de la cuota, si te lo dieron';

  @override
  String get instalStatedHelp =>
      'Sin la cuota de manejo. Si no lo sabes, se calcula con la tasa.';

  @override
  String get instalFeeField => 'Cuota de manejo o seguro, por cuota';

  @override
  String get instalFeeHelp =>
      'Escribe 0 si no tiene. Si no lo sabes, déjalo vacío: el total quedará como estimado.';

  @override
  String get instalCash => 'Precio de contado';

  @override
  String get instalCashHelp => 'Para comparar cuánto cuesta pagar a cuotas.';

  @override
  String get instalIncomplete =>
      'Falta el nombre, el valor financiado o el número de cuotas.';

  @override
  String get detectiveTitle => 'Cargos para revisar';

  @override
  String get detectiveBody =>
      'Quincena mira tus movimientos de los últimos 60 días, aquí en el teléfono, y te muestra lo que vale la pena revisar, con la evidencia. Nunca borra un movimiento ni dice que algo sea fraude.';

  @override
  String get detectiveEmpty => 'Nada para revisar por ahora.';

  @override
  String get detectiveOpen => 'Para revisar';

  @override
  String get detectiveReviewing => 'Lo vas a revisar';

  @override
  String detectiveShowPutAway(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ver las $count que marcaste',
      one: 'Ver la que marcaste',
    );
    return '$_temp0';
  }

  @override
  String get detectiveHidePutAway => 'Ocultar las que marcaste';

  @override
  String get detectiveWhat => 'Qué revisar';

  @override
  String get detectiveKindTwice => 'Pagos repetidos';

  @override
  String get detectiveKindPriceUp => 'Subidas de precio';

  @override
  String get detectiveKindUnusual => 'Cargos fuera de lo común';

  @override
  String get detectiveRuleTwice =>
      'Mismo valor, comercio y cuenta, con menos de un día y medio de diferencia.';

  @override
  String get detectiveRulePriceUp =>
      'Un comercio que cobró tres veces o más y en el último cobro subió 5 % o más.';

  @override
  String get detectiveRuleUnusual =>
      'Un cargo de tres veces o más lo que sueles gastar en esa categoría y esa cuenta.';

  @override
  String get detectiveTwiceSeenTitle =>
      'Puede ser el mismo pago visto dos veces';

  @override
  String detectiveTwiceSeenWhy(String first, String second) {
    return 'Mismo valor, comercio y cuenta, muy seguidos, pero llegaron por caminos distintos: $first y $second. Lo más probable es que sea un solo pago registrado dos veces. Si sobra uno, ábrelo y bórralo tú.';
  }

  @override
  String get detectiveTwiceTitle => 'Dos cobros iguales, muy seguidos';

  @override
  String get detectiveTwiceWhy =>
      'Mismo valor, comercio y cuenta, y llegaron por el mismo camino: pueden ser dos cobros reales. Si hiciste una sola compra, revísalo con tu banco.';

  @override
  String detectivePriceUpTitle(String merchant) {
    return '$merchant cobra más que antes';
  }

  @override
  String detectivePriceUpWhy(String before, String now, int percent) {
    return 'Solía cobrar $before y el último cobro fue $now, un $percent % más. Que suba no quiere decir que esté mal: puede ser un cambio de plan o de tarifa.';
  }

  @override
  String detectiveUnusualTitle(String category) {
    return 'Mucho más de lo usual en $category';
  }

  @override
  String detectiveUnusualWhy(String times, String category) {
    return 'Es unas $times veces lo que sueles gastar por compra en $category en esta cuenta. Puede ser una compra grande que planeaste.';
  }

  @override
  String get detectiveExpected => 'Es esperado';

  @override
  String get detectiveReview => 'Lo voy a revisar';

  @override
  String get detectiveDismiss => 'Descartar';

  @override
  String get detectiveShowAgain => 'Volver a mostrar';

  @override
  String get sourceManual => 'A mano';

  @override
  String get sourceStatement => 'Extracto';

  @override
  String get sourceGemini => 'Conversación con Gemini';

  @override
  String get sourceOther => 'Otra fuente';

  @override
  String get planCommitments => 'Pagos';

  @override
  String planFixedNext30(String amount) {
    return '$amount en los próximos 30 días';
  }

  @override
  String planFixedGuesses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parecen pagos fijos: revísalos',
      one: 'Uno parece pago fijo: revísalo',
    );
    return '$_temp0';
  }

  @override
  String get planFixedNone => 'Arriendo, servicios, suscripciones';

  @override
  String get planInstalNone => 'Ninguna registrada';

  @override
  String planInstalOwed(String amount) {
    return 'Te falta pagar $amount';
  }

  @override
  String planInstalOwedEstimated(String amount) {
    return 'Te falta pagar unos $amount';
  }

  @override
  String planDetective(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cargos para revisar',
      one: 'Un cargo para revisar',
    );
    return '$_temp0';
  }

  @override
  String get planDetectiveNone => 'Nada raro por ahora';

  @override
  String get computedCommitments =>
      'Lo ya comprometido en los próximos 30 días';

  @override
  String comingIncome(String client) {
    return 'Cobro esperado: $client';
  }

  @override
  String get computedOwed => 'Lo que te deben, tus cobros y tus viajes';

  @override
  String get freeExplainReserved => 'Reserva de ingresos variables';

  @override
  String get messageCopied => 'Mensaje copiado: pégalo donde quieras enviarlo.';

  @override
  String get rateSourceManual => 'tu tasa';

  @override
  String get planSharedNone => 'Divide una cuenta y lleva lo que te deben';

  @override
  String planShared(String owed, String owing) {
    return 'Te deben $owed · debes $owing';
  }

  @override
  String get planFreelanceNone => 'Cobros pendientes, estimados y una reserva';

  @override
  String planFreelance(String amount) {
    return '$amount por cobrar';
  }

  @override
  String planFreelanceLate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cobros vencidos',
      one: 'Un cobro vencido',
    );
    return '$_temp0';
  }

  @override
  String get planTripsNone => 'Un presupuesto en la moneda del viaje';

  @override
  String planTripLeft(String trip, String amount) {
    return '$trip: te quedan $amount';
  }

  @override
  String get splitTitle => 'Dividir un gasto';

  @override
  String get splitBody =>
      'Nadie más necesita la app: escribe los nombres. Lo que te deben no cuenta como plata para gastar hasta que te paguen.';

  @override
  String get splitGroup => 'Grupo';

  @override
  String get splitNewGroup => 'Un grupo nuevo';

  @override
  String get splitWithWhom => '¿Con quién lo divides?';

  @override
  String get splitWithWhomHelp => 'Nombres separados por comas: Ana, Juan';

  @override
  String get splitGroupName => 'Nombre del grupo';

  @override
  String get splitWhat => '¿Qué fue?';

  @override
  String get splitAmount => 'Valor total';

  @override
  String get splitFromEntry => 'El del movimiento: no se cambia.';

  @override
  String get splitPaidBy => '¿Quién pagó?';

  @override
  String get splitEven => 'En partes iguales';

  @override
  String get splitCustom => 'Por montos';

  @override
  String splitPartOf(String name) {
    return 'Parte de $name';
  }

  @override
  String splitRest(String amount, String name) {
    return 'Para que el total cuadre, los $amount del redondeo quedan en la parte de $name.';
  }

  @override
  String splitRestYou(String amount) {
    return 'Para que el total cuadre, los $amount del redondeo quedan en tu parte.';
  }

  @override
  String get splitPartYou => 'Tu parte';

  @override
  String splitMissing(String amount) {
    return 'Faltan $amount para el total';
  }

  @override
  String splitOver(String amount) {
    return 'Sobran $amount sobre el total';
  }

  @override
  String splitYourPart(String mine, String others) {
    return 'Tu parte es $mine; $others te los deben.';
  }

  @override
  String get splitIncomplete => 'Falta el valor o con quién dividirlo.';

  @override
  String get splitDoesNotAddUp => 'Las partes no suman el total.';

  @override
  String get splitNeedsSomeone => 'Agrega al menos a una persona más.';

  @override
  String get splitRemove => 'Quitar la división';

  @override
  String get splitThis => 'Dividir este gasto';

  @override
  String get splitChange => 'Cambiar la división';

  @override
  String splitYours(String amount) {
    return 'Dividido: tu parte $amount';
  }

  @override
  String get sharedTitle => 'Gastos compartidos';

  @override
  String get sharedBody =>
      'Divide gastos con quien sea, sin que tenga la app. Lo que te deben no es plata para gastar: vuelve a serlo cuando te pagan.';

  @override
  String get sharedEmpty =>
      'Aún no divides gastos. Crea un grupo, o abre un gasto en Movimientos y toca «Dividir este gasto».';

  @override
  String get sharedNewGroup => 'Nuevo grupo';

  @override
  String get sharedEditGroup => 'Editar grupo';

  @override
  String get sharedGroupName => 'Nombre del grupo';

  @override
  String get sharedAddPeople => 'Agregar personas';

  @override
  String get sharedGroupIncomplete =>
      'Falta el nombre o alguien más en el grupo.';

  @override
  String get sharedOwedToYou => 'Te deben';

  @override
  String get sharedYouOwe => 'Debes';

  @override
  String get sharedNotCash =>
      'Lo que te deben no se suma a lo que puedes gastar hasta que llega.';

  @override
  String get sharedGroups => 'Grupos';

  @override
  String sharedOwesYouShort(String amount) {
    return 'Te deben $amount';
  }

  @override
  String sharedYouOweShort(String amount) {
    return 'Debes $amount';
  }

  @override
  String get sharedEven => 'A paz y salvo';

  @override
  String get sharedYou => 'Tú';

  @override
  String get sharedDelete => 'Borrar grupo';

  @override
  String sharedDeleteTitle(String name) {
    return '¿Borrar $name?';
  }

  @override
  String get sharedDeleteBody =>
      'Se borran el grupo, sus gastos y sus pagos aquí. Tus movimientos no se tocan.';

  @override
  String get sharedAddExpense => 'Agregar gasto';

  @override
  String sharedOwedToYouIn(String amount) {
    return 'En este grupo te deben $amount';
  }

  @override
  String sharedYouOweIn(String amount) {
    return 'En este grupo debes $amount';
  }

  @override
  String get sharedAllEven => 'Todos están a paz y salvo';

  @override
  String get sharedToSettle => 'Para quedar a paz y salvo';

  @override
  String sharedPaysYou(String name, String amount) {
    return '$name te paga $amount';
  }

  @override
  String sharedYouPay(String name, String amount) {
    return 'Le pagas a $name $amount';
  }

  @override
  String sharedPays(String from, String to, String amount) {
    return '$from le paga a $to $amount';
  }

  @override
  String get sharedRemind => 'Recordar';

  @override
  String sharedReminderMessage(String name, String amount, String group) {
    return 'Hola, $name. Te escribo por los $amount de $group. Cuando puedas me los pasas. ¡Gracias!';
  }

  @override
  String get sharedRecordPayment => 'Registrar pago';

  @override
  String get sharedExpenses => 'Gastos';

  @override
  String get sharedNoExpenses => 'Aún no hay gastos en este grupo.';

  @override
  String sharedPaidBy(String name) {
    return 'pagó $name';
  }

  @override
  String get sharedPaidByYou => 'pagaste tú';

  @override
  String sharedYourShare(String amount) {
    return 'tu parte $amount';
  }

  @override
  String get sharedPayments => 'Pagos';

  @override
  String sharedPaid(String from, String to) {
    return '$from le pagó a $to';
  }

  @override
  String sharedPaidYou(String from) {
    return '$from te pagó';
  }

  @override
  String sharedYouPaid(String to) {
    return 'Le pagaste a $to';
  }

  @override
  String get sharedLinked => 'llegó a tu cuenta';

  @override
  String get sharedRemovePayment => 'Quitar este pago';

  @override
  String get sharedLedgerNote =>
      'De un gasto que pagaste por otros, solo tu parte cuenta como gasto; el resto es plata prestada. Cuando te la devuelven no es un ingreso: es plata que vuelve.';

  @override
  String get sharedArrivedAs => '¿Llegó a una de tus cuentas?';

  @override
  String get sharedNotRecorded => 'No, o no está en Quincena';

  @override
  String get sharedArrivedAsHelp =>
      'Si eliges el movimiento, cuenta como plata que vuelve y no como ingreso.';

  @override
  String get freelanceTitle => 'Ingresos variables';

  @override
  String get freelanceBody =>
      'Para cuando tus ingresos cambian de un mes a otro. Separa lo cobrado, lo pendiente y lo estimado. Quincena no calcula impuestos: la reserva la decides tú.';

  @override
  String get freelanceAdd => 'Agregar cobro';

  @override
  String get freelanceEdit => 'Cobro';

  @override
  String get freelancePending => 'Por cobrar';

  @override
  String get freelanceEstimated => 'Estimado';

  @override
  String get freelanceReserve => 'Reserva';

  @override
  String freelanceOverdueNote(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cobros vencidos por $amount.',
      one: 'Un cobro vencido por $amount.',
    );
    return '$_temp0';
  }

  @override
  String get freelanceOverdue => 'Vencidos';

  @override
  String get freelancePendingList => 'Pendientes';

  @override
  String get freelanceEstimatedList => 'Estimados';

  @override
  String get freelanceCollectedList => 'Cobrados';

  @override
  String get freelanceScenario => 'Qué contar en los próximos días';

  @override
  String get scenarioCollected => 'Lo cobrado';

  @override
  String get scenarioPending => 'Lo facturado';

  @override
  String get scenarioEstimated => 'Todo';

  @override
  String get scenarioCollectedBody =>
      'Solo la plata que ya tienes. Lo más prudente para un mes difícil.';

  @override
  String get scenarioPendingBody =>
      'También lo facturado, el día que lo esperas. Si se atrasa, se corre al día siguiente, y nunca cuenta en lo que puedes gastar hasta que llega.';

  @override
  String get scenarioEstimatedBody =>
      'También lo que crees que vendrá sin haberlo facturado. Lo menos prudente: úsalo con cuidado.';

  @override
  String get freelanceReservePercent => 'Apartar de cada cobro';

  @override
  String get freelanceNoReserve => 'Nada';

  @override
  String freelanceReserveNow(String amount, String date) {
    return 'Tienes apartados $amount desde el $date. No cuentan en lo que puedes gastar, pero siguen en tus cuentas.';
  }

  @override
  String get freelanceReserveOff =>
      'Sin reserva: todo lo que cobras cuenta en lo que puedes gastar.';

  @override
  String get freelanceNoTax =>
      'Quincena no calcula impuestos ni sabe cuánto te toca pagar: el porcentaje es tuyo.';

  @override
  String get freelanceUse => 'Usé de la reserva';

  @override
  String get freelanceUseAmount => '¿Cuánto usaste?';

  @override
  String get freelanceUseHelp =>
      'Por ejemplo, lo que pagaste de impuestos o seguridad social.';

  @override
  String freelanceExpectedOn(String date) {
    return 'Esperado el $date';
  }

  @override
  String freelanceCollectedOn(String date) {
    return 'Cobrado el $date';
  }

  @override
  String freelanceLate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Vencido hace $days días: era el $date',
      one: 'Vencido hace un día: era el $date',
    );
    return '$_temp0';
  }

  @override
  String get freelanceClient => '¿Quién te paga?';

  @override
  String get freelanceAmount => 'Valor';

  @override
  String get incomeEstimated => 'Estimado';

  @override
  String get incomePending => 'Facturado';

  @override
  String get incomeCollected => 'Cobrado';

  @override
  String get incomeEstimatedHelp =>
      'Crees que vendrá, pero aún no lo facturas.';

  @override
  String get incomePendingHelp => 'Ya lo facturaste y esperas el pago.';

  @override
  String get incomeCollectedHelp => 'La plata ya llegó.';

  @override
  String get freelanceArrivedAs => '¿Con qué movimiento llegó?';

  @override
  String get freelanceNote => 'Nota';

  @override
  String get freelanceIncomplete => 'Falta quién te paga o el valor.';

  @override
  String get freelanceRemind => 'Recordar al cliente';

  @override
  String freelanceReminderMessage(String client, String amount, String date) {
    return 'Hola, $client. Te escribo por el pago de $amount que esperaba el $date. ¿Me confirmas cuándo lo puedes hacer? ¡Gracias!';
  }

  @override
  String get freelanceDelete => 'Borrar cobro';

  @override
  String get tripsTitle => 'Viajes';

  @override
  String get tripsBody =>
      'Un presupuesto en la moneda del viaje, contado con tus mismos movimientos: nada se copia.';

  @override
  String get tripsEmpty => 'Aún no tienes viajes.';

  @override
  String get tripsNew => 'Nuevo viaje';

  @override
  String get tripEdit => 'Editar viaje';

  @override
  String get tripDelete => 'Borrar viaje';

  @override
  String tripDeleteTitle(String name) {
    return '¿Borrar $name?';
  }

  @override
  String get tripDeleteBody =>
      'Se borra el viaje aquí. Sus gastos siguen en tus cuentas.';

  @override
  String tripLeftShort(String amount) {
    return 'Quedan $amount';
  }

  @override
  String tripSpentShort(String amount) {
    return 'Gastaste $amount';
  }

  @override
  String get tripSpent => 'Gastaste';

  @override
  String get tripLeft => 'Te quedan';

  @override
  String tripOf(String amount) {
    return 'de $amount';
  }

  @override
  String tripPerDay(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Puedes gastar $amount al día los $days días que quedan.',
      one: 'Puedes gastar $amount hoy, el último día.',
    );
    return '$_temp0';
  }

  @override
  String tripAverage(String amount) {
    return 'Llevas $amount al día en promedio.';
  }

  @override
  String get tripOver => 'El viaje terminó.';

  @override
  String tripUnconverted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gastos no tienen tasa para convertirlos y no cuentan.',
      one: 'Un gasto no tiene tasa para convertirlo y no cuenta.',
    );
    return '$_temp0';
  }

  @override
  String get tripShared => 'Gastos compartidos del viaje';

  @override
  String get tripShare => 'Dividir gastos del viaje con alguien';

  @override
  String get tripExpenses => 'Gastos del viaje';

  @override
  String get tripNoExpenses =>
      'Los gastos de las fechas del viaje aparecen aquí solos. Agrega los que pagaste allá en su moneda.';

  @override
  String get tripIncludeEarlier => 'Incluir un gasto de antes';

  @override
  String get tripIncludeEarlierBody =>
      'El vuelo o el hotel que pagaste antes de salir.';

  @override
  String get tripNothingEarlier =>
      'No hay gastos en los 120 días antes del viaje.';

  @override
  String get tripSameMovements =>
      'Un viaje usa tus mismos movimientos: cambiar uno aquí lo cambia en tu cuenta.';

  @override
  String get tripNoRate => 'Sin tasa';

  @override
  String get tripExclude => 'No es del viaje';

  @override
  String tripForeign(
    String amount,
    String rate,
    String date,
    String fee,
    String estimate,
  ) {
    return '$amount a $rate ($date) más $fee de la tarjeta: $estimate estimado';
  }

  @override
  String tripForeignNoFee(
    String amount,
    String rate,
    String date,
    String estimate,
  ) {
    return '$amount a $rate ($date): $estimate estimado';
  }

  @override
  String tripConverted(String amount, String source, String date) {
    return '$amount, convertido con $source del $date';
  }

  @override
  String tripChargedMore(String charged, String difference) {
    return 'El banco cobró $charged: $difference más que el estimado';
  }

  @override
  String tripChargedLess(String charged, String difference) {
    return 'El banco cobró $charged: $difference menos que el estimado';
  }

  @override
  String get tripAdjust => 'Ajustar al cargo real';

  @override
  String get tripCharged => '¿Cuánto te cobró el banco?';

  @override
  String get tripAdjustHelp =>
      'Cambia el movimiento a lo que dice el extracto, y queda la diferencia con el estimado.';

  @override
  String get tripName => '¿A dónde vas?';

  @override
  String get tripCurrency => 'Moneda del viaje';

  @override
  String get tripBudget => 'Presupuesto';

  @override
  String get tripFee => 'Comisión de tu tarjeta en el exterior';

  @override
  String get tripFeeHelp =>
      'Si la sabes: se suma al estimar lo que te cobrarán en pesos.';

  @override
  String get tripFeeShort => 'Comisión';

  @override
  String get tripIncomplete => 'Falta a dónde vas.';

  @override
  String get tripAddExpense => 'Agregar gasto del viaje';

  @override
  String get tripWhat => '¿En qué?';

  @override
  String get tripAmount => 'Valor';

  @override
  String get tripPaidWith => 'Pagaste con';

  @override
  String tripRate(String from, String to) {
    return '1 $from en $to';
  }

  @override
  String get tripRateNone => 'Sin tasa guardada: escribe la que viste.';

  @override
  String tripRateFrom(String source, String date) {
    return '$source del $date';
  }

  @override
  String tripWillRecord(String amount, String account) {
    return 'Se registran $amount en $account, estimado hasta que llegue el cargo real.';
  }

  @override
  String get tripExpenseIncomplete => 'Falta el valor o la tasa.';

  @override
  String get syncTitle => 'Varios dispositivos';

  @override
  String get syncRow => 'Tus datos en otro teléfono o computador, cifrados';

  @override
  String get syncBody =>
      'Usa Quincena en más de un dispositivo con los mismos datos. Los cambios viajan en un archivo cifrado que mueves tú, por AirDrop, Archivos o un chat contigo: solo tus dispositivos lo pueden abrir, y Quincena no lo recibe.';

  @override
  String get syncNotBackup =>
      'Sincronizar no es un respaldo: une los cambios de tus dispositivos. Para guardar una copia de todo, usa Exportar en Ajustes.';

  @override
  String get syncNotOnWeb =>
      'La sincronización está en la app del teléfono y del computador.';

  @override
  String get syncStart => 'Empezar en este dispositivo';

  @override
  String get syncJoin => 'Unir este dispositivo';

  @override
  String get syncHow =>
      'Empieza en el dispositivo que ya tiene tus datos. En el otro, toca «Unir este dispositivo» y escribe el código.';

  @override
  String get syncYourCode => 'Tu código';

  @override
  String get syncNewCode => 'Tu código nuevo';

  @override
  String get syncCodeKeep =>
      'Con este código unes tus otros dispositivos. Guárdalo donde guardas tus contraseñas: si pierdes todos tus dispositivos y el código, nadie podrá abrir los archivos, ni siquiera Quincena.';

  @override
  String get syncCopyCode => 'Copiar el código';

  @override
  String get syncCodeCopied => 'Código copiado.';

  @override
  String get syncDone => 'Listo';

  @override
  String get syncJoinBody =>
      'Escribe el código que muestra tu otro dispositivo en Ajustes, Varios dispositivos. Los guiones no importan.';

  @override
  String get syncCodeField => 'Código';

  @override
  String get syncJoinAction => 'Unir';

  @override
  String get syncCodeLength =>
      'Al código le sobran o le faltan caracteres: son 54.';

  @override
  String get syncCodeCharacter =>
      'Hay un carácter que el código no usa. Revisa que no sea una U.';

  @override
  String get syncCodeCheck =>
      'El código no cuadra: revisa si hay un carácter cambiado.';

  @override
  String get syncJoined =>
      'Listo. Ahora abre un archivo de tu otro dispositivo para traer tus datos.';

  @override
  String get syncSend => 'Guardar mis cambios en un archivo';

  @override
  String get syncOpen => 'Abrir un archivo de otro dispositivo';

  @override
  String get syncSendHow =>
      'Guarda el archivo donde tu otro dispositivo lo encuentre, o envíatelo, y ábrelo allá. Cada archivo lleva todo, así que el más reciente basta.';

  @override
  String get syncSaved => 'Archivo guardado. Ábrelo en tu otro dispositivo.';

  @override
  String syncMerged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Listo: $count cambios.',
      one: 'Listo: un cambio.',
      zero: 'Ya estaba todo al día.',
    );
    return '$_temp0';
  }

  @override
  String syncMergedWaiting(int count, int waiting) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambios',
      one: 'Un cambio',
    );
    String _temp1 = intl.Intl.pluralLogic(
      waiting,
      locale: localeName,
      other: '$waiting esperan',
      one: 'uno espera',
    );
    return '$_temp0; $_temp1 a que lo revises.';
  }

  @override
  String get syncNotSync =>
      'Ese no es un archivo de sincronización de Quincena.';

  @override
  String get syncOtherVault =>
      'Ese archivo se hizo con otro código. Abre uno de un dispositivo unido con este código.';

  @override
  String get syncNewer =>
      'Ese archivo es de una versión más nueva de Quincena: actualiza la app.';

  @override
  String get syncDamaged =>
      'El archivo está dañado o se cortó: guárdalo de nuevo en el otro dispositivo. No cambió nada.';

  @override
  String get syncWaiting => 'Para revisar';

  @override
  String get syncWaitingBody =>
      'Cambios que no quedaron porque otro dispositivo cambió lo mismo. Nada se perdió: puedes traerlos de vuelta.';

  @override
  String get syncWhyEditedBoth =>
      'Cambiado aquí y en otro dispositivo; quedó el más reciente.';

  @override
  String get syncWhyDeletedElsewhere =>
      'Lo cambiaste aquí, pero se borró en otro dispositivo.';

  @override
  String get syncWhyDeletedHere =>
      'Lo borraste aquí; así lo habían cambiado en otro dispositivo.';

  @override
  String get syncWhyWithAccount => 'Su cuenta se borró en un dispositivo.';

  @override
  String get syncWhatProfile => 'Tu perfil';

  @override
  String get syncWhatSetting => 'Un ajuste';

  @override
  String get syncRestore => 'Traer de vuelta';

  @override
  String get syncDismiss => 'Descartar';

  @override
  String get syncRestored =>
      'De vuelta. Tus otros dispositivos lo reciben con el próximo archivo.';

  @override
  String get syncThisDevice => 'Este dispositivo';

  @override
  String get syncShowCode => 'Ver el código';

  @override
  String get syncChange => 'Cambiar el código';

  @override
  String get syncChangeTitle => '¿Cambiar el código?';

  @override
  String get syncChangeBody =>
      'Los archivos que guardes desde ahora solo se abren con el código nuevo; une con él los dispositivos que quieras conservar. Los archivos que ya enviaste se siguen abriendo con el anterior.';

  @override
  String get syncStop => 'Dejar de sincronizar';

  @override
  String get syncStopTitle => '¿Dejar de sincronizar aquí?';

  @override
  String get syncStopBody =>
      'Este dispositivo olvida el código. Tus datos se quedan aquí.';

  @override
  String get syncWhyReplaced =>
      'Lo que había antes de traer de vuelta otra versión.';

  @override
  String get syncWhyDuplicate =>
      'Llegó dos veces del mismo extracto o de Binance; quedó una.';

  @override
  String get reportAnswer => 'Reportar';

  @override
  String get reportSent => 'Reportada';

  @override
  String get reportTitle => 'Reportar esta respuesta';

  @override
  String get reportWhy => '¿Qué tiene de malo?';

  @override
  String get reportOffensive => 'Es ofensiva o inapropiada';

  @override
  String get reportWrong => 'Es incorrecta o engañosa';

  @override
  String get reportOther => 'Otra cosa';

  @override
  String get reportComment => 'Cuéntanos más (opcional)';

  @override
  String get reportWhat =>
      'A DL SOFT le llegan tu pregunta, esta respuesta con sus cifras y lo que escribas aquí; nada más de tu cuenta, ni un identificador tuyo. Los reportes se borran a los 90 días.';

  @override
  String get reportSend => 'Enviar reporte';

  @override
  String get reportSending => 'Enviando…';

  @override
  String get reportFailed =>
      'No se pudo enviar. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get reportThanks => 'Gracias. Vamos a revisar esta respuesta.';

  @override
  String get standingCanSpend => 'Puedes gastar';

  @override
  String get standingShort => 'Te faltan';

  @override
  String standingUntil(String date) {
    return 'hasta el $date';
  }

  @override
  String standingShortUntil(String date) {
    return 'para llegar al $date';
  }

  @override
  String standingNextFortnight(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'tu quincena llega en $days días',
      one: 'tu quincena llega mañana',
      zero: 'hoy llega tu quincena',
    );
    return '$_temp0';
  }

  @override
  String standingNextPay(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'tu próximo pago llega en $days días',
      one: 'tu próximo pago llega mañana',
      zero: 'hoy llega tu pago',
    );
    return '$_temp0';
  }

  @override
  String get standingAvailable => 'En tus cuentas de uso diario';

  @override
  String standingPaymentsBefore(String date) {
    return 'Pagos hasta el $date';
  }

  @override
  String get standingCushionLine => 'Colchón';

  @override
  String get standingEnvelopesLine => 'Apartado en sobres';

  @override
  String get standingReserveLine => 'Reserva de ingresos variables';

  @override
  String standingShortSemantics(String free, String date, String when) {
    return 'Te faltan $free para llegar al $date; $when.';
  }

  @override
  String get homeTodo => 'Por hacer';

  @override
  String get todoReview => 'Revisar';

  @override
  String get todoSplit => 'Repartir';

  @override
  String get paydayArrivedPay => 'Te llegó el pago';

  @override
  String get netWorthDetail => 'Lo que tienes menos lo que debes';

  @override
  String get groupCards => 'Tarjetas de crédito';

  @override
  String cardOwed(String amount) {
    return 'Debes $amount';
  }

  @override
  String cardInFavor(String amount) {
    return 'A favor $amount';
  }

  @override
  String get cardClear => 'Al día';

  @override
  String get totalExplainHave => 'Lo que tienes';

  @override
  String get totalExplainOwe => 'Lo que debes';

  @override
  String get ratesSeeAll => 'Ver tasas usadas';

  @override
  String get cardOwedLabel => 'Debes';

  @override
  String get cardInFavorLabel => 'A favor';

  @override
  String get whichAccountIn => 'No sabemos a qué cuenta llegó.';

  @override
  String get whichAccountOut => 'No sabemos de qué cuenta salió.';

  @override
  String get fromOwnAccount => '¿Viene de otra cuenta tuya?';

  @override
  String get moreActions => 'Más acciones';

  @override
  String get hideOriginal => 'Ocultar el mensaje';

  @override
  String statementNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuevos',
      one: '1 nuevo',
      zero: 'Ninguno nuevo',
    );
    return '$_temp0';
  }

  @override
  String statementAlready(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ya estaban',
      one: '1 ya estaba',
      zero: 'ninguno repetido',
    );
    return '$_temp0';
  }

  @override
  String statementUnsorted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sin categoría',
      one: '1 sin categoría',
    );
    return '$_temp0';
  }

  @override
  String get statementAlreadyUnchecked =>
      'Lo que ya estaba quedó sin marcar, para no contarlo dos veces.';

  @override
  String get statementSelectAll => 'Seleccionar todos';

  @override
  String get statementSelectNone => 'Quitar todos';

  @override
  String get statementDoneSorted => 'Todos quedaron con su categoría.';

  @override
  String statementDoneUnsorted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quedaron sin categoría: tócalos para ponérsela.',
      one: 'Uno quedó sin categoría: tócalo para ponérsela.',
    );
    return '$_temp0';
  }

  @override
  String get statementGiveCategory => 'Sin categoría';

  @override
  String get statementFinish => 'Listo';

  @override
  String get licensesTitle => 'Licencias y créditos';

  @override
  String get licensesLegalese =>
      '© 2026 DL SOFT TECHNOLOGIES SAS. Los comercios cercanos vienen de © colaboradores de OpenStreetMap (ODbL).';

  @override
  String comingLowestLine(String amount, String date) {
    return 'Tu saldo mínimo estimado será $amount el $date.';
  }

  @override
  String get timelineFortnight => 'Tu quincena';

  @override
  String get timelineCharge => 'Un cobro programado';

  @override
  String get timelineExpected => 'esperado';

  @override
  String timelineMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Y $count más hasta el pago.',
      one: 'Y un día más hasta el pago.',
    );
    return '$_temp0';
  }

  @override
  String get buyAsk => '¿Me alcanza para…?';

  @override
  String get buyAskBody =>
      'Escribe el precio y te digo si te alcanza sin tocar lo comprometido.';

  @override
  String get buyAskHint => 'Precio';

  @override
  String get buyAskGo => 'Ver';

  @override
  String get fabMovement => 'Movimiento';

  @override
  String goalSoFar(String saved) {
    return 'Llevas $saved';
  }

  @override
  String goalMissing(String missing) {
    return 'faltan $missing';
  }

  @override
  String get goalReached => 'Meta cumplida';

  @override
  String goalNeedMark(String amount) {
    return 'Necesitas $amount';
  }

  @override
  String askExample(String question) {
    return 'Por ejemplo: $question';
  }

  @override
  String get askExampleBuy => '¿Me alcanza para unos audífonos de \$350.000?';

  @override
  String askExampleGoal(String name) {
    return '¿Llego a mi meta de $name?';
  }

  @override
  String get askExampleWeekend => '¿Cuánto puedo gastar este fin de semana?';

  @override
  String get askExampleCard => '¿Cuánto debo en la tarjeta?';

  @override
  String get askExampleCrypto => '¿Cómo va mi cripto esta semana?';

  @override
  String get askExampleMost => '¿En qué gasté más este mes?';

  @override
  String get chartPerformance => 'Rendimiento';

  @override
  String get chartValue => 'Valor';

  @override
  String get chartPerformanceNote =>
      'Solo lo que movieron los precios de tus monedas, con el dólar de hoy: comprar o vender no cambia esta línea.';

  @override
  String get binancePromiseRead => 'Solo lectura';

  @override
  String get binancePromiseNoWithdraw => 'No permite retiros';

  @override
  String get binancePromiseNoTrade =>
      'No permite órdenes de compra ni de venta';

  @override
  String get binancePromiseDisconnect => 'La desconectas cuando quieras';

  @override
  String ratesFailedAt(String when) {
    return 'No se pudieron actualizar. Se usan las del $when.';
  }

  @override
  String portfolioPricingFailedAt(String when) {
    return 'No se pudieron leer los precios. Se muestran los del $when.';
  }

  @override
  String get chartLoading => 'Actualizando la gráfica…';

  @override
  String get loanLentAction => 'Le presté';

  @override
  String get loanBorrowedAction => 'Me prestaron';

  @override
  String get loanLentTitle => 'Le presté plata a alguien';

  @override
  String get loanBorrowedTitle => 'Alguien me prestó plata';

  @override
  String get loanLentWho => '¿A quién?';

  @override
  String get loanBorrowedWho => '¿Quién te prestó?';

  @override
  String get loanWhat => '¿Para qué? (opcional)';

  @override
  String get loanLabel => 'Préstamo';

  @override
  String get loanFromAccount => '¿De qué cuenta salió?';

  @override
  String get loanNoAccount => 'No salió de mis cuentas';

  @override
  String get loanLentNote =>
      'Queda como plata que te deben, no como gasto. Cuando te la devuelvan, regístralo en el grupo.';

  @override
  String get loanBorrowedNote =>
      'Queda como plata que debes. Cuando la pagues, regístralo en el grupo.';

  @override
  String get loanIncomplete => 'Falta a quién o el monto.';

  @override
  String get statementImporting => 'Importando…';

  @override
  String get exportBody =>
      'Un archivo con todo lo que tienes en Quincena: cuentas, movimientos, planes y ajustes. Sirve para pasarlo a otro teléfono o guardar una copia.';

  @override
  String get exportSealed => 'Cifrado (recomendado)';

  @override
  String get exportSealedBody =>
      'Solo se abre en Quincena con tu código de respaldo. Puedes guardarlo en la nube o mandártelo sin que nadie más lo lea.';

  @override
  String get exportPlain => 'Sin cifrar (JSON)';

  @override
  String get exportPlainBody =>
      'Cualquiera que tenga el archivo puede leer tus finanzas. Sirve para llevarlas a otra herramienta.';

  @override
  String get exportAction => 'Exportar';

  @override
  String get backupShowCode => 'Ver mi código de respaldo';

  @override
  String get backupYourCode => 'Tu código de respaldo';

  @override
  String get backupCodeKeep =>
      'Con este código abres tus respaldos cifrados, en este teléfono o en otro. Guárdalo donde guardas tus contraseñas: sin él nadie podrá abrirlos, ni siquiera Quincena.';

  @override
  String get backupCodeKept => 'Ya lo guardé';

  @override
  String get backupCodeTitle => 'Respaldo cifrado';

  @override
  String get backupCodeBody =>
      'Escribe el código de respaldo que Quincena te mostró la primera vez que exportaste cifrado.';

  @override
  String get backupOpen => 'Abrir';

  @override
  String get backupWrongCode =>
      'Ese código no abre este respaldo. Si es el de sincronización, el de respaldo es otro.';

  @override
  String get backupIsSync =>
      'Ese es un archivo de sincronización: se abre en Ajustes, Varios dispositivos. No se cambió nada.';

  @override
  String get backupChangeCode => 'Cambiar el código';

  @override
  String get backupChangeTitle => '¿Cambiar el código de respaldo?';

  @override
  String get backupChangeBody =>
      'Los respaldos que ya hiciste se siguen abriendo con el código de antes; los nuevos, con el nuevo. Guarda los dos mientras tengas respaldos viejos.';

  @override
  String get backupChange => 'Cambiar';

  @override
  String get backupNewCode => 'Tu nuevo código de respaldo';

  @override
  String widgetUpdated(String when) {
    return 'Actualizado: $when';
  }

  @override
  String get widgetStale => 'Abre Quincena para ver la cifra de hoy.';

  @override
  String get widgetSection => 'Widget de inicio';

  @override
  String get widgetHow =>
      'Para agregarlo, mantén presionado un espacio vacío de la pantalla de inicio y busca Quincena. Muestra lo que puedes gastar hasta tu próximo pago, como lo calculó la app la última vez que la abriste.';

  @override
  String get widgetHide => 'Ocultar montos en el widget';

  @override
  String get widgetHideHelp => 'Dice hasta cuándo, sin la cifra.';

  @override
  String get widgetAdd => 'Agregar a la pantalla de inicio';

  @override
  String get widgetAddFailed =>
      'Tu pantalla de inicio no deja agregarlo desde aquí. Mantén presionado un espacio vacío y busca Quincena.';

  @override
  String get rateManualTag => 'Manual';

  @override
  String rateManualOn(String date) {
    return 'Escrita a mano el $date';
  }

  @override
  String rateAutomaticNow(String value) {
    return 'La automática hoy: $value';
  }

  @override
  String get rateUseFetchedShort => 'Usar la automática';

  @override
  String get rateRestoreFailed =>
      'No se pudo traer la tasa automática. Sigue la tuya; intenta de nuevo con conexión.';

  @override
  String rateStepPrice(String asset, String value, String source, String when) {
    return 'Precio de mercado: 1 $asset = $value · $source, $when';
  }

  @override
  String rateStepConvert(
    String base,
    String asset,
    String value,
    String source,
    String date,
  ) {
    return 'Conversión a $base: 1 $asset = $value · $source del $date';
  }

  @override
  String rateStepManual(String asset, String value) {
    return '1 $asset = $value · escrita a mano';
  }

  @override
  String ratesIntro(String base) {
    return 'Así pasamos a $base lo que tienes en otras monedas. Solo cambian los totales, no los saldos de tus cuentas.';
  }

  @override
  String ratesManualCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasas escritas a mano',
      one: '1 tasa escrita a mano',
    );
    return '$_temp0';
  }

  @override
  String get portfolioNoData => 'Sin dato';

  @override
  String get portfolioNoData24h => 'Aún no hay precio de hace 24 horas.';

  @override
  String get portfolioNoPrice => 'Sin precio';

  @override
  String portfolioDayDetail(String percent) {
    return '$percent por precio';
  }

  @override
  String get portfolioGainMeaning =>
      'Lo que vale hoy lo que aún tienes menos lo que pagaste por eso, en pesos. Incluye cuánto se movió el dólar frente al peso y las comisiones de Binance; lo que ya vendiste va aparte.';

  @override
  String portfolioGainUncosted(String amount) {
    return 'Sin contar $amount que llegó sin precio de compra.';
  }

  @override
  String portfolioConvertedWith(String day) {
    return 'Pasados a pesos con la TRM del $day';
  }

  @override
  String get portfolioRefresh => 'Actualizar';

  @override
  String get portfolioRefreshLabel => 'Actualizar precios';

  @override
  String get chartPerformanceNoteFx =>
      'Lo que movieron los precios y el dólar frente al peso: comprar o vender no cambia esta línea.';

  @override
  String get portfolioGainMeaningPlain =>
      'Lo que vale hoy lo que aún tienes menos lo que pagaste por eso. Incluye las comisiones de Binance; lo que ya vendiste va aparte.';

  @override
  String get chartPerformanceNoteFxPlain =>
      'Lo que movieron los precios y el dólar frente a tu moneda: comprar o vender no cambia esta línea.';

  @override
  String get freeExplainSpendableSection => 'Tus cuentas de uso diario';

  @override
  String get standingCardDebtLine => 'Lo que debes en tarjetas';

  @override
  String get cardSpendableHelp =>
      'Si está encendido, lo que debes en esta tarjeta se resta de lo que puedes gastar, porque lo pagas con tus cuentas de uso diario.';

  @override
  String freeExplainAssumePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'No cuenta $count movimientos que esperan en Por revisar. Cuando los confirmes, la cifra puede cambiar.',
      one:
          'No cuenta 1 movimiento que espera en Por revisar. Cuando lo confirmes, la cifra puede cambiar.',
    );
    return '$_temp0';
  }

  @override
  String paydayArrivedAmount(String amount) {
    return 'Te llegó la quincena: $amount';
  }

  @override
  String paydayArrivedPayAmount(String amount) {
    return 'Te llegó el pago: $amount';
  }

  @override
  String paydayArrivedDetail(String date, String account) {
    return 'El $date en $account. Ponle a cada parte su sobre antes de gastar.';
  }

  @override
  String listAnd(String a, String b, String sound) {
    String _temp0 = intl.Intl.selectLogic(sound, {'i': 'e', 'other': 'y'});
    return '$a $_temp0 $b';
  }

  @override
  String comingLowestLineSure(String amount, String date) {
    return 'Tu saldo mínimo estimado será $amount el $date, sin contar lo que esperas recibir.';
  }

  @override
  String get totalExplainOwedToYou => 'Te deben';

  @override
  String get totalExplainYouOwe => 'Les debes a otras personas';

  @override
  String get totalExplainShared => 'Gastos compartidos y préstamos';

  @override
  String get totalExplainInstallments => 'Compras a cuotas';

  @override
  String get totalExplainInstallmentsLeft =>
      'Lo que falta pagar, fuera de tus tarjetas';

  @override
  String paydayArrivedDetailRange(String from, String to, String account) {
    return 'Del $from al $to en $account. Ponle a cada parte su sobre antes de gastar.';
  }

  @override
  String get statementSelectNew => 'Marcar los nuevos';

  @override
  String statementRepeatsChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Marcaste $count que ya estaban: se contarían dos veces.',
      one: 'Marcaste 1 que ya estaba: se contaría dos veces.',
    );
    return '$_temp0';
  }

  @override
  String statementSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionados',
      one: '1 seleccionado',
      zero: 'Nada seleccionado',
    );
    return '$_temp0';
  }

  @override
  String statementIn(String amount) {
    return 'entran $amount';
  }

  @override
  String statementOut(String amount) {
    return 'salen $amount';
  }

  @override
  String get statementReviewLine => 'Revisar movimiento';

  @override
  String get statementOriginal => 'Como aparece en el extracto';

  @override
  String statementCardPayment(String card) {
    return 'Pago de tu tarjeta $card';
  }

  @override
  String statementOwnTransferTo(String account) {
    return 'Pasa a $account';
  }

  @override
  String statementOwnTransferFrom(String account) {
    return 'Viene de $account';
  }

  @override
  String statementBetweenAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entre tus cuentas',
      one: '1 entre tus cuentas',
    );
    return '$_temp0';
  }

  @override
  String get statementTransferNote =>
      'Un pago de tarjeta pasa plata de una cuenta tuya a otra: no cuenta como gasto, porque las compras ya están en la tarjeta.';

  @override
  String get statementIsCardPayment => '¿Es el pago de una tarjeta tuya?';

  @override
  String get statementAddCard =>
      'Parece el pago de una tarjeta. Agrégala en Cuentas para que Quincena no cuente dos veces lo que compraste con ella.';

  @override
  String statementDoneTransfers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count quedaron como movimientos entre tus cuentas: no cuentan como gasto.',
      one: 'Uno quedó como movimiento entre tus cuentas: no cuenta como gasto.',
    );
    return '$_temp0';
  }

  @override
  String statementOlder(int count, String date, String account) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimientos son de antes del $date',
      one: 'Un movimiento es de antes del $date',
    );
    return '$_temp0, cuando escribiste el saldo de $account.';
  }

  @override
  String get statementOlderKeep => 'Mi saldo ya los incluye (recomendado)';

  @override
  String get statementOlderAdd => 'Sumarlos a mi saldo';

  @override
  String get statementOlderNote =>
      'Se guardan para ver en qué se fue la plata, sin cambiar lo que tienes hoy.';

  @override
  String statementEndsAt(String date, String amount) {
    return 'Según el extracto, el $date tenías $amount.';
  }

  @override
  String statementMismatch(String amount) {
    return 'Quincena tendría $amount ese día.';
  }

  @override
  String get statementUseBalance => 'Ajustar al saldo del extracto';

  @override
  String statementBalanceEffect(String account, String before, String after) {
    return 'Saldo de $account: $before → $after';
  }

  @override
  String statementDebtEffect(String account, String before, String after) {
    return 'Lo que debes en $account: $before → $after';
  }

  @override
  String statementBalanceSame(String account, String amount) {
    return 'El saldo de $account sigue en $amount: ya incluía estos movimientos.';
  }

  @override
  String get statementPaidFrom => '¿De cuál de tus cuentas salió este pago?';

  @override
  String get statementSaveFailed =>
      'No se pudo terminar de importar. Lo que sí se guardó aparece como «Ya importado».';

  @override
  String get goalTypeAmount => 'Escribir monto';

  @override
  String get goalAmountTitle => '¿Cuánto quieres apartar al mes?';

  @override
  String get goalAmountUse => 'Usar este monto';

  @override
  String get goalAmountInvalid => 'Escribe un monto mayor que cero.';

  @override
  String goalUseNeeded(String amount) {
    return 'Usar $amount al mes';
  }

  @override
  String goalSimulating(String current) {
    return 'Simulación · hoy apartas $current';
  }

  @override
  String goalBackToCurrent(String amount) {
    return 'Volver a $amount';
  }

  @override
  String goalPlanContributions(
    int count,
    String amount,
    String first,
    String last,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Son $count aportes de $amount, del $first al $last.',
      one: 'Es 1 aporte, el $first.',
    );
    return '$_temp0';
  }

  @override
  String get goalEffectTitle => 'Qué cambia en lo que puedes gastar';

  @override
  String goalEffectUntilPayday(String payday, String free, String day) {
    return 'Hasta el $payday puedes gastar $free: el aporte sale el $day, así que no lo toca.';
  }

  @override
  String goalEffectBeforePay(String day, String payday, String left) {
    return 'El aporte del $day sale antes de tu pago: hasta el $payday podrías gastar $left.';
  }

  @override
  String goalEffectMore(String payday, String amount) {
    return 'Desde la quincena del $payday tendrías $amount menos al mes para gastar que hoy.';
  }

  @override
  String goalEffectLess(String payday, String amount) {
    return 'Desde la quincena del $payday tendrías $amount más al mes para gastar que hoy.';
  }

  @override
  String get goalEffectSame =>
      'Es lo que ya apartas: lo que puedes gastar no cambia.';

  @override
  String get goalNeverArrives => 'Sin aporte al mes no llegas a la meta.';

  @override
  String goalEffectUntilPaydayShort(String short, String payday, String day) {
    return 'Te faltan $short para llegar al $payday. El aporte sale el $day, después de tu pago.';
  }

  @override
  String goalEffectBeforePayShort(String day, String short, String payday) {
    return 'El aporte del $day sale antes de tu pago: te faltarían $short para llegar al $payday.';
  }

  @override
  String get newConversationShort => 'Nueva';

  @override
  String get conversationCleared => 'Empezaste una conversación nueva.';

  @override
  String get seeResult => 'Ver resultado';

  @override
  String get newAnswerBelow => 'Hay una respuesta nueva abajo';

  @override
  String get settledExpense => 'Gasto guardado';

  @override
  String get settledPlan => 'Plan guardado';

  @override
  String get settledCancelled => 'Marcadas como canceladas';

  @override
  String settledAt(String what, String time) {
    return '$what · $time';
  }

  @override
  String get cancelPickHint =>
      'Marca las que quieras cancelar para ver cuánto ahorras';

  @override
  String subscriptionSelect(String name) {
    return 'Seleccionar $name para cancelar';
  }

  @override
  String get subscriptionToCancel => 'Para cancelar';

  @override
  String get subscriptionCancelled => 'Cancelada';

  @override
  String get cardLimitField => 'Cupo total (opcional)';

  @override
  String get cardLimitHelp =>
      'Con el cupo te mostramos cuánto te queda por usar. Nunca se suma a lo que puedes gastar: es plata prestada.';

  @override
  String cardCreditLeft(String amount) {
    return 'Cupo libre $amount';
  }

  @override
  String cardCreditLeftOf(String left, String limit) {
    return 'Cupo libre $left de $limit';
  }

  @override
  String get groupCrypto => 'Cripto';

  @override
  String get cryptoPerformanceRow => 'Rendimiento y ganancia';

  @override
  String get portfolioSources => 'Gestionar fuentes';

  @override
  String get binanceRowOff => 'Sin conectar · solo lectura, nunca mueve fondos';

  @override
  String get binanceCardManualBody =>
      'Tus saldos de Binance están anotados a mano. Conéctala para que se actualicen solos.';

  @override
  String get portfolioSourceManual => 'Anotado a mano: no se actualiza solo';

  @override
  String portfolioSourceBinance(String when) {
    return 'Conectada a Binance · leída $when';
  }

  @override
  String get portfolioSourceBinanceNever =>
      'Conectada a Binance: se actualiza sola';

  @override
  String portfolioSourceWallet(String when) {
    return 'Por dirección pública · leída $when';
  }

  @override
  String get portfolioSourceWalletNever =>
      'Por dirección pública: se actualiza sola';

  @override
  String get chartNow => 'Ahora';

  @override
  String get chartZero => '0 = como empezó el periodo';

  @override
  String chartPointGain(String when, String amount) {
    return '$when: $amount desde el inicio';
  }

  @override
  String chartPointValue(String when, String amount) {
    return '$when: valía $amount';
  }

  @override
  String get chartTouchHint =>
      'Toca la línea y desliza el dedo para ver cada momento.';

  @override
  String chartSemanticsGain(String range, String amount, String percent) {
    return 'Ganancia por precio $range: $amount, $percent';
  }

  @override
  String get portfolioSourceBinanceOff => 'Leída de Binance · sin conectar';

  @override
  String get portfolioSourceWalletOff =>
      'Leída por dirección pública · ya no la sigues';

  @override
  String demoBannerTitle(String name) {
    return 'Estás viendo la cuenta de ejemplo de $name';
  }

  @override
  String get demoBannerBody =>
      'Con tus cuentas, Quincena te dice cuánto puedes gastar tú. Se guardan solo en este dispositivo.';

  @override
  String standingNextCharge(String name, String amount, String date) {
    return 'El próximo: $name, $amount el $date';
  }

  @override
  String get homeTodoThen => 'Después';

  @override
  String todoLatePay(String date) {
    return 'Registra tu pago del $date';
  }

  @override
  String get todoLatePayBody =>
      'Todavía no aparece. Si ya llegó, regístralo para que cuente.';

  @override
  String get todoRecord => 'Registrar';

  @override
  String todoRates(int count, String codes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan las tasas de $codes',
      one: 'Falta la tasa de $codes',
    );
    return '$_temp0';
  }

  @override
  String todoRatesBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mientras tanto cuentan como cero en tus totales.',
      one: 'Mientras tanto cuenta como cero en tus totales.',
    );
    return '$_temp0';
  }

  @override
  String get todoSeeRates => 'Ver tasas';

  @override
  String get standingProvisional => 'Provisional: faltan tus pagos fijos';

  @override
  String get todoFixedTitle => 'Agrega tus pagos fijos';

  @override
  String todoFixedBody(String date) {
    return 'Lo que pagues hasta el $date sale de lo que puedes gastar.';
  }

  @override
  String get todoAdd => 'Agregar';

  @override
  String get noFixedPayments => 'No tengo pagos fijos';

  @override
  String get fixedNoneDone =>
      'Listo. Lo que puedes gastar ya no es provisional.';

  @override
  String get freeExplainAssumeNoFixed =>
      'No tiene pagos fijos: si pagas arriendo, servicios o suscripciones, agrégalos en Plan › Pagos fijos y saldrán de esta cifra antes de llegar.';

  @override
  String onboardingPayAmount(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'fortnight': '¿Cuánto te llega cada quincena?',
      'other': '¿Cuánto te llega cada pago?',
    });
    return '$_temp0';
  }

  @override
  String get onboardingPayAmountHelp =>
      'Opcional. No cuenta como plata hasta que llega; sirve para ver los días que vienen.';

  @override
  String get onboardingFixedTitle => '¿Qué pagas fijo?';

  @override
  String get onboardingFixedBody =>
      'Arriendo, servicios, celular, suscripciones. Quincena los resta de lo que puedes gastar antes de que lleguen.';

  @override
  String get fixedSuggestRent => 'Arriendo';

  @override
  String get fixedSuggestAdmin => 'Administración';

  @override
  String get fixedSuggestUtilities => 'Servicios';

  @override
  String get fixedSuggestInternet => 'Internet';

  @override
  String get fixedSuggestPhone => 'Plan del celular';

  @override
  String get fixedSuggestSubscription => 'Una suscripción';
}
