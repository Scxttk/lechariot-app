import Foundation
import SwiftData

/// Offer cache: replace-all per region on each successful refresh.
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

    private let container: ModelContainer

    init(inMemory: Bool = false) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: CachedOffer.self, configurations: config)
    }

    /// Cached offers for a region plus the time they were fetched (nil if empty).
    func load(region: String) throws -> (offers: [Offer], fetchedAt: Date?) {
        let descriptor = FetchDescriptor<CachedOffer>(
            predicate: #Predicate { $0.region == region },
            sortBy: [SortDescriptor(\.validFrom, order: .reverse)]
        )
        let rows = try container.mainContext.fetch(descriptor)
        return (rows.map(\.offer), rows.first?.fetchedAt)
    }

    /// Drops all cached rows of `region` and stores `offers` in their place.
    func replaceAll(_ offers: [Offer], region: String, fetchedAt: Date = .now) throws {
        let context = container.mainContext
        try context.delete(model: CachedOffer.self, where: #Predicate { $0.region == region })
        for offer in offers {
            context.insert(CachedOffer(offer: offer, fetchedAt: fetchedAt))
        }
        try context.save()
    }

    /// Drops every cached row of every region.
    func deleteAll() throws {
        let context = container.mainContext
        try context.delete(model: CachedOffer.self)
        try context.save()
    }

    /// True when there is no fetch timestamp, it is older than `maxAge`, or it
    /// is from an earlier calendar week — the cache key is Region+KW, so a week
    /// rollover always invalidates even a fresh-looking cache.
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
