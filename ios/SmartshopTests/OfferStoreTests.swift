import XCTest
@testable import Smartshop

/// Repository stub with switchable result for driving OfferStore states.
private struct StubOfferRepository: OfferRepositoryProtocol {
    var result: Result<[Offer], Error> = .success([])

    func offers(branchIds: [String]) async throws -> [Offer] {
        try result.get()
    }
}

private struct StubError: LocalizedError {
    var errorDescription: String? { "kaputt" }
}

/// Records the query the store composes so tests can assert multi-region calls.
private final class RecordingOfferRepository: OfferRepositoryProtocol {
    var result: [Offer] = []
    private(set) var lastBranchIds: [String]?
    private(set) var callCount = 0

    func offers(branchIds: [String]) async throws -> [Offer] {
        lastBranchIds = branchIds
        callCount += 1
        return result
    }
}

@MainActor
final class OfferStoreTests: XCTestCase {
    /// Eigene Defaults je Test: Der Cache merkt sich dort die Filialwahl, und
    /// `.standard` würde die Tests aneinander koppeln.
    private func makeCache() throws -> OfferCache {
        let suite = UserDefaults(suiteName: "offercache-\(UUID().uuidString)")!
        return try OfferCache(inMemory: true, defaults: suite)
    }

    func testLoadSuccessReachesLoadedAndFillsCache() async throws {
        let cache = try makeCache()
        let store = OfferStore(
            repository: StubOfferRepository(result: .success(MockFixtures.offers)),
            cache: cache
        )

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        XCTAssertEqual(store.state, .loaded)
        XCTAssertEqual(store.offers.count, MockFixtures.offers.count)
        XCTAssertFalse(store.isStale)
        let cached = try cache.load()
        XCTAssertEqual(cached.offers.count, MockFixtures.offers.count)
    }

    func testLoadEmptyResultReachesEmpty() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .success([])),
            cache: try makeCache()
        )

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        XCTAssertEqual(store.state, .empty)
    }

    func testEmptyResultWithFavoriteChainsIsEmptyAfterLoad() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .success([])),
            cache: try makeCache()
        )

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: ["Kaufland"])

        XCTAssertTrue(store.isEmptyAfterLoad)
        XCTAssertTrue(store.hasFavoriteChains)
    }

    func testEmptyResultWithoutFavoriteChainsHasNoFavoriteChains() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .success([])),
            cache: try makeCache()
        )

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        XCTAssertTrue(store.isEmptyAfterLoad)
        XCTAssertFalse(store.hasFavoriteChains)
    }

    func testLoadedResultIsNotEmptyAfterLoad() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .success(MockFixtures.offers)),
            cache: try makeCache()
        )

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        XCTAssertFalse(store.isEmptyAfterLoad)
    }

    func testLoadErrorWithoutCacheReachesError() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: try makeCache()
        )

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        // The message is written for a shopper, so the store must not simply
        // forward whatever the networking layer threw — `SupabaseError` has no
        // localization at all and used to surface as "The operation couldn't be
        // completed. (Smartshop.SupabaseError error 2.)".
        guard case .error(let message) = store.state else {
            return XCTFail("expected an error state, got \(store.state)")
        }
        XCTAssertFalse(message.contains("kaputt"), "internal error text must not reach the screen")
        XCTAssertTrue(message.contains("Angebote"))
    }

    /// A cancelled fetch is routine — `.task(id: regions)` restarts on every
    /// region change and leaving the tab cancels too. It must not be mistaken
    /// for the network being down.
    func testCancellationIsNotTreatedAsAnError() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(CancellationError())),
            cache: try makeCache()
        )

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        XCTAssertFalse(store.isOffline)
        if case .error = store.state {
            XCTFail("a cancelled load must not surface as an error")
        }
    }

    func testLoadErrorWithCacheKeepsCachedDataAndFlagsStale() async throws {
        let cache = try makeCache()
        // Stale timestamp so the store attempts (and fails) a network refresh.
        try cache.replaceAll(
            MockFixtures.offers,
            fetchedAt: .now.addingTimeInterval(-OfferCache.maxAge - 60)
        )
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: cache
        )

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        XCTAssertEqual(store.state, .loaded)
        XCTAssertEqual(store.offers.count, MockFixtures.offers.count)
        XCTAssertTrue(store.isOffline)
        XCTAssertTrue(store.isStale)
    }

    func testCachedOffersAreNarrowedToFavoriteChains() async throws {
        let cache = try makeCache()
        try cache.replaceAll(MockFixtures.offers, fetchedAt: .now)
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: cache
        )

        await store.load(branchIds: ["lidl-01219-1"], chains: ["Lidl"])

        // Gefiltert wird über die FILIALE, nicht über die Kette: Die Fixtures
        // tragen seit Phase 12 ihre market_id, und genau die ist der Filter,
        // der zu dem passt, was im Picker angetippt wurde.
        XCTAssertTrue(store.offers.allSatisfy { $0.market == "Lidl" })
        XCTAssertFalse(store.offers.isEmpty)
    }

    // MARK: Multi-region

    /// Products differ by default: an offer that is identical in everything but
    /// the region is a display duplicate now and gets collapsed — which is what
    /// `testTheSameOfferInTwoRegionsIsShownOnce` is for.
    private func offer(
        region: String,
        market: String = "Lidl",
        product: String = MockFixtures.offers[0].product,
        price: Double? = MockFixtures.offers[0].price,
        from: Date? = nil,
        until: Date? = nil
    ) -> Offer {
        let base = MockFixtures.offers[0]
        return Offer(
            market: market, product: product, price: price,
            regularPrice: base.regularPrice, unit: base.unit,
            category: base.category, emoji: base.emoji,
            validFrom: from ?? base.validFrom, validUntil: until ?? base.validUntil,
            basePrice: base.basePrice, baseUnit: base.baseUnit, region: region
        )
    }

    /// Alle gewählten Filialen in EINER Abfrage — nicht eine pro Filiale.
    func testLoadQueriesAllBranchesInOneCall() async throws {
        let repository = RecordingOfferRepository()
        repository.result = [
            offer(region: "01219", product: "Bio Vollmilch"),
            offer(region: "01067", product: "Butter"),
        ]
        let store = OfferStore(repository: repository, cache: try makeCache())

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: ["Lidl", "Aldi"])

        XCTAssertEqual(repository.lastBranchIds, ["lidl-01219-1", "aldi-01219-1"])
        XCTAssertEqual(repository.callCount, 1)
        XCTAssertEqual(store.offers.count, 2)
    }

    /// Ohne gewählte Filiale gibt es nichts zu fragen — die App darf dann auch
    /// keinen leeren Request abschicken, sondern zeigt ihren Leerzustand.
    func testWithoutBranchesNothingIsFetched() async throws {
        let repository = RecordingOfferRepository()
        let store = OfferStore(repository: repository, cache: try makeCache())

        await store.load(branchIds: [], chains: [])

        XCTAssertEqual(repository.callCount, 0)
        XCTAssertEqual(store.state, .empty)
    }

    /// Eine geänderte Filialwahl macht den Cache unvollständig, auch wenn er
    /// taufrisch ist. Ohne diese Prüfung zeigte ein neu gewählter Laden bis zum
    /// nächsten Kalenderwochenwechsel nichts.
    func testANewBranchSelectionRefetchesEvenWithAFreshCache() async throws {
        let repository = RecordingOfferRepository()
        repository.result = [offer(region: "01219", product: "Bio Vollmilch")]
        let store = OfferStore(repository: repository, cache: try makeCache())

        await store.load(branchIds: ["lidl-01219-1"], chains: [])
        XCTAssertEqual(repository.callCount, 1)

        // Dieselbe Auswahl: der Cache reicht.
        await store.load(branchIds: ["lidl-01219-1"], chains: [])
        XCTAssertEqual(repository.callCount, 1)

        // Eine Filiale dazu: neu holen.
        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])
        XCTAssertEqual(repository.callCount, 2)
    }

    // MARK: Dedupe for display

    /// The week row and the one-day row are one offer on screen — but the cache
    /// is the region's complete KW dataset and keeps both.
    func testDuplicatesAreCollapsedForDisplayWhileTheCacheKeepsRawRows() async throws {
        let cache = try makeCache()
        let day = MockFixtures.day
        let week = offer(
            region: "01219",
            from: day.date(from: "2026-07-13")!, until: day.date(from: "2026-07-19")!
        )
        let knueller = offer(
            region: "01219",
            from: day.date(from: "2026-07-16")!, until: day.date(from: "2026-07-16")!
        )
        let store = OfferStore(
            repository: StubOfferRepository(result: .success([week, knueller])),
            cache: cache
        )

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        XCTAssertEqual(store.offers.count, 1)
        XCTAssertEqual(try cache.load().offers.count, 2)
    }

    func testTheSameOfferInTwoRegionsIsShownOnce() async throws {
        let cache = try makeCache()
        let store = OfferStore(
            repository: StubOfferRepository(
                result: .success([offer(region: "01219"), offer(region: "01067")])
            ),
            cache: cache
        )

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        XCTAssertEqual(store.offers.count, 1)
        // Der Cache behält beide Rohzeilen — Dedupe ist eine Anzeigefrage und
        // wird beim Lesen angewandt, nicht beim Schreiben.
        XCTAssertEqual(try cache.load().offers.count, 2)
    }

    /// The cached path in `load()` must dedupe too — otherwise the duplicates
    /// come back the moment the app opens offline.
    func testOffersServedFromCacheAreDeduplicatedAsWell() async throws {
        let cache = try makeCache()
        let day = MockFixtures.day
        let stale = Date.now.addingTimeInterval(-OfferCache.maxAge - 60)
        try cache.replaceAll(
            [
                offer(region: "01219"),
                offer(
                    region: "01219",
                    from: day.date(from: "2026-07-16")!, until: day.date(from: "2026-07-16")!
                ),
            ], fetchedAt: stale
        )
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: cache
        )

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        XCTAssertEqual(store.offers.count, 1)
        XCTAssertTrue(store.isOffline)
    }

    /// Der Refresh ersetzt den ganzen Cache. Eine alte Zeile, die der neue Lauf
    /// nicht mehr liefert, muss verschwinden — sonst zeigt die App einen Laden,
    /// den der Nutzer längst abgewählt hat.
    func testRefreshReplacesTheWholeCache() async throws {
        let cache = try makeCache()
        try cache.replaceAll([offer(region: "01067", product: "Alte Ware")], fetchedAt: .now)
        let repository = RecordingOfferRepository()
        repository.result = [offer(region: "01219", product: "Neue Ware")]
        let store = OfferStore(repository: repository, cache: cache)

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        XCTAssertEqual(try cache.load().offers.map(\.product), ["Neue Ware"])
    }

    func testCachedOffersOfAllBranchesAreServedWhenOffline() async throws {
        let cache = try makeCache()
        let stale = Date.now.addingTimeInterval(-OfferCache.maxAge - 60)
        try cache.replaceAll(
            [
                offer(region: "01219", product: "Bio Vollmilch"),
                offer(region: "01067", product: "Butter"),
            ],
            fetchedAt: stale
        )
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: cache
        )

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        XCTAssertEqual(store.state, .loaded)
        XCTAssertEqual(Set(store.offers.map(\.product)), ["Bio Vollmilch", "Butter"])
        XCTAssertTrue(store.isOffline)
    }

    // MARK: KW-Cache

    func testFreshCompleteCacheSkipsNetworkRefresh() async throws {
        let cache = try makeCache()
        try cache.replaceAll(
            MockFixtures.offers, branchIds: ["lidl-01219-1", "aldi-01219-1"], fetchedAt: .now
        )
        let repository = RecordingOfferRepository()
        let store = OfferStore(repository: repository, cache: cache)

        await store.load(branchIds: ["lidl-01219-1", "aldi-01219-1"], chains: [])

        XCTAssertEqual(repository.callCount, 0)
        XCTAssertEqual(store.state, .loaded)
        XCTAssertFalse(store.isStale)
    }

    func testMatchKeySurvivesCacheRoundTrip() async throws {
        let cache = try makeCache()
        var tagged = MockFixtures.offers[0]
        tagged.matchKey = ["milch"]
        try cache.replaceAll([tagged], fetchedAt: .now)

        let cached = try cache.load()

        XCTAssertEqual(cached.offers.first?.matchKeys, ["milch"])
    }
}
