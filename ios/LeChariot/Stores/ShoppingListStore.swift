import Foundation
import Observation

// MARK: - Offer matching

/// Suggestion logic for shopping-list items on top of OfferMatcher: rejected
/// matches drop out, and the suggested offer is the cheapest direct hit,
/// falling back to the cheapest category hit.
enum ShoppingListMatcher {
    static func matches(
        for text: String,
        in offers: [Offer],
        isRejected: (Offer) -> Bool = { _ in false }
    ) -> [OfferMatch] {
        OfferMatcher.matches(for: text, in: offers).filter { !isRejected($0.offer) }
    }

    static func cheapestMatch(
        for text: String,
        in offers: [Offer],
        isRejected: (Offer) -> Bool = { _ in false }
    ) -> OfferMatch? {
        // matches() already orders direct-before-category, each by price —
        // but priceless offers sort last, so prefer the first priced hit.
        let ranked = matches(for: text, in: offers, isRejected: isRejected)
        return ranked.first { $0.offer.price != nil } ?? ranked.first
    }
}

// MARK: - Quick-add suggestions

/// The staples offered as one-tap chips on the shopping list.
///
/// Lives outside the view so the "what is still worth suggesting" rule is
/// testable — it used to be a private constant behind the empty state, where
/// the whole strip vanished the moment the first chip was tapped.
enum ShoppingSuggestions {
    /// Staples that cover most first lists. The empty screen is otherwise a
    /// text field and nothing to react to — one tap here and the app can
    /// immediately show what it is for.
    static let staples = [
        "Milch", "Brot", "Butter", "Eier",
        "Käse", "Bananen", "Kaffee", "Nudeln",
    ]

    /// The staples not on the list yet, in their fixed order.
    ///
    /// Checked items count as on the list: re-suggesting what the user just
    /// ticked off would be the app arguing with them, and `add` would refuse
    /// the duplicate anyway.
    static func remaining(for items: [ShoppingItem], from staples: [String] = staples) -> [String] {
        let taken = Set(items.map { $0.text.lowercased() })
        return staples.filter { !taken.contains($0.lowercased()) }
    }

    /// How many tiles the strip shows.
    static let stripLength = 8

    /// Tags that are never a shopping list entry.
    private static let notGroceries: Set<String> = ["nonfood"]

    /// The strip: staples first, then topped up from **this week's offers** so
    /// it keeps its length instead of running dry.
    ///
    /// The old behaviour was the opposite of what it should be: eight fixed
    /// staples, minus whatever is already on the list, so the strip shrank
    /// with every tap and was gone after eight. Now new ones move up.
    ///
    /// The top-ups come from the `match_key` tags of the offers, not from
    /// product titles: a tag *is* a shopping term ("käse", "bananen") and is
    /// by construction something the matcher can find again, whereas
    /// "K-Classic Bio Vollmilch 1l" is a flyer headline nobody writes on a
    /// list. Ordered by the best discount carrying that tag — so a suggestion
    /// has a reason, which is the whole difference to a longer fixed list.
    static func strip(
        for items: [ShoppingItem],
        offers: [Offer],
        limit: Int = stripLength
    ) -> [String] {
        var taken = Set(items.map { $0.text.lowercased() })
        var result: [String] = []

        for staple in staples where !taken.contains(staple.lowercased()) {
            result.append(staple)
            taken.insert(staple.lowercased())
            if result.count == limit { return result }
        }

        // Best discount per tag; a tag without a discount still counts, just
        // last — "im Angebot" beats "nothing to suggest".
        var bestDiscount: [String: Int] = [:]
        for offer in offers {
            for tag in offer.matchKeys where !notGroceries.contains(tag) {
                let discount = offer.discountPercent ?? 0
                if let seen = bestDiscount[tag], seen >= discount { continue }
                bestDiscount[tag] = discount
            }
        }

        let ranked = bestDiscount
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)

        for tag in ranked {
            let word = tag.prefix(1).uppercased() + tag.dropFirst()
            guard !taken.contains(word.lowercased()) else { continue }
            result.append(word)
            taken.insert(word.lowercased())
            if result.count == limit { break }
        }
        return result
    }
}

// MARK: - Store

/// Local source of truth for the shopping list.
///
/// Persistence: UserDefaults, same rationale as RegionStore — a handful of
/// short strings, no queries or relations, so SwiftData would be overkill.
@MainActor
@Observable
final class ShoppingListStore {
    private(set) var items: [ShoppingItem]

    private let defaults: UserDefaults
    private static let key = "shopping.items"

    init(defaults: UserDefaults = AppDefaults.shared) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
            self.items = stored
        } else {
            self.items = []
        }
    }

    var uncheckedItems: [ShoppingItem] { items.filter { !$0.isChecked } }
    var checkedItems: [ShoppingItem] { items.filter(\.isChecked) }

    /// Adds an item unless one with the same text already exists
    /// (case-insensitive, like the CLI). Returns false on duplicates.
    @discardableResult
    func add(_ rawText: String) -> Bool {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        guard !items.contains(where: { $0.text.lowercased() == text.lowercased() }) else {
            return false
        }
        items.append(ShoppingItem(text: text))
        persist()
        return true
    }

    func toggle(_ item: ShoppingItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isChecked.toggle()
        persist()
    }

    func remove(_ item: ShoppingItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clearChecked() {
        items.removeAll { $0.isChecked }
        persist()
    }

    func clearAll() {
        items.removeAll()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Self.key)
        }
    }

    #if DEBUG
    /// See `DebugReset`. Clears memory and disk, not just the array — a
    /// `clearAll()` would leave an empty-but-present record behind.
    func resetAllData() {
        items = []
        defaults.removeObject(forKey: Self.key)
    }
    #endif
}
