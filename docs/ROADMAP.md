# Roadmap

## Estado y alcance del plan

Las fases 5 a 15 están construidas y en `main`, y la build 11 de TestFlight
las lleva todas. Las fases 10 a 14 incorporan las 15 propuestas
del [registro de ideación](IDEAS_PRODUCTO.md), y la 15 es la sincronización
entre dispositivos. Construida no quiere decir validada: lo que falta probar
en dispositivos reales y con personas está en la puerta de calidad de abajo y
en [`QUALITY.md`](QUALITY.md). No hay fechas comprometidas. La versión
1.1.0, en curso, son las fases 16 a 19.

**Visión:** Quincena ayuda a decidir antes de gastar, además de explicar en qué
se fue la plata. Cada respuesta debe poder convertirse en una herramienta
interactiva, con cifras verificables y acciones bajo control de la persona.

**Orden de entrega:** las fases se construyeron en orden, cada una sobre la
anterior, y la primera versión de las tiendas las lleva todas. La puerta de
calidad de la fase 9 sigue siendo la condición para publicar.

Quincena started as a demo with a made-up account. It is becoming an app anyone
can use for their own money, on iOS, Android, the web and the desktop, with the
demo kept as a way to try it before entering anything.

## Decisions

**Data stays on the device.** Every platform keeps a local SQLite database. No
server holds anyone's movements. Sync between a person's devices comes later,
end-to-end encrypted.

**Gemini goes through Firebase AI Logic.** The app holds no key: requests go
through the project's Firebase AI Logic endpoint, protected by App Check, with
a daily limit per person. The model receives the figures a question needs,
worked out on the device by the same tools the agent already uses, and never
the database.

**Every account has its own currency.** Pesos, dollars, euros or a crypto asset
held on an exchange. Totals convert to a base currency the person chooses, with
the official TRM for dollars and market prices for crypto, cached for offline
use and overridable by hand.

**Movements come in from everywhere a bank leaves a trace.** Manual entry,
Apple Pay and bank notifications through iOS Shortcuts, Android notifications,
statements (PDF, Excel, CSV), bank alert emails and exchange APIs. Each source
writes to an inbox; a parser reads amount, currency, merchant and account; a
deduplicator merges what is the same purchase (one Apple Pay payment can arrive
four times: Wallet, the bank's push, an SMS and an email); and the person
confirms what the parser was not sure of.

**Open source, in this repository.** The demo account becomes "try it with
sample data".

## Phases

### 5. Foundation

A person installs Quincena, says how they get paid, adds their accounts in any
currency and records movements by hand. The home screen's "free until payday"
comes from their own data.

- Local database (drift) with accounts, movements, categories, budgets, goals,
  recurring charges, an inbox and exchange rates, with migrations.
- Money as a decimal amount and an asset, so a crypto balance keeps its
  precision and pesos never pass through a float.
- Onboarding: name, base currency, pay schedule (twice a month, monthly,
  biweekly, weekly), first accounts. Or the sample account.
- Movements: quick add, edit, delete, transfers between own accounts, including
  across currencies.
- Accounts with balances in their own currency and the total in the base one.
- Rates: TRM from datos.gov.co, crypto prices from Binance's public ticker.
- Export everything to a file, import it back, delete everything.

Done when someone with a peso account, a dollar account and USDT on Binance can
set up the app, record a week of movements and see the right totals, offline.

### 6. Automatic capture

- An inbox, "Por revisar", for everything that arrives from outside: confirm,
  edit, dismiss, mute the app that sent it, and record on its own what is
  clear, with undo.
- A parser for the alerts of the banks and wallets used in Colombia, and a
  deduplicator across sources and against movements entered by hand.
- iOS: a "Record a movement" App Intent that Shortcuts automations call without
  opening the app, for Wallet (Apple Pay), Message, Email and, from iOS 27,
  Notification. From iOS 27 a shortcut carries its own trigger, so the app
  offers ready ones, each added from an iCloud link and switched on with one
  toggle: the banks' notifications, bank texts that mention $, any Apple Pay
  card, and screenshots whose text, read on the phone first, shows $. iOS 26
  automations are still set up by hand, following the steps in the app.
- Android: a notification listener, opt-in, that keeps only notifications
  with an amount next to a currency, never security codes, and skips the
  apps the person mutes.
- Where a payment happened, when the alert does not say: the phone's
  location at that moment, kept on the device, and the shops within 80
  metres of it from OpenStreetMap through Photon, so "Compra POS 4512" can
  become a suggestion like "Éxito Laureles · Groceries". Off until the
  person turns it on; the coordinates are the only thing that leaves the
  device. On Android it needs "Allow all the time", and the app explains why
  before asking.
- Screenshots, photos, PDFs and texts of payments, read on the device (Vision
  on iOS and macOS, ML Kit on Android) and parsed by their labels: shared
  from any app on Android, picked in the inbox everywhere, and through a
  "Read a receipt" action in Shortcuts on iOS, which a shortcut can put in
  the share sheet or on Back Tap.

### 7. Gemini for everyone

- Firebase AI Logic in the quincena-dlsoft project, with Gemini 3.8 Flash and
  no key in the app. App Check is enforced, since Firebase switches AI Logic
  off without it: App Attest on iOS and macOS (the dev.dlsoft.quincena App
  ID has the capability), Play Integrity on Android, and debug tokens for
  simulators and emulators.
- Anonymous sign-in, a cap of 20 requests a minute per person set on the
  project, and 30 questions a day counted in the app.
- The conversation over the person's own accounts: the tools read the
  database as it is now, in whole units of the base currency, an `accounts`
  tool gives every account in its own currency, and recording an expense
  saves it for real.
- A plain-language note on what Gemini sees.
- The web too, with reCAPTCHA Enterprise for App Check and a key that only
  works on diegolopezrm.github.io.
- Firebase's Apple SDK, and every other plugin, through Swift Package
  Manager, with no CocoaPods left: Firebase published its last pods with
  12.19.0.
- The Blaze plan, with Gemini on Google Cloud's Agent Platform, which does
  not train on what it is sent, and the project's prompt cache off. A
  monthly budget with alerts and a spend cap that pauses Gemini when it is
  reached; the Gemini Developer API closed; email alerts, prompts kept out of
  Cloud Logging, and API keys restricted to the app.
  [PRODUCTION.md](PRODUCTION.md) says which limits stop spending and which
  only warn.
- Android release builds signed with an upload key kept outside the
  repository.
- Still open: the opt-out from Agent Platform's abuse logging, Play Integrity
  once the app is in the Play Console, and a daily limit per person on a
  server if 30 a day has to hold.

### 8. Investments, statements and exchanges

Built and released on the web and in TestFlight:

- A crypto portfolio. Every account in crypto, priced with Binance's public
  market data every 30 seconds while a screen shows it: its value in the base
  currency and in dollars, the last 24 hours, how it splits between coins and
  where each one is kept, and a chart from 24 hours to a year drawn with what
  was held at each moment.
- What each holding cost, followed from the money that went in: bitcoin
  bought with tether bought with pesos cost those pesos, with each day's TRM
  for the dollar side. Against it, the gain or loss while held, the gains
  already taken in sales and conversions, and what came in with no known
  cost, said apart.
- Purchases and sales recorded with their cost, paid from one of the
  person's accounts or outside them (Binance P2P, cash), and the cost of what
  an account started with. Buying or selling is neither spending nor income.
- Binance linked with a read-only API key, checked with Binance and refused
  if it can trade, move or withdraw, and kept in the device's keychain. Each
  sync reads every wallet's balances, P2P orders with what they cost in
  pesos, conversions, spot trades, deposits and withdrawals: a year back the
  first time, then since the last one. Each movement is recorded once, and
  every account ends holding what Binance says. Not on the web, where
  Binance does not answer a browser's signed requests.
- Gemini's `portfolio` tool, with the same figures and no advice on what to
  buy or sell.

- Bank and card statements: CSV and Excel read on the device, finding their
  columns by their headers in Spanish or English (one signed amount, or
  debits and credits, and a balance that gives positive amounts their sign);
  a PDF read row by row as it is printed, every page, on the device, and by
  Gemini only when the person asks. Each line is reviewed before it is
  saved: the merchant without the bank's words around it, a category the
  app already knows, and whether the account already has it within three
  days. Importing the same statement again adds nothing.
- A Binance P2P order and the bank's payment for it become one transfer, so
  the payment no longer counts as spending.
- Self-custody wallets by public address, read from public services:
  Bitcoin, Ethereum (ETH, USDT, USDC) and TRON (TRX, USDT, USDC).
- The chart's change over a range counts what prices made on what was held,
  not what was bought or sold in it.

Not done, and why:

- Bank alert emails. iOS 27's Email trigger only filters by sender or
  subject, so it cannot catch every bank's alerts without setting up each
  one, and reading a mailbox on the device needs the person's email password
  or Google's restricted Gmail scopes. The banks' notifications and texts,
  which the ready shortcuts and the Android listener already read, carry the
  same movements.
- Bitso and Buda. Their read-only APIs sign requests their own way; without
  an account to try them against, nothing could be verified, so they wait
  for one.

### 9. Release

- App Store, Google Play and the web, with store listings in Spanish and
  English.
- Privacy policy under Colombia's Ley 1581 de 2012, and the data controls the
  app already has (export, delete) linked from it.
- Google Play's declarations for notification access and background
  location, with the in-app explanations they ask for.
- The app's icon and name on the home screen.
- An iOS share extension, so Quincena is in the share sheet without a
  shortcut. It needs an App Group between the extension and the app, set up
  with the developer account the App Store needs anyway.

Built:

- The privacy policy, under Ley 1581 de 2012 with DL SOFT TECHNOLOGIES SAS
  as the party responsible, and a support page, in Spanish and English on
  the web. Settings links both, next to export and delete, and an export
  now carries what the app learned: capture rules and the wallets followed.
- The store listings in both languages, the answers to App Privacy and Data
  safety, the background location declaration and the review notes, in
  `docs/store/README.md`, with screenshots rendered from an example person.
- The iOS share extension: a screenshot, a photo, a PDF or a text shared
  from any app is read on the device and waits in "Por revisar". It shares
  the `group.dev.dlsoft.quincena` App Group with the app; Android already
  had its share target.
- The quality gate, recorded in `docs/QUALITY.md`: a build for every
  platform, the stores' and the model's requirements checked, nine screens
  held to the accessibility guidelines at twice the text size in both
  themes, imports that roll back whole, Gemini saying when there is no
  connection, no real data in fixtures or release logs, and "¿De dónde
  sale?" under the free amount, which shows each part of it and the rates
  behind it.

Left for the developer accounts: submitting to the App Store, creating the
app in Google Play with its upload key, and the checks on real devices that
`docs/QUALITY.md` lists.

#### Puerta de calidad del lanzamiento

- Verificar en dispositivos reales captura, permisos, funcionamiento sin red,
  recuperación tras cierre y comportamiento con permisos denegados.
- Probar migraciones y restauración con datos de versiones anteriores; una
  importación fallida no debe destruir la base existente.
- Unificar logo, iconos, pantallas de arranque, web, capturas y fichas de tiendas;
  verificar legibilidad en tamaños pequeños, tema claro y oscuro.
- Accesibilidad: lector de pantalla, texto grande, contraste, navegación por
  teclado cuando aplique y ninguna señal basada solo en color.
- Validar español e inglés, fechas, monedas y redondeos; sin datos reales en
  capturas de tienda, registros de diagnóstico ni fixtures.
- Hacer visibles los componentes de «libre hasta el próximo pago», la fecha de
  las tasas y el estado estimado de cualquier proyección. Permitir desactivar
  captura automática y corregir sus resultados.
- Revisar vigencia de requisitos de tiendas, SDK, modelos, privacidad y cuotas
  del proveedor antes de publicar; las versiones mencionadas arriba son
  decisiones a verificar, no garantías de disponibilidad futura.
- Registrar evidencia de pruebas y compilaciones por plataforma. Una función
  no compatible debe tener alternativa clara o declararse no disponible.

### 10. Confianza y un motor financiero explicable

**Estado:** construida en 2847859, build 6.

**Objetivo:** que todas las nuevas experiencias compartan cálculos consistentes
y que la persona pueda entender y corregir lo que hace la app.

**Dependencias:** base financiera (5), captura (6) y herramientas de Gemini (7).

- **Idea 11 — ¿De dónde salió este número?** Desplegar movimientos, período,
  fórmula, origen y fecha de tasas detrás de cada cifra agregada, incluidas las
  respuestas de Gemini. Empezar por disponible, saldos y conversiones.
- **Idea 15 — Captura que aprende contigo.** Ofrecer reglas de comercio,
  categoría y cuenta después de una corrección. Listarlas, editarlas,
  desactivarlas y explicar qué regla actuó. Mantener excepciones por revisar.
- Motor local de proyecciones que separe saldo real, ingreso confirmado,
  ingreso esperado, obligaciones, reservas y escenarios hipotéticos.
- Definir cómo se calcula el disponible: horizonte de fechas, cuentas incluidas,
  compromisos, colchón y reservas sin doble conteo. Mostrar los supuestos.
- Las herramientas calculan con precisión monetaria; Gemini explica sus
  resultados. La funcionalidad esencial no depende de que el modelo responda.

**Criterios de terminado:**

- Una cifra y su desglose coinciden con y sin conexión; al corregir un movimiento
  se actualizan todas las vistas que dependen de él.
- Pruebas cubren múltiples monedas, redondeos, transferencias, datos incompletos,
  ingreso retrasado y ausencia de historial.
- Cada captura automática indica por qué se registró y ofrece corrección o
  deshacer. Cambiar una regla no reescribe el historial silenciosamente.

### 11. Decidir antes de gastar

**Estado:** construida en f6c1fe2, build 7.

**Objetivo:** entregar el primer conjunto diferencial de uso cotidiano.

**Dependencias:** motor y trazabilidad de la fase 10; calendario de pagos y
recurrencias confirmadas. La entrada manual debe funcionar sin Gemini.

- **Idea 1 — ¿Me lo puedo comprar?** Introducir precio, moneda, cuenta y fecha;
  comparar comprar hoy frente a después del próximo pago. Mostrar obligaciones,
  colchón y mínimo de saldo proyectado, con controles de precio y fecha.
- **Idea 2 — Calendario de días apretados.** Vista inicial de 30 días con saldo
  proyectado, ingresos y pagos. Identificar fechas bajo el colchón y abrir el
  detalle de lo que causa la caída. Mover fechas solo dentro de una simulación.
- **Idea 5 — Cierre de quincena en tres tarjetas.** Qué cambió, qué viene y una
  acción posible. Comparar períodos equivalentes y enlazar cada conclusión con
  sus movimientos. Resumen dentro de la app y recordatorio opcional.

**Criterios de terminado:**

- Compra y calendario usan el mismo cálculo; cambiar precio o fecha actualiza
  ambos sin llamadas adicionales al modelo.
- Sin información suficiente se pide completarla o se muestra un escenario
  limitado; nunca se garantiza que una compra sea segura.
- La simulación no crea movimientos ni cambia pagos reales. El resumen funciona
  con historial escaso sin inventar tendencias.
- Recordatorios desactivables y sin importes sensibles en pantalla bloqueada.

### 12. Planear la quincena y avanzar hacia metas

**Estado:** construida en 068ba97, build 8.

**Objetivo:** convertir ingresos y aspiraciones en un plan ajustable.

**Dependencias:** fases 10–11 y metas/presupuestos existentes.

- **Idea 3 — Me llegó la quincena.** Al confirmar un ingreso, proponer una
  distribución entre compromisos, gastos cotidianos, metas y dinero libre.
  Editar importes, guardar y reutilizar una plantilla de sobres virtuales.
- **Idea 4 — ¿Y si…?** Comparar escenario actual y alternativo: ahorro adicional,
  subida de arriendo o retraso de ingresos. Empezar por una variable y ampliar
  a escenarios guardados con supuestos visibles.
- **Idea 10 — Colchón en días de tranquilidad.** Traducir una reserva elegida a
  días estimados de gastos esenciales, usando categorías confirmadas y un
  período visible. Meta configurable, sin cifra universal impuesta.
- **Idea 13 — Lo quiero, pero después.** Lista de deseos con precio manual,
  prioridad y espera opcional; comparar una compra con el avance de otra meta.
  Sin rastreo de tiendas ni incentivos de afiliación en el alcance inicial.

**Criterios de terminado:**

- Las asignaciones no superan el dinero asignable sin advertencia explícita;
  sobres y cuentas no cuentan la misma plata dos veces.
- Los sobres no se presentan como transferencias bancarias. Guardar un escenario
  no lo aplica al presupuesto; aplicar cambios requiere confirmación.
- Un gasto esencial promedio cero o historial insuficiente produce una
  explicación, no infinitos días de cobertura.
- Deseos y simulaciones no alteran saldos; fechas de metas se recalculan con
  los mismos supuestos del plan.

### 13. Compromisos, cuotas y cargos bajo control

**Estado:** construida en 24f0408, build 9.

**Objetivo:** entender cuánto dinero futuro ya está comprometido.

**Dependencias:** fases 10–12, recurrencias y conciliación de movimientos.

- **Idea 6 — Suscripciones con memoria.** Próximas renovaciones, fin de pruebas,
  cambios de precio y recordatorios configurables. La persona confirma si las
  usa. Mostrar ahorro potencial al pausar, sin prometer cancelar por ella.
- **Idea 7 — Compras a cuotas, sin sorpresas.** Registro manual de principal,
  cuotas, tasa y cargos; calendario de pagos, saldo pendiente y total estimado.
  Comparar contado y cuotas, declarando modalidad y periodicidad de la tasa.
- **Idea 12 — Detective de cargos.** Reglas locales para posibles duplicados,
  aumentos de recurrencias y movimientos atípicos. Mostrar evidencia y permitir
  marcar como esperado, investigar o descartar la alerta.

**Criterios de terminado:**

- Diferenciar compra, deuda y pago de tarjeta para no duplicar gastos. Probar
  pagos parciales, cambios de importe y cancelación de una recurrencia.
- No calcular un costo total definitivo cuando faltan tasa o comisiones;
  distinguir expresamente lo conocido de lo estimado.
- Distinguir dos capturas del mismo cargo de dos cargos bancarios reales.
  Ninguna alerta borra movimientos ni declara fraude automáticamente.
- Todas las alertas son explicables y silenciables; un cargo recurrente no
  prueba que el servicio esté sin uso.

### 14. Finanzas que se adaptan a la vida real

**Estado:** construida en 7f3c700, build 10.

**Objetivo:** añadir módulos opcionales sin complicar la experiencia básica.

**Dependencias:** fases 10–13, cuentas multidivisa y proyecciones.

- **Idea 8 — Plata que te deben y gastos compartidos.** Dividir un gasto en
  partes iguales o personalizadas; separar gasto propio de cuenta por cobrar;
  registrar devoluciones parciales y liquidar grupos pequeños. Funcionar sin
  exigir que los demás instalen Quincena. Redactar recordatorios para compartir
  solo cuando la persona decida enviarlos.
- **Idea 9 — Modo independiente.** Diferenciar cobrado, pendiente y estimado;
  fechas previstas y vencidas, reservas configurables y un escenario conservador
  elegido por la persona para meses de ingresos variables. Sin cálculo tributario
  automático en el alcance inicial.
- **Idea 14 — Bolsillo de viaje.** Presupuesto etiquetado, moneda local y base,
  gasto diario y restante. Integrar gastos compartidos cuando se habiliten;
  tasas con fecha, comisiones conocidas y posterior ajuste al cargo real.

**Criterios de terminado:**

- Una devolución reduce lo pendiente sin inventar ingresos ni duplicar el gasto;
  las divisiones conservan el total, incluido el residuo de redondeo.
- Dinero por cobrar nunca aparece como efectivo disponible. Retrasar un cobro
  modifica la proyección, no el saldo real.
- Un viaje usa los mismos movimientos del libro principal, no una copia;
  conversiones y diferencias contra el cargo final son trazables.
- Cada módulo se puede omitir; no exige permisos, contactos ni servicios externos
  que no sean necesarios para la función elegida.

### 15. Continuidad entre dispositivos

**Estado:** construida en 3beda3c, build 11. El diseño, el modelo de amenazas y
las dos revisiones de seguridad están en [`SYNC.md`](SYNC.md); falta probarla
entre dispositivos reales.

**Objetivo:** desarrollar la sincronización cifrada ya prevista, sin perder el
principio de datos locales ni convertirla en requisito para usar la app.

**Dependencias:** esquema estable, identificadores consistentes, migraciones y
exportación/restauración probadas. Puede investigarse en paralelo al producto,
pero requiere diseño y revisión de seguridad antes de implementarse.

- Diseñar identidad, vinculación de dispositivos, gestión de claves y recuperación;
  explicar qué ocurre si se pierde un dispositivo o la clave de recuperación.
- Sincronización opcional con cifrado de extremo a extremo; documentar qué
  metadatos quedan fuera del cifrado y cómo se minimizan.
- Resolver conflictos, ediciones simultáneas, duplicados y eliminaciones sin
  resucitar datos borrados ni perder cambios silenciosamente.
- Revocar dispositivos y definir eliminación de copias remotas, retención y
  límites de recuperación. La copia local sigue funcionando sin red.

**Criterios de terminado:** dos dispositivos convergen después de editar sin
conexión; pruebas de conflictos, restauración, revocación y borrado pasan;
revisión de seguridad completada y ninguna clave secreta expuesta al servidor.
No confundir sincronización con copia de seguridad: documentar ambas garantías.

## Versión 1.1.0

La 1.0 salió a revisión en las dos tiendas el 2 y el 3 de octubre de 2026.
La 1.1.0 junta dos fuentes: lo que quedó abierto al publicar (cumplimiento,
costos de Gemini, respaldo y validación) y una revisión externa de
experiencia sobre las pantallas de la 1.0. Su conclusión, que esta versión
adopta como principio: **cada pantalla debe decir qué significa el dinero y
cuál es la siguiente decisión útil, sin obligar a interpretar números.**

Las prioridades de esa revisión ordenan las fases: la 16 es lo que debe
estar antes de mostrarla a más personas, la 17 lo que la hace sentir buena y
la 18 el pulido. La 19 recoge lo demás. Cada fase cierra con pruebas, un
commit en `main` y una build en TestFlight.

### 16. Que el dinero se entienda solo

**Estado:** construida, build 14 (1.1.0).

**Objetivo:** que nadie tenga que preguntarse cuánto tiene, cuánto puede
gastar y hasta cuándo.

- Un solo formato: `$299.900` sin espacio, `+$85.000` y `−$63.200` con el
  signo menos de verdad, `+6,98 %` y `3 oct · 9:40 a. m.`; en inglés, sus
  equivalentes. Una sola función por tipo de dato, sin excepciones sueltas.
- Inicio: una sola cifra para gastar, "Puedes gastar $299.900 hasta el 15
  de octubre", con su cuenta debajo (disponible hoy, pagos antes del pago,
  colchón y sobres si los hay) en lugar de "Para gastar" compitiendo con
  ella. La barra dice sus valores ("$299.900 libres · $26.900
  comprometidos"). "Tu próxima quincena llega en 12 días" cuando a la
  persona le pagan por quincena; "tu próximo pago" en los demás casos.
- "Por hacer": los avisos de Inicio (movimientos por revisar, llegó la
  quincena) como una sección de filas con su acción escrita ("Revisar",
  "Organizarla"), no como tarjetas que compiten.
- Cuentas: patrimonio como activos menos deudas, lo disponible para gastar
  aparte, y las tarjetas de crédito como deudas ("Debes $480.000", y el
  cupo disponible si la persona lo dio). Las tasas, en una línea por moneda
  con "Ver todas"; la edición, en su propia pantalla.
- Por revisar: una acción principal por tarjeta, "Editar" y un menú para lo
  demás; "Sugerencia: Mercado, porque ya registraste Éxito Laureles" en vez
  de "Por qué"; y ante un ingreso, la pregunta "¿Es plata tuya que viene de
  otra cuenta?", para no contar como ingreso una transferencia propia.
- Importar extracto: cuántos movimientos son nuevos, cuántos parecen
  repetidos y cuántos necesitan revisión antes de importar; "Seleccionar
  todos"; y al terminar, qué quedó y un enlace a lo que falta revisar.
- Crédito a OpenStreetMap donde aparece un comercio sugerido por ubicación,
  y el aviso de ubicación con la frase que pide Google ("incluso cuando la
  app está cerrada o no se usa").

**Criterios de terminado:** las capturas de Inicio, Cuentas y Por revisar
en los dos idiomas pasan la prueba de accesibilidad; una prueba recorre
cada pantalla buscando montos con otro formato; lo libre, lo disponible y
el patrimonio cuadran en "¿De dónde sale?".

### 17. Decidir antes de gastar

**Estado:** construida, build 15 (1.1.0). Queda abierto: la plata que alguien
te presta y llega a una de tus cuentas no tiene todavía cómo registrarse sin
contar como ingreso; "Me prestaron" anota la deuda.

**Objetivo:** que Inicio sea un resumen del día y que las respuestas
empiecen por la conclusión.

- "Próximos días" en Inicio: hoy, cada cobro y el próximo pago en una línea
  de tiempo, con "Tu punto más bajo será $299.900 el 12 de octubre".
- "¿Me alcanza para…?" visible en Inicio, con el precio a la mano.
- Respuestas de Gemini: primero la conclusión ("No con tu ahorro actual: te
  faltan $350.000 al mes para el 20 de diciembre"); la meta muestra lo que
  falta además del porcentaje; el control de ahorro dice en vivo cuándo se
  llega, marca el monto necesario y se detiene ahí con una vibración leve;
  las oportunidades de ahorro dicen "Podrías liberar hasta $409.200" con su
  desglose, sin dar por hecho que la persona quiera cancelar algo.
- Preguntas sugeridas en la barra de Gemini, según lo que hay en la cuenta.
- Cripto: "Hoy" y "Ganancia total" separados; la gráfica muestra el
  rendimiento (solo el precio) por defecto y el valor del portafolio como
  segunda vista; la conexión con Binance dice en palabras simples que solo
  lee y nunca mueve fondos.
- Estados vacíos, de carga (esqueletos y los datos anteriores visibles con
  "Actualizando…") y de error que dicen qué falló y de cuándo son los
  datos que se ven.
- El botón de agregar dice qué agrega ("Movimiento") y "Le presté / Me
  prestaron" en gastos compartidos, sin pasar por "tu parte en 0".

**Criterios de terminado:** pruebas de widget del control de ahorro, la
línea de tiempo y los estados vacío y de error; las cinco respuestas de la
demo empiezan por su conclusión.

### 18. Pulido

**Estado:** construida, build 16 (1.1.0).

- El verde queda para la acción principal y lo positivo; las acciones
  secundarias, en neutro.
- Menos tarjetas y menos relleno: métricas y encabezados sin borde,
  tarjetas solo para lo que se toca o se agrupa, unos 20 % menos de espacio
  vertical.
- Tipografía más liviana: cifras grandes en 700 a 800, títulos en 600 a
  700, texto en 400 a 500.
- Animaciones que explican un cambio (confirmar un movimiento, mover el
  control de ahorro, importar), háptica leve y respeto por "reducir
  movimiento".
- La frase que ordena el producto en fichas y web: "Quincena sabe cuánto
  puedes gastar sin dañar tus planes".

### 19. Respaldo, costos y alcance

**Estado:** construida, build 17 (1.1.0). Quedan decisiones de Diego: la
caché de prompts y el límite en el servidor; y la validación con personas.

- Respaldo cifrado: exportar sale sellado con un código propio, como el de
  la sincronización, salvo que la persona elija el JSON legible. El primer
  respaldo muestra el código; abrirlo en otro teléfono lo pide, y ningún
  código de sincronización abre un respaldo ni al revés. Diseño en
  [`SYNC.md`](SYNC.md).
- Widget de "Puedes gastar" en iOS y Android: dice lo mismo que Inicio,
  avisa cuando la cifra es de otro día y puede ocultar los montos, que
  entonces ni se guardan para el widget.
- Gemini más barato: el prompt pasó de 19.080 a 11.822 tokens por ronda,
  contados por el modelo, con los mismos esquemas en una línea. Dos
  preguntas de Inicio, hechas en vivo, costaron US$0,024 y US$0,041 en vez
  de US$0,035 y US$0,052. La caché de prompts queda a decisión de Diego
  ([`PRODUCTION.md`](PRODUCTION.md)).
- Límite diario en el servidor: diseñado en
  [`SERVER_LIMIT.md`](SERVER_LIMIT.md), una función delante de Gemini que
  cuenta rondas y tokens por persona y un techo diario para todos. Se
  decide antes de construirla.
- Validación: lo que falta probar en dispositivos reales está en
  [`QUALITY.md`](QUALITY.md), y la prueba cerrada con personas durante dos
  quincenas, en [`CLOSED_TEST.md`](CLOSED_TEST.md).
- En la web, lo que depende del teléfono sigue fuera por diseño: captura
  automática, leer fotos en el dispositivo, Binance, sincronización,
  recordatorios y el widget.

### Segunda revisión de claridad

El 4 de octubre llegó una segunda revisión externa, sobre las capturas de
la 1.1 y la demo web ([texto completo](reviews/2026-10-04-claridad.md)).
De sus 70 puntos ninguno estaba resuelto del todo: 37 quedaban a medias y
30 eran nuevos. No eran solo textos. También había errores de datos:
- volver a la tasa automática sin conexión borraba la tasa;
- "Seleccionar todos" marcaba también los repetidos de un extracto;
- un pago de tarjeta importado del banco contaba como gasto doble;
- un formulario del chat se podía guardar dos veces.

Las fases 20 a 24 siguen las prioridades del revisor. Las de un mismo
momento se construyen en ramas separadas que se unen en `main` antes de
cerrar.

**Glosario único, para la app, el prompt y las fichas:**
- **"Puedes gastar {X} hasta el {fecha}":** la cifra para gastar. Nunca
  "libre" ni "disponible".
- **"En tus cuentas de uso diario":** el saldo de lo que cuenta para gastar.
- **"Lo que debes en tarjetas":** la deuda de tarjetas.
- **"Pagos hasta el {fecha}":** lo que sale antes del pago. Incluye el día
  del pago.
- **"Reserva de ingresos variables":** la reserva.
- **"Saldo mínimo estimado":** el mínimo proyectado.
- **En inglés:**
  - "You can spend… until"
  - "everyday accounts"
  - "transaction"
  - "safety buffer"
  - "installments"
  - "recurring payments"
  - "Needs review"

### 20. Qué significa cada cifra

**Estado:** construida, build 19 (1.1.0). El prompt pasó de unos 11.800 a
unos 12.500 tokens por ronda (estimado por tamaño).

- **Inicio:**
  - La cuenta de "Puedes gastar" separa "En tus cuentas de uso diario" de
    "Lo que debes en tarjetas", en lugar de restar la tarjeta en silencio.
  - "¿De dónde sale?" está también en la demo y cuenta los movimientos que
    esperan revisión.
  - La quincena que llegó dice monto, fecha y cuenta.
- **Patrimonio:** también resta lo que debes en gastos compartidos y lo
  que falta de cuotas pagadas por fuera de una tarjeta, y suma lo que te
  deben.
- **Tasas:**
  - Volver a la tasa automática trae la nueva antes de soltar la manual.
  - Se ve cuál es manual.
  - Cada paso de una conversión va en su propia línea.
  - En Cuentas quedan plegadas en "Ver tasas usadas".
- **Cripto:**
  - "Sin dato" en vez de un 0 % inventado.
  - "Ganancia no realizada" sin los saldos que llegaron sin precio de
    compra, y con las comisiones dentro del costo.
  - La TRM aparece con su fecha.
  - El rendimiento es ponderado en el tiempo.

### 21. Simular no es guardar

**Estado:** construida, build 19 (1.1.0). Las metas cuentan sus aportes el
16 de cada mes; las metas propias con otro día quedan para cuando los
avisos de meta existan.

- **La meta:**
  - La respuesta dice cuánto hace falta al mes y en qué fechas.
  - El control simula: "Simulación · hoy apartas…", con "Volver a…",
    escribir un monto y "Usar $600.000 al mes".
  - El control explica qué le pasa a lo que puedes gastar.
  - "Guardar este plan" guarda de verdad, también con Gemini.
  - Un plan guardado no baja "Puedes gastar"; llenar el sobre de metas es
    el paso siguiente.
- **Formularios del chat:** se guardan una sola vez y quedan como
  comprobante. "Editar" reemplaza el movimiento, no lo duplica.
- **Suscripciones:**
  - Se marcan con casillas.
  - Pasan por "Antes de cancelar" y terminan en "Ya las cancelé".
- **Lo que la app no hace:** ninguna respuesta promete mover plata,
  apartarla, avisar o cancelar. Los avisos de meta quedan para la 1.2.
- **La conversación:**
  - No salta mientras lees.
  - "Nueva" deja volver a la anterior.

### 22. Inicio y Cuentas en orden, nada tapado

**Estado:** construida, build 19 (1.1.0). La tarjeta de Inicio bajó de unos
390 a 324 pt, no a 265: "¿De dónde sale?" necesita 48 pt de toque junto a la
etiqueta, y bajarla más pide moverlo; queda a decisión de Diego.

- **Botón de agregar:**
  - Se oculta al bajar.
  - En Cuentas y Plan pasa a ser un botón dentro de la página.
- **Inicio:**
  - Sin saludo en modo propio.
  - Muestra el próximo pago.
  - "Por hacer" queda en orden de prioridad.
  - La tarjeta es unos 95 pt más baja.
- **Cuentas:**
  - Primero uso diario, luego tarjetas, ahorros y Cripto.
  - El cupo de las tarjetas, como dato opcional (esquema v3).
- **Plan:** queda en cuatro grupos.
- **Cripto:** la gráfica va antes que las conexiones.
- **Onboarding:**
  - Pregunta los pagos fijos.
  - Dice cuándo la cifra todavía es provisional.

### 23. Por revisar e importar con menos lectura

**Estado:** construida, build 19 (1.1.0).

- **Importar extracto:**
  - Los repetidos no se marcan solos.
  - Se ven los totales de lo seleccionado y el saldo antes y después.
  - Cada línea se puede editar.
  - Un pago de tarjeta entra como transferencia.
  - Con movimientos anteriores al saldo que escribiste, se pregunta si
    ese saldo ya los incluye.
- **Por revisar:**
  - Dos grupos: "Listos para registrar" y "Necesitan información".
  - El botón dice lo que hace.
  - Siempre se puede deshacer.
  - Los listos se registran en conjunto cuando son dos o más.

### 24. Inglés, accesibilidad y capturas

**Estado:** construida, build 19 (1.1.0). El atajo de iOS cambió de nombre
("Record a transaction") y falta probarlo en un dispositivo; lo demás que
pide un teléfono real está en [`QUALITY.md`](QUALITY.md).

- **El inglés:**
  - Sigue el glosario también en el atajo de iOS, la web y las fichas.
  - Usa un solo formato de porcentajes y ordinales.
- **Texto grande:** hasta el tamaño más grande de iOS.
- **Listas:** las listas largas se construyen a medida que se ven.
- **Capturas:**
  - Las de tienda se regeneran con precios fijos.
  - Ninguna captura de tienda muestra 0 % por no leer precios.

### 25. Flujo por flujo

**Estado:** construida, build 20 (1.1.0).

Cada cosa que una persona puede hacer en la app es un flujo en
`integration_test/flows/`:
- Tiene un objetivo en primera persona.
- Lleva una foto por paso, con una línea que dice qué se hizo y qué
  mirar.
- Trae comprobaciones sobre los datos de verdad: montos exactos, registros
  creados o borrados, "Deshacer" que deja todo como estaba, ajustes que se
  guardan.

Son 181 flujos, con 1.168 pasos y 1.210 comprobaciones:
- Sin teléfono corren con `test_screens/flows_check_test.dart`.
- En un simulador propio corren con `tool/flows/run.sh`, que arma una
  imagen por flujo para que la revisen expertos.

Escribirlos sacó a la luz cerca de cien errores, todos corregidos con su
prueba. Entre ellos:
- "Borrar todo" dejaba avisos programados y la llave de Binance.
- Pagar la tarjeta desde el banco no bajaba lo que se le debe.
- "¿Me alcanza?" no descontaba la reserva ni los sobres.
- El sobre "Día a día" decía "Te pasaste" recién repartido.

Las cuentas cerradas ahora se archivan en vez de borrarse.

El 9 de octubre los 181 flujos se jugaron en un iPhone 17 Pro simulado y
quedaron en una página para que expertos digan, flujo por flujo, si se
entiende. Lo que dejó esa corrida y el plan que se propone después están en
[la revisión flujo por flujo](reviews/2026-10-09-flujo-por-flujo.md).
- Sin teléfono, `test_screens/flows_keyboard_test.dart` juega los flujos con
  el teclado abierto mientras un campo tiene el foco, en un iPhone 17 Pro o
  en un SE.
- En el SE encontró cuatro cuadros que no cabían y no se podían desplazar.
  Los diez cuadros que piden un dato ahora se desplazan cuando no caben.

El mismo día llegó la primera revisión de un experto sobre los 181 flujos
([texto completo](reviews/2026-10-09-experto.md)). De sus 34 afirmaciones
sobre cómo funciona hoy la app, 21 resultaron ciertas, 12 lo son en parte y
1 no. El plan propuesto, de la fase 27 a la 37, sigue su orden: primero la
confianza en las cifras, después que la app haga el trabajo y al final el
pulido.

### 26. Lo que pidieron las tiendas

**Estado:** construida, build 20 (1.1.0), enviada a las dos tiendas el 8
de octubre. En App Store, la 1.1.0 volvió a revisión con la respuesta a
Apple; en Google Play, la versión 20 reemplazó a la 13 con las capturas,
las instrucciones de acceso y la declaración de ubicación con el video
nuevo. Detalle en `docs/store/README.md`.

El 6 de octubre Google Play rechazó la versión de Android por dos
motivos:
- **Aviso de ubicación:** el permiso de ubicación del sistema salía sin un
  aviso propio antes.
- **Capturas:** mostraban la app completa, y "Con datos de ejemplo" abría
  solo una conversación.

El 8 de octubre Apple rechazó la 1.0 por la pauta 5.6: le pareció que la
app escondía funciones durante la revisión. La causa era la misma que la
de las capturas.

Lo que cambió:
- **"Con datos de ejemplo":** abre toda la app con la cuenta inventada de
  Valentina.
  - La cuenta vive en memoria y se borra al salir.
  - Una franja visible dice que es el ejemplo.
  - La conversación responde con las mismas cifras de las pantallas.
  - Hay un extracto y un mensaje de banco para probar sin archivos.
  - Nada toca los datos, avisos, widget, llavero o sincronización de la
    persona.
- **Capturas de tienda:** salen de ese mismo modo, así que no pueden
  mostrar algo que la app no tenga.
- **Aviso de ubicación:** antes de cualquier permiso de ubicación o de
  acceso a notificaciones sale un aviso que dice qué se recoge, para qué,
  cuándo y a dónde va. Solo "Aceptar" lleva al permiso, y el de "Permitir
  todo el tiempo" tiene su propio aviso.
- **Opciones de desarrollador:** "Quién responde", una key propia de
  Gemini, el inspector y las sesiones grabadas quedan solo en la demo web,
  que es la vitrina para desarrolladores. Las apps de las tiendas son el
  producto.
- **Notas para los revisores:** dicen dónde está cada pantalla de las
  capturas y cómo probar los atajos de iOS y la extensión de compartir.

## Trazabilidad de las 15 ideas

Los números conservan la referencia del [registro de ideación](IDEAS_PRODUCTO.md).
Todas están construidas, en la fase que indica la tabla.

| Idea | Entrega prevista | Fase |
|---|---|---|
| 1 | ¿Me lo puedo comprar? | 11 |
| 2 | Calendario de días apretados | 11 |
| 3 | Me llegó la quincena / sobres virtuales | 12 |
| 4 | Simulador ¿y si…? | 12 |
| 5 | Cierre en tres tarjetas | 11 |
| 6 | Suscripciones con memoria | 13 |
| 7 | Compras a cuotas | 13 |
| 8 | Dinero por cobrar y gastos compartidos | 14 |
| 9 | Modo independiente | 14 |
| 10 | Colchón en días | 12 |
| 11 | Trazabilidad de cifras | 10 |
| 12 | Detective de cargos | 13 |
| 13 | Lista de deseos | 12 |
| 14 | Bolsillo de viaje | 14 |
| 15 | Reglas de captura visibles | 10 |

## Reglas de ejecución y validación

- Antes de cada fase, acordar alcance y responsable; evitar ediciones
  simultáneas sobre los mismos archivos.
- Desglosar la fase en cambios pequeños: modelo/migración, cálculo, interfaz,
  herramientas del agente, localización, pruebas y documentación.
- Validar primero con datos ficticios y prototipos. Las experiencias financieras
  deben funcionar mediante controles normales, no solo conversación con Gemini.
- Cada entrega necesita pruebas de cálculo, integración, accesibilidad y estados
  vacío, error, sin conexión y permisos denegados según corresponda.
- Mantener migraciones compatibles y exportación/restauración actualizadas con
  cada dato nuevo. No guardar secretos ni movimientos reales en logs.
- No ejecutar pagos, inversiones, cancelaciones o mensajes sin autorización;
  ninguna de estas fases incorpora ejecución bancaria automática.
- No usar culpa, rankings de riqueza, rachas punitivas ni promesas de predicción
  exacta. Explicar alternativas, incertidumbre y supuestos.
- Medir comprensión del disponible, capacidad de explicar un cálculo, tiempo
  para revisar capturas, correcciones necesarias y utilidad durante dos
  quincenas. No optimizar solo tiempo en pantalla ni recopilar datos financieros
  para analítica sin consentimiento.
- Establecer objetivos medibles después de obtener una línea base con usuarios;
  registrar hallazgos y ajustar alcance antes de ampliar cada módulo.
- Marcar una entrega como terminada solo con evidencia de pruebas y señalar
  por separado su disponibilidad local, en beta y publicada por plataforma.
