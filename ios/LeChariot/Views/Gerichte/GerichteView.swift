import SwiftUI

/// **Kochen** — zwei Fragen in einem Blatt:
///
/// - **Aus der Liste:** Was lässt sich aus dem kochen, was schon draufsteht
///   (und was diese Woche im Angebot ist)? Ein Knopf, die Antwort als Karten.
/// - **Gericht:** „Lasagne für 4" → die Zutaten, abgebildet aufs Wörterbuch,
///   mit einem Tipp auf die Liste.
///
/// Beides fragt über die Edge Function `gerichte` Claude Haiku. Vor dem
/// ersten Mal steht die Einwilligung (`GerichteEinwilligungView`) — ohne sie
/// zeigt das Blatt nichts anderes als sie.
struct GerichteView: View {
    let offers: [Offer]

    @Environment(ShoppingListStore.self) private var list
    @Environment(ProfileStore.self) private var profile
    @Environment(\.dismiss) private var dismiss

    @State private var store = GerichteStore()
    @State private var modus: Modus
    @State private var gerichtText = ""
    @State private var mitAngeboten = true
    @State private var gewaehlt: Set<String> = []
    @FocusState private var feldAktiv: Bool

    enum Modus: Hashable {
        case liste
        case gericht
    }

    init(offers: [Offer], startetMitListe: Bool) {
        self.offers = offers
        _modus = State(initialValue: startetMitListe ? .liste : .gericht)
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.einwilligungErteilt {
                    inhalt
                } else {
                    GerichteEinwilligungView(
                        erlauben: { withAnimation(.snappy) { store.einwilligen() } },
                        spaeter: { dismiss() }
                    )
                }
            }
            .themedScreen()
            .navigationTitle("Kochen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .accessibilityIdentifier("gerichte.done")
                }
            }
            .navigationDestination(for: Gericht.self) { gericht in
                GerichtDetailView(gericht: gericht, fertig: { dismiss() })
            }
        }
    }

    private var inhalt: some View {
        VStack(spacing: 0) {
            Picker("Modus", selection: $modus) {
                Text("Aus der Liste").tag(Modus.liste)
                Text("Gericht").tag(Modus.gericht)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .accessibilityIdentifier("gerichte.modus")

            switch modus {
            case .liste: ausDerListe
            case .gericht: gerichtSuchen
            }
        }
    }

    // MARK: Aus der Liste

    private var angebotsBegriffe: [String] { GerichtAbgleich.angebotsBegriffe(offers) }

    @ViewBuilder
    private var ausDerListe: some View {
        if list.items.isEmpty {
            ContentUnavailableView(
                "Deine Liste ist leer",
                systemImage: "fork.knife",
                description: Text("Schreib ein paar Zutaten auf oder such ein Gericht.")
            )
            .accessibilityIdentifier("gerichte.listeLeer")
        } else {
            List {
                if !angebotsBegriffe.isEmpty {
                    Section {
                        Toggle("Angebote der Woche einbeziehen", isOn: $mitAngeboten)
                            .tint(Theme.accent)
                            .listRowBackground(Theme.surface)
                            .accessibilityIdentifier("gerichte.mitAngeboten")
                    }
                }
                switch store.vorschlaege {
                case .leer:
                    EmptyView()
                case .laedt:
                    Section { ladeZeile("Gerichte werden gesucht …") }
                case let .fehler(fehler):
                    Section { fehlerZeile(fehler) }
                case let .fertig(gerichte):
                    ForEach(gerichte) { gericht in
                        Section { vorschlagsKarte(gericht) }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                hauptKnopf(
                    store.vorschlaege.istFertig ? "Neu vorschlagen" : "Gerichte vorschlagen",
                    id: "gerichte.vorschlagen",
                    aus: store.vorschlaege == .laedt
                ) {
                    Task {
                        await store.frageVorschlaege(
                            items: list.items,
                            angebote: mitAngeboten ? angebotsBegriffe : [],
                            installId: profile.profile.installId
                        )
                    }
                }
            }
        }
    }

    private func vorschlagsKarte(_ gericht: Gericht) -> some View {
        let fehlt = GerichtAbgleich.fehlende(gericht, items: list.items)
        return NavigationLink(value: gericht) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(gericht.name)
                    .font(.headline)
                Text(fehlt.isEmpty
                     ? "Alles auf der Liste"
                     : "Fehlt: " + fehlt.map(\.name).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(fehlt.isEmpty ? Theme.success : Theme.secondaryText)
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .listRowBackground(Theme.surface)
        .accessibilityIdentifier("gerichte.vorschlag")
    }

    // MARK: Gericht → Zutaten

    private var gerichtSuchen: some View {
        List {
            Section {
                HStack(spacing: Theme.Spacing.sm) {
                    TextField("z. B. Lasagne für 4", text: $gerichtText)
                        .focused($feldAktiv)
                        .submitLabel(.search)
                        .onSubmit(frageZutaten)
                        .accessibilityIdentifier("gerichte.feld")
                    Button(action: frageZutaten) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(TactileButtonStyle())
                    .disabled(gerichtText.trimmingCharacters(in: .whitespaces).isEmpty
                              || store.zutaten == .laedt)
                    .accessibilityLabel("Zutaten suchen")
                    .accessibilityIdentifier("gerichte.suchen")
                }
                .listRowBackground(Theme.surface)
            }

            switch store.zutaten {
            case .leer:
                EmptyView()
            case .laedt:
                Section { ladeZeile("Zutaten werden gesucht …") }
            case let .fehler(fehler):
                Section { fehlerZeile(fehler) }
            case let .fertig(gericht):
                ZutatenAuswahl(gericht: gericht, gewaehlt: $gewaehlt)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if case let .fertig(gericht) = store.zutaten {
                ZutatenKnopf(gericht: gericht, gewaehlt: gewaehlt, fertig: { dismiss() })
            }
        }
        .task { if store.zutaten == .leer { feldAktiv = true } }
    }

    private func frageZutaten() {
        feldAktiv = false
        let text = gerichtText
        Task { await store.frageZutaten(fuer: text, installId: profile.profile.installId) }
    }

    // MARK: Bausteine

    private func ladeZeile(_ text: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ProgressView()
            Text(text).foregroundStyle(Theme.secondaryText)
        }
        .listRowBackground(Theme.surface)
        .accessibilityIdentifier("gerichte.laedt")
    }

    private func fehlerZeile(_ fehler: GerichteFehler) -> some View {
        Label(fehler.meldung, systemImage: "exclamationmark.circle")
            .foregroundStyle(Theme.error)
            .listRowBackground(Theme.surface)
            .accessibilityIdentifier("gerichte.fehler")
    }

    private func hauptKnopf(
        _ titel: String, id: String, aus: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(titel)
                .font(.body.weight(.semibold))
                .frame(minHeight: 50)
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(aus)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
        .accessibilityIdentifier(id)
    }
}

private extension GerichteStore.Zustand {
    var istFertig: Bool {
        if case .fertig = self { return true }
        return false
    }
}

/// Ein Vorschlag aus der Liste, eine Seite tiefer: dieselbe Auswahl wie beim
/// gesuchten Gericht.
struct GerichtDetailView: View {
    let gericht: Gericht
    let fertig: () -> Void
    @State private var gewaehlt: Set<String> = []

    var body: some View {
        List {
            ZutatenAuswahl(gericht: gericht, gewaehlt: $gewaehlt)
        }
        .safeAreaInset(edge: .bottom) {
            ZutatenKnopf(gericht: gericht, gewaehlt: gewaehlt, fertig: fertig)
        }
        .themedScreen()
        .navigationTitle(gericht.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// **Die Zutaten eines Gerichts, jede einzeln abwählbar.**
///
/// Vorausgewählt ist, was auf der Liste fehlt; was schon draufsteht, steht da
/// als „Auf der Liste" und lässt sich trotzdem dazunehmen — wer für vier
/// kocht, braucht vielleicht zwei Packungen. Der Knopf dazu
/// (`ZutatenKnopf`) steht unten fest, nicht am Ende der Liste: Bei neun
/// Zutaten läge er sonst unter dem Rand.
struct ZutatenAuswahl: View {
    let gericht: Gericht
    @Binding var gewaehlt: Set<String>

    @Environment(ShoppingListStore.self) private var list
    @State private var vorhanden: Set<String> = []

    var body: some View {
        Section {
            ForEach(gericht.zutaten) { zutat in
                zeile(zutat)
            }
        } header: {
            Text(gericht.portionen == 1 ? "\(gericht.name) · 1 Portion"
                                        : "\(gericht.name) · \(gericht.portionen) Portionen")
        }
        .task(id: gericht) {
            let fehlt = Set(GerichtAbgleich.fehlende(gericht, items: list.items).map(\.name))
            vorhanden = Set(gericht.zutaten.map(\.name)).subtracting(fehlt)
            gewaehlt = fehlt
        }
    }

    private func zeile(_ zutat: Zutat) -> some View {
        let an = gewaehlt.contains(zutat.name)
        return Button {
            if an { gewaehlt.remove(zutat.name) } else { gewaehlt.insert(zutat.name) }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: an ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(an ? Theme.accent : Theme.secondaryText)
                ItemGlyphView(term: ItemGlyphTerm.term(for: zutat.name) ?? zutat.begriff,
                              category: nil, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(zutat.name).foregroundStyle(.primary)
                    if vorhanden.contains(zutat.name) {
                        Text("Auf der Liste")
                            .font(.caption)
                            .foregroundStyle(Theme.success)
                    }
                }
                Spacer()
                Text(zutat.menge)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.surface)
        .accessibilityAddTraits(an ? .isSelected : [])
        .accessibilityIdentifier("gerichte.zutat.\(zutat.name)")
    }
}

/// Legt die gewählten Zutaten an. Die Menge geht als Notiz mit, nicht in den
/// Text, damit die Suche das Wort findet und nicht „500 g Hackfleisch".
struct ZutatenKnopf: View {
    let gericht: Gericht
    let gewaehlt: Set<String>
    let fertig: () -> Void

    @Environment(ShoppingListStore.self) private var list
    @State private var hinzugefuegt = 0

    var body: some View {
        Button {
            for zutat in gericht.zutaten where gewaehlt.contains(zutat.name) {
                list.addIngredient(zutat.name, menge: zutat.menge)
            }
            hinzugefuegt += 1
            fertig()
        } label: {
            Text(titel)
                .font(.body.weight(.semibold))
                .frame(minHeight: 50)
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(gewaehlt.isEmpty)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
        .sensoryFeedback(.success, trigger: hinzugefuegt)
        .accessibilityIdentifier("gerichte.hinzufuegen")
    }

    private var titel: String {
        switch gewaehlt.count {
        case 0: "Nichts ausgewählt"
        case 1: "1 Zutat hinzufügen"
        default: "\(gewaehlt.count) Zutaten hinzufügen"
        }
    }
}

/// **Die Einwilligung vor dem ersten Mal.**
///
/// Zwei Knöpfe, beide sagen, was sie tun — dieselbe Form wie
/// `ConsentStepView`, aus demselben Grund: Wer durchklickt, soll nicht aus
/// Versehen Ja gesagt haben. Der Text nennt den Empfänger beim Namen, weil
/// genau das hier anders ist als überall sonst in der App: Die Daten gehen an
/// einen Dritten.
struct GerichteEinwilligungView: View {
    let erlauben: () -> Void
    let spaeter: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Image(systemName: "fork.knife")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.accent)
                    Text("Kochen mit Claude")
                        .font(.title2.weight(.bold))
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    detail(
                        "arrow.up.circle",
                        Theme.accent,
                        "Was übertragen wird",
                        "Das Gericht, das du eintippst, oder die Einträge deiner Liste — dazu Begriffe aus den Angeboten der Woche."
                    )
                    detail(
                        "building.2",
                        Theme.accent,
                        "An wen",
                        "An Anthropic, den Anbieter des Sprachmodells Claude, über den Server von \(AppBrand.name). Anthropic nutzt diese Daten nicht zum Training."
                    )
                    detail(
                        "iphone",
                        Theme.success,
                        "Was auf dem Gerät bleibt",
                        "Vorname, Notizen, Ort und Filialen."
                    )
                }

                Text("Du kannst es in den Einstellungen jederzeit widerrufen.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.sm) {
                Button(action: erlauben) {
                    Text("Erlauben")
                        .font(.body.weight(.semibold))
                        .frame(minHeight: 50)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .accessibilityIdentifier("gerichte.erlauben")
                Button("Nicht erlauben", action: spaeter)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("gerichte.nichtErlauben")
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.sm)
            .background(Theme.background)
        }
    }

    private func detail(_ symbol: String, _ farbe: Color, _ titel: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .foregroundStyle(farbe)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
