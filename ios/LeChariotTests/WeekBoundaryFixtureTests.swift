import XCTest
@testable import LeChariot

/// Dieselbe Grenze, aber gegen **echte Produktionszeilen** statt gegen erfundene.
///
/// `Fixtures/penny-4030829-2026-08-01.json` ist ein wörtlicher Auszug der
/// Antwort, die `LiveOfferRepository` am 01.08.2026 für die Penny-Filiale
/// 4030829 bekommen hat (dieselbe `or=(market_id.eq…,nationwide.is.true)`-
/// Abfrage): **alle 454 Zukunftszeilen** und jede vierte laufende, 624
/// insgesamt. Die 454 sind 279 Zeilen der Filiale plus NORMAs 175 bundesweite,
/// die zu jeder Auswahl dazukommen.
///
/// Erfundene Daten hätten diesen Fehler nicht gefunden — er lebt davon, dass
/// die Zukunftszeilen in der Produktion **keinen preisgleichen Zwilling** in
/// der laufenden Woche haben und damit am Dedupe vorbeikommen.
@MainActor
final class WeekBoundaryFixtureTests: XCTestCase {
    private struct FixtureRepository: OfferRepositoryProtocol {
        let rows: [Offer]
        func offers(branchIds: [String]) async throws -> [Offer] { rows }
    }

    /// Der Tag, an dem der Auszug gezogen wurde.
    private let stichtag = MockFixtures.day.date(from: "2026-08-01")!

    private func productionRows() throws -> [Offer] {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "penny-4030829-2026-08-01", withExtension: "json"
            ),
            "Fixture fehlt im Testbündel"
        )
        return try JSONDecoder.supabase.decode([Offer].self, from: Data(contentsOf: url))
    }

    private func loadedStore() async throws -> OfferStore {
        let suite = UserDefaults(suiteName: "fixture-\(UUID().uuidString)")!
        let store = OfferStore(
            repository: FixtureRepository(rows: try productionRows()),
            cache: try OfferCache(inMemory: true, defaults: suite),
            clock: { self.stichtag }
        )
        await store.load(branchIds: ["4030829"], chains: [])
        return store
    }

    /// Die Zahlen des Auszugs — fällt, sobald sich der Auszug ändert, ohne
    /// dass jemand die Erwartung mitzieht.
    func testFixtureHoldsWhatItClaims() throws {
        let rows = try productionRows()
        XCTAssertEqual(rows.count, 624)
        XCTAssertEqual(rows.filter { $0.validFrom > stichtag }.count, 454)
    }

    /// **Der Fund vom 01.08., in einer Zeile:** keine einzige Zukunftszeile
    /// darf in der laufenden Liste stehen. Vor dem Fix standen dort **452** der
    /// 454 (eine echte Dublette, eine mit preisgleichem laufenden Zwilling);
    /// gegen den *vollen* Zeilensatz derselben Filiale waren es 448 von 1 125.
    func testNoProductionFutureRowReachesTheRunningList() async throws {
        let store = try await loadedStore()

        let leaked = store.offers.filter { $0.validFrom > stichtag }
        XCTAssertTrue(
            leaked.isEmpty,
            "\(leaked.count) Zeile(n) der Folgewoche in der laufenden Liste, z. B. "
                + (leaked.first.map { "\($0.market) · \($0.product) ab \($0.validFrom)" } ?? "—")
        )
        XCTAssertFalse(store.offers.isEmpty, "Die laufende Woche darf nicht leer werden")
    }

    /// Und die Gegenrichtung: `upcomingOffers` bekommt sie alle, aus beiden Ketten.
    func testTheyLandInUpcomingOffersInstead() async throws {
        let store = try await loadedStore()

        XCTAssertTrue(store.upcomingOffers.allSatisfy { $0.validFrom > stichtag })
        XCTAssertEqual(Set(store.upcomingOffers.map(\.market)), ["Penny", "NORMA"])
        // 454 roh minus **eine** echte Dublette („Ritter Sport Bunte Vielfalt*",
        // zweimal ab 03.08. zum selben Preis). Mehr fängt der Dedupe hier nicht,
        // und das ist der Befund: Die Zukunftszeilen haben fast nie einen
        // Zwilling, an dem sie hängenbleiben könnten.
        XCTAssertEqual(store.upcomingOffers.count, 453)
    }

    /// Der teuerste Einzelfall aus der Messung: Ohne laufendes Gegenstück kommt
    /// diese Zeile am Dedupe vorbei — sie ist der Beweis, dass `preferred()`
    /// den Fehler strukturell nicht fangen konnte. Von 454 Zukunftszeilen des
    /// Auszugs hat **eine** einen preisgleichen Zwilling.
    func testTheVacuumCleanerIsInUpcomingOffersAndNowhereElse() async throws {
        let store = try await loadedStore()
        let name = "AEG Bodenstaubsauger VX4-1-EB*"

        XCTAssertFalse(store.offers.contains { $0.product == name })
        XCTAssertTrue(store.upcomingOffers.contains { $0.product == name })
    }
}
