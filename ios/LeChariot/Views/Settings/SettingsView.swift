import SwiftUI
import UIKit

/// Einstellungen: Filialen und Regionen, Hilfe, Profil, Datenschutz.
///
/// **Die erste Seite trägt keine Listen mehr** ([UI-2], 2026-08-01). Vorher
/// stand die Filialliste ganz oben und wuchs mit jeder gewählten Filiale;
/// wer viele hatte, sah nichts anderes mehr und kam an den Rest nur durch
/// Scrollen. Filialen und Regionen liegen jetzt zusammen eine Seite tiefer —
/// sie beantworten dieselbe Frage („wo kaufst du ein"), und beide sind
/// Listen unbekannter Länge.
struct SettingsView: View {
    @Environment(RegionStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(ShoppingListStore.self) private var list
    @Environment(MatchRejectionStore.self) private var rejections
    @Environment(MatchFeedbackStore.self) private var feedback
    @Environment(TutorialStore.self) private var tutorial
    @Environment(SetupProgressStore.self) private var setup
    @Environment(AreaRequestStore.self) private var areaRequests
    @Environment(BranchRequestStore.self) private var branchRequests
    @Environment(PurchaseHistoryStore.self) private var history
    /// Übersetzt die PLZ in den Ort, an dem man wirklich steht — siehe
    /// `PlaceNameStore`.
    @Environment(PlaceNameStore.self) private var placeNames
    @Environment(DiagnosticsGate.self) private var diagnostics
    @AppStorage(Theme.appearanceKey, store: AppDefaults.shared)
    private var appearance: AppAppearance = .system
    let marketRepository: MarketRepositoryProtocol

    @State private var showResetConfirmation = false
    /// Ob gerade auf der Zeile „Version" gedrückt wird — siehe `appSection`.
    @State private var isPressingVersion = false
    @State private var installIdCopied = false
    @State private var showForgetConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var privacy = PrivacyStore()

    var body: some View {
        NavigationStack {
            List {
                Group {
                    shoppingSection
                    // Direkt darunter, nicht ganz unten: Der letzte Rahmen des
                    // Rundgangs zeigt auf beide Abschnitte, und dafür müssen
                    // sie ohne Scrollen zusammen sichtbar sein.
                    helpSection
                    profileSection
                    feedbackSection
                    appearanceSection
                    privacySection
                    appSection
                }
                .listRowBackground(Theme.surface)
            }
            .themedScreen()
            .navigationTitle("Einstellungen")
        }
    }

    // MARK: Einkaufen

    /// Eine Zeile statt zweier Listen. Was dahinter liegt, steht in
    /// `ShoppingPlacesScreen`.
    private var shoppingSection: some View {
        Section {
            NavigationLink {
                ShoppingPlacesScreen(marketRepository: marketRepository)
            } label: {
                LabeledContent("Filialen und Regionen", value: placesSummary)
            }
            .accessibilityIdentifier("settings.places")
            // Der Anker sitzt auf der Zeile, nicht auf dem Abschnitt: Ein
            // `Section` reicht den Modifikator an jede Zeile einzeln durch.
            .tutorialAnchor(.settingsMarkets)
        } header: {
            Text("Einkaufen")
        } footer: {
            Text(store.hasFavorites
                 ? "Nur Angebote deiner Filialen zählen für deine Liste."
                 : "Ohne gewählte Filiale werden keine Angebote angezeigt.")
        }
    }

    /// „8 Filialen · 2 Regionen" — die Zeile sagt, wie viel dahinter liegt,
    /// damit man nicht hineingehen muss, um es zu erfahren.
    private var placesSummary: String {
        let branches = store.favoriteMarkets.count
        let regions = store.regions.count
        guard branches > 0 else { return "keine gewählt" }
        let left = branches == 1 ? "1 Filiale" : "\(branches) Filialen"
        let right = regions == 1 ? "1 Region" : "\(regions) Regionen"
        return "\(left) · \(right)"
    }

    // MARK: Hilfe

    private var helpSection: some View {
        Section {
            Button {
                // Aus den Einstellungen: **keine** Frage nach den Filialen am
                // Ende. Wer hier startet, hat seine Wahl längst getroffen oder
                // sitzt eine Zeile über dem Weg dorthin.
                tutorial.start(origin: .settings, hasMarkets: store.hasFavorites)
            } label: {
                // Gezeichneter Wegweiser statt `sparkles` — siehe `AppGlyph`.
                // Die zwei Glitzer-Glyphen versprachen Zauberei, wo eine
                // Einführung und ein Aufräumen stehen ([UI-3], 01.08.).
                AppGlyphLabel(title: "Rundgang erneut ansehen", glyph: .tour)
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityIdentifier("settings.tutorial")
            .tutorialAnchor(.settingsHelp)

            // **Nur die Vorschläge, nicht die App.**
            //
            // Eine Kaufhistorie sagt etwas über Ernährung, Alkohol, Kinder,
            // Gesundheit — Dinge, die eine Einkaufsliste nicht sagt. Wer sie
            // loswerden will, soll dafür nicht Filialen, Profil und Onboarding
            // mit aufgeben müssen. Scotts Entscheidung vom 2026-07-31; sie ist
            // der Grund, warum es diesen Knopf **neben** dem Zurücksetzen gibt
            // und nicht nur das Zurücksetzen.
            //
            // Ohne Warnfarbe und ohne `role: .destructive`: Was hier
            // verschwindet, ist ein Komfort, kein Besitz.
            Button {
                showForgetConfirmation = true
            } label: {
                AppGlyphLabel(title: "Vorschläge vergessen", glyph: .forgetSuggestions)
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityIdentifier("settings.forgetSuggestions")
            .confirmationDialog(
                "Vorschläge vergessen?",
                isPresented: $showForgetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Vergessen", role: .destructive) { history.forget() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Le Chariot vergisst, was du bisher abgehakt hast. „Häufig gekauft“ zeigt danach wieder die Standardvorschläge. Deine Liste, deine Filialen und deine Angaben bleiben.")
            }

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
                        setup: setup,
                        areaRequests: areaRequests,
                        branchRequests: branchRequests,
                        history: history,
                        placeNames: placeNames
                    )
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                // Der zweite Satz kam am 2026-07-31 dazu, zusammen mit der
                // sichtbaren Installations-ID: Das Zurücksetzen vergibt eine
                // neue, und damit sind die schon hochgeladenen Zeilen von
                // niemandem mehr zu benennen — auch nicht von dem, der sie
                // löschen lassen will. Das ist eine Folge, die man vorher
                // wissen muss, nicht hinterher.
                Text("Deine Filialen, deine Einkaufsliste und deine Angaben aus dem Onboarding werden gelöscht. Danach startet Le Chariot wie nach einer Neuinstallation. Du bekommst dabei eine neue Installations-ID — willst du früher hochgeladene Angaben löschen lassen, kopier die alte vorher unter „App“.")
            }
        } header: {
            Text("Hilfe")
        } footer: {
            Text("Der Rundgang zeigt die kurze Einführung auf der Einkaufsliste noch einmal; Le Chariot legt dafür ein paar Beispiel-Artikel auf die Liste und räumt sie danach wieder ab. Zurücksetzen hilft, wenn etwas hakt — es löscht alles, was auf dem Gerät liegt.")
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

    // MARK: Datenschutz

    /// **Auskunft und Löschung, selbst auslösbar** ([UI-4], 2026-08-01).
    ///
    /// Bis hierher gab es nur „App zurücksetzen" (rein lokal) und die
    /// kopierbare ID. Wer löschen lassen wollte, konnte seine ID nennen und
    /// warten — das Löschversprechen der Datenschutzerklärung war damit zur
    /// Hälfte eingelöst, der Export gar nicht.
    private var privacySection: some View {
        Section {
            installIdRow

            Button {
                let local = LocalDataExport.collect(
                    profile: profile, regions: store, list: list, history: history
                )
                Task { await privacy.buildExport(local: local) }
            } label: {
                LabeledContent("Deine Daten exportieren") {
                    if privacy.export == .working { ProgressView() }
                }
                .foregroundStyle(Theme.accent)
            }
            .accessibilityIdentifier("settings.export")
            // Ein Button verdeckt das Label seines `LabeledContent` — die
            // Zeile war im Audit ohne Beschreibung. Dieselbe Falle wie bei
            // `BranchPickerRow`; ein Button nimmt das Label direkt.
            .accessibilityLabel("Deine Daten exportieren")
            .accessibilityHint("Legt alles, was Le Chariot über dich hat, als Datei bereit")

            if case let .done(note) = privacy.export, let file = privacy.exportFile {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ShareLink(item: file) {
                        Label("Datei teilen oder sichern", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("settings.export.share")
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            if case let .failed(message) = privacy.export {
                Text(message).font(.caption).foregroundStyle(Theme.error)
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                LabeledContent("Hochgeladene Daten löschen") {
                    if privacy.deletion == .working { ProgressView() }
                }
                .foregroundStyle(Theme.error)
            }
            .accessibilityIdentifier("settings.deleteUploaded")
            .accessibilityLabel("Hochgeladene Daten löschen")
            .accessibilityHint("Löscht deine Profilangaben und Rückmeldungen auf dem Server")
            .confirmationDialog(
                "Hochgeladene Daten löschen?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) {
                    let id = profile.profile.installId
                    Task { await privacy.deleteUploadedData(installId: id) }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Deine Profilangaben und deine Rückmeldungen zu Treffern werden auf dem Server gelöscht. Was auf diesem Gerät liegt — Liste, Filialen, Vorname — bleibt; dafür ist „App zurücksetzen“ da.")
            }

            if case let .done(message) = privacy.deletion {
                Text(message).font(.caption).foregroundStyle(Theme.secondaryText)
            }
            if case let .failed(message) = privacy.deletion {
                Text(message).font(.caption).foregroundStyle(Theme.error)
            }
        } header: {
            Text("Datenschutz")
        } footer: {
            // Nennt beim Namen, was **nicht** gelöscht wird. Am 01.08. an den
            // Migrationen nachgesehen: `install_id` steht nur in
            // `user_profiles` und `match_feedback`. Die Filial- und
            // Gebietsanforderungen sind je Laden **eine** Zeile für alle
            // Tester — dort steht, welcher Laden geholt werden soll, nicht wer
            // ihn wollte.
            Text("Die Installations-ID ist das Einzige, womit sich die hochgeladenen Zeilen benennen lassen — sie hängt an keinem Namen und an keinem Gerät. Gelöscht werden deine Profilangaben und deine Rückmeldungen. Angeforderte Filialen bleiben: dort steht nur, welcher Laden geholt werden soll, nicht wer ihn wollte. Zurücksetzen vergibt eine neue ID; die alten Zeilen kann danach niemand mehr zuordnen, du auch nicht.")
        }
    }

    // MARK: App

    private var appSection: some View {
        Section {
            // **Der Weg zum Messwerkzeug** (02.08. entschieden, Geste am
            // 03.08. festgelegt, weil Scott nicht antworten konnte): langer
            // Druck auf die Version. Ein Tester, der die Geste nicht kennt,
            // bekommt hier nie etwas zu sehen — und ein langer Druck auf eine
            // Zeile ohne Knopf tut sonst nichts.
            // Eine Zeile aus zwei Texten statt `LabeledContent`: Die Geste
            // braucht eine Fläche, die sie ganz abdeckt, und der Test einen
            // Griff, den es wirklich gibt.
            HStack {
                Text("Version")
                Spacer()
                Text(Self.appVersion).foregroundStyle(Theme.secondaryText)
            }
            .contentShape(Rectangle())
            // Die Zeile sagt, dass sie gedrückt wird. **Das ist der eigentliche
            // Fix**, nicht die kürzere Frist: Wer eine Sekunde drücken soll und
            // dabei nichts sieht, lässt nach einer halben los und schließt
            // daraus, dass es die Geste nicht gibt.
            .opacity(isPressingVersion ? 0.45 : 1)
            .animation(.easeOut(duration: 0.15), value: isPressingVersion)
            // **0,6 s statt 1,0 — gemessen, nicht geschätzt** (03.08.): Bei
            // 0,6 s und 0,8 s passierte nichts, erst bei 1,0 s ging sie auf.
            // Eine Geste, die genau an ihrer Untergrenze sitzt, trifft nur, wer
            // die Zahl kennt. 0,6 s ist immer noch das Dreifache eines Tipps.
            //
            // `maximumDistance` großzügig: Ein ruhender Finger wandert, und die
            // Vorgabe von 10 pt bricht die Geste dabei ab.
            .onLongPressGesture(minimumDuration: 0.6, maximumDistance: 40) {
                isPressingVersion = false
                // Rückmeldung an den Finger, bevor das Auge die neue Zeile
                // findet — die steht eine Zeile tiefer und ist leicht zu
                // übersehen.
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                diagnostics.reveal()
            } onPressingChanged: { pressing in
                isPressingVersion = pressing
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.version")

            if diagnostics.isRevealed {
                NavigationLink("Diagnose") { DiagnosticsView() }
                    .accessibilityIdentifier("settings.diagnostics")
            }
            // Endmarke für den Kontrast-Audit, der ans Ende der Liste scrollen
            // muss, bevor er misst. Ein Bezeichner und kein Text: Die Marke war
            // zweimal deutsche Prosa und ist zweimal gebrochen, als die Prosa
            // sich änderte.
            LabeledContent("Angebote", value: "wöchentlich aktualisiert")
                .accessibilityIdentifier("settings.end")
            // Reserved ad position — see `AdSlot`. Lowest-value slot, kept as the
            // natural home for a house ad (e.g. a werbefreie Variante).
            AdSlotView(slot: .settingsFooter)
        } header: {
            Text("App")
        }
    }

    /// **Die ID, die die Datenschutzerklärung verspricht.**
    ///
    /// Dort steht seit jeher: „Weil wir bewusst nicht wissen, wer du bist,
    /// brauchen wir für Auskunft oder Löschung deine Installations-ID … dann
    /// sagen wir dir, wo du sie findest." Bis zum 2026-07-31 gab es diesen Ort
    /// nicht — die ID stand in keinem Bildschirm der App. **Ein Recht, das man
    /// nur mit einer Angabe wahrnehmen kann, die man nirgends ablesen kann,
    /// ist keins.**
    ///
    /// Antippen kopiert. Ein Feld zum Markieren wäre der ehrlichere Weg, aber
    /// 36 Zeichen in einer Listenzeile von Hand zu markieren ist genau die
    /// Sorte Aufgabe, an der jemand aufgibt, der ohnehin schon verärgert genug
    /// ist, um eine Löschung zu verlangen.
    private var installIdRow: some View {
        let id = profile.profile.installId.uuidString
        return Button {
            UIPasteboard.general.string = id
            withAnimation { installIdCopied = true }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Installations-ID")
                        .foregroundStyle(Color.primary)
                    Text(id)
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: installIdCopied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(Theme.accent)
            }
        }
        .accessibilityIdentifier("settings.installId")
        // Der Zustand steht **im Namen** und nicht nur im Zeichen: Ein
        // Häkchen, das nur zu sehen ist, bestätigt niemandem etwas, der
        // VoiceOver benutzt — und die ID ist gerade für den da, der sie
        // weitergeben muss.
        .accessibilityLabel(installIdCopied ? "Installations-ID kopiert" : "Installations-ID kopieren")
        .accessibilityValue(id)
        .accessibilityHint("Kopiert die ID in die Zwischenablage")
    }

    private static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "–"
    }

}

// MARK: - Subscreens

/// **Filialen und Regionen, eine Seite tiefer** ([UI-2], 2026-08-01).
///
/// Beide sind Listen unbekannter Länge und beantworten dieselbe Frage: wo
/// kaufst du ein. Auf der ersten Seite der Einstellungen fraß die Filialliste
/// alles andere weg, sobald jemand mehr als eine Handvoll Läden hatte.
private struct ShoppingPlacesScreen: View {
    @Environment(RegionStore.self) private var store
    /// Übersetzt die PLZ in den Ort — siehe `PlaceNameStore`.
    @Environment(PlaceNameStore.self) private var placeNames
    let marketRepository: MarketRepositoryProtocol

    @State private var regionToRemove: String?

    var body: some View {
        List {
            Group {
                marketSection
                regionSection
            }
            .listRowBackground(Theme.surface)
        }
        .themedScreen()
        .navigationTitle("Filialen und Regionen")
        .navigationBarTitleDisplayMode(.inline)
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
                        // Der Ort steht vorn, die Zahl klein daneben: Gesucht
                        // wird mit der PLZ, gewohnt wird in einer Stadt
                        // (Scotts Fund vom 02.08.). Solange der Geocoder
                        // schweigt, ist der Name die PLZ und die Zeile sieht
                        // aus wie vorher.
                        let name = placeNames.name(forPLZ: plz)
                        Text(name == plz ? "PLZ \(plz)" : name)
                            .font(.body.weight(.medium))
                        if name != plz {
                            Text("PLZ \(plz)")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        syncStateLabel(store.syncState(for: plz))
                    }
                    .task { await placeNames.resolve(plz: plz) }
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

}


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
        .environment(SetupProgressStore())
        .environment(AreaRequestStore(repository: MockAreaRequestRepository()))
        .environment(BranchRequestStore(repository: MockBranchRequestRepository()))
}
