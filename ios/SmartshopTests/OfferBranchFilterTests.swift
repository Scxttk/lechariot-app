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
    func offers(regions: [String]) async throws -> [Offer] { result }
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
        region: String = "01067"
    ) -> Offer {
        Offer(
            marketId: branch, market: chain, product: product, price: price,
            regularPrice: nil, unit: nil, category: "Getränke", emoji: "🥤",
            validFrom: day, validUntil: until, basePrice: nil, baseUnit: nil,
            region: region
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

        await store.load(regions: ["01067"], chains: ["REWE"], branchIds: ["1766063"])

        XCTAssertEqual(store.offers.map(\.product), ["Coca-Cola"])
        XCTAssertEqual(store.offers.first?.price, 0.75, "Der Preis der GEWÄHLTEN Filiale")
    }

    func testTwoChosenBranchesShowBothFlyers() async {
        let store = store(koeln1067)

        await store.load(
            regions: ["01067"], chains: ["REWE"], branchIds: ["1766063", "1766160"]
        )

        // Beide Cola-Zeilen überleben: verschiedene Preise sind verschiedene
        // Angebote, das entscheidet der Dedupe-Schlüssel über die Cents.
        XCTAssertEqual(Set(store.offers.map(\.price)), [0.75, 1.49, 12.99])
    }

    /// Without branch ids the old chain rule has to survive untouched —
    /// installs whose favourites predate the branch key rely on it.
    func testWithoutBranchIdsTheChainFilterStillApplies() async {
        var offers = koeln1067
        offers.append(offer(branch: "4816", chain: "Netto", product: "Butter", price: 1.99))
        let store = store(offers)

        await store.load(regions: ["01067"], chains: ["Netto"], branchIds: [])

        XCTAssertEqual(store.offers.map(\.product), ["Butter"])
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

        await store.load(regions: ["01067"], chains: ["REWE"], branchIds: ["1766063"])

        XCTAssertEqual(store.offers.map(\.product), ["Coca-Cola"])
    }

    func testMixedDatasetKeepsBothHalves() async {
        // Mid-migration: one branch-keyed row, one legacy row of another chain.
        let mixed = [
            offer(branch: "1766063", product: "Coca-Cola", price: 0.75),
            offer(branch: nil, chain: "Netto", product: "Butter", price: 1.99),
        ]
        let store = store(mixed)

        await store.load(
            regions: ["01067"], chains: ["REWE", "Netto"], branchIds: ["1766063"]
        )

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
         "region":"01067"}
        """.data(using: .utf8)!
        let offer = try JSONDecoder.supabase.decode(Offer.self, from: json)
        XCTAssertEqual(offer.marketId, "1766063")
    }
}
