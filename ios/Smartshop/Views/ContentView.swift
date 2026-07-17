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
            OffersPlaceholderView()
                .tabItem {
                    Label("Angebote", systemImage: "tag")
                }
            SettingsPlaceholderView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }
}

struct OffersPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "cart")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Angebote folgen in Kürze")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Smartshop")
        }
    }
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
