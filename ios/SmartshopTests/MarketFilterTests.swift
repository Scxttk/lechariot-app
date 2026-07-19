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

    func testKonsumIsListedAsChainWithoutData() {
        XCTAssertTrue(MarketFilter.chainsWithoutData.contains("Konsum"))
    }
}
