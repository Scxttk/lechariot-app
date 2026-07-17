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

        await store.load(plz: "01219", chains: [])

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

        await store.load(plz: "01219", chains: [])

        XCTAssertEqual(store.state, .empty)
    }

    func testLoadErrorWithoutCacheReachesError() async throws {
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: try makeCache()
        )

        await store.load(plz: "01219", chains: [])

        XCTAssertEqual(store.state, .error("kaputt"))
    }

    func testLoadErrorWithCacheKeepsCachedDataAndFlagsStale() async throws {
        let cache = try makeCache()
        try cache.replaceAll(MockFixtures.offers, region: "01219", fetchedAt: .now)
        let store = OfferStore(
            repository: StubOfferRepository(result: .failure(StubError())),
            cache: cache
        )

        await store.load(plz: "01219", chains: [])

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

        await store.load(plz: "01219", chains: ["Lidl"])

        XCTAssertTrue(store.offers.allSatisfy { $0.market == "Lidl" })
        XCTAssertFalse(store.offers.isEmpty)
    }
}
