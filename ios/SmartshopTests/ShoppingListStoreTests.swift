import XCTest
@testable import Smartshop

@MainActor
final class ShoppingListStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "ShoppingListStoreTests")
        defaults.removePersistentDomain(forName: "ShoppingListStoreTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "ShoppingListStoreTests")
        super.tearDown()
    }

    private func makeStore() -> ShoppingListStore {
        ShoppingListStore(defaults: defaults)
    }

    // MARK: Add & dedupe

    func testAddTrimsAndAppends() {
        let store = makeStore()
        XCTAssertTrue(store.add("  Milch "))
        XCTAssertEqual(store.items.map(\.text), ["Milch"])
    }

    func testAddRejectsEmptyAndDuplicates() {
        let store = makeStore()
        XCTAssertFalse(store.add("   "))
        XCTAssertTrue(store.add("Milch"))
        XCTAssertFalse(store.add("milch"))
        XCTAssertEqual(store.items.count, 1)
    }

    // MARK: Toggle, remove, clear

    func testToggleMovesItemBetweenOpenAndChecked() {
        let store = makeStore()
        store.add("Milch")
        let item = store.items[0]
        store.toggle(item)
        XCTAssertTrue(store.items[0].isChecked)
        XCTAssertEqual(store.uncheckedItems.count, 0)
        XCTAssertEqual(store.checkedItems.count, 1)
        store.toggle(store.items[0])
        XCTAssertFalse(store.items[0].isChecked)
    }

    func testRemoveAndClearChecked() {
        let store = makeStore()
        store.add("Milch")
        store.add("Brot")
        store.add("Eier")
        store.toggle(store.items[0])
        store.remove(store.items[1])
        XCTAssertEqual(store.items.map(\.text), ["Milch", "Eier"])
        store.clearChecked()
        XCTAssertEqual(store.items.map(\.text), ["Eier"])
        store.clearAll()
        XCTAssertTrue(store.items.isEmpty)
    }

    // MARK: Persistence

    func testItemsSurviveReload() {
        let store = makeStore()
        store.add("Milch")
        store.add("Brot")
        store.toggle(store.items[1])

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.items.map(\.text), ["Milch", "Brot"])
        XCTAssertTrue(reloaded.items[1].isChecked)
    }

    // MARK: Matcher

    private func offer(
        product: String,
        price: Double? = 1.0,
        basePrice: Double? = nil,
        market: String = "Lidl"
    ) -> Offer {
        Offer(
            market: market, product: product, price: price, regularPrice: nil,
            unit: nil, category: "Sonstiges", emoji: nil,
            validFrom: MockFixtures.day.date(from: "2026-07-13")!,
            validUntil: MockFixtures.day.date(from: "2026-07-19")!,
            basePrice: basePrice, baseUnit: nil, nationwide: false
        )
    }

    func testMatcherFindsCheapestCaseInsensitive() {
        let offers = [
            offer(product: "Bio Vollmilch", price: 1.29),
            offer(product: "Frische Vollmilch", price: 0.99),
            offer(product: "Orangen", price: 0.49),
        ]
        let match = ShoppingListMatcher.cheapestMatch(for: "vollmilch", in: offers)
        XCTAssertEqual(match?.offer.product, "Frische Vollmilch")
    }

    func testMatcherIgnoresOffersWithoutPrice() {
        let offers = [
            offer(product: "Vollmilch", price: nil),
            offer(product: "Vollmilch extra", price: 1.49),
        ]
        let match = ShoppingListMatcher.cheapestMatch(for: "Vollmilch", in: offers)
        XCTAssertEqual(match?.offer.product, "Vollmilch extra")
    }

    func testMatcherReturnsNilWithoutHitOrForEmptyText() {
        let offers = [offer(product: "Orangen")]
        XCTAssertNil(ShoppingListMatcher.cheapestMatch(for: "Milch", in: offers))
        XCTAssertNil(ShoppingListMatcher.cheapestMatch(for: "   ", in: offers))
    }

    func testMatcherBreaksPriceTieByBasePrice() {
        let offers = [
            offer(product: "Butter 250g", price: 1.99, basePrice: 7.96),
            offer(product: "Butter 500g", price: 1.99, basePrice: 3.98),
        ]
        let match = ShoppingListMatcher.cheapestMatch(for: "Butter", in: offers)
        XCTAssertEqual(match?.offer.product, "Butter 500g")
    }

    // MARK: Quick-add suggestions

    /// The point of the strip: take one staple, the others are still there.
    func testTakingASuggestionLeavesTheOthersStanding() {
        let remaining = ShoppingSuggestions.remaining(for: [ShoppingItem(text: "Milch")])

        XCTAssertFalse(remaining.contains("Milch"))
        XCTAssertEqual(remaining.count, ShoppingSuggestions.staples.count - 1)
        XCTAssertEqual(remaining.first, "Brot")
    }

    /// `add` refuses duplicates case-insensitively — suggesting one anyway
    /// would offer a chip that does nothing when tapped.
    func testSuggestionsMatchTheListCaseInsensitively() {
        let remaining = ShoppingSuggestions.remaining(for: [ShoppingItem(text: "milch")])

        XCTAssertFalse(remaining.contains("Milch"))
    }

    /// Re-suggesting what the user just ticked off would be the app arguing
    /// with them.
    func testACheckedItemIsStillOnTheList() {
        let remaining = ShoppingSuggestions.remaining(
            for: [ShoppingItem(text: "Brot", isChecked: true)]
        )

        XCTAssertFalse(remaining.contains("Brot"))
    }

    func testNothingLeftToSuggestReturnsAnEmptyStrip() {
        let items = ShoppingSuggestions.staples.map { ShoppingItem(text: $0) }

        XCTAssertTrue(ShoppingSuggestions.remaining(for: items).isEmpty)
    }

    func testUnrelatedItemsLeaveTheSuggestionsAlone() {
        let remaining = ShoppingSuggestions.remaining(for: [ShoppingItem(text: "Schokolade")])

        XCTAssertEqual(remaining, ShoppingSuggestions.staples)
    }

    // MARK: Corrupt persistence

    func testCorruptPersistedDataResetsToEmptyList() {
        defaults.set(Data("{broken".utf8), forKey: "shopping.items")
        let store = makeStore()
        XCTAssertTrue(store.items.isEmpty)
        // Store stays usable and re-persists cleanly after the reset.
        XCTAssertTrue(store.add("Milch"))
        XCTAssertEqual(makeStore().items.map(\.text), ["Milch"])
    }
}

// MARK: - Vorschläge wachsen nach (Backlog 2026-07-25)

@MainActor
final class SuggestionStripTests: XCTestCase {
    private let day = Calendar.supabase.date(from: DateComponents(year: 2026, month: 7, day: 20))!

    private func offer(_ product: String, tags: [String], price: Double, was: Double?) -> Offer {
        Offer(
            marketId: "lidl-01219-1", market: "Lidl", product: product, price: price,
            regularPrice: was, unit: nil, category: "Sonstiges", emoji: nil,
            validFrom: day, validUntil: day, basePrice: nil, baseUnit: nil,
            nationwide: false, matchKey: tags
        )
    }

    /// Der eigentliche Punkt: Der Streifen behält seine Länge, statt mit jedem
    /// Tippen zu schrumpfen. Vorher war er nach acht Grundnahrungsmitteln weg.
    func testTheStripKeepsItsLengthAsStaplesAreUsedUp() {
        let items = ShoppingSuggestions.staples.map { ShoppingItem(text: $0) }
        let offers = (1...12).map {
            offer("Angebot \($0)", tags: ["ware\($0)"], price: 1.0, was: 2.0)
        }

        let strip = ShoppingSuggestions.strip(for: items, offers: offers)

        XCTAssertEqual(strip.count, ShoppingSuggestions.stripLength)
        // Nichts davon steht schon auf der Liste.
        XCTAssertTrue(strip.allSatisfy { !ShoppingSuggestions.staples.contains($0) })
    }

    /// Solange Grundnahrungsmittel übrig sind, führen sie — sie sind die
    /// wahrscheinlichere Wahl als ein zufälliges Wochenangebot.
    func testStaplesComeFirst() {
        let strip = ShoppingSuggestions.strip(
            for: [], offers: [offer("Sekt", tags: ["sekt"], price: 3.0, was: 9.0)]
        )

        XCTAssertEqual(Array(strip.prefix(ShoppingSuggestions.staples.count)),
                       ShoppingSuggestions.staples)
    }

    /// Der Nachschub ist nach Rabatt sortiert — dann hat der Vorschlag einen
    /// Grund, und genau das unterscheidet ihn von einer längeren festen Liste.
    func testTopUpsAreOrderedByDiscount() {
        let items = ShoppingSuggestions.staples.map { ShoppingItem(text: $0) }
        let offers = [
            offer("Wenig reduziert", tags: ["mehl"], price: 1.80, was: 2.00),   // 10 %
            offer("Stark reduziert", tags: ["sekt"], price: 3.00, was: 9.00),   // 67 %
            offer("Ohne Streichpreis", tags: ["reis"], price: 1.00, was: nil),  //  0 %
        ]

        let strip = ShoppingSuggestions.strip(for: items, offers: offers)

        XCTAssertEqual(strip, ["Sekt", "Mehl", "Reis"])
    }

    /// Non-Food ist kein Einkaufslisten-Eintrag. Ein Akkuschrauber im Prospekt
    /// darf nicht als Vorschlag auftauchen.
    func testNonFoodIsNeverSuggested() {
        let items = ShoppingSuggestions.staples.map { ShoppingItem(text: $0) }
        let offers = [
            offer("Akku-Schrauber", tags: ["nonfood"], price: 29.99, was: 59.99),
            offer("Gouda", tags: ["gouda"], price: 1.99, was: 2.49),
        ]

        let strip = ShoppingSuggestions.strip(for: items, offers: offers)

        XCTAssertEqual(strip, ["Gouda"])
    }

    /// Was schon auf der Liste steht, kommt nicht als Angebot zurück.
    func testAnItemAlreadyOnTheListIsNotSuggestedAgain() {
        let items = ShoppingSuggestions.staples.map { ShoppingItem(text: $0) }
            + [ShoppingItem(text: "gouda")]
        let offers = [offer("Gouda", tags: ["gouda"], price: 1.99, was: 2.49)]

        XCTAssertTrue(ShoppingSuggestions.strip(for: items, offers: offers).isEmpty)
    }

    /// Ohne Angebote bleibt es beim alten Verhalten — kein Absturz, keine
    /// leeren Kacheln.
    func testWithoutOffersTheStaplesStillWork() {
        XCTAssertEqual(ShoppingSuggestions.strip(for: [], offers: []),
                       ShoppingSuggestions.staples)
    }
}
