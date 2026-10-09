# Release quality gate

What was checked before Quincena's first public version, 1.0.0, how it was
checked, and what is left for a real device or for the developer account.
The gate itself is in `docs/ROADMAP.md`, phase 9. Checked on 2 October 2026.

## Builds

| Platform | How | Result |
| --- | --- | --- |
| iOS | `flutter build ipa --release`, Xcode 26.1.1, iOS 26.1 SDK | Signed for the App Store. The app and its share extension each carry their distribution profile and the `group.dev.dlsoft.quincena` App Group. |
| Android | `flutter build appbundle --release` and `flutter build apk --release` | Built, 89 MB bundle and 108 MB APK with every ABI; signed with the debug certificate until the upload key exists. |
| Web | `flutter build web --release --base-href /quincena/`, as CI publishes it | Built. |
| macOS | `flutter build macos --release` | Built, 72 MB. |

## Store and provider requirements

Checked against each provider's published requirements on 2 October 2026.

| Requirement | Since | Quincena |
| --- | --- | --- |
| Google Play: new apps and updates target Android 16, API 36 | 31 August 2026 | `targetSdk` 36, `compileSdk` 36, `minSdk` 24 |
| App Store: built with Xcode 26 and an iOS 26 SDK | 28 April 2026 | Xcode 26.1.1, iOS 26.1 SDK; deployment target iOS 16 |
| Firebase AI Logic: a model that is not being retired | | `gemini-3.8-flash`, the latest stable, which Google lists as short-term; when it is withdrawn the app falls back to `gemini-3.5-flash`, not retired before 19 May 2027. Gemini 2.5, which shuts down in October 2026, is not used. |
| Firebase: App Check required for AI Logic | 2 November 2026 | Already enforced (`docs/PRODUCTION.md`) |

## Automated checks

`flutter test` runs 1036 tests, the same that CI runs on every push,
with `dart format`, `flutter analyze --fatal-infos` and a check that the
generated catalog is current.

- **Accessibility.** `test/own_accessibility_test.dart` opens 53 screens
  of someone's own money (home, movements, accounts, the archived ones,
  what deleting a card asks first, where the net worth
  and the money to spend come from, a card, crypto, Binance, wallets, a
  statement, "Por revisar", automatic capture, the next 30 days, "¿Me
  alcanza?", the close, Plan, envelopes, the cushion in days, wishes, what
  if, fixed payments, purchases in instalments, one of them, the charges
  to check, shared expenses, a group, variable income, trips, one trip,
  more than one device; the first screen, the four steps of onboarding,
  settings, the app's frame on each of its four tabs, asking about one's
  money and an answer, the three "¿De dónde sale?" sheets, and the sheets
  for a new movement, account, goal and fixed payment and for changing a
  movement and a card) on a 360-point phone with the system text at twice
  its size, the most Android offers, in both themes and both languages.
  It scrolls each from top to end and holds it to Flutter's guidelines:
  nothing overflows, every tap target labeled, 48 by 48 on Android and 44
  by 44 on iOS, and text contrast of at least 4.5:1. It found the faint
  ink at 3.5:1 on the light canvas and 4.3:1 on dark cards; it is now at
  least 4.5:1 on every ground it sits on. No words are squeezed into a
  column a few letters wide, except on the twelve screens the test still
  lists (crypto, the close, fixed payments, instalments, trips and others).
  Inicio, Cuentas, Por revisar, Plan, the frame on each tab, the first
  screen and onboarding also hold at iOS's largest text size, AX5, about
  3.1 times the default, with no text cut short: with large text a row's
  amount goes under its name.
  `test/large_text_test.dart` holds the sample account and its five answers
  at twice the text size in both languages, and `test/catalog_test.dart`
  audits what every component tells a screen reader.
- **Keyboard and long lists.** `test/keyboard_test.dart` raises a 336-point
  keyboard over the forms at twice the text size: the field being typed in
  stays above it, and the button that saves or goes on is in sight or a
  scroll away. `test/long_lists_test.dart` loads 1,500 movements:
  Movimientos and an account's page build only the days near the screen,
  go down to the oldest and search all of it.
- **No signal by color alone.** Gains and losses carry a sign, the free and
  committed bar has a legend, and categories are named next to their color.
- **Sync between devices.** `test/sync_test.dart` runs two and three
  devices on their own databases: offline edits that converge in any order
  of files, a file merged twice, the same record changed on two devices,
  deleted on one and edited on another, deleted and brought back, an
  account deleted with a movement added elsewhere, a backup that carried
  another device's versions, list items changed on two devices, the same
  statement line imported on both, a wallet followed on both, something
  written again under a deleted id, the same version brought back on two
  devices, a device restored from an older backup of itself, a new code
  that leaves old devices out, every single-character typo in the code,
  and files that are tampered with, cut, from another vault or of a newer
  format. The design and its two security review passes are in
  `docs/SYNC.md`.
- **Sealed backups.** `test/backup_test.dart` restores a sealed backup on
  the phone that made it with nothing to type and on another with its
  code, typed as people type it, and keeps that code there. It checks that
  no other code opens it, that a sync file is not taken for a backup nor a
  backup for a sync file, even with its first bytes changed, that a file
  cut, changed, of a newer format or from another app changes nothing, that
  a new code leaves older backups to the old one, that a phone without a
  keychain still seals each backup with a code of its own, and that the
  person sees the code before choosing where to keep the file and is
  asked to replace everything only once the file has opened.
- **The home screen widget.** `test/home_widget_test.dart` checks that the
  app hands the widget Inicio's own words and figure in both languages,
  "Te faltan" when the period falls short, nothing of the amount when the
  person hides it, and a new figure only when something changed; that the
  sample's figures never reach it; and that Settings says how to add it. On
  3 October 2026 the iOS widget's view was drawn from its source in both
  themes, both sizes and each state (current, of another day, short,
  hidden, before any figure), and its extension rendered without errors in
  the simulator, where the app's figure reached the App Group. On a Pixel 9
  emulator the widget was added from Settings and showed the figure in
  light and dark, hid it on request, kept only the dots, and opened the
  app when tapped. The simulator's widget gallery would not load, so the
  iOS widget still has to be seen on a home screen, from TestFlight.
- **Money that reads by itself.** `test/money_clarity_test.dart` holds
  the home card to one figure to spend, with what is there today and each
  thing held back as its own line, "Te faltan" when the period falls short,
  and the next pay named as a quincena only for those paid twice a month.
  It checks that a credit card shows what is owed and the net worth splits
  into what is had and what is owed, that money arriving from another of
  the person's accounts is recorded as a transfer and not as income, that
  the licenses page credits OpenStreetMap and the fonts, and that amounts
  are written one way. `test/statement_page_test.dart` follows an import
  from its summary (new, already there, without a category) to the
  movements left to categorize.
- **Deciding before spending.** `test/decide_test.dart` checks that the
  home lines up the days until payday with the lowest point first and the
  pay marked as expected, that "¿Me alcanza para…?" opens the days ahead
  with the price tried out, that a goal's slider says what is missing,
  marks what it takes, stops on it and ticks once, that the ask bar turns
  to questions the account can answer and holds still while the person
  types, and that money lent from an account is owed to the person and
  not counted as spending.
- **Motion that explains.** `test/exit_list_test.dart` checks that a
  confirmed capture folds away where it was before it goes, that it simply
  goes with animations turned down, and that one that comes back stays.
- **Reporting an answer.** `test/report_test.dart` reports a Gemini
  answer from the conversation: the reason, the comment and the answer go
  to Firestore with App Check's token; the sheet stays open with an error
  when the report does not arrive; the demo's scripted answers cannot be
  reported; and what the person types into a form stays out of the
  report. `firestore.rules` was tried against the live database on 3
  October 2026: a report missing a field or with one more, with an
  unknown reason or platform, longer than the limits, or kept for less
  than 85 days or more than 95 is refused. Firestore measures a string in
  UTF-16 code units, as Dart does, so the app cuts to the same limits.
- **Migrations and restore.** `test/migration_test.dart` upgrades a version
  1 database to version 2 with drift's schema verifier. `test/store_test.dart`
  restores an export from version 1, refuses a file from elsewhere or from
  a newer version, and checks that a file breaking halfway through leaves
  the data as it was: an import runs in one transaction.
- **Where a number comes from.** "¿De dónde sale?" under the free amount
  shows each spendable account's part with the rate that converted it, its
  source and day, what is committed before payday, what is left out, and
  that it is an estimate. `test/ledger_builder_test.dart` checks that the
  parts add up to the figure exactly, with dollars, a transfer to savings,
  a payment entered ahead and charges expected before payday.
- **Without a connection.** Rates and prices fall back to the last ones
  saved, with their date, and the chart waits for the network; Binance and
  wallets say they could not be reached;
  Gemini says there is no connection and that the rest of the app works
  (`test/gemini_test.dart`). Capture, the ledger and every figure work
  offline.
- **Spanish and English.** Every string is in both `.arb` files; amounts,
  dates and percentages follow the interface language
  (`test/english_test.dart`).
- **No real data.** The store screenshots show Valentina, an example
  person. Wallet addresses in tests are made up; the only real ones in the
  code are the USDT and USDC contracts the app reads balances from. Errors
  that could quote a statement, a Binance response or a question are only
  logged in debug builds.

## On a simulator and an emulator

- **Every screen, on an iPhone.** `tool/tour/run.sh` plays
  `integration_test/tour.dart` on an iPhone 17 Pro simulator made for the
  run and deleted after it: 17 scenes, from the first launch to the
  sample's five answers, through every tab, every page of the plan,
  settings, sync, backups, dark mode and English, each screen scrolled
  from top to bottom. The simulator's own screenshots, status bar
  included, land in `capturas/ios` with an `index.html` that shows them by
  section. `test_screens/tour_check_test.dart` walks the same tour without
  a simulator, as iOS, to check every step still finds its way. The first
  run, on 3 October 2026, found that opening Cripto told its listeners in
  the middle of a build; it no longer does.
- **iOS share extension**, iPhone 17 Pro simulator, iOS 26.1: a receipt
  shared from Photos to Quincena was read on the device ("Quedó en Por
  revisar") and, after onboarding, waited in "Por revisar" as Ana Gomez,
  −$45.900, on 2 October at 10:42, with the Bancolombia account already
  chosen. Shared a second time it was set apart as a likely repeat. A
  payment shared before onboarding now waits until the first accounts
  exist, so it is matched to its account.
- **Android share target**, Pixel 9 emulator, Android 16 (API 36), the
  release APK: a bank message shared to Quincena was "in Quincena's To
  review"; after onboarding it waited there as Ana Gomez, −$45,900, on
  2 October at 10:42, with the Bancolombia account chosen. An image shared
  from the shell was turned down by Android, which lets an app read only
  what it was granted: shared from the gallery, the share grants it. That
  path is left for a real device.

- **Sharing a reminder**, iPhone 17 Pro simulator, iOS 26: in a group where
  Ana owed $ 30.000, "Recordar" opened the system's share sheet with
  "Hola, Ana. Te escribo por los $ 30.000…", and closing it sent nothing.
- **Reminders**, Pixel 9 emulator, Android 16, a release build with the
  receiver opened to the shell for the test only: the payday reminder set
  six alarms at nine on the next paydays. Fired with the app force-stopped,
  it showed "Your fortnight close is ready" and its line, with no amount.
  Alarms kept by build 8 or earlier still show if they fire before the
  updated app is opened.

## Left for real devices

TestFlight build 5 and an Android phone, before the stores' review:

- Capture: the ready shortcuts on iOS 26 and 27, the share sheet from a
  bank app, and bank notifications on Android.
- Permissions turned down: notification access, location while in use and
  always, and turning location off in the system's settings afterwards.
- Airplane mode: the app opens, records and shows its figures; rates,
  prices, Binance, wallets and Gemini say what they could not reach.
- Recovery: closing the app while a statement imports or a sync runs, and
  reopening it.
- VoiceOver and TalkBack on the home, a movement and "Por revisar".
- Reminders on the lock screen: the payday close and a renewal or free
  trial, at nine, with no amount, after restarting the phone too.
- Sharing a reminder on Android: the system's chooser opens with the
  message, and nothing is sent until the person picks where.
- Sync between a phone and a Mac or a second phone: save a file, carry it
  by AirDrop or Files, open it on the other, and back.

For 1.1.0, on TestFlight and the internal track, before production:

- The widget on an iPhone's home screen, small and medium, light and dark,
  with amounts and hidden; on the lock screen and in StandBy, where the
  amount should hide while the phone is locked; and the next morning, when
  it says the figure is a day old.
- The widget on an Android launcher other than the Pixel's, such as
  Samsung's, added from Settings and from the launcher.
- A sealed backup saved to iCloud Drive or Google Drive and opened on
  another phone with its code; the same file after deleting everything on
  the first one; and a JSON export opened in a text editor.
- Reporting a Gemini answer from a phone, with App Check's real providers.
- The five home questions with Gemini on a phone, after the prompt changed
  shape.
- VoiceOver and TalkBack over the lines under the figure on Inicio, the
  "Por hacer" rows and the "Próximos días" line.
- The largest text on each phone, AX5 on iOS and the largest font on
  Android, over Inicio, Cuentas, Por revisar, Plan and onboarding.

The closed test with people, over two fortnights, is planned in
[`CLOSED_TEST.md`](CLOSED_TEST.md).

## Left for the developer account

Nothing. Version 1.0 went to App Review on 2 October 2026 with build 12,
and 1.0.0 (13) to Google Play's review for production on 3 October, with
Play Integrity linked and the privacy policy naming DL SOFT's NIT,
address and phone. `docs/store/README.md` has what each store was told.
