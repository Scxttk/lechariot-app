import Foundation
import Observation

// MARK: - Display helpers

extension Offer {
    /// Discount in percent vs. the regular price, or nil when not computable.
    var discountPercent: Int? {
        guard let price, let regularPrice, regularPrice > 0, price < regularPrice else {
            return nil
        }
        return Int(((regularPrice - price) / regularPrice * 100).rounded())
    }
}

/// How the offer list is sectioned.
enum OfferGrouping: String, CaseIterable, Identifiable {
    case market = "Markt"
    case category = "Kategorie"
    var id: String { rawValue }
}

/// Sort order inside sections.
enum OfferSort: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case deals = "Deals"
    var id: String { rawValue }
}

/// Pure search/filter/group/sort pipeline over loaded offers. Kept side-effect
/// free so it is trivially testable.
enum OfferQuery {
    static func apply(
        _ offers: [Offer],
        search: String = "",
        category: String? = nil,
        market: String? = nil,
        sort: OfferSort = .standard
    ) -> [Offer] {
        var result = offers
        let needle = search.trimmingCharacters(in: .whitespaces)
        if !needle.isEmpty {
            result = result.filter { $0.product.localizedCaseInsensitiveContains(needle) }
        }
        if let category {
            result = result.filter { $0.category == category }
        }
        if let market {
            result = result.filter { $0.market == market }
        }
        switch sort {
        case .standard:
            result.sort { $0.product.localizedCompare($1.product) == .orderedAscending }
        case .deals:
            result.sort { ($0.discountPercent ?? -1) > ($1.discountPercent ?? -1) }
        }
        return result
    }

    /// Sections in display order. Market sections alphabetical; category
    /// sections follow the fixed `Categories.all` order.
    static func grouped(_ offers: [Offer], by grouping: OfferGrouping) -> [(key: String, offers: [Offer])] {
        switch grouping {
        case .market:
            let dict = Dictionary(grouping: offers, by: \.market)
            return dict.keys.sorted().map { (key: $0, offers: dict[$0]!) }
        case .category:
            let dict = Dictionary(grouping: offers, by: \.category)
            var sections = Categories.all.compactMap { name in
                dict[name].map { (key: name, offers: $0) }
            }
            let known = Set(Categories.all)
            for key in dict.keys.sorted() where !known.contains(key) {
                sections.append((key: key, offers: dict[key]!))
            }
            return sections
        }
    }
}

// MARK: - Store

/// Drives the Angebote screen. Serves cached offers instantly, refreshes from
/// the network in the background, and flags stale data (>24h or offline).
@MainActor
@Observable
final class OfferStore {
    enum State: Equatable {
        case loading
        case loaded
        case empty
        case error(String)
    }

    private(set) var state: State = .loading
    private(set) var offers: [Offer] = []
    private(set) var fetchedAt: Date?
    /// True while a background refresh is running behind cached data.
    private(set) var isRefreshing = false
    /// Set when a refresh failed but cached data is still shown.
    private(set) var isOffline = false

    private let repository: OfferRepositoryProtocol
    private let cache: OfferCache?
    private var plz: String?
    private var chains: [String] = []

    var isStale: Bool {
        isOffline || OfferCache.isStale(fetchedAt: fetchedAt)
    }

    init(repository: OfferRepositoryProtocol, cache: OfferCache?) {
        self.repository = repository
        self.cache = cache
    }

    /// Shows cached offers for the region immediately (if any), then refreshes.
    func load(plz: String, chains: [String]) async {
        self.plz = plz
        self.chains = chains
        if let cached = try? cache?.load(region: plz), !cached.offers.isEmpty {
            offers = filteredToChains(cached.offers)
            fetchedAt = cached.fetchedAt
            state = offers.isEmpty ? .empty : .loaded
        } else {
            state = .loading
        }
        await refresh()
    }

    /// Fetches from the network and replaces the cache for the region.
    func refresh() async {
        guard let plz else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let fresh = try await repository.offers(regions: [plz], chains: chains)
            let now = Date.now
            try? cache?.replaceAll(fresh, region: plz, fetchedAt: now)
            offers = fresh
            fetchedAt = now
            isOffline = false
            state = fresh.isEmpty ? .empty : .loaded
        } catch {
            isOffline = true
            // Keep showing cached data; only surface the error when there is none.
            if offers.isEmpty {
                state = .error(error.localizedDescription)
            }
        }
    }

    /// The cache stores all chains of a region as fetched; narrow to the
    /// currently favorited chains for display.
    private func filteredToChains(_ offers: [Offer]) -> [Offer] {
        guard !chains.isEmpty else { return offers }
        return offers.filter { chains.contains($0.market) }
    }
}
