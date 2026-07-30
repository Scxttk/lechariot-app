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
    /// Fordert die Angebote einer Filiale an, die das Backend noch nie geholt
    /// hat.
    ///
    /// Kommt seit 2026-07-30 aus der Umgebung statt als optionaler Parameter.
    /// Als Parameter war er genau einmal gesetzt — im Onboarding —, und der Weg
    /// über die Einstellungen ließ ihn weg. Eine dort gewählte Filiale löste
    /// deshalb **keine** Anforderung aus und bekam nie Angebote; in der App sah
    /// das aus wie „dieser Markt hat diese Woche nichts". Ein Optional, das an
    /// einer von zwei Aufrufstellen fehlt, ist kein Standardwert, sondern ein
    /// Loch.
    @Environment(BranchRequestStore.self) private var branchRequests
    @Environment(AreaRequestStore.self) private var areaRequests
    var onDone: () -> Void

    @State private var markets: [Market] = []
    /// Address, region and fallback distance per store — only for rows that
    /// came from the directory. Nil while the `markets` fallback is showing.
    @State private var plan: PickerDirectory.Plan?
    /// Where the phone actually is, once we may know it.
    ///
    /// Distances used to be measured from the *postcode centre a store was
    /// found around*, which meant every row could have a different reference
    /// point — with two regions far apart the list read "Penny Gößnitz · 7,6 km"
    /// above "Penny Am Haff · 22 km" while the user stood in Ahlbeck. The
    /// search still runs around the postcode centres (otherwise the second
    /// region's stores would be out of reach and unpickable, which is the whole
    /// point of having one); only the number on screen moves to a single honest
    /// anchor.
    @State private var deviceAnchor: (lat: Double, lon: Double)?
    @State private var locator = PLZLocator()
    @State private var locationOffered = false
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

    /// How many stores of one chain the list shows before it stops.
    ///
    /// Since the picker draws from the directory rather than from `markets`,
    /// a city chain brings dozens: measured on 2026-07-26, the 10 km around
    /// Dresden-Strehlen hold **44 Netto branches**. Listing all of them turns
    /// the first screen of the app into a scroll through 142 rows. The nearest
    /// five answer the question for almost everyone; the rest are one tap away
    /// and, if the store is even further out, the search field finds it by name.
    static let visiblePerChain = 5

    /// Chains the user unfolded to see every branch.
    @State private var expandedChains: Set<String> = []

    private func visibleMarkets(_ group: (chain: String, markets: [Market])) -> [Market] {
        // While searching, showing everything is the point — the query IS the
        // narrowing, and hiding matches behind "show all" would hide the hit.
        guard query.trimmingCharacters(in: .whitespaces).isEmpty,
              !expandedChains.contains(group.chain)
        else { return group.markets }
        // An already chosen store is never hidden behind the fold, however far
        // away it is. With honest distances a branch picked at the other home
        // sinks past position five, and a ticked box the user cannot see is the
        // reported bug in a new costume.
        var shown = Array(group.markets.prefix(Self.visiblePerChain))
        let shownIds = Set(shown.map(\.marketId))
        shown += group.markets.filter { store.isFavorite($0) && !shownIds.contains($0.marketId) }
        return shown
    }

    private func nearerFirst(_ lhs: Market, _ rhs: Market) -> Bool {
        switch (distance(for: lhs), distance(for: rhs)) {
        case let (l?, r?) where l != r: return l < r
        // Stores without a distance sort last, but keep a stable order among
        // themselves — otherwise the list reshuffles on every redraw.
        case (nil, _?): return false
        case (_?, nil): return true
        default: return lhs.branchName < rhs.branchName
        }
    }

    /// How far the store is, from the phone when we know where that is and from
    /// the postcode the store was found around otherwise.
    private func distance(for market: Market) -> Double? {
        guard let entry = plan?.byMarketId[market.marketId] else { return nil }
        guard let deviceAnchor else { return entry.distanceKm }
        return entry.branch.distanceKm(from: deviceAnchor.lat, deviceAnchor.lon)
    }

    /// "1,2 km" — one decimal below 10 km, none above. Nobody navigates by
    /// 100 m at that distance, and the extra digit only adds noise.
    private func distanceLabel(_ km: Double) -> String {
        // `locale:` is the point: without it `String(format:)` writes a period,
        // and the comma this comment has promised since it was written never
        // actually appeared.
        km < 10
            ? String(format: "%.1f km", locale: .current, km)
            : String(format: "%.0f km", locale: .current, km)
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
        store.hasFavorites
    }

    var body: some View {
        List {
            Section {
                Label("Wähle die Läden, in die du wirklich gehst. Nur deren Angebote zählen für deine Liste.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }

            // Nur ein Angebot, kein Zwang: Ohne Standort misst die Liste ab der
            // PLZ-Mitte und sagt das auch in jeder Zeile. Mit Standort stimmen
            // die Entfernungen — und bei mehreren Regionen ist das der
            // Unterschied zwischen einer sortierten Liste und einer, deren
            // Zahlen von verschiedenen Punkten stammen.
            if canOfferLocation && !locationOffered {
                Section {
                    Button {
                        Task { await askForLocation() }
                    } label: {
                        Label("Entfernungen von deinem Standort", systemImage: "location")
                            .font(.subheadline)
                    }
                    .accessibilityHint("Misst die Entfernungen ab deinem Standort statt ab der Mitte deiner Postleitzahl")
                } footer: {
                    Text(plzs.count > 1
                         ? "Ohne Standort misst jede Zeile ab der Postleitzahl, bei der sie gefunden wurde."
                         : "Ohne Standort misst jede Zeile ab der Mitte deiner Postleitzahl.")
                }
            }

            ForEach(chainGroups, id: \.chain) { group in
                Section(group.chain) {
                    let shown = visibleMarkets(group)
                    ForEach(shown) { marketRow($0) }
                    if shown.count < group.markets.count {
                        let hidden = group.markets.count - shown.count
                        Button {
                            withAnimation { _ = expandedChains.insert(group.chain) }
                        } label: {
                            Label(
                                "\(hidden) weitere \(group.chain)-Filialen",
                                systemImage: "chevron.down"
                            )
                            .font(.subheadline)
                        }
                        .accessibilityHint("Zeigt alle Filialen dieser Kette")
                    }
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
                                    .foregroundStyle(Theme.secondaryText)
                                Text("Keine Daten verfügbar")
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "circle.slash")
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(chain), keine Daten verfügbar, nicht wählbar")
                    }
                } footer: {
                    Text("Diese Kette veröffentlicht ihre Angebote nicht in einer Form, die Le Chariot auslesen kann.")
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
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            if markets.isEmpty && !isLoading && query.isEmpty && errorMessage == nil {
                Section {
                    Text("Für deine Regionen wurden noch keine Filialen gefunden.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
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
        // Kein Wartebildschirm: Der Gebiets-Lauf dauert ~3 Minuten, so lange
        // das Onboarding zu blockieren wäre schlimmer als eine kurze Liste,
        // die nachwächst. Deshalb nur ein Hinweis über der Liste.
        .safeAreaInset(edge: .top) {
            if areaRequests.isFetchingArea {
                Text(areaFetchNotice)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.sm)
                    .background(.bar)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !hasAnyFavorites && !isLoading {
                Text("Wähle mindestens eine Filiale, um fortzufahren.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(.bar)
                    .accessibilityHidden(true)
            }
        }
        .task {
            await useLocationIfAlreadyAllowed()
            await loadMarkets()
        }
        .refreshable { await loadMarkets() }
    }

    /// Names the postcode once there is more than one — "deiner Gegend" is no
    /// answer to a user who keeps two, and the short list they are looking at
    /// belongs to exactly one of them.
    private var areaFetchNotice: String {
        let waiting = areaRequests.pendingAreaPLZs
        let where_ = waiting.count == 1 && plzs.count > 1
            ? "um \(waiting[0])"
            : "in deiner Gegend"
        return "Wir holen gerade die übrigen Märkte \(where_) — das dauert etwa drei Minuten. Du kannst schon wählen; wir sagen Bescheid, sobald mehr da ist."
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
            if store.isFavorite(market) {
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
                        .foregroundStyle(Theme.secondaryText)
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
        let entry = plan?.byMarketId[market.marketId]
        let address = entry?.address ?? ""
        let distance = distance(for: market).map { km -> String in
            let label = distanceLabel(km)
            // Without the phone's position the number is measured from a
            // postcode centre, and with several regions a different one per
            // row. Then it has to say which — an unlabelled number that
            // silently changes its reference point is what caused the report.
            guard deviceAnchor == nil, plzs.count > 1, let plz = entry?.anchorPLZ else { return label }
            return "\(label) ab \(plz)"
        }
        let joined = [address.isEmpty ? nil : address, distance]
            .compactMap { $0 }
            .joined(separator: " · ")
        return joined.isEmpty ? "PLZ \(market.plz)" : joined
    }

    private func loadMarkets() async {
        isLoading = true
        errorMessage = nil
        do {
            if let directory = try await loadDirectory(), !directory.entries.isEmpty {
                plan = directory
                markets = directory.entries.map(\.market)
                // After the list is on screen, never before: a region run takes
                // ~3 minutes, and the picker must not wait on the round trips
                // that start it.
                Task { await requestUnfetchedAreas(directory.areaCandidates) }
            } else {
                plan = nil
                markets = try await marketRepository.markets(plzs: plzs)
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
    private func loadDirectory() async throws -> PickerDirectory.Plan? {
        var finds: [PickerDirectory.RegionFind] = []
        for plz in plzs {
            guard let point = try? await Self.locate(plz) else { continue }
            let branches = try await Self.nearbyWideningIfSparse(
                repository: branchRepository, lat: point.lat, lon: point.lon
            )
            finds.append(
                PickerDirectory.RegionFind(
                    plz: plz, lat: point.lat, lon: point.lon, branches: branches
                )
            )
        }
        // Not one postcode could be geocoded: the caller falls back to the
        // `markets` table rather than showing an empty list.
        guard !finds.isEmpty else { return nil }
        return PickerDirectory.plan(finds)
    }

    /// Six of the eight chains are only in the directory where somebody asked
    /// for them; Kaufland and Penny are always there because their whole
    /// German list costs one request. So a list made **exclusively** of those
    /// two is not a thin area — it is an area nobody has fetched yet.
    ///
    /// Measured on 2026-07-26 in Gößnitz (04639): Penny plus two Kauflands on
    /// screen, while Netto, Lidl and REWE existed a few streets away and were
    /// simply not in `branches`. The request goes out silently and takes about
    /// three minutes; the picker says so, and the user is told again when it
    /// lands, because by then they will have moved on.
    ///
    /// **One request per region.** Asked once over all regions merged, a single
    /// well-stocked postcode answered for every other one — a second region
    /// then never got fetched at all, and nothing anywhere failed. Reported
    /// 2026-07-30 by a tester with 04626 and 17419; the Ahlbeck half showed two
    /// chains and would have kept showing two forever.
    private func requestUnfetchedAreas(_ candidates: [PickerDirectory.AreaCandidate]) async {
        for candidate in candidates {
            // Der Anker ist weiter die nächstgelegene Filiale — an ihm prüft
            // der Server, dass es diesen Ort überhaupt gibt. Was das Gebiet
            // bestimmt, sind seit v21 aber die **Koordinaten der Regionsmitte**:
            // Der Anker kann in der Nachbarstadt stehen, und in Ahlbeck stand er
            // 24,5 km weit weg in Ueckermünde.
            await areaRequests.requestArea(
                anchors: candidate.anchors.map(\.marketId),
                region: candidate.plz,
                lat: candidate.lat,
                lon: candidate.lon
            )
        }
    }

    /// How far around each postcode the directory is searched to begin with.
    static let radiusKm: Double = 10

    /// Below this many stores the search widens — a village with two shops is
    /// not a finished list, it is a radius that is too small.
    static let minBranches = 6

    /// The widest the search goes before giving up.
    static let maxRadiusKm: Double = 40

    /// Searches `radiusKm` and doubles until enough stores turn up or
    /// `maxRadiusKm` is reached.
    ///
    /// 10 km is right for a city — Dresden has 142 stores in it — and too
    /// small in the countryside. Measured on 2026-07-25 for 96515 Sonneberg:
    /// the only ALDI Nord of the area sits in Neuhaus am Rennweg, **15 km**
    /// away, and was therefore not selectable at all. Raising the radius
    /// globally would have made city dwellers scroll through 300 entries
    /// instead; growing it only where the list stays short costs a second
    /// request exactly where one is needed.
    ///
    /// The directory has the data either way — `branches-sync` fills 25 km
    /// around each area.
    static func nearbyWideningIfSparse(
        repository: BranchRepositoryProtocol,
        lat: Double,
        lon: Double
    ) async throws -> [Branch] {
        var radius = radiusKm
        var branches = try await repository.nearby(lat: lat, lon: lon, radiusKm: radius)
        while branches.count < minBranches && radius < maxRadiusKm {
            radius = min(radius * 2, maxRadiusKm)
            branches = try await repository.nearby(lat: lat, lon: lon, radiusKm: radius)
        }
        return branches
    }

    /// Postcode → coordinates. Real geocoding talks to Apple's servers, which
    /// a mock run must never do: UI tests would depend on the network and on
    /// whatever the geocoder feels like answering. Mock runs therefore use a
    /// fixed point — Dresden, where the fixtures live.
    private static func locate(_ plz: String) async throws -> (lat: Double, lon: Double) {
        guard !AppRepositories.usesMockData else { return MockFixtures.coordinates(forPLZ: plz) }
        return try await PLZLocator.coordinates(forPLZ: plz)
    }

    /// True when asking would cost the user a system dialog. Mock runs never
    /// ask — a UI journey must not depend on a permission sheet, and the
    /// fixtures are anchored on postcodes anyway.
    private var canOfferLocation: Bool {
        guard !AppRepositories.usesMockData, deviceAnchor == nil else { return false }
        return locator.authorizationStatus == .notDetermined
    }

    /// Reads the position only if the user has already agreed to share it
    /// somewhere else — the region step offers exactly that. Silence is the
    /// point: opening a list of shops is not a request to be asked for a
    /// permission.
    private func useLocationIfAlreadyAllowed() async {
        guard !AppRepositories.usesMockData, deviceAnchor == nil else { return }
        switch locator.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            deviceAnchor = try? await locator.currentCoordinates()
        default:
            return
        }
    }

    private func askForLocation() async {
        locationOffered = true
        deviceAnchor = try? await locator.currentCoordinates()
    }
}

#Preview {
    NavigationStack {
        MarketPickerView(plz: "01219", marketRepository: MockMarketRepository(), onDone: {})
            .environment(RegionStore())
            .environment(AreaRequestStore(repository: MockAreaRequestRepository()))
            .environment(BranchRequestStore(repository: MockBranchRequestRepository()))
    }
}
