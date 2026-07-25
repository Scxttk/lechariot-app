import SwiftUI

/// The app's home screen: the shopping list, with the week's cheapest offer per
/// item and — above everything — which branch covers the list best.
struct ShoppingListView: View {
    let regions: [String]
    let favoriteMarkets: [Market]

    @Environment(ShoppingListStore.self) private var list
    /// Shared with the offers tab — see `ContentView.offerStore`.
    let offerStore: OfferStore
    @Environment(MatchRejectionStore.self) private var rejections
    @Environment(ProfileStore.self) private var profile
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
        .task(id: regions) {
            await offerStore.load(regions: regions, chains: chains, branchIds: branchIds)
        }
        .sheet(item: $detailItem) { item in
            MatchDetailView(item: item, offers: offerStore.offers)
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
                        .listRowInsets(EdgeInsets(
                            top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                            bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                        ))
                }
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(list.uncheckedItems) { item in
                    ShoppingListRowView(
                        item: item,
                        match: match(for: item, plan: plan),
                        onToggle: { withAnimation { list.toggle(item) } },
                        onShowMatches: { detailItem = item }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            list.remove(item)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
            .listRowBackground(Theme.surface)

            suggestionSection

            if !list.checkedItems.isEmpty {
                Section("Erledigt") {
                    ForEach(list.checkedItems) { item in
                        ShoppingListRowView(item: item, match: nil) {
                            withAnimation { list.toggle(item) }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                list.remove(item)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }

            // Reserved ad position: below everything, well clear of the plan
            // card and the suggestion tiles. Renders nothing today — see `AdSlot`.
            AdSlotView(slot: .shoppingListFooter)
        }
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
                    Text("Schreib auf, was du einkaufen willst. Smartshop sagt dir, welche deiner Filialen die Liste am günstigsten abdeckt.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Häufig gekauft")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    suggestionChips(ShoppingSuggestions.remaining(for: list.items))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.xl)
        }
    }

    // MARK: Suggestions

    /// The chips stay reachable once the list has its first item.
    ///
    /// They used to live only behind the empty state, so the whole strip
    /// disappeared with the very first tap — and adding a second staple meant
    /// typing it. What is already on the list drops out, so the strip shrinks
    /// as it is used and is gone once nothing is left to suggest.
    @ViewBuilder
    private var suggestionSection: some View {
        let remaining = ShoppingSuggestions.remaining(for: list.items)
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
    }

    // MARK: Input

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Artikel hinzufügen …", text: $newItemText)
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
    }

    private func addItem() {
        guard list.add(newItemText) else { return }
        newItemText = ""
        inputFocused = true
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

#Preview {
    ShoppingListView(
        regions: ["01219"],
        favoriteMarkets: MockFixtures.markets,
        offerStore: OfferStore(repository: MockOfferRepository(), cache: nil)
    )
    .environment(ShoppingListStore())
    .environment(MatchRejectionStore())
    .environment(ProfileStore())
}
