import SwiftUI

struct ContentView: View {
    @Environment(RegionStore.self) private var store
    let marketRepository: MarketRepositoryProtocol

    var body: some View {
        if store.isOnboardingComplete {
            mainTabs
        } else {
            OnboardingFlowView(marketRepository: marketRepository)
        }
    }

    private var mainTabs: some View {
        TabView {
            offersTab
                .tabItem {
                    Label("Angebote", systemImage: "tag")
                }
            SettingsPlaceholderView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }

    @ViewBuilder
    private var offersTab: some View {
        if let plz = store.selectedRegion {
            OffersView(
                plz: plz,
                favoriteMarkets: store.favoriteMarkets(in: plz),
                repository: Self.offerRepository
            )
        } else {
            ContentUnavailableView("Keine Region ausgewählt", systemImage: "mappin.slash")
        }
    }

    /// Mirrors the live-or-mock fallback used in SmartshopApp for the other repositories.
    private static let offerRepository: OfferRepositoryProtocol = {
        if let client = SupabaseClient.fromConfig() {
            return LiveOfferRepository(client: client)
        }
        return MockOfferRepository()
    }()
}

struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Region") {
                    Text("Noch keine Region ausgewählt")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Einstellungen")
        }
    }
}

#Preview {
    ContentView(marketRepository: MockMarketRepository())
        .environment(RegionStore(repository: MockRegionRepository()))
}
