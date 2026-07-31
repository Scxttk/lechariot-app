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

/// Whether a postcode is usable. Since migration v16 there is nothing to wait
/// for — a postcode is ready the moment it is typed — so the only distinction
/// left is "known to this install" or not.
enum RegionSyncState: Equatable {
    /// Not one of the user's postcodes.
    case unknown
    /// Saved and usable.
    case ready
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

    private let defaults: UserDefaults

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
    /// Set once the user has walked through onboarding, and never cleared by
    /// normal use. See `isOnboardingComplete`.
    private(set) var hasCompletedOnboarding: Bool

    private enum Keys {
        static let regions = "region.plzs"
        static let selected = "region.selected"
        static let favorites = "region.favoriteMarkets"
        static let ready = "region.readyPLZs"
        static let onboarded = "region.onboardingCompleted"

        static let all = [regions, selected, favorites, ready, onboarded]
    }

    init(defaults: UserDefaults = AppDefaults.shared) {
        self.defaults = defaults
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
        // ready/selected must reference a PLZ that is still in `regions`.
        // Favorites are exempt: the picker deliberately offers branches from
        // neighbouring postcodes, so a favorite's own `plz` is often not one
        // of the user's regions (or empty when the directory has none).
        let knownPLZs = Set(regions)
        readyRegions.formIntersection(knownPLZs)
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

    /// Removes a postcode. **The chosen branches stay.**
    ///
    /// This used to also drop every favourite whose own `plz` equalled the
    /// region, which sounds tidy and worked almost never: the picker offers
    /// everything within 10–40 km, and a store's own postcode is hardly ever
    /// the region's. Penny Gößnitz carries 04639, the region was 04626 — so it
    /// survived, while a store that happened to sit in 04626 would have gone.
    /// Half a cleanup, decided by a coincidence of postcode boundaries.
    ///
    /// The honest version is to not do it at all: the app cannot tell a
    /// leftover from a branch someone picked across the border on purpose —
    /// which is the very case regions exist for. Branches are removed one by
    /// one in the settings, where doing so is now visible.
    func removeRegion(_ plz: String) {
        regions.removeAll { $0 == plz }
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

    // MARK: Wunschmärkte

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

    /// Wipes every trace of this store, in memory and on disk, so the next
    /// render is indistinguishable from a first launch. Seit 2026-07-30 auch
    /// im Release-Build erreichbar — siehe `AppReset`.
    func resetAllData() {
        regions = []
        selectedRegion = nil
        favoriteMarkets = []
        readyRegions = []
        syncStates = [:]
        hasCompletedOnboarding = false
        for key in Keys.all { defaults.removeObject(forKey: key) }
    }
}
