import Foundation
import Observation

// MARK: - Display helpers

extension DateFormatter {
    /// "13.7." — the short validity form used in rows and the price history.
    static let offerDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d.M."
        return formatter
    }()

    /// "13. Juli" — the detail sheet has room for the long form.
    static let offerDayLong: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d. MMMM"
        return formatter
    }()
}

extension Offer {
    /// Discount in percent vs. the regular price, or nil when not computable.
    var discountPercent: Int? {
        guard let price, let regularPrice, regularPrice > 0, price < regularPrice else {
            return nil
        }
        return Int(((regularPrice - price) / regularPrice * 100).rounded())
    }

    var validityText: String {
        let from = DateFormatter.offerDay.string(from: validFrom)
        let until = DateFormatter.offerDay.string(from: validUntil)
        return "Gültig \(from) – \(until)"
    }

    /// One sensible VoiceOver utterance: product, price, discount, regular
    /// price, market and validity instead of a scatter of fragments.
    ///
    /// Lives on the model, not in the row: the row is the *label of a Button*
    /// now, and the button owns the accessibility element.
    var voiceOverSummary: String {
        var parts: [String] = [product]
        if let unit { parts.append(unit) }
        if let price {
            parts.append(price.formatted(.currency(code: "EUR")))
        }
        if let discountPercent {
            parts.append("\(discountPercent) Prozent reduziert")
        }
        if let regularPrice {
            parts.append("statt \(regularPrice.formatted(.currency(code: "EUR")))")
        }
        parts.append("bei \(market)")
        parts.append("gültig bis \(DateFormatter.offerDay.string(from: validUntil))")
        return parts.joined(separator: ", ")
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

    /// Key for "this is the same offer, published twice".
    ///
    /// Market + product + price, deliberately WITHOUT region and WITHOUT the
    /// validity dates — those are exactly the two ways a duplicate arises:
    ///  · dates out — Kaufland/Lidl/Penny publish the week row (23.–29.7.) and
    ///    a one-day "Knüller" row (24.7.) for the same product at the same
    ///    price. The offers table keys on `valid_from`, so both survive.
    ///  · region out — a user with two ready PLZ gets the identical row twice,
    ///    and both land in the same "Kaufland" section because `Offer.id`
    ///    contains the region.
    /// Price stays IN: of the 65 duplicate (market, product) pairs measured in
    /// region 01219, 26 carry different prices — next week's row, or a
    /// genuinely different variant. Those must both survive.
    ///
    /// `unit` is deliberately out too: the one-day row often drops it, and
    /// keeping it in the key would leave the duplicate on screen.
    static func duplicateKey(_ offer: Offer) -> String {
        let product = offer.product
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        // Cents, not the Double: 1.99 from two sources can differ in the last bit.
        let cents = offer.price.map { String(Int(($0 * 100).rounded())) } ?? "-"
        return "\(offer.market.lowercased())|\(product)|\(cents)"
    }

    /// Which of two rows sharing a `duplicateKey` the user should see:
    /// a row valid today beats one that only starts later, then the wider
    /// window (the week beats the one-day row), then the earlier start — and
    /// `id` as the final tiebreak so the result never depends on input order.
    static func preferred(_ lhs: Offer, _ rhs: Offer, now: Date) -> Offer {
        // Offer dates are Berlin midnights; comparing against `now` directly
        // would call a row that expires today already invalid.
        let today = Calendar.supabase.startOfDay(for: now)
        func isCurrent(_ offer: Offer) -> Bool {
            offer.validFrom <= today && today <= offer.validUntil
        }
        if isCurrent(lhs) != isCurrent(rhs) {
            return isCurrent(lhs) ? lhs : rhs
        }
        let width = (
            lhs.validUntil.timeIntervalSince(lhs.validFrom),
            rhs.validUntil.timeIntervalSince(rhs.validFrom)
        )
        if width.0 != width.1 { return width.0 > width.1 ? lhs : rhs }
        if lhs.validFrom != rhs.validFrom {
            return lhs.validFrom < rhs.validFrom ? lhs : rhs
        }
        return lhs.id <= rhs.id ? lhs : rhs
    }

    /// Collapses rows published twice. The order of the survivors is the input
    /// order, so callers can still sort afterwards.
    static func deduplicated(_ offers: [Offer], now: Date = .now) -> [Offer] {
        var best: [String: Offer] = [:]
        var order: [String] = []
        for offer in offers {
            let key = duplicateKey(offer)
            if let incumbent = best[key] {
                best[key] = preferred(incumbent, offer, now: now)
            } else {
                best[key] = offer
                order.append(key)
            }
        }
        return order.compactMap { best[$0] }
    }

    /// Sections in display order. Market sections alphabetical; category
    /// sections follow the fixed `Categories.all` order.
    static func grouped(_ offers: [Offer], by grouping: OfferGrouping) -> [(key: String, offers: [Offer])] {
        switch grouping {
        case .market:
            let dict = Dictionary(grouping: offers, by: \.market)
            return dict.keys.sorted().compactMap { key in
                dict[key].map { (key: key, offers: $0) }
            }
        case .category:
            let dict = Dictionary(grouping: offers, by: \.category)
            var sections = Categories.all.compactMap { name in
                dict[name].map { (key: name, offers: $0) }
            }
            let known = Set(Categories.all)
            for key in dict.keys.sorted() where !known.contains(key) {
                guard let offers = dict[key] else { continue }
                sections.append((key: key, offers: offers))
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
    private var regions: [String] = []
    private var chains: [String] = []
    /// Branch ids of the chosen stores. Empty = show every branch (the state
    /// before a user has picked any, and the state of installs that predate
    /// the branch key).
    private var branchIds: [String] = []

    var isStale: Bool {
        isOffline || OfferCache.isStale(fetchedAt: fetchedAt)
    }

    /// True once loading finished with zero offers to show (region ready, but
    /// no matching offers) — distinct from `loading`, `error`, and `loaded`.
    /// Drives the friendly empty-state in the offer list.
    var isEmptyAfterLoad: Bool { state == .empty }

    /// Whether the user has restricted the list to specific Wunschmärkte.
    /// Lets the empty-state suggest picking other markets in the settings.
    var hasFavoriteChains: Bool { !chains.isEmpty }

    init(repository: OfferRepositoryProtocol, cache: OfferCache?) {
        self.repository = repository
        self.cache = cache
    }

    /// Shows cached offers for the regions immediately (if any), then refreshes.
    /// A single fetch spans all regions (offers query: `region=in.(...)`), so a
    /// user near a PLZ border sees favorites from every ready region at once.
    ///
    /// `branchIds` narrows the *display* to the chosen stores. The fetch and
    /// the cache stay per region on purpose: the cache is the complete tagged
    /// week of a region (KW-Cache), and which stores of it the user wants to
    /// see is a display question — the same reason the chain filter has always
    /// worked this way.
    func load(regions: [String], chains: [String], branchIds: [String] = []) async {
        self.regions = regions
        self.chains = chains
        self.branchIds = branchIds
        let cached = regions.compactMap { try? cache?.load(region: $0) }
        // The nationwide bucket rides along but is not part of the region
        // count below: a user whose chosen chains happen to include no
        // nationwide chain has an empty bucket, and that must not look like a
        // cold cache and force a fetch on every launch.
        let national = (try? cache?.load(region: nil)) ?? nil
        let cachedOffers = cached.flatMap(\.offers) + (national?.offers ?? [])
        if !cachedOffers.isEmpty {
            offers = display(cachedOffers)
            // The oldest region determines staleness of the combined list.
            fetchedAt = (cached.compactMap(\.fetchedAt) + [national?.fetchedAt].compactMap { $0 })
                .min()
            state = offers.isEmpty ? .empty : .loaded
        } else {
            state = .loading
        }
        // KW-Cache: skip the network while EVERY region has cached offers from
        // the current calendar week younger than maxAge; a week rollover or an
        // empty region forces a refresh.
        let cacheComplete = cached.count == regions.count
            && cached.allSatisfy { !$0.offers.isEmpty }
        if cacheComplete && !OfferCache.isStale(fetchedAt: fetchedAt) {
            return
        }
        await refresh()
    }

    /// Fetches the COMPLETE offer set of all regions in one query (no chain
    /// filter — the cache is the per-region KW dataset) and replaces the cache
    /// per region; display is narrowed to the favorited chains in memory.
    func refresh() async {
        guard !regions.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        // The regions this run is for. A second `load()` can change `regions`
        // while the fetch is in flight (user adds a PLZ, tab reappears); without
        // the comparison below the slower answer would win and the screen would
        // show offers for a region set the user has moved on from.
        let requested = regions
        do {
            let fresh = try await repository.offers(regions: requested)
            try Task.checkCancellation()
            guard requested == regions else { return }
            let now = Date.now
            // The cache keeps the RAW rows — it is the per-region KW dataset,
            // and dedupe is a display concern applied on read. Written before
            // `offers` for exactly that reason; don't fold the two together.
            let byRegion = Dictionary(grouping: fresh, by: \.region)
            for region in requested {
                try? cache?.replaceAll(byRegion[region] ?? [], region: region, fetchedAt: now)
            }
            // …plus the nationwide bucket. Rewritten on every refresh like any
            // other, so a week rollover clears it too.
            try? cache?.replaceAll(byRegion[nil] ?? [], region: nil, fetchedAt: now)
            offers = display(fresh)
            fetchedAt = now
            isOffline = false
            state = offers.isEmpty ? .empty : .loaded
        } catch {
            // A cancelled fetch is not a failure: `.task(id: regions)` restarts
            // this whenever the regions change and cancels the previous run, and
            // leaving the tab cancels it too. Treating that as "offline" put a
            // warning banner on perfectly fresh data.
            guard !LoadFailure.isCancellation(error) else { return }
            isOffline = true
            // Keep showing cached data; only surface the error when there is none.
            if offers.isEmpty {
                state = .error(LoadFailure.message(for: error, subject: "Die Angebote"))
            }
        }
    }

    /// The single funnel every offer takes on its way to the screen: narrowed
    /// to the chosen stores, then collapsed where a chain published the same
    /// offer twice. Both `offers` assignments go through here, so the Angebote
    /// list, the Top-Deals section and the shopping-list matcher — all of which
    /// read `store.offers` — see the same set.
    private func display(_ offers: [Offer]) -> [Offer] {
        OfferQuery.deduplicated(filteredToChosenStores(offers))
    }

    /// The cache stores every store of a region as fetched; narrow it for
    /// display.
    ///
    /// By branch when the user has chosen branches — that is the whole point of
    /// the branch key: in 01067 the chain filter shows all three REWE flyers at
    /// once (146 + 162 + 243 rows), the branch filter shows the one the user
    /// actually walks into.
    ///
    /// By chain otherwise, unchanged. That covers installs whose favourites
    /// were stored before the branch key and rows the backend pushed before
    /// migration v13 — dropping those silently would empty the screen for
    /// exactly the users who cannot see why.
    /// A nationwide row belongs to no branch and therefore to every branch of
    /// its chain — ALDI's `market_id` is `ALDI_NORD_DE`, never the branch the
    /// user picked. Matching it against the chosen branch ids would drop both
    /// ALDI chains off the screen; the chain rule is the right one for it.
    private func filteredToChosenStores(_ offers: [Offer]) -> [Offer] {
        let (nationwide, regional) = (
            offers.filter(\.isNationwide),
            offers.filter { !$0.isNationwide }
        )
        return filteredToChains(nationwide) + filteredToChosenBranches(regional)
    }

    private func filteredToChosenBranches(_ offers: [Offer]) -> [Offer] {
        if !branchIds.isEmpty {
            let chosen = Set(branchIds)
            let known = offers.filter { $0.marketId != nil }
            if !known.isEmpty {
                let byBranch = known.filter { chosen.contains($0.marketId ?? "") }
                // Rows without a branch id keep the chain rule, so a mixed
                // dataset (mid-migration) never loses a whole chain.
                let legacy = offers.filter { $0.marketId == nil }
                return byBranch + filteredToChains(legacy)
            }
        }
        return filteredToChains(offers)
    }

    private func filteredToChains(_ offers: [Offer]) -> [Offer] {
        guard !chains.isEmpty else { return offers }
        return offers.filter { chains.contains($0.market) }
    }
}
