import SwiftUI

struct ContentView: View {
    @Environment(RegionStore.self) private var store
    let marketRepository: MarketRepositoryProtocol

    @State private var shoppingList = ShoppingListStore()
    @State private var rejections = MatchRejectionStore()
    /// Every cold start lands on the shopping list — that is the screen the app
    /// exists for. Deliberately not persisted: reopening the app mid-week must
    /// not drop the user wherever they happened to leave off.
    @State private var selectedTab: Tab = .liste

    private enum Tab {
        case liste, angebote, einstellungen
    }

    var body: some View {
        if store.isOnboardingComplete {
            mainTabs
        } else {
            OnboardingFlowView(marketRepository: marketRepository)
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            allRegionScoped { regions, markets in
                ShoppingListView(regions: regions, favoriteMarkets: markets, repository: Self.offerRepository)
            }
            .tabItem {
                Label("Liste", systemImage: "checklist")
            }
            .tag(Tab.liste)

            offersTab
                .tabItem {
                    Label("Angebote", systemImage: "tag")
                }
                .tag(Tab.angebote)

            SettingsView(marketRepository: marketRepository)
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                .tag(Tab.einstellungen)
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

    /// Einkaufsliste spans all ready regions, like Angebote — the chosen
    /// branches are the filter, not the selected region.
    @ViewBuilder
    private func allRegionScoped(
        @ViewBuilder content: ([String], [Market]) -> some View
    ) -> some View {
        let regions = store.orderedReadyRegions
        if regions.isEmpty {
            ContentUnavailableView("Keine Region ausgewählt", systemImage: "mappin.slash")
        } else {
            content(regions, store.favoriteMarkets(in: regions))
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
