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
    private var chains: [String] = []
    /// Branch ids of the chosen stores — what is fetched AND what is shown.
    /// Empty = nothing to ask for; the screen stays in its empty state with a
    /// route into the settings.
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

    /// Shows the cached offers immediately (if any), then refreshes.
    ///
    /// Asked for by **branch**, not by postcode. A postcode fetched every store
    /// in it — in 01067 that is three REWE flyers at once (146 + 162 + 243
    /// rows), of which the user walks into one. `chains` only still exists for
    /// the section labels and the market filter menu.
    func load(branchIds: [String], chains: [String]) async {
        self.branchIds = branchIds
        self.chains = chains
        guard !branchIds.isEmpty else {
            offers = []
            state = .empty
            return
        }
        let cached = (try? cache?.load()) ?? nil
        let cachedOffers = cached?.offers ?? []
        if !cachedOffers.isEmpty {
            offers = display(cachedOffers)
            fetchedAt = cached?.fetchedAt
            state = offers.isEmpty ? .empty : .loaded
        } else {
            state = .loading
        }
        // KW-Cache: skip the network while the cache holds this week's answer
        // for exactly this set of branches. A week rollover, an empty cache or
        // a changed selection all force a refresh.
        // A different selection makes the cache incomplete even when it is
        // fresh — otherwise a newly picked store showed nothing until the next
        // calendar week.
        if !cachedOffers.isEmpty
            && cache?.cachedBranchIds == branchIds
            && !OfferCache.isStale(fetchedAt: fetchedAt) {
            return
        }
        await refresh()
    }

    /// Fetches the COMPLETE offer set of the chosen branches in one query (no
    /// chain filter — the cache is the whole tagged week of those branches) and
    /// replaces the cache; display narrowing happens in memory.
    func refresh() async {
        guard !branchIds.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        // The branches this run is for. A second `load()` can change them while
        // the fetch is in flight (user picks another store, tab reappears);
        // without the comparison below the slower answer would win and the
        // screen would show stores the user has moved on from.
        let requested = branchIds
        do {
            let fresh = try await repository.offers(branchIds: requested)
            try Task.checkCancellation()
            guard requested == branchIds else { return }
            let now = Date.now
            // The cache keeps the RAW rows — dedupe is a display concern
            // applied on read. Written before `offers` for exactly that reason;
            // don't fold the two together.
            try? cache?.replaceAll(fresh, branchIds: requested, fetchedAt: now)
            offers = display(fresh)
            fetchedAt = now
            isOffline = false
            state = offers.isEmpty ? .empty : .loaded
        } catch {
            // A cancelled fetch is not a failure: `.task(id: branchIds)`
            // restarts this whenever the selection changes and cancels the
            // previous run, and leaving the tab cancels it too. Treating that
            // as "offline" put a warning banner on perfectly fresh data.
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
