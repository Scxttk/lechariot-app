import SwiftUI

struct ContentView: View {
    var body: some View {
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
    ContentView()
}
