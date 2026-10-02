# Production

Where Quincena's Firebase project stands before real people and real money
go through it. Checked on 2 October 2026. Nothing here is published yet: the
web demo deploys from `main`, and none of this has been merged.

## What is set up

The project is `quincena-dlsoft`, on the Blaze plan with DL SOFT's billing
account, with three apps: Android, Apple (iOS and macOS share the bundle ID
`dev.dlsoft.quincena`) and web.

- **Gemini runs on Agent Platform**, Google Cloud's (formerly Vertex AI), on
  the `global` location, through Firebase AI Logic. The project's prompt
  cache is off. The Gemini Developer API, which the app used before, is
  closed: every one of its quotas is at zero.
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
- **API keys** only reach Firebase APIs, so none of them can call Gemini
  directly. The Apple key only answers the app's bundle ID, and the web key
  only answers `diegolopezrm.github.io` and `localhost`. The Android key waits
  for the signing certificates (see Play Integrity below).
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
itself, such as a Cloud Function with Firestore.

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
  directed at minors.

Sources: [Agent Platform zero data retention](https://docs.cloud.google.com/gemini-enterprise-agent-platform/resources/zero-data-retention),
[Agent Platform abuse monitoring](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/abuse-monitoring),
[AI Logic data governance](https://firebase.google.com/docs/ai-logic/data-governance),
[Gemini API terms](https://ai.google.dev/gemini-api/terms),
[AI Logic models](https://firebase.google.com/docs/ai-logic/models).

## What a question costs

The system prompt is about 77,000 characters, some 19,000 tokens on Agent
Platform. Most of it is the catalog. Every round of an answer sends it again:
the model asks for the tools it needs, gets their answers, and writes the
surface. The prompt now asks for every tool at once, which brought the
spending question from six rounds to four; simpler ones take two. The last
round writes about 1,100 tokens and thinks another 2,000 to 3,500, even at
the low thinking level, the lowest 3.8 Flash takes.

At 3.8 Flash's prices until 31 December 2026, US$0.75 per million input
tokens and US$3.75 per million output tokens, with the cache off, a question
costs about US$0.04 to US$0.08. From January 2027 the prices double. COP
100,000 a month covers some 400 to 750 questions. An answer takes 25 to 60
seconds, most of it that last round.

The prompt cache would make every round after the first far cheaper, at the
price of Google keeping the prompt in memory for up to 24 hours. A shorter
catalog description would save on every round either way.

## Pending

Waiting on the owner:

1. Request the opt-out from Agent Platform's abuse logging, with the form
   linked from the abuse monitoring page. It asks for the organization's
   details.
2. Play Integrity:
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
3. Sign in to Xcode with DL SOFT's Apple account. An iPhone needs it to run
   the app at all, since App Attest needs a provisioning profile with the
   capability. The Mac app needs it to be signed with the team: until then
   the keychain refuses the anonymous account, so a Mac asks with App Check
   alone and no user, and App Attest or DeviceCheck can't vouch for a
   release build.
4. Decide on the prompt cache: cheaper, or nothing kept in memory.

Technical, once those are settled:

- Restrict the Android key to the package and the signing certificates.
- Replay protection (single-use App Check tokens): each request then costs an
  attestation. Play Integrity allows 10,000 a day, and reCAPTCHA gives 10,000
  free assessments a month for the whole organization.
- Server prompt templates, to pin the model and the prompt on the server.
- A shorter catalog description in the prompt.
- A per-person daily limit on a server, if 30 a day has to hold.
- Flutter 3.44.9 before Xcode 27: 3.44.8 fixes the build with it.
