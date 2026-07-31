# Werbeplätze

Nothing renders yet. `AdSlot` in `ios/LeChariot/Views/Ads/AdSlot.swift` reserves
three places and `AdSlotView` returns `EmptyView()`, so the slots cost nothing
until someone fills them. This file is the reasoning that used to sit in that
file's header.

## The rule

Le Chariot's pitch is "Einkaufsliste ohne Beeinflussung": the app names the
cheapest shop for your list, and nobody pays to be the answer. An ad that looks
like an offer doesn't just annoy — it makes that claim untrue. So the question
is never "where do ads earn most", it's "where can an ad sit without ever being
read as a recommendation".

## The slots, ranked

1. **`.offerListInline`** — in the Angebote tab, between two market sections.
   The best of the three: the user is browsing, not deciding, the scroll
   context tolerates an interruption, and a full-width card is obviously not a
   row.
2. **`.settingsFooter`** — bottom of the settings. Nearly invisible. Only
   really useful as a house slot, e.g. promoting a paid tier.

`.shoppingListFooter` **was** here — under the list, after "Erledigt" — and was
removed on 2026-07-31 with the personal suggestion strip. The reasoning that
justified it ("out of the decision path, modest, safe") was written when the
strip above it showed eight fixed staples. It now shows what this household
actually buys, and an ad under *that* is not the same object: it sits below a
strip that knows the answer, on a screen whose whole claim is that nobody paid
for what it recommends. The slot is gone rather than merely unused, because an
unused slot is an invitation.

## Where an ad must never go

- **The Einkaufsplan-Karte and the suggestion tiles in the list rows.** That is
  the recommendation itself. A paid placement next to "Am besten zu Lidl ·
  19,32 €" is precisely the manipulation the app exists to avoid.
- **Onboarding.** The old waiting screen made this tempting — it's gone now,
  but the reason stands: it's the first impression, and the user hasn't yet
  seen one thing the app does for them.
- **The suggestion grid that typing opens** (L-4 in `Le Chariot
  Liste-Konzept`, not built yet — this line is here *before* it, on purpose).
  That grid is the moment of choosing. Bring! sells exactly this position:
  screenshot 3 of that note shows "Dr. Oetker Vitalis Müsli" sitting between
  Buttermilch and Hafermilch, correctly badged, and **it still looks like every
  other search result**. Which is the second half of the rule below:
  **labelling is necessary, not sufficient.** A paid tile in a list of
  dictionary terms cannot be made honest by a badge, because the harm is the
  ranking, not the disclosure.

## Before a slot ships

- A label ("Anzeige") and a look that can't be confused with
  `Theme.cardSurface()` — different corner radius, or a hairline in a non-brand
  colour.
- Height reserved *before* the creative loads. Otherwise the list jumps under
  the user's thumb mid-scroll.
- Offline and failure paths collapse the slot to nothing. Never a grey box,
  never a spinner.
- A kill switch, so a paid tier can turn ads off without a release.
