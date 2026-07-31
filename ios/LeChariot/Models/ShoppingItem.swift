import Foundation

/// One entry of the local shopping list. Free text — matching against offers
/// happens at display time, never persisted.
struct ShoppingItem: Codable, Equatable, Identifiable {
    let id: UUID
    var text: String
    var isChecked: Bool
    let addedAt: Date

    /// What this item is, more precisely — a note for the person in the shop,
    /// **never** part of the query.
    ///
    /// Bring! writes "corny hafer schoko" under an item called "Riegel": the
    /// entry stays the generic word, the specific part hangs off it. We copy
    /// that, and the reason is arithmetic rather than taste. `OfferMatcher`
    /// stage 1 requires **every** word of the query to hit a title token, and
    /// stage 2 keeps that an AND. "Landliebe Butter Original" would only be
    /// findable where that exact brand is on offer; everywhere else butter
    /// would count as uncovered, the coverage figure in the plan card would
    /// drop, and the recommended market could change. The same holds for a
    /// fourth word like "Bio".
    ///
    /// Stored as the chosen chips rather than one string so the vocabulary
    /// stays inspectable, and **optional with a default** so lists written by
    /// older builds keep decoding — a tester has had the app on their device
    /// since 2026-07-30, and a list that empties itself on update is the worst
    /// bug this app could ship.
    var detail: [String]?

    init(
        id: UUID = UUID(),
        text: String,
        isChecked: Bool = false,
        addedAt: Date = .now,
        detail: [String]? = nil
    ) {
        self.id = id
        self.text = text
        self.isChecked = isChecked
        self.addedAt = addedAt
        self.detail = detail
    }

    /// The one string that leaves this item — to the matcher, to the purchase
    /// counter, and into the feedback report.
    ///
    /// It exists so the boundary has a name. `text` alone would work today;
    /// what it would not do is make the next person notice that appending the
    /// detail here is the thing that breaks matching.
    var query: String { text }

    /// The detail as one line, or nil when there is nothing to show.
    var detailLine: String? {
        guard let detail, !detail.isEmpty else { return nil }
        return detail.joined(separator: " · ")
    }
}
