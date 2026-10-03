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

The party responsible for the data is DL SOFT TECHNOLOGIES SAS, NIT
902024441-0, Carrera 28 # 54-28, Bucaramanga, phone +57 316 605 0934, with
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
build answers the encryption questions in App Store Connect: standard
algorithms, not offered in France. App Store Connect's reply is that no
document is needed and the key can say `NO`, which stays true only while
France is left out.

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
serving the request. Published on 2 October 2026:

| Data type | Collected | Purpose | Linked to the person | Tracking |
| --- | --- | --- | --- | --- |
| Identifiers: User ID (Firebase's anonymous ID) | Yes | App Functionality | No: anonymous, deleted after 30 days | No |
| Financial Info: Other financial info (the figures in a question to Gemini) | Yes, when the person asks | App Functionality | No | No |
| Purchases: Purchase history (the payments of a category in a month, which the `category_payments` tool gives Gemini) | Yes, when the person asks | App Functionality | No | No |
| User Content: Other user content (the question's text, a statement read with Gemini) | Yes, when the person asks | App Functionality | No | No |
| Location: Precise location | Yes, only with the option on | App Functionality (finding the shop of a payment) | No | No |

Everything else (accounts, movements, contacts, health, browsing,
diagnostics, usage data) is not collected: it stays on the device or is
not handled at all. No tracking, no ads, no third-party analytics.

Build 12, in review, cannot report an answer. A report (from build 13)
carries the same types: the question, the answer's figures and the
person's comment, for App Functionality, nothing linked to the person.
So the answers above hold when an iOS build with reports ships.

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
>
> Sync between devices (Ajustes, Varios dispositivos) is optional: devices
> exchange end-to-end encrypted files that the person moves, with no
> account or server.

Version 1.0 went to App Review on 2 October 2026 with build 12. The
review contact is Diego López, +57 316 605 0934, admin@dlsoft.dev. Release
is set to manual, so an approved version waits for someone to release it.

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

Submitted on 2 October 2026 and updated on 3 October for reports about
answers. None of it is processed ephemerally, and none is shared: Google
and Photon receive it as service providers.

| Data | Collected | Shared | Purpose | Optional |
| --- | --- | --- | --- | --- |
| Device or other IDs (Firebase's anonymous ID, made only when the person asks Gemini) | Yes | No | App functionality; fraud prevention, security and compliance | Yes |
| Financial info: purchase history (the payments of a category in a month, in a question to Gemini or a reported answer) | Yes | No | App functionality; fraud prevention, security and compliance | Yes |
| Financial info: other (figures in a question to Gemini or a reported answer) | Yes | No | App functionality; fraud prevention, security and compliance | Yes |
| Messages: other in-app messages (a question's text, a report's comment) | Yes | No | App functionality; fraud prevention, security and compliance | Yes |
| Files and docs (a statement read with Gemini) | Yes | No | App functionality | Yes |
| Location: precise | Yes | No | App functionality | Yes |

Encrypted in transit: yes. No accounts are created in the app. The person
can ask for deletion: yes, in the app (Settings, delete everything) and by
email, as section 4 of the privacy policy says; that page is the deletion
link. Data is not sold.

The rest of App content, also submitted: no ads; nothing behind a login;
IARC rating for every age (PEGI 3, ESRB Everyone, USK 0), with online
content declared for Gemini's answers; audience 18 and over; no
advertising ID; not a government or health app; financial features
"Other": personal finance management with read-only balances, and no
loans, payments, transfers, custody, trading or advice.

Listing: Spanish (Latin America) by default and English (United States),
the 512 icon from `web/icons/Icon-512.png`, the feature graphics
`feature-graphic-{es,en}.png` (from `tool/brand/feature_graphic.py`), and
the six phone screenshots per language. Category Finance; contact
admin@dlsoft.dev and the marketing site; no phone.

1.0.0 (12) went to internal testing on 2 October 2026: a 19.5 MB download
from a 92.6 MB bundle, with Play App Signing. Its testers are the
"Quincena internos" list, with Diego's account, since 3 October; a tester
joins at https://play.google.com/apps/internaltest/4700567245405439080
and installs from there.

1.0.0 (13), with reports about answers, replaced it there on 3 October
and was promoted to production the same day: a full rollout to 176
countries and regions and the rest of the world, without France, for
the same encryption declaration as on the App Store. A first submission
sends everything together, so the 12 changes went to review at once:
the release, the countries, both listings, the rating, the audience,
the privacy policy, ads, Data safety, health apps and the category, with
the location and sign-in declarations. Managed publishing is off, so
Google's approval publishes the app; Play says reviews usually take up
to 7 days.

### AI-generated content

Google Play asks apps whose AI chat is a central feature, as "Pregúntale
a tu plata" is in this listing, to let people report offensive output
without leaving the app. From build 13 every answer a model wrote has
"Reportar"; where reports go and how long they stay is in
`docs/PRODUCTION.md`.

### Permission declarations

**Background location** (`ACCESS_BACKGROUND_LOCATION`). Play asks for the
app's purpose, one feature that needs the location in the background, and
a short video. Submitted on 2 October 2026:

> **Purpose:** Quincena is a personal finance app that shows how much money
> is left until the next payday. Payments are recorded by hand, from bank
> statements, or automatically from the bank and wallet notifications the
> person chooses to let it read. Records are kept on the phone, with no
> account.
>
> **Feature:** Finding the shop of a payment. Payment notifications arrive
> while Quincena is closed, and many do not name the shop ("Compra POS
> 4512"). With "Use where the payment happened" turned on (off by
> default), Quincena reads the location once when a payment notification
> arrives and suggests the shop nearby. The prominent disclosure "Location
> while Quincena is closed" comes before Android's prompt. The location
> stays on the phone; only coordinates go to Photon (OpenStreetMap search).

The video, `background-location.mp4` (51 seconds, recorded on an emulator
with example data, captioned): Settings, Automatic capture, turning on
"Use where the payment happened", Android's location prompt, the app's
explanation "Location while Quincena is closed", "Allow all the time",
then the app closed, a bank notification with no shop name ("Compra por
$18.500 POS 7731") and the payment waiting in To review with the shop
found nearby. It is shared from DL SOFT's Google Drive to anyone with the
link: https://drive.google.com/file/d/1xdb85_mDkdhPHvFe85GKVF-SWqFoob4N/view

**Notification access** (`BIND_NOTIFICATION_LISTENER_SERVICE`). Not a
Play declaration, but the listing and the in-app explanation say what it
reads: notifications with an amount next to a currency, from apps the
person does not mute; never security codes.

## Version 1.1.0

Not submitted yet. What goes to both stores when it is.

**Promotional text** (App Store, 170): Quincena sabe cuánto puedes gastar
sin dañar tus planes. Pregúntale a tu plata y recibe la respuesta como una
herramienta que puedes tocar. / Quincena knows how much you can spend
without hurting your plans. Ask your money and get the answer as a tool you
can touch.

**What's new** (es):

> Ahora ves en grande lo que puedes gastar hasta el pago, con su cuenta
> debajo, y lo que viene día a día. Las tarjetas de crédito aparecen como lo
> que debes, «Por revisar» pide una sola decisión por movimiento y pregunta
> si una plata que llega viene de otra cuenta tuya. Las respuestas empiezan
> por la conclusión, y puedes reportar una respuesta de Gemini. Hay un
> widget para la pantalla de inicio, que puede ocultar los montos, y los
> respaldos salen cifrados con un código tuyo.

**What's new** (en):

> What you can spend until payday now comes first, with the sum under it,
> and what is coming day by day. Credit cards show what you owe, "To
> review" asks for one decision per movement and whether money that
> arrives comes from another account of yours. Answers start with their
> conclusion, and you can report a Gemini answer. There is a home screen
> widget, which can hide amounts, and backups are encrypted with a code of
> your own.

The screenshots are rendered again from `test_screens/store_screens_test.dart`
before submitting: the 1.0 ones in `screenshots/` are what the stores show
today.
