import XCTest
@testable import Smartshop

final class OfferQueryTests: XCTestCase {
    private func offer(
        product: String = "Testprodukt",
        market: String = "Lidl",
        category: String = "Sonstiges",
        price: Double? = 1.0,
        regular: Double? = nil
    ) -> Offer {
        Offer(
            market: market, product: product, price: price, regularPrice: regular,
            unit: nil, category: category, emoji: nil,
            validFrom: MockFixtures.day.date(from: "2026-07-13")!,
            validUntil: MockFixtures.day.date(from: "2026-07-19")!,
            basePrice: nil, baseUnit: nil, region: "01219"
        )
    }

    // MARK: Discount

    func testDiscountPercentRoundsCorrectly() {
        XCTAssertEqual(offer(price: 0.99, regular: 1.29).discountPercent, 23)
        XCTAssertEqual(offer(price: 1.0, regular: 2.0).discountPercent, 50)
    }

    func testDiscountPercentNilWithoutRegularOrWhenNotCheaper() {
        XCTAssertNil(offer(price: 1.0, regular: nil).discountPercent)
        XCTAssertNil(offer(price: nil, regular: 2.0).discountPercent)
        XCTAssertNil(offer(price: 2.0, regular: 2.0).discountPercent)
        XCTAssertNil(offer(price: 3.0, regular: 2.0).discountPercent)
    }

    // MARK: Search & filter

    func testSearchIsCaseInsensitiveSubstring() {
        let offers = [offer(product: "Bio Vollmilch"), offer(product: "Orangen")]
        let hits = OfferQuery.apply(offers, search: "vollMILCH")
        XCTAssertEqual(hits.map(\.product), ["Bio Vollmilch"])
    }

    func testCategoryAndMarketFilterCombine() {
        let offers = [
            offer(product: "A", market: "Lidl", category: "Getränke"),
            offer(product: "B", market: "Aldi", category: "Getränke"),
            offer(product: "C", market: "Lidl", category: "Backwaren"),
        ]
        let hits = OfferQuery.apply(offers, category: "Getränke", market: "Lidl")
        XCTAssertEqual(hits.map(\.product), ["A"])
    }

    // MARK: Sort

    func testDealsSortPutsHighestDiscountFirstAndNilLast() {
        let offers = [
            offer(product: "Klein", price: 1.8, regular: 2.0),   // 10 %
            offer(product: "Ohne", price: 1.0, regular: nil),    // nil
            offer(product: "Groß", price: 1.0, regular: 2.0),    // 50 %
        ]
        let sorted = OfferQuery.apply(offers, sort: .deals)
        XCTAssertEqual(sorted.map(\.product), ["Groß", "Klein", "Ohne"])
    }

    // MARK: Grouping

    func testGroupingByMarketIsAlphabetical() {
        let offers = [offer(market: "Lidl"), offer(market: "Aldi"), offer(market: "Lidl")]
        let sections = OfferQuery.grouped(offers, by: .market)
        XCTAssertEqual(sections.map(\.key), ["Aldi", "Lidl"])
        XCTAssertEqual(sections[1].offers.count, 2)
    }

    func testGroupingByCategoryFollowsFixedOrder() {
        let offers = [
            offer(category: "Sonstiges"),
            offer(category: "Obst & Gemüse"),
            offer(category: "Getränke"),
        ]
        let sections = OfferQuery.grouped(offers, by: .category)
        XCTAssertEqual(sections.map(\.key), ["Obst & Gemüse", "Getränke", "Sonstiges"])
    }
}
