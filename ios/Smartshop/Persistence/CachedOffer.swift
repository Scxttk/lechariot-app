import Foundation
import SwiftData

/// SwiftData mirror of `Offer` plus the timestamp of the refresh that stored it.
@Model
final class CachedOffer {
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
    var region: String
    var fetchedAt: Date

    init(offer: Offer, fetchedAt: Date) {
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
        self.fetchedAt = fetchedAt
    }

    var offer: Offer {
        Offer(
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
            region: region
        )
    }
}
