import Foundation

/// Row of the Supabase `offers` table. See docs/CONTRACTS.md.
struct Offer: Codable, Equatable, Identifiable {
    let market: String
    let product: String
    let price: Double?
    let regularPrice: Double?
    let unit: String?
    let category: String
    let emoji: String?
    let validFrom: Date
    let validUntil: Date
    let basePrice: Double?
    let baseUnit: String?
    let region: String
    /// Public Supabase-Storage URL of the product image; nil = emoji only.
    /// Default keeps the memberwise initializer source-compatible.
    var imageUrl: String? = nil
    /// Begriffs-Tags from the backend import (`["käse"]`, `["nonfood"]`,
    /// `[]` = untagged). Optional so rows pushed before migration_v10 decode.
    var matchKey: [String]? = nil

    var id: String { "\(market)|\(product)|\(region)|\(validFrom.timeIntervalSince1970)" }

    /// Tags for category-fallback matching; empty when untagged.
    var matchKeys: [String] { matchKey ?? [] }

    enum CodingKeys: String, CodingKey {
        case market, product, price, unit, category, emoji, region
        case regularPrice = "regular_price"
        case validFrom = "valid_from"
        case validUntil = "valid_until"
        case basePrice = "base_price"
        case baseUnit = "base_unit"
        case imageUrl = "image_url"
        case matchKey = "match_key"
    }
}
