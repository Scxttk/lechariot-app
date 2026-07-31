import SwiftUI

/// Einstellungen tab: manage regions (PLZs) and branches, reusing the
/// onboarding components; plus the profile, appearance and app info.
struct SettingsView: View {
    @Environment(RegionStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(ShoppingListStore.self) private var list
    @Environment(MatchRejectionStore.self) private var rejections
    @Environment(MatchFeedbackStore.self) private var feedback
    @Environment(TutorialStore.self) private var tutorial
    @Environment(AreaRequestStore.self) private var areaRequests
    @Environment(BranchRequestStore.self) private var branchRequests
    @AppStorage(Theme.appearanceKey, store: AppDefaults.shared)
    private var appearance: AppAppearance = .system
    let marketRepository: MarketRepositoryProtocol

    @State private var showResetConfirmation = false
    @State private var regionToRemove: String?

    var body: some View {
        NavigationStack {
            List {
                Group {
                    marketSection
                    // Direkt unter den Filialen, nicht ganz unten: Der letzte
                    // Rahmen des Rundgangs zeigt auf beide Abschnitte, und
                    // dafür müssen sie ohne Scrollen zusammen sichtbar sein.
                    helpSection
                    regionSection
                    profileSection
                    feedbackSection
                    appearanceSection
                    appSection
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
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(market.chain)
                            .font(.body.weight(.medium))
                        // Dieselbe Dopplung wie im Picker, nur eine Zeile
                        // tiefer: Die Überschrift der Zeile ist der
                        // Kettenname, und „Penny Am Haff" darunter schreibt
                        // ihn noch einmal. Am 2026-07-31 mit dem Picker
                        // zusammen gekürzt — den halben Fehler zu beheben
                        // liest sich später wie Absicht.
                        Text(market.isNationwide
                            ? "Deutschlandweit"
                            : "\(MarketFilter.branchLabel(name: market.branchName, chain: market.chain)) · PLZ \(market.plz)")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    // Bis hierher gab es überhaupt keinen Weg, eine Filiale
                    // wieder loszuwerden — nur zurück in den Picker und dort
                    // abwählen. Wer nach einem Umzug eine falsch gewordene
                    // Filiale stehen hat, sucht sie aber hier.
                    // „Penny Am Haff entfernen", nicht „Penny Penny Am Haff
                    // entfernen": Die Kette gehört ins Label — es ist der
                    // einzige Ort, an dem VoiceOver sie hier hört —, aber
                    // eben nur einmal.
                    removeButton(
                        "\(market.chain) "
                        + "\(MarketFilter.branchLabel(name: market.branchName, chain: market.chain))"
                        + " entfernen"
                    ) {
                        store.toggleFavorite(market)
                    }
                }
            }
            if let plz = store.regions.first {
                NavigationLink {
                    EditMarketsScreen(plz: plz, marketRepository: marketRepository)
                } label: {
                    Label("Filialen bearbeiten", systemImage: "storefront")
                        .foregroundStyle(Theme.accent)
                }
                // Der Anker sitzt auf der Zeile, nicht auf dem Abschnitt: Ein
                // `Section` reicht den Modifikator an jede Zeile einzeln durch,
                // und übrig blieb der Fußtext statt der Filialen.
                .tutorialAnchor(.settingsMarkets)
            } else {
                // Ohne Region verschwand dieser Link ersatzlos — und mit ihm
                // der einzige Weg zu den Filialen. Eine Sackgasse, aus der nur
                // der Weg über einen anderen Abschnitt herausführte.
                NavigationLink {
                    AddRegionScreen()
                } label: {
                    Label("Region hinzufügen, um Filialen zu wählen", systemImage: "plus")
                        .foregroundStyle(Theme.accent)
                }
                .tutorialAnchor(.settingsMarkets)
            }
        } header: {
            Text("Deine Filialen")
        } footer: {
            Text(branches.isEmpty
                 ? "Ohne gewählte Filiale werden keine Angebote angezeigt."
                 : "Nur Angebote dieser Filialen zählen für deine Liste.")
        }
    }

    /// Ein sichtbarer Papierkorb statt einer Wischgeste.
    ///
    /// Beides zusammen ginge auch, aber `.swipeActions` auf einer Zeile mit
    /// flachem `.listRowBackground` zieht während der Animation eine rechteckige
    /// Kante durch den runden Container — und eine Geste, die im Fußtext erklärt
    /// werden muss, hat ihren Zweck ohnehin verfehlt.
    ///
    /// `Theme.error`, nie System-Rot: das gemessene Kontrastproblem auf der
    /// cremefarbenen Fläche.
    private func removeButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation { action() }
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(Theme.error)
        }
        .buttonStyle(.borderless)
        // Ohne Label liest VoiceOver „Papierkorb" vor — und lässt offen,
        // welche der gleich aussehenden Zeilen daran hängt.
        .accessibilityLabel(label)
    }

    // MARK: Hilfe

    private var helpSection: some View {
        Section {
            Button {
                tutorial.start()
            } label: {
                Label("Rundgang erneut ansehen", systemImage: "sparkles")
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityIdentifier("settings.tutorial")
            .tutorialAnchor(.settingsHelp)

            // Der Notausgang, und ab 2026-07-30 in **jedem** Build. Vorher gab
            // es ihn nur unter `#if DEBUG`; wer in TestFlight feststeckte,
            // konnte die App nur löschen und neu installieren. Genau die
            // Tester, die das am ehesten bräuchten — Scotts Großeltern —, sind
            // die, denen man es am schwersten erklärt.
            //
            // Ganz unten in der Sektion und mit Rückfrage: Er steht neben einem
            // Knopf, den man aus Neugier drückt, und tut etwas Endgültiges.
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("App zurücksetzen", systemImage: "arrow.counterclockwise")
                    .foregroundStyle(Theme.error)
            }
            .accessibilityIdentifier("settings.reset")
            .confirmationDialog(
                "App zurücksetzen?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Zurücksetzen", role: .destructive) {
                    AppReset.everything(
                        regions: store,
                        profile: profile,
                        list: list,
                        rejections: rejections,
                        feedback: feedback,
                        tutorial: tutorial,
                        areaRequests: areaRequests,
                        branchRequests: branchRequests
                    )
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Deine Filialen, deine Einkaufsliste und deine Angaben aus dem Onboarding werden gelöscht. Danach startet Le Chariot wie nach einer Neuinstallation.")
            }
        } header: {
            Text("Hilfe")
        } footer: {
            Text("Der Rundgang zeigt die kurze Einführung auf der Einkaufsliste noch einmal; Le Chariot legt dafür ein paar Beispiel-Artikel auf die Liste und räumt sie danach wieder ab. Zurücksetzen hilft, wenn etwas hakt — es löscht alles, was auf dem Gerät liegt.")
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
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PLZ \(plz)")
                            .font(.body.weight(.medium))
                        syncStateLabel(store.syncState(for: plz))
                    }
                    Spacer()
                    removeButton("PLZ \(plz) entfernen") { regionToRemove = plz }
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
            Text("Angebote sind regional. Wohnst du an einer PLZ-Grenze, füge die Nachbar-PLZ hinzu — dann kannst du auch dort Filialen wählen.")
        }
        .confirmationDialog(
            regionToRemove.map { "PLZ \($0) entfernen?" } ?? "",
            isPresented: Binding(
                get: { regionToRemove != nil },
                set: { if !$0 { regionToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Entfernen", role: .destructive) {
                if let plz = regionToRemove { withAnimation { store.removeRegion(plz) } }
                regionToRemove = nil
            }
            Button("Abbrechen", role: .cancel) { regionToRemove = nil }
        } message: {
            // Sagt, was *nicht* passiert. Genau daran hing die Verwirrung: Wer
            // umzieht, erwartet, dass mit der PLZ auch die dortigen Filialen
            // gehen — und die App kann eine vergessene nicht von einer bewusst
            // über die Grenze gewählten unterscheiden.
            Text(store.regions.count == 1
                 ? "Deine gewählten Filialen bleiben. Ohne Region kannst du allerdings keine neuen suchen."
                 : "Deine gewählten Filialen bleiben — die entfernst du einzeln unter „Deine Filialen“.")
        }
    }

    @ViewBuilder
    private func syncStateLabel(_ state: RegionSyncState) -> some View {
        switch state {
        case .ready:
            Text("Bereit")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        case .unknown:
            Text("Noch nicht geprüft")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
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
                 ? "Deine Angaben helfen bei der Weiterentwicklung und werden anonym übermittelt. Vorname und Einkaufsliste bleiben auf dem Gerät."
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

    // MARK: Rückfragen

    private var feedbackSection: some View {
        @Bindable var feedback = feedback
        return Section {
            Toggle("Nach Ablehnungen fragen", isOn: $feedback.isAskingEnabled)
                .tint(Theme.accent)
        } header: {
            Text("Rückfragen")
        } footer: {
            Text(feedback.isAskingEnabled
                 ? "Wenn du einen Treffer weglegst, fragt Le Chariot kurz nach dem Grund. Das ist der einzige Weg, wie falsche Treffer gefunden und behoben werden. Überspringen geht immer."
                 : "Weglegen funktioniert unverändert. Es wird nicht gefragt und nichts übertragen.")
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
            // Endmarke für den Kontrast-Audit, der ans Ende der Liste scrollen
            // muss, bevor er misst. Ein Bezeichner und kein Text: Die Marke war
            // zweimal deutsche Prosa und ist zweimal gebrochen, als die Prosa
            // sich änderte — zuletzt am 2026-07-30, als der Debug-Abschnitt
            // wegfiel, dessen Fußzeile sie war.
            LabeledContent("Angebote", value: "wöchentlich aktualisiert")
                .accessibilityIdentifier("settings.end")
            // Reserved ad position — see `AdSlot`. Lowest-value slot, kept as the
            // natural home for a house ad (e.g. a werbefreie Variante).
            AdSlotView(slot: .settingsFooter)
        }
    }

    private static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "–"
    }

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
                                let branchIds = store.favoriteMarkets.map(\.marketId)
                                Task { await profile.sync(plz: plz, branchIds: branchIds) }
                            }
                        }
                    ))
                    .tint(Theme.accent)
                } footer: {
                    Text("Übermittelt werden Haushaltsgröße, Einkaufsrhythmus, Budget-Rahmen, Ernährungsangaben, Postleitzahl und die gewählten Filialen — verknüpft mit einer Zufallsnummer, nicht mit dir. Vorname und Einkaufsliste bleiben auf dem Gerät.")
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
        .environment(RegionStore())
        .environment(ProfileStore())
        .environment(ShoppingListStore())
        .environment(MatchRejectionStore())
        .environment(MatchFeedbackStore())
        .environment(TutorialStore())
        .environment(AreaRequestStore(repository: MockAreaRequestRepository()))
        .environment(BranchRequestStore(repository: MockBranchRequestRepository()))
}
