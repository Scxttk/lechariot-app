import XCTest
@testable import Smartshop

/// The case this whole rebuild exists for: three REWE branches in one postcode.
///
/// Measured against the live database on 2026-07-25 for 01067 — Friedrichstadt
/// 243 offers, Schweriner Straße 162, Postplatz 146, and a Coca-Cola that costs
/// €0.75 at two of them and €1.49 at the third. Filtering by chain shows all
/// three flyers at once; filtering by branch shows the store the user walks
/// into.
private struct StubOfferRepository: OfferRepositoryProtocol {
    var result: [Offer] = []
    func offers(branchIds: [String]) async throws -> [Offer] { result }
}

@MainActor
final class OfferBranchFilterTests: XCTestCase {
    private let day = Calendar.supabase.date(from: DateComponents(year: 2026, month: 7, day: 20))!
    private let until = Calendar.supabase.date(from: DateComponents(year: 2026, month: 7, day: 25))!

    private func offer(
        branch: String?,
        chain: String = "REWE",
        product: String,
        price: Double,
        nationwide: Bool = false
    ) -> Offer {
        Offer(
            marketId: branch, market: chain, product: product, price: price,
            regularPrice: nil, unit: nil, category: "Getränke", emoji: "🥤",
            validFrom: day, validUntil: until, basePrice: nil, baseUnit: nil,
            nationwide: false
        )
    }

    /// Postplatz, Friedrichstadt, Schweriner Straße — with the real prices.
    private var koeln1067: [Offer] {
        [
            offer(branch: "1766063", product: "Coca-Cola", price: 0.75),
            offer(branch: "1766160", product: "Coca-Cola", price: 1.49),
            offer(branch: "1766160", product: "Aperol", price: 12.99),
            offer(branch: "1763556", product: "Bifi Roll", price: 0.89),
        ]
    }

    private func store(_ offers: [Offer]) -> OfferStore {
        OfferStore(repository: StubOfferRepository(result: offers), cache: nil)
    }

    func testChosenBranchHidesTheNeighbourBranchOfTheSameChain() async {
        let store = store(koeln1067)

        await store.load(branchIds: ["1766063"], chains: ["REWE"])

        XCTAssertEqual(store.offers.map(\.product), ["Coca-Cola"])
        XCTAssertEqual(store.offers.first?.price, 0.75, "Der Preis der GEWÄHLTEN Filiale")
    }

    func testTwoChosenBranchesShowBothFlyers() async {
        let store = store(koeln1067)

        await store.load(branchIds: ["1766063", "1766160"], chains: ["REWE"])

        // Beide Cola-Zeilen überleben: verschiedene Preise sind verschiedene
        // Angebote, das entscheidet der Dedupe-Schlüssel über die Cents.
        XCTAssertEqual(Set(store.offers.map(\.price)), [0.75, 1.49, 12.99])
    }

    /// Ohne gewählte Filiale gibt es nichts zu fragen. Seit die Abfrage über
    /// Filialen läuft, ist die leere Auswahl kein „zeig alles" mehr, sondern
    /// ein Leerzustand — den `ContentView` ohnehin abfängt, bevor die Tabs
    /// überhaupt erscheinen („Keine Filiale gewählt").
    func testWithoutBranchIdsThereIsNothingToShow() async {
        var offers = koeln1067
        offers.append(offer(branch: "4816", chain: "Netto", product: "Butter", price: 1.99))
        let store = store(offers)

        await store.load(branchIds: [], chains: ["Netto"])

        XCTAssertTrue(store.offers.isEmpty)
        XCTAssertEqual(store.state, .empty)
    }

    /// A dataset from before migration v13 has no branch on its rows. Applying
    /// the branch filter to it would empty the screen for exactly the users who
    /// cannot see why, so those rows fall back to the chain rule.
    func testRowsWithoutABranchFallBackToTheChainRule() async {
        let legacy = [
            offer(branch: nil, product: "Coca-Cola", price: 0.99),
            offer(branch: nil, chain: "Netto", product: "Butter", price: 1.99),
        ]
        let store = store(legacy)

        await store.load(branchIds: ["1766063"], chains: ["REWE"])

        XCTAssertEqual(store.offers.map(\.product), ["Coca-Cola"])
    }

    func testMixedDatasetKeepsBothHalves() async {
        // Mid-migration: one branch-keyed row, one legacy row of another chain.
        let mixed = [
            offer(branch: "1766063", product: "Coca-Cola", price: 0.75),
            offer(branch: nil, chain: "Netto", product: "Butter", price: 1.99),
        ]
        let store = store(mixed)

        await store.load(branchIds: ["1766063"], chains: ["REWE", "Netto"])

        XCTAssertEqual(Set(store.offers.map(\.product)), ["Coca-Cola", "Butter"])
    }

    /// Two branches, same product, same price — the row ids must differ, or a
    /// SwiftUI list shows one of them and silently drops the other.
    func testTwoBranchesOfOneChainHaveDistinctRowIds() {
        let a = offer(branch: "1766063", product: "Coca-Cola", price: 0.75)
        let b = offer(branch: "1763556", product: "Coca-Cola", price: 0.75)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testOfferDecodesTheBranchColumn() throws {
        let json = """
        {"market_id":"1766063","market":"REWE","product":"Coca-Cola","price":0.75,
         "category":"Getränke","valid_from":"2026-07-20","valid_until":"2026-07-25",
         "nationwide":false}
        """.data(using: .utf8)!
        let offer = try JSONDecoder.supabase.decode(Offer.self, from: json)
        XCTAssertEqual(offer.marketId, "1766063")
    }
}

// MARK: - Bundesweite Angebote (ALDI, Phase 12 Schritt 5)

/// ALDI Nord und ALDI SÜD veröffentlichen einen Katalog für ganz Deutschland;
/// ihre Zeilen tragen weder Filiale noch Region. Vorher speicherte das Backend
/// trotzdem eine Kopie pro Region — 2.965 Zeilen für rund 320 Angebote —, weil
/// diese App `region=in.(…)` fragte und eine Zeile ohne Region nie gesehen
/// hätte.
@MainActor
final class NationwideOfferTests: XCTestCase {
    private let day = Calendar.supabase.date(from: DateComponents(year: 2026, month: 7, day: 20))!
    private let until = Calendar.supabase.date(from: DateComponents(year: 2026, month: 7, day: 25))!

    private func offer(
        branch: String?,
        chain: String,
        product: String,
        price: Double,
        nationwide: Bool
    ) -> Offer {
        Offer(
            marketId: branch, market: chain, product: product, price: price,
            regularPrice: nil, unit: nil, category: "Molkerei", emoji: "🧀",
            validFrom: day, validUntil: until, basePrice: nil, baseUnit: nil,
            nationwide: nationwide
        )
    }

    private var mixed: [Offer] {
        [
            offer(branch: "ALDI_NORD_DE", chain: "ALDI Nord", product: "Ofenkäse",
                  price: 2.22, nationwide: true),
            offer(branch: "ALDI_SUED_DE", chain: "ALDI SÜD", product: "Rispentomaten",
                  price: 1.11, nationwide: true),
            offer(branch: "1766063", chain: "REWE", product: "Coca-Cola",
                  price: 0.75, nationwide: false),
            offer(branch: "1766160", chain: "REWE", product: "Aperol",
                  price: 12.99, nationwide: false),
        ]
    }

    private func store(_ offers: [Offer]) -> OfferStore {
        OfferStore(repository: StubOfferRepository(result: offers), cache: nil)
    }

    /// Der Kern: Die gewählte ALDI-Filiale heißt `ALDI_NORD_4711`, die Zeile
    /// trägt `ALDI_NORD_DE`. Ein reiner Filial-Abgleich würde ALDI komplett
    /// vom Bildschirm nehmen — genau der Fehler, der Schritt 5 vorher blockiert
    /// hat.
    func testANationwideOfferSurvivesTheBranchFilter() async {
        let store = store(mixed)

        await store.load(branchIds: ["ALDI_NORD_4711", "1766063"], chains: ["ALDI Nord", "REWE"])

        XCTAssertEqual(Set(store.offers.map(\.product)), ["Ofenkäse", "Coca-Cola"])
    }

    /// Bundesweit heißt nicht „immer sichtbar": Wer ALDI SÜD nicht gewählt hat,
    /// bekommt den Süd-Katalog auch nicht zu sehen.
    func testANationwideChainThatIsNotChosenStaysAway() async {
        let store = store(mixed)

        await store.load(branchIds: ["ALDI_NORD_4711"], chains: ["ALDI Nord"])

        XCTAssertEqual(store.offers.map(\.product), ["Ofenkäse"])
    }

    /// Am Aldi-Äquator (96515 Sonneberg) stehen beide Ketten nebeneinander.
    /// Keine verdrängt die andere — sie tragen verschiedene Ketten und
    /// verschiedene National-IDs.
    func testAtTheAldiEquatorBothCataloguesAreShown() async {
        let store = store(mixed)

        await store.load(branchIds: ["ALDI_NORD_NEUHAUS", "ALDI_SUED_SONNEBERG"], chains: ["ALDI Nord", "ALDI SÜD"])

        XCTAssertEqual(Set(store.offers.map(\.market)), ["ALDI Nord", "ALDI SÜD"])
        XCTAssertEqual(Set(store.offers.map(\.product)), ["Ofenkäse", "Rispentomaten"])
    }

    /// Die Ketten-Regel gilt für bundesweite Zeilen weiterhin — sie tragen
    /// eine National-ID, die in keiner Filialwahl vorkommt, und wären mit einem
    /// reinen Filial-Abgleich unsichtbar. Hier gewählt: eine REWE-Filiale und
    /// ALDI SÜD; der Nord-Katalog bleibt trotzdem weg.
    func testTheChainRuleGovernsNationwideRows() async {
        let store = store(mixed)

        await store.load(branchIds: ["1766063", "ALDI_SUED_IRGENDWO"], chains: ["ALDI SÜD", "REWE"])

        XCTAssertEqual(Set(store.offers.map(\.product)), ["Rispentomaten", "Coca-Cola"])
    }

    /// `Offer.id` trennt die FILIALE, nicht die Reichweite. Seit Migration
    /// v16 lautet der Datenbankschlüssel (market_id, product, valid_from) —
    /// dieselbe Filiale kann ein Produkt in einer Woche nicht gleichzeitig
    /// lokal und bundesweit führen, und die Id bildet genau das ab.
    func testTheIdSeparatesBranchesNotReach() {
        let nord = offer(branch: "ALDI_NORD_DE", chain: "ALDI Nord",
                         product: "Ofenkäse", price: 2.22, nationwide: true)
        let sued = offer(branch: "ALDI_SUED_DE", chain: "ALDI SÜD",
                         product: "Ofenkäse", price: 2.22, nationwide: true)

        XCTAssertNotEqual(nord.id, sued.id)
        XCTAssertTrue(nord.isNationwide)
    }

    /// Eine Zeile ohne `region` muss überhaupt erst durch den Decoder kommen —
    /// vorher war das Feld nicht optional und die Zeile fiel still weg.
    func testARowWithoutARegionDecodes() throws {
        let json = """
        {"market_id":"ALDI_NORD_DE","market":"ALDI Nord","product":"Ofenkäse",
         "price":2.22,"regular_price":null,"unit":null,"category":"Molkerei",
         "emoji":"🧀","valid_from":"2026-07-20","valid_until":"2026-07-25",
         "base_price":null,"base_unit":null,"nationwide":true,"image_url":null,
         "match_key":["käse"]}
        """
        let decoded = try JSONDecoder.supabase.decode(Offer.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.nationwide, true)
        XCTAssertTrue(decoded.isNationwide)
        XCTAssertEqual(decoded.marketId, "ALDI_NORD_DE")
    }
}
