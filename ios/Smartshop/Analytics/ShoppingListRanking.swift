import Foundation

/// One market's result for the current shopping list: how many open items it
/// covers with offers and what the matched offers add up to.
struct MarketListRank: Equatable, Identifiable {
    let chain: String
    let matchedCount: Int
    let itemCount: Int
    /// Sum over the cheapest priced match per item; nil when no match has a price.
    let total: Double?

    var id: String { chain }
}

/// Ranking of the Wunschmärkte for the shopping list. Coverage beats price:
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
                var matched = 0
                var total: Double?
                for item in items {
                    guard let match = ShoppingListMatcher.cheapestMatch(
                        for: item.text, in: chainOffers,
                        isRejected: { isRejected(item.text, $0) }
                    ) else { continue }
                    matched += 1
                    if let price = match.offer.price {
                        total = (total ?? 0) + price
                    }
                }
                return MarketListRank(
                    chain: chain, matchedCount: matched,
                    itemCount: items.count, total: total
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
