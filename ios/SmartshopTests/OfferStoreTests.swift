import XCTest
@testable import Smartshop

/// Repository stub with switchable result for driving OfferStore states.
private struct StubOfferRepository: OfferRepositoryProtocol {
    var result: Result<[Offer], Error> = .success([])

    func offers(regions: [String]) async throws -> [Offer] {
        try result.get()
    }
}

private struct StubError: LocalizedError {
    var errorDescription: String? { "kaputt" }
}

/// Records the query the store composes so tests can assert multi-region calls.
private final class RecordingOfferRepository: OfferRepositoryProtocol {
    var result: [Offer] = []
    private(set) var lastRegions: [String]?
    private(set) var callCount = 0

    func offers(regions: [String]) async throws -> [Offer] {
        lastRegions = regions
        callCount += 1
        return result
    }
}

@MainActor
final class OfferStoreTests: XCTestCase {
    private func makeCache() throws -> OfferCache {
        try OfferCache(inMemory: true)
    }

    func testLoadSuccessReachesLoadedAndFillsCache() async throws {
        let cache = try makeCache()
        let store = OfferStore(
            repository: StubOfferRepository(result: .success(MockFixtures.offers)),
            cache: cache
        )

        await store.load(regions: ["01219"], chains: [])

        XCTAssertEqual(store.state, .loaded)
        XCTAssertEqual(store.offers.count, MockFixtures.offers.count)
        XCTAssertFalse(store.isStale)
        let cached = try cache.load(region: "01219")
        XCTAssertEqual(cached.offers.count, MockFixtures.offers.count)
    }

    func testLoadEmptyResultReachesEmpty() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .success([])),
            cache: try makeCache()
        )

        await store.load(regions: ["01219"], chains: [])

        XCTAssertEqual(store.state, .empty)
    }

    func testEmptyResultWithFavoriteChainsIsEmptyAfterLoad() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .success([])),
            cache: try makeCache()
        )

        await store.load(regions: ["01219"], chains: ["Kaufland"])

        XCTAssertTrue(store.isEmptyAfterLoad)
        XCTAssertTrue(store.hasFavoriteChains)
    }

    func testEmptyResultWithoutFavoriteChainsHasNoFavoriteChains() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .success([])),
            cache: try makeCache()
        )

        await store.load(regions: ["01219"], chains: [])

        XCTAssertTrue(store.isEmptyAfterLoad)
        XCTAssertFalse(store.hasFavoriteChains)
    }

    func testLoadedResultIsNotEmptyAfterLoad() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .success(MockFixtures.offers)),
            cache: try makeCache()
        )

        await store.load(regions: ["01219"], chains: [])

        XCTAssertFalse(store.isEmptyAfterLoad)
    }

    func testLoadErrorWithoutCacheReachesError() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: try makeCache()
        )

        await store.load(regions: ["01219"], chains: [])

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

        await store.load(regions: ["01219"], chains: [])

        XCTAssertFalse(store.isOffline)
        if case .error = store.state {
            XCTFail("a cancelled load must not surface as an error")
        }
    }

    func testLoadErrorWithCacheKeepsCachedDataAndFlagsStale() async throws {
        let cache = try makeCache()
        // Stale timestamp so the store attempts (and fails) a network refresh.
        try cache.replaceAll(
            MockFixtures.offers, region: "01219",
            fetchedAt: .now.addingTimeInterval(-OfferCache.maxAge - 60)
        )
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: cache
        )

        await store.load(regions: ["01219"], chains: [])

        XCTAssertEqual(store.state, .loaded)
        XCTAssertEqual(store.offers.count, MockFixtures.offers.count)
        XCTAssertTrue(store.isOffline)
        XCTAssertTrue(store.isStale)
    }

    func testCachedOffersAreNarrowedToFavoriteChains() async throws {
        let cache = try makeCache()
        try cache.replaceAll(MockFixtures.offers, region: "01219", fetchedAt: .now)
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: cache
        )

        await store.load(regions: ["01219"], chains: ["Lidl"])

        XCTAssertTrue(store.offers.allSatisfy { $0.market == "Lidl" })
        XCTAssertFalse(store.offers.isEmpty)
    }

    // MARK: Multi-region

    private func offer(region: String, market: String = "Lidl") -> Offer {
        let base = MockFixtures.offers[0]
        return Offer(
            market: market, product: base.product, price: base.price,
            regularPrice: base.regularPrice, unit: base.unit,
            category: base.category, emoji: base.emoji,
            validFrom: base.validFrom, validUntil: base.validUntil,
            basePrice: base.basePrice, baseUnit: base.baseUnit, region: region
        )
    }

    func testLoadQueriesAllRegionsInOneCall() async throws {
        let repository = RecordingOfferRepository()
        repository.result = [offer(region: "01219"), offer(region: "01067")]
        let store = OfferStore(repository: repository, cache: try makeCache())

        await store.load(regions: ["01219", "01067"], chains: ["Lidl", "Aldi"])

        XCTAssertEqual(repository.lastRegions, ["01219", "01067"])
        XCTAssertEqual(store.offers.count, 2)
        XCTAssertEqual(Set(store.offers.map(\.region)), ["01219", "01067"])
    }

    func testRefreshReplacesCachePerRegion() async throws {
        let cache = try makeCache()
        // Stale row that the fresh (empty) result for 01067 must clear.
        try cache.replaceAll([offer(region: "01067")], region: "01067", fetchedAt: .now)
        let repository = RecordingOfferRepository()
        repository.result = [offer(region: "01219")]
        let store = OfferStore(repository: repository, cache: cache)

        await store.load(regions: ["01219", "01067"], chains: [])

        XCTAssertEqual(try cache.load(region: "01219").offers.count, 1)
        XCTAssertTrue(try cache.load(region: "01067").offers.isEmpty)
    }

    func testCachedOffersOfAllRegionsAreServedWhenOffline() async throws {
        let cache = try makeCache()
        let stale = Date.now.addingTimeInterval(-OfferCache.maxAge - 60)
        try cache.replaceAll([offer(region: "01219")], region: "01219", fetchedAt: stale)
        try cache.replaceAll([offer(region: "01067")], region: "01067", fetchedAt: stale)
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: cache
        )

        await store.load(regions: ["01219", "01067"], chains: [])

        XCTAssertEqual(store.state, .loaded)
        XCTAssertEqual(Set(store.offers.map(\.region)), ["01219", "01067"])
        XCTAssertTrue(store.isOffline)
    }

    // MARK: KW-Cache

    func testFreshCompleteCacheSkipsNetworkRefresh() async throws {
        let cache = try makeCache()
        try cache.replaceAll(MockFixtures.offers, region: "01219", fetchedAt: .now)
        let repository = RecordingOfferRepository()
        let store = OfferStore(repository: repository, cache: cache)

        await store.load(regions: ["01219"], chains: [])

        XCTAssertEqual(repository.callCount, 0)
        XCTAssertEqual(store.state, .loaded)
        XCTAssertFalse(store.isStale)
    }

    func testMatchKeySurvivesCacheRoundTrip() async throws {
        let cache = try makeCache()
        var tagged = MockFixtures.offers[0]
        tagged.matchKey = ["milch"]
        try cache.replaceAll([tagged], region: "01219", fetchedAt: .now)

        let cached = try cache.load(region: "01219")

        XCTAssertEqual(cached.offers.first?.matchKeys, ["milch"])
    }
}
