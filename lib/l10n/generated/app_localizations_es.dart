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
      'Con esto Quincena calcula cuánto tienes libre hasta el próximo pago.';

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
  String get accountSpendable => 'Cuenta para gastar';

  @override
  String get accountSpendableHelp =>
      'Su saldo cuenta en lo que tienes libre hasta el próximo pago. Apágalo para ahorros, inversiones y cripto.';

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
  String get groupSpendable => 'Para gastar';

  @override
  String get groupSaved => 'Ahorros, inversiones y cripto';

  @override
  String get netWorth => 'Todo lo que tienes';

  @override
  String get noAccounts => 'Aún no tienes cuentas.';

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
  String get rateManual => 'Escrita a mano';

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
    return '$asset se cuenta como un dólar.';
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
  String get noMovements => 'Aún no hay movimientos.';

  @override
  String get noMovementsBody =>
      'Registra un gasto, un ingreso o una transferencia con el botón +.';

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
  String importFailed(String reason) {
    return 'Ese archivo no se pudo leer: $reason';
  }

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
      'Tus cuentas y movimientos se guardan solo en este dispositivo. Para las tasas, Quincena consulta fuentes públicas (la TRM, Binance y el Banco Central Europeo) sin enviar nada tuyo.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String standingDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Faltan $days días para el próximo pago.',
      one: 'Falta un día para el próximo pago.',
      zero: 'Hoy es día de pago.',
    );
    return '$_temp0';
  }

  @override
  String standingCommittedOwn(String committed) {
    return '$committed ya están comprometidos en pagos programados.';
  }
}
