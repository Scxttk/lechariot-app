import SwiftUI

/// Branch picker ("Wunschmärkte"): one cross-chain, searchable list of all
/// branches in the user's regions, grouped by chain. Search matches chain,
/// branch name and PLZ. Chains without backend data (see
/// `MarketFilter.chainsWithoutData`) are listed but not selectable.
/// At least one selected branch is required to continue.
struct MarketPickerView: View {
    @Environment(RegionStore.self) private var store
    let plz: String
    let marketRepository: MarketRepositoryProtocol
    var onDone: () -> Void

    @State private var markets: [Market] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var query = ""

    /// All regions whose branches the picker offers — the current one plus
    /// every other ready region, so PLZ-border users pick across borders.
    private var plzs: [String] {
        var seen = Set<String>()
        return ([plz] + store.orderedReadyRegions).filter { seen.insert($0).inserted }
    }

    private var filtered: [Market] {
        MarketFilter.filter(markets, query: query)
    }

    /// Local branches grouped by chain, chains alphabetical, branches by name.
    private var chainGroups: [(chain: String, markets: [Market])] {
        Dictionary(grouping: filtered.filter { !$0.isNationwide }, by: \.chain)
            .map { (chain: $0.key, markets: $0.value.sorted { $0.branchName < $1.branchName }) }
            .sorted { $0.chain < $1.chain }
    }

    private var nationwideMarkets: [Market] {
        filtered.filter(\.isNationwide).sorted { $0.chain < $1.chain }
    }

    private var missingChains: [String] {
        MarketFilter.chainsWithoutData.filter { chain in
            query.trimmingCharacters(in: .whitespaces).isEmpty
                || chain.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private var hasAnyFavorites: Bool {
        !store.favoriteMarkets(in: plzs).isEmpty
    }

    var body: some View {
        List {
            Section {
                Label("Wähle die Läden, in die du wirklich gehst. Nur deren Angebote zählen für deine Liste.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(chainGroups, id: \.chain) { group in
                Section(group.chain) {
                    ForEach(group.markets) { marketRow($0) }
                }
            }

            if !nationwideMarkets.isEmpty {
                Section {
                    ForEach(nationwideMarkets) { marketRow($0) }
                } header: {
                    Text("Überregionale Angebote")
                } footer: {
                    Text("Filiale unbekannt – Angebote gelten deutschlandweit")
                }
            }

            if !missingChains.isEmpty {
                Section {
                    ForEach(missingChains, id: \.self) { chain in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chain)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text("Keine Daten verfügbar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "circle.slash")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(chain), keine Daten verfügbar, nicht wählbar")
                    }
                } footer: {
                    Text("Diese Kette veröffentlicht ihre Angebote nicht in einer Form, die Smartshop auslesen kann.")
                }
            }

            // The error gets its own section regardless of what is already on
            // screen: a failed *reload* used to be invisible whenever markets
            // from an earlier attempt were still listed, so the user waited for
            // a list that was never coming.
            if let errorMessage {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Label(errorMessage, systemImage: "wifi.exclamationmark")
                            .font(.subheadline)
                            .foregroundStyle(Theme.error)
                        Button("Erneut versuchen") {
                            Task { await loadMarkets() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }

            if filtered.isEmpty && !isLoading && !query.isEmpty {
                Section {
                    Text("Keine Filiale passt zu \u{201E}\(query)\u{201C}.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if markets.isEmpty && !isLoading && query.isEmpty && errorMessage == nil {
                Section {
                    Text("Für deine Regionen wurden noch keine Filialen gefunden.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if store.canAddRegion {
                Section {
                    NavigationLink {
                        AddRegionScreen()
                    } label: {
                        Label("Deine Filiale fehlt? Weitere PLZ hinzufügen", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                }
            }
        }
        .themedScreen()
        .searchable(text: $query, prompt: "Kette, Filiale oder PLZ")
        // Only cover the list on the *first* load — during a pull-to-refresh the
        // list already has its own spinner, and two at once looked broken.
        .overlay { if isLoading && markets.isEmpty { ProgressView("Filialen werden geladen …") } }
        .navigationTitle("Filialen wählen")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { onDone() }
                    .disabled(!hasAnyFavorites)
                    .accessibilityIdentifier("markets.done")
                    // A disabled button with no explanation is a dead end;
                    // VoiceOver users get nothing at all from it.
                    .accessibilityHint(hasAnyFavorites ? "" : "Wähle zuerst mindestens eine Filiale aus")
            }
        }
        // Tells the user what the greyed-out "Fertig" is waiting for, without
        // adding a second permanent line once they have chosen something.
        .safeAreaInset(edge: .bottom) {
            if !hasAnyFavorites && !isLoading {
                Text("Wähle mindestens eine Filiale, um fortzufahren.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(.bar)
                    .accessibilityHidden(true)
            }
        }
        .task { await loadMarkets() }
        .refreshable { await loadMarkets() }
    }

    private func marketRow(_ market: Market) -> some View {
        let isFav = store.isFavorite(market)
        return Button {
            withAnimation { store.toggleFavorite(market) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(market.isNationwide ? market.chain : market.branchName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(market.isNationwide ? "Deutschlandweit" : "PLZ \(market.plz)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Checkmark, not a star: this is a selection, not a rating —
                // and `Color.yellow` on the cream surface measured 1.37:1,
                // far below the 3:1 that a meaning-carrying glyph needs.
                Image(systemName: isFav ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isFav ? Theme.accent : Color.secondary)
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
            }
            // Without this the row only reacts where something is drawn — and
            // the middle of the row is the `Spacer`. Tapping the obvious target,
            // the gap between branch name and checkmark, did nothing at all.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // No `.accessibilityElement(children: .ignore)` here: on a Button it
        // shadows the element VoiceOver actually focuses, and the label below
        // was silently dropped — the row announced "Dresden Reick, PLZ 01219"
        // with no chain name and no selected/not-selected state. A Button takes
        // an overriding label directly.
        .accessibilityLabel(
            "\(market.chain), \(market.isNationwide ? "deutschlandweit" : market.branchName)"
        )
        .accessibilityValue(isFav ? "ausgewählt" : "nicht ausgewählt")
        .accessibilityHint(isFav ? "Doppeltippen zum Entfernen" : "Doppeltippen zum Hinzufügen")
        .accessibilityAddTraits(isFav ? [.isSelected] : [])
    }

    private func loadMarkets() async {
        isLoading = true
        errorMessage = nil
        do {
            markets = try await marketRepository.markets(plzs: plzs)
        } catch {
            // Leaving the screen cancels this; that is not something to report.
            guard !LoadFailure.isCancellation(error) else {
                isLoading = false
                return
            }
            errorMessage = LoadFailure.message(for: error, subject: "Die Filialen")
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        MarketPickerView(plz: "01219", marketRepository: MockMarketRepository(), onDone: {})
            .environment(RegionStore(repository: MockRegionRepository()))
    }
}
