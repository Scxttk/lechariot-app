import SwiftUI

/// The app's home screen: the shopping list, with the week's cheapest offer per
/// item and — above everything — which branch covers the list best.
struct ShoppingListView: View {
    let favoriteMarkets: [Market]

    @Environment(ShoppingListStore.self) private var list
    /// Shared with the offers tab — see `ContentView.offerStore`.
    let offerStore: OfferStore
    /// Öffnet die Filialauswahl. Liegt in `ContentView`, weil der Picker über
    /// den Tabs erscheint und nicht in der Liste.
    var onChooseMarkets: () -> Void = {}
    @Environment(MatchRejectionStore.self) private var rejections
    @Environment(ProfileStore.self) private var profile
    /// Zählt beim Abhaken mit — siehe `PurchaseHistoryStore`.
    @Environment(PurchaseHistoryStore.self) private var history
    /// Optional, damit Previews ohne Rundgang auskommen.
    @Environment(TutorialStore.self) private var tutorial: TutorialStore?
    @State private var detailItem: ShoppingItem?
    /// Der Artikel, dessen Angaben gerade bearbeitet werden — nicht zu
    /// verwechseln mit `detailItem`, das die **Angebote** zum Artikel zeigt.
    @State private var editingItem: ShoppingItem?
    @State private var newItemText = ""
    @FocusState private var inputFocused: Bool
    /// Was der Nutzer in dieser Sitzung zuletzt mit der Vorschlagsfläche getan
    /// hat — siehe `SuggestionSurface`. Bewusst `@State` und nicht persistiert.
    @State private var suggestionChoice: Bool?

    private var chains: [String] {
        Array(Set(favoriteMarkets.map(\.chain))).sorted()
    }

    /// **Die Liste ist ohne Filiale benutzbar — seit dem 2026-07-31 ist das der
    /// Normalfall beim ersten Start.**
    ///
    /// Vorher lag vor diesem Bildschirm eine `ContentUnavailableView`
    /// („Keine Filiale gewählt"), und das Onboarding endete deshalb in der
    /// Filialauswahl. Jetzt endet es hier, und die zwei Stellen, an denen sonst
    /// Angebote stünden, tragen den Leerzustand: die Plan-Karte und die
    /// Treffer-Zeile. Beide behalten dabei ihren Anker — ohne den überspringt
    /// sich der Rundgang durch die Rahmen, die den Zweck der App erklären.
    private var hasMarkets: Bool { !favoriteMarkets.isEmpty }

    /// The chosen branches — the filter that matches what the user picked
    /// since the backend keys offers by branch (migration v13).
    private var branchIds: [String] {
        favoriteMarkets.map(\.marketId).sorted()
    }

    /// Matches are recomputed on the fly; only rejections are persisted.
    ///
    /// The suggestion follows the market the card recommends, not the cheapest
    /// offer anywhere. Otherwise the screen tells two stories at once — "go to
    /// Lidl, 19,32 €" on top, Netto and Kaufland prices in the rows — and the
    /// sum in the card matches nothing the user can actually buy in one trip.
    /// Items the recommended market has nothing for fall back to the cheapest
    /// offer elsewhere; the market name on the row says where.
    ///
    /// **Eine geheftete Wahl steht über dieser Regel.** Sie ist der Grund, aus
    /// dem es die Zeile gibt: Wer den GRÜNLÄNDER gewählt hat, will ihn
    /// dauerhaft auf der Liste sehen — auch dann, wenn die Karte gerade eine
    /// andere Kette empfiehlt. Der Marktname an der Zeile sagt weiterhin, wo.
    /// Die Karte widerspricht dem nicht: Sie führt denselben Artikel dann unter
    /// „Deine Wahl woanders" auf, statt ihn als abgedeckt zu zählen.
    private func suggestion(for item: ShoppingItem, plan: [MarketListRank]) -> ItemSuggestion {
        if let pin = item.pinned,
           let offer = ShoppingListMatcher.pinnedOffer(pin, in: offerStore.offers) {
            return ItemSuggestion(
                match: OfferMatch(
                    offer: offer,
                    kind: ShoppingListMatcher.kind(of: offer, for: item.query)
                ),
                isPinned: true
            )
        }
        let fallback: OfferMatch? = {
            if let winner = plan.first,
               let covered = winner.matchedItems.first(where: { $0.item == item.query }) {
                return covered.match
            }
            return ShoppingListMatcher.cheapestMatch(for: item.query, in: offerStore.offers) {
                rejections.isRejected(itemText: item.query, offer: $0)
            }
        }()
        // `dormantPin` ist genau dann gesetzt, wenn eine Wahl geheftet ist, es
        // sie diese Woche aber nirgends gibt — der Zweig darüber hat sie sonst
        // schon abgefangen.
        return ItemSuggestion(match: fallback, dormantPin: item.pinned)
    }

    private var ranks: [MarketListRank] {
        ShoppingListRanking.rank(
            items: list.uncheckedItems,
            offers: offerStore.offers,
            chains: chains
        ) { rejections.isRejected(itemText: $0, offer: $1) }
    }

    /// Die Kette, die ohne die Heftungen gewönne — `nil`, wenn sie nichts
    /// ändern. Kostet nur dann einen zweiten Durchlauf, wenn überhaupt etwas
    /// geheftet ist; die Prüfung darauf steckt in `winnerWithoutPins`. Der
    /// schon gerechnete Plan wird durchgereicht, damit es bei **einem**
    /// zusätzlichen Durchlauf bleibt.
    private func winnerWithoutPins(_ plan: [MarketListRank]) -> String? {
        ShoppingListRanking.winnerWithoutPins(
            items: list.uncheckedItems,
            offers: offerStore.offers,
            chains: chains,
            currentWinner: plan.first?.chain
        ) { rejections.isRejected(itemText: $0, offer: $1) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if list.items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
            .themedScreen()
            .navigationTitle("Einkaufsliste")
            .toolbar { toolbarMenu }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .task(id: branchIds) {
            await offerStore.load(branchIds: branchIds, chains: chains)
        }
        .sheet(item: $detailItem) { item in
            MatchDetailView(
                item: item,
                offers: offerStore.offers,
                favoriteMarkets: favoriteMarkets
            )
                .environment(rejections)
                // Das Blatt schreibt die Heftung selbst und muss den Artikel
                // dafür **live** lesen: `detailItem` ist eine Kopie vom Moment
                // des Antippens und wüsste von der eigenen Änderung nichts.
                .environment(list)
        }
        .sheet(item: $editingItem) { item in
            ItemDetailSheet(item: item) { detail in
                list.setDetail(detail, for: item)
            }
        }
    }

    // MARK: List

    private var itemList: some View {
        List {
            let plan = ranks
            if !plan.isEmpty {
                Section {
                    ShoppingPlanCard(ranks: plan, winnerWithoutPins: winnerWithoutPins(plan))
                        .tutorialAnchor(.planCard)
                        .listRowInsets(EdgeInsets(
                            top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                            bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                        ))
                }
                .listRowBackground(Color.clear)
            } else if !hasMarkets {
                // Der Platz der Plan-Karte bleibt besetzt, statt leer zu
                // bleiben: Was hier fehlt, ist die Antwort, für die es die App
                // gibt — und dass sie fehlt, ist das Argument, Filialen zu
                // wählen. Der Anker sitzt hier und **nur** hier; die Fassung im
                // Leerzustand trägt ihn bewusst nicht (zwei Anker desselben
                // Ziels entscheidet der Preference-Merge, siehe L-2).
                Section {
                    NoMarketsCard(action: onChooseMarkets)
                        .tutorialAnchor(.planCard)
                        .listRowInsets(EdgeInsets(
                            top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                            bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                        ))
                }
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(Array(list.uncheckedItems.enumerated()), id: \.element.id) { index, item in
                    ShoppingListRowView(
                        item: item,
                        suggestion: suggestion(for: item, plan: plan),
                        hasMarkets: hasMarkets,
                        // Nur die erste offene Zeile trägt die Anker des
                        // Rundgangs — sonst zeigt das Loch auf sechs Stellen.
                        carriesTutorialAnchors: index == 0,
                        onToggle: { check(item) },
                        onShowMatches: { detailItem = item },
                        onEditDetail: { editingItem = item }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            list.remove(item)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                    // Pro Zeile statt pro Abschnitt: Diese Zeilen wischen, und
                    // ein flacher Hintergrund zeigt dabei eine eckige Kante.
                    .groupedRowBackground(
                        GroupedRowPosition(index: index, count: list.uncheckedItems.count)
                    )
                }
            }

            if !list.checkedItems.isEmpty {
                Section("Erledigt") {
                    ForEach(Array(list.checkedItems.enumerated()), id: \.element.id) { index, item in
                        ShoppingListRowView(
                            item: item,
                            onToggle: { check(item) },
                            // Auch am erledigten Artikel: Die Angabe gilt beim
                            // nächsten Mal genauso, und wer im Laden merkt,
                            // dass es die große Packung sein muss, notiert es
                            // dort — nicht zu Hause davor.
                            onEditDetail: { editingItem = item }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                list.remove(item)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                        .groupedRowBackground(
                            GroupedRowPosition(index: index, count: list.checkedItems.count)
                        )
                    }
                }
            }

        }
    }

    /// Abhaken heißt „gekauft" — und nur das wird gezählt.
    ///
    /// Ein Artikel, den man versehentlich wieder aufmacht, darf den Streifen
    /// nicht mitlernen; deshalb hängt das Zählen am Übergang **nach**
    /// abgehakt und nicht am Umschalten.
    private func check(_ item: ShoppingItem) {
        let wasChecked = item.isChecked
        withAnimation { list.toggle(item) }
        if !wasChecked { history.record(item.query) }
    }

    // MARK: Empty state

    /// Nur noch die Ansprache — die Vorschläge stehen seit L-2 unten.
    ///
    /// Bis zum 2026-07-31 lagen die Kacheln **zweimal** in dieser Datei: hier
    /// und als Listenabschnitt. Sie stehen jetzt an genau einer Stelle, in der
    /// Fläche über der Eingabezeile, und sind damit auf dem leeren wie auf dem
    /// vollen Bildschirm derselbe Ort.
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checklist")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.accent)
                    // The name, when we have one, earns its keep here rather
                    // than in the navigation bar: it greets on the empty screen
                    // and stays out of the way once the list is in daily use.
                    Text(profile.greetingName.isEmpty
                         ? "Was brauchst du?"
                         : "Was brauchst du, \(profile.greetingName)?")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    // **Nicht zusätzlich zur Filialen-Karte.** Beide Absätze
                    // sagen dasselbe („welche deiner Filialen die Liste am
                    // günstigsten abdeckt"), und zusammen schoben sie den Knopf
                    // der Karte unter die Vorschlagsfläche — am Simulator
                    // gemessen, der erste Bildschirm nach dem Onboarding.
                    if hasMarkets {
                        Text("Schreib auf, was du einkaufen willst. Le Chariot sagt dir, welche deiner Filialen die Liste am günstigsten abdeckt.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                }

                // Wer den Rundgang am Ende des Onboardings ablehnt, sieht die
                // Frage nach den Filialen nie — und stünde ohne das hier vor
                // einem Bildschirm, der nichts davon erwähnt. **Ohne Anker:**
                // Der Rundgang legt für den Plan-Rahmen Beispiel-Artikel hin,
                // spielt also nie über diesem Zustand.
                if !hasMarkets {
                    NoMarketsCard(action: onChooseMarkets)
                }
            }
            .padding(Theme.Spacing.xl)
        }
    }

    // MARK: Suggestions

    /// Was der Streifen zeigt, in drei Stufen: zuerst was dieser Haushalt
    /// tatsächlich kauft, dann — nur beim Kaltstart — die acht festen Wörter,
    /// zuletzt aufgefüllt aus den Angeboten dieser Woche.
    ///
    /// Der persönliche Teil verliert eine gute Eigenschaft des alten
    /// Streifens: Jede Kachel hatte einen Grund **dieser Woche** (bester
    /// Rabatt). Persönliche Kacheln haben den nicht. Bewusst in Kauf genommen —
    /// zwei Überschriften zur Erklärung der Gruppen wären die schlechtere
    /// Antwort, weil sie einen Vorschlag erklären, den niemand erklärt haben
    /// wollte.
    private var suggestions: [String] {
        ShoppingSuggestions.strip(
            for: list.items,
            offers: offerStore.offers,
            history: history.top(
                ShoppingSuggestions.personalLength,
                excluding: Set(list.items.map { PurchaseHistoryStore.normalized($0.text) })
            ),
            includeStaples: history.needsStaples
        )
    }

    /// Ob die Fläche gerade offen steht. Die Regel steht in
    /// `SuggestionSurface`, hier stehen nur die drei Eingaben.
    private var surfaceIsExpanded: Bool {
        SuggestionSurface.isExpanded(
            choice: suggestionChoice,
            listIsEmpty: list.items.isEmpty,
            tourIsRunning: tutorial?.isRunning == true
        )
    }

    /// **Die Vorschläge kleben an der Eingabezeile, nicht an der Liste.**
    ///
    /// Der Streifen war ein Abschnitt mitten in der Liste, zwischen den
    /// Artikeln und „Erledigt", und rutschte mit jeder weiteren Zeile weiter
    /// aus dem Daumenbereich. Die erste Testerin von außen hat das als „nicht
    /// einhändig erreichbar" gemeldet — nicht das Feld war gemeint, sondern
    /// alles, was zum Hinzufügen dazugehört. Jetzt liegt beides im selben
    /// Block unten: ein Daumen, ein Weg.
    ///
    /// **Nicht mitgewandert** ist das Menü oben rechts. „Liste leeren" ist der
    /// eine Knopf, der wirklich Schaden anrichtet, und er gehört dorthin, wo
    /// ein Daumen ihn nicht aus Versehen trifft.
    private var bottomBar: some View {
        VStack(spacing: 0) {
            suggestionSurface
            inputBar
        }
        // Eine Fläche für beides. Vorher trug die Eingabezeile den Hintergrund
        // allein; zwei übereinandergelegte `.bar`-Flächen ergäben eine Kante
        // quer über den Block.
        .background(.bar)
    }

    @ViewBuilder
    private var suggestionSurface: some View {
        let remaining = suggestions
        if !remaining.isEmpty && surfaceIsExpanded {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Häufig gekauft")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                suggestionChips(remaining)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .readableWidth()
            // Aufziehen von unten, verschwinden ohne Bewegung: Beim Zuklappen
            // rutscht die Liste ohnehin nach unten nach, und zwei Bewegungen
            // gegeneinander sehen aus wie ein Ruckler.
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    private func suggestionChips(_ staples: [String]) -> some View {
        // Flexible grid rather than a fixed row count, so the chips reflow
        // instead of clipping at large Dynamic Type sizes.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96), spacing: Theme.Spacing.sm)],
            alignment: .leading,
            spacing: Theme.Spacing.sm
        ) {
            ForEach(staples, id: \.self) { staple in
                Button {
                    // Eine Kachel antippen heißt „ich benutze die Fläche" —
                    // sie bleibt danach offen. Ohne das schlüge sie beim ersten
                    // Artikel unter dem Daumen zu, und der zweite Vorschlag
                    // wäre wieder einen Knopfdruck weit weg. Genau der Fehler
                    // ist schon einmal dagewesen (2026-07-26, damals mit dem
                    // Leerzustand als Ursache).
                    suggestionChoice = true
                    // `add` is @discardableResult Bool; swallow it explicitly so
                    // withAnimation's generic result type stays unambiguous.
                    withAnimation { _ = list.add(staple) }
                } label: {
                    Text(staple)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            Theme.surface,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                                .strokeBorder(Theme.stroke)
                        )
                }
                .buttonStyle(TactileButtonStyle())
                .accessibilityLabel("\(staple) hinzufügen")
            }
        }
        // Seit L-2 steht das Raster an **einer** Stelle. Vorher lag es im
        // Leerzustand und als Listenabschnitt, und welches der beiden der
        // Rundgang ausleuchtete, entschied der Preference-Merge.
        .tutorialAnchor(.suggestions)
    }

    // MARK: Input

    /// Der Platzhalter sagt, in welchem Zustand die Liste ist.
    ///
    /// Vorher stand dort immer „Artikel hinzufügen …" — eine Beschriftung des
    /// Feldes, keine Ansprache. Vor der leeren Liste ist die Frage die
    /// eigentliche Aufforderung; danach ist der einzige noch nützliche Hinweis,
    /// **dass es weitergeht**: `addItem()` behält den Fokus, die Tastatur
    /// bleibt stehen, und der Platzhalter sagt jetzt dasselbe. Von Bring!
    /// übernommen („Ich brauche …" / „Nächster Artikel …").
    private var inputPlaceholder: String {
        list.items.isEmpty ? "Was brauchst du?" : "Nächster Artikel …"
    }

    /// Der Knopf, der die Vorschlagsfläche auf- und zuklappt.
    ///
    /// Links im Feld, weil er zu dem gehört, was darüber liegt. Er fehlt, wenn
    /// es nichts vorzuschlagen gibt — ein Knopf, der eine leere Fläche öffnet,
    /// ist ein kaputter Knopf.
    @ViewBuilder
    private var surfaceToggle: some View {
        if !suggestions.isEmpty {
            let open = surfaceIsExpanded
            Button {
                withAnimation(.snappy) { suggestionChoice = !open }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 17, weight: .semibold))
                    .rotationEffect(.degrees(open ? 180 : 0))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityIdentifier("list.suggestions.toggle")
            // Der Zustand steckt im Namen und nicht in einem `value`: Ein
            // gedrehtes Winkelzeichen sagt einem Screenreader nichts.
            .accessibilityLabel(open ? "Vorschläge ausblenden" : "Vorschläge einblenden")
        }
    }

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            surfaceToggle

            TextField(inputPlaceholder, text: $newItemText)
                // Vier Test-Helfer griffen das Feld über seinen Platzhalter —
                // deutscher Fließtext als Griff, und der ändert sich ab jetzt
                // sogar zur Laufzeit. Ein Bezeichner ändert sich nur, wenn ihn
                // jemand absichtlich ändert. (Dieselbe Falle hat die Endmarke
                // des Einstellungs-Audits zweimal gerissen.)
                .accessibilityIdentifier("list.input")
                .focused($inputFocused)
                .submitLabel(.done)
                .onSubmit(addItem)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(height: 44)
                .background(
                    Theme.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.stroke)
                )

            Button(action: addItem) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(TactileButtonStyle())
            .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Artikel hinzufügen")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        // Bar across the whole width, field only as wide as the list above it.
        .readableWidth()
        .tutorialAnchor(.inputBar)
    }

    private func addItem() {
        guard list.add(newItemText) else { return }
        newItemText = ""
        inputFocused = true
        // Wer tippt, weiß was er braucht — die Fläche gibt der Liste ihren
        // Platz zurück. Die Gegenrichtung steht bei den Kacheln.
        withAnimation(.snappy) { suggestionChoice = false }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarMenu: some ToolbarContent {
        // Während des Rundgangs gibt es das Menü nicht.
        //
        // Die Navigationsleiste zeichnet UIKit; `accessibilityHidden` auf dem
        // Inhalt erreicht sie nicht, und „Liste leeren" mitten in der Führung
        // wäre der eine Knopf, der wirklich Schaden anrichtet. Also nicht
        // verstecken, sondern gar nicht erst bauen.
        ToolbarItem(placement: .topBarTrailing) {
            if tutorial?.isRunning != true {
                Menu {
                    Button("Erledigte entfernen", systemImage: "checkmark.circle") {
                        withAnimation { list.clearChecked() }
                    }
                    .disabled(list.checkedItems.isEmpty)
                    Button("Liste leeren", systemImage: "trash", role: .destructive) {
                        withAnimation { list.clearAll() }
                    }
                    .disabled(list.items.isEmpty)
                } label: {
                    Label("Mehr", systemImage: "ellipsis.circle")
                }
            }
        }
    }
}

/// Der Leerzustand an der Stelle der Plan-Karte: **ehrlich statt versteckt.**
///
/// Die Karte wegzulassen wäre die bequeme Antwort gewesen — dann steht auf dem
/// ersten Bildschirm der App nichts, was erklärt, warum man Filialen wählen
/// sollte, und der Rundgang überspringt den Rahmen, der den Zweck der App
/// erklärt. Also steht hier, was fehlt, und daneben der Weg dahin.
struct NoMarketsCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Noch keine Filiale gewählt")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("Le Chariot vergleicht nur die Läden, in die du wirklich gehst. Sobald du Filialen gewählt hast, steht hier, welche davon deine Liste am günstigsten abdeckt — und was der Einkauf dort kostet.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                // Ein Bezeichner, damit die Ausnahme im Kontrast-Audit an
                // etwas hängt, das sich nur absichtlich ändert — und nicht an
                // drei Zeilen deutschem Fließtext. Siehe
                // `AccessibilityAuditTests.knownSystemDrawn`.
                .accessibilityIdentifier("list.noMarkets.body")
            Button(action: action) {
                Text("Filialen wählen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .frame(minHeight: 44)
                    .background(Theme.accent, in: Capsule())
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityIdentifier("list.chooseMarkets")
            .padding(.top, Theme.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .themeCard()
    }
}

#Preview {
    ShoppingListView(
        favoriteMarkets: MockFixtures.markets,
        offerStore: OfferStore(repository: MockOfferRepository(), cache: nil)
    )
    .environment(ShoppingListStore())
    .environment(MatchRejectionStore())
    .environment(ProfileStore())
    .environment(PurchaseHistoryStore())
}

#Preview("Ohne Filialen") {
    ShoppingListView(
        favoriteMarkets: [],
        offerStore: OfferStore(repository: MockOfferRepository(), cache: nil)
    )
    .environment(ShoppingListStore())
    .environment(MatchRejectionStore())
    .environment(ProfileStore())
    .environment(PurchaseHistoryStore())
}
