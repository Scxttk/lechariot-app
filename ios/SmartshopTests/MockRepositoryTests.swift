import XCTest
@testable import Smartshop

final class MockRepositoryTests: XCTestCase {
    func testMockOfferRepositoryFiltersByRegion() async throws {
        let repository = MockOfferRepository()

        let matching = try await repository.offers(regions: ["01219"])
        XCTAssertEqual(matching.count, MockFixtures.offers.count)
        XCTAssertTrue(matching.allSatisfy { $0.region == "01219" })

        let empty = try await repository.offers(regions: ["10115"])
        XCTAssertTrue(empty.isEmpty)
    }

    func testMockRegionRepositoryLookup() async throws {
        let repository = MockRegionRepository()

        let region = try await repository.region(plz: "01219")
        XCTAssertEqual(region?.plz, "01219")
        XCTAssertEqual(region?.active, true)

        let missing = try await repository.region(plz: "99999")
        XCTAssertNil(missing)
    }
}
