import SwiftUI

/// Angebote tab: cached-first offer list of the chosen branches. Decoupled
/// from RegionStore — it takes the markets, nothing else.
struct OffersView: View {
    let favoriteMarkets: [Market]

    /// Shared with the shopping list — see `ContentView.offerStore`.
    let store: OfferStore

    /// Only the detail sheet needs it, and only after a tap — defaulted so
    /// neither `ContentView` nor the preview has to know about it.
    var priceHistoryRepository: PriceHistoryRepositoryProtocol = AppRepositories.priceHistory

    @State private var search = ""
    @State private var selectedOffer: Offer?
    @State private var grouping: OfferGrouping = .market
    @State private var sort: OfferSort = .standard
    @State private var categoryFilter: String?
    @State private var marketFilter: String?

    private var chains: [String] {
        Array(Set(favoriteMarkets.map(\.chain))).sorted()
    }

    /// The chosen branches themselves. Since the backend keys offers by branch
    /// (migration v13), this is the filter that actually matches what the user
    /// picked — the chain list above only still exists for the section labels
    /// and the market filter menu.
    private var branchIds: [String] {
        favoriteMarkets.map(\.marketId).sorted()
    }

    var body: some View {
        NavigationStack {
            content
                .themedScreen()
                .navigationTitle("Angebote")
                .searchable(text: $search, prompt: "Produkt suchen")
                .toolbar { filterMenu }
                .sheet(item: $selectedOffer) { offer in
                    OfferDetailView(
                        offer: offer,
                        favoriteMarkets: favoriteMarkets,
                        historyRepository: priceHistoryRepository
                    )
                }
        }
        .task(id: branchIds) {
            await store.load(branchIds: branchIds, chains: chains)
        }
        // A market filter can outlive the branch it names — unfavourite Netto in
        // the settings and the Angebote tab was left filtering on a chain that no
        // longer has offers, i.e. permanently empty with no visible cause.
        .onChange(of: chains) { _, updated in
            if let marketFilter, !updated.contains(marketFilter) {
                self.marketFilter = nil
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .loading:
            // Skeleton matching the loaded list shape — no layout jump when
            // real offers arrive. Bare rows on purpose: a disabled Button would
            // dim the already-redacted placeholder a second time, and the list
            // carries its own "wird geladen" label below.
            List(Offer.skeleton) { OfferRowView(offer: $0).listRowBackground(Theme.surface) }
                .redacted(reason: .placeholder)
                .disabled(true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Angebote werden geladen")
        case .empty:
            emptyState
        case .error(let message):
            ContentUnavailableView {
                Label("Fehler beim Laden", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Erneut versuchen") {
                    Task { await store.refresh() }
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Theme.onAccent)
            }
        case .loaded:
            offerList
        }
    }

    /// Region is ready, but there are no offers to show. Guides the user toward
    /// picking other markets when the empty list is a consequence of their
    /// Wunschmärkte selection.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("Keine Angebote", systemImage: "basket")
        } description: {
            Text(store.hasFavoriteChains
                ? "Für deine Filialen liegen gerade keine Angebote vor. Nimm in den Einstellungen weitere Filialen dazu, um mehr zu sehen."
                : "Für deine Region liegen aktuell keine Angebote vor. Schau später noch einmal vorbei.")
        } actions: {
            // The empty state has no list, so there is nothing to pull down —
            // without this button a user who suspects a hiccup can only kill
            // the app and hope.
            Button("Erneut laden") {
                Task { await store.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .accessibilityLabel(store.hasFavoriteChains
            ? "Keine Angebote für deine Filialen"
            : "Keine Angebote für deine Region")
    }

    /// Everything was filtered away. Distinct from `emptyState`: here the data
    /// is fine and the user's own filter is in the way, so the fix is one tap.
    private var noFilterMatchState: some View {
        ContentUnavailableView {
            Label("Nichts für diesen Filter", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text("Für die gewählte Kategorie oder den gewählten Markt gibt es diese Woche keine Angebote.")
        } actions: {
            Button("Filter zurücksetzen") { resetFilters() }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Theme.onAccent)
        }
    }

    private func resetFilters() {
        categoryFilter = nil
        marketFilter = nil
        sort = .standard
    }

    private var offerList: some View {
        List {
            if store.isStale {
                staleBanner
            }
            let visible = OfferQuery.apply(
                store.offers, search: search,
                category: categoryFilter, market: marketFilter, sort: sort
            )
            if visible.isEmpty {
                // Two different dead ends that used to look identical: an empty
                // search still rendered the search-empty view, which reads as
                // "Keine Ergebnisse für ‚‘" when only a filter was to blame.
                if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    noFilterMatchState
                }
            } else {
                topDealsSection
                ForEach(Array(OfferQuery.grouped(visible, by: grouping).enumerated()), id: \.element.key) { index, section in
                    Section(sectionTitle(section.key)) {
                        ForEach(section.offers) { offerRow($0) }
                    }
                    .listRowBackground(Theme.surface)
                    // Reserved ad position: after the first market section, so a
                    // creative can never be read as part of a group. Renders
                    // nothing today — see `AdSlot`.
                    if index == 0 {
                        AdSlotView(slot: .offerListInline)
                    }
                }
            }
        }
        .refreshable { await store.refresh() }
    }

    /// A row whose whole width opens the detail sheet.
    ///
    /// The Button owns the accessibility element — no
    /// `.accessibilityElement(children: .ignore)` anywhere in this chain, or
    /// the label below is swallowed (see `OfferRowView`). `TactileButtonStyle`
    /// brings its own `.contentShape(Rectangle())`, so the gap between product
    /// text and price is tappable too.
    private func offerRow(_ offer: Offer) -> some View {
        Button {
            selectedOffer = offer
        } label: {
            OfferRowView(offer: offer)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel(offer.voiceOverSummary)
        .accessibilityHint("Zeigt Details und Preisverlauf")
        // Stable handle for the UI journeys — the label itself is a whole
        // sentence built from whichever offer happens to be live.
        .accessibilityIdentifier("offers.row")
    }

    /// The five deepest discounts, pinned above the grouped list. Hidden as
    /// soon as the user searches or filters — then they are looking for
    /// something specific and a "best of" list is only in the way.
    @ViewBuilder
    private var topDealsSection: some View {
        let isBrowsing = search.isEmpty && !hasActiveFilter
        let deals = isBrowsing ? OfferAnalytics.topDeals(store.offers, limit: 5) : []
        if !deals.isEmpty {
            Section {
                ForEach(deals) { offerRow($0) }
            } header: {
                Text("Top-Deals der Woche")
            }
            .listRowBackground(Theme.surface)
        }
    }

    private var staleBanner: some View {
        Label(
            store.isOffline
                ? "Offline – zeige zuletzt geladene Angebote"
                : "Angebote sind möglicherweise veraltet",
            systemImage: "exclamationmark.triangle"
        )
        .font(.footnote)
        .foregroundStyle(Theme.warning)
        .listRowBackground(Theme.warningSurface)
    }

    /// Market sections show the branch name when the chain has exactly one
    /// favorited branch across the shown regions.
    private func sectionTitle(_ key: String) -> String {
        guard grouping == .market else { return key }
        return Market.displayTitle(chain: key, favorites: favoriteMarkets)
    }

    private var filterMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Gruppierung", selection: $grouping) {
                    ForEach(OfferGrouping.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Sortierung", selection: $sort) {
                    ForEach(OfferSort.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Kategorie", selection: $categoryFilter) {
                    Text("Alle Kategorien").tag(String?.none)
                    ForEach(Categories.all, id: \.self) { Text($0).tag(String?.some($0)) }
                }
                Picker("Markt", selection: $marketFilter) {
                    Text("Alle Märkte").tag(String?.none)
                    ForEach(chains, id: \.self) { Text($0).tag(String?.some($0)) }
                }
            } label: {
                Label("Filter", systemImage: hasActiveFilter
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
            }
        }
    }

    private var hasActiveFilter: Bool {
        categoryFilter != nil || marketFilter != nil || sort == .deals
    }
}

#Preview {
    OffersView(
        favoriteMarkets: MockFixtures.markets,
        store: OfferStore(repository: MockOfferRepository(), cache: nil),
        priceHistoryRepository: MockPriceHistoryRepository()
    )
}
