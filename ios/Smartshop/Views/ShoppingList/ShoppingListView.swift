import SwiftUI

/// Einkaufsliste tab: local list with per-item cheapest-offer suggestions from
/// the current week's offers (region + Wunschmärkte, like the Angebote tab).
struct ShoppingListView: View {
    let plz: String
    let favoriteMarkets: [Market]

    @Environment(ShoppingListStore.self) private var list
    @State private var offerStore: OfferStore
    @State private var newItemText = ""
    @FocusState private var inputFocused: Bool

    init(plz: String, favoriteMarkets: [Market], repository: OfferRepositoryProtocol) {
        self.plz = plz
        self.favoriteMarkets = favoriteMarkets
        _offerStore = State(initialValue: OfferStore(repository: repository, cache: try? OfferCache()))
    }

    private var chains: [String] {
        Array(Set(favoriteMarkets.map(\.chain))).sorted()
    }

    /// Matches are recomputed on the fly; nothing offer-related is persisted.
    private func match(for item: ShoppingItem) -> Offer? {
        ShoppingListMatcher.cheapestMatch(for: item.text, in: offerStore.offers)
    }

    /// Sum of the suggested prices of all open items with a match.
    private var matchedTotal: Double {
        list.uncheckedItems.compactMap { match(for: $0)?.price }.reduce(0, +)
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
            .navigationTitle("Einkaufsliste")
            .toolbar { toolbarMenu }
            .safeAreaInset(edge: .bottom) { inputBar }
        }
        .task(id: plz) { await offerStore.load(plz: plz, chains: chains) }
    }

    // MARK: List

    private var itemList: some View {
        List {
            Section {
                ForEach(list.uncheckedItems) { item in
                    ShoppingListRowView(item: item, match: match(for: item)) {
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
            } footer: {
                if matchedTotal > 0 {
                    HStack {
                        Text("Angebots-Summe")
                        Spacer()
                        Text(matchedTotal, format: .currency(code: "EUR"))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                    }
                    .font(.footnote)
                }
            }

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
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Einkaufsliste ist leer", systemImage: "checklist")
        } description: {
            Text("Füge unten Artikel hinzu. Smartshop findet automatisch das günstigste passende Angebot deiner Märkte.")
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

            Button(action: addItem) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
            }
            .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Artikel hinzufügen")
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
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
        plz: "01219",
        favoriteMarkets: MockFixtures.markets,
        repository: MockOfferRepository()
    )
    .environment(ShoppingListStore())
}
