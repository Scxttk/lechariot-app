import SwiftUI

/// Branch picker ("Wunschmärkte"): one cross-chain, searchable list of the
/// stores near the user, grouped by chain and sorted by distance within each
/// chain. Search matches chain, branch name and PLZ. Chains without backend
/// data (see `MarketFilter.chainsWithoutData`) are listed but not selectable.
/// At least one selected branch is required to continue.
///
/// The list comes from the **directory** (`public.branches`, backend migration
/// v12), not from `markets`. That is the whole point of Phase 12: `markets`
/// holds exactly one store per chain and postcode — whichever the store finder
/// happened to return first — which is why Scott's REWE am Postplatz was not
/// selectable at all. The directory holds every store the chains' own finders
/// know about.
///
/// `markets` stays as the fallback: if geocoding the postcode fails or the
/// directory has no entry for the area yet, an empty picker would be a dead
/// end, and the old list is still a usable answer.
struct MarketPickerView: View {
    @Environment(RegionStore.self) private var store
    let plz: String
    let marketRepository: MarketRepositoryProtocol
    var branchRepository: BranchRepositoryProtocol = AppRepositories.branches
    /// Requests offers for a store the backend has never fetched. Optional so
    /// previews and the settings path work without one.
    var branchRequests: BranchRequestStore?
    var onDone: () -> Void

    @State private var markets: [Market] = []
    /// Distance in km per market id — only for stores that came from the
    /// directory, so the row can say how far away it is.
    @State private var distances: [String: Double] = [:]
    /// Street/city per market id, same source.
    @State private var addresses: [String: String] = [:]
    @State private var usedDirectory = false
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

    /// Local branches grouped by chain, chains alphabetical. Within a chain the
    /// nearest store first — with three REWE in one postcode, alphabetical
    /// order says nothing about which one the user means.
    private var chainGroups: [(chain: String, markets: [Market])] {
        Dictionary(grouping: filtered.filter { !$0.isNationwide }, by: \.chain)
            .map { (chain: $0.key, markets: $0.value.sorted(by: nearerFirst)) }
            .sorted { $0.chain < $1.chain }
    }

    private func nearerFirst(_ lhs: Market, _ rhs: Market) -> Bool {
        switch (distances[lhs.marketId], distances[rhs.marketId]) {
        case let (l?, r?) where l != r: return l < r
        // Stores without a distance sort last, but keep a stable order among
        // themselves — otherwise the list reshuffles on every redraw.
        case (nil, _?): return false
        case (_?, nil): return true
        default: return lhs.branchName < rhs.branchName
        }
    }

    /// "1,2 km" — one decimal below 10 km, none above. Nobody navigates by
    /// 100 m at that distance, and the extra digit only adds noise.
    private func distanceLabel(_ km: Double) -> String {
        km < 10 ? String(format: "%.1f km", km) : String(format: "%.0f km", km)
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
                        .foregroundStyle(Theme.onAccent)
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
            // Picking a store the backend has never fetched is the whole
            // reason `branch_requests` exists: the region sync only ever
            // scraped ONE branch per chain, so choosing the second REWE of a
            // postcode used to select a store with no offers behind it.
            // Measured on 2026-07-25: the request is answered in about 40
            // seconds, so this happens quietly in the background rather than
            // behind a modal.
            if store.isFavorite(market), let branchRequests {
                Task { await branchRequests.request(market.marketId) }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(market.isNationwide ? market.chain : market.branchName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle(for: market))
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
        // Adresse und Entfernung stehen im Hinweis, nicht im Label: Das Label
        // ist der Name, auf den auch die UI-Journeys zeigen, und ein Label,
        // das sich mit der Entfernung ändert, wäre kein Name mehr.
        .accessibilityHint(
            [subtitle(for: market),
             isFav ? "Doppeltippen zum Entfernen" : "Doppeltippen zum Hinzufügen"]
                .joined(separator: ". ")
        )
        .accessibilityValue(isFav ? "ausgewählt" : "nicht ausgewählt")
        .accessibilityAddTraits(isFav ? [.isSelected] : [])
    }

    /// What the user needs to tell two stores of the same chain apart: the
    /// street, and how far it is. Falls back to the postcode when the row came
    /// from `markets` instead of the directory — that one has no address.
    private func subtitle(for market: Market) -> String {
        if market.isNationwide { return "Deutschlandweit" }
        let address = addresses[market.marketId] ?? ""
        let distance = distances[market.marketId].map(distanceLabel)
        let joined = [address.isEmpty ? nil : address, distance]
            .compactMap { $0 }
            .joined(separator: " · ")
        return joined.isEmpty ? "PLZ \(market.plz)" : joined
    }

    private func loadMarkets() async {
        isLoading = true
        errorMessage = nil
        do {
            if let directory = try await loadDirectory(), !directory.isEmpty {
                markets = directory
                usedDirectory = true
            } else {
                markets = try await marketRepository.markets(plzs: plzs)
                usedDirectory = false
            }
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

    /// Stores near the picked postcodes, from the directory. Returns nil when
    /// no postcode could be geocoded — the caller then falls back to `markets`
    /// rather than showing an empty list.
    ///
    /// The radius is deliberately generous: the store on the way home may sit
    /// two postcodes away, and the list is sorted by distance anyway, so a
    /// further one costs a scroll, not a wrong answer.
    private func loadDirectory() async throws -> [Market]? {
        var found: [String: (market: Market, distance: Double)] = [:]
        var geocoded = false
        for plz in plzs {
            guard let point = try? await Self.locate(plz) else { continue }
            geocoded = true
            let branches = try await branchRepository.nearby(
                lat: point.lat, lon: point.lon, radiusKm: Self.radiusKm
            )
            for branch in branches {
                let distance = branch.distanceKm(from: point.lat, point.lon) ?? .greatestFiniteMagnitude
                // The same store shows up around two neighbouring postcodes;
                // keep the smaller distance, that is the one the user cares
                // about.
                if let existing = found[branch.marketId], existing.distance <= distance { continue }
                found[branch.marketId] = (branch.asMarket, distance)
                addresses[branch.marketId] = branch.addressLine
            }
        }
        guard geocoded else { return nil }
        distances = found.mapValues(\.distance)
        return found.values.map(\.market)
    }

    /// How far around each postcode the directory is searched.
    static let radiusKm: Double = 10

    /// Postcode → coordinates. Real geocoding talks to Apple's servers, which
    /// a mock run must never do: UI tests would depend on the network and on
    /// whatever the geocoder feels like answering. Mock runs therefore use a
    /// fixed point — Dresden, where the fixtures live.
    private static func locate(_ plz: String) async throws -> (lat: Double, lon: Double) {
        guard !AppRepositories.usesMockData else { return (51.0504, 13.7317) }
        return try await PLZLocator.coordinates(forPLZ: plz)
    }
}

#Preview {
    NavigationStack {
        MarketPickerView(plz: "01219", marketRepository: MockMarketRepository(), onDone: {})
            .environment(RegionStore(repository: MockRegionRepository()))
    }
}
