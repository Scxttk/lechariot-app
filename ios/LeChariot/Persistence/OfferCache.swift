import Foundation
import SwiftData

/// Offer cache: replace-all on each successful refresh.
/// Cached rows are served instantly on launch; `fetchedAt` drives staleness.
@MainActor
final class OfferCache {
    /// Cached data older than this counts as stale.
    static let maxAge: TimeInterval = 24 * 60 * 60

    /// The app's single cache instance.
    ///
    /// A `ModelContainer` is expensive and opens the store file. SwiftUI
    /// re-evaluates `@State` initial values on every view init and throws all
    /// but the first away, so building one inline meant constructing containers
    /// over and over — for the same file — and discarding them.
    ///
    /// UI-test runs get an in-memory container instead. `-uiTesting` swaps the
    /// repositories for fixtures, but the cache is read *before* the network
    /// and lives in its own store file — so a normal run's real offers were
    /// served to the "hermetic" journeys and quietly overruled the fixtures.
    static let shared: OfferCache? = {
        #if DEBUG
        if UITestSupport.isActive { return try? OfferCache(inMemory: true) }
        #endif
        return try? OfferCache()
    }()

    /// Key under which the branch selection the cache was written for is kept.
    private static let branchesKey = "offerCache.branchIds"

    private let container: ModelContainer
    private let defaults: UserDefaults

    init(inMemory: Bool = false, defaults: UserDefaults = AppDefaults.shared) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: CachedOffer.self, configurations: config)
        self.defaults = defaults
    }

    /// The branches the cached rows were fetched for.
    ///
    /// Persisted next to the rows, not held in memory: after a cold start the
    /// store has no idea what the cache contains, and an in-memory field would
    /// have made every launch look like a changed selection and refetch —
    /// which is exactly what the KW cache exists to avoid.
    var cachedBranchIds: [String] {
        defaults.stringArray(forKey: Self.branchesKey) ?? []
    }

    /// Everything in the cache plus the time it was fetched (nil if empty).
    ///
    /// No bucket parameter any more. Since the app asks for its chosen
    /// branches in a single query, the cache holds exactly one answer — the
    /// per-region buckets only ever existed because several postcodes were
    /// split out of one response afterwards.
    func load() throws -> (offers: [Offer], fetchedAt: Date?) {
        let descriptor = FetchDescriptor<CachedOffer>(
            sortBy: [SortDescriptor(\.validFrom, order: .reverse)]
        )
        let rows = try container.mainContext.fetch(descriptor)
        return (rows.map(\.offer), rows.first?.fetchedAt)
    }

    /// Drops the whole cache and stores `offers` in its place, remembering
    /// which branches they were fetched for.
    func replaceAll(_ offers: [Offer], branchIds: [String] = [], fetchedAt: Date = .now) throws {
        let context = container.mainContext
        try context.delete(model: CachedOffer.self)
        for offer in offers {
            context.insert(CachedOffer(offer: offer, fetchedAt: fetchedAt))
        }
        try context.save()
        defaults.set(branchIds, forKey: Self.branchesKey)
    }

    /// Drops every cached row.
    func deleteAll() throws {
        let context = container.mainContext
        try context.delete(model: CachedOffer.self)
        try context.save()
        defaults.removeObject(forKey: Self.branchesKey)
    }

    /// True when there is no fetch timestamp, it is older than `maxAge`, or it
    /// is from an earlier calendar week — the cache key is Filialen+KW, so a
    /// week rollover always invalidates even a fresh-looking cache.
    static func isStale(fetchedAt: Date?, now: Date = .now) -> Bool {
        guard let fetchedAt else { return true }
        return now.timeIntervalSince(fetchedAt) > maxAge
            || weekKey(for: fetchedAt) != weekKey(for: now)
    }

    /// ISO calendar week identifier, e.g. "2026-W30".
    static func weekKey(for date: Date) -> String {
        let cal = Calendar(identifier: .iso8601)
        let week = cal.component(.weekOfYear, from: date)
        let year = cal.component(.yearForWeekOfYear, from: date)
        return String(format: "%d-W%02d", year, week)
    }
}
