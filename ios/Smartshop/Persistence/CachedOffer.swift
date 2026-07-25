import Foundation
import SwiftData

/// SwiftData mirror of `Offer` plus the timestamp of the refresh that stored it.
@Model
final class CachedOffer {
    /// Default keeps the lightweight SwiftData migration of stores written
    /// before the branch key working — those rows simply have no branch.
    var marketId: String?
    var market: String
    var product: String
    var price: Double?
    var regularPrice: Double?
    var unit: String?
    var category: String
    var emoji: String?
    var validFrom: Date
    var validUntil: Date
    var basePrice: Double?
    var baseUnit: String?
    /// nil = nationwide (see `Offer.region`). Optional also keeps the
    /// lightweight SwiftData migration of stores written before Phase 12
    /// working — those rows all have a region.
    var region: String?
    var imageUrl: String?
    /// Default value keeps lightweight migration of pre-match_key stores working.
    var matchKey: [String] = []
    var fetchedAt: Date

    init(offer: Offer, fetchedAt: Date) {
        self.marketId = offer.marketId
        self.market = offer.market
        self.product = offer.product
        self.price = offer.price
        self.regularPrice = offer.regularPrice
        self.unit = offer.unit
        self.category = offer.category
        self.emoji = offer.emoji
        self.validFrom = offer.validFrom
        self.validUntil = offer.validUntil
        self.basePrice = offer.basePrice
        self.baseUnit = offer.baseUnit
        self.region = offer.region
        self.imageUrl = offer.imageUrl
        self.matchKey = offer.matchKeys
        self.fetchedAt = fetchedAt
    }

    var offer: Offer {
        Offer(
            marketId: marketId,
            market: market,
            product: product,
            price: price,
            regularPrice: regularPrice,
            unit: unit,
            category: category,
            emoji: emoji,
            validFrom: validFrom,
            validUntil: validUntil,
            basePrice: basePrice,
            baseUnit: baseUnit,
            region: region,
            imageUrl: imageUrl,
            matchKey: matchKey
        )
    }
}
