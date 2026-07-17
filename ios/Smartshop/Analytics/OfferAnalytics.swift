import Foundation

/// Aggregates for the Analyse tab. One measure per chart, computed from the
/// current week's offers.
struct MarketStat: Equatable, Identifiable {
    let chain: String
    let offerCount: Int
    /// Mean discount in percent over offers with a computable discount, nil if none.
    let avgDiscount: Int?
    let dealCount: Int

    var id: String { chain }
}

struct CategoryStat: Equatable, Identifiable {
    let category: String
    let emoji: String
    let count: Int

    var id: String { category }
}

struct OverallStats: Equatable {
    let offerCount: Int
    let marketCount: Int
    let avgDiscount: Int?
    let maxDiscount: Int?
}

/// Pure computation over loaded offers, no side effects (pattern: OfferQuery).
enum OfferAnalytics {
    static func overall(_ offers: [Offer]) -> OverallStats {
        let discounts = offers.compactMap(\.discountPercent)
        return OverallStats(
            offerCount: offers.count,
            marketCount: Set(offers.map(\.market)).count,
            avgDiscount: average(discounts),
            maxDiscount: discounts.max()
        )
    }

    /// Per-chain stats, sorted by offer count descending.
    static func marketStats(_ offers: [Offer]) -> [MarketStat] {
        Dictionary(grouping: offers, by: \.market)
            .map { chain, offers in
                let discounts = offers.compactMap(\.discountPercent)
                return MarketStat(
                    chain: chain,
                    offerCount: offers.count,
                    avgDiscount: average(discounts),
                    dealCount: discounts.count
                )
            }
            .sorted { ($0.offerCount, $1.chain) > ($1.offerCount, $0.chain) }
    }

    /// The biggest discounts of the week, deepest first.
    static func topDeals(_ offers: [Offer], limit: Int = 10) -> [Offer] {
        offers
            .filter { $0.discountPercent != nil }
            .sorted { ($0.discountPercent ?? 0, $1.product) > ($1.discountPercent ?? 0, $0.product) }
            .prefix(limit)
            .map { $0 }
    }

    /// Offer count per category in the fixed `Categories.all` order, unknown
    /// categories appended; empty categories are omitted.
    static func categoryBreakdown(_ offers: [Offer]) -> [CategoryStat] {
        let grouped = Dictionary(grouping: offers, by: \.category)
        var stats = Categories.all.compactMap { name -> CategoryStat? in
            guard let offers = grouped[name] else { return nil }
            return CategoryStat(
                category: name,
                emoji: offers.compactMap(\.emoji).first ?? "🛒",
                count: offers.count
            )
        }
        let known = Set(Categories.all)
        for key in grouped.keys.sorted() where !known.contains(key) {
            stats.append(CategoryStat(
                category: key,
                emoji: grouped[key]?.compactMap(\.emoji).first ?? "🛒",
                count: grouped[key]?.count ?? 0
            ))
        }
        return stats
    }

    private static func average(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}
