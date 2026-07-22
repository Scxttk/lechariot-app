import XCTest
@testable import Smartshop

final class OfferMatcherTests: XCTestCase {
    private func offer(
        _ product: String,
        matchKey: [String] = [],
        price: Double? = 1.99,
        market: String = "Lidl"
    ) -> Offer {
        var base = MockFixtures.offers[0]
        base = Offer(
            market: market, product: product, price: price,
            regularPrice: nil, unit: nil, category: base.category, emoji: nil,
            validFrom: base.validFrom, validUntil: base.validUntil,
            basePrice: nil, baseUnit: nil, region: "01219"
        )
        base.matchKey = matchKey
        return base
    }

    /// The week's cheese shelf: many offers share the "käse" tag, only one
    /// is an actual Limburger.
    private var kaeseRegal: [Offer] {
        [
            offer("Limburger", matchKey: ["käse"]),
            offer("Gouda jung", matchKey: ["käse"]),
            offer("GALBANI Mozzarella", matchKey: ["käse", "mozzarella"]),
            offer("Emmentaler Scheiben", matchKey: ["käse"]),
            offer("Cheddar am Stück", matchKey: ["käse"]),
        ]
    }

    // MARK: Stufe 1 — Direkttreffer (Nachweis Laufplan)

    func testLimburgerHitsOnlyTheLimburgerNotAllCheese() {
        let direct = OfferMatcher.matches(for: "Limburger", in: kaeseRegal)
            .filter { $0.kind == .direct }
        XCTAssertEqual(direct.map(\.offer.product), ["Limburger"])
    }

    func testLimburgerTypoStillHitsDirect() {
        let direct = OfferMatcher.matches(for: "limbuger", in: kaeseRegal)
            .filter { $0.kind == .direct }
        XCTAssertEqual(direct.map(\.offer.product), ["Limburger"])
    }

    func testShortTokensAreNotFuzzyMatched() {
        // "Käse" (4 letters) must never fuzzy-hit "Kekse" — fuzziness starts at 5.
        let offers = [offer("Kekse Auswahl", matchKey: ["kekse"])]
        let direct = OfferMatcher.matches(for: "Käse", in: offers)
            .filter { $0.kind == .direct }
        XCTAssertTrue(direct.isEmpty)
    }

    func testButterDoesNotFuzzyMatchBitter() {
        // Real match_feedback rows from 2026-07-21: "Butter" direct-hit
        // "CAMPARI Bitter" and "Aperol Aperitif Bitter" via Levenshtein 1.
        // Same-length substitutions are different words, not typos.
        let offers = [
            offer("CAMPARI Bitter", matchKey: []),
            offer("Aperol Aperitif Bitter", matchKey: []),
        ]
        let direct = OfferMatcher.matches(for: "Butter", in: offers)
            .filter { $0.kind == .direct }
        XCTAssertTrue(direct.isEmpty)
    }

    func testMultiwordQueryRequiresAllTokens() {
        let offers = [
            offer("Gouda jung", matchKey: ["käse"]),
            offer("Gouda gerieben", matchKey: ["käse"]),
        ]
        let direct = OfferMatcher.matches(for: "Gouda jung", in: offers)
            .filter { $0.kind == .direct }
        XCTAssertEqual(direct.map(\.offer.product), ["Gouda jung"])
    }

    // MARK: Stufe 2 — Kategorie-Fallback (Nachweis Laufplan)

    func testKaeseQueryReturnsAllCheeseOffers() {
        let matches = OfferMatcher.matches(for: "Käse", in: kaeseRegal)
        XCTAssertEqual(matches.count, kaeseRegal.count)
        // Direct hits come first, category fallback after; no duplicates.
        XCTAssertEqual(Set(matches.map(\.offer.product)).count, kaeseRegal.count)
    }

    func testTomatenQueryDoesNotHitTomatenmark() {
        // Backend dictionary blocks composites: Tomatenmark carries no
        // "tomaten" tag, so neither stage may surface it.
        let offers = [
            offer("Rispentomaten", matchKey: ["tomaten"]),
            offer("Bio Tomatenmark", matchKey: []),
            offer("Cherrytomaten 250g", matchKey: ["tomaten"]),
        ]
        let matches = OfferMatcher.matches(for: "Tomaten", in: offers)
        XCTAssertFalse(matches.contains { $0.offer.product.contains("Tomatenmark") })
        XCTAssertEqual(matches.count, 2)
    }

    func testDirectHitIsNotDuplicatedAsCategoryHit() {
        let offers = [offer("Käse Aufschnitt", matchKey: ["käse"])]
        let matches = OfferMatcher.matches(for: "Käse", in: offers)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].kind, .direct)
    }

    func testMatchesOrderedDirectFirstThenByPrice() {
        // "Käse" hits "Käse Aufschnitt" directly (title token) and the rest
        // only via tag — direct first, then category by ascending price.
        let offers = [
            offer("Bergkäse teuer", matchKey: ["käse"], price: 4.99),
            offer("Käse Aufschnitt", matchKey: ["käse"], price: 2.49),
            offer("Gouda billig", matchKey: ["käse"], price: 0.99),
        ]
        let matches = OfferMatcher.matches(for: "Käse", in: offers)
        XCTAssertEqual(
            matches.map(\.offer.product),
            ["Käse Aufschnitt", "Gouda billig", "Bergkäse teuer"]
        )
        XCTAssertEqual(matches.map(\.kind), [.direct, .category, .category])
    }

    // MARK: Levenshtein

    func testLevenshteinBasics() {
        XCTAssertEqual(OfferMatcher.levenshtein("limbuger", "limburger"), 1)
        XCTAssertEqual(OfferMatcher.levenshtein("tomate", "tomaten"), 1)
        XCTAssertEqual(OfferMatcher.levenshtein("käse", "kekse"), 2)
    }
}

// MARK: - Rejections

@MainActor
final class MatchRejectionStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test.rejections")!
        defaults.removePersistentDomain(forName: "test.rejections")
    }

    func testRejectionSurvivesStoreRecreation() {
        // Same UserDefaults suite = same app storage across "restarts".
        let offer = MockFixtures.offers[0]
        let store = MatchRejectionStore(defaults: defaults)
        store.reject(itemText: "Milch", offer: offer)

        let reloaded = MatchRejectionStore(defaults: defaults)
        XCTAssertTrue(reloaded.isRejected(itemText: "Milch", offer: offer))
        XCTAssertFalse(reloaded.isRejected(itemText: "Käse", offer: offer))
    }

    func testUnrejectPersists() {
        let offer = MockFixtures.offers[0]
        let store = MatchRejectionStore(defaults: defaults)
        store.reject(itemText: "Milch", offer: offer)
        store.unreject(itemText: "Milch", offer: offer)

        let reloaded = MatchRejectionStore(defaults: defaults)
        XCTAssertFalse(reloaded.isRejected(itemText: "Milch", offer: offer))
    }

    func testRejectedOfferDropsOutOfSuggestion() {
        let cheap = MockFixtures.offers[0]
        let store = MatchRejectionStore(defaults: defaults)
        store.reject(itemText: cheap.product, offer: cheap)

        let match = ShoppingListMatcher.cheapestMatch(
            for: cheap.product, in: [cheap]
        ) { store.isRejected(itemText: cheap.product, offer: $0) }
        XCTAssertNil(match)
    }
}
