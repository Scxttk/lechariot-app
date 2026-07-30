import SwiftUI

/// Reserved places for future advertising. Nothing renders today —
/// `AdSlotView` is an `EmptyView`.
///
/// One rule decides all three: an ad that can be mistaken for a recommendation
/// makes "Einkaufsliste ohne Beeinflussung" untrue. So never on the
/// Einkaufsplan-Karte, never in the suggestion tiles, never during onboarding.
/// Which slot is worth what, and what a creative has to satisfy before it ships:
/// `docs/ADS.md`.
enum AdSlot {
    case offerListInline
    case shoppingListFooter
    case settingsFooter
}

/// Placeholder for a future ad. Renders nothing.
struct AdSlotView: View {
    let slot: AdSlot

    var body: some View {
        // TODO: Werbung — render the creative for `slot` here. Read
        // docs/ADS.md first; the reserved-height and silent-failure rules are
        // the two that break the list if you skip them.
        EmptyView()
    }
}
