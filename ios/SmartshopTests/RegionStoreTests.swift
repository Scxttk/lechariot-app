import XCTest
@testable import Smartshop

/// Controllable region repository: fixtures can change mid-test to simulate
/// the backend finishing a sync while the store polls.
final class ControllableRegionRepository: RegionRepositoryProtocol, @unchecked Sendable {
    var regionsByPLZ: [String: Region] = [:]
    var shouldThrow = false
    private(set) var registeredPLZs: [String] = []
    /// Region fetches remaining until `syncCompletesTo` is applied, if set.
    var fetchesUntilSynced: Int?
    var syncCompletesTo: Region?

    struct TestError: Error {}

    func region(plz: String) async throws -> Region? {
        if shouldThrow { throw TestError() }
        if let remaining = fetchesUntilSynced {
            if remaining <= 0, let synced = syncCompletesTo, synced.plz == plz {
                regionsByPLZ[plz] = synced
            } else {
                fetchesUntilSynced = remaining - 1
            }
        }
        return regionsByPLZ[plz]
    }

    func registerRegion(plz: String) async throws {
        if shouldThrow { throw TestError() }
        registeredPLZs.append(plz)
    }
}

@MainActor
final class RegionStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "RegionStoreTests")
        defaults.removePersistentDomain(forName: "RegionStoreTests")
    }

    private func makeStore(
        repository: RegionRepositoryProtocol,
        maxPollAttempts: Int = 3
    ) -> RegionStore {
        RegionStore(
            repository: repository,
            defaults: defaults,
            pollInterval: .milliseconds(1),
            maxPollAttempts: maxPollAttempts
        )
    }

    // MARK: PLZ validation

    func testPLZValidation() {
        XCTAssertTrue(PLZValidator.isValid("01219"))
        XCTAssertTrue(PLZValidator.isValid(" 44135 "))
        XCTAssertFalse(PLZValidator.isValid("1219"))
        XCTAssertFalse(PLZValidator.isValid("012190"))
        XCTAssertFalse(PLZValidator.isValid("0121a"))
        XCTAssertFalse(PLZValidator.isValid(""))
        XCTAssertFalse(PLZValidator.isValid("۰۱۲۱۹")) // non-ASCII digits
        XCTAssertEqual(PLZValidator.normalized(" 01219 "), "01219")
        XCTAssertNil(PLZValidator.normalized("abc"))
    }

    // MARK: State machine

    func testExistingSyncedRegionIsImmediatelyReady() async {
        let repo = ControllableRegionRepository()
        repo.regionsByPLZ["01219"] = Region(plz: "01219", lastSynced: "2026-07-16T05:00:00Z", active: true)
        let store = makeStore(repository: repo)

        await store.addRegion("01219")

        XCTAssertEqual(store.syncState(for: "01219"), .ready)
        XCTAssertEqual(store.regions, ["01219"])
        XCTAssertEqual(store.selectedRegion, "01219")
        XCTAssertTrue(repo.registeredPLZs.isEmpty)
    }

    func testMissingRegionIsRegisteredAndBecomesReadyAfterPolling() async {
        let repo = ControllableRegionRepository()
        repo.fetchesUntilSynced = 2
        repo.syncCompletesTo = Region(plz: "01219", lastSynced: "2026-07-17T05:00:00Z", active: true)
        let store = makeStore(repository: repo, maxPollAttempts: 10)

        await store.addRegion("01219")
        XCTAssertEqual(store.syncState(for: "01219"), .requested)
        XCTAssertEqual(repo.registeredPLZs, ["01219"])

        await store.waitForPolling("01219")
        XCTAssertEqual(store.syncState(for: "01219"), .ready)
        XCTAssertTrue(store.readyRegions.contains("01219"))
    }

    func testExistingUnsyncedRegionPollsWithoutRegistering() async {
        let repo = ControllableRegionRepository()
        repo.regionsByPLZ["01219"] = Region(plz: "01219", lastSynced: nil, active: true)
        repo.fetchesUntilSynced = 1
        repo.syncCompletesTo = Region(plz: "01219", lastSynced: "2026-07-17T05:00:00Z", active: true)
        let store = makeStore(repository: repo, maxPollAttempts: 10)

        await store.addRegion("01219")
        XCTAssertEqual(store.syncState(for: "01219"), .syncing)
        XCTAssertTrue(repo.registeredPLZs.isEmpty)

        await store.waitForPolling("01219")
        XCTAssertEqual(store.syncState(for: "01219"), .ready)
    }

    func testPollingTimesOut() async {
        let repo = ControllableRegionRepository()
        repo.regionsByPLZ["01219"] = Region(plz: "01219", lastSynced: nil, active: true)
        let store = makeStore(repository: repo, maxPollAttempts: 3)

        await store.addRegion("01219")
        await store.waitForPolling("01219")

        XCTAssertEqual(store.syncState(for: "01219"), .failed(.timedOut))
        XCTAssertFalse(store.isOnboardingComplete)
    }

    func testNetworkErrorYieldsFailedState() async {
        let repo = ControllableRegionRepository()
        repo.shouldThrow = true
        let store = makeStore(repository: repo)

        await store.addRegion("01219")

        XCTAssertEqual(store.syncState(for: "01219"), .failed(.network))
    }

    func testInvalidPLZIsRejected() async {
        let repo = ControllableRegionRepository()
        let store = makeStore(repository: repo)

        await store.addRegion("abc")

        XCTAssertTrue(store.regions.isEmpty)
        XCTAssertEqual(store.syncState(for: "abc"), .unknown)
    }

    func testMaxTenRegions() async {
        let repo = ControllableRegionRepository()
        let store = makeStore(repository: repo)
        for i in 0..<12 {
            await store.addRegion(String(format: "%05d", i))
        }
        XCTAssertEqual(store.regions.count, 10)
        XCTAssertFalse(store.canAddRegion)
    }

    // MARK: Multi-region helpers

    func testOrderedReadyRegionsAndFavoritesAcrossRegions() async {
        let repo = ControllableRegionRepository()
        repo.regionsByPLZ["01219"] = Region(plz: "01219", lastSynced: "2026-07-16T05:00:00Z", active: true)
        repo.regionsByPLZ["01067"] = Region(plz: "01067", lastSynced: "2026-07-16T05:00:00Z", active: true)
        // Never syncs → must not appear in orderedReadyRegions.
        repo.regionsByPLZ["10115"] = Region(plz: "10115", lastSynced: nil, active: true)
        let store = makeStore(repository: repo, maxPollAttempts: 1)

        await store.addRegion("01219")
        await store.addRegion("10115")
        await store.addRegion("01067")
        await store.waitForPolling("10115")

        XCTAssertEqual(store.orderedReadyRegions, ["01219", "01067"])

        let dresden = Market(chain: "Lidl", branchName: "Dresden Reick", marketId: "lidl-01219-1", plz: "01219")
        let mitte = Market(chain: "Aldi", branchName: "Dresden Mitte", marketId: "aldi-01067-1", plz: "01067")
        store.toggleFavorite(dresden)
        store.toggleFavorite(mitte)

        XCTAssertEqual(store.favoriteMarkets(in: ["01219", "01067"]), [dresden, mitte])
        XCTAssertEqual(store.favoriteMarkets(in: ["01067"]), [mitte])
    }

    // MARK: Persistence round-trip

    func testWunschmaerktePersistenceRoundTrip() async {
        let repo = ControllableRegionRepository()
        repo.regionsByPLZ["01219"] = Region(plz: "01219", lastSynced: "2026-07-16T05:00:00Z", active: true)
        let store = makeStore(repository: repo)

        await store.addRegion("01219")
        let market = Market(chain: "Lidl", branchName: "Dresden Reick", marketId: "lidl-01219-1", plz: "01219")
        store.toggleFavorite(market)
        XCTAssertTrue(store.isOnboardingComplete)

        // Fresh store over the same defaults simulates an app relaunch.
        let relaunched = makeStore(repository: repo)
        XCTAssertEqual(relaunched.regions, ["01219"])
        XCTAssertEqual(relaunched.selectedRegion, "01219")
        XCTAssertEqual(relaunched.favoriteMarkets, [market])
        XCTAssertEqual(relaunched.syncState(for: "01219"), .ready)
        XCTAssertTrue(relaunched.isOnboardingComplete)

        relaunched.toggleFavorite(market)
        XCTAssertTrue(relaunched.favoriteMarkets.isEmpty)
        XCTAssertFalse(relaunched.isOnboardingComplete)
    }

    func testRemoveRegionClearsFavoritesAndSelection() async {
        let repo = ControllableRegionRepository()
        repo.regionsByPLZ["01219"] = Region(plz: "01219", lastSynced: "2026-07-16T05:00:00Z", active: true)
        let store = makeStore(repository: repo)

        await store.addRegion("01219")
        store.toggleFavorite(Market(chain: "Lidl", branchName: "Dresden Reick", marketId: "lidl-01219-1", plz: "01219"))
        store.removeRegion("01219")

        XCTAssertTrue(store.regions.isEmpty)
        XCTAssertNil(store.selectedRegion)
        XCTAssertTrue(store.favoriteMarkets.isEmpty)
        XCTAssertEqual(store.syncState(for: "01219"), .unknown)
    }

    // MARK: Corrupt/out-of-sync persisted state

    func testCorruptFavoritesDataResetsToEmpty() {
        defaults.set(Data("not json".utf8), forKey: "region.favoriteMarkets")
        defaults.set(["01219"], forKey: "region.plzs")
        let store = makeStore(repository: ControllableRegionRepository())
        XCTAssertTrue(store.favoriteMarkets.isEmpty)
    }

    func testOrphanedSelectionAndFavoritesAreSanitizedOnInit() throws {
        // Selected region and a favorite reference a PLZ that is no longer
        // in the region list (corrupt/old defaults).
        defaults.set(["01219"], forKey: "region.plzs")
        defaults.set("99999", forKey: "region.selected")
        defaults.set(["01219", "99999"], forKey: "region.readyPLZs")
        let orphan = Market(chain: "Lidl", branchName: "Weg", marketId: "lidl-99999-1", plz: "99999")
        let kept = Market(chain: "EDEKA", branchName: "Reick", marketId: "edeka-01219-1", plz: "01219")
        defaults.set(try JSONEncoder().encode([orphan, kept]), forKey: "region.favoriteMarkets")

        let store = makeStore(repository: ControllableRegionRepository())
        XCTAssertEqual(store.selectedRegion, "01219")
        XCTAssertEqual(store.favoriteMarkets, [kept])
        XCTAssertEqual(store.orderedReadyRegions, ["01219"])
        XCTAssertTrue(store.isOnboardingComplete)
    }
}
