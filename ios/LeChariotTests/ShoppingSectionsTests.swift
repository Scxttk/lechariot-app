import XCTest
@testable import LeChariot

/// **Die Liste in Kategorie-Abschnitte, wie Bring! sie zeigt** (Video 03.08.).
final class ShoppingSectionsTests: XCTestCase {

    private func item(_ text: String) -> ShoppingItem {
        ShoppingItem(text: text)
    }

    private func offer(_ product: String, category: String) -> Offer {
        Offer(
            market: "netto-01219-1", product: product, price: 1.0, regularPrice: nil,
            unit: nil, category: category, emoji: nil,
            validFrom: Date(timeIntervalSince1970: 0),
            validUntil: Date(timeIntervalSince1970: 604_800),
            basePrice: nil, baseUnit: nil, nationwide: false
        )
    }

    private func matches(_ category: String) -> [OfferMatch] {
        [OfferMatch(offer: offer("x", category: category), kind: .direct)]
    }

    // MARK: Einsortieren

    func testAnItemLandsInTheCategoryOfItsBestMatch() {
        XCTAssertEqual(ShoppingSections.category(forMatches: matches("Molkerei & Eier")), "Molkerei & Eier")
    }

    /// **Ohne Treffer keine Kategorie** — und das ist keine Lücke, sondern der
    /// Restabschnitt.
    func testAnItemWithoutAMatchHasNoCategory() {
        XCTAssertNil(ShoppingSections.category(forMatches: []))
    }

    /// Eine leere Kategorie aus dem Import ist keine Kategorie. Sonst stünde
    /// über einem Abschnitt gar nichts.
    func testAnEmptyCategoryCountsAsNone() {
        XCTAssertNil(ShoppingSections.category(forMatches: matches("   ")))
    }

    // MARK: Die Abschnitte

    func testSectionsFollowTheFixedCategoryOrderNotTheTypingOrder() {
        let butter = item("Butter")     // Molkerei & Eier — steht in Categories.all an 2.
        let apfel = item("Äpfel")       // Obst & Gemüse — an 1.
        let sections = ShoppingSections.build(items: [butter, apfel]) {
            $0.text == "Butter" ? "Molkerei & Eier" : "Obst & Gemüse"
        }
        XCTAssertEqual(sections.map(\.category), ["Obst & Gemüse", "Molkerei & Eier"])
    }

    /// Innerhalb eines Abschnitts bleibt die Reihenfolge der Liste — wer seine
    /// Artikel in einer bestimmten Folge tippt, findet sie darin wieder.
    func testWithinASectionTheListOrderSurvives() {
        let items = [item("Butter"), item("Käse"), item("Quark")]
        let sections = ShoppingSections.build(items: items) { _ in "Molkerei & Eier" }
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].items.map(\.text), ["Butter", "Käse", "Quark"])
    }

    /// **Der Rest steht hinten und heißt nicht „Sonstiges".** „Sonstiges" ist
    /// eine der fünfzehn echten Kategorien; ein Artikel ohne Treffer ist etwas
    /// anderes als einer, den der Prospekt als Sonstiges führt.
    func testItemsWithoutACategoryGoLastAndKeepTheirOwnName() {
        let sections = ShoppingSections.build(items: [item("Wunderkerzen"), item("Butter")]) {
            $0.text == "Butter" ? "Molkerei & Eier" : nil
        }
        XCTAssertEqual(sections.map(\.category), ["Molkerei & Eier", ShoppingSections.restName])
        XCTAssertNotEqual(ShoppingSections.restName, "Sonstiges")
        XCTAssertTrue(sections.last?.isRest == true)
    }

    /// Der Import kennt Kategorien, die `Categories.all` nicht führt — im
    /// Mock-Vorrat etwa „Kaffee & Tee". Die dürfen nicht verschwinden.
    func testACategoryTheAppDoesNotKnowStillGetsASection() {
        let sections = ShoppingSections.build(items: [item("Kaffee"), item("Butter")]) {
            $0.text == "Kaffee" ? "Kaffee & Tee" : "Molkerei & Eier"
        }
        XCTAssertEqual(sections.map(\.category), ["Molkerei & Eier", "Kaffee & Tee"])
    }

    func testEveryItemEndsUpInExactlyOneSection() {
        let items = (1...9).map { item("Artikel \($0)") }
        let sections = ShoppingSections.build(items: items) { item in
            item.text.hasSuffix("1") ? nil : Categories.all[item.text.count % Categories.all.count]
        }
        XCTAssertEqual(sections.flatMap(\.items).count, items.count)
        XCTAssertEqual(Set(sections.flatMap(\.items).map(\.id)), Set(items.map(\.id)))
    }

    // MARK: Überschriften

    /// **Eine frische Liste ohne Filialen hat keinen einzigen Treffer.** Dann
    /// stünde über der ganzen Liste „Noch nicht einsortiert" — schlechter als
    /// keine Überschrift.
    func testAListThatIsAllRestGetsNoHeaders() {
        let sections = ShoppingSections.build(items: [item("Butter"), item("Käse")]) { _ in nil }
        XCTAssertEqual(sections.count, 1)
        XCTAssertFalse(ShoppingSections.needsHeaders(sections))
    }

    func testTheEmptyListNeedsNoHeadersEither() {
        XCTAssertFalse(ShoppingSections.needsHeaders([]))
    }

    /// Sobald etwas einsortiert ist, trennen die Überschriften wirklich etwas —
    /// auch wenn es nur ein Abschnitt ist: „Molkerei & Eier" sagt dann etwas.
    func testOneRealCategoryIsWorthAHeader() {
        let sections = ShoppingSections.build(items: [item("Butter")]) { _ in "Molkerei & Eier" }
        XCTAssertTrue(ShoppingSections.needsHeaders(sections))
    }

    func testTwoSectionsAlwaysNeedHeaders() {
        let sections = ShoppingSections.build(items: [item("Butter"), item("Wunderkerzen")]) {
            $0.text == "Butter" ? "Molkerei & Eier" : nil
        }
        XCTAssertTrue(ShoppingSections.needsHeaders(sections))
    }
}

/// **„Passende Artikel im Angebot" — die Zähler kommen aus der Plan-Rechnung.**
final class OfferHitSummaryTests: XCTestCase {

    private func rank(_ chain: String, matched: Int) -> MarketListRank {
        MarketListRank(
            chain: chain,
            matchedItems: (0..<matched).map { _ in
                RankedItemMatch(
                    item: "x",
                    match: OfferMatch(
                        offer: Offer(
                            market: "m", product: "p", price: 1, regularPrice: nil,
                            unit: nil, category: "Molkerei & Eier", emoji: nil,
                            validFrom: Date(timeIntervalSince1970: 0),
                            validUntil: Date(timeIntervalSince1970: 604_800),
                            basePrice: nil, baseUnit: nil, nationwide: false
                        ),
                        kind: .direct
                    ),
                    isPinned: false
                )
            },
            missingItems: [],
            total: nil
        )
    }

    /// **Eine Kette ohne Treffer bekommt keinen Chip.** „Netto 15 · ALDI 0"
    /// liest sich wie ein Angebot und ist keines — die Zeile heißt „passende
    /// Artikel im Angebot".
    func testAChainWithoutHitsGetsNoChip() {
        let summary = OfferHitSummary(ranks: [rank("Netto", matched: 15), rank("Aldi", matched: 0)])
        XCTAssertEqual(summary.chains.map(\.chain), ["Netto"])
    }

    /// Die meisten Treffer zuerst — genau die Reihenfolge aus dem Video
    /// („Netto 15 · Penny 3").
    func testTheChainWithTheMostHitsComesFirst() {
        let summary = OfferHitSummary(ranks: [rank("Penny", matched: 3), rank("Netto", matched: 15)])
        XCTAssertEqual(summary.chains.map(\.chain), ["Netto", "Penny"])
        XCTAssertEqual(summary.chains.map(\.count), [15, 3])
        XCTAssertEqual(summary.total, 18)
    }

    /// Ohne Treffer gibt es die Zeile gar nicht — statt einer Zeile, die „0"
    /// sagt.
    func testNoHitsMeansNoRow() {
        XCTAssertTrue(OfferHitSummary(ranks: []).isEmpty)
        XCTAssertTrue(OfferHitSummary(ranks: [rank("Netto", matched: 0)]).isEmpty)
    }
}
