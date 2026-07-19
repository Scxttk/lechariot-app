import SwiftUI

/// Branch picker ("Wunschmärkte"): one cross-chain, searchable list of all
/// branches in the user's regions, grouped by chain. Search matches chain,
/// branch name and PLZ. Chains without backend data (see
/// `MarketFilter.chainsWithoutData`) are listed but not selectable.
/// At least one selected branch is required to continue.
struct MarketPickerView: View {
    @Environment(RegionStore.self) private var store
    let plz: String
    let marketRepository: MarketRepositoryProtocol
    var onDone: () -> Void

    @State private var markets: [Market] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var query = ""

    /// All regions whose branches the picker offers — the current one plus
    /// every other ready region, so PLZ-border users pick across borders.
    private var plzs: [String] {
        var seen = Set<String>()
        return ([plz] + store.orderedReadyRegions).filter { seen.insert($0).inserted }
    }

    private var filtered: [Market] {
        MarketFilter.filter(markets, query: query)
    }

    /// Local branches grouped by chain, chains alphabetical, branches by name.
    private var chainGroups: [(chain: String, markets: [Market])] {
        Dictionary(grouping: filtered.filter { !$0.isNationwide }, by: \.chain)
            .map { (chain: $0.key, markets: $0.value.sorted { $0.branchName < $1.branchName }) }
            .sorted { $0.chain < $1.chain }
    }

    private var nationwideMarkets: [Market] {
        filtered.filter(\.isNationwide).sorted { $0.chain < $1.chain }
    }

    private var missingChains: [String] {
        MarketFilter.chainsWithoutData.filter { chain in
            query.trimmingCharacters(in: .whitespaces).isEmpty
                || chain.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private var hasAnyFavorites: Bool {
        !store.favoriteMarkets(in: plzs).isEmpty
    }

    var body: some View {
        List {
            Section {
                Label("Wähle deine Filialen – nur deren Angebote werden dir angezeigt.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(chainGroups, id: \.chain) { group in
                Section(group.chain) {
                    ForEach(group.markets) { marketRow($0) }
                }
            }

            if !nationwideMarkets.isEmpty {
                Section {
                    ForEach(nationwideMarkets) { marketRow($0) }
                } header: {
                    Text("Überregionale Angebote")
                } footer: {
                    Text("Filiale unbekannt – Angebote gelten deutschlandweit")
                }
            }

            if !missingChains.isEmpty {
                Section {
                    ForEach(missingChains, id: \.self) { chain in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chain)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text("Keine Daten verfügbar")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Image(systemName: "star.slash")
                                .foregroundStyle(.tertiary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(chain), keine Daten verfügbar, nicht wählbar")
                    }
                } footer: {
                    Text("Diese Kette veröffentlicht ihre Angebote nicht in einer Form, die Smartshop auslesen kann.")
                }
            }

            if filtered.isEmpty && !isLoading && !query.isEmpty {
                Section {
                    Text("Keine Filiale passt zu \u{201E}\(query)\u{201C}.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if markets.isEmpty && !isLoading && query.isEmpty {
                Section {
                    Text(errorMessage ?? "Für deine Regionen wurden noch keine Märkte gefunden.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if store.canAddRegion {
                Section {
                    NavigationLink {
                        AddRegionScreen()
                    } label: {
                        Label("Deine Filiale fehlt? Weitere PLZ hinzufügen", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Kette, Filiale oder PLZ")
        .overlay { if isLoading { ProgressView("Märkte werden geladen…") } }
        .navigationTitle("Filialen wählen")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { onDone() }
                    .disabled(!hasAnyFavorites)
            }
        }
        .task { await loadMarkets() }
        .refreshable { await loadMarkets() }
    }

    private func marketRow(_ market: Market) -> some View {
        let isFav = store.isFavorite(market)
        return Button {
            withAnimation { store.toggleFavorite(market) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(market.isNationwide ? market.chain : market.branchName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(market.isNationwide ? "Deutschlandweit" : "PLZ \(market.plz)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isFav ? "star.fill" : "star")
                    .foregroundStyle(isFav ? Color.yellow : Color.secondary)
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(market.chain), \(market.isNationwide ? "deutschlandweit" : market.branchName)"
        )
        .accessibilityValue(isFav ? "Wunschmarkt" : "kein Wunschmarkt")
        .accessibilityHint(isFav ? "Doppeltippen zum Entfernen" : "Doppeltippen zum Hinzufügen")
        .accessibilityAddTraits(isFav ? [.isSelected] : [])
    }

    private func loadMarkets() async {
        isLoading = true
        errorMessage = nil
        do {
            markets = try await marketRepository.markets(plzs: plzs)
        } catch {
            errorMessage = "Märkte konnten nicht geladen werden. Ziehe die Liste nach unten, um es erneut zu versuchen."
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        MarketPickerView(plz: "01219", marketRepository: MockMarketRepository(), onDone: {})
            .environment(RegionStore(repository: MockRegionRepository()))
    }
}
