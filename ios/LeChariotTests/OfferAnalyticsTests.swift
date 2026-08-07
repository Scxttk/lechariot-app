import XCTest
@testable import LeChariot

final class OfferAnalyticsTests: XCTestCase {
    private func offer(
        product: String = "Testprodukt",
        market: String = "Lidl",
        // **Ein Lebensmittel als Vorgabe, seit dem 06.08.** Vorher stand hier
        // „Sonstiges" — der Topf, in dem der Kindersessel liegt und den
        // `topDeals` jetzt auslässt.
        category: String = "Molkerei & Eier",
        emoji: String? = nil,
        price: Double? = 1.0,
        regular: Double? = nil
    ) -> Offer {
        Offer(
            market: market, product: product, price: price, regularPrice: regular,
            unit: nil, category: category, emoji: emoji,
            validFrom: MockFixtures.day.date(from: "2026-07-13")!,
            validUntil: MockFixtures.day.date(from: "2026-07-19")!,
            basePrice: nil, baseUnit: nil, nationwide: false
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

    // MARK: Die Aktionsware in der Mitte des Ladens (06.08.)

    /// **Der Bildschirm eröffnete mit Kindersessel, Auflaufform und
    /// Werkstattfeilen.** An 849 verschiedenen Angeboten mit Streichpreis
    /// nachgezählt: Die ersten dreißig Plätze nach Rabatt trugen `Sonstiges`
    /// (14), `Kinder` (9) und `Haushalt` (7) — und kein Lebensmittel. Nach
    /// Prozent gewinnt ein Artikel, der von 24,99 € auf 2,99 € fällt, immer
    /// gegen einen Joghurt.
    func testTheMiddleAisleDoesNotOpenTheOffers() {
        let offers = [
            offer(product: "Kindersessel", category: "Sonstiges", price: 2.99, regular: 24.99),
            offer(product: "Auflaufform", category: "Haushalt", price: 3.99, regular: 19.99),
            offer(product: "Spielküche", category: "Kinder", price: 9.99, regular: 29.99),
            offer(product: "Joghurt", category: "Molkerei & Eier", price: 0.49, regular: 1.29),
        ]
        XCTAssertEqual(OfferAnalytics.topDeals(offers).map(\.product), ["Joghurt"])
    }

    /// **Drogerie und Tierbedarf bleiben drin, und das ist gemessen, nicht
    /// gefühlt:** An denselben Daten trugen sie oben Zahnpasta, Shampoo,
    /// Pflaster und Katzenfutter — Dinge, die auf einer Einkaufsliste stehen.
    func testToothpasteAndCatFoodStillCount() {
        let offers = [
            offer(product: "Zahnpasta", category: "Drogerie", price: 1.0, regular: 2.0),
            offer(product: "Katzenfutter", category: "Tierbedarf", price: 1.8, regular: 2.0),
        ]
        XCTAssertEqual(
            OfferAnalytics.topDeals(offers).map(\.product),
            ["Zahnpasta", "Katzenfutter"]
        )
    }

    /// Der Import schreibt die Kategorie als Freitext; ein Leerzeichen davor
    /// darf den Kindersessel nicht wieder nach oben lassen.
    func testTheFilterSurvivesStrayWhitespace() {
        let offers = [offer(product: "Kindersessel", category: " Sonstiges ",
                            price: 2.99, regular: 24.99)]
        XCTAssertTrue(OfferAnalytics.topDeals(offers).isEmpty)
    }
}
