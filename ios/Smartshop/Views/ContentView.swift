import SwiftUI

struct ContentView: View {
    @Environment(RegionStore.self) private var store
    let marketRepository: MarketRepositoryProtocol

    @State private var shoppingList = ShoppingListStore()
    @State private var rejections = MatchRejectionStore()

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

            regionScoped { plz, markets in
                ShoppingListView(plz: plz, favoriteMarkets: markets, repository: Self.offerRepository)
            }
            .tabItem {
                Label("Einkaufsliste", systemImage: "checklist")
            }

            regionScoped { plz, markets in
                AnalyseView(plz: plz, favoriteMarkets: markets, repository: Self.offerRepository)
            }
            .tabItem {
                Label("Analyse", systemImage: "chart.bar.xaxis")
            }

            SettingsView(marketRepository: marketRepository)
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
        .environment(shoppingList)
        .environment(rejections)
        .tint(Theme.accent)
    }

    /// Angebote spans all ready regions with their favorites, so PLZ-border
    /// users see offers from every region they added.
    @ViewBuilder
    private var offersTab: some View {
        let regions = store.orderedReadyRegions
        if regions.isEmpty {
            ContentUnavailableView("Keine Region ausgewählt", systemImage: "mappin.slash")
        } else {
            OffersView(
                regions: regions,
                favoriteMarkets: store.favoriteMarkets(in: regions),
                repository: Self.offerRepository
            )
        }
    }

    /// All region-bound tabs share the same guard and inputs.
    @ViewBuilder
    private func regionScoped(
        @ViewBuilder content: (String, [Market]) -> some View
    ) -> some View {
        if let plz = store.selectedRegion {
            content(plz, store.favoriteMarkets(in: plz))
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

#Preview {
    ContentView(marketRepository: MockMarketRepository())
        .environment(RegionStore(repository: MockRegionRepository()))
}
