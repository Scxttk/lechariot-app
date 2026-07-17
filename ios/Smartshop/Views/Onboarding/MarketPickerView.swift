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

    private var grouped: [(chain: String, markets: [Market])] {
        Dictionary(grouping: markets, by: \.chain)
            .map { (chain: $0.key, markets: $0.value.sorted { $0.branchName < $1.branchName }) }
            .sorted { $0.chain < $1.chain }
    }

    private var hasFavoritesHere: Bool { !store.favoriteMarkets(in: plz).isEmpty }

    var body: some View {
        List {
            Section {
                Label("Wähle mindestens einen Wunschmarkt – nur dessen Angebote werden dir angezeigt.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(grouped, id: \.chain) { group in
                Section(group.chain) {
                    ForEach(group.markets) { market in
                        marketRow(market)
                    }
                }
            }

            if markets.isEmpty && !isLoading {
                Section {
                    Text(errorMessage ?? "Für die PLZ \(plz) wurden noch keine Märkte gefunden.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                    Text(market.branchName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("PLZ \(market.plz)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isFav ? "star.fill" : "star")
                    .foregroundStyle(isFav ? Color.yellow : Color.secondary)
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
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
