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

    private var pollTasks: [String: Task<Void, Never>] = [:]

    private enum Keys {
        static let regions = "region.plzs"
        static let selected = "region.selected"
        static let favorites = "region.favoriteMarkets"
        static let ready = "region.readyPLZs"
    }

    init(
        repository: RegionRepositoryProtocol,
        defaults: UserDefaults = .standard,
        pollInterval: Duration = .seconds(30),
        maxPollAttempts: Int = 20
    ) {
        self.repository = repository
        self.defaults = defaults
        self.pollInterval = pollInterval
        self.maxPollAttempts = maxPollAttempts
        self.regions = defaults.stringArray(forKey: Keys.regions) ?? []
        self.selectedRegion = defaults.string(forKey: Keys.selected)
        self.readyRegions = Set(defaults.stringArray(forKey: Keys.ready) ?? [])
        if let data = defaults.data(forKey: Keys.favorites),
           let markets = try? JSONDecoder().decode([Market].self, from: data) {
            self.favoriteMarkets = markets
        } else {
            self.favoriteMarkets = []
        }
        for plz in readyRegions where regions.contains(plz) {
            syncStates[plz] = .ready
        }
    }

    // MARK: Derived state

    var canAddRegion: Bool { regions.count < Self.maxRegions }

    /// Onboarding is done once at least one region is ready and at least one
    /// Wunschmarkt is chosen.
    var isOnboardingComplete: Bool {
        !readyRegions.intersection(regions).isEmpty && !favoriteMarkets.isEmpty
    }

    func syncState(for plz: String) -> RegionSyncState {
        syncStates[plz] ?? .unknown
    }

    // MARK: Region flow

    /// Checks a PLZ against the backend, registers it if unknown, and polls
    /// until it is synced. Drives `syncStates[plz]` through the state machine.
    func addRegion(_ rawPLZ: String) async {
        guard let plz = PLZValidator.normalized(rawPLZ), canAddRegion else { return }
        if !regions.contains(plz) {
            regions.append(plz)
            if selectedRegion == nil { selectedRegion = plz }
            persist()
        }
        await checkAndSync(plz: plz)
    }

    /// Re-runs the check/poll flow, e.g. after a failure.
    func retry(_ plz: String) async {
        await checkAndSync(plz: plz)
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

    private func checkAndSync(plz: String) async {
        pollTasks[plz]?.cancel()
        do {
            if let region = try await repository.region(plz: plz) {
                if region.lastSynced != nil {
                    markReady(plz)
                } else {
                    syncStates[plz] = .syncing
                    startPolling(plz: plz)
                }
            } else {
                try await repository.registerRegion(plz: plz)
                syncStates[plz] = .requested
                startPolling(plz: plz)
            }
        } catch {
            syncStates[plz] = .failed(.network)
        }
    }

    private func startPolling(plz: String) {
        pollTasks[plz] = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<maxPollAttempts {
                try? await Task.sleep(for: pollInterval)
                if Task.isCancelled { return }
                if let region = try? await repository.region(plz: plz) {
                    if region.lastSynced != nil {
                        markReady(plz)
                        return
                    }
                    // Row now exists → backend picked the request up.
                    if syncStates[plz] == .requested { syncStates[plz] = .syncing }
                }
            }
            if !Task.isCancelled { syncStates[plz] = .failed(.timedOut) }
        }
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
        if let data = try? JSONEncoder().encode(favoriteMarkets) {
            defaults.set(data, forKey: Keys.favorites)
        }
    }
}
