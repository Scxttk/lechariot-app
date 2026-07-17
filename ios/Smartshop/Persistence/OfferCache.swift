import Foundation
import SwiftData

/// Offer cache: replace-all per region on each successful refresh.
/// Cached rows are served instantly on launch; `fetchedAt` drives staleness.
@MainActor
final class OfferCache {
    /// Cached data older than this counts as stale.
    static let maxAge: TimeInterval = 24 * 60 * 60

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

    /// True when there is no fetch timestamp or it is older than `maxAge`.
    static func isStale(fetchedAt: Date?, now: Date = .now) -> Bool {
        guard let fetchedAt else { return true }
        return now.timeIntervalSince(fetchedAt) > maxAge
    }
}
