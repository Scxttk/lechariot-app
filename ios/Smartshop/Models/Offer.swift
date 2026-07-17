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

    var id: String { "\(market)|\(product)|\(region)|\(validFrom.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case market, product, price, unit, category, emoji, region
        case regularPrice = "regular_price"
        case validFrom = "valid_from"
        case validUntil = "valid_until"
        case basePrice = "base_price"
        case baseUnit = "base_unit"
    }
}
