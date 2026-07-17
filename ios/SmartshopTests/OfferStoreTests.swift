import XCTest
@testable import Smartshop

/// Repository stub with switchable result for driving OfferStore states.
private struct StubOfferRepository: OfferRepositoryProtocol {
    var result: Result<[Offer], Error> = .success([])

    func offers(regions: [String], chains: [String]) async throws -> [Offer] {
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
    private(set) var lastChains: [String]?

    func offers(regions: [String], chains: [String]) async throws -> [Offer] {
        lastRegions = regions
        lastChains = chains
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

    func testLoadErrorWithoutCacheReachesError() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: try makeCache()
        )

        await store.load(regions: ["01219"], chains: [])

        XCTAssertEqual(store.state, .error("kaputt"))
    }

    func testLoadErrorWithCacheKeepsCachedDataAndFlagsStale() async throws {
        let cache = try makeCache()
        try cache.replaceAll(MockFixtures.offers, region: "01219", fetchedAt: .now)
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
        XCTAssertEqual(repository.lastChains, ["Lidl", "Aldi"])
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
        try cache.replaceAll([offer(region: "01219")], region: "01219", fetchedAt: .now)
        try cache.replaceAll([offer(region: "01067")], region: "01067", fetchedAt: .now)
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: cache
        )

        await store.load(regions: ["01219", "01067"], chains: [])

        XCTAssertEqual(store.state, .loaded)
        XCTAssertEqual(Set(store.offers.map(\.region)), ["01219", "01067"])
        XCTAssertTrue(store.isOffline)
    }
}
