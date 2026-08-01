import XCTest
@testable import LeChariot

final class MockRepositoryTests: XCTestCase {
    func testMockOfferRepositoryFiltersByBranch() async throws {
        let repository = MockOfferRepository()

        let both = try await repository.offers(branchIds: ["lidl-01219-1", "aldi-01219-1"])
        XCTAssertEqual(both.count, MockFixtures.offers.count)

        // Eine Filiale liefert nur ihre eigenen Angebote — das ist der ganze
        // Unterschied zur PLZ-Abfrage, die immer alle Läden der Gegend brachte.
        // Die Menge der Ketten, nicht die Liste der Zeilen: Seit die Fixtures
        // eine zweite Lidl-Zeile tragen (die teurere Milch, an der sich das
        // Anheften überhaupt zeigen lässt), sagt `["Lidl"]` als Array nur noch,
        // wie viele Angebote zufällig drinstehen — geprüft werden soll aber,
        // dass **keine fremde Kette** durchkommt.
        let onlyLidl = try await repository.offers(branchIds: ["lidl-01219-1"])
        XCTAssertFalse(onlyLidl.isEmpty)
        XCTAssertEqual(Set(onlyLidl.map(\.market)), ["Lidl"])

        let empty = try await repository.offers(branchIds: ["gibt-es-nicht"])
        XCTAssertTrue(empty.isEmpty)
    }

}
