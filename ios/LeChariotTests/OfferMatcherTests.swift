import XCTest
@testable import LeChariot

final class OfferMatcherTests: XCTestCase {
    private func offer(
        _ product: String,
        matchKey: [String] = [],
        price: Double? = 1.99,
        market: String = "Lidl",
        category: String? = nil
    ) -> Offer {
        var base = MockFixtures.offers[0]
        base = Offer(
            market: market, product: product, price: price,
            regularPrice: nil, unit: nil, category: category ?? base.category, emoji: nil,
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

    func testFischDoesNotFuzzyMatchFrisch() {
        // Echte match_feedback-Zeilen der Runde vom 2026-08-05: „fisch"
        // lieferte Direkttreffer auf drei Titel mit „frisch". Der eingefügte
        // Buchstabe steht **vorn** — das ist kein Tippfehler, sondern ein
        // anderes Wort. Vgl. „Butter"/„Bitter" (21.07.).
        let offers = [
            offer("Sensodyne Zahncreme Sensitiv Fluorid oder Extra Frisch", matchKey: ["nonfood"]),
            offer("Gutfried Hähnchen-Fleischwurst würzig-frisch", matchKey: ["wurst"]),
            offer("Bettine Ziegenkäse holl. Frisch- oder Weichkäse", matchKey: ["käse"]),
            offer("FUNNY-FRISCH Knuspersnack", matchKey: ["chips"]),
            offer("WC-FRISCH Kraft Aktiv", matchKey: ["nonfood"]),
        ]
        XCTAssertTrue(OfferMatcher.matches(for: "Fisch", in: offers).isEmpty)
    }

    func testLachsDoesNotFuzzyMatchFlachs() {
        // Dieselbe Form wie fisch/frisch: ein Buchstabe vorn dazu.
        let offers = [offer("Flachs Deko-Bund", matchKey: ["nonfood"])]
        XCTAssertTrue(OfferMatcher.matches(for: "Lachs", in: offers).isEmpty)
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

    /// **Bis #106 stand hier „Direkttreffer zuerst".** Der „Käse Aufschnitt"
    /// gewann gegen den billigeren Gouda, weil er das Wort im Titel trägt —
    /// eine Rangfolge nach Fundweg. Alle drei stehen im selben Regal, also
    /// ordnet jetzt der Preis; der Fundweg bleibt in `kind` und wird in der
    /// Zeile genannt, statt die Reihenfolge zu bestimmen.
    func testInsideOneShelfThePriceOrdersRegardlessOfRoute() {
        let offers = [
            offer("Bergkäse teuer", matchKey: ["käse"], price: 4.99, category: "Molkerei & Eier"),
            offer("Käse Aufschnitt", matchKey: ["käse"], price: 2.49, category: "Molkerei & Eier"),
            offer("Gouda billig", matchKey: ["käse"], price: 0.99, category: "Molkerei & Eier"),
        ]
        let matches = OfferMatcher.matches(for: "Käse", in: offers)
        XCTAssertEqual(
            matches.map(\.offer.product),
            ["Gouda billig", "Käse Aufschnitt", "Bergkäse teuer"]
        )
        XCTAssertEqual(matches.map(\.kind), [.category, .direct, .category])
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

    // MARK: Sorte statt Warengruppe (Wörterbuch-Runde 2026-08-25)

    /// Das Wurstregal der Woche, so getaggt, wie das Backend seit der Runde
    /// vom 25.08. taggt: **beide** Tags, die Sorte und die Warengruppe.
    private var wurstRegal: [Offer] {
        [
            offer("AOSTE Salami", matchKey: ["wurst", "salami"]),
            offer("WILTMANN Bio-Salami", matchKey: ["wurst", "salami"]),
            offer("K-CLASSIC Rostbratwurst", matchKey: ["wurst", "bratwurst"]),
            offer("Rügenwalder Teewurst", matchKey: ["wurst", "leberwurst"]),
            offer("BÖKLUNDER Kleine Wiener", matchKey: ["wurst", "würstchen"]),
        ]
    }

    /// **Die häufigste Beschwerde, als Test.** Wer „Salami" tippt, bekam über
    /// den Tag `wurst` das ganze Regal — am Bestand vom 25.08. waren das 216
    /// Angebote für jedes einzelne Wurstwort, „Frankfurter" und „Leberwurst"
    /// eingeschlossen.
    func testASortDoesNotDragInTheWholeShelf() {
        let treffer = OfferMatcher.matches(for: "Salami", in: wurstRegal)
        XCTAssertEqual(
            Set(treffer.map(\.offer.product)),
            ["AOSTE Salami", "WILTMANN Bio-Salami"],
            "geliefert wurde: \(treffer.map(\.offer.product))"
        )
    }

    /// Und die Gegenprobe, ohne die der Test oben auch von einer kaputten
    /// Suche erfüllt wäre: Die Warengruppe selbst holt weiterhin alles.
    func testTheShelfWordStillFindsEverything() {
        let treffer = OfferMatcher.matches(for: "Wurst", in: wurstRegal)
        XCTAssertEqual(treffer.count, wurstRegal.count)
    }

    /// Ein Suchwort ohne Titeltreffer, das nur über die Sorte ankommt.
    func testASortWordFindsItsOfferWithoutStandingInTheTitle() {
        let treffer = OfferMatcher.matches(for: "Frankfurter", in: wurstRegal)
        XCTAssertEqual(treffer.map(\.offer.product), ["BÖKLUNDER Kleine Wiener"])
    }

    // MARK: Die Sperrliste gilt auch für den Titeltreffer (Runde 2026-08-25b)

    /// Das Milchregal, wie das Backend es taggt: Die drei gemeldeten Zeilen
    /// tragen **kein** `milch`, weil das Wörterbuch sie für den Begriff
    /// sperrt — nur stand das Wort trotzdem im Titel.
    private var milchRegal: [Offer] {
        [
            offer("Frische Vollmilch 3,5 %", matchKey: ["milch"]),
            offer("MILCH-SCHNITTE Snack", matchKey: ["schokolade"]),
            offer("LECKERMÄULCHEN Milch-Quark", matchKey: ["quark"]),
            offer("LINDENHOF Faire Milch Gouda jung", matchKey: ["käse", "gouda"]),
        ]
    }

    /// **Der am häufigsten gemeldete Fehltreffer überhaupt.** Drei Meldungen
    /// für die Milch-Schnitte, drei für den Milch-Quark. Beide standen als
    /// Direkttreffer da, weil „Milch" wörtlich im Titel steht — und Stufe 1
    /// fragte das Wörterbuch nicht, das beide längst sperrt.
    func testATitleHitTheDictionaryBlocksIsNoHit() {
        let treffer = OfferMatcher.matches(for: "Milch", in: milchRegal)
        XCTAssertEqual(
            treffer.map(\.offer.product), ["Frische Vollmilch 3,5 %"],
            "geliefert wurde: \(treffer.map(\.offer.product))"
        )
    }

    /// Dieselbe Form über eine Wendung statt ein Wort: „Brot-Aufstrich" wird
    /// zu zwei Wörtern normalisiert, gesperrt ist es als Paar.
    func testABlockedPhraseInTheTitleAlsoCounts() {
        let regal = [
            offer("Bauernbrot geschnitten", matchKey: ["brot"]),
            offer("POPP Brot-Aufstrich", matchKey: ["marmelade"]),
        ]
        XCTAssertEqual(
            OfferMatcher.matches(for: "Brot", in: regal).map(\.offer.product),
            ["Bauernbrot geschnitten"]
        )
    }

    /// **Und die Gegenprobe, ohne die die Regel zu viel nähme:** Wer das
    /// sperrende Wort selbst tippt, meint genau das Produkt. `salami` sperrt
    /// „pizza" — „Pizza Salami" zu suchen muss die Pizza finden.
    func testAWordTheUserTypedDoesNotBlock() {
        let regal = [
            offer("Pizza Salami", matchKey: ["pizza", "wurst"]),
            offer("AOSTE Salami", matchKey: ["wurst", "salami"]),
        ]
        XCTAssertEqual(
            OfferMatcher.matches(for: "Pizza Salami", in: regal).map(\.offer.product),
            ["Pizza Salami"]
        )
        // Und ohne das getippte Wort bleibt die Sperre stehen.
        XCTAssertEqual(
            OfferMatcher.matches(for: "Salami", in: regal).map(\.offer.product),
            ["AOSTE Salami"]
        )
    }

    /// Ein gesperrter Titeltreffer soll nicht über die Hintertür der Tags
    /// zurückkommen — und ein Angebot ohne jede Sperre bleibt unberührt.
    func testTheBlockDoesNotLeakIntoUnrelatedOffers() {
        let regal = [
            offer("Schinken-Käse-Croissant", matchKey: ["backwaren", "croissant"]),
            offer("Gouda am Stück", matchKey: ["käse", "gouda"]),
        ]
        XCTAssertEqual(
            OfferMatcher.matches(for: "Käse", in: regal).map(\.offer.product),
            ["Gouda am Stück"]
        )
    }

    /// **Die Regel selbst**, an den beiden Fällen, die sie gebaut haben.
    func testTheNarrowerTermWins() {
        XCTAssertTrue(MatchDictionary.terms(forToken: "salami").contains("wurst"))
        XCTAssertEqual(MatchDictionary.meaning(forToken: "salami"), ["salami"])
        // Gemeldet am 25.08.: „Brokkoli gesucht, alles andere an Gemüse
        // bekommen." `brokkoli` trug Porree, Radieschen und Rote Bete mit.
        XCTAssertEqual(MatchDictionary.meaning(forToken: "porree"), ["lauch"])
        XCTAssertEqual(MatchDictionary.terms(forToken: "brokkoli"), ["brokkoli"])
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

    // MARK: Reihenfolge — was das Produkt ist, nicht wie es gefunden wurde (#106)

    /// **Der gemessene Fall vom 01.08.**: Ein Gebäckartikel nannte „Käse"
    /// wörtlich und stand deshalb ganz oben. Den Twister von damals sperrt
    /// inzwischen das Wörterbuch; die Käse-Spätzle nicht, und das zu Recht —
    /// sie sind ein Treffer, nur eben keiner aus dem Käseregal.
    func testTheFrozenDishDoesNotStandAboveTheCheese() {
        let regal = [
            offer("Käse-Spätzle", matchKey: ["spätzle"], price: 0.99, category: "Tiefkühl"),
            offer("GRÜNLÄNDER Schnittkäse", matchKey: ["käse"], price: 2.49, category: "Molkerei & Eier"),
        ]
        let treffer = OfferMatcher.matches(for: "Käse", in: regal)

        XCTAssertEqual(treffer.map(\.offer.product), ["GRÜNLÄNDER Schnittkäse", "Käse-Spätzle"])
        // Der Fundweg bleibt, was er ist — er ordnet nur nicht mehr.
        XCTAssertEqual(treffer.first?.kind, .category)
        XCTAssertEqual(treffer.last?.kind, .direct)
    }

    /// Innerhalb des Regals entscheidet weiter der Preis — auch über den
    /// Fundweg hinweg. Vorher stand jeder Titeltreffer über jedem Tag-Treffer,
    /// und der billigste Joghurt landete auf Platz vier.
    func testInsideTheShelfThePriceDecidesAcrossBothRoutes() {
        let regal = [
            offer("MILBONA Joghurt 3,5 %", matchKey: ["joghurt"], price: 0.89, category: "Molkerei & Eier"),
            offer("MÜLLER Froop", matchKey: ["joghurt"], price: 0.44, category: "Molkerei & Eier"),
            offer("BIOLAND Joghurt mild", matchKey: ["joghurt"], price: 1.79, category: "Molkerei & Eier"),
        ]
        let treffer = OfferMatcher.matches(for: "Joghurt", in: regal)

        XCTAssertEqual(treffer.map(\.offer.price), [0.44, 0.89, 1.79])
    }

    /// Kennt das Wörterbuch die Anfrage nicht — Markenname, Fantasiewort —,
    /// gibt es kein Regal, in das etwas gehören könnte. Dann zählt allein der
    /// Preis, genau wie vor #106.
    func testWithoutAKnownShelfOnlyThePriceOrders() {
        let regal = [
            offer("MILBONA Butterkäse", matchKey: ["käse"], price: 2.99, category: "Molkerei & Eier"),
            offer("MILBONA Skyr", matchKey: ["joghurt"], price: 0.99, category: "Molkerei & Eier"),
        ]
        let treffer = OfferMatcher.matches(for: "Milbona", in: regal)

        XCTAssertEqual(treffer.map(\.offer.price), [0.99, 2.99])
    }

    /// Zwei Zeilen, die in allem gleich sind, dürfen nicht in zwei Läufen zwei
    /// Reihenfolgen ergeben: Swifts `sorted` ist nicht stabil.
    func testTheSameShelfAndPriceStillOrdersTheSameEveryRun() {
        let regal = [
            offer("Gouda jung", matchKey: ["käse"], price: 1.99, category: "Molkerei & Eier"),
            offer("Emmentaler Scheiben", matchKey: ["käse"], price: 1.99, category: "Molkerei & Eier"),
            offer("Cheddar am Stück", matchKey: ["käse"], price: 1.99, category: "Molkerei & Eier"),
        ]
        let einmal = OfferMatcher.matches(for: "Käse", in: regal).map(\.offer.product)
        let nochmal = OfferMatcher.matches(for: "Käse", in: regal.reversed()).map(\.offer.product)

        XCTAssertEqual(einmal, nochmal)
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
