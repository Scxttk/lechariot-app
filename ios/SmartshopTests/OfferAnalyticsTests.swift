import XCTest
@testable import Smartshop

final class OfferAnalyticsTests: XCTestCase {
    private func offer(
        product: String = "Testprodukt",
        market: String = "Lidl",
        category: String = "Sonstiges",
        emoji: String? = nil,
        price: Double? = 1.0,
        regular: Double? = nil
    ) -> Offer {
        Offer(
            market: market, product: product, price: price, regularPrice: regular,
            unit: nil, category: category, emoji: emoji,
            validFrom: MockFixtures.day.date(from: "2026-07-13")!,
            validUntil: MockFixtures.day.date(from: "2026-07-19")!,
            basePrice: nil, baseUnit: nil, region: "01219"
        )
    }

    // MARK: Overall

    func testOverallStats() {
        let offers = [
            offer(market: "Lidl", price: 1.0, regular: 2.0),   // 50 %
            offer(market: "Lidl", price: 0.9, regular: 1.0),   // 10 %
            offer(market: "Aldi", price: 1.0),                 // no discount
        ]
        let stats = OfferAnalytics.overall(offers)
        XCTAssertEqual(stats.offerCount, 3)
        XCTAssertEqual(stats.marketCount, 2)
        XCTAssertEqual(stats.avgDiscount, 30)
        XCTAssertEqual(stats.maxDiscount, 50)
    }

    func testOverallStatsEmptyDiscountsAreNil() {
        let stats = OfferAnalytics.overall([offer()])
        XCTAssertNil(stats.avgDiscount)
        XCTAssertNil(stats.maxDiscount)
    }

    // MARK: Market stats

    func testMarketStatsSortedByCountDescending() {
        let offers = [
            offer(market: "Aldi"),
            offer(market: "Lidl", price: 1.0, regular: 2.0),
            offer(market: "Lidl"),
        ]
        let stats = OfferAnalytics.marketStats(offers)
        XCTAssertEqual(stats.map(\.chain), ["Lidl", "Aldi"])
        XCTAssertEqual(stats[0].offerCount, 2)
        XCTAssertEqual(stats[0].avgDiscount, 50)
        XCTAssertEqual(stats[0].dealCount, 1)
        XCTAssertNil(stats[1].avgDiscount)
    }

    // MARK: Top deals

    func testTopDealsSortedAndLimited() {
        let offers = [
            offer(product: "Klein", price: 1.8, regular: 2.0),  // 10 %
            offer(product: "Ohne", price: 1.0),                 // excluded
            offer(product: "Groß", price: 1.0, regular: 2.0),   // 50 %
            offer(product: "Mittel", price: 1.5, regular: 2.0), // 25 %
        ]
        XCTAssertEqual(
            OfferAnalytics.topDeals(offers).map(\.product),
            ["Groß", "Mittel", "Klein"]
        )
        XCTAssertEqual(OfferAnalytics.topDeals(offers, limit: 2).count, 2)
    }

    // MARK: Categories

    func testCategoryBreakdownFollowsFixedOrderAndPicksEmoji() {
        let offers = [
            offer(category: "Sonstiges"),
            offer(category: "Obst & Gemüse", emoji: "🍊"),
            offer(category: "Obst & Gemüse"),
            offer(category: "Unbekannt"),
        ]
        let stats = OfferAnalytics.categoryBreakdown(offers)
        XCTAssertEqual(stats.map(\.category), ["Obst & Gemüse", "Sonstiges", "Unbekannt"])
        XCTAssertEqual(stats[0].count, 2)
        XCTAssertEqual(stats[0].emoji, "🍊")
        XCTAssertEqual(stats[1].emoji, "🛒")
    }
}
