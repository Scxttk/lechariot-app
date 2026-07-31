import Foundation

/// One list item paired with the offer a market has for it. Carries the whole
/// `OfferMatch` rather than just the offer, so callers that reuse this as the
/// row suggestion keep the true direct-vs-category kind instead of guessing.
struct RankedItemMatch: Equatable, Identifiable {
    let item: String
    let match: OfferMatch

    var offer: Offer { match.offer }
    var id: String { item }
}

/// One market's result for the current shopping list: which of the open items
/// it covers with offers, which it does not, and what the matched offers add
/// up to.
struct MarketListRank: Equatable, Identifiable {
    let chain: String
    /// Covered items with the cheapest offer each, in list order.
    let matchedItems: [RankedItemMatch]
    /// Items this market has nothing for, in list order.
    let missingItems: [String]
    /// Sum over the cheapest priced match per item; nil when no match has a price.
    let total: Double?

    var id: String { chain }
    var matchedCount: Int { matchedItems.count }
    var itemCount: Int { matchedItems.count + missingItems.count }
}

/// Ranking of the chosen branches for the shopping list. Coverage beats price:
/// a market matching 5/6 items always ranks above one matching 2/6, however
/// cheap the 2 are. Price only breaks coverage ties. The totals compare offer
/// prices only — items without a matched offer contribute nothing, so this is
/// "cheapest for the matched offers", not a full-basket price.
enum ShoppingListRanking {
    static func rank(
        items: [ShoppingItem],
        offers: [Offer],
        chains: [String],
        isRejected: (String, Offer) -> Bool = { _, _ in false }
    ) -> [MarketListRank] {
        guard !items.isEmpty else { return [] }
        let byChain = Dictionary(grouping: offers, by: \.market)
        return chains
            .map { chain -> MarketListRank in
                let chainOffers = byChain[chain] ?? []
                var matched: [RankedItemMatch] = []
                var missing: [String] = []
                var total: Double?
                for item in items {
                    // `query`, nicht `text`: Die Angabe am Artikel (L-5a) ist eine
                    // Notiz und darf die Abdeckungszahl nicht bewegen.
                    guard let match = ShoppingListMatcher.cheapestMatch(
                        for: item.query, in: chainOffers,
                        isRejected: { isRejected(item.query, $0) }
                    ) else {
                        missing.append(item.query)
                        continue
                    }
                    matched.append(RankedItemMatch(item: item.query, match: match))
                    if let price = match.offer.price {
                        total = (total ?? 0) + price
                    }
                }
                return MarketListRank(
                    chain: chain, matchedItems: matched,
                    missingItems: missing, total: total
                )
            }
            .sorted { lhs, rhs in
                if lhs.matchedCount != rhs.matchedCount {
                    return lhs.matchedCount > rhs.matchedCount
                }
                let l = lhs.total ?? .infinity, r = rhs.total ?? .infinity
                if l != r { return l < r }
                return lhs.chain < rhs.chain
            }
    }
}
