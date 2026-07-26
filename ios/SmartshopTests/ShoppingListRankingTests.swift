import XCTest
@testable import Smartshop

final class ShoppingListRankingTests: XCTestCase {
    private func offer(
        _ product: String,
        market: String,
        price: Double? = 1.0,
        matchKey: [String] = []
    ) -> Offer {
        let base = MockFixtures.offers[0]
        var made = Offer(
            market: market, product: product, price: price,
            regularPrice: nil, unit: nil, category: base.category, emoji: nil,
            validFrom: base.validFrom, validUntil: base.validUntil,
            basePrice: nil, baseUnit: nil, nationwide: false
        )
        made.matchKey = matchKey
        return made
    }

    private func items(_ texts: [String]) -> [ShoppingItem] {
        texts.map { ShoppingItem(text: $0) }
    }

    /// Nachweis Laufplan: a market with 2/6 cheap hits must NOT rank above a
    /// market with 5/6 hits, however expensive the 5 are.
    func testCoverageBeatsPrice() {
        let list = items(["Milch", "Butter", "Gouda", "Salami", "Joghurt", "Ananas"])
        let offers = [
            // Lidl: 5/6, expensive
            offer("Frische Milch", market: "Lidl", price: 3.0),
            offer("Butter Markenqualität", market: "Lidl", price: 3.0),
            offer("Gouda jung", market: "Lidl", price: 3.0),
            offer("Salami geschnitten", market: "Lidl", price: 3.0),
            offer("Joghurt Becher", market: "Lidl", price: 3.0),
            // Netto: 2/6, dirt cheap
            offer("Frische Milch", market: "Netto", price: 0.5),
            offer("Butter Markenqualität", market: "Netto", price: 0.5),
        ]
        let ranks = ShoppingListRanking.rank(items: list, offers: offers, chains: ["Lidl", "Netto"])
        XCTAssertEqual(ranks.map(\.chain), ["Lidl", "Netto"])
        XCTAssertEqual(ranks[0].matchedCount, 5)
        XCTAssertEqual(ranks[0].total, 15.0)
        XCTAssertEqual(ranks[1].matchedCount, 2)
    }

    func testPriceBreaksCoverageTie() {
        let list = items(["Milch"])
        let offers = [
            offer("Frische Milch", market: "Lidl", price: 1.29),
            offer("Frische Milch", market: "Netto", price: 0.99),
        ]
        let ranks = ShoppingListRanking.rank(items: list, offers: offers, chains: ["Lidl", "Netto"])
        XCTAssertEqual(ranks.map(\.chain), ["Netto", "Lidl"])
    }

    func testUsesCheapestMatchPerItemAndChain() {
        let list = items(["Käse"])
        let offers = [
            offer("Käse Aufschnitt", market: "Lidl", price: 2.49),
            offer("Käse Würfel", market: "Lidl", price: 1.11),
        ]
        let ranks = ShoppingListRanking.rank(items: list, offers: offers, chains: ["Lidl"])
        XCTAssertEqual(ranks[0].total, 1.11)
    }

    func testRejectedMatchDoesNotCount() {
        let list = items(["Milch"])
        let milch = offer("Frische Milch", market: "Lidl", price: 0.99)
        let ranks = ShoppingListRanking.rank(
            items: list, offers: [milch], chains: ["Lidl"]
        ) { _, _ in true }
        XCTAssertEqual(ranks[0].matchedCount, 0)
        XCTAssertNil(ranks[0].total)
    }

    func testEmptyListYieldsNoRanking() {
        let ranks = ShoppingListRanking.rank(items: [], offers: MockFixtures.offers, chains: ["Lidl"])
        XCTAssertTrue(ranks.isEmpty)
    }

    func testChainWithoutAnyOffersStillListedLast() {
        let list = items(["Milch"])
        let offers = [offer("Frische Milch", market: "Lidl", price: 0.99)]
        let ranks = ShoppingListRanking.rank(items: list, offers: offers, chains: ["Lidl", "Konsum"])
        XCTAssertEqual(ranks.map(\.chain), ["Lidl", "Konsum"])
        XCTAssertEqual(ranks[1].matchedCount, 0)
        XCTAssertNil(ranks[1].total)
    }

    func testCategoryHitCountsTowardCoverage() {
        let list = items(["Käse"])
        let offers = [offer("Gouda jung", market: "Lidl", price: 1.99, matchKey: ["käse"])]
        let ranks = ShoppingListRanking.rank(items: list, offers: offers, chains: ["Lidl"])
        XCTAssertEqual(ranks[0].matchedCount, 1)
        XCTAssertEqual(ranks[0].total, 1.99)
    }

    // MARK: Per-item breakdown (feeds the Einkaufsplan card)

    /// The card names the covered items and the ones the user pays full price
    /// for, so both lists must together account for every item on the list.
    func testMatchedAndMissingItemsCoverTheWholeList() {
        let list = items(["Milch", "Butter", "Zahnpasta"])
        let offers = [
            offer("Frische Milch", market: "Lidl", price: 0.99),
            offer("Butter Markenqualität", market: "Lidl", price: 1.79),
        ]
        let rank = ShoppingListRanking.rank(items: list, offers: offers, chains: ["Lidl"])[0]

        XCTAssertEqual(rank.matchedItems.map(\.item), ["Milch", "Butter"])
        XCTAssertEqual(rank.missingItems, ["Zahnpasta"])
        XCTAssertEqual(rank.matchedCount, 2)
        XCTAssertEqual(rank.itemCount, 3)
        XCTAssertEqual(rank.matchedCount + rank.missingItems.count, list.count)
    }

    /// The card shows the item the user typed next to the offer it resolved to;
    /// mixing those up would make "Käse → Gouda jung" unreadable.
    func testMatchedItemKeepsTheUserWordingAndTheOffer() {
        let list = items(["Käse"])
        let offers = [offer("Gouda jung", market: "Lidl", price: 1.99, matchKey: ["käse"])]
        let rank = ShoppingListRanking.rank(items: list, offers: offers, chains: ["Lidl"])[0]

        XCTAssertEqual(rank.matchedItems[0].item, "Käse")
        XCTAssertEqual(rank.matchedItems[0].offer.product, "Gouda jung")
    }

    func testChainWithoutOffersListsEveryItemAsMissing() {
        let list = items(["Milch", "Butter"])
        let offers = [offer("Frische Milch", market: "Lidl", price: 0.99)]
        let ranks = ShoppingListRanking.rank(items: list, offers: offers, chains: ["Lidl", "Konsum"])

        let konsum = try! XCTUnwrap(ranks.first { $0.chain == "Konsum" })
        XCTAssertTrue(konsum.matchedItems.isEmpty)
        XCTAssertEqual(konsum.missingItems, ["Milch", "Butter"])
    }

    func testRejectedMatchLandsInMissing() {
        let list = items(["Milch"])
        let milch = offer("Frische Milch", market: "Lidl", price: 0.99)
        let rank = ShoppingListRanking.rank(
            items: list, offers: [milch], chains: ["Lidl"]
        ) { _, _ in true }[0]

        XCTAssertTrue(rank.matchedItems.isEmpty)
        XCTAssertEqual(rank.missingItems, ["Milch"])
    }
}
