import Foundation
import Observation

// MARK: - PLZ validation

enum PLZValidator {
    /// German PLZ: exactly 5 digits.
    static func isValid(_ plz: String) -> Bool {
        let trimmed = plz.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == 5 && trimmed.allSatisfy { $0.isASCII && $0.isNumber }
    }

    static func normalized(_ plz: String) -> String? {
        let trimmed = plz.trimmingCharacters(in: .whitespacesAndNewlines)
        return isValid(trimmed) ? trimmed : nil
    }
}

// MARK: - Sync state

/// Lifecycle of a region between "user typed a PLZ" and "offers available".
enum RegionSyncState: Equatable {
    /// Nothing known yet (initial, or check not started).
    case unknown
    /// Region row was missing; anon INSERT sent, waiting for backend to pick it up.
    case requested
    /// Region row exists but `last_synced` is still nil; polling for completion.
    case syncing
    /// Region has been synced at least once; offers/markets are available.
    case ready
    /// Check or registration failed, or polling timed out.
    case failed(RegionSyncFailure)
}

enum RegionSyncFailure: Equatable {
    /// Network/server error during check or registration.
    case network
    /// Polling exhausted; backend will usually deliver data overnight.
    case timedOut
}

/// Heuristic snapshot of a running backend sync: markets appear one by one,
/// the offer count grows. No total exists, so no percentage is derived.
struct RegionSyncProgress: Equatable {
    var markets: [Market] = []
    var offerCount: Int = 0
}

// MARK: - Store

/// Local source of truth for the user's regions (PLZs), the selected region and
/// favorite markets ("Wunschmärkte").
///
/// Persistence: UserDefaults. The data is tiny (≤10 PLZ strings, a selected PLZ
/// and a short JSON-encoded market list), needs no queries or relations, so
/// SwiftData would be overkill.
@MainActor
@Observable
final class RegionStore {
    static let maxRegions = 10

    private let repository: RegionRepositoryProtocol
    private let defaults: UserDefaults
    /// Interval between polls while a region is syncing. Injectable for tests.
    private let pollInterval: Duration
    /// Maximum number of polls before giving up (~10 min at 30 s default).
    private let maxPollAttempts: Int
    /// Interval between progress polls while the WaitingView is visible.
    private let progressPollInterval: Duration

    /// Saved PLZs, in the order the user added them.
    private(set) var regions: [String]
    /// PLZ whose offers are currently shown.
    private(set) var selectedRegion: String?
    /// Favorite markets across all regions (each carries its own `plz`).
    private(set) var favoriteMarkets: [Market]
    /// PLZs known to have completed at least one backend sync.
    private(set) var readyRegions: Set<String>
    /// Live sync state per PLZ for the current app session.
    private(set) var syncStates: [String: RegionSyncState] = [:]
    /// Live progress per PLZ while a sync runs (fed by `observeProgress`).
    private(set) var syncProgress: [String: RegionSyncProgress] = [:]
    /// Set once the user has walked through onboarding, and never cleared by
    /// normal use. See `isOnboardingComplete`.
    private(set) var hasCompletedOnboarding: Bool

    private var pollTasks: [String: Task<Void, Never>] = [:]

    private enum Keys {
        static let regions = "region.plzs"
        static let selected = "region.selected"
        static let favorites = "region.favoriteMarkets"
        static let ready = "region.readyPLZs"
        static let onboarded = "region.onboardingCompleted"

        static let all = [regions, selected, favorites, ready, onboarded]
    }

    init(
        repository: RegionRepositoryProtocol,
        defaults: UserDefaults = AppDefaults.shared,
        pollInterval: Duration = .seconds(30),
        maxPollAttempts: Int = 20,
        progressPollInterval: Duration = .seconds(10)
    ) {
        self.repository = repository
        self.defaults = defaults
        self.pollInterval = pollInterval
        self.maxPollAttempts = maxPollAttempts
        self.progressPollInterval = progressPollInterval
        self.regions = defaults.stringArray(forKey: Keys.regions) ?? []
        self.selectedRegion = defaults.string(forKey: Keys.selected)
        self.readyRegions = Set(defaults.stringArray(forKey: Keys.ready) ?? [])
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarded)
        if let data = defaults.data(forKey: Keys.favorites),
           let markets = try? JSONDecoder().decode([Market].self, from: data) {
            self.favoriteMarkets = markets
        } else {
            self.favoriteMarkets = []
        }
        // Sanitize persisted state that got out of sync (corrupt/old defaults):
        // everything must reference a PLZ that is still in `regions`.
        let knownPLZs = Set(regions)
        readyRegions.formIntersection(knownPLZs)
        favoriteMarkets.removeAll { !knownPLZs.contains($0.plz) }
        if let selected = selectedRegion, !knownPLZs.contains(selected) {
            selectedRegion = regions.first
        }
        for plz in readyRegions {
            syncStates[plz] = .ready
        }
        // Installs from before the flag existed: they earned their way through
        // onboarding under the old derived rule, so honour it once and store it.
        if !hasCompletedOnboarding, !readyRegions.isEmpty, !favoriteMarkets.isEmpty {
            hasCompletedOnboarding = true
        }
        persist()
    }

    // MARK: Derived state

    var canAddRegion: Bool { regions.count < Self.maxRegions }

    /// Ready regions in the order the user added them; the Angebote query
    /// spans all of them so PLZ-border users see every favorited market.
    var orderedReadyRegions: [String] {
        regions.filter { readyRegions.contains($0) }
    }

    /// Whether the main app UI may be shown.
    ///
    /// This used to be derived from "has a ready region AND a chosen branch",
    /// which made it reversible: removing the last branch in the settings threw
    /// the user out of the app and back into onboarding, mid-tap, with the
    /// settings screen yanked away underneath them. Onboarding is a one-time
    /// event, so it is recorded as one. Missing regions or branches are now
    /// ordinary empty states inside the tabs, right next to the settings that
    /// fix them.
    var isOnboardingComplete: Bool { hasCompletedOnboarding }

    /// True once at least one branch is chosen — without one, nothing can be
    /// matched and both content tabs have nothing honest to show.
    var hasFavorites: Bool { !favoriteMarkets.isEmpty }

    /// Records that onboarding was walked through. Idempotent.
    func completeOnboarding() {
        guard !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
        persist()
    }

    func syncState(for plz: String) -> RegionSyncState {
        syncStates[plz] ?? .unknown
    }

    func progress(for plz: String) -> RegionSyncProgress {
        syncProgress[plz] ?? RegionSyncProgress()
    }

    /// Polls found markets and the offer count for a PLZ while its sync runs.
    /// Meant to be bound to the WaitingView's lifetime via `.task` — it returns
    /// when the view disappears (cancellation) or the sync leaves the
    /// requested/syncing states, so nothing polls behind the user's back.
    /// Best-effort: single failed fetches keep the previous snapshot.
    func observeProgress(plz: String) async {
        while !Task.isCancelled {
            switch syncState(for: plz) {
            case .requested, .syncing, .unknown:
                break
            case .ready, .failed:
                return
            }
            var snapshot = progress(for: plz)
            if let markets = try? await repository.foundMarkets(plz: plz) {
                snapshot.markets = markets
            }
            if !Task.isCancelled, syncProgress[plz] != snapshot {
                syncProgress[plz] = snapshot
            }
            try? await Task.sleep(for: progressPollInterval)
        }
    }

    // MARK: Region flow

    /// Adds a postcode. **Nothing is asked of the backend any more.**
    ///
    /// Until migration v16 the app registered the postcode in `public.regions`,
    /// a trigger started a scrape and the user watched a waiting screen. That
    /// table is gone: since Phase 12 the postcode is nothing but a *location*
    /// — it geocodes so the picker can list nearby branches from the
    /// directory, and the directory is filled independently of anyone asking.
    /// What still needs fetching is a **branch**, and choosing one that the
    /// backend has never fetched triggers `branch_requests` right there in the
    /// picker.
    ///
    /// So the postcode is ready the moment it is typed.
    func addRegion(_ rawPLZ: String) async {
        guard let plz = PLZValidator.normalized(rawPLZ), canAddRegion else { return }
        if !regions.contains(plz) {
            regions.append(plz)
            if selectedRegion == nil { selectedRegion = plz }
            persist()
        }
        markReady(plz)
    }

    /// Kept so the failure path in the UI still compiles; with no backend
    /// round-trip there is nothing left that could fail.
    func retry(_ plz: String) async {
        markReady(plz)
    }

    func removeRegion(_ plz: String) {
        pollTasks[plz]?.cancel()
        pollTasks[plz] = nil
        regions.removeAll { $0 == plz }
        favoriteMarkets.removeAll { $0.plz == plz }
        readyRegions.remove(plz)
        syncStates[plz] = nil
        if selectedRegion == plz { selectedRegion = regions.first }
        persist()
    }

    func selectRegion(_ plz: String) {
        guard regions.contains(plz) else { return }
        selectedRegion = plz
        persist()
    }


    private func markReady(_ plz: String) {
        syncStates[plz] = .ready
        readyRegions.insert(plz)
        persist()
    }

    /// Awaits an in-flight poll task; used by tests to run the machine to completion.
    func waitForPolling(_ plz: String) async {
        await pollTasks[plz]?.value
    }

    // MARK: Wunschmärkte

    func favoriteMarkets(in plz: String) -> [Market] {
        favoriteMarkets.filter { $0.plz == plz }
    }

    func favoriteMarkets(in plzs: [String]) -> [Market] {
        favoriteMarkets.filter { plzs.contains($0.plz) }
    }

    func isFavorite(_ market: Market) -> Bool {
        favoriteMarkets.contains { $0.marketId == market.marketId }
    }

    func toggleFavorite(_ market: Market) {
        if let idx = favoriteMarkets.firstIndex(where: { $0.marketId == market.marketId }) {
            favoriteMarkets.remove(at: idx)
        } else {
            favoriteMarkets.append(market)
        }
        persist()
    }

    // MARK: Persistence

    private func persist() {
        defaults.set(regions, forKey: Keys.regions)
        defaults.set(selectedRegion, forKey: Keys.selected)
        defaults.set(Array(readyRegions), forKey: Keys.ready)
        defaults.set(hasCompletedOnboarding, forKey: Keys.onboarded)
        if let data = try? JSONEncoder().encode(favoriteMarkets) {
            defaults.set(data, forKey: Keys.favorites)
        }
    }

    #if DEBUG
    /// Wipes every trace of this store, in memory and on disk, so the next
    /// render is indistinguishable from a first launch. Debug builds only —
    /// see `DebugReset`.
    func resetAllData() {
        for task in pollTasks.values { task.cancel() }
        pollTasks.removeAll()
        regions = []
        selectedRegion = nil
        favoriteMarkets = []
        readyRegions = []
        syncStates = [:]
        syncProgress = [:]
        hasCompletedOnboarding = false
        for key in Keys.all { defaults.removeObject(forKey: key) }
    }
    #endif
}
