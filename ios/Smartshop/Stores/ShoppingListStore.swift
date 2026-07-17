import Foundation
import Observation

// MARK: - Offer matching

/// Finds the cheapest current offer for a shopping-list item. Mirrors the CLI's
/// `list suggest`: case-insensitive substring match on the product name.
enum ShoppingListMatcher {
    static func cheapestMatch(for text: String, in offers: [Offer]) -> Offer? {
        let needle = text.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return nil }
        return offers
            .filter { $0.price != nil && $0.product.localizedCaseInsensitiveContains(needle) }
            .min { lhs, rhs in
                let (lp, rp) = (lhs.price!, rhs.price!)
                if lp != rp { return lp < rp }
                // Same price: prefer the better base price when known.
                return (lhs.basePrice ?? .infinity) < (rhs.basePrice ?? .infinity)
            }
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

    init(defaults: UserDefaults = .standard) {
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
}
