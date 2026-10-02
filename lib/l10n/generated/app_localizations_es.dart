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
  String get problemLimit =>
      'Ya usaste las preguntas de hoy. Mañana puedes seguir preguntando.';

  @override
  String get askTitle => 'Pregúntale a tu plata';

  @override
  String get askYourMoneyLabel => 'Pregúntale a tu plata';

  @override
  String get ownAskFree => '¿Cuánto me queda libre hasta el pago?';

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
      'Gemini no recibe tu base de datos. Pide las cifras que necesita a herramientas que corren en tu teléfono, y lo que viaja son sus respuestas: tus totales por categoría y por mes, lo libre hasta el pago, tus suscripciones, tu meta de ahorro, tus cuentas con su saldo y, cuando la pregunta lo pide, los pagos más grandes de un mes con su comercio.';

  @override
  String get geminiNoteNot =>
      'No viajan tus otros movimientos uno por uno, ni tus notas, ni las alertas de tu banco, ni tu ubicación.';

  @override
  String get geminiNoteTerms =>
      'Quincena usa por ahora el nivel gratuito de la API de Gemini. En ese nivel Google puede usar lo que se envía para mejorar sus productos, y personas pueden revisarlo. No escribas en una pregunta nada que no quieras compartir, como un número de cuenta.';

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

  @override
  String get inboxTitle => 'Por revisar';

  @override
  String inboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimientos por revisar',
      one: 'Un movimiento por revisar',
    );
    return '$_temp0';
  }

  @override
  String get inboxBannerBody => 'Llegaron de tus notificaciones y mensajes.';

  @override
  String get inboxEmpty => 'Nada por revisar.';

  @override
  String get inboxEmptyBody =>
      'Cuando llegue un pago de tu banco, aparece aquí para confirmarlo.';

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
  String get chooseAccount => 'Elige la cuenta';

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
    return 'Cerca: $name, a $metres m';
  }

  @override
  String get possibleDuplicates => 'Posibles repetidos';

  @override
  String get duplicateLine => 'El mismo pago ya llegó por otra vía.';

  @override
  String get notDuplicate => 'No es repetido';

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
      'Cuando la alerta no dice dónde fue, Quincena busca los comercios a unos metros de donde estaba el teléfono. La ubicación se guarda solo aquí; para buscar los comercios se envían únicamente las coordenadas a OpenStreetMap, a través de Photon.';

  @override
  String get captureLocationDenied =>
      'Quincena no tiene permiso para usar la ubicación. Puedes darlo en los ajustes del teléfono.';

  @override
  String get openPhoneSettings => 'Abrir ajustes';

  @override
  String get captureAlwaysTitle => 'Ubicación con la app cerrada';

  @override
  String get captureAlwaysBody =>
      'Los pagos casi siempre llegan con Quincena cerrada. Para saber dónde estabas en ese momento, Android pide elegir «Permitir todo el tiempo». Quincena solo mira la ubicación cuando llega una notificación de pago.';

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
}
