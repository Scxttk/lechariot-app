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
}
