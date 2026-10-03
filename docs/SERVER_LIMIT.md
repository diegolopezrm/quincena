# A daily limit counted on the server

Phase 19 asks for a design before any code: today the 30 questions a day
are counted on the phone. This is that design, what it would cost, and
what has to be decided before it is built.

## What protects Gemini today

| Limit | Where | What gets around it |
| --- | --- | --- |
| App Check | Google | Nothing outside the app: requests must come from a genuine install |
| 20 requests a minute per person | Firebase AI Logic | Probably counted per IP address (see [PRODUCTION.md](PRODUCTION.md)), so a new IP |
| 30 questions a day | The phone | Reinstalling, clearing the app's data, or a modified app |
| COP 100,000 a month | The billing account's spend cap | Nothing: it stops Gemini for everyone |

The daily limit is the only one a person meets, and it is the weakest. The
spend cap is the strongest and the bluntest. At 20 requests a minute, about
US$0.01 to US$0.02 a request, one device that passes App Check can spend
some US$12 to US$25 an hour. The cap, about US$25, would last an hour or
two, and Gemini would then stop for everyone until the month ends.

So a server-side limit protects availability more than money: it keeps one
person from using up everyone's month.

## What does not work

- **A counter the app writes to Firestore.** Rules can check a counter goes
  up by one, but nothing ties the counter to the call to Gemini: a modified
  app skips the counter and calls Gemini anyway.
- **Firebase AI Logic's server prompt templates.** In their template-only
  mode they pin the model and the prompt, which is worth having, but they
  count nothing per person or per day.
- **Quotas on Agent Platform.** The models the app uses run on dynamic
  shared quota, where a project's overrides do not apply (tried when the
  caps were set), and they would be per project anyway, not per person.

## The design: a function in front of Gemini

A callable Cloud Function, `ask`, becomes the only way to Gemini. The app
sends it what it sends AI Logic today, one round at a time; the function
counts, refuses or forwards, and streams the answer back.

```
app ──(App Check, anonymous ID token)──▶ ask ──▶ Gemini on Agent Platform
                                          │
                                          └──▶ Firestore: limits/{day}/people/{uid}
```

- **Who.** App Check is enforced on the function, and the request carries
  the anonymous Firebase ID token the app already has. The person is the
  uid.
- **What it counts.** Rounds and tokens, not questions: a question is
  several rounds and the app decides when one starts, so a modified app
  could call every round the first. Tokens are what cost money, and Gemini
  reports them with every answer.
- **Limits.** Per person and day: 150 rounds (30 questions at up to five
  rounds) and 1.5 million tokens. For everyone and day: one thirtieth of the
  monthly cap, about US$0.85 today. The second is the one that protects
  everyone: one bad day can no longer take the month. It also says how
  small the cap is: at US$0.02 to US$0.05 a question, the whole app averages
  20 to 40 Gemini questions a day, and the ceiling has to grow with it.
- **How.** Before calling Gemini, a transaction reads the person's and the
  day's counters and refuses with `resource-exhausted` if either is spent.
  After, it adds the tokens Gemini reports. Counters carry an `expireAt` and
  a TTL policy deletes them after a week.
- **What it pins.** The model, the thinking level and the output limit are
  set in the function, not taken from the request. Today anyone holding a
  valid App Check token can ask any model on `global`; with the function,
  only the one the app uses.
- **What it never keeps.** The prompt, the tools' answers and the reply
  pass through and are not logged or stored. The counters hold a uid, a
  day and three numbers.
- **Streaming.** The function streams each chunk back as Gemini writes it,
  so answers still draw as they arrive. Callable functions can stream with
  `sendChunk`; whether FlutterFire's `cloud_functions` reads a streamed
  callable on every platform the app runs on has to be checked before
  building. Without it, an answer appears whole at the end of its last
  round.
- **Where.** `us-central1`, next to the Firestore database in `nam5`.

The device keeps doing what it does now: the tools run on the phone against
the person's own data, and only what they return goes to Gemini. The
function sees the same as Gemini does.

### In the app

- A `FunctionGeminiClient` beside `FirebaseGeminiClient`, with the same
  shape, chosen at build time. It maps `resource-exhausted` to the messages
  the app already has: no questions left today, or Gemini resting until
  tomorrow when the day's ceiling is spent.
- The 30 on the phone stay as what the person sees; the server's are what
  holds.

### Turning AI Logic off

The function only limits anything once it is the only way in. After a
version that uses it has reached everyone, Firebase AI Logic's per-person
limit goes to zero, so App Check tokens can no longer reach Gemini through
it. Until then both work, and the function guards only its own traffic.

### Privacy

The policy says questions are not kept on any Quincena server, which stays
true. It would add that they pass through a DL SOFT function in Google
Cloud, which counts how many a person asks each day and keeps nothing else,
and that the count is deleted after a week.

## What it costs

- **Cloud Functions:** the free tier covers 2 million invocations a month;
  at four rounds a question, that is 500,000 questions.
- **Firestore:** two reads and four writes a round (the person's counter and
  the day's), inside the free tier's 20,000 writes a day up to some 1,200
  questions a day. Past that, about US$0.18 per 100,000 writes. The day's
  counter takes every round's writes; it needs splitting into shards only
  past about one round a second.
- **Latency:** 50 to 200 ms a round, plus a cold start of one to two seconds
  on the first question after a quiet spell. One instance kept warm removes
  the cold start for about US$5 to US$10 a month.
- **Work:** the function with its tests against the Firebase emulators, the
  client, the error messages, and the policy. About two phases' worth.

## To decide

1. **When.** Now, before more people use Gemini, or when the budget alerts
   first show unusual spending. The monthly cap keeps the worst case at
   COP 100,000 either way; what changes is whether one person can stop
   Gemini for everyone.
2. **The limits.** 150 rounds and 1.5 million tokens a person a day, and a
   thirtieth of the monthly cap for everyone, or other numbers.
3. **The language.** TypeScript with `firebase-functions`, the supported
   path, or Dart on Cloud Run, which keeps one language and has no Firebase
   SDK for functions.
4. **A warm instance.** About US$5 to US$10 a month against a slower first
   question.
