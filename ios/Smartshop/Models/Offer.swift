import Foundation

/// Row of the Supabase `offers` table. See docs/CONTRACTS.md.
struct Offer: Codable, Equatable, Identifiable {
    /// Branch the offer belongs to (backend migration v13). Optional only so
    /// rows pushed before that migration still decode — every live row has it,
    /// and the column is NOT NULL.
    ///
    /// This is what makes two stores of the same chain in the same postcode
    /// tell apart: measured on 2026-07-25, the three REWE branches in 01067
    /// published three different flyers in the same week, and a Coca-Cola cost
    /// €0.75 at two of them and €1.49 at the third.
    var marketId: String? = nil
    /// Chain name — what the offer sections are grouped and labelled by.
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
    /// Does this offer apply country-wide instead of at one branch?
    ///
    /// ALDI Nord and ALDI SÜD publish one catalogue for all of Germany; their
    /// offers have no branch of their own. Until migration v16 the same fact
    /// was carried by an absent `region` — the column said "postcode" and
    /// answered "nationwide", so it was renamed to what it means. Optional
    /// only so rows written before v16 still decode; the column is NOT NULL.
    var nationwide: Bool? = nil
    /// Public Supabase-Storage URL of the product image; nil = emoji only.
    /// Default keeps the memberwise initializer source-compatible.
    var imageUrl: String? = nil
    /// Begriffs-Tags from the backend import (`["käse"]`, `["nonfood"]`,
    /// `[]` = untagged). Optional so rows pushed before migration_v10 decode.
    var matchKey: [String]? = nil

    /// `marketId` is part of the identity: without it the same product at two
    /// branches of one chain in one region collapses to a single row id, and
    /// SwiftUI lists show one of them or neither.
    var id: String {
        "\(marketId ?? market)|\(product)|\(validFrom.timeIntervalSince1970)"
    }

    /// Valid at every branch of its chain rather than at one.
    var isNationwide: Bool { nationwide == true }

    /// Tags for category-fallback matching; empty when untagged.
    var matchKeys: [String] { matchKey ?? [] }

    enum CodingKeys: String, CodingKey {
        case market, product, price, unit, category, emoji, nationwide
        case marketId = "market_id"
        case regularPrice = "regular_price"
        case validFrom = "valid_from"
        case validUntil = "valid_until"
        case basePrice = "base_price"
        case baseUnit = "base_unit"
        case imageUrl = "image_url"
        case matchKey = "match_key"
    }
}
