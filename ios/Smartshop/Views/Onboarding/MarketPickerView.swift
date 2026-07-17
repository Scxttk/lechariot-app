import SwiftUI

/// Second onboarding step: pick favorite markets ("Wunschmärkte") for a ready
/// region, grouped by chain. At least one is required to continue.
struct MarketPickerView: View {
    @Environment(RegionStore.self) private var store
    let plz: String
    let marketRepository: MarketRepositoryProtocol
    var onDone: () -> Void

    @State private var markets: [Market] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var localMarkets: [Market] {
        markets.filter { !$0.isNationwide }
            .sorted { ($0.chain, $0.branchName) < ($1.chain, $1.branchName) }
    }

    private var nationwideMarkets: [Market] {
        markets.filter(\.isNationwide).sorted { $0.chain < $1.chain }
    }

    private var hasFavoritesHere: Bool { !store.favoriteMarkets(in: plz).isEmpty }

    var body: some View {
        List {
            Section {
                Label("Wähle mindestens einen Wunschmarkt – nur dessen Angebote werden dir angezeigt.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !localMarkets.isEmpty {
                Section("Märkte in deiner Nähe") {
                    ForEach(localMarkets) { marketRow($0) }
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

            if markets.isEmpty && !isLoading {
                Section {
                    Text(errorMessage ?? "Für die PLZ \(plz) wurden noch keine Märkte gefunden.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if store.canAddRegion {
                Section {
                    NavigationLink {
                        AddRegionScreen()
                    } label: {
                        Label("Wohnst du nahe einer PLZ-Grenze? Weitere PLZ hinzufügen", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                }
            }
        }
        .overlay { if isLoading { ProgressView("Märkte werden geladen…") } }
        .navigationTitle("Wunschmärkte")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { onDone() }
                    .disabled(!hasFavoritesHere)
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
                    Text(market.chain)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(market.isNationwide ? "Deutschlandweit" : "\(market.branchName) · PLZ \(market.plz)")
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
            markets = try await marketRepository.markets(plzs: [plz])
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
