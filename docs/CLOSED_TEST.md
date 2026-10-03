# Closed test: two fortnights with real people

The roadmap's last check before Quincena grows: people using it with their
own money from one payday to the second after it. This page is the plan,
what it measures, and what to send the people who take part.

Quincena has no analytics and this does not add any: what it measures, it
measures by asking. The people's finances stay on their phones; nothing in
this plan collects them.

## Who

Eight to twelve people in Colombia, chosen so every part of the app is
used by someone:

- Paid twice a month, and at least three paid monthly or with variable
  income (one freelancer at least).
- At least four on Android and four on iPhone.
- At least three with a credit card in use, and two who split expenses
  with someone.
- At least two who have never kept a budget.

Not family of DL SOFT, if possible: they forgive too much.

## How they get the app

- **iPhone:** an external TestFlight group. The first build sent to it goes
  through Apple's beta review, a day or two.
- **Android:** a closed testing track in Play Console with the testers'
  emails, apart from the internal track and from production.

Both take the build that closes phase 19 or a later one.

## When

From a payday to the second payday after it, for example from 15 October
to 15 November 2026. Starting on a payday means "Me llegó la quincena" and
the envelopes are the first thing they see.

## What is measured

The roadmap's rules ask for these. Each has its question and its moment.

| What | How | When |
| --- | --- | --- |
| Understanding what is free | "¿Cuánto puedes gastar y hasta cuándo?" Right if it matches Inicio within a day's spending | Day 1, 7, 15 and 30 |
| Explaining a figure | "¿De dónde sale esa cifra?" Right if they name what is held back (payments, cushion, envelopes) | Day 7 and 30 |
| Time to review captures | They time "Por revisar" once, start to empty | Day 7 and 21 |
| Corrections | "De lo que llegó solo, ¿cuánto tuviste que cambiar: casi nada, algo, mucho?" | Day 15 and 30 |
| Usefulness | "¿Cambió alguna decisión tuya esta quincena? ¿Cuál?" and "¿Lo seguirías usando?" | Day 15 and 30 |
| Gemini | How many questions they asked, which answer helped, which did not; reports sent arrive in Firestore | Day 15 and 30 |
| Problems | Anything that failed, was lost or confused them, as it happens | Always |

Day 1 and the first week set the baseline. Targets come after it, as the
roadmap asks, not before.

## How it runs

- A short interview by video at the start (20 minutes): installing,
  onboarding with their own accounts, turning on capture. Watching, not
  helping, unless they are stuck.
- The check-ins on days 1, 7, 15, 21 and 30, five questions or fewer, by
  WhatsApp or a form. Answers are kept in one sheet, by person and day,
  with no amounts.
- A closing interview at day 30 (20 minutes): what they would keep, what
  they would remove, and the tasks above once more.
- One WhatsApp group for problems, with DL SOFT answering within a day.

## When it is done

- No lost data and no crash that a tester could not get past.
- What each person answered, against the baseline, in one page per
  measure, with what changes in the app because of it.
- The decision to grow, wait, or change first, written in the roadmap.

## Messages for the testers

**Invitation**

> Hola, {nombre}. Estoy probando Quincena, una app que te dice cuánto
> puedes gastar hasta tu próximo pago sin dañar tus planes. ¿Me ayudas a
> probarla durante dos quincenas, del {inicio} al {fin}? Son unos minutos
> a la semana: usarla con tus cuentas y responderme cinco preguntas cada
> tanto. Tus cuentas y movimientos se quedan en tu teléfono; yo no los veo
> ni los recibo. Si te animas, te mando el enlace para instalarla.

**Day 1**

> ¡Bienvenido! Para empezar: abre Quincena, elige "Con mis cuentas" y
> agrega las que usas para gastar, con lo que tienen hoy. Si quieres que
> los pagos lleguen solos, actívalo en Ajustes, Captura automática. Hoy
> solo una pregunta: ¿cuánto dice Quincena que puedes gastar y hasta
> cuándo? ¿Te parece cierto?

**Check-in (days 7, 15, 21 and 30, the ones that apply)**

> 1. ¿Cuánto puedes gastar y hasta cuándo, según Quincena?
> 2. ¿De dónde sale esa cifra?
> 3. De lo que llegó solo, ¿cuánto tuviste que cambiar: casi nada, algo o
>    mucho?
> 4. ¿Cambió alguna decisión tuya esta quincena? ¿Cuál?
> 5. ¿Algo falló, se perdió o te confundió?
