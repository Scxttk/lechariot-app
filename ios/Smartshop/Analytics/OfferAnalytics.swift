import Foundation

/// Pure computation over loaded offers, no side effects (pattern: OfferQuery).
///
/// This used to back an Analyse tab full of bar charts (offers per market,
/// average discount, category breakdown). Those answered questions about the
/// dataset, not about the user's week, so the tab and its aggregates are gone —
/// `git log` has them if a future dashboard needs them back. What survived is
/// the one aggregate a shopper actually uses.
enum OfferAnalytics {
    /// The biggest discounts of the week, deepest first.
    static func topDeals(_ offers: [Offer], limit: Int = 10) -> [Offer] {
        offers
            .filter { $0.discountPercent != nil }
            .sorted { ($0.discountPercent ?? 0, $1.product) > ($1.discountPercent ?? 0, $0.product) }
            .prefix(limit)
            .map { $0 }
    }
}
