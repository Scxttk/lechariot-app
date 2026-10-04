import XCTest
@testable import LeChariot

/// **Sonntags rechnet die Einkaufsliste mit Montag.** Gemessen am Sonntag,
/// 04.10.2026, 22:14, für drei Filialen (ALDI Nord, Lidl, Penny): Die
/// Plan-Karte zeigte „Noch kein Treffer", weil **keine** Zeile am Sonntag galt,
/// aber 603 ab Montag — gerade dann, wenn die Woche geplant wird.
///
/// Alle Zusicherungen rechnen mit einem gesetzten „jetzt" — siehe
/// `SundayOfferWindowTests`.
@MainActor
final class SundayListWeekTests: XCTestCase {
    private struct StubRepository: OfferRepositoryProtocol {
        var rows: [Offer]
        func offers(branchIds: [String]) async throws -> [Offer] { rows }
    }

    private let montag = MockFixtures.day.date(from: "2026-10-05")!

    private func berlin(_ day: String, _ hour: Int, _ minute: Int) -> Date {
        let start = MockFixtures.day.date(from: day)!
        return Calendar.supabase.date(byAdding: DateComponents(hour: hour, minute: minute), to: start)!
    }

    private func offer(
        _ product: String, _ chain: String, _ marketId: String,
        price: Double, from: String, until: String
    ) -> Offer {
        Offer(
            marketId: marketId, market: chain, product: product, price: price,
            regularPrice: nil, unit: nil, category: "Molkerei & Eier", emoji: nil,
            validFrom: MockFixtures.day.date(from: from)!,
            validUntil: MockFixtures.day.date(from: until)!,
            basePrice: nil, baseUnit: nil, nationwide: false
        )
    }

    /// Die Lage vom 04.10. in klein: Lidls alte Woche endete Samstag, Pennys
    /// läuft bis Sonntag, beide haben ab Montag die neue.
    private var rows: [Offer] {
        [
            offer("Butter Markenqualität", "Lidl", "lidl-1", price: 2.19, from: "2026-09-28", until: "2026-10-03"),
            offer("Butter Markenqualität", "Lidl", "lidl-1", price: 1.79, from: "2026-10-05", until: "2026-10-10"),
            offer("Frische Milch", "Penny", "penny-1", price: 1.09, from: "2026-09-28", until: "2026-10-04"),
            offer("Frische Milch", "Penny", "penny-1", price: 0.99, from: "2026-10-05", until: "2026-10-11"),
        ]
    }

    private func loadedStore(at now: Date, rows: [Offer]) async throws -> OfferStore {
        let suite = UserDefaults(suiteName: "sunday-list-\(UUID().uuidString)")!
        let store = OfferStore(
            repository: StubRepository(rows: rows),
            cache: try OfferCache(inMemory: true, defaults: suite),
            clock: { now }
        )
        await store.load(branchIds: ["lidl-1", "penny-1"], chains: [])
        return store
    }

    // MARK: Der Tag

    func testOnSundayTheListDayIsMonday() {
        XCTAssertEqual(OfferQuery.listDay(now: berlin("2026-10-04", 22, 14)), montag)
        XCTAssertEqual(OfferQuery.listDay(now: berlin("2026-10-04", 0, 5)), montag,
                       "Der ganze Sonntag, nicht erst der Abend")
    }

    /// Samstagabend bleibt Samstag: Die Läden haben bis 20 oder 22 Uhr offen,
    /// und die Samstagszeilen gelten bis Mitternacht.
    func testSaturdayEveningAndMondayStayToday() {
        let samstagAbend = berlin("2026-10-03", 23, 30)
        XCTAssertEqual(OfferQuery.listDay(now: samstagAbend),
                       Calendar.supabase.startOfDay(for: samstagAbend))
        XCTAssertEqual(OfferQuery.listDay(now: berlin("2026-10-05", 0, 5)), montag)
    }

    // MARK: Der Store

    func testOnSundayTheListComparesMondaysOffers() async throws {
        let store = try await loadedStore(at: berlin("2026-10-04", 22, 14), rows: rows)

        XCTAssertEqual(store.listWeekStart, montag)
        XCTAssertEqual(Set(store.listOffers.map(\.validFrom)), [montag],
                       "Pennys Sonntagszeile weicht der Montagszeile — eine Woche, nicht zwei gemischt")
        XCTAssertEqual(store.listOffers.compactMap(\.price).sorted(), [0.99, 1.79])

        XCTAssertEqual(store.offers.map(\.market), ["Penny"],
                       "Der Angebote-Tab zeigt weiter, was heute gilt")
    }

    func testTheListCardFindsTheWeekOnSunday() async throws {
        let store = try await loadedStore(at: berlin("2026-10-04", 22, 14), rows: rows)
        let liste = ["Milch", "Butter"].map { ShoppingItem(text: $0) }

        let ranks = ShoppingListRanking.rank(
            items: liste, offers: store.listOffers, chains: ["Lidl", "Penny"]
        )

        XCTAssertEqual(ranks.first.map { ShoppingPlanCard.caption($0, weekStart: store.listWeekStart) },
                       "Ab Montag am besten zu")
        XCTAssertEqual(ranks.map(\.matchedCount), [1, 1])
    }

    func testOnSaturdayEveningTheListKeepsSaturdaysOffers() async throws {
        let store = try await loadedStore(at: berlin("2026-10-03", 23, 30), rows: rows)

        XCTAssertNil(store.listWeekStart)
        XCTAssertEqual(store.listOffers.compactMap(\.price).sorted(), [1.09, 2.19])
        XCTAssertEqual(store.listOffers.map(\.id), store.offers.map(\.id))
    }

    /// Ohne eine einzige Zeile für Montag gibt es nichts, womit gerechnet
    /// werden könnte — dann bleibt es bei dem, was heute gilt.
    func testWithoutMondayRowsSundayKeepsToday() async throws {
        let nurDieseWoche = rows.filter { $0.validFrom < montag }
        let store = try await loadedStore(at: berlin("2026-10-04", 22, 14), rows: nurDieseWoche)

        XCTAssertNil(store.listWeekStart)
        XCTAssertEqual(store.listOffers.map(\.market), ["Penny"])
    }

    // MARK: Die Karte

    func testTheCardSaysMondayOnlyWhenItCountsMonday() {
        let treffer = MarketListRank(
            chain: "Lidl",
            matchedItems: [RankedItemMatch(item: "Butter", match: OfferMatch(offer: rows[1], kind: .direct))],
            missingItems: ["Milch"], total: 1.79
        )
        let leer = MarketListRank(chain: "Lidl", matchedItems: [], missingItems: ["Milch"], total: nil)

        XCTAssertEqual(ShoppingPlanCard.caption(treffer, weekStart: nil), "Am besten zu")
        XCTAssertEqual(ShoppingPlanCard.caption(treffer, weekStart: montag), "Ab Montag am besten zu")
        XCTAssertEqual(ShoppingPlanCard.caption(leer, weekStart: montag), "Noch kein Treffer")

        XCTAssertEqual(ShoppingPlanCard.coverageText(leer, weekStart: nil),
                       "Für deine Liste gibt es diese Woche keine Angebote in deinen Filialen.")
        XCTAssertEqual(ShoppingPlanCard.coverageText(leer, weekStart: montag),
                       "Für deine Liste gibt es ab Montag keine Angebote in deinen Filialen.")
        XCTAssertTrue(ShoppingPlanCard.headlineSummary(treffer, weekStart: montag)
            .hasPrefix("Ab Montag am besten zu Lidl"))
    }
}
