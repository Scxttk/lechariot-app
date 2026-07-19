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
            basePrice: basePrice, baseUnit: nil, region: "01219"
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
