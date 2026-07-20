import SwiftUI

/// Einstellungen tab: manage regions (PLZs) and branches, reusing the
/// onboarding components; plus the profile, appearance and app info.
struct SettingsView: View {
    @Environment(RegionStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(ShoppingListStore.self) private var list
    @Environment(MatchRejectionStore.self) private var rejections
    @AppStorage(Theme.appearanceKey, store: AppDefaults.shared)
    private var appearance: AppAppearance = .system
    let marketRepository: MarketRepositoryProtocol

    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Group {
                    marketSection
                    regionSection
                    profileSection
                    appearanceSection
                    appSection
                    #if DEBUG
                    debugSection
                    #endif
                }
                .listRowBackground(Theme.surface)
            }
            .themedScreen()
            .navigationTitle("Einstellungen")
        }
    }

    // MARK: Filialen

    /// The branches are what the app actually filters on, so they come first.
    private var marketSection: some View {
        let branches = store.favoriteMarkets
            .sorted { ($0.chain, $0.branchName) < ($1.chain, $1.branchName) }
        return Section {
            ForEach(branches) { market in
                VStack(alignment: .leading, spacing: 2) {
                    Text(market.chain)
                        .font(.body.weight(.medium))
                    Text(market.isNationwide
                        ? "Deutschlandweit"
                        : "\(market.branchName) · PLZ \(market.plz)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let plz = store.regions.first {
                NavigationLink {
                    EditMarketsScreen(plz: plz, marketRepository: marketRepository)
                } label: {
                    Label("Filialen bearbeiten", systemImage: "storefront")
                        .foregroundStyle(Theme.accent)
                }
            }
        } header: {
            Text("Deine Filialen")
        } footer: {
            Text(branches.isEmpty
                 ? "Ohne gewählte Filiale werden keine Angebote angezeigt."
                 : "Nur Angebote dieser Filialen zählen für deine Liste.")
        }
    }

    // MARK: Regionen

    /// Regions are pure status now. There used to be a checkmark picking one
    /// "selected" region, but list, offers and ranking all query every ready
    /// region — the chosen branches are the filter, so the checkmark selected
    /// nothing and only invited the user to fiddle with it.
    private var regionSection: some View {
        Section {
            ForEach(store.regions, id: \.self) { plz in
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLZ \(plz)")
                        .font(.body.weight(.medium))
                    syncStateLabel(store.syncState(for: plz))
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation { store.removeRegion(plz) }
                    } label: {
                        Label("Entfernen", systemImage: "trash")
                    }
                }
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
            Text("Angebote sind regional. Wohnst du an einer PLZ-Grenze, füge die Nachbar-PLZ hinzu — dann kannst du auch dort Filialen wählen. Wische nach links, um eine Region zu entfernen.")
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
            Text("Wird vorbereitet …")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed:
            Text("Vorbereitung fehlgeschlagen")
                .font(.caption)
                .foregroundStyle(Theme.error)
        case .unknown:
            Text("Noch nicht geprüft")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Profil

    private var profileSection: some View {
        Section {
            NavigationLink {
                ProfileEditScreen()
            } label: {
                LabeledContent("Dein Profil", value: profileSummary)
            }
        } header: {
            Text("Profil")
        } footer: {
            Text(profile.hasConsented
                 ? "Deine Angaben helfen bei der Weiterentwicklung und werden anonym übermittelt. Vorname, Einkaufsliste und Filialen bleiben auf dem Gerät."
                 : "Deine Angaben bleiben vollständig auf diesem Gerät.")
        }
    }

    private var profileSummary: String {
        let size = profile.profile.householdSize
        var parts = [size == 1 ? "1 Person" : "\(size) Personen"]
        parts.append("\(profile.profile.rhythm.label)/Woche")
        if !profile.profile.dietTags.isEmpty {
            parts.append("\(profile.profile.dietTags.count) Angaben")
        }
        return parts.joined(separator: " · ")
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
            LabeledContent("Angebote", value: "wöchentlich aktualisiert")
            // Reserved ad position — see `AdSlot`. Lowest-value slot, kept as the
            // natural home for a house ad (e.g. a werbefreie Variante).
            AdSlotView(slot: .settingsFooter)
        }
    }

    private static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "–"
    }

    // MARK: Debug

    #if DEBUG
    /// Only compiled into debug builds — a release build has no reset button and
    /// no code path leading to one.
    private var debugSection: some View {
        Section {
            Button("Onboarding zurücksetzen", systemImage: "arrow.counterclockwise", role: .destructive) {
                showResetConfirmation = true
            }
            .foregroundStyle(Theme.error)
            .confirmationDialog(
                "Alles zurücksetzen?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Zurücksetzen", role: .destructive) {
                    DebugReset.everything(
                        regions: store, profile: profile,
                        list: list, rejections: rejections
                    )
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Regionen, Filialen, Profil, Einkaufsliste, abgelehnte Treffer und der Angebots-Cache werden gelöscht. Die App startet danach beim Willkommensbildschirm.")
            }
        } header: {
            Text("Debug")
        } footer: {
            Text("Nur in Entwicklungs-Builds sichtbar.")
        }
    }
    #endif
}

// MARK: - Subscreens

/// Wraps MarketPickerView so "Fertig" pops back to the settings list.
private struct EditMarketsScreen: View {
    @Environment(\.dismiss) private var dismiss
    let plz: String
    let marketRepository: MarketRepositoryProtocol

    var body: some View {
        MarketPickerView(plz: plz, marketRepository: marketRepository, onDone: { dismiss() })
    }
}

/// Edits the onboarding answers after the fact, including the consent toggle.
private struct ProfileEditScreen: View {
    @Environment(ProfileStore.self) private var profile
    @Environment(RegionStore.self) private var store

    @State private var name = ""

    var body: some View {
        List {
            Group {
                Section("Name") {
                    TextField("Vorname", text: $name)
                        .textContentType(.givenName)
                        // Saved as it is typed. It used to be written on submit
                        // and on disappear, which loses the edit whenever iOS
                        // kills the app in the background — and every other
                        // field on this screen already saves immediately, so
                        // the name was the odd one out.
                        .onChange(of: name) { _, edited in profile.setFirstName(edited) }
                }

                Section("Haushalt") {
                    Stepper(
                        profile.profile.householdSize == 1
                            ? "1 Person"
                            : "\(profile.profile.householdSize) Personen",
                        value: Binding(
                            get: { profile.profile.householdSize },
                            set: { profile.setHousehold(size: $0) }
                        ),
                        in: 1...10
                    )
                    Picker("Einkäufe pro Woche", selection: Binding(
                        get: { profile.profile.rhythm },
                        set: { profile.setRhythm($0) }
                    )) {
                        ForEach(ShoppingRhythm.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Wochenbudget", selection: Binding(
                        get: { profile.profile.budget },
                        set: { profile.setBudget($0) }
                    )) {
                        Text("Keine Angabe").tag(BudgetBracket?.none)
                        ForEach(BudgetBracket.allCases) { Text($0.label).tag(BudgetBracket?.some($0)) }
                    }
                }

                Section("Ernährung") {
                    ForEach(DietTag.allCases) { tag in
                        Button {
                            profile.toggleDietTag(tag)
                        } label: {
                            HStack {
                                Label(tag.label, systemImage: tag.symbol)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if profile.profile.dietTags.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                        }
                        .accessibilityAddTraits(
                            profile.profile.dietTags.contains(tag) ? [.isSelected] : []
                        )
                    }
                }

                Section {
                    Toggle("Angaben anonym übermitteln", isOn: Binding(
                        get: { profile.hasConsented },
                        set: { consented in
                            profile.setConsent(consented)
                            if consented {
                                let plz = store.orderedReadyRegions.first
                                Task { await profile.sync(plz: plz) }
                            }
                        }
                    ))
                    .tint(Theme.accent)
                } footer: {
                    Text("Übermittelt werden Haushaltsgröße, Einkaufsrhythmus, Budget-Rahmen, Ernährungsangaben und Postleitzahl — verknüpft mit einer Zufallsnummer, nicht mit dir. Vorname, Einkaufsliste und Filialen bleiben auf dem Gerät.")
                }
            }
            .listRowBackground(Theme.surface)
        }
        .themedScreen()
        .navigationTitle("Dein Profil")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = profile.profile.firstName }
    }
}

#Preview {
    SettingsView(marketRepository: MockMarketRepository())
        .environment(RegionStore(repository: MockRegionRepository()))
        .environment(ProfileStore())
        .environment(ShoppingListStore())
        .environment(MatchRejectionStore())
}
