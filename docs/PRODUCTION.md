# Production

Where Quincena's Firebase project stands before real people and real money
go through it. Checked on 2 October 2026. Nothing here is published yet: the
web demo deploys from `main`, and none of this has been merged.

## What is set up

The project is `quincena-dlsoft`, still on the no-cost Spark plan, with three
apps: Android, Apple (iOS and macOS share the bundle ID
`dev.dlsoft.quincena`) and web.

- **App Check** is enforced for Firebase AI Logic. Every request needs a token
  from App Attest (with DeviceCheck as fallback) on Apple devices, Play
  Integrity on Android, or reCAPTCHA Enterprise on the web. The reCAPTCHA key
  is score based and only works on `diegolopezrm.github.io`. Simulators,
  emulators and local web builds use a debug token that never enters the
  repository. From 2 November 2026 Firebase requires App Check for AI Logic
  anyway.
- **Anonymous sign-in**, with anonymous accounts deleted 30 days after they
  are created; the app signs in again when that happens.
  `diegolopezrm.github.io` is an authorized domain.
- **API keys** only reach Firebase APIs, so none of them can call the Gemini
  API directly. The Apple key only answers the app's bundle ID, and the web
  key only answers `diegolopezrm.github.io` and `localhost`. The Android key
  waits for the signing certificates (see Play Integrity below).
- **Logs**: prompts and answers are kept out of Cloud Logging by an exclusion
  on the `_Default` sink, in case AI monitoring is ever turned on. Out of the
  box it stores them, personal data included.
- **iOS and macOS** take every plugin, Firebase included, through Swift
  Package Manager. No CocoaPods is left: Firebase published its last pods
  with 12.19.0, and the CocoaPods registry turns read-only in December 2026.
- **Android release builds** are signed with an upload key described in
  `android/key.properties`, which stays out of the repository. Without that
  file they fall back to the debug key, which Google Play refuses.

## Which limits stop spending, and which only warn

A limit that stops spending refuses the request before it reaches the
model, so the refused request costs nothing. A warning arrives after the
money is spent.

| Limit | Kind | Value |
| --- | --- | --- |
| App Check | Stops: requests that don't come from the app are refused | Enforced |
| Requests per person, per minute (AI Logic) | Stops, with a 429 | 20; the Live API, which the app does not use, 0 |
| Requests per model, per minute and per day, on every paid tier | Stops, with a 429 | 3.8 Flash: 60 a minute, 300 a day. 3.5 Flash: 30 and 100 |
| Every other model, priority processing, images and video | Stops | 0 |
| Free tier, while the project is on Spark | Stops | 5 requests a minute and 20 a day per model, for the whole project |
| Spend cap on Firebase AI Logic (preview) | Stops the service a few minutes late; the overage is billed | Pending: needs Blaze |
| Gemini API prepay balance, if the account requires it | Stops at zero, about ten minutes late | Pending: needs Blaze |
| Gemini API tier 1 | Stops | US$10 per 10 minutes, US$250 a month per billing account |
| Budget alerts | Warns, hours late | Pending: needs Blaze |
| Monitoring alerts by email | Warns | Bursts over 150 requests in 10 minutes, more than 10 refusals (429) in 10 minutes, a Gemini quota running out |
| 30 questions a day in the app | Neither: it guides the person, and reinstalling resets it | 30 |

`tool/firebase/caps.py` sets the quota limits and shows them (`--check`).
`tool/firebase/alerts.py` sets up the alerts. Both act as whoever is signed in
to `gcloud`.

### What "per person" means

Firebase doesn't document who counts as one person for the per-minute limit.
Google Cloud counts per-user quotas against the authenticated principal, or
the IP address when there is none. A Firebase ID token is probably not such
a principal, so the limit is likely per IP address. If so, people behind the
same carrier NAT share it, and creating a new anonymous account does not
reset it. A short test would settle it: two anonymous users from the same
address, with the limit lowered for a minute.

No server-side limit counts a person's questions per day. The daily limits
above are for the whole project. A real per-person daily limit needs a
small backend that counts by user and calls Gemini itself, such as a Cloud
Function with Firestore, and that needs Blaze.

## Privacy, before real financial data

The tools send Gemini totals, balances, account names and, when a question
asks for them, the largest payments of a month with their merchants.

- **Spark, Gemini Developer API**: these are the Gemini API's Unpaid
  Services. Google may use prompts and answers to improve its products, and
  people may review them. The terms ask developers not to send personal
  information to Unpaid Services. **No real financial data on Spark.** The
  in-app note says so.
- **Blaze, Gemini Developer API**: Paid Services. Prompts and answers are not
  used to improve products. They are kept for 55 days for abuse monitoring,
  and the Developer API offers no zero data retention.
- **Blaze, Agent Platform** (formerly Vertex AI, `FirebaseAI.agentPlatform()`
  in firebase_ai 4): Google Cloud's service terms forbid training on
  customer data. Prompts are logged for abuse monitoring only when a
  classifier flags them, for up to 90 days, and Google takes requests to
  opt out. The 24-hour cache can be switched off. It costs the same on the
  `global` location.
- **Both models are stable**, not previews, and the same terms apply to both.
  3.5 Flash will be retired no earlier than May 2027. On Agent Platform, 3.8
  Flash is a short-term model that can be retired 45 days after its
  replacement ships.
- People in the EEA, the UK or Switzerland may only be served with Paid
  Services. The terms also rule out relying on Gemini for financial advice,
  and apps directed at minors.

Recommended: Blaze, with Agent Platform on the `global` location, the cache
off and the abuse-logging opt-out requested, before any real account goes
through it.

Sources: [Gemini API terms](https://ai.google.dev/gemini-api/terms),
[AI Logic data governance](https://firebase.google.com/docs/ai-logic/data-governance),
[Gemini API usage policies](https://ai.google.dev/gemini-api/docs/usage-policies),
[Agent Platform zero data retention](https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/zero-data-retention),
[AI Logic models](https://firebase.google.com/docs/ai-logic/models).

## What a question costs

The system prompt is about 77,000 characters, roughly 21,000 tokens. Most of
it is the catalog. A question takes two or three rounds, and each round sends
it again: about 45,000 to 70,000 input tokens and 1,500 output tokens.

Gemini 3.8 Flash costs US$0.75 per million input tokens and US$3.75 per
million output tokens until 31 December 2026, and double that from January
2027. Cached input costs a tenth. A question costs about US$0.02 with the
prompt cached and US$0.05 without. Every question that falls back to 3.5
Flash costs about twice as much.

The cheapest saving is a shorter catalog description in the prompt.

## Pending

Waiting on the owner:

1. Choose the billing account for Blaze and approve a monthly budget.
2. After linking it: check in AI Studio whether the account asks for a
   prepay (US$5 minimum). Without auto-reload, the balance is a hard cap.
   Then set a spend cap on Firebase AI Logic (Firebase console > Settings >
   Usage and billing > Details & settings) and a budget with alerts at 50%,
   90% and 100%, with the amount in pesos (`100000COP` is 100,000):

   ```bash
   gcloud billing budgets create --billing-account=ACCOUNT_ID \
     --display-name="Quincena" --budget-amount=AMOUNTCOP \
     --filter-projects=projects/quincena-dlsoft \
     --threshold-rule=percent=0.5 --threshold-rule=percent=0.9 \
     --threshold-rule=percent=1.0 \
     --threshold-rule=percent=1.0,basis=forecasted-spend
   ```

3. Choose the Developer API or Agent Platform for financial data.
4. Play Integrity:
   1. Create the upload key and point `android/key.properties` at it:

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
      internal testing.
   3. Link `quincena-dlsoft` under Protected with Play > Play Integrity API.
      This needs a direct Owner of the project.
   4. Add the SHA-256 of Play's app signing certificate to the Android app in
      Firebase, and register Play Integrity in App Check.

   Builds that don't come from Google Play fail Play Integrity. They keep
   using the debug provider.
5. Sign in to Xcode with DL SOFT's Apple account. An iPhone needs it to run
   the app at all, since App Attest needs a provisioning profile with the
   capability. The Mac app needs it to be signed with the team: until then
   the keychain refuses the anonymous account, so a Mac asks with App Check
   alone and no user, and App Attest or DeviceCheck can't vouch for a
   release build.

Technical, once those are settled:

- Restrict the Android key to the package and the signing certificates.
- Replay protection (single-use App Check tokens): each request then costs an
  attestation. Play Integrity allows 10,000 a day, and reCAPTCHA gives 10,000
  free assessments a month for the whole organization.
- A per-person daily limit on a server, if 30 a day has to hold.
- Flutter 3.44.9 before Xcode 27: 3.44.8 fixes the build with it.
