# Production

Where Quincena's Firebase project stands before real people and real money
go through it. Checked on 3 October 2026: version 1.0 is in App Review with
build 12, and 1.0.0 (13) in Google Play's review for production. The web
demo deploys from `main`.

## What is set up

The project is `quincena-dlsoft`, on the Blaze plan with DL SOFT's billing
account, with three apps: Android, Apple (iOS and macOS share the bundle ID
`dev.dlsoft.quincena`) and web.

- **Gemini runs on Agent Platform**, Google Cloud's (formerly Vertex AI), on
  the `global` location, through Firebase AI Logic. The project's prompt
  cache is off. The Gemini Developer API, which the app used before, is
  closed: every one of its quotas is at zero.
- **App Check** is enforced for Firebase AI Logic and Cloud Firestore. Every
  request needs a token from App Attest (with DeviceCheck as fallback) on
  Apple devices, Play Integrity on Android, or reCAPTCHA Enterprise on the
  web. The reCAPTCHA key is score based and only works on
  `diegolopezrm.github.io`. Simulators,
  emulators and local web builds use a debug token that never enters the
  repository. From 2 November 2026 Firebase requires App Check for AI Logic
  anyway.
- **Anonymous sign-in**, with anonymous accounts deleted 30 days after they
  are created; the app signs in again when that happens.
  `diegolopezrm.github.io` is an authorized domain.
- **API keys** only reach Firebase APIs, so none of them can call Gemini
  directly. The Apple key only answers the app's bundle ID, the web key only
  answers `diegolopezrm.github.io` and `localhost`, and the Android key only
  answers the app's package signed with the debug certificate, the upload
  key or Play's app signing key. GitHub flags all three as
  secrets; they ship in every build by design, and those alerts are closed
  as such.
- **Reports about answers** (`lib/ai/reports.dart`) go to Cloud Firestore,
  the `(default)` database in `nam5`, into `reports`. `firestore.rules` lets
  the app create a report with nine fields of fixed sizes and nothing else:
  no reads, changes or deletes. A TTL policy on `expireAt` deletes each
  report 90 days after it is made, and none carries an account or device
  identifier. DL SOFT reads them in the Firebase console, under Firestore,
  to correct the prompt and what it filters. Google Play asks apps whose AI
  chat is a central feature to let people report offensive output without
  leaving the app. The rules deploy with
  `firebase deploy --only firestore:rules --project quincena-dlsoft`.
- **Logs**: prompts and answers are kept out of Cloud Logging by an exclusion
  on the `_Default` sink, in case AI monitoring is ever turned on. Out of the
  box it stores them, personal data included.
- **iOS extensions**: the share extension (`dev.dlsoft.quincena.ShareExtension`)
  and the home screen widget (`dev.dlsoft.quincena.QuincenaWidget`) share
  the App Group `group.dev.dlsoft.quincena` with the app, which leaves them
  what they need there. Both sign automatically with the team, like the app,
  and carry its version.
- **iOS and macOS** take every plugin, Firebase included, through Swift
  Package Manager. No CocoaPods is left: Firebase published its last pods
  with 12.19.0, and the CocoaPods registry turns read-only in December 2026.
- **Android release builds** are signed with an upload key described in
  `android/key.properties`, which stays out of the repository. Without that
  file they fall back to the debug key, which Google Play refuses. Play signs
  what it delivers with its own app signing key.

## Which limits stop spending, and which only warn

A limit that stops spending refuses the request before it reaches the
model, so the refused request costs nothing. A warning arrives after the
money is spent.

| Limit | Kind | Value |
| --- | --- | --- |
| App Check | Stops: requests that don't come from the app are refused | Enforced |
| Requests per person, per minute (AI Logic) | Stops, with a 429 | 20; the Live API, which the app does not use, 0 |
| Spend cap on Agent Platform (preview) | Stops the service for the rest of the month, a few minutes late; the overage is billed | COP 100,000 a month |
| Gemini Developer API, every model and tier | Stops | 0 |
| Agent Platform outside `global`, and its images, audio, Live, Flex and embeddings | Stops, where Google applies the limit | 0 |
| Input tokens a day on Agent Platform, for 3.8 and 3.5 Flash | Not applied: Google does not apply a project's overrides to models on dynamic shared quota | 6 and 2 million, set in case it starts |
| Monthly budget for the project | Warns, hours late | COP 100,000: at 50%, 90%, 100% and a 100% forecast, to the billing account's admins and by email |
| Monitoring alerts by email | Warns | Bursts over 150 requests in 10 minutes, more than 10 refusals (429) in 10 minutes, a Gemini quota running out |
| 30 questions a day in the app | Neither: it guides the person, and reinstalling resets it | 30 |

On Agent Platform, a project cannot cap single models: the ones the app uses
run on dynamic shared quota, and a model set to zero there still answered
when it was tried. Anyone holding a valid App Check token can ask any model
on `global`; the spend cap is what bounds the cost. Firebase AI Logic's server
prompt templates, in their template-only mode, would pin the model too.

`tool/firebase/caps.py` sets the quota limits and shows them (`--check`).
`tool/firebase/alerts.py` sets up the alerts. Both act as whoever is signed in
to `gcloud`. The budget and the spend cap live on the billing account; the
spend cap was set in the Firebase console, under Settings > Usage and billing
> Details & settings.

### What "per person" means

Firebase doesn't document who counts as one person for the per-minute limit.
Google Cloud counts per-user quotas against the authenticated principal, or
the IP address when there is none. A Firebase ID token is probably not such
a principal, so the limit is likely per IP address. If so, people behind the
same carrier NAT share it, and creating a new anonymous account does not
reset it.

No server-side limit counts a person's questions per day. A real per-person
daily limit needs a small backend that counts by user and calls Gemini
itself; [`SERVER_LIMIT.md`](SERVER_LIMIT.md) designs one, a Cloud Function
with Firestore, and lists what to decide before building it.

## Privacy

The tools send Gemini totals, balances, account names and, when a question
asks for them, the largest payments of a month with their merchants.

- **Agent Platform, as a paying customer**, is what the app uses. Google
  Cloud's service terms forbid training on customer data. Prompts are logged
  for abuse monitoring only when a classifier flags them, for up to 90 days,
  and Google takes requests to opt out of that too. The project's cache,
  which would keep prompts in memory for up to 24 hours, is off. "Qué ve
  Gemini" in the app says this in plain words.
- **The Gemini Developer API**, closed now, keeps prompts for 55 days for
  abuse monitoring even when paid, and on the free tier Google may use them
  to improve its products, with people reviewing them.
- **Both models are stable**, not previews, and the same terms apply to both.
  3.5 Flash will be retired no earlier than May 2027. On Agent Platform, 3.8
  Flash is a short-term model that can be retired 45 days after its
  replacement ships.
- The terms also rule out relying on Gemini for financial advice, and apps
  directed at minors. The prompt tells Gemini to describe what happened to
  an investment and never to say what to buy or sell.

Crypto and Binance:

- **A Binance key** is checked with Binance before it is kept, and refused
  unless it can only read. It lives in the device's keychain (the Keychain
  on Apple devices, the Keystore on Android), on that device only: never in
  the database, an export, the logs or a prompt. Requests go from the device
  straight to `api.binance.com`, signed with HMAC-SHA256 and stamped with
  Binance's clock; nothing passes through the Firebase project. What a sync
  reads stays in the local database like any other movement. The web does
  not offer it: Binance does not answer a browser's signed requests, and a
  browser has no keychain.
- **Market prices** come from Binance's public market data
  (`data-api.binance.vision`), and past dollar rates from datos.gov.co or,
  for other currencies, the European Central Bank through Frankfurter. Those
  requests say which coins or currencies are wanted, never how much the
  person holds.

Sources: [Agent Platform zero data retention](https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/zero-data-retention),
[Agent Platform abuse monitoring](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/abuse-monitoring),
[AI Logic data governance](https://firebase.google.com/docs/ai-logic/data-governance),
[Gemini API terms](https://ai.google.dev/gemini-api/terms),
[AI Logic models](https://firebase.google.com/docs/ai-logic/models).

## What a question costs

The system prompt is about 49,000 characters, 11,822 tokens counted by the
model itself (`countTokens`, through Firebase AI Logic) on 3 October 2026.
Most of it is the catalog. genui writes its three JSON schemas indented, one
key per line; the app sends the same JSON on one line, which the model reads
the same way and which took the prompt from 19,080 tokens to 11,822. Every
round of an answer sends it again: the model asks for the tools it needs,
gets their answers, and writes the surface. The prompt asks for every tool
at once, so most questions take two rounds and the longest three or four.
`flutter test tool/prompt` writes the prompt as sent, by part.

Measured live the same day, with 3.8 Flash through Firebase AI Logic:

| Question | Rounds | Prompt tokens | Written | Thinking | Cost | With the old prompt |
| --- | --- | --- | --- | --- | --- | --- |
| ¿En qué se me fue la plata en septiembre? | 2 | 26,252 | 1,216 | 0 | US$0.024 | US$0.035 |
| ¿Me alcanza para ir a Cartagena en diciembre? | 2 | 26,075 | 1,484 | 4,322 | US$0.041 | US$0.052 |

That is at 3.8 Flash's prices until 31 December 2026, US$0.75 per million
input tokens and US$3.75 per million output tokens (thinking included), with
the cache off: a question costs about US$0.02 to US$0.05, and COP 100,000 a
month covers some 600 to 1,200 of them. From January 2027 the prices double.
What the model thinks now weighs nearly as much as the whole prompt: in
the second question its 4,322 tokens of thought cost US$0.016 and the
26,075 it read US$0.020, at the low thinking level, the lowest 3.8 Flash
takes. An answer takes 20 to 60 seconds, most of it the
last round.

The prompt cache would make every round after the first cheaper still, at
the price of Google keeping the prompt in memory for up to 24 hours. That
is DL SOFT's decision.

## Pending

Waiting on the owner:

1. Request the opt-out from Agent Platform's abuse logging. The abuse
   monitoring page still links a form for it, but the form no longer takes
   answers (checked on 2 October 2026), so the request goes to Google:
   through the form's "contact the owner" link, Google Cloud sales, or a
   support case. Until then a prompt is only kept if a safety classifier
   flags it, for up to 90 days in the project's location, and never used
   for training.
2. Play Integrity:
   1. Create the upload key and point `android/key.properties` at it. Done
      on 2 October 2026: its certificate's SHA-1 is
      `34:0F:1E:BB:0C:3A:16:07:CB:5A:B1:48:DB:F6:B5:56:30:67:38:A0` and its
      SHA-256
      `62:EA:79:93:1E:A3:A1:9D:F4:C1:CA:CE:39:C9:06:67:18:05:36:B6:5C:02:E6:54:76:D1:D5:FF:48:FD:C9:28`.

      ```bash
      keytool -genkey -v -keystore ~/keys/quincena-upload.jks \
        -keyalg RSA -keysize 2048 -validity 10000 -alias upload
      ```

      ```properties
      storeFile=/Users/you/keys/quincena-upload.jks
      storePassword=...
      keyAlias=upload
      keyPassword=...
      ```

   2. Create the app in Play Console and upload `flutter build appbundle` to
      internal testing. Done on 2 October 2026 with 1.0.0 (12). Play's app
      signing certificate has the SHA-1
      `A1:D6:C8:B0:96:0A:75:A4:6E:88:FF:F7:EB:AC:C9:29:37:C9:0F:5F` and the
      SHA-256
      `D3:1F:CE:28:1F:4D:84:B5:54:13:C3:0E:A7:8F:EA:CB:24:CF:5C:6F:01:5D:59:68:A7:0F:4C:E9:19:5A:27:F0`.
   3. Link `quincena-dlsoft` under Protected with Play > Play Integrity API.
      This needs a direct Owner of the project, and linking accepts the
      Play Integrity API's terms of service for DL SOFT. Done on 2 October
      2026, with Diego's approval: 10,000 requests a day, and the default
      verdicts on (licensing, app integrity, device integrity).
   4. Add the SHA-256 of Play's app signing certificate to the Android app in
      Firebase, and register Play Integrity in App Check. Done: Firebase has
      the SHA-1 and SHA-256 of both certificates, and App Check shows Play
      Integrity registered.
   5. Add the SHA-1 of the upload and the Play signing certificates to the
      Android API key, or release builds from Play will be refused. Done,
      next to the debug certificate's.

   Builds that don't come from Google Play fail Play Integrity. They keep
   using the debug provider.
3. Sign in to Xcode with DL SOFT's Apple account. An iPhone needs it to run
   the app at all, since App Attest needs a provisioning profile with the
   capability. The Mac app needs it to be signed with the team: until then
   the keychain refuses the anonymous account, so a Mac asks with App Check
   alone and no user, and App Attest or DeviceCheck can't vouch for a
   release build.
4. Decide on the prompt cache: cheaper, or nothing kept in memory.

Technical, once those are settled:

- Replay protection (single-use App Check tokens): each request then costs an
  attestation. Play Integrity allows 10,000 a day, and reCAPTCHA gives 10,000
  free assessments a month for the whole organization.
- Server prompt templates, to pin the model and the prompt on the server.
- A shorter catalog description in the prompt.
- A per-person daily limit on a server, if 30 a day has to hold.
- Flutter 3.44.9 before Xcode 27: 3.44.8 fixes the build with it.
