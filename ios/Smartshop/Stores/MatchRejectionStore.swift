import Foundation
import Observation

/// Persisted "this suggestion is wrong" decisions from the match-detail sheet.
///
/// Keyed by normalized item text + `Offer.id`. Because `Offer.id` contains
/// `valid_from`, rejections expire naturally with the offer week — next week's
/// offers get a fresh chance. Persistence: UserDefaults, same rationale as
/// ShoppingListStore (a small string set, no queries).
@MainActor
@Observable
final class MatchRejectionStore {
    private(set) var rejected: Set<String>

    private let defaults: UserDefaults
    private static let key = "matching.rejections"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.rejected = Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    private func key(itemText: String, offer: Offer) -> String {
        "\(itemText.lowercased().trimmingCharacters(in: .whitespaces))|\(offer.id)"
    }

    func isRejected(itemText: String, offer: Offer) -> Bool {
        rejected.contains(key(itemText: itemText, offer: offer))
    }

    func reject(itemText: String, offer: Offer) {
        rejected.insert(key(itemText: itemText, offer: offer))
        persist()
    }

    func unreject(itemText: String, offer: Offer) {
        rejected.remove(key(itemText: itemText, offer: offer))
        persist()
    }

    private func persist() {
        defaults.set(Array(rejected).sorted(), forKey: Self.key)
    }
}
