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

- Inbox for everything that arrives from outside, with review.
- Parsers for the alerts of the banks and wallets used in Colombia, and a
  deduplicator across sources.
- iOS: an App Intent that Shortcuts automations call without opening the app,
  and signed shortcuts for Apple Pay (Wallet), SMS, bank notifications (iOS 27)
  and email subjects.
- Android: a notification listener, opt-in, limited to the apps the person
  picks.
- Share a screenshot or a text to Quincena from any app, read on the device.
- Where a payment happened, when the alert does not say: the phone's
  location at that moment, kept on the device, and the shops within a few
  metres of it from OpenStreetMap, so "Compra POS 4512" can become a
  suggestion like "Éxito Laureles · Groceries". Off until the person turns
  it on; the coordinates are the only thing that leaves the device.

### 7. Gemini for everyone

- Firebase AI Logic with App Check and anonymous sign-in, and a daily limit per
  person.
- The agent's tools read the database, in the base currency, with each
  account's own currency where it matters.
- A plain-language note on what the model sees.

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
