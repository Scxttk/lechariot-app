import SwiftUI

/// Reserved places for future advertising. **Nothing is rendered today** —
/// `AdSlotView` is deliberately an `EmptyView`, so the slots cost nothing at
/// runtime and can be filled later without touching layout code.
///
/// ## Why the placement matters more than usual here
///
/// Le Chariot's pitch is *"Einkaufsliste ohne Beeinflussung"* — the app tells you
/// which shop is cheapest for **your** list, with nobody paying to be the
/// answer. An ad that looks like an offer does not just annoy, it makes the
/// product's central claim untrue. So the rule is not "where do ads earn most"
/// but "where can an ad sit without ever being mistaken for a recommendation".
///
/// ## The slots, ranked
///
/// 1. `.offerListInline` — inside the Angebote tab, between two market sections.
///    Best slot: the user is browsing rather than deciding, the scroll context
///    tolerates an interruption, and a full-width card is clearly not a row.
/// 2. `.shoppingListFooter` — below the shopping list, after "Erledigt". Out of
///    the decision path, seen on almost every session. Modest but safe.
/// 3. `.settingsFooter` — bottom of the settings. Nearly invisible; useful only
///    as a house slot (e.g. promoting a paid tier).
///
/// ## Where ads must never go
///
/// - The **Einkaufsplan-Karte** and the **suggestion tiles in the list rows**.
///   That is the recommendation itself; a paid placement next to "Am besten zu
///   Lidl · 19,32 €" is exactly the manipulation the app exists to avoid.
/// - The **onboarding**, including `WaitingView`. The wait is long enough to be
///   tempting, but it is also the first impression, and the user has not yet
///   seen a single thing the app does for them.
///
/// ## What filling a slot will need
///
/// - A label ("Anzeige") and a visual treatment that cannot be confused with
///   `Theme.cardSurface()` — different corner radius or a hairline in a
///   non-brand colour.
/// - A fixed height reserved *before* the creative loads, otherwise the list
///   jumps under the user's thumb mid-scroll.
/// - Offline and failure paths: the slot must collapse to nothing, never to a
///   grey box or a spinner.
/// - A kill switch, so ads can be turned off for a paid tier without a release.
enum AdSlot {
    case offerListInline
    case shoppingListFooter
    case settingsFooter
}

/// Placeholder for a future ad. Renders nothing.
struct AdSlotView: View {
    let slot: AdSlot

    var body: some View {
        // TODO: Werbung — render the creative for `slot` here. See the AdSlot
        // docs above for the constraints (label, reserved height, silent
        // failure, kill switch) before wiring anything up.
        EmptyView()
    }
}
