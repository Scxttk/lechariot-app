import XCTest
@testable import LeChariot

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
            basePrice: nil, baseUnit: nil, nationwide: false
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

    // MARK: Wörterbuch in der Suche (gemeldet 21.07., entschieden 31.07.)

    /// Das Regal aus dem gemeldeten Fall: Fleisch-Schnitzel und vegane
    /// Alternativen, so getaggt, wie das Backend sie tatsächlich taggt
    /// (nachgesehen in Supabase am 2026-07-31).
    private var schnitzelRegal: [Offer] {
        [
            offer("Schweineschnitzel XXL", matchKey: ["schwein"]),
            offer("MÜHLENHOF Frische Puten-Schnitzel", matchKey: ["pute"]),
            offer("RÜGENWALDER Vegane Mühlen BBQ-Steaks", matchKey: ["rind", "tofu"]),
            offer("Like vegane Fleischalternative", matchKey: ["tofu"]),
        ]
    }

    /// Ohne geladenes Wörterbuch wären die Leer-Erwartungen unten wertlos —
    /// sie träfen dann aus dem falschen Grund zu.
    func testTheDictionaryIsActuallyBundled() {
        XCTAssertGreaterThan(
            MatchDictionary.wordCount, 400,
            "Wörterbuch nicht im Bundle — die übrigen Tests prüfen sonst nichts"
        )
        XCTAssertEqual(MatchDictionary.terms(forToken: "vegan"), ["tofu"])
        XCTAssertEqual(MatchDictionary.terms(forToken: "fleischersatz"), ["tofu"])
    }

    /// **Der gemeldete Fall, und er muss leer bleiben.** „vegan Schnitzel"
    /// meint ein Produkt, das beides ist — kein Schweineschnitzel. Mit einem
    /// ODER in Stufe 2 hätte die Synonym-Abbildung genau das geliefert, weil
    /// „schnitzel" auf `schwein` und `pute` zeigt.
    func testVeganSchnitzelStaysEmpty() {
        let matches = OfferMatcher.matches(for: "vegan Schnitzel", in: schnitzelRegal)
        XCTAssertTrue(
            matches.isEmpty,
            "geliefert wurde: \(matches.map(\.offer.product))"
        )
    }

    /// Und die Gegenprobe, ohne die der Test oben auch von einer kaputten
    /// Suche erfüllt würde: Ein Synonym allein findet die getaggten Zeilen,
    /// obwohl das Wort in keinem Titel steht.
    func testASynonymAloneFindsTaggedOffers() {
        let matches = OfferMatcher.matches(for: "Fleischersatz", in: schnitzelRegal)
        XCTAssertEqual(
            Set(matches.map(\.offer.product)),
            ["RÜGENWALDER Vegane Mühlen BBQ-Steaks", "Like vegane Fleischalternative"]
        )
        XCTAssertTrue(matches.allSatisfy { $0.kind == .category })
    }

    /// Zwei Wörter, zwei Wege: „Pizza" steht im Titel, „vegan" nur im Tag —
    /// erfüllt ist damit beides, und das Angebot passt. Das ist der Fall, für
    /// den die Abbildung überhaupt gebaut ist.
    func testBothWordsMaySatisfyThroughDifferentRoutes() {
        let offers = [
            offer("Pizza Margherita", matchKey: ["pizza"]),
            offer("Pizza Gemüse", matchKey: ["pizza", "tofu"]),
        ]
        let matches = OfferMatcher.matches(for: "vegane Pizza", in: offers)
        XCTAssertEqual(matches.map(\.offer.product), ["Pizza Gemüse"])
    }

    /// Die Sperrlisten des Wörterbuchs gelten auch für Suchwörter: „Milchreis"
    /// ist bei `milch` gesperrt und darf nicht das ganze Milchregal öffnen.
    func testBlockedWordsDoNotOpenTheirCategory() {
        let offers = [
            offer("MILBONA Frische Weidemilch", matchKey: ["milch"]),
            offer("Fettarme H-Milch", matchKey: ["milch"]),
        ]
        XCTAssertTrue(OfferMatcher.matches(for: "Milchreis", in: offers).isEmpty)
    }

    /// Mehrwortige Synonyme wirken als Wendung — einzeln ist „creme" nichts.
    func testAMultiwordSynonymMatchesAsAPhrase() {
        let offers = [offer("MILBONA Crème Fraîche XXL", matchKey: ["sahne"])]
        XCTAssertEqual(
            OfferMatcher.matches(for: "creme fraiche", in: offers).count, 1
        )
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
