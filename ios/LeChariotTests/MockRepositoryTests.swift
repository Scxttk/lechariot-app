import XCTest
@testable import LeChariot

final class MockRepositoryTests: XCTestCase {
    /// **Die Fixtures müssen in derselben Zeitzone rechnen wie die Abfrage.**
    ///
    /// `MockFixtures.weekStart` sagt, ab wann ein Fixture-Angebot gilt;
    /// `OfferQuery.current` entscheidet, was „heute" ist — und zwar fest in
    /// Europe/Berlin, weil Angebotsdaten Berliner Mitternachte sind. Rechnete
    /// eine der beiden Seiten in der Zone des Geräts, fielen sie überall
    /// auseinander, wo die Uhr nicht deutsch geht.
    ///
    /// Genau das war bis zum 10.08. der Fall, und niemand hat es gemerkt: Auf
    /// Scotts Mac fallen beide auf denselben Augenblick. Auf einem
    /// GitHub-Runner (UTC) liegt `weekStart` zwei Stunden dahinter, kein
    /// einziges Angebot gilt, und die App zeigt „NOCH KEIN TREFFER" — alle drei
    /// Tests von `OfferHitsJourneyTests` fielen dort an derselben Zeile.
    ///
    /// Dieser Test kostet nichts und fängt den Rückfall. Er ist die billigste
    /// Stelle dafür: Er braucht keinen Simulator und läuft in jedem Unit-Lauf
    /// mit.
    func testTheFixtureOffersAreValidTodayWhereverTheClockStands() {
        XCTAssertFalse(
            OfferQuery.current(MockFixtures.offers).isEmpty,
            "Kein einziges Fixture-Angebot gilt heute. Fast immer heisst das: "
            + "`MockFixtures.weekStart` rechnet wieder in der Zeitzone des "
            + "Geräts statt in `Calendar.supabase`."
        )
    }

    func testMockOfferRepositoryFiltersByBranch() async throws {
        let repository = MockOfferRepository()

        // Beide Wochen: Das Repository ist die Abfrage, und die kennt keine
        // Datumsgrenze. Getrennt wird erst im `OfferStore`.
        let both = try await repository.offers(branchIds: ["lidl-01219-1", "aldi-01219-1"])
        XCTAssertEqual(both.count, MockFixtures.offers.count + MockFixtures.nextWeekOffers.count)

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

    /// **Die Anforderungs-Mocks müssen gleichzeitige Aufrufe aushalten** —
    /// beim App-Start laufen `checkPendingBranches`/`checkPendingArea`
    /// doppelt (das `.task` und der `scenePhase`-Wechsel), und genau dieses
    /// Nebeneinander hat den Simulator etwa jeden dreißigsten Start mit
    /// `EXC_BAD_ACCESS` in `Array.append` umgebracht (.ips-Berichte vom
    /// 03.–06.08., identischer Stack). In den Journeys sah das aus wie „die
    /// App startet nicht", und der Verdacht wanderte reihum.
    ///
    /// Ohne das Schloss in den Mocks fällt dieser Test um oder zählt falsch;
    /// mit ihm ist die Zahl exakt.
    func testTheRequestMocksSurviveConcurrentCalls() async throws {
        let branches = MockBranchRequestRepository()
        let areas = MockAreaRequestRepository()
        let rounds = 500

        await withTaskGroup(of: Void.self) { group in
            for lauf in 0..<2 {
                group.addTask {
                    for i in 0..<rounds {
                        try? await branches.requestBranch(marketId: "markt-\(lauf)-\(i)")
                        _ = try? await branches.request(marketId: "markt-\(lauf)-\(i)")
                        try? await areas.requestArea(
                            marketId: "gebiet-\(lauf)-\(i)", lat: 51.0, lon: 13.7
                        )
                    }
                }
            }
        }

        XCTAssertEqual(branches.requested.count, 2 * rounds)
        XCTAssertEqual(areas.requested.count, 2 * rounds)
    }

}
