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
  Notification. Automations are set up by hand, following the steps in the
  app: iOS does not let an app or a file create them.
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
- Limits that stop spending, set before the project pays: per model, per
  minute and per day on every paid tier, every other model at zero, and no
  Live API. Email alerts, prompts kept out of Cloud Logging, and API keys
  restricted to the app. [PRODUCTION.md](PRODUCTION.md) says which limits
  stop spending and which only warn.
- Android release builds signed with an upload key kept outside the
  repository.
- Still open, each waiting on a decision or an account: the Blaze plan and
  its budget (on the free tier Google may use what is sent, so no real
  financial data until then), the Gemini Developer API or Agent Platform for
  that data, Play Integrity once the app is in the Play Console, and a
  daily limit per person on a server if 30 a day has to hold.

### 8. Statements, email and exchanges

- Statement import: CSV and Excel read on the device; PDF read by Gemini. Every
  extracted movement is shown for review before it is saved.
- Bank alert emails over IMAP, on the device, filtered by sender.
- Binance with a read-only API key kept in the device's secure storage:
  balances, deposits, withdrawals and conversions.

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
