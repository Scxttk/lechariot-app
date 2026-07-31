import SwiftUI

/// The app's home screen: the shopping list, with the week's cheapest offer per
/// item and — above everything — which branch covers the list best.
struct ShoppingListView: View {
    let favoriteMarkets: [Market]

    @Environment(ShoppingListStore.self) private var list
    /// Shared with the offers tab — see `ContentView.offerStore`.
    let offerStore: OfferStore
    @Environment(MatchRejectionStore.self) private var rejections
    @Environment(ProfileStore.self) private var profile
    /// Zählt beim Abhaken mit — siehe `PurchaseHistoryStore`.
    @Environment(PurchaseHistoryStore.self) private var history
    /// Optional, damit Previews ohne Rundgang auskommen.
    @Environment(TutorialStore.self) private var tutorial: TutorialStore?
    @State private var detailItem: ShoppingItem?
    @State private var newItemText = ""
    @FocusState private var inputFocused: Bool

    private var chains: [String] {
        Array(Set(favoriteMarkets.map(\.chain))).sorted()
    }

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
    private func match(for item: ShoppingItem, plan: [MarketListRank]) -> OfferMatch? {
        if let winner = plan.first,
           let covered = winner.matchedItems.first(where: { $0.item == item.text }) {
            return covered.match
        }
        return ShoppingListMatcher.cheapestMatch(for: item.text, in: offerStore.offers) {
            rejections.isRejected(itemText: item.text, offer: $0)
        }
    }

    private var ranks: [MarketListRank] {
        ShoppingListRanking.rank(
            items: list.uncheckedItems,
            offers: offerStore.offers,
            chains: chains
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
            .safeAreaInset(edge: .bottom) { inputBar }
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
        }
    }

    // MARK: List

    private var itemList: some View {
        List {
            let plan = ranks
            if !plan.isEmpty {
                Section {
                    ShoppingPlanCard(ranks: plan)
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
                        match: match(for: item, plan: plan),
                        // Nur die erste offene Zeile trägt die Anker des
                        // Rundgangs — sonst zeigt das Loch auf sechs Stellen.
                        carriesTutorialAnchors: index == 0,
                        onToggle: { check(item) },
                        onShowMatches: { detailItem = item }
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

            suggestionSection

            if !list.checkedItems.isEmpty {
                Section("Erledigt") {
                    ForEach(Array(list.checkedItems.enumerated()), id: \.element.id) { index, item in
                        ShoppingListRowView(item: item, match: nil) {
                            check(item)
                        }
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
        if !wasChecked { history.record(item.text) }
    }

    // MARK: Empty state

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
                    Text("Schreib auf, was du einkaufen willst. Le Chariot sagt dir, welche deiner Filialen die Liste am günstigsten abdeckt.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Häufig gekauft")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    suggestionChips(suggestions)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

    /// The chips stay reachable once the list has its first item.
    ///
    /// They used to live only behind the empty state, so the whole strip
    /// disappeared with the very first tap — and adding a second staple meant
    /// typing it. Since 2026-07-26 new suggestions move up as the staples are
    /// used, drawn from the offers of the chosen branches; before that the
    /// strip shrank with every tap and was gone after eight.
    @ViewBuilder
    private var suggestionSection: some View {
        let remaining = suggestions
        if !remaining.isEmpty {
            Section("Häufig gekauft") {
                suggestionChips(remaining)
                    .listRowInsets(EdgeInsets(
                        top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                        bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                    ))
            }
            // The chips carry their own surface; a second one behind them
            // would draw a card around a card.
            .listRowBackground(Color.clear)
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
        // Das Raster steht an zwei Stellen — im Leerzustand und als Abschnitt.
        // Immer nur eines davon wird gebaut, also gewinnt im Preference-Merge
        // das, das gerade auf dem Bildschirm liegt.
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

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
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
        .readableWidth()
        // Bar across the whole width, field only as wide as the list above it.
        .background(.bar)
        .tutorialAnchor(.inputBar)
    }

    private func addItem() {
        guard list.add(newItemText) else { return }
        newItemText = ""
        inputFocused = true
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

#Preview {
    ShoppingListView(
        favoriteMarkets: MockFixtures.markets,
        offerStore: OfferStore(repository: MockOfferRepository(), cache: nil)
    )
    .environment(ShoppingListStore())
    .environment(MatchRejectionStore())
    .environment(ProfileStore())
}
