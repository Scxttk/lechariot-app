import Foundation

/// One entry of the local shopping list. Free text — matching against offers
/// happens at display time, never persisted.
struct ShoppingItem: Codable, Equatable, Identifiable {
    let id: UUID
    var text: String
    var isChecked: Bool
    let addedAt: Date

    init(id: UUID = UUID(), text: String, isChecked: Bool = false, addedAt: Date = .now) {
        self.id = id
        self.text = text
        self.isChecked = isChecked
        self.addedAt = addedAt
    }
}
