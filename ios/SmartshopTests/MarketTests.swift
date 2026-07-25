import XCTest
@testable import Smartshop

final class MarketTests: XCTestCase {
    private func market(id: String) -> Market {
        Market(chain: "Lidl", branchName: "Lidl Deutschland", marketId: id, plz: "01219")
    }

    func testNationalPlaceholderIdsAreNationwide() {
        XCTAssertTrue(market(id: "LIDL_DE").isNationwide)
        XCTAssertTrue(market(id: "ALDI_NORD_DE").isNationwide)
        XCTAssertTrue(market(id: "ALDI_SUED_DE").isNationwide)
    }

    func testRealBranchIdsAreNotNationwide() {
        XCTAssertFalse(market(id: "lidl-01219-1").isNationwide)
        XCTAssertFalse(market(id: "aldi-01219-1").isNationwide)
        // Suffix must match exactly at the end of the id.
        XCTAssertFalse(market(id: "LIDL_DE_01219").isNationwide)
        XCTAssertFalse(market(id: "").isNationwide)
    }

    // MARK: Display title

    private func branch(_ chain: String, _ name: String, plz: String = "01219") -> Market {
        Market(chain: chain, branchName: name, marketId: "\(chain)-\(name)", plz: plz)
    }

    func testDisplayTitleNamesTheBranchWhenItIsTheOnlyOne() {
        let favorites = [branch("Lidl", "Dresden Reick"), branch("Kaufland", "Strehlen")]

        XCTAssertEqual(
            Market.displayTitle(chain: "Lidl", favorites: favorites),
            "Lidl – Dresden Reick"
        )
    }

    /// The backend's branch names usually start with the chain
    /// ("Kaufland Dresden-Strehlen, O.D.C.") — prefixing it again stutters.
    func testDisplayTitleDoesNotRepeatTheChainTheBranchAlreadyNames() {
        let favorites = [branch("Kaufland", "Kaufland Dresden-Strehlen, O.D.C.")]

        XCTAssertEqual(
            Market.displayTitle(chain: "Kaufland", favorites: favorites),
            "Kaufland Dresden-Strehlen, O.D.C."
        )
    }

    /// Naming one of two favorited branches would be a guess.
    func testDisplayTitleStaysAtTheChainWhenSeveralBranchesAreFavorited() {
        let favorites = [branch("Lidl", "Dresden Reick"), branch("Lidl", "Dresden Gorbitz")]

        XCTAssertEqual(Market.displayTitle(chain: "Lidl", favorites: favorites), "Lidl")
    }

    func testDisplayTitleStaysAtTheChainWithoutAUsableBranchName() {
        XCTAssertEqual(Market.displayTitle(chain: "Lidl", favorites: []), "Lidl")
        XCTAssertEqual(
            Market.displayTitle(chain: "Lidl", favorites: [branch("Lidl", "")]),
            "Lidl"
        )
    }
}
