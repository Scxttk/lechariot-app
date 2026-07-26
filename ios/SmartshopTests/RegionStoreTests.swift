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

    // Mid-sync progress fixtures; mutable so tests can simulate the backend
    // finding more markets/offers between polls.
    var marketsByPLZ: [String: [Market]] = [:]
    var offerCounts: [String: Int] = [:]
    private(set) var progressFetches = 0

    func foundMarkets(plz: String) async throws -> [Market] {
        if shouldThrow { throw TestError() }
        progressFetches += 1
        return marketsByPLZ[plz] ?? []
    }

    func offerCount(plz: String) async throws -> Int {
        if shouldThrow { throw TestError() }
        return offerCounts[plz] ?? 0
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
            maxPollAttempts: maxPollAttempts,
            progressPollInterval: .milliseconds(1)
        )
    }

    /// Polls `condition` (up to ~1 s) so tests survive scheduler jitter.
    private func waitUntil(_ condition: @autoclosure () -> Bool) async {
        for _ in 0..<1000 where !condition() {
            try? await Task.sleep(for: .milliseconds(1))
        }
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

    /// Seit Migration v16 fragt die App beim Hinzufügen einer PLZ **nichts**
    /// mehr beim Backend nach. Die Tabelle `regions` gibt es nicht mehr; die
    /// PLZ ist nur noch Standort-Eingabe für den Filial-Picker, und der holt
    /// sein Verzeichnis selbst. Eine PLZ ist damit fertig, sobald sie getippt
    /// ist — und der einzige Grund zu warten wäre eine **Filiale**, die das
    /// Backend noch nie geholt hat. Die fordert der Picker selbst an.
    func testAPostcodeIsReadyImmediatelyAndAsksNothingOfTheBackend() async {
        let repo = ControllableRegionRepository()
        let store = makeStore(repository: repo)

        await store.addRegion("01219")

        XCTAssertEqual(store.syncState(for: "01219"), .ready)
        XCTAssertTrue(store.readyRegions.contains("01219"))
        XCTAssertTrue(repo.registeredPLZs.isEmpty, "nichts registrieren")
    }

    /// Und ein kaputtes Backend ändert daran nichts — es wird ja nicht
    /// gefragt. Vorher landete der Nutzer hier auf einem Fehlerbildschirm.
    func testABrokenBackendNoLongerBlocksAddingAPostcode() async {
        let repo = ControllableRegionRepository()
        repo.shouldThrow = true
        let store = makeStore(repository: repo)

        await store.addRegion("01219")

        XCTAssertEqual(store.syncState(for: "01219"), .ready)
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

    func testOrderedReadyRegionsAndFavoritesAcrossRegions() async {
        let repo = ControllableRegionRepository()
        let store = makeStore(repository: repo)

        await store.addRegion("01219")
        await store.addRegion("10115")
        await store.addRegion("01067")

        // Alle drei sind bereit — seit v16 gibt es keinen Zustand mehr, in dem
        // eine PLZ auf das Backend wartet. Die Reihenfolge ist die des
        // Hinzufügens.
        XCTAssertEqual(store.orderedReadyRegions, ["01219", "10115", "01067"])

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
        store.completeOnboarding()
        XCTAssertTrue(store.isOnboardingComplete)

        // Fresh store over the same defaults simulates an app relaunch.
        let relaunched = makeStore(repository: repo)
        XCTAssertEqual(relaunched.regions, ["01219"])
        XCTAssertEqual(relaunched.selectedRegion, "01219")
        XCTAssertEqual(relaunched.favoriteMarkets, [market])
        XCTAssertEqual(relaunched.syncState(for: "01219"), .ready)
        XCTAssertTrue(relaunched.isOnboardingComplete)
    }

    // MARK: Onboarding completion

    func testFreshStoreIsNotOnboarded() {
        let store = makeStore(repository: ControllableRegionRepository())
        XCTAssertFalse(store.isOnboardingComplete)
        XCTAssertFalse(store.hasFavorites)
    }

    /// The regression that motivated the sticky flag: removing the last branch
    /// used to flip `isOnboardingComplete` back to false, which yanked the whole
    /// app out from under a user standing in the settings.
    func testRemovingTheLastBranchKeepsTheUserInTheApp() async {
        let repo = ControllableRegionRepository()
        repo.regionsByPLZ["01219"] = Region(plz: "01219", lastSynced: "2026-07-16T05:00:00Z", active: true)
        let store = makeStore(repository: repo)
        await store.addRegion("01219")
        let market = Market(chain: "Lidl", branchName: "Reick", marketId: "lidl-1", plz: "01219")
        store.toggleFavorite(market)
        store.completeOnboarding()

        store.toggleFavorite(market)

        XCTAssertTrue(store.favoriteMarkets.isEmpty)
        XCTAssertFalse(store.hasFavorites, "the tabs need to know a branch is missing")
        XCTAssertTrue(store.isOnboardingComplete, "but that must not restart onboarding")
    }

    func testRemovingTheLastRegionKeepsTheUserInTheApp() async {
        let repo = ControllableRegionRepository()
        repo.regionsByPLZ["01219"] = Region(plz: "01219", lastSynced: "2026-07-16T05:00:00Z", active: true)
        let store = makeStore(repository: repo)
        await store.addRegion("01219")
        store.toggleFavorite(Market(chain: "Lidl", branchName: "Reick", marketId: "lidl-1", plz: "01219"))
        store.completeOnboarding()

        store.removeRegion("01219")

        XCTAssertTrue(store.orderedReadyRegions.isEmpty)
        XCTAssertTrue(store.isOnboardingComplete)
    }

    /// Installs that predate the flag must not be sent through onboarding again
    /// just because their defaults have no `onboardingCompleted` key.
    func testInstallFromBeforeTheFlagCountsAsOnboarded() throws {
        let market = Market(chain: "Lidl", branchName: "Reick", marketId: "lidl-1", plz: "01219")
        defaults.set(["01219"], forKey: "region.plzs")
        defaults.set(["01219"], forKey: "region.readyPLZs")
        defaults.set(try JSONEncoder().encode([market]), forKey: "region.favoriteMarkets")

        let store = makeStore(repository: ControllableRegionRepository())

        XCTAssertTrue(store.isOnboardingComplete)
        // …and the migration is written through, so it survives the next launch
        // even if the user then removes the branch.
        XCTAssertTrue(defaults.bool(forKey: "region.onboardingCompleted"))
    }

    /// An install that never finished onboarding (region added, no branch
    /// picked) must not be migrated into the app.
    func testHalfFinishedInstallIsNotMigrated() {
        defaults.set(["01219"], forKey: "region.plzs")
        defaults.set(["01219"], forKey: "region.readyPLZs")

        let store = makeStore(repository: ControllableRegionRepository())

        XCTAssertFalse(store.isOnboardingComplete)
    }

    #if DEBUG
    func testDebugResetRestoresFirstLaunchState() async {
        let repo = ControllableRegionRepository()
        repo.regionsByPLZ["01219"] = Region(plz: "01219", lastSynced: "2026-07-16T05:00:00Z", active: true)
        let store = makeStore(repository: repo)
        await store.addRegion("01219")
        store.toggleFavorite(Market(chain: "Lidl", branchName: "Reick", marketId: "lidl-1", plz: "01219"))
        store.completeOnboarding()

        store.resetAllData()

        XCTAssertFalse(store.isOnboardingComplete)
        XCTAssertTrue(store.regions.isEmpty)
        XCTAssertTrue(store.favoriteMarkets.isEmpty)
        XCTAssertTrue(store.orderedReadyRegions.isEmpty)
        XCTAssertNil(store.selectedRegion)
        XCTAssertEqual(store.syncState(for: "01219"), .unknown)

        // Deterministic: a relaunch over the same defaults sees nothing either,
        // so the reset can be repeated without drift.
        let relaunched = makeStore(repository: repo)
        XCTAssertFalse(relaunched.isOnboardingComplete)
        XCTAssertTrue(relaunched.regions.isEmpty)
    }
    #endif

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
