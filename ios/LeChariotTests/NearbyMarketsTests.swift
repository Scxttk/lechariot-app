import XCTest
@testable import LeChariot

/// Der Ketten-Schritt und sein Belohnungsschritt hängen an einer Zusage: **Das
/// Netz blockiert das Onboarding nie.** Genau die wird hier geprüft — mit
/// eingesetzten Verzeichnissen statt echter Server, denn ein Test, der am Netz
/// hängt, prüft die Leitung und nicht die Regel.
final class NearbyMarketsTests: XCTestCase {
    /// Der feste Punkt der Fixtures — Dresden, wie in `MockFixtures.dresden`.
    /// Eingesetzt statt über `defaultLocate`, damit der Test nicht davon
    /// abhängt, ob auf der Maschine eine `APIKeys.plist` liegt.
    private let dresden: @Sendable (String) async throws -> (lat: Double, lon: Double) = { _ in
        (lat: 51.0504, lon: 13.7317)
    }

    // MARK: Reine Teile

    func testChainsAreDedupedAndSorted() {
        let branches = [
            branch(chain: "REWE"), branch(chain: "Lidl"),
            branch(chain: "REWE"), branch(chain: "Aldi"),
        ]
        XCTAssertEqual(NearbyMarketsLookup.chains(in: branches), ["Aldi", "Lidl", "REWE"])
    }

    /// Die Rückfalliste ist das, was Offline-Nutzer zu sehen bekommen — neun
    /// Ketten, jede einmal, in den Schreibweisen der `branches`-Tabelle.
    func testTheFallbackListNamesAllNineChainsOnce() {
        let list = NearbyMarketsLookup.allChains
        XCTAssertEqual(list.count, 9)
        XCTAssertEqual(Set(list).count, 9, "keine Kette doppelt")
        for expected in ["EDEKA", "Kaufland", "Penny", "NORMA", "ALDI Nord", "ALDI SÜD"] {
            XCTAssertTrue(list.contains(expected), "\(expected) fehlt in der Rückfalliste")
        }
    }

    // MARK: Antwortet das Verzeichnis, kommen echte Zahlen

    func testAFastDirectoryDeliversChainsAndBranchCount() async {
        let found = await NearbyMarketsLookup.nearby(
            plz: "01219", repository: MockBranchRepository(), locate: dresden
        )
        // Die Dresdner Fixtures: Lidl, Aldi, Netto und zwei REWE in Reichweite.
        XCTAssertEqual(found?.chains, ["Aldi", "Lidl", "Netto", "REWE"])
        XCTAssertEqual(found?.branchCount, 5)
    }

    // MARK: Antwortet es nicht, wartet niemand

    func testASlowDirectoryRunsIntoTheTimeoutInsteadOfBlocking() async {
        let start = Date()
        let found = await NearbyMarketsLookup.nearby(
            plz: "01219", repository: SlowBranchRepository(), locate: dresden, timeout: 0.2
        )
        XCTAssertNil(found, "eine Antwort nach der Uhr ist keine Antwort")
        XCTAssertLessThan(Date().timeIntervalSince(start), 2,
                          "der Schritt darf nicht auf das lahme Verzeichnis warten")
    }

    func testAFailingDirectoryReturnsNilInsteadOfThrowing() async {
        let found = await NearbyMarketsLookup.nearby(
            plz: "01219", repository: FailingBranchRepository(), locate: dresden
        )
        XCTAssertNil(found, "offline heißt Rückfalliste, nicht Fehlerbildschirm")
    }

    // MARK: Die Sätze des Belohnungsschritts

    func testThePayoffHeadlineHandlesSingularAndPlural() {
        XCTAssertEqual(PayoffCopy.headline(chains: 9, branches: 34),
                       "9 Ketten, 34 Filialen in deiner Nähe.")
        XCTAssertEqual(PayoffCopy.headline(chains: 1, branches: 1),
                       "1 Kette, 1 Filiale in deiner Nähe.")
        XCTAssertEqual(PayoffCopy.likedLine(count: 1), "1 Kette hast du dir gemerkt.")
        XCTAssertEqual(PayoffCopy.likedLine(count: 3), "3 Ketten hast du dir gemerkt.")
    }

    // MARK: Helfer

    private func branch(chain: String) -> Branch {
        Branch(marketId: UUID().uuidString, chain: chain, name: "\(chain) Test",
               street: nil, plz: nil, city: nil, lat: 51.05, lon: 13.73)
    }
}

/// Ein Verzeichnis, das nie rechtzeitig antwortet.
private struct SlowBranchRepository: BranchRepositoryProtocol {
    func nearby(lat: Double, lon: Double, radiusKm: Double) async throws -> [Branch] {
        try await Task.sleep(nanoseconds: 5_000_000_000)
        return []
    }

    func branch(marketId: String) async throws -> Branch? { nil }
}

/// Ein Verzeichnis ohne Leitung.
private struct FailingBranchRepository: BranchRepositoryProtocol {
    func nearby(lat: Double, lon: Double, radiusKm: Double) async throws -> [Branch] {
        throw URLError(.notConnectedToInternet)
    }

    func branch(marketId: String) async throws -> Branch? { nil }
}
