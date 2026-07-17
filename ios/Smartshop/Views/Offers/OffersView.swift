import SwiftUI

/// Angebote tab: cached-first offer list across all ready regions, restricted
/// to the user's Wunschmärkte. Decoupled from RegionStore — takes regions + markets.
struct OffersView: View {
    let regions: [String]
    let favoriteMarkets: [Market]

    @State private var store: OfferStore
    @State private var search = ""
    @State private var grouping: OfferGrouping = .market
    @State private var sort: OfferSort = .standard
    @State private var categoryFilter: String?
    @State private var marketFilter: String?

    init(regions: [String], favoriteMarkets: [Market], repository: OfferRepositoryProtocol) {
        self.regions = regions
        self.favoriteMarkets = favoriteMarkets
        _store = State(initialValue: OfferStore(repository: repository, cache: try? OfferCache()))
    }

    private var chains: [String] {
        Array(Set(favoriteMarkets.map(\.chain))).sorted()
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Angebote")
                .searchable(text: $search, prompt: "Produkt suchen")
                .toolbar { filterMenu }
        }
        .task(id: regions) { await store.load(regions: regions, chains: chains) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .loading:
            ProgressView("Angebote werden geladen…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView(
                "Keine Angebote",
                systemImage: "tag.slash",
                description: Text("Für deine Region und Märkte liegen aktuell keine Angebote vor.")
            )
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
            }
        case .loaded:
            offerList
        }
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
                ContentUnavailableView.search(text: search)
            } else {
                ForEach(OfferQuery.grouped(visible, by: grouping), id: \.key) { section in
                    Section(sectionTitle(section.key)) {
                        ForEach(section.offers) { OfferRowView(offer: $0) }
                    }
                }
            }
        }
        .refreshable { await store.refresh() }
    }

    private var staleBanner: some View {
        Label(
            store.isOffline
                ? "Offline – zeige zuletzt geladene Angebote"
                : "Angebote sind möglicherweise veraltet",
            systemImage: "exclamationmark.triangle"
        )
        .font(.footnote)
        .foregroundStyle(.orange)
        .listRowBackground(Color.orange.opacity(0.12))
    }

    /// Market sections show the branch name when the chain has exactly one
    /// favorited branch across the shown regions.
    private func sectionTitle(_ key: String) -> String {
        guard grouping == .market else { return key }
        let branches = favoriteMarkets.filter { $0.chain == key }
        if branches.count == 1, !branches[0].branchName.isEmpty {
            return "\(key) – \(branches[0].branchName)"
        }
        return key
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
        regions: ["01219"],
        favoriteMarkets: MockFixtures.markets,
        repository: MockOfferRepository()
    )
}
