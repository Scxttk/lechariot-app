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
