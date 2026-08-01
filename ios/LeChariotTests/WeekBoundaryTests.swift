import XCTest
@testable import LeChariot

/// Die Grenze zwischen der laufenden Woche und allem, was später beginnt.
///
/// **Das hier sind Regressionstests, keine Funktionstests.** Bis zum
/// 01.08.2026 gab es diese Grenze nicht: `LiveOfferRepository` holt `select=*`
/// ohne Datumsbedingung, und in `display()` stand kein Filter. Gegen die
/// Produktion nachgestellt standen so **448 von 1 125** Zeilen einer
/// Penny-Filiale mit einem Preis der Folgewoche in der laufenden Liste — und
/// damit auch in der Marktrangfolge und in der Summe der Plan-Karte.
/// Zahlen in [[Le Chariot Backlog]], „Das Leck".
@MainActor
final class WeekBoundaryTests: XCTestCase {
    private struct StubRepository: OfferRepositoryProtocol {
        var rows: [Offer]
        func offers(branchIds: [String]) async throws -> [Offer] { rows }
    }

    /// Fester Stichtag: Samstag, 01.08.2026 — der Tag, an dem gemessen wurde,
    /// und der letzte Tag des laufenden Prospekts.
    private let heute = MockFixtures.day.date(from: "2026-08-01")!

    private func makeStore(_ rows: [Offer]) throws -> OfferStore {
        OfferStore(
            repository: StubRepository(rows: rows),
            cache: try makeCache(),
            clock: { self.heute }
        )
    }

    private func makeCache() throws -> OfferCache {
        let suite = UserDefaults(suiteName: "nextweek-\(UUID().uuidString)")!
        return try OfferCache(inMemory: true, defaults: suite)
    }

    private func offer(
        product: String,
        market: String = "Penny",
        price: Double? = 1.99,
        from: String,
        until: String
    ) -> Offer {
        Offer(
            marketId: "4030829", market: market, product: product, price: price,
            regularPrice: nil, unit: nil, category: "Sonstiges", emoji: nil,
            validFrom: MockFixtures.day.date(from: from)!,
            validUntil: MockFixtures.day.date(from: until)!,
            basePrice: nil, baseUnit: nil, nationwide: false
        )
    }

    /// Der laufende Prospekt, wie er am 01.08.2026 in der Produktion stand.
    private var laufend: Offer {
        offer(product: "MILBONA Joghurt", from: "2026-07-27", until: "2026-08-01")
    }

    /// Eine echte Zeile aus der Produktion, Filiale 4030829: kein preisgleicher
    /// Zwilling in dieser Woche, also kommt sie am Dedupe vorbei.
    private var kuenftig: Offer {
        offer(product: "AEG Bodenstaubsauger VX4-1-EB*", price: 69.99,
              from: "2026-08-03", until: "2026-08-09")
    }

    // MARK: Das Leck

    /// **Fällt gegen den Stand vor dem 01.08.:** dort enthält `store.offers`
    /// beide Zeilen.
    func testFutureRowsNeverReachTheRunningWeek() async throws {
        let store = try makeStore([laufend, kuenftig])

        await store.load(branchIds: ["4030829"], chains: [])

        XCTAssertEqual(store.offers.map(\.product), ["MILBONA Joghurt"],
                       "Ein Preis der Folgewoche steht in der laufenden Liste")
        XCTAssertEqual(store.upcomingOffers.map(\.product),
                       ["AEG Bodenstaubsauger VX4-1-EB*"])
    }

    /// Abgelaufene Zeilen gehören in keinen der beiden Töpfe. In der Produktion
    /// standen am 01.08. 28 solche Zeilen.
    func testExpiredRowsAppearNowhere() async throws {
        let alt = offer(product: "Altes Angebot", from: "2026-07-20", until: "2026-07-26")
        let store = try makeStore([laufend, alt])

        await store.load(branchIds: ["4030829"], chains: [])

        XCTAssertEqual(store.offers.map(\.product), ["MILBONA Joghurt"])
        XCTAssertTrue(store.upcomingOffers.isEmpty)
    }

    /// Der Dedupe darf die Trennung nicht unterlaufen: Bei gleichem Preis
    /// gewann bisher `preferred()` die laufende Zeile — die künftige verschwand
    /// damit **auch aus der Vorschau**. Beide Töpfe müssen ihre Zeile behalten.
    func testSamePriceInBothWeeksKeepsBothSides() async throws {
        let dieseWoche = offer(product: "Butter", price: 1.99, from: "2026-07-27", until: "2026-08-01")
        let naechste = offer(product: "Butter", price: 1.99, from: "2026-08-03", until: "2026-08-09")
        let store = try makeStore([dieseWoche, naechste])

        await store.load(branchIds: ["4030829"], chains: [])

        XCTAssertEqual(store.offers.count, 1)
        XCTAssertEqual(store.offers.first?.validFrom, dieseWoche.validFrom)
        XCTAssertEqual(store.upcomingOffers.count, 1)
        XCTAssertEqual(store.upcomingOffers.first?.validFrom, naechste.validFrom)
    }

    // MARK: Getrennte Zukunftsfenster

    /// **Dieselbe Regel wie Stufe 2 des Backend-Dedupe** (Backend #32):
    /// Überlappende Fenster gleichen Preises verschmelzen, **disjunkte nicht.**
    /// Lidl listet heute zwei künftige Prospekte; würden sie verschmelzen,
    /// verlöre die Vorschau eine ganze Woche.
    func testDisjointFutureWeeksStaySeparateRows() async throws {
        let woche1 = offer(product: "Kaffee", market: "Lidl", price: 4.99,
                           from: "2026-08-03", until: "2026-08-08")
        let woche2 = offer(product: "Kaffee", market: "Lidl", price: 4.99,
                           from: "2026-08-10", until: "2026-08-15")
        let store = try makeStore([laufend, woche1, woche2])

        await store.load(branchIds: ["4030829"], chains: [])

        XCTAssertEqual(store.upcomingOffers.count, 2,
                       "Zwei disjunkte Zukunftswochen sind zwei Angebote, nicht eins")
        XCTAssertEqual(store.upcomingOffers.map(\.validFrom).sorted(),
                       [woche1.validFrom, woche2.validFrom])
    }

    /// Die Gegenprobe: Innerhalb **einer** Zukunftswoche bleibt der Dedupe
    /// scharf — sonst stünde jede doppelt veröffentlichte Kachel zweimal da.
    func testDuplicatesInsideOneFutureWeekStillCollapse() async throws {
        let a = offer(product: "Kaffee", market: "Lidl", price: 4.99,
                      from: "2026-08-03", until: "2026-08-08")
        let b = offer(product: "Kaffee", market: "Lidl", price: 4.99,
                      from: "2026-08-03", until: "2026-08-08")
        let store = try makeStore([a, b])

        await store.load(branchIds: ["4030829"], chains: [])

        XCTAssertEqual(store.upcomingOffers.count, 1)
    }

}
