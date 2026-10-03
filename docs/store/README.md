# Store listings

What Quincena says about itself in the App Store and Google Play, the
answers to their privacy forms, and the screenshots. The screenshots come
from `test_screens/store_screens_test.dart`, with an example person,
Valentina, and never anyone's real data:

```bash
flutter test test_screens/store_screens_test.dart --update-goldens
```

which writes them straight into `screenshots/`.

| Store | Size | Folder |
| --- | --- | --- |
| App Store, 6.9-inch iPhone | 1320 × 2868 | `screenshots/appstore/{es,en}` |
| App Store, 13-inch iPad | 2064 × 2752 | `screenshots/appstore-ipad/{es,en}` |
| Google Play, phone | 1080 × 2400 | `screenshots/play/{es,en}` |

Their order: a generative answer, the home screen, what was caught to
review, crypto, a statement being imported, and the accounts.

## Links

| | Spanish | English |
| --- | --- | --- |
| Privacy policy | https://diegolopezrm.github.io/quincena/privacidad/ | https://diegolopezrm.github.io/quincena/privacy/ |
| Support | https://diegolopezrm.github.io/quincena/soporte/ | https://diegolopezrm.github.io/quincena/support/ |
| Marketing | https://diegolopezrm.github.io/quincena/ | the same |

The party responsible for the data is DL SOFT TECHNOLOGIES SAS, with
admin@dlsoft.dev for requests.

## App Store

App Store Connect: "Quincena: tu plata", ID 6818576351, primary language
Spanish (Mexico), adding English (U.S.). Category Finance; secondary,
Productivity. Free, in every country but France.

**Encryption.** Sync files are sealed with XChaCha20-Poly1305 from a Dart
library: a standard algorithm, not the one in Apple's operating system. In
App Store Connect's terms that needs no documentation, except a French
encryption declaration to be offered in France, which is why France is left
out for now. `Info.plist` carries no `ITSAppUsesNonExemptEncryption`, so each
build answers the encryption questions in App Store Connect.

### Spanish

**Name** (30): Quincena: tu plata

**Subtitle** (30): Lo que te queda hasta el pago

**Promotional text** (170): Pregúntale a tu plata y recibe la respuesta
como una herramienta que puedes tocar. Tus finanzas se quedan en tu
teléfono.

**Keywords** (100): finanzas,presupuesto,gastos,quincena,ahorro,nómina,cripto,extracto,pesos,dólares,metas,deudas

**Description:**

> Quincena te dice cuánta plata tienes libre hasta el próximo pago, y qué
> hacer con ella antes de gastarla.
>
> TUS CUENTAS, EN CUALQUIER MONEDA
> Bancos, billeteras, tarjetas, efectivo, dólares y cripto, cada una en su
> moneda, con el total en pesos convertido con la TRM oficial y los precios
> del mercado.
>
> PREGÚNTALE A TU PLATA
> «¿En qué se me fue la plata este mes?», «¿Cuánto me queda libre?». Cada
> respuesta llega como una interfaz: gráficas, listas y planes que puedes
> tocar, con cifras calculadas en tu teléfono.
>
> LOS PAGOS SE REGISTRAN SOLOS
> Atajos listos para las notificaciones de tus bancos, los SMS, Apple Pay y
> las capturas de comprobantes. Lo que no está claro te espera en «Por
> revisar», y lo repetido se reconoce.
>
> EXTRACTOS
> Importa el extracto de tu banco o tarjeta en CSV, Excel o PDF, se lee en
> el teléfono y revisas cada movimiento antes de guardarlo.
>
> DECIDE ANTES DE GASTAR
> «¿Me alcanza?» te muestra lo más bajo que quedaría tu plata hasta el pago
> si compras hoy o si esperas; ves los próximos 30 días con los días
> apretados marcados y el cierre de cada quincena en tres tarjetas. Cada
> cifra muestra de dónde sale. Son estimaciones con lo que tienes
> programado, nunca una garantía.
>
> PLANEA TU QUINCENA
> Reparte lo que te llega en sobres para el día a día, tus metas y lo que
> quieras apartar, sin mover plata. Mira cuándo llegas a cada meta, cuántos
> días cubre tu colchón y qué pasaría si ahorras más, si sube un gasto o si
> te pagan tarde. Guarda lo que quieres para después y mira qué le haría
> a tus metas comprarlo.
>
> TUS COMPROMISOS, A LA VISTA
> Tus suscripciones y pagos fijos con la próxima renovación, el fin de cada
> prueba gratis, los cambios de precio y un aviso antes de que cobren; ves
> cuánto te ahorrarías al pausar una, y la app nunca cancela nada por ti.
> Lleva tus compras a cuotas con su calendario, lo que te falta y lo que
> cuestan frente al contado, separando lo que sabes de lo estimado. Un
> detective de cargos te muestra pagos repetidos, subidas de precio y
> cargos fuera de lo común, con la evidencia y sin borrar nada.
>
> PARA TU VIDA REAL
> Divide una cuenta con quien sea, sin que tenga la app: tu parte es tu
> gasto y lo demás es plata que te deben, que no cuenta como disponible.
> Si tus ingresos cambian de un mes a otro, separa lo cobrado, lo
> facturado y lo estimado, elige qué contar y aparta una reserva. En un
> viaje, lleva un presupuesto en la moneda local con tus mismos
> movimientos, la tasa de cada día y el cargo real del banco.
>
> CRIPTO, COMO UN PROFESIONAL
> Tu portafolio con precios en vivo, lo que te costó cada moneda en pesos y
> en dólares, la ganancia o pérdida y la gráfica de 24 horas a un año.
> Conecta Binance con una llave de solo lectura, o sigue tus billeteras por
> su dirección pública.
>
> PRIVADA POR DISEÑO
> Tus cuentas y movimientos se guardan solo en tu teléfono. Sin publicidad,
> sin venta de datos. Exporta todo cuando quieras. Si usas Quincena en más
> de un dispositivo, los cambios viajan en un archivo cifrado que solo tus
> dispositivos pueden abrir.
>
> Quincena no da asesoría financiera ni de inversión.

### English

**Name** (30): Quincena: tu plata

**Subtitle** (30): What's left until payday

**Promotional text** (170): Ask your money and get the answer as a tool
you can touch. Your finances stay on your phone.

**Keywords** (100): finance,budget,spending,payday,savings,salary,crypto,statement,pesos,dollars,goals,debt

**Description:**

> Quincena tells you how much money is free until your next payday, and
> helps you decide before you spend it.
>
> YOUR ACCOUNTS, IN ANY CURRENCY
> Banks, wallets, cards, cash, dollars and crypto, each in its own currency,
> with the total converted at official and market rates.
>
> ASK YOUR MONEY
> "Where did my money go this month?", "How much is free until payday?"
> Every answer arrives as an interface: charts, lists and plans you can
> touch, with figures worked out on your phone.
>
> PAYMENTS RECORD THEMSELVES
> Ready shortcuts for your banks' notifications, texts, Apple Pay and
> receipt screenshots. What is unclear waits in "To review", and repeats
> are recognized.
>
> STATEMENTS
> Import your bank or card statement as CSV, Excel or PDF. It is read on
> your phone, and you review every movement before it is saved.
>
> DECIDE BEFORE YOU SPEND
> "Can I afford it?" shows the lowest your money would get until payday if
> you buy today or wait; you see the next 30 days with the tight ones
> marked, and the close of each fortnight in three cards. Every figure
> shows where it comes from. They're estimates from what's scheduled, never
> a guarantee.
>
> PLAN YOUR FORTNIGHT
> Split what you're paid into envelopes for the day to day, your goals and
> whatever you want to set aside, without moving money. See when you'll
> reach each goal, how many days your cushion covers, and what would
> happen if you saved more, a charge went up or your pay came late. Keep
> what you want for later and see what buying it would do to your goals.
>
> YOUR COMMITMENTS, IN SIGHT
> Your subscriptions and fixed payments with their next renewal, the end of
> each free trial, price changes and a reminder before they charge; see
> what pausing one would save, and the app never cancels anything for you.
> Track instalment purchases with their schedule, what's left and what they
> cost against paying at once, keeping what you know apart from what's
> estimated. A charge detective shows repeated payments, price increases
> and unusual charges, with the evidence, and deletes nothing.
>
> FOR REAL LIFE
> Split a bill with anyone, no app needed on their side: your part is your
> spending, and the rest is money you're owed, which doesn't count as
> available. If your income changes from month to month, keep collected,
> billed and estimated apart, choose what counts ahead and keep a reserve.
> On a trip, keep a budget in the local currency with your own movements,
> each day's rate and the bank's real charge.
>
> CRYPTO, LIKE A PRO
> Your portfolio with live prices, what each coin cost you in pesos and
> dollars, your gain or loss, and the chart from 24 hours to a year.
> Connect Binance with a read-only key, or follow your wallets by their
> public address.
>
> PRIVATE BY DESIGN
> Your accounts and movements are kept only on your phone. No ads, no
> selling of data. Export everything whenever you want. If you use Quincena
> on more than one device, changes travel in an encrypted file only your
> devices can open.
>
> Quincena does not give financial or investment advice.

### App Privacy

Apple counts as collected what leaves the device and is kept beyond
serving the request. Proposed answers:

| Data type | Collected | Purpose | Linked to the person | Tracking |
| --- | --- | --- | --- | --- |
| Identifiers: User ID (Firebase's anonymous ID) | Yes | App Functionality | No: anonymous, deleted after 30 days | No |
| Financial Info: Other financial info (the figures in a question to Gemini) | Yes, when the person asks | App Functionality | No | No |
| User Content: Other user content (the question's text, a statement read with Gemini) | Yes, when the person asks | App Functionality | No | No |
| Location: Precise location | Yes, only with the option on | App Functionality (finding the shop of a payment) | No | No |

Everything else (accounts, movements, contacts, health, browsing,
diagnostics, usage data) is not collected: it stays on the device or is
not handled at all. No tracking, no ads, no third-party analytics.

### Age rating

4+ for content. The rating's questions on AI assistants: Gemini answers
only about the person's money, through tools, inside the app.

### Review notes

> Quincena keeps every account and movement on the device. To try it
> without entering anything, tap "Con datos de ejemplo" on the first
> screen. "Pregúntale a tu plata" uses Gemini through Firebase AI Logic,
> protected by App Check; questions are limited to 30 a day per person.
> Connecting Binance needs a read-only API key of the reviewer's own and is
> optional; every other feature works without it.

## Google Play

### Spanish

**Short description** (80): Cuánta plata te queda hasta el pago, y qué hacer con ella antes de gastarla.

**Full description:** the App Store's, without the shortcuts paragraph,
which on Android reads:

> LOS PAGOS SE REGISTRAN SOLOS
> Si le das permiso, Quincena lee las notificaciones de tus bancos y
> billeteras, solo las que traen un monto, nunca los códigos de seguridad.
> Lo que no está claro te espera en «Por revisar».

### English

**Short description** (80): How much money is left until payday, and what to do with it before you spend it.

**Full description:** the App Store's, with the same Android paragraph:

> PAYMENTS RECORD THEMSELVES
> If you allow it, Quincena reads your banks' and wallets' notifications,
> only those with an amount, never security codes. What is unclear waits
> in "To review".

### Data safety

| Data | Collected | Shared | Purpose | Optional |
| --- | --- | --- | --- | --- |
| Device or other IDs (Firebase's anonymous ID) | Yes | No | App functionality, fraud prevention | No |
| Financial info: other (figures in a question to Gemini) | Yes | No | App functionality | Yes |
| Messages: other in-app messages (a question's text) | Yes | No | App functionality | Yes |
| Location: precise | Yes | No | App functionality | Yes |

Encrypted in transit: yes. The person can ask for deletion: yes, in the
app (Settings, delete everything) and by email. Data is not sold, and
Google receives it as a service provider.

### Permission declarations

**Background location** (`ACCESS_BACKGROUND_LOCATION`). Play asks for a
justification and a short video.

> Quincena records a person's payments from their bank's notifications.
> Most of those notifications arrive while the app is closed, and many do
> not name the shop ("Compra POS 4512"). With the person's consent, and
> only at the moment a payment notification arrives, Quincena reads the
> phone's location to suggest the shop nearby, so the payment is recorded
> with its merchant and category. The option is off by default, the app
> explains it before asking, and the person can turn it off at any time.
> The coordinates stay on the device; to find the shop, only they are
> sent to OpenStreetMap's Photon search.

The video: Settings, Automatic capture, turning on "Usar la ubicación del
pago", the explanation, the permission dialog with "Allow all the time",
then a payment notification arriving with the app closed and the payment
waiting in "Por revisar" with the shop's name.

**Notification access** (`BIND_NOTIFICATION_LISTENER_SERVICE`). Not a
Play declaration, but the listing and the in-app explanation say what it
reads: notifications with an amount next to a currency, from apps the
person does not mute; never security codes.
