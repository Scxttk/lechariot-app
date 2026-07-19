import SwiftUI

/// Einstellungen tab: manage regions (PLZs) and Wunschmärkte, reusing the
/// onboarding components; plus app/data info.
struct SettingsView: View {
    @Environment(RegionStore.self) private var store
    @AppStorage(Theme.appearanceKey) private var appearance: AppAppearance = .system
    let marketRepository: MarketRepositoryProtocol

    var body: some View {
        NavigationStack {
            List {
                Group {
                    regionSection
                    if let plz = store.selectedRegion {
                        marketSection(plz: plz)
                    }
                    appearanceSection
                    appSection
                }
                .listRowBackground(Theme.surface)
            }
            .themedScreen()
            .navigationTitle("Einstellungen")
        }
    }

    // MARK: Regionen

    private var regionSection: some View {
        Section {
            ForEach(store.regions, id: \.self) { plz in
                regionRow(plz)
            }
            NavigationLink {
                AddRegionScreen()
            } label: {
                Label("Region hinzufügen", systemImage: "plus")
                    .foregroundStyle(store.canAddRegion ? Theme.accent : Color.secondary)
            }
            .disabled(!store.canAddRegion)
        } header: {
            Text("Regionen")
        } footer: {
            Text("Die ausgewählte Region bestimmt, welche Angebote du siehst. Wische nach links, um eine Region zu entfernen.")
        }
    }

    private func regionRow(_ plz: String) -> some View {
        Button {
            store.selectRegion(plz)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLZ \(plz)")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    syncStateLabel(store.syncState(for: plz))
                }
                Spacer()
                if store.selectedRegion == plz {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { store.removeRegion(plz) }
            } label: {
                Label("Entfernen", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func syncStateLabel(_ state: RegionSyncState) -> some View {
        switch state {
        case .ready:
            Text("Bereit")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .requested, .syncing:
            Text("Wird synchronisiert …")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed:
            Text("Synchronisierung fehlgeschlagen")
                .font(.caption)
                .foregroundStyle(.red)
        case .unknown:
            Text("Noch nicht geprüft")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: Wunschmärkte

    private func marketSection(plz: String) -> some View {
        let favorites = store.favoriteMarkets(in: plz)
        return Section {
            ForEach(favorites) { market in
                VStack(alignment: .leading, spacing: 2) {
                    Text(market.chain)
                        .font(.body.weight(.medium))
                    Text(market.branchName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink {
                EditMarketsScreen(plz: plz, marketRepository: marketRepository)
            } label: {
                Label("Märkte bearbeiten", systemImage: "storefront")
                    .foregroundStyle(Theme.accent)
            }
        } header: {
            Text("Wunschmärkte – PLZ \(plz)")
        } footer: {
            if favorites.isEmpty {
                Text("Ohne Wunschmarkt werden keine Angebote angezeigt.")
            }
        }
    }

    // MARK: Darstellung

    private var appearanceSection: some View {
        Section("Darstellung") {
            Picker("Erscheinungsbild", selection: $appearance) {
                ForEach(AppAppearance.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: App

    private var appSection: some View {
        Section("App") {
            LabeledContent("Version", value: Self.appVersion)
            LabeledContent("Datenquelle", value: "Supabase · wöchentliche Angebote")
        }
    }

    private static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "–"
    }
}

// MARK: - Subscreens (onboarding components reused)

/// Wraps MarketPickerView so "Fertig" pops back to the settings list.
private struct EditMarketsScreen: View {
    @Environment(\.dismiss) private var dismiss
    let plz: String
    let marketRepository: MarketRepositoryProtocol

    var body: some View {
        MarketPickerView(plz: plz, marketRepository: marketRepository, onDone: { dismiss() })
    }
}

#Preview {
    SettingsView(marketRepository: MockMarketRepository())
        .environment(RegionStore(repository: MockRegionRepository()))
}
