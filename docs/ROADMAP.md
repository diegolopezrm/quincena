# Roadmap

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
