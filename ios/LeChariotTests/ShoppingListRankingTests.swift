import XCTest
@testable import LeChariot

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

    // MARK: Die geheftete Wahl in der Rangfolge

    /// **Die Summe rechnet den Einkauf, den der Nutzer macht.** Wer den
    /// GRÜNLÄNDER für 0,99 € geheftet hat, spart die 0,69 € des
    /// Speck-Käse-Twisters nicht — eine Karte, die trotzdem 0,69 € behauptet,
    /// rechnet einen fremden Einkauf aus.
    func testAPinnedChoiceCountsWithItsOwnPrice() {
        var kaese = ShoppingItem(text: "Käse")
        let gruenlaender = offer("GRÜNLÄNDER Schnittkäse", market: "Lidl", price: 0.99)
        kaese.pins = [gruenlaender.asPin]
        let offers = [
            offer("Speck-Käse-Twister", market: "Lidl", price: 0.69),
            gruenlaender,
        ]

        let ohne = ShoppingListRanking.rank(
            items: [ShoppingItem(text: "Käse")], offers: offers, chains: ["Lidl"]
        )[0]
        XCTAssertEqual(ohne.total, 0.69, "Ohne Heftung gewinnt das billigste — sonst prüft der Test daneben")

        let mit = ShoppingListRanking.rank(items: [kaese], offers: offers, chains: ["Lidl"])[0]
        XCTAssertEqual(mit.total, 0.99)
        XCTAssertEqual(mit.matchedItems[0].offer.product, "GRÜNLÄNDER Schnittkäse")
        XCTAssertTrue(mit.matchedItems[0].isPinned)
        XCTAssertTrue(mit.hasPinnedItems)
    }

    /// Eine Kette, die das geheftete Produkt nicht führt, deckt den Artikel
    /// nicht ab — und landet dafür in einem **eigenen** Topf. „Netto hat keinen
    /// Käse" und „Netto hat Käse, aber nicht deinen" sind zwei Sätze.
    func testAChainWithoutThePinnedProductListsItSeparatelyFromTheMissingOnes() {
        var kaese = ShoppingItem(text: "Käse")
        let gruenlaender = offer("GRÜNLÄNDER Schnittkäse", market: "Lidl", price: 0.99)
        kaese.pins = [gruenlaender.asPin]
        let offers = [
            gruenlaender,
            offer("Käse Würfel", market: "Netto", price: 0.55),
        ]

        let netto = ShoppingListRanking.rank(
            items: [kaese], offers: offers, chains: ["Lidl", "Netto"]
        ).first { $0.chain == "Netto" }!

        XCTAssertTrue(netto.matchedItems.isEmpty)
        XCTAssertTrue(netto.missingItems.isEmpty, "Netto hat sehr wohl Käse — nur nicht diesen")
        XCTAssertEqual(netto.pinnedElsewhere.map(\.item), ["Käse"])
        XCTAssertEqual(netto.pinnedElsewhere[0].line, "Käse — GRÜNLÄNDER Schnittkäse bei Lidl")
        XCTAssertNil(netto.total)
        // Der Artikel bleibt im Nenner: „deckt 0 von 1 ab" ist die wahre
        // Aussage, „0 von 0" wäre eine Ausrede.
        XCTAssertEqual(netto.itemCount, 1)
    }

    /// **Und deshalb darf eine Heftung den empfohlenen Markt kippen.** Ohne sie
    /// gewinnt Netto mit 2/2; mit ihr deckt Netto nur noch einen Artikel ab.
    func testAPinCanFlipTheRecommendedMarketAndSaysSo() {
        var kaese = ShoppingItem(text: "Käse")
        let gruenlaender = offer("GRÜNLÄNDER Schnittkäse", market: "Lidl", price: 0.99)
        kaese.pins = [gruenlaender.asPin]
        let list = [ShoppingItem(text: "Milch"), kaese]
        let offers = [
            offer("Frische Milch", market: "Lidl", price: 1.19),
            gruenlaender,
            offer("Frische Milch", market: "Netto", price: 0.89),
            offer("Käse Würfel", market: "Netto", price: 0.55),
        ]

        let ohne = ShoppingListRanking.rank(
            items: list.map { var k = $0; k.pins = nil; return k },
            offers: offers, chains: ["Lidl", "Netto"]
        )
        XCTAssertEqual(ohne.first?.chain, "Netto", "Ohne Heftung deckt Netto beides billiger ab")

        let mit = ShoppingListRanking.rank(items: list, offers: offers, chains: ["Lidl", "Netto"])
        XCTAssertEqual(mit.first?.chain, "Lidl")
        XCTAssertEqual(mit.first?.matchedCount, 2)

        // Und die Karte kann es sagen.
        XCTAssertEqual(
            ShoppingListRanking.winnerWithoutPins(
                items: list, offers: offers, chains: ["Lidl", "Netto"]
            ),
            "Netto"
        )
    }

    /// Die Gegenprobe: Kippt die Heftung nichts, sagt die Karte auch nichts.
    /// Ein Hinweis, der immer dasteht, erklärt nichts mehr.
    func testWithoutAFlipTheCardStaysQuiet() {
        var kaese = ShoppingItem(text: "Käse")
        let gruenlaender = offer("GRÜNLÄNDER Schnittkäse", market: "Lidl", price: 0.99)
        kaese.pins = [gruenlaender.asPin]
        let offers = [
            gruenlaender,
            offer("Speck-Käse-Twister", market: "Lidl", price: 0.69),
        ]
        XCTAssertNil(ShoppingListRanking.winnerWithoutPins(
            items: [kaese], offers: offers, chains: ["Lidl"]
        ))
        XCTAssertNil(ShoppingListRanking.winnerWithoutPins(
            items: [ShoppingItem(text: "Käse")], offers: offers, chains: ["Lidl"]
        ), "Ohne jede Heftung schon gar nicht")
    }

    /// **Hälfte 2 der Regel: eine Heftung ohne Angebot schläft.** Sonst gälte
    /// der Artikel überall als unabgedeckt, und die Abdeckungszahl erzählte von
    /// einem verschwundenen Prospekt statt vom Einkauf. Dass die Zeile den
    /// Rückfall trotzdem ausspricht, prüft `PinnedOfferTests`.
    func testAPinWhoseProductIsGoneFallsBackToTheCheapestEverywhere() {
        var kaese = ShoppingItem(text: "Käse")
        kaese.pins = [offer("GRÜNLÄNDER Schnittkäse", market: "Netto", price: 0.99).asPin]
        let offers = [offer("Käse Würfel", market: "Lidl", price: 0.55)]

        let lidl = ShoppingListRanking.rank(items: [kaese], offers: offers, chains: ["Lidl"])[0]
        XCTAssertEqual(lidl.matchedItems.map(\.item), ["Käse"])
        XCTAssertFalse(lidl.matchedItems[0].isPinned)
        XCTAssertTrue(lidl.pinnedElsewhere.isEmpty)
        XCTAssertEqual(lidl.total, 0.55)
    }
}
