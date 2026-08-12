import XCTest
@testable import LeChariot

/// **Was der Merker zusichern muss: dieselbe Antwort, weniger Rechnen.**
///
/// Ein Merker, der eine Änderung verschläft, zeigt einen Plan von vorhin — und
/// das wäre schlimmer als die Rechenzeit, die er spart. Jede Eingabe von
/// `ShoppingListRanking.rank` bekommt deshalb hier ihren eigenen Fall.
@MainActor
final class ShoppingListPlanTests: XCTestCase {
    private func offers() -> [Offer] {
        let base = MockFixtures.offers[0]
        return ["Lidl", "Aldi"].map { markt in
            var made = Offer(
                market: markt, product: "Vollmilch 1,5 %", price: markt == "Lidl" ? 0.99 : 1.19,
                regularPrice: nil, unit: nil, category: base.category, emoji: nil,
                validFrom: base.validFrom, validUntil: base.validUntil,
                basePrice: nil, baseUnit: nil, nationwide: false
            )
            made.matchKey = ["milch"]
            return made
        }
    }

    private func ranks(
        _ plan: ShoppingListPlan,
        items: [ShoppingItem],
        offers: [Offer],
        generation: Int = 1,
        chains: [String] = ["Lidl", "Aldi"],
        rejections: Set<String> = []
    ) -> [MarketListRank] {
        plan.ranks(items: items, offers: offers, offerGeneration: generation,
                   chains: chains, rejections: rejections) { _, _ in false }
    }

    func testDerZweiteAufrufMitDenselbenEingabenRechnetNichtNochEinmal() {
        let plan = ShoppingListPlan()
        let items = [ShoppingItem(text: "Milch")]
        let vorrat = offers()

        let erst = ranks(plan, items: items, offers: vorrat)
        let zweit = ranks(plan, items: items, offers: vorrat)

        XCTAssertEqual(plan.berechnungen, 1, "Der zweite Rumpf hat noch einmal gerechnet")
        XCTAssertEqual(erst.map(\.chain), zweit.map(\.chain))
        XCTAssertEqual(erst.first?.matchedCount, zweit.first?.matchedCount)
    }

    /// Der Fall, der im Laden passiert: ein Haken. Danach ist die Liste eine
    /// andere, und der Plan muss es auch sein.
    func testEinArtikelWenigerRechnetNeu() {
        let plan = ShoppingListPlan()
        let vorrat = offers()
        _ = ranks(plan, items: [ShoppingItem(text: "Milch"), ShoppingItem(text: "Brot")],
                  offers: vorrat)
        _ = ranks(plan, items: [ShoppingItem(text: "Milch")], offers: vorrat)
        XCTAssertEqual(plan.berechnungen, 2)
    }

    func testEineNeueHeftungRechnetNeu() {
        let plan = ShoppingListPlan()
        let vorrat = offers()
        var item = ShoppingItem(text: "Milch")
        _ = ranks(plan, items: [item], offers: vorrat)
        item.pins = [vorrat[1].asPin]
        _ = ranks(plan, items: [item], offers: vorrat)
        XCTAssertEqual(plan.berechnungen, 2, "Die Heftung steht nicht im Schlüssel")
    }

    /// **Ein neuer Vorrat bei gleicher Zeilenzahl** — der Fall, an dem
    /// „Zeitpunkt plus Anzahl" als Schlüssel gescheitert wäre: Wer die Filiale
    /// wechselt, bekommt aus dem Cache denselben Zeitpunkt und kann dieselbe
    /// Zeilenzahl haben. Der Zähler von `OfferStore` kann das nicht.
    func testEinNeuerVorratRechnetNeu() {
        let plan = ShoppingListPlan()
        let items = [ShoppingItem(text: "Milch")]
        _ = ranks(plan, items: items, offers: offers(), generation: 1)
        _ = ranks(plan, items: items, offers: offers(), generation: 2)
        XCTAssertEqual(plan.berechnungen, 2)
    }

    func testEineWeitereKetteRechnetNeu() {
        let plan = ShoppingListPlan()
        let items = [ShoppingItem(text: "Milch")]
        let vorrat = offers()
        _ = ranks(plan, items: items, offers: vorrat, chains: ["Lidl"])
        _ = ranks(plan, items: items, offers: vorrat, chains: ["Lidl", "Aldi"])
        XCTAssertEqual(plan.berechnungen, 2)
    }

    func testEineNeueAblehnungRechnetNeu() {
        let plan = ShoppingListPlan()
        let items = [ShoppingItem(text: "Milch")]
        let vorrat = offers()
        _ = ranks(plan, items: items, offers: vorrat, rejections: [])
        _ = ranks(plan, items: items, offers: vorrat, rejections: ["milch|lidl-vollmilch"])
        XCTAssertEqual(plan.berechnungen, 2)
    }
}
