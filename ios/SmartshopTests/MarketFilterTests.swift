import XCTest
@testable import Smartshop

final class MarketFilterTests: XCTestCase {
    private func market(_ chain: String, branch: String, plz: String = "01219") -> Market {
        Market(chain: chain, branchName: branch, marketId: "\(chain)_\(branch)", plz: plz)
    }

    private var branches: [Market] {
        [
            market("Netto", branch: "JPT-Straße"),
            market("Kaufland", branch: "Strehlen"),
            market("REWE", branch: "Postplatz", plz: "01067"),
            market("Lidl", branch: "Strehlener Platz"),
        ]
    }

    func testEmptyQueryKeepsEverything() {
        XCTAssertEqual(MarketFilter.filter(branches, query: "  ").count, 4)
    }

    func testMatchesBranchNameCaseInsensitive() {
        let hits = MarketFilter.filter(branches, query: "jpt")
        XCTAssertEqual(hits.map(\.branchName), ["JPT-Straße"])
    }

    func testMatchesChain() {
        XCTAssertEqual(MarketFilter.filter(branches, query: "rewe").map(\.branchName), ["Postplatz"])
    }

    func testMatchesPLZ() {
        XCTAssertEqual(MarketFilter.filter(branches, query: "01067").map(\.chain), ["REWE"])
    }

    func testDiacriticInsensitive() {
        // "strasse" should find "Straße", "strehlen" both Strehlen branches.
        XCTAssertEqual(MarketFilter.filter(branches, query: "strasse").map(\.branchName), ["JPT-Straße"])
        XCTAssertEqual(MarketFilter.filter(branches, query: "Strehlen").count, 2)
    }

    func testNoMatch() {
        XCTAssertTrue(MarketFilter.filter(branches, query: "Edeka").isEmpty)
    }

    /// Guards the app layer against accidental dedupe: two branches of the
    /// same chain in the same PLZ must both survive filtering and stay
    /// distinguishable. (That only one arrives today is a backend limitation:
    /// the scrapers' find_market returns a single nearest branch per chain.)
    func testTwoBranchesOfSameChainInSamePLZBothKept() {
        let nettos = [
            market("Netto", branch: "Johannes-Paul-Thilman-Straße"),
            market("Netto", branch: "Strehlener Platz"),
        ]
        let hits = MarketFilter.filter(nettos, query: "netto")
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(Set(hits.map(\.id)).count, 2, "branches must keep distinct ids")
        XCTAssertEqual(MarketFilter.filter(nettos, query: "thilman").count, 1)
    }

    func testKonsumIsListedAsChainWithoutData() {
        XCTAssertTrue(MarketFilter.chainsWithoutData.contains("Konsum"))
    }
}
