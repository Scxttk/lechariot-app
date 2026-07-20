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

    func testTopDealsWithoutDiscountsIsEmpty() {
        XCTAssertTrue(OfferAnalytics.topDeals([offer(), offer()]).isEmpty)
    }
}
