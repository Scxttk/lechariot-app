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
    /// Führt in den Angebote-Tab — die Zeile „Passende Artikel im Angebot"
    /// zeigt die Zahlen, die Angebote selbst stehen dort.
    var onShowOffers: () -> Void = {}
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
    /// Der laufende Tipp-Fluss — siehe `AddFlowState` und `ItemDetailPanel`.
    /// Bewusst `@State` und nicht persistiert: Er endet mit der Tastatur.
    @State private var addFlow = AddFlowState()
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
        let pins = item.pinnedOffers
        if !pins.isEmpty {
            var positions: [ItemSuggestion.Position] = []
            var dormant: [PinnedOffer] = []
            for pin in pins {
                if let offer = ShoppingListMatcher.pinnedOffer(pin, in: offerStore.offers) {
                    positions.append(ItemSuggestion.Position(
                        match: OfferMatch(
                            offer: offer,
                            kind: ShoppingListMatcher.kind(of: offer, for: item.query)
                        ),
                        isPinned: true
                    ))
                } else {
                    dormant.append(pin)
                }
            }
            if !positions.isEmpty {
                return ItemSuggestion(positions: positions, dormantPins: dormant)
            }
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
        return ItemSuggestion(
            positions: fallback.map { [ItemSuggestion.Position(match: $0, isPinned: false)] } ?? [],
            dormantPins: item.pinnedOffers
        )
    }

    /// Der Satz für eine Zeile ohne Treffer, wenn ein Suchwort dem Wörterbuch
    /// fremd ist. `nil`, sobald es einen Treffer gibt — dann führt die Kachel
    /// ins Trefferblatt, und dort steht die Auskunft im Kopf.
    ///
    /// Der Vorbehalt spart mehr als er aussieht: `QueryUnderstanding` liest den
    /// ganzen Vorrat nur, wenn wirklich ein Wort unbekannt ist, und diese Zeile
    /// fragt nur, wenn wirklich nichts gefunden wurde.
    private func unknownWordNote(for item: ShoppingItem, suggestion: ItemSuggestion) -> String? {
        guard suggestion.match == nil else { return nil }
        return QueryUnderstanding.of(query: item.query, in: offerStore.offers).unknownNote
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
        // **Der Fluss endet mit der Tastatur.** Bei Bring! tut „Abbrechen"
        // genau das: Es beendet das Tippen insgesamt, nicht die Angaben zu
        // einem Artikel. Wer das Feld verlässt, ist fertig mit Aufschreiben —
        // und ein Panel, das darüber hinaus stehen bliebe, wäre wieder ein
        // Ding, das man wegräumen muss.
        //
        // **Mit Bedenkzeit, und die ist nicht Geschmack:** Zwischen dem
        // Absenden und dem wiedergeholten Fokus (`keepTyping`) liegt genau ein
        // Durchgang ohne Fokus. Ohne die Pause räumte der Fluss sich bei jedem
        // Artikel selbst ab — am Simulator gemessen, bevor diese Zeilen so
        // aussahen.
        .task(id: inputFocused) {
            guard !inputFocused else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, !inputFocused else { return }
            withAnimation(.snappy) { addFlow.end() }
        }
        // Gelöschte Artikel dürfen im Fluss nicht weiterleben — sonst zeigt das
        // Panel Chips zu einer Zeile, die es nicht mehr gibt.
        .onChange(of: list.items.map(\.id)) { _, ids in
            addFlow.keepOnly(Set(ids))
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
            ItemDetailSheet(item: item) { detail, note in
                list.setDetail(detail, note: note, for: item)
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

            // **Die Zeile aus dem Video, in der Liste statt im Angebote-Tab.**
            // Sie rechnet nichts nach: Die Zähler stehen schon in `plan`.
            let hits = OfferHitSummary(ranks: plan)
            if !hits.isEmpty {
                Section {
                    OfferHitsRow(summary: hits, onOpen: onShowOffers)
                        .listRowInsets(EdgeInsets(
                            top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                            bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                        ))
                }
                .listRowBackground(Color.clear)
            }

            // **Kategorie-Abschnitte wie bei Bring!** — einsortiert wird über
            // den Treffer, den die Zeile ohnehin zeigt.
            let byQuery = ShoppingSections.categories(from: plan)
            let sections = ShoppingSections.build(items: list.uncheckedItems) { byQuery[$0.query] }
            let showsHeaders = ShoppingSections.needsHeaders(sections)
            let firstOpenItem = list.uncheckedItems.first?.id

            ForEach(sections) { section in
                Section {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        let itemSuggestion = suggestion(for: item, plan: plan)
                        ShoppingListRowView(
                            item: item,
                            suggestion: itemSuggestion,
                            hasMarkets: hasMarkets,
                            // Nur die erste offene Zeile trägt die Anker des
                            // Rundgangs — sonst zeigt das Loch auf sechs
                            // Stellen. Mit Abschnitten ist das nicht mehr
                            // „Index 0", sondern der erste Artikel der Liste.
                            carriesTutorialAnchors: item.id == firstOpenItem,
                            unknownWordNote: unknownWordNote(for: item, suggestion: itemSuggestion),
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
                        // Pro Zeile statt pro Abschnitt: Diese Zeilen wischen,
                        // und ein flacher Hintergrund zeigt dabei eine eckige
                        // Kante. Die Rundung gilt jetzt je Abschnitt.
                        .groupedRowBackground(
                            GroupedRowPosition(index: index, count: section.items.count)
                        )
                    }
                } header: {
                    if showsHeaders {
                        Text(section.category)
                            .accessibilityIdentifier("list.section.\(section.category)")
                    }
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
        // **Wer die Liste anfasst, ist mit dem Aufschreiben fertig.** Der
        // zweite Ausgang aus dem Tipp-Fluss neben „Tastatur weg": Ohne ihn
        // bliebe die Angaben-Schicht stehen, während man schon durch die Liste
        // scrollt — und nähme ihr genau dort Platz weg, wo man gerade hinsieht.
        .scrollDismissesKeyboard(.immediately)
        // **Und der Ausgang gilt auch ohne Tastatur.** `scrollDismissesKeyboard`
        // räumt eine Tastatur weg; wo nie eine stand (der Weg über „Häufig
        // gekauft"), räumte es nichts, und die Schicht blieb über der Liste
        // stehen — am 03.08. gemessen: 482 pt von 874, auch nach dem Scrollen.
        // Der Zug an der Liste ist das Signal, nicht der Fokus.
        .simultaneousGesture(
            DragGesture(minimumDistance: 12).onChanged { _ in
                if addFlow.isActive { endFlow() }
            }
        )
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
            detailPanel
            inputBar
        }
        // Eine Fläche für beides. Vorher trug die Eingabezeile den Hintergrund
        // allein; zwei übereinandergelegte `.bar`-Flächen ergäben eine Kante
        // quer über den Block.
        .background(.bar)
    }

    /// Die Wörterbuchwörter zum getippten Text — leer, solange nichts getippt
    /// ist.
    private var typedTerms: [String] {
        TermSuggestions.words(for: newItemText, in: offerStore.offers)
    }

    /// **Beim Tippen zeigt dieselbe Fläche etwas anderes.**
    ///
    /// **Eine feste Höhe, und der Grund dafür ist nachgemessen ein anderer als
    /// der naheliegende.** Die Vermutung war: Wächst die Fläche, schiebt sie
    /// die Eingabezeile unter dem Daumen weg. Sie tut es nicht — die Zeile ist
    /// das **unterste** Element des Blocks, sie klebt an der Tastaturkante, und
    /// die Fläche wächst nach oben. Genau das hat L-2 (PR #29) gekauft.
    /// Nachgeprüft, indem die feste Höhe probeweise entfernt wurde: Die Zeile
    /// stand trotzdem auf den Zehntel-Punkt still.
    ///
    /// Was sich sehr wohl bewegt hätte, sind **die Kacheln selbst**. Die
    /// Trefferzahl ist mit jedem Buchstaben eine andere; eine mitwachsende
    /// Fläche schöbe die Kachel, auf die man gerade zielt, unter dem Finger
    /// weg. Deshalb **eine** Reihe von fester Höhe, die zur Seite scrollt,
    /// statt eines Rasters, das nach oben wächst — und deshalb auch keine
    /// Leerfläche unter einer einzelnen Kachel.
    @ViewBuilder
    private var suggestionSurface: some View {
        if !newItemText.trimmingCharacters(in: .whitespaces).isEmpty {
            termSurface
        } else {
            stapleSurface
        }
    }

    /// **Der Vorschlagsstreifen weicht dem Angaben-Panel — mit zwei Ausnahmen.**
    ///
    /// Beides gleichzeitig stehen zu lassen wäre der bequeme Weg gewesen und
    /// hätte den Block unten auf über 300 Punkte gebracht; von der Liste, in
    /// die man gerade etwas einträgt, bliebe neben der Tastatur kaum etwas
    /// übrig. Also weicht der Streifen — aber **nicht** stillschweigend: Der
    /// Winkel-Knopf links im Feld holt ihn zurück, und genau dafür gibt es ihn.
    ///
    /// Die zweite Ausnahme ist der Rundgang. Sein Rahmen „Oder nimm einen
    /// Vorschlag" hängt am Anker der Kacheln; ein Tester, der im Rahmen davor
    /// wirklich etwas tippt, hätte den Rahmen sonst übersprungen bekommen —
    /// und zwar genau dann, wenn er der Aufforderung gefolgt ist.
    private var showsStapleSurface: Bool {
        guard surfaceIsExpanded else { return false }
        return !detailPanelIsUp || suggestionChoice == true || tutorial?.isRunning == true
    }

    @ViewBuilder
    private var stapleSurface: some View {
        let remaining = suggestions
        if !remaining.isEmpty && showsStapleSurface {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Häufig gekauft")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                // **Neben der Angaben-Schicht schrumpft der Streifen auf eine
                // Reihe.** Gemessen am 03.08.: Beides in voller Größe brachte
                // den Block unten auf 482 pt von 874 — 55 % des Bildschirms für
                // das Anlegen eines Artikels, und die Liste, in die man ihn
                // gerade einträgt, war auf eine Zeile geschrumpft.
                //
                // Nicht weggelassen, sondern gekürzt: Der zweite Vorschlag muss
                // **einen Tipp** weit weg bleiben. Genau das war am 26.07. schon
                // einmal kaputt, als die Fläche beim ersten Artikel zuschlug.
                if detailPanelIsUp {
                    suggestionRow(remaining)
                } else {
                    suggestionChips(remaining)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .readableWidth()
            // **Auf- und zuziehen, beides von unten.**
            //
            // Vorher stand hier ein reines Ausblenden, mit der Begründung, zwei
            // Bewegungen gegeneinander sähen aus wie ein Ruckler. Am Simulator
            // Bild für Bild nachgesehen (03.08., Scotts Punkt 7) ist es
            // schlimmer: Der Block klappt in **einem** Bild zusammen, die
            // Eingabezeile sitzt sofort unten — und die Kacheln bleiben als
            // durchsichtige Geister über der Liste hängen, außerhalb der
            // Fläche, zu der sie gehören. Das ist kein Übergang, das ist ein
            // Rest.
            //
            // Mit derselben Bewegung in beide Richtungen fahren sie unter die
            // Eingabezeile, statt im Nichts zu verblassen.
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// Das Raster beim Tippen.
    ///
    /// **Und die Zeile, wenn nichts passt, gehört dazu.** Sie ist der Grund,
    /// aus dem die Fläche auch dann steht, wenn sie leer ist: „Kein Begriff
    /// passt" ist eine Auskunft, kein Fehler — dieselbe Unterscheidung, die der
    /// Kopf des Trefferblatts seit dem 01.08. trifft. Ein Raster, das sich
    /// stillschweigend schließt, sagt genau das nicht.
    private var termSurface: some View {
        let terms = typedTerms
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(terms.isEmpty ? "Kein bekannter Begriff" : "Le Chariot kennt")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .accessibilityIdentifier("list.terms.title")

            Group {
                if terms.isEmpty {
                    Text("Kein Wort im Wörterbuch passt zu \u{201E}\(newItemText.trimmingCharacters(in: .whitespaces))\u{201C}. Aufschreiben kannst du es trotzdem.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("list.terms.empty")
                } else {
                    termChips(terms)
                }
            }
            // Die eine Zahl, an der alles hängt: Kachelhöhe. Ob eine Kachel
            // dasteht, sechs oder keine, ändert an ihr nichts.
            .frame(height: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
        .readableWidth()
    }

    private func termChips(_ terms: [String]) -> some View {
        // Waagerecht statt als Raster: Eine Reihe kann acht Kacheln tragen,
        // ohne dabei höher zu werden. Ein Raster müsste entweder umbrechen
        // (dann wandern die Kacheln) oder abschneiden (dann sind Begriffe
        // unerreichbar, die es gibt).
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(terms, id: \.self) { term in
                Button {
                    // Der Tipp legt **das Wort** auf die Liste, nicht den
                    // getippten Anfang. Genau dafür ist das Raster da: Was
                    // hier steht, versteht der Matcher.
                    newItemText = ""
                    // **Zweimal, und das ist derselbe Fund wie in `addItem`:**
                    // Der Tipp auf eine Kachel nimmt dem Feld den Fokus, und
                    // zwar **nach** dieser Zeile. Ohne den Durchgang Geduld
                    // stand `inputFocused` einen Wimpernschlag später auf
                    // `false`, der Fluss beendete sich selbst — und die
                    // Angaben-Schicht war weg, bevor jemand sie gesehen hat.
                    inputFocused = true
                    keepTyping()
                    // Nur bei Erfolg: Bei einem Duplikat legt `add` nichts an,
                    // und `lastAdded` wäre dann ein fremder Eintrag.
                    let angelegt = withAnimation { list.add(term) }
                    if angelegt { beginFlow(with: list.lastAdded) }
                } label: {
                    Text(term)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, Theme.Spacing.md)
                        .frame(minWidth: 96)
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
                    .accessibilityLabel("\(term) hinzufügen")
                }
            }
        }
    }

    /// Dieselben Vorschläge, nur als eine seitlich scrollende Reihe — die
    /// Fassung neben der Angaben-Schicht. 44 pt statt 148, und der nächste
    /// Vorschlag bleibt einen Tipp weit weg.
    private func suggestionRow(_ staples: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(staples, id: \.self) { staple in
                    Button {
                        suggestionChoice = true
                        let angelegt = withAnimation { list.add(staple) }
                        if angelegt { beginFlow(with: list.lastAdded) }
                    } label: {
                        Text(staple)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, Theme.Spacing.md)
                            .frame(minWidth: 96)
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
        }
        // Der Rundgang-Anker gehört auf die Fassung, die er ausleuchtet — und
        // während des Rundgangs steht immer die volle. Hier also keiner: zwei
        // Anker desselben Ziels entscheidet der Preference-Merge, siehe L-2.
        .frame(height: 44)
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
                    // Nur bei Erfolg — siehe die Vorschlagskacheln oben.
                    let angelegt = withAnimation { list.add(staple) }
                    if angelegt { beginFlow(with: list.lastAdded) }
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

    // MARK: Angaben

    /// Der Artikel, dessen Angaben unten stehen — **frisch aus dem Speicher**.
    ///
    /// `AddFlowState` hält nur die Identität. Eine Kopie hier wüsste nichts von
    /// den Chips, die man ihr gerade gibt, und das Panel bliebe grau, während
    /// die Liste die Angabe schon trägt.
    private var activeFlowItem: ShoppingItem? {
        // **Während des Rundgangs zeigt das Panel genau dort, wo sein Rahmen es
        // erklärt — und sonst nirgends.** Der erste Rahmen lädt zum Tippen ein
        // („Probier es gleich aus"); wer das tut, hätte die Schicht sonst über
        // den ganzen Rundgang stehen und nähme damit den datenabhängigen
        // Rahmen darunter (Plan-Karte, Treffer-Zeile) ihren Platz — die
        // überspringen sich dann selbst, und zwar ausgerechnet bei dem, der
        // der Aufforderung gefolgt ist.
        if tutorial?.isRunning == true { return tourPanelItem }
        guard let id = addFlow.activeID else { return nil }
        return list.items.first { $0.id == id }
    }

    /// Was der Rundgang zeigen will. Sein Rahmen zu den Angaben darf nicht
    /// davon abhängen, dass der Tester im Rahmen davor wirklich getippt hat —
    /// dann steht dort der zuletzt angelegte Artikel, sonst der letzte
    /// Beispiel-Artikel.
    private var tourPanelItem: ShoppingItem? {
        guard tutorial?.isRunning == true, tutorial?.step.showsDetailPanel == true else {
            return nil
        }
        if let id = addFlow.activeID, let item = list.items.first(where: { $0.id == id }) {
            return item
        }
        return list.uncheckedItems.last
    }

    /// **Ein Blatt schlägt das Panel.** Beide zeigen denselben Wortschatz; wer
    /// die volle Fassung geöffnet hat, will sie und nicht ihren Schatten
    /// darunter — und zwei Sätze gleich beschrifteter Chips auf einem
    /// Bildschirm sind für eine Journey nicht auseinanderzuhalten.
    private var detailPanelIsUp: Bool {
        activeFlowItem != nil && editingItem == nil && detailItem == nil
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let item = activeFlowItem, editingItem == nil, detailItem == nil {
            ItemDetailPanel(
                item: item,
                recent: recentFlowItems(active: item),
                onFocus: { addFlow.focus($0.id) },
                onToggleChip: { word in
                    // **Sofort durchgeschrieben, ohne „Fertig".** Das ist der
                    // ganze Unterschied zum Blatt: Es gibt nichts zu
                    // bestätigen, also auch nichts zu verlieren, wenn man
                    // stattdessen weitertippt.
                    withAnimation(.snappy) {
                        list.setDetail(
                            ItemDetailVocabulary.toggling(word, in: item.detail ?? []),
                            for: item
                        )
                    }
                },
                onOpenFull: { editingItem = item },
                onDismiss: { endFlow() }
            )
            .tutorialAnchor(.detailPanel)
        }
    }

    /// Die Kachelzeile über dem Panel. Der aktive Artikel ist immer dabei —
    /// auch dann, wenn der Rundgang ihn gesetzt hat und der Fluss leer ist.
    private func recentFlowItems(active: ShoppingItem) -> [ShoppingItem] {
        let ids = addFlow.recent
        let known = ids.compactMap { id in list.items.first { $0.id == id } }
        return known.contains(where: { $0.id == active.id }) ? known : known + [active]
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
                // „Weiter", nicht „Fertig": Die Rückgabetaste legt seit dem
                // 03.08. wirklich den nächsten Artikel an, statt das Feld zu
                // schließen. Eine Beschriftung, die etwas anderes verspricht
                // als die Taste tut, ist die kleinste mögliche Lüge — und die
                // erste, die jemand ausprobiert.
                .submitLabel(.next)
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
        keepTyping()
        // **Das Mengen-Menü kommt von selbst** ([UI-8], Scott 01.08.) — der
        // Moment nach dem Anlegen ist der einzige, in dem jemand noch weiß,
        // welche Größe er meint. Seit dem 03.08. als Schicht statt als Blatt:
        // Der Fokus bleibt im Feld, das nächste Wort ersetzt das Panel
        // einfach. Siehe `ItemDetailPanel`.
        beginFlow(with: list.lastAdded)
        // Wer tippt, weiß was er braucht — die Fläche gibt der Liste ihren
        // Platz zurück. Die Gegenrichtung steht bei den Kacheln.
        withAnimation(.snappy) { suggestionChoice = false }
    }

    /// **Der Fokus bleibt im Feld — und das kostet einen Umweg.**
    ///
    /// `inputFocused = true` **im** `onSubmit` verpufft: SwiftUI gibt den Fokus
    /// nach dem Absenden selbst ab, und zwar nach dem Aufruf. Am Simulator
    /// gemessen (03.08.): Nach „Butter⏎" stand `app.keyboards.count` auf 0,
    /// obwohl genau diese Zeile seit dem 31.07. im Code steht und ein Kommentar
    /// daneben „die Tastatur bleibt stehen" behauptete. **Die Zusage war nie
    /// eingelöst** — sie ist nur nicht aufgefallen, weil danach ohnehin ein
    /// Blatt aufging und den Fokus mitnahm.
    ///
    /// Im nächsten Durchgang hält es. Das ist ein Wimpernschlag ohne Fokus, und
    /// deshalb wartet `endFlowIfTypingStopped` einen Moment, bevor es den Fluss
    /// beendet.
    private func keepTyping() {
        Task { @MainActor in
            inputFocused = true
            // **Und ein zweites Mal.** Ein Durchgang reicht meistens, aber
            // nicht immer: Wer zwei Wörter ohne Pause absendet, verlor am
            // 03.08. reproduzierbar den Fokus zwischen ihnen — im Testlauf zwei
            // bis vier von sechs Journeys, jedes Mal eine andere. Mit einer
            // Pause von einer Zehntelsekunde dazwischen lief es sechsmal
            // hintereinander durch. Das Nachfassen kostet nichts und macht die
            // Zusage unabhängig davon, welcher Durchgang zuerst dran war.
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled, addFlow.isActive else { return }
            inputFocused = true
        }
    }

    /// Ein Artikel ist entstanden — der Fluss nimmt ihn auf.
    private func beginFlow(with item: ShoppingItem?) {
        guard let item else { return }
        withAnimation(.snappy) { addFlow.added(item.id) }
    }

    /// **Der Ausgang, der keine Tastatur braucht.**
    ///
    /// Bis zum 03.08. gab es nur einen: „die Tastatur ist unten". Auf dem Weg
    /// über „Häufig gekauft" stand aber nie eine — und damit war die Schicht
    /// dort nicht verlassbar (Scotts Punkt 9). Der Fokus wird trotzdem
    /// mitgenommen, wo einer liegt: Sonst zöge `keepTyping` die Schicht im
    /// nächsten Durchgang wieder auf.
    private func endFlow() {
        inputFocused = false
        withAnimation(.snappy) { addFlow.end() }
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
