# Quincena

[![CI](https://github.com/diegolopezrm/quincena/actions/workflows/ci.yml/badge.svg)](https://github.com/diegolopezrm/quincena/actions/workflows/ci.yml)

Personal finance where every answer is an interface.

Ask where September's money went and you get a donut chart, the two things
that moved and the five largest payments. Ask whether you can afford
Cartagena in December and you get a goal with a slider: drag it and the
arrival date recalculates on the device, with no new message from the agent.
Ask what subscriptions you have and you get a list with a switch on each row
and a footer that says what cancelling the switched-off ones would save.

None of those screens is in the source. An agent composes each one at runtime
from a catalog of components, with [genui](https://pub.dev/packages/genui)
rendering them and [genui_gen](https://pub.dev/packages/genui_gen) deriving
the catalog from the widgets' own constructors.

The account is made up. Valentina is a designer in Medellín, paid on the 15th
and the last day of the month, saving for a trip while she pays off a student
loan. Every merchant is made up too.

## What it shows

**A catalog with no second source of truth.** Twenty components and six
functions, each written as an ordinary Flutter widget or Dart function and
annotated. The JSON schema the agent composes against, the builder that turns
its JSON back into the widget, and the example data are generated from the
constructor. [`catalog.json`](catalog.json) is the same catalog as an agent
outside the app sees it, checked against the Dart on every test run.

**Interfaces that keep working after the agent is done.** The goal planner's
slider writes to the data model, and two catalog functions read from it to say
when the goal is reached and whether that is in time. The subscription list is
a template repeated over the data, each row's switch writes to its own entry,
and a function over the whole list totals the savings. A form validates with
rules the agent wrote, and the message of the first failing rule shows under
the field.

**The tooling around it.** Turn on developer mode in settings and the
genui_gen inspector sits over the conversation: the component tree the agent
built, every data path with what reads it, what a screen reader announces,
and the messages that got the screen there. "Copiar la sesión" puts the
whole session on the clipboard as a genui_gen trace, with what the person
typed into a form redacted, ready to paste into an issue and replay.

**Two languages.** The app speaks Spanish and English, following the device
or the choice in settings. The scripted answers, the prompt Gemini gets,
the catalog's own words and every amount and date switch together:
`$ 4.719.400` and `19 sept` in Spanish, `$4,719,400` and `Sep 19` in English.

## Run it

```bash
flutter pub get
flutter run -d chrome
```

The demo runs offline. A scripted agent answers the questions on the home
screen with the same components, bindings and function calls a model sends,
and every number in its answers comes from the account, so saving an expense
changes the next answer.

## Talk to Gemini

In settings, choose "Gemini en vivo" and paste a key from
[Google AI Studio](https://aistudio.google.com). The key stays in the tab:
it is not saved, and it only travels to Google. Then ask anything about the
account.

Gemini gets the catalog through genui's prompt builder, with two of its
defaults switched off: the chat preset forbids `updateDataModel`, which every
interactive component here relies on, and tells a model that cannot run code
to do arithmetic itself, which a finance app must never let it do. It gets
the numbers from tools that ask the account, never from its own head. When a
surface it sends fails validation against the catalog, genui reports why and
the app sends that back within the same turn, so the person sees the
corrected answer rather than the broken one.

For a local run you can also pass the key at build time:

```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=your-key
```

Never do that for a build you publish: a web build made with the key
defined carries it in its JavaScript.

## Recording real sessions

```bash
GEMINI_API_KEY=your-key flutter test tool/record
```

asks Gemini each question on the home screen and writes what it sent to
`assets/traces/` as genui_gen traces. The app replays them in "Lo que
respondió Gemini", step by step and with no network, and
`test/recorded_test.dart` replays every one against the current catalog on
each run, so a catalog change that would break a real conversation fails a
test instead of a person.

After changing a widget or a function, regenerate the catalog:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Tests

```bash
flutter test
```

Besides the answers themselves, in both languages and at twice the system
text size, the catalog is held to three things.
`genUiFuzz` renders everything the schema allows and fails on anything that
breaks. `genUiSemanticsAudit` fails on a control a screen reader cannot name.
And `catalog.json` has to match the Dart.

The first two earned their place on the first run. The fuzzer found that every
component crashed under any theme but the app's own, and the audit found that
the goal slider announced its value without saying what the value was of.

## Layout

| Path | What is there |
|---|---|
| `lib/catalog/` | the components the agent composes with, and the data shapes they take |
| `lib/functions/` | the functions the agent can call from a binding |
| `lib/agent/` | the assembled catalog, the prompt, the tools, the scripted agent and the live one |
| `lib/data/` | the account: movements, subscriptions, the goal |
| `lib/ui/` | the screen around the conversation |

## Credits

Type is [Bricolage Grotesque](https://fonts.google.com/specimen/Bricolage+Grotesque)
and [Geist](https://fonts.google.com/specimen/Geist), under the SIL Open Font
License. Icons are [Phosphor](https://phosphoricons.com), under the MIT
license. The licenses sit next to the files in `assets/`.
