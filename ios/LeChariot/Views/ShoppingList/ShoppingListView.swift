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
    /// Die vier Einmal-Schilder — optional, damit Previews ohne sie
    /// auskommen. Die Liste meldet ihm
    /// nur Momente; entschieden wird in `ContextTipRules`.
    @Environment(ContextTipStore.self) private var tips: ContextTipStore?
    /// Die zwei ersten Male (Artikel, Treffer) und die Checkliste dazu.
    @Environment(SetupProgressStore.self) private var setup
    /// Der Merker für die Marktwertung — siehe `ShoppingListPlan`. Er gehört der
    /// Ansicht und nicht dem Store: Gerechnet wird über die **offenen** Artikel
    /// dieses Bildschirms, und die Ansicht ist die Stelle, die sie kennt.
    @State private var planMemo = ShoppingListPlan()
    /// Der Artikel, dessen Blatt gerade oben steht — Angaben **und** Treffer,
    /// siehe `ItemSheet`. Bis zum 10.08. waren das zwei Zustände.
    @State private var sheetItem: ShoppingItem?
    /// Ob das Blatt mit aufgeklappten Angaben aufgehen soll — siehe `ItemSheet`.
    @State private var sheetOpensAngaben = false
    @State private var newItemText = ""
    @FocusState private var inputFocused: Bool
    /// Der laufende Tipp-Fluss — siehe `AddFlowState` und `ItemDetailPanel`.
    /// Bewusst `@State` und nicht persistiert: Er endet mit der Tastatur.
    @State private var addFlow = AddFlowState()
    /// Die Wertung, die hinter „Passende Artikel im Angebot" liegt — gesetzt
    /// beim Antippen, damit das Blatt genau den Lauf zeigt, dessen Zahlen in
    /// der Zeile standen. Siehe `OfferHitsView`.
    @State private var hitsRanks: [MarketListRank]?
    /// Weggewischte Beispiel-Angebote der leeren Liste. Bewusst `@State` und
    /// nicht persistiert: Die Fläche existiert nur bis zum ersten Artikel,
    /// und ein Nein zu einem Wochenangebot ist keins für immer.
    @State private var dismissedExamples: Set<String> = []
    /// Die Zeile, deren Treffer-Kachel gerade einmalig aufleuchtet — der
    /// Aha-Moment beim allerersten Treffer. Siehe die Aufgabe an
    /// `firstMatchArrived`.
    @State private var glowItemID: UUID?

    /// Die Oberkante der Tastatur im Fenster, sonst `nil`.
    ///
    /// **Aus der Systemmeldung, nicht aus einem `GeometryReader`** — und das
    /// ist nachgemessen, nicht Geschmack. Jeder Reader hier drin liefert
    /// entweder das ganze Fenster (`ignoresSafeArea`: 874 pt, Einzüge 0) oder
    /// eine Höhe, in der der Block unten schon abgezogen ist (gemessen 477 pt
    /// bei 335 pt unterem Einzug). Die zweite Zahl den Block bemessen zu
    /// lassen, der sie erzeugt, ist eine Rückkopplung. Die Tastatur meldet ihre
    /// Lage von außen.
    ///
    /// **Diese Kante liegt höher als die, die eine Journey sieht**: Die Meldung
    /// zählt die Vorschlagszeile („Ich · Ja · Das") mit, `app.keyboards` nicht —
    /// auf dem 17 Pro 539 statt 583. Die 539 ist die richtige, denn dort endet
    /// der Block.
    @State private var tastaturOben: CGFloat?

    /// Der obere Sicherheitsabstand — Statusleiste bzw. Dynamic Island.
    /// Vom Block unten unberührt, deshalb hier gefahrlos aus der Geometrie.
    @State private var sicherOben: CGFloat = 0

    /// Die Höhe der Eingabezeile. Sie hängt nicht an der Schicht über ihr,
    /// deshalb ist sie messbar, ohne sich selbst zu bemessen.
    @State private var eingabeHoehe: CGFloat = 0

    /// Was über dem Block stehen bleiben muss: **eine ganze Kachelreihe.**
    ///
    /// Die Zahl ist die gemessene Höhe einer Rasterzeile aus drei Kacheln
    /// (#91). Sie skaliert mit der Schrift, weil die Kachel es tut — sonst
    /// reservierte ein großer Schriftgrad zu wenig.
    @ScaledMetric(relativeTo: .body) private var kachelReihe: CGFloat = 120

    /// Wie viel Höhe die Angaben-Schicht bekommen darf, damit über dem ganzen
    /// Block eine Kachelreihe stehen bleibt. `nil` heißt „keine Tastatur, keine
    /// Enge" — dann ist die Schicht so hoch, wie ihr Inhalt es will.
    ///
    /// **Als Zahl weitergereicht, nicht als `frame(maxHeight:)`.** Der Rahmen
    /// war der erste Versuch und kostete gemessen 2,33 pt, *auch wenn er gar
    /// nicht griff* (Blockoberkante 188,67 statt 191) — und genau diese zwei
    /// Punkte sind auf dem 17 Pro die ganze Reserve.
    ///
    /// **Genau eine Kachelreihe, kein Abstand obendrauf** — auch das ist
    /// gemessen. Mit 8 pt Luft fällt der 17 Pro von vier Reihen auf drei: Dort
    /// stehen 297 pt zur Verfügung und vier Reihen brauchen 292. Die Zusage ist
    /// „eine ganze Kachelreihe", und die hält diese Rechnung; die 5 pt, die
    /// dabei übrig bleiben, sind Zugabe, keine Voraussetzung.
    private var platzFuerAngaben: CGFloat? {
        guard let tastaturOben, eingabeHoehe > 0 else { return nil }
        return max(0, tastaturOben - sicherOben - kachelReihe - eingabeHoehe)
    }

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


    /// Der Plan der Woche — **über den Merker, nicht direkt gerechnet.**
    ///
    /// Drei Leser in diesem Rumpf hängen daran (`listBody`, `openGroups`,
    /// `firstMatchArrived`), und ein Rumpf läuft bei jeder Zustandsänderung.
    /// Direkt gerufen kostete das je Tipp ein Mehrfaches von 42 ms (gemessen bei
    /// 1 200 Prospektzeilen, Debug am Simulator, `TippKostenProbe`); siehe
    /// `ShoppingListPlan`.
    private var ranks: [MarketListRank] {
        planMemo.ranks(
            items: list.uncheckedItems,
            offers: offerStore.offers,
            offerGeneration: offerStore.generation,
            chains: chains,
            rejections: rejections.rejected
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

    /// Was die Einmal-Tipps über die Liste wissen müssen — als Wert, damit
    /// `.task(id:)` genau dann neu läuft, wenn sich daran etwas ändert.
    /// `guidanceVisible` gehört dazu: Auch das Verschwinden der Checkliste
    /// (versiegelt nach dem ersten Treffer) ist ein Moment, an dem ein
    /// wartender Tipp drankommen darf.
    private struct ListTipMoment: Equatable {
        var flowActive: Bool
        var matchVisible: Bool
        var openCount: Int
        var guidanceVisible: Bool
    }

    private var listTipMoment: ListTipMoment {
        ListTipMoment(
            flowActive: addFlow.isActive,
            matchVisible: firstOpenHasMatch,
            openCount: list.uncheckedItems.count,
            guidanceVisible: guidanceBlocksTips
        )
    }

    /// Ob die erste offene Zeile eine Angebotskachel trägt — die Zeile, an der
    /// der Treffer-Tipp hängt. Bewusst der billige Weg über `cheapestMatch` statt der
    /// vollen `suggestion(for:plan:)`: Die rechnete hier den ganzen Plan ein
    /// zweites Mal je Durchlauf. In den Randfällen, in denen beide auseinander
    /// liegen (schlafende Heftung), verschiebt sich der Tipp höchstens auf
    /// eine spätere Sitzung — er verschwindet nicht.
    private var firstOpenHasMatch: Bool {
        guard hasMarkets, let first = list.uncheckedItems.first else { return false }
        return ShoppingListMatcher.cheapestMatch(for: first.query, in: offerStore.offers) {
            rejections.isRejected(itemText: first.query, offer: $0)
        } != nil
    }

    // MARK: Führung (geführter erster Artikel, Checkliste)

    /// Welche Führungsfläche gerade dran ist — die Vorfahrtsregel steht
    /// in `ListGuidance`, hier stehen nur die sieben Eingaben.
    private var guidance: ListGuidance {
        ListGuidance.surface(
            listIsEmpty: list.items.isEmpty,
            hasMarkets: hasMarkets,
            firstItemAdded: setup.firstItemAdded,
            checklistVisible: setup.checklistIsVisible(hasMarkets: hasMarkets),
            flowActive: addFlow.isActive,
            tipActive: activeListTip != nil
        )
    }

    /// Das aktive Schild, sofern es zu **diesem** Bildschirm gehört —
    /// der Vorschau-Tipp des Angebote-Tabs zählt hier nicht.
    private var activeListTip: ContextTip? {
        tips?.activeTip(on: .list)
    }

    /// Ob eine Führungsfläche den Bildschirm hätte, wenn kein Tipp aktiv wäre
    /// — die Eingabe für die Tipp-Aktivierung (`ContextTipRules.tipOnList`):
    /// Ein Tipp feuert nur auf die freie Liste, eine Fläche nach der anderen.
    /// Ohne Tipp und ohne Fluss gerechnet, denn gefragt ist der Zustand, in
    /// dem der Tipp **stünde**, nicht der Moment des Fragens.
    private var guidanceBlocksTips: Bool {
        ListGuidance.surface(
            listIsEmpty: list.items.isEmpty,
            hasMarkets: hasMarkets,
            firstItemAdded: setup.firstItemAdded,
            checklistVisible: setup.checklistIsVisible(hasMarkets: hasMarkets),
            flowActive: false,
            tipActive: false
        ) != .none
    }

    /// Die Beispiel-Angebote der leeren Liste. Leer ohne Filialen — dann
    /// trägt `FirstItemPrompt` die Einladung (siehe `FirstItemSuggestions`).
    private var firstItemExamples: [FirstItemExample] {
        FirstItemSuggestions.examples(from: offerStore.offers, excluding: dismissedExamples)
    }

    /// Ob gerade der **allererste** Treffer auf dem Bildschirm steht.
    ///
    /// Kurzgeschlossen über den persistierten Merker: Nach dem ersten Mal
    /// kostet die Frage nichts mehr.
    private var firstMatchArrived: Bool {
        guard !setup.firstMatchSeen,
              !list.items.isEmpty else { return false }
        // Direkt an der Wertung abgelesen: `OfferHitSummary` hat diese Frage
        // bis zum 06.08. beantwortet und ist mit der Trefferzeile weggefallen.
        // Es war ohnehin nur diese eine Zeile Arithmetik.
        return ranks.contains { $0.matchedCount > 0 }
    }

    /// Ein Artikel ist auf einem Bedienweg entstanden — nicht durch den
    /// Rundgang, dessen Beispiel-Artikel bewusst nicht zählen.
    private func recordUserAdd() {
        setup.recordItemAdded()
    }

    /// Der geführte erste Artikel: anlegen, merken — und **ohne** die
    /// Angaben-Schicht. Der Blick soll auf die Zeile mit ihrer Treffer-Kachel
    /// fallen (das ist der Aha-Moment), nicht auf ein Panel darüber.
    private func addGuidedItem(_ word: String) {
        let angelegt = withAnimation(.snappy) { list.add(word) }
        guard angelegt else { return }
        recordUserAdd()
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
            .overlay(alignment: .top) { obereBlende }
            .navigationTitle("Einkaufsliste")
            // **Kompakt statt groß.** Der große Titel kostet oben rund 56 pt
            // für ein Wort, das die Tab-Leiste unten ohnehin schon sagt. Auf
            // dem Bildschirm, für den es die App gibt, ist das der teuerste
            // Platz — vor der Entschlackung am 06.08. fing der erste Artikel
            // der Liste bei 535 von 874 pt an.
            .navigationBarTitleDisplayMode(.inline)
            // **Beim Tippen gibt die Titelleiste ihren Platz ab**
            // (2026-08-08, Scotts Nachrunde zu Punkt C).
            //
            // Der Vergleich mit Bring! hing an einer Zahl, die nicht im Panel
            // steckt: **Bring! hat über der Liste gar nichts.** Ihre obere
            // Zone ist Statusleiste plus genau eine Kachelreihe. Bei uns
            // liegen dort zusätzlich 54 pt Titelleiste — mit ihr bleiben vom
            // Zwanzig-Prozent-Streifen keine 60 pt übrig, und darin steht
            // keine einzige Kachel. Die Leiste zu behalten hieße, den oberen
            // Bereich als Zierrat zu führen.
            //
            // Verloren geht dabei nichts, was jetzt gebraucht wird: Der Titel
            // sagt „Einkaufsliste", was die Tab-Leiste ohnehin sagt, und das
            // Menü dahinter trägt „Liste leeren" — den einen Knopf, der
            // wirklich Schaden anrichtet, und der beim Aufschreiben nichts zu
            // suchen hat. Sobald „Fertig" den Fluss beendet, ist die Leiste
            // zurück.
            .toolbar(flowIsUp ? .hidden : .visible, for: .navigationBar)
            .toolbar { toolbarMenu }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        // **Der Block darf die obere Zone nicht aufessen** (09.08.).
        //
        // Bis hierher war der Block so hoch, wie sein Inhalt es wollte, und was
        // oben übrig blieb, war Rest. Auf dem Gerät, auf dem die vier
        // Chipreihen gemessen wurden, ging das mit 9 pt auf; auf einem iPhone
        // SE blieben von der oberen Zone 39 pt. Jetzt ist die Kachelreihe die
        // gesetzte Größe und der Block bekommt, was danach übrig ist —
        // `ItemDetailPanel.vocabulary` sucht sich dazu die Reihenzahl.
        .background {
            GeometryReader { proxy in
                Color.clear.onChange(of: proxy.safeAreaInsets.top, initial: true) { _, neu in
                    sicherOben = neu
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillChangeFrameNotification
        )) { meldung in
            guard let rahmen = meldung.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect else { return }
            tastaturOben = rahmen.minY
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification
        )) { _ in
            tastaturOben = nil
        }
        .task(id: branchIds) {
            await offerStore.load(branchIds: branchIds, chains: chains)
        }
        // Bestehende Installationen: Wer schon Artikel auf der Liste hat, hat
        // seinen ersten längst hinzugefügt — nur der Merker ist jünger als die
        // Liste. Ohne den Nachtrag stünde in der Checkliste ein offener Punkt
        // über einer vollen Liste.
        .task {
            if !list.items.isEmpty { setup.recordItemAdded() }
        }
        // **Der Aha-Moment.** Sobald der erste Treffer dasteht, wird er
        // festgehalten — und die Kachel der Zeile leuchtet genau einmal kurz
        // auf. Kein Konfetti: Die Treffer-Kachel selbst ist die Botschaft, das
        // Glühen lenkt nur den Blick. Ohne Filialen passiert hier nichts; der
        // Moment feuert dann nach, sobald Filialen gewählt sind und der erste
        // Treffer wirklich erscheint.
        .task(id: firstMatchArrived) {
            guard firstMatchArrived, setup.recordFirstMatch() else { return }
            let matched = Set(ranks.flatMap { $0.matchedItems.map(\.item) })
            guard let hit = list.uncheckedItems.first(where: { matched.contains($0.query) }) else {
                return
            }
            withAnimation(.snappy) { glowItemID = hit.id }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.6)) { glowItemID = nil }
        }
        // Versiegelt die Checkliste, sobald alle vier Punkte gleichzeitig
        // erfüllt waren — danach kommt sie nie wieder, auch wenn später die
        // letzte Filiale abgewählt wird.
        .task(id: "\(hasMarkets)|\(setup.firstItemAdded)|\(setup.firstMatchSeen)") {
            setup.sealIfComplete(hasMarkets: hasMarkets)
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
        // **Eine** Stelle statt drei Aufrufstellen (Feld, Wörterbuch-Kacheln,
        // Vorschlags-Kacheln): Jeder Weg, der wirklich etwas anlegt, wächst
        // hier durch.
        .onChange(of: list.items.count) { old, new in
            if new > old { tips?.itemAdded() }
        }
        // **Der Moment der Tipps ist die ruhende Liste.** Solange der
        // Tipp-Fluss läuft, tippt jemand — eine Sprechblase dazwischen wäre
        // genau das Aufdringliche, das Einmal-Tipps vermeiden sollen. Die
        // Bedingung steckt mit im `id`, damit auch das Ende des Flusses den
        // Lauf auslöst, nicht nur ein Wechsel der Zahlen.
        .task(id: listTipMoment) {
            let moment = listTipMoment
            guard !moment.flowActive else { return }
            tips?.listSettled(
                matchVisible: moment.matchVisible,
                hasOpenItems: moment.openCount > 0,
                guidanceVisible: moment.guidanceVisible
            )
        }
        // **Ein Blatt je Artikel, und es trägt beides** (10.08., Punkt A).
        // Bis heute standen hier zwei: die Treffer (`detailItem`) und die
        // Angaben (`editingItem`). Siehe `ItemSheet`.
        .sheet(item: $sheetItem) { item in
            ItemSheet(
                item: item,
                offers: offerStore.offers,
                favoriteMarkets: favoriteMarkets,
                startsWithAngaben: sheetOpensAngaben
            )
                .environment(rejections)
                // Das Blatt schreibt Angaben und Heftung selbst und muss den
                // Artikel dafür **live** lesen: `sheetItem` ist eine Kopie vom
                // Moment des Antippens und wüsste von der eigenen Änderung
                // nichts.
                .environment(list)
        }
        .sheet(item: Binding(
            get: { hitsRanks.map(RankBundle.init) },
            set: { hitsRanks = $0?.ranks }
        )) { bundle in
            OfferHitsView(ranks: bundle.ranks, favoriteMarkets: favoriteMarkets)
                .environment(list)
        }
    }

    // MARK: Das Raster

    /// **Ein Abschnitt der Liste als Raster** (2026-08-07, Scott: „i want the
    /// list to look like bring").
    ///
    /// Bis heute war jeder Artikel eine `List`-Zeile mit Kreis, Name und
    /// Angebotszeile — vier Artikel füllten den Bildschirm. Jetzt trägt **eine**
    /// Zeile der `List` das ganze Raster eines Abschnitts. Die Karten darüber
    /// (Plan, Tipp, Checkliste) bleiben eigene Zeilen; sie sind Fließtext und
    /// gehören nicht ins Raster.
    ///
    /// `.adaptive` statt fester Spalten: Auf dem iPhone kommen **drei** heraus
    /// (seit 08.08., vorher vier), auf dem iPad entsprechend mehr — ohne zweite
    /// Regel. Die Zahl und ihre Begründung stehen bei `ShoppingGridTile.columns`.
    ///
    /// **Was mit den Zeilen weggefallen ist**, steht nicht mehr auf der
    /// Fläche: der Satz „Diese Woche nirgends im Angebot", der Hinweis auf ein
    /// Wort ohne Wörterbucheintrag, und der Satz zur schlafenden Wahl. Eine
    /// Kachel von 76 pt trägt keinen Satz. Alle drei stehen weiterhin im
    /// Trefferblatt, das das Kontextmenü der Kachel öffnet, und der
    /// Vorlesetext der Kachel spricht sie unverändert aus.
    private func raster(_ items: [ShoppingItem], plan: [MarketListRank]) -> some View {
        LazyVGrid(
            columns: ShoppingGridTile.columns,
            alignment: .leading,
            spacing: Theme.Spacing.lg
        ) {
            ForEach(items) { item in
                ShoppingGridTile(
                    item: item,
                    suggestion: suggestion(for: item, plan: plan),
                    highlightsFirstMatch: item.id == glowItemID,
                    onToggle: { check(item) },
                    onOpenItem: { openSheet(for: item) },
                    onDelete: { list.remove(item) }
                )
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .listRowBackground(Color.clear)
        // Ohne das zieht die `List` eine Haarlinie unter das ganze Raster —
        // eine Trennlinie zwischen Kacheln und Nichts.
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(
            top: Theme.Spacing.xs, leading: Theme.Spacing.lg,
            bottom: Theme.Spacing.xs, trailing: Theme.Spacing.lg
        ))
    }

    // MARK: List

    /// **Die Abschnitte der offenen Artikel — an einer Stelle**, weil zwei
    /// Stellen sie verschieden ausrechnen würden und das Mitscrollen dann auf
    /// einen Abschnitt zielte, den die Liste gar nicht zeichnet.
    ///
    /// **Ohne Überschriften auch ohne Abschnitte.** Am 06.08. am Gerät
    /// gesehen: Die Überschriften waren weg, die Abschnitte standen aber
    /// weiter als eigene Blöcke da — drei Artikel, drei Karten, dazwischen je
    /// rund 40 pt Luft, und der Bildschirm war voll.
    ///
    /// Dazu kommt der zweite Grund, und der wiegt schwerer: Abschnitte
    /// sortieren die Liste um. Mit Überschrift ist das erklärt, ohne sie ist es
    /// eine Umsortierung, die niemand angefordert hat und die aussieht wie ein
    /// Fehler. Dann gilt die eigene Reihenfolge.
    private func openGroups(plan: [MarketListRank]) -> (groups: [ShoppingSection], showsHeaders: Bool) {
        let byQuery = ShoppingSections.categories(from: plan)
        let sections = ShoppingSections.build(items: list.uncheckedItems) {
            byQuery[$0.query] ?? ShoppingSections.warengruppe(forItem: $0.query)
        }
        guard ShoppingSections.needsHeaders(sections) else {
            return ([ShoppingSection(category: "", items: list.uncheckedItems)], false)
        }
        return (sections, true)
    }

    private var openGroups: [ShoppingSection] { openGroups(plan: ranks).groups }

    /// **Die obere Kante beim Tippen** (10.08., erster Befund des Zonen-Bildes
    /// vom 08.08.).
    ///
    /// Sobald die Titelleiste abtritt (`flowIsUp`), hat die Liste über sich
    /// nichts mehr — und die Kacheln der oberen Zone fahren **hart** unter die
    /// Uhr. Solange die Leiste stand, machte deren Unschärfe diese Arbeit; mit
    /// ihr ist sie ersatzlos weggefallen, und das war an dem Umbau nicht
    /// beabsichtigt.
    ///
    /// **Kein Balken, sondern ein Verlauf, und keine Höhe zurück.** Ein
    /// undurchsichtiger Streifen wäre die Titelleiste unter anderem Namen —
    /// die 54 pt, um die es am 08.08. ging. Der Verlauf liegt **über** der
    /// Liste, nimmt ihr also nichts: Die Kachelreihe steht, wo sie steht, sie
    /// verschwindet nur, statt abgeschnitten zu werden.
    ///
    /// `sicherOben` ist die gemessene sichere Fläche (dasselbe Maß, mit dem
    /// `platzFuerAngaben` rechnet), nicht eine Zahl für ein Gerät — auf einem
    /// SE sind es 20 pt statt 59, und ein fester Wert wäre dort ein Balken über
    /// dem Inhalt.
    ///
    /// **Die Blende hört an der sicheren Fläche auf, und das ist die
    /// Korrektur am ersten Entwurf.** Der deckte 59 pt voll und blendete 24 pt
    /// darunter aus — am gerenderten Bild hat er die obere Kachelreihe damit
    /// nicht ausgeblendet, sondern **verschwinden lassen**: In derselben Lage,
    /// in der vorher drei Kacheln halb unter der Uhr standen, stand nachher
    /// eine leere Fläche. Das ist die Titelleiste unter anderem Namen, also
    /// genau das, was am 08.08. abgeräumt wurde.
    ///
    /// Voll deckt sie deshalb nur die **obere Hälfte** der sicheren Fläche —
    /// dort steht die Uhr, und die muss lesbar bleiben —, und an deren
    /// Unterkante ist sie durchsichtig. Unterhalb der sicheren Fläche liegt
    /// nichts von ihr; keine Kachel, die im Bild steht, wird dunkler.
    @ViewBuilder
    private var obereBlende: some View {
        if flowIsUp, sicherOben > 0 {
            LinearGradient(
                stops: [
                    .init(color: Theme.background, location: 0),
                    .init(color: Theme.background, location: 0.5),
                    .init(color: Theme.background.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: sicherOben)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .ignoresSafeArea(edges: .top)
        }
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            listBody
                // **Der obere Rest folgt dem zuletzt angelegten Artikel**
                // (2026-08-08, Scotts Punkt C-2).
                //
                // Beim Tippen bleibt von der Liste ein Streifen von rund 250
                // pt übrig — die Tastatur nimmt ein Drittel, die Angaben und
                // die Eingabezeile ein knappes Viertel, die Navigationsleiste
                // den Rest oben. Was in diesem Streifen stand, war bisher der
                // Anfang der Liste: richtige Auskunft, falscher Moment.
                // Bring! zeigt dort, was gerade entstanden ist.
                //
                // **Das Ziel ist der Abschnitt, nicht die Kachel — gemessen,
                // nicht gewählt.** Der erste Anlauf hängte `.id` an die Kachel
                // selbst; am Simulator stand die zuletzt getippte danach
                // unverändert unter dem Bildschirm (y = 861 von 874). Eine
                // `List` ist UIKit-getragen, und `ScrollViewReader` erreicht
                // ihre **Zeilen**; das ganze Raster eines Abschnitts ist eine
                // einzige davon. `.bottom` ist damit genau richtig: Der neue
                // Artikel steht immer als letzter in seinem Abschnitt, also
                // in dessen unterster Kachelreihe.
                //
                // **Nur der frisch angelegte zieht den Blick.** Ein Tipp auf
                // eine ältere Kachel der Angaben-Zeile wechselt den aktiven
                // Artikel auch — dort wäre der Abschnitt aber das falsche
                // Maß, weil der Artikel irgendwo mittendrin steht. Die Zusage
                // lautet „die Liste folgt dem zuletzt **angelegten** Artikel",
                // und genau die wird hier eingelöst.
                .onChange(of: addFlow.activeID) { _, id in
                    guard let id, id == list.lastAdded?.id,
                          let abschnitt = openGroups.first(
                              where: { $0.items.contains { $0.id == id } }
                          ) else { return }
                    // **Einen Durchgang später, und das ist die ganze
                    // Zeile.** Im selben Durchgang gibt es die neue Zeile noch
                    // nicht: Der Aufruf zielte dann auf den Abschnitt in
                    // seiner alten Höhe, und die frische Kachel blieb hinter
                    // dem Block stehen. Dieselbe Sorte Umweg wie `keepTyping`,
                    // aus demselben Grund.
                    //
                    // **Ein ganzer Umbau hing an dieser Pause, und er war
                    // falsch.** Weil der erste Anlauf ohne sie nichts bewegte,
                    // sah es aus, als reiche die Scroll-Fläche der `List` beim
                    // Tippen bis unter den Block — gebaut war schon ein
                    // gemessenes `safeAreaPadding`, das den Bezug „korrigiert"
                    // hätte. Eine Messreihe über die Randstärke (0 / 100 / 200
                    // / 260 pt) hat es widerlegt: **Ohne jeden Rand steht die
                    // Kachel richtig** (Unterkante 343 bei einem Block ab 363),
                    // jeder Punkt Rand schiebt sie um genau einen Punkt zu
                    // weit nach oben. `safeAreaInset` hatte die ganze Zeit
                    // recht; falsch war nur der Zeitpunkt des Aufrufs.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(80))
                        guard !Task.isCancelled else { return }
                        withAnimation(.snappy) {
                            proxy.scrollTo(abschnitt.id, anchor: .bottom)
                        }
                    }
                }
        }
    }

    private var listBody: some View {
        List {
            let plan = ranks
            if !plan.isEmpty, !planCardStandsBack {
                Section {
                    ShoppingPlanCard(
                        ranks: plan,
                        winnerWithoutPins: winnerWithoutPins(plan),
                        onShowHits: { hitsRanks = plan }
                    )
                        .listRowInsets(EdgeInsets(
                            top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                            bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                        ))
                }
                .listRowBackground(Color.clear)
            } else if guidance == .noMarkets, !planCardStandsBack {
                // Der Platz der Plan-Karte bleibt besetzt, statt leer zu
                // bleiben: Was hier fehlt, ist die Antwort, für die es die App
                // gibt — und dass sie fehlt, ist das Argument, Filialen zu
                // wählen. Der Anker sitzt hier und **nur** hier; die Fassung im
                // Leerzustand trägt ihn bewusst nicht (zwei Anker desselben
                // Ziels entscheidet der Preference-Merge, siehe L-2). Ob die
                // Karte oder die Checkliste dransteht, sagt `ListGuidance` —
                // während des Rundgangs immer die Karte, seines Ankers wegen.
                Section {
                    NoMarketsCard(action: onChooseMarkets)
                        .listRowInsets(EdgeInsets(
                            top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                            bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                        ))
                }
                .listRowBackground(Color.clear)
            }

            // Der Tipp der Liste steht oben, über dem, was er erklärt — und
            // nur einer, den der Store für aktiv erklärt. Siehe
            // `ContextTipCard`. **Nur als Führungsfläche, nie zusätzlich:**
            // Der Squash-Merge vom 05.08. hatte Tipp-Abschnitt (#82) und
            // Checkliste (#80) übereinandergestapelt — zwei Karten, die beide
            // „hilf mir" sagen, genau das Gedränge, gegen das `ListGuidance`
            // gebaut ist. Jetzt entscheidet dieselbe Vorfahrtsregel auch hier.
            if guidance == .tip {
                Section {
                    ContextTipCard(store: tips, surface: .list)
                        .listRowInsets(EdgeInsets(
                            top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                            bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                        ))
                }
                .listRowBackground(Color.clear)
            }

            // Die Checkliste ersetzt die Filialen-Karte, solange sie sichtbar
            // ist — sie enthält deren Weg („Markt wählen") selbst. Siehe die
            // Vorfahrtsregel in `ListGuidance`.
            if guidance == .checklist {
                Section {
                    checklistCard
                        .listRowInsets(EdgeInsets(
                            top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                            bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                        ))
                }
                .listRowBackground(Color.clear)
            }

            // **Die Zeile „Passende Artikel im Angebot" ist am 06.08.
            // weggefallen.** Sie stand als eigene Karte unter der Plan-Karte
            // und zeigte dieselben Ketten noch einmal als Chips — zusammen 209
            // pt, bevor der erste Artikel anfing. Der Weg zu den Treffern liegt
            // jetzt in der Plan-Karte selbst; das Ziel ist unverändert.


            // **Kategorie-Abschnitte wie bei Bring!** — einsortiert wird über
            // den Treffer, den die Zeile ohnehin zeigt. Die Rechnung selbst
            // steht in `openGroups`, damit das Mitscrollen denselben Abschnitt
            // trifft, den die Liste zeichnet.
            let abschnitte = openGroups(plan: plan)
            let showsHeaders = abschnitte.showsHeaders
            ForEach(abschnitte.groups) { section in
                Section {
                    raster(section.items, plan: plan)
                        // Das Ziel des Mitscrollens — siehe `followTheFlow`
                        // oben. Eine `List`-Zeile ist die feinste Auflösung,
                        // die `ScrollViewReader` hier hergibt.
                        .id(section.id)
                } header: {
                    // **Beim Tippen ohne Überschriften.** Der Streifen über
                    // dem Block ist dann rund eine Kachelreihe hoch; eine
                    // Überschrift kostete davon 40 pt und schob genau den
                    // Artikel hinaus, den man gerade angelegt hat (gemessen:
                    // bei einem einzigen Artikel stand er 7 pt unter der
                    // Kante). Die Einteilung selbst bleibt — nur ihre
                    // Beschriftung ruht, solange getippt wird.
                    if showsHeaders, !flowIsUp {
                        // **Das gezeichnete Zeichen trägt hier die Identität.**
                        // `CategoryGlyphView` hatte in der ganzen App genau
                        // eine Aufrufstelle — als Rückfall eines Rückfalls.
                        // Fünfzehn von Hand gezeichnete Zeichen, und man bekam
                        // sie praktisch nie zu sehen.
                        HStack(spacing: Theme.Spacing.sm) {
                            CategoryGlyphView(category: section.category, size: 15)
                                .foregroundStyle(Theme.accent)
                                .accessibilityHidden(true)
                            Text(section.category)
                        }
                        .accessibilityIdentifier("list.section.\(section.category)")
                    }
                }
            }

            if !list.checkedItems.isEmpty {
                Section("Erledigt") {
                    raster(list.checkedItems, plan: plan)
                    // **Der eine Satz, der Scotts Frage beantwortet** („when
                    // does erledigt products get deleted", 10.08.). Sonst gilt
                    // hier die Regel gegen erklärenden Beitext — die Ausnahme
                    // ist, dass etwas von selbst verschwindet: Wer das nicht
                    // weiß, hält den nächsten leeren Abschnitt für einen
                    // Fehler.
                    //
                    // **Als letzte Zeile des Abschnitts, nicht als `footer`.**
                    // Gerendert (10.08.) war der Fußbereich einer `.plain`-Liste
                    // ein weißes, klebendes Band quer über die Fläche, mit
                    // Fließtext in voller Größe — er sah aus wie eine Meldung,
                    // nicht wie eine Fußnote.
                    Text("Nach einer Woche räumt \(AppBrand.name) das hier weg. Die Wörter bleiben als Vorschlag.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("list.checked.retention")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: 0, leading: Theme.Spacing.lg,
                            bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                        ))
                }
            }

        }
        // **`.plain`, und das ist der ganze Unterschied** (06.08.).
        //
        // Die App setzte **nirgends** ein `.listStyle`. Jede Liste war damit
        // `insetGrouped`, die Vorgabe von iOS — die Hälfte des Kasten-Gefühls,
        // über das Scott sich beschwert hat, kam gar nicht aus dem Theme,
        // sondern aus dem System.
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // **Der Abstand über der Plan-Karte war Luft, kein Aufbau.** Zwischen
        // der Titelleiste und der Karte lagen rund 50 pt Nichts — die
        // Standardluft, die eine gruppierte `List` über ihren ersten Abschnitt
        // legt. Auf dem Bildschirm, für den es die App gibt, ist das der
        // teuerste Platz.
        // Beim Tippen fällt auch diese Luft weg: Der Streifen über dem Block
        // ist dann rund eine Kachelreihe hoch, und 8 pt davon sind 8 pt.
        .contentMargins(.top, flowIsUp ? 0 : Theme.Spacing.sm, for: .scrollContent)
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
        if !wasChecked {
            history.record(item.query)
            // Der erste Haken ist der Moment für den Wisch-Tipp — die Werte
            // beschreiben die Liste **nach** dem Haken. Siehe `ContextTipStore`.
            tips?.checkedOff(
                matchVisible: firstOpenHasMatch,
                hasOpenItems: !list.uncheckedItems.isEmpty,
                guidanceVisible: guidanceBlocksTips
            )
        }
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
                        Text("Schreib auf, was du einkaufen willst. \(AppBrand.name) sagt dir, welche deiner Filialen die Liste am günstigsten abdeckt.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    // **Der geführte erste Artikel als ein Satz** — Teil der
                    // Ansprache, keine zweite Karte (siehe `ListGuidance`).
                    // Er steht genau dann, wenn es noch nie einen Artikel gab
                    // und keine Beispiel-Angebote da sind, die die Einladung
                    // besser tragen: direkt nach dem Onboarding also über der
                    // Filialen-Karte — der Aha-Moment passiert in den eigenen
                    // Daten, deshalb kommt der Artikel vor der Filiale.
                    if showsFirstItemPrompt {
                        FirstItemPrompt(
                            word: FirstItemSuggestions.prompt(excluding: dismissedExamples),
                            onAdd: addGuidedItem
                        )
                        .padding(.top, Theme.Spacing.sm)
                    }
                }

                switch guidance {
                case .firstItem:
                    // Echte Wochenangebote als Beispiel-Artikel. Wer eines
                    // antippt, sieht seinen ersten Artikel sofort mit
                    // Treffer-Kachel — der eingebaute Aha-Moment.
                    if !firstItemExamples.isEmpty {
                        FirstItemCard(
                            examples: firstItemExamples,
                            onAdd: addGuidedItem,
                            onDismiss: { word in
                                withAnimation(.snappy) { _ = dismissedExamples.insert(word) }
                            }
                        )
                    }
                case .checklist:
                    checklistCard
                case .noMarkets:
                    // Wer den Rundgang am Ende des Onboardings ablehnt, sieht
                    // die Frage nach den Filialen nie — und stünde ohne das
                    // hier vor einem Bildschirm, der nichts davon erwähnt.
                    // **Ohne Anker:** Der Rundgang legt für den Plan-Rahmen
                    // Beispiel-Artikel hin, spielt also nie über diesem
                    // Zustand.
                    NoMarketsCard(action: onChooseMarkets)
                case .tip, .none:
                    // `.tip` auf der leeren Liste kommt nur vor, wenn jemand
                    // nach einem aktiven Tipp alles löscht — die Tipps
                    // erklären Zeilen, und ohne Zeilen gibt es nichts zu
                    // erklären.
                    EmptyView()
                }
            }
            .padding(Theme.Spacing.xl)
        }
    }

    /// Ob die Ansprache die Einladung „Füg mal ‚Milch‘ hinzu" trägt. Nur vor
    /// dem allerersten Artikel — und nicht, wenn die Beispiel-Angebote sie
    /// schon tragen.
    private var showsFirstItemPrompt: Bool {
        guard !setup.firstItemAdded else { return false }
        switch guidance {
        case .firstItem: return firstItemExamples.isEmpty
        case .noMarkets: return true
        case .tip, .checklist, .none: return false
        }
    }

    /// Eine Fassung für beide Bildschirme (Leerzustand und Liste).
    private var checklistCard: some View {
        SetupChecklistCard(
            hasMarkets: hasMarkets,
            firstItemAdded: setup.firstItemAdded,
            firstMatchSeen: setup.firstMatchSeen,
            onChooseMarkets: onChooseMarkets,
            onAddItem: { inputFocused = true },
            onDismiss: { withAnimation(.snappy) { setup.dismissChecklist() } }
        )
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
                // **Nur die offenen sperren.** Ein abgehakter Artikel gehört in
                // den Vorrat zurück, nicht aus ihm heraus — siehe
                // `ShoppingSuggestions.openWords`.
                excluding: Set(list.uncheckedItems.map { PurchaseHistoryStore.normalized($0.text) })
            ),
            includeStaples: history.needsStaples
        )
    }

    /// Ob der Tipp-Fluss gerade läuft — Tastatur oben **oder** eine
    /// Angaben-Schicht, die über „Häufig auf der Liste" entstanden ist.
    private var flowIsUp: Bool { inputFocused || addFlow.isActive }

    /// **Die Plan-Karte tritt beim Tippen zurück** (2026-08-08, Punkt C-2,
    /// wörtlich): „Wir zeigen dort den besten Markt — die Auskunft ist
    /// richtig, aber im Moment des Tippens die falsche."
    ///
    /// Bis heute stand sie auch dann oben, wenn vom Bildschirm nur noch ein
    /// Streifen übrig war — und schob den Artikel, den man gerade angelegt
    /// hatte, aus genau diesem Streifen heraus. Bei **einem** Artikel war er
    /// damit gar nicht zu sehen: 324 pt gemessen, bei einem Block ab 183.
    ///
    private var planCardStandsBack: Bool { flowIsUp }

    /// Ob gerade etwas im Feld steht.
    private var isTyping: Bool {
        !newItemText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Welche Gestalt die Fläche über der Zeile gerade hat. Die Regel steht in
    /// `SuggestionSurface`, hier stehen nur die vier Eingaben.
    private var surfaceShape: SuggestionSurface.Shape {
        SuggestionSurface.shape(
            isTyping: isTyping,
            keyboardIsUp: inputFocused,
            detailPanelIsUp: detailPanelIsUp,
            listIsEmpty: list.items.isEmpty
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
                .background {
                    GeometryReader { proxy in
                        Color.clear.onChange(of: proxy.size.height, initial: true) { _, neu in
                            eingabeHoehe = neu
                        }
                    }
                }
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

    /// **Beim Tippen zeigt dieselbe Fläche etwas anderes — und zwar von
    /// selbst** (10.08., Punkt E).
    ///
    /// Zwei Zustände, wie im Referenzvideo: Tastatur auf und Feld leer heißt
    /// „Häufig auf der Liste", ab dem ersten Buchstaben stehen an derselben
    /// Stelle die **passenden Produkte**. Welcher dran ist, entscheidet
    /// `SuggestionSurface` — hier steht nur, was die Gestalten zeichnen.
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
        switch surfaceShape {
        case .none: EmptyView()
        case .terms: termSurface
        case .staples: stapleSurface(schmal: false)
        case .staplesRow: stapleSurface(schmal: true)
        }
    }

    @ViewBuilder
    private func stapleSurface(schmal: Bool) -> some View {
        let remaining = suggestions
        if !remaining.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Häufig auf der Liste")
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
                if schmal {
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

    /// **Die Produkte beim Tippen** (10.08., Punkt E).
    ///
    /// > „if u type a letter the matching starts and where previous the
    /// > vorgeschlagenen offers came now coming actual products that match it,
    /// > so the product name with its drawing not the actual matched offer"
    ///
    /// Zwei Dinge stecken in dem Satz, und beide sind hier eingelöst: Die
    /// Kacheln tragen ab jetzt das **Artikelzeichen** neben dem Wort (siehe
    /// `termChip`), und was sie zeigen, ist ein **Produkt** — ein Wort aus dem
    /// Wörterbuch — und nicht die Prospektzeile, die dazu gefunden wurde. Der
    /// Unterschied ist keiner der Darstellung: „Bärenmarke Die Frische" auf
    /// einer Kachel legte das Angebot auf die Liste, „Milch" legt den Artikel
    /// dorthin, und nur der Artikel bleibt nächste Woche richtig.
    ///
    /// **Und die Zeile, wenn nichts passt, gehört dazu.** Sie ist der Grund,
    /// aus dem die Fläche auch dann steht, wenn sie leer ist: „Kein Begriff
    /// passt" ist eine Auskunft, kein Fehler — dieselbe Unterscheidung, die der
    /// Kopf des Artikelblatts seit dem 01.08. trifft. Ein Raster, das sich
    /// stillschweigend schließt, sagt genau das nicht.
    private var termSurface: some View {
        let terms = typedTerms
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(terms.isEmpty ? "Kein bekannter Begriff" : "\(AppBrand.name) kennt")
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
                    termChip(term)
                }
            }
        }
    }

    /// **Zeichen neben dem Wort, nicht darüber** — und das ist eine Zahl, keine
    /// Meinung: Die Fläche beim Tippen ist 44 pt hoch, und diese 44 sind die
    /// eine Zahl, an der die ganze Zone hängt (siehe `termSurface`). Ein
    /// Zeichen über dem Wort, wie auf der Listen-Kachel, bräuchte 64 und
    /// schöbe die Eingabezeile bei jedem Buchstaben um 20 pt.
    ///
    /// Das Zeichen kommt aus demselben Satz wie das der Kachel
    /// (`ItemGlyphTerm` → `ItemGlyphs`); für die Begriffe ohne Zeichnung
    /// (Warengruppen wie „soßen") bleibt es leer, und dann steht das Wort
    /// allein — das ist ehrlicher als ein erfundenes Bild.
    private func termChip(_ term: String) -> some View {
        Button {
            // Der Tipp legt **das Wort** auf die Liste, nicht den
            // getippten Anfang. Genau dafür ist die Fläche da: Was
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
            if angelegt {
                recordUserAdd()
                beginFlow(with: list.lastAdded)
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                // Nur wenn es wirklich eine Zeichnung gibt: `ItemGlyphView`
                // liefert sonst eine **leere Fläche** in voller Größe, und die
                // wäre ein 22 pt breites Loch vor dem Wort.
                if let zeichen = gezeichneterBegriff(term) {
                    ItemGlyphView(term: zeichen, category: nil, size: 22)
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                }
                Text(term)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
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

    /// Der Wörterbuchbegriff dieses Wortes — aber nur, wenn er gezeichnet ist.
    private func gezeichneterBegriff(_ word: String) -> String? {
        guard let term = ItemGlyphTerm.term(for: word),
              ItemGlyph.drawing(for: term, in: CGRect(x: 0, y: 0, width: 1, height: 1)) != nil
        else { return nil }
        return term
    }

    /// Dieselben Vorschläge, nur als eine seitlich scrollende Reihe — die
    /// Fassung neben der Angaben-Schicht. 44 pt statt 148, und der nächste
    /// Vorschlag bleibt einen Tipp weit weg.
    private func suggestionRow(_ staples: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(staples, id: \.self) { staple in
                    Button {
                        let angelegt = withAnimation { list.add(staple) }
                        if angelegt {
                            recordUserAdd()
                            beginFlow(with: list.lastAdded)
                        }
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
                    // **Die Fläche bleibt nach dem Tipp stehen**, nur
                    // geschrumpft auf eine Reihe — das entscheidet seit dem
                    // 10.08. `SuggestionSurface` am Zustand („Schicht oben,
                    // keine Tastatur") statt an einer gemerkten Wahl. Der
                    // Grund ist derselbe geblieben: Der zweite Vorschlag muss
                    // einen Tipp weit weg bleiben (2026-07-26).
                    // Nur bei Erfolg — siehe die Vorschlagskacheln oben.
                    let angelegt = withAnimation { list.add(staple) }
                    if angelegt {
                        recordUserAdd()
                        beginFlow(with: list.lastAdded)
                    }
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
    }

    // MARK: Angaben

    /// Der Artikel, dessen Angaben unten stehen — **frisch aus dem Speicher**.
    ///
    /// `AddFlowState` hält nur die Identität. Eine Kopie hier wüsste nichts von
    /// den Chips, die man ihr gerade gibt, und das Panel bliebe grau, während
    /// die Liste die Angabe schon trägt.
    private var activeFlowItem: ShoppingItem? {
        guard let id = addFlow.activeID else { return nil }
        return list.items.first { $0.id == id }
    }

    /// **Ein Blatt schlägt die Schicht.** Beide zeigen denselben Wortschatz;
    /// wer das Artikelblatt geöffnet hat, will es und nicht seinen Schatten
    /// darunter — und zwei Sätze gleich beschrifteter Chips auf einem
    /// Bildschirm sind für eine Journey nicht auseinanderzuhalten.
    ///
    /// **Und beim Tippen tritt die Schicht hinter die Vorschläge zurück**
    /// (2026-08-08): Bring! hat an dieser Stelle **eine** Schicht, nie zwei.
    /// Gemessen, warum: Mit dem hohen Panel (vier Chipreihen) blieben über
    /// beidem zusammen noch 72 pt Liste — keine ganze Kachelreihe.
    private var detailPanelIsUp: Bool {
        activeFlowItem != nil && sheetItem == nil && !isTyping
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let item = activeFlowItem, detailPanelIsUp {
            ItemDetailPanel(
                item: item,
                reihen: ItemDetailVocabulary.groups(for: item.query),
                recent: recentFlowItems(active: item),
                platz: platzFuerAngaben,
                onFocus: { addFlow.focus($0.id) },
                onToggleChip: { word in
                    // **Sofort durchgeschrieben, ohne „Fertig".** Das ist der
                    // ganze Unterschied zum Blatt: Es gibt nichts zu
                    // bestätigen, also auch nichts zu verlieren, wenn man
                    // stattdessen weitertippt.
                    withAnimation(.snappy) {
                        list.setDetail(
                            ItemDetailVocabulary.toggling(
                                word, in: item.detail ?? [],
                                reihen: ItemDetailVocabulary.groups(for: item.query)
                            ),
                            for: item
                        )
                    }
                    // Wer einen Chip antippt, hat die Angaben gefunden — der
                    // Tipp dazu erübrigt sich für immer.
                    tips?.detailsUsed()
                },
                onOpenFull: {
                    sheetOpensAngaben = true
                    sheetItem = item
                    tips?.detailsUsed()
                }
            )
        }
    }

    /// Die Kachelzeile über dem Panel. Der aktive Artikel ist immer dabei —
    /// auch dann, wenn der Fluss leer ist.
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

    /// **Fertig — unten links an der Tastatur** (2026-08-08, Scotts Punkt C-3).
    ///
    /// Der Ausgang aus dem Tipp-Fluss stand bisher als ✗ oben rechts in der
    /// Angaben-Schicht: an der Schicht, die er wegräumt, und damit am oberen
    /// Ende des Blocks — der weiteste Weg für den Daumen, der gerade auf der
    /// Tastatur liegt. Er sitzt jetzt am unteren linken Ende, direkt über der
    /// Tastatur, und heißt, was er tut.
    ///
    /// **Er bestätigt weiterhin nichts.** Jeder Chip ist längst durchgeschrieben
    /// (siehe `ItemDetailPanel`); „Fertig" beendet das Aufschreiben, es speichert
    /// es nicht. Deshalb steht er auch dann da, wenn nur die Tastatur oben ist
    /// und noch gar kein Artikel angelegt wurde.
    ///
    /// **Und er ist der einzige Ausgang ohne Tastatur.** Auf dem Weg über
    /// „Häufig auf der Liste" steht keine — genau Scotts Punkt 9 vom 03.08.,
    /// den bis heute das ✗ der Schicht getragen hat.
    ///
    /// **Seit dem 10.08. ist er der einzige Knopf hier unten** (Punkt B-2: „I
    /// don't like both the collaps buttons"). Neben ihm stand ein Winkel, der
    /// die Vorschlagsfläche holte; die kommt jetzt von selbst, sobald die
    /// Tastatur steht (`SuggestionSurface`). Von den beiden hat dieser
    /// gewonnen, weil er etwas kann, was sonst niemand kann: den Fluss ohne
    /// Tastatur beenden. Der Winkel dagegen holte nur zurück, was heute gar
    /// nicht mehr verschwindet.
    @ViewBuilder
    private var doneButton: some View {
        if flowIsUp {
            Button(action: endFlow) {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityLabel("Fertig")
            .accessibilityIdentifier("list.input.done")
        }
    }

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            doneButton

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
    }

    private func addItem() {
        guard list.add(newItemText) else { return }
        recordUserAdd()
        newItemText = ""
        keepTyping()
        // **Das Mengen-Menü kommt von selbst** ([UI-8], Scott 01.08.) — der
        // Moment nach dem Anlegen ist der einzige, in dem jemand noch weiß,
        // welche Größe er meint. Seit dem 03.08. als Schicht statt als Blatt:
        // Der Fokus bleibt im Feld, das nächste Wort ersetzt das Panel
        // einfach. Siehe `ItemDetailPanel`.
        beginFlow(with: list.lastAdded)
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

    /// **Das Artikelblatt eines Artikels, der schon auf der Liste steht**
    /// (10.08., Punkt A) — der Weg dahin ist das Halten auf seiner Kachel.
    ///
    /// Es öffnet sich derselbe Bildschirm, den auch „Notiz …" aus der Schicht
    /// öffnet: die Angebote der Woche, die Angaben hinter ihrem Knopf oben
    /// (`ItemSheet`). Zwei Wege zu denselben Angaben dürfen nicht zwei
    /// verschiedene Bildschirme sein — das war die Lehre aus dem Feldtest vom
    /// 09.08. und gilt unverändert. Was sie unterscheiden dürfen, ist womit
    /// der Bildschirm aufmacht: Hier ist der Artikel gemeint, dort die Angabe.
    private func openSheet(for item: ShoppingItem) {
        sheetOpensAngaben = false
        sheetItem = item
        tips?.detailsUsed()
    }

    /// **Der Ausgang, der keine Tastatur braucht.**
    ///
    /// Bis zum 03.08. gab es nur einen: „die Tastatur ist unten". Auf dem Weg
    /// über „Häufig auf der Liste" stand aber nie eine — und damit war die
    /// Schicht dort nicht verlassbar (Scotts Punkt 9). Der Fokus wird trotzdem
    /// mitgenommen, wo einer liegt: Sonst zöge `keepTyping` die Schicht im
    /// nächsten Durchgang wieder auf.
    private func endFlow() {
        inputFocused = false
        withAnimation(.snappy) { addFlow.end() }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
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

/// `.sheet(item:)` will etwas Identifizierbares — eine Wertung ist ein Array.
private struct RankBundle: Identifiable {
    let ranks: [MarketListRank]
    var id: String { ranks.map(\.chain).joined(separator: "|") }
}

/// Der Leerzustand an der Stelle der Plan-Karte: **ehrlich statt versteckt.**
///
/// Die Karte wegzulassen wäre die bequeme Antwort gewesen — dann steht auf dem
/// ersten Bildschirm der App nichts, was erklärt, warum man Filialen wählen
/// sollte. Also steht hier, was fehlt, und daneben der Weg dahin.
struct NoMarketsCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Noch keine Filiale gewählt")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(AppBrand.name) vergleicht nur die Läden, in die du wirklich gehst. Sobald du Filialen gewählt hast, steht hier, welche davon deine Liste am günstigsten abdeckt — und was der Einkauf dort kostet.")
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
    .environment(SetupProgressStore())
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
    .environment(SetupProgressStore())
}
