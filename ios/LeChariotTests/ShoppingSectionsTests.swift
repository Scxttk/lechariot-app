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

    // MARK: Die Kategorien aus dem Plan

    /// **Der Preis, den der erste Entwurf gekostet hat, steht als Test da.**
    /// Die Kategorie kommt aus dem Plan-Lauf, nicht aus einem zweiten Durchgang
    /// über alle Angebote — gemessen war das die doppelte Scroll-Ausrollzeit.
    func testCategoriesComeFromThePlanThatIsComputedAnyway() {
        let ranks = [
            rank("Netto", items: [("Butter", "Molkerei & Eier"), ("Äpfel", "Obst & Gemüse")]),
        ]
        let byQuery = ShoppingSections.categories(from: ranks)
        XCTAssertEqual(byQuery["Butter"], "Molkerei & Eier")
        XCTAssertEqual(byQuery["Äpfel"], "Obst & Gemüse")
    }

    /// Die erste Kette gewinnt: `ranks` ist nach Abdeckung sortiert, und der
    /// Artikel steht in der Liste unter der Kategorie, die die empfohlene
    /// Filiale ihm gibt.
    func testTheFirstRankWins() {
        let ranks = [
            rank("Netto", items: [("Butter", "Molkerei & Eier")]),
            rank("Lidl", items: [("Butter", "Sonstiges")]),
        ]
        XCTAssertEqual(ShoppingSections.categories(from: ranks)["Butter"], "Molkerei & Eier")
    }

    /// Eine leere Kategorie aus dem Import zählt nicht — sonst stünde über
    /// einem Abschnitt gar nichts.
    func testAnEmptyCategoryInThePlanIsIgnored() {
        let ranks = [rank("Netto", items: [("Butter", "  ")])]
        XCTAssertNil(ShoppingSections.categories(from: ranks)["Butter"])
    }

    private func rank(_ chain: String, items: [(String, String)]) -> MarketListRank {
        MarketListRank(
            chain: chain,
            matchedItems: items.map { name, category in
                RankedItemMatch(
                    item: name,
                    match: OfferMatch(offer: offer(name, category: category), kind: .direct),
                    isPinned: false
                )
            },
            missingItems: [],
            total: nil
        )
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

    /// **Eine Überschrift über einer einzigen Zeile sortiert nichts.**
    ///
    /// Bis zum 06.08. bekam ein Abschnitt seine Überschrift, sobald überhaupt
    /// etwas einsortiert war — auch bei genau einem Artikel. Am Gerät
    /// gemessen: fünf Artikel, drei Abschnitte, jede Überschrift über einer
    /// Zeile und je rund 50 pt. Zusammen mehr Platz als die Artikel selbst.
    func testASingleItemUnderAHeadingIsNotWorthTheHeading() {
        let sections = ShoppingSections.build(items: [item("Butter")]) { _ in "Molkerei & Eier" }
        XCTAssertFalse(ShoppingSections.needsHeaders(sections))
    }

    /// Zwei Abschnitte mit je einem Artikel bleiben ohne — im Schnitt kommt
    /// **ein** Artikel auf einen Abschnitt, und der steht schon da.
    func testTwoSectionsOfOneItemEachStayHeaderless() {
        let sections = ShoppingSections.build(items: [item("Butter"), item("Wunderkerzen")]) {
            $0.text == "Butter" ? "Molkerei & Eier" : nil
        }
        XCTAssertFalse(ShoppingSections.needsHeaders(sections))
    }

    /// Ab zwei Artikeln je Abschnitt im Schnitt trennen die Überschriften
    /// wirklich etwas — dann stehen sie.
    func testHeadingsAppearOnceTheSectionsActuallyHold() {
        let molkerei = ["Butter", "Käse", "Quark"].map(item)
        let rest = ["Wunderkerzen", "Batterien"].map(item)
        let sections = ShoppingSections.build(items: molkerei + rest) {
            molkerei.map(\.text).contains($0.text) ? "Molkerei & Eier" : nil
        }
        XCTAssertEqual(sections.count, 2)
        XCTAssertTrue(ShoppingSections.needsHeaders(sections))
    }
}
