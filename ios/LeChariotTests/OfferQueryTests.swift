import XCTest
@testable import LeChariot

final class OfferQueryTests: XCTestCase {
    private func offer(
        product: String = "Testprodukt",
        market: String = "Lidl",
        category: String = "Sonstiges",
        price: Double? = 1.0,
        regular: Double? = nil,
        from: String = "2026-07-13",
        until: String = "2026-07-19",
        region: String = "01219",
        unit: String? = nil
    ) -> Offer {
        Offer(
            market: market, product: product, price: price, regularPrice: regular,
            unit: unit, category: category, emoji: nil,
            validFrom: MockFixtures.day.date(from: from)!,
            validUntil: MockFixtures.day.date(from: until)!,
            basePrice: nil, baseUnit: nil, nationwide: false
        )
    }

    /// Fixed "today" for every dedupe test — `.now` would rot the suite.
    private let today = MockFixtures.day.date(from: "2026-07-15")!

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

    /// **Suche innerhalb einer Kette.** Das ist die Zusage der Chip-Leiste
    /// über der Angebotsliste: Der Chip schränkt nicht nur die Abschnitte
    /// ein, sondern auch, was die Suche darin findet. Wäre die Suche
    /// unabhängig vom Markt, führte der Chip in die Irre — er sähe aktiv aus
    /// und stünde über Treffern aus anderen Märkten.
    func testSearchIsRestrictedToTheChosenMarket() {
        let offers = [
            offer(product: "Bio Vollmilch", market: "Lidl"),
            offer(product: "Frische Vollmilch", market: "Aldi"),
        ]
        XCTAssertEqual(
            OfferQuery.apply(offers, search: "vollmilch", market: "Lidl").map(\.product),
            ["Bio Vollmilch"]
        )
        // Und die Gegenprobe: ohne Chip findet dieselbe Suche beide.
        XCTAssertEqual(OfferQuery.apply(offers, search: "vollmilch").count, 2)
    }

    /// Eine Kette, in der es das Gesuchte nicht gibt, liefert leer — und
    /// **nicht** ersatzweise die Treffer der anderen. Der Bildschirm erklärt
    /// diesen Fall eigens (`noSearchHitInOneMarket`); täte die Abfrage hier
    /// heimlich etwas anderes, erklärte er etwas, das nie einträte.
    func testASearchWithNoHitInThatMarketStaysEmpty() {
        let offers = [
            offer(product: "Bio Vollmilch", market: "Lidl"),
            offer(product: "Spanische Orangen", market: "Aldi"),
        ]
        XCTAssertTrue(OfferQuery.apply(offers, search: "vollmilch", market: "Aldi").isEmpty)
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

    // MARK: Dedupe

    /// Kaufland publishes the same product both in the week's flyer and in a
    /// one-day "Knüller" section. Both rows are real, both are the same offer.
    func testWeekRowAndOneDayRowAtTheSamePriceCollapse() {
        let week = offer(price: 1.99, from: "2026-07-13", until: "2026-07-19")
        let knueller = offer(price: 1.99, from: "2026-07-15", until: "2026-07-15")

        let result = OfferQuery.deduplicated([week, knueller], now: today)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.validUntil, week.validUntil, "the week row is the truthful one")
    }

    /// Same market, same product, different price: next week's row, or a
    /// different pack size the flyer titles identically. Both must survive.
    func testDifferentPricesForTheSameProductBothSurvive() {
        let offers = [offer(price: 1.99), offer(price: 2.49)]

        XCTAssertEqual(OfferQuery.deduplicated(offers, now: today).count, 2)
    }

    /// Dieselbe Zeile zweimal — etwa die Wochenzeile und die Ein-Tages-Zeile
    /// derselben Kette. Der Dedupe-Schlüssel fasst sie zusammen.
    func testTheSameOfferTwiceCollapses() {
        let offers = [offer(), offer()]

        XCTAssertEqual(OfferQuery.deduplicated(offers, now: today).count, 1)
    }

    func testACurrentlyValidRowBeatsAFutureOne() {
        let next = offer(from: "2026-07-20", until: "2026-07-26")
        let current = offer(from: "2026-07-13", until: "2026-07-19")

        let result = OfferQuery.deduplicated([next, current], now: today)

        XCTAssertEqual(result.map(\.validFrom), [current.validFrom])
    }

    /// An offer that ends today is still valid today — comparing against the
    /// wall clock instead of the start of the day would drop it.
    func testARowEndingTodayStillCountsAsCurrent() {
        let endingToday = offer(from: "2026-07-13", until: "2026-07-15")
        let future = offer(from: "2026-07-20", until: "2026-08-20")
        let noon = today.addingTimeInterval(12 * 3600)

        let result = OfferQuery.deduplicated([future, endingToday], now: noon)

        XCTAssertEqual(result.map(\.validUntil), [endingToday.validUntil])
    }

    func testAmongCurrentRowsTheWiderWindowWins() {
        let oneDay = offer(from: "2026-07-15", until: "2026-07-15")
        let week = offer(from: "2026-07-13", until: "2026-07-19")

        let result = OfferQuery.deduplicated([oneDay, week], now: today)

        XCTAssertEqual(result.map(\.validFrom), [week.validFrom])
    }

    /// The unit is not part of the key: the one-day row often drops it, and a
    /// duplicate that differs only there is still a duplicate.
    func testDifferingUnitsDoNotKeepADuplicateAlive() {
        let offers = [offer(unit: "je 1 l"), offer(unit: nil)]

        XCTAssertEqual(OfferQuery.deduplicated(offers, now: today).count, 1)
    }

    func testOffersWithoutAPriceStillCollapseWithTheirTwin() {
        let offers = [offer(price: nil), offer(price: nil)]

        XCTAssertEqual(OfferQuery.deduplicated(offers, now: today).count, 1)
    }

    func testDedupeIsOrderIndependentAndIdempotent() {
        let offers = [
            offer(product: "A", price: 1.99, from: "2026-07-15", until: "2026-07-15"),
            offer(product: "A", price: 1.99),
            offer(product: "B", price: 2.49),
            offer(product: "B", price: 3.49),
        ]

        let forward = OfferQuery.deduplicated(offers, now: today)
        let backward = OfferQuery.deduplicated(offers.reversed(), now: today)

        XCTAssertEqual(Set(forward.map(\.id)), Set(backward.map(\.id)))
        XCTAssertEqual(
            OfferQuery.deduplicated(forward, now: today).map(\.id),
            forward.map(\.id),
            "running it twice must not change anything"
        )
    }

    func testDedupePreservesTheInputOrderOfSurvivors() {
        let offers = [offer(product: "Zitrone"), offer(product: "Apfel"), offer(product: "Zitrone")]

        let result = OfferQuery.deduplicated(offers, now: today)

        XCTAssertEqual(result.map(\.product), ["Zitrone", "Apfel"])
    }
}
