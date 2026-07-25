import XCTest
@testable import Smartshop

final class MockRepositoryTests: XCTestCase {
    func testMockOfferRepositoryFiltersByBranch() async throws {
        let repository = MockOfferRepository()

        let both = try await repository.offers(branchIds: ["lidl-01219-1", "aldi-01219-1"])
        XCTAssertEqual(both.count, MockFixtures.offers.count)

        // Eine Filiale liefert nur ihre eigenen Angebote — das ist der ganze
        // Unterschied zur PLZ-Abfrage, die immer alle Läden der Gegend brachte.
        let onlyLidl = try await repository.offers(branchIds: ["lidl-01219-1"])
        XCTAssertEqual(onlyLidl.map(\.market), ["Lidl"])

        let empty = try await repository.offers(branchIds: ["gibt-es-nicht"])
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
