import SwiftUI

/// Branch picker ("Wunschmärkte"): one cross-chain, searchable list of the
/// stores near the user, grouped by chain and sorted by distance within each
/// chain. Search matches chain, branch name and PLZ. At least one selected
/// branch is required to continue.
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

    /// Ob gerade gesucht wird. Die Suche ist die Einschränkung — dann stehen
    /// die Treffer flach da statt hinter einer Kettenseite.
    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
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

    private var nationwideMarkets: [Market] {
        filtered.filter(\.isNationwide).sorted { $0.chain < $1.chain }
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

            if isSearching {
                // Die Suche ist die Einschränkung: Treffer flach zeigen, nicht
                // hinter einer Kettenseite verstecken.
                ForEach(chainGroups, id: \.chain) { group in
                    Section(group.chain) {
                        ForEach(rows(for: group.markets)) { BranchPickerRow(row: $0) }
                    }
                }
            } else {
                chainSection
            }

            if !nationwideMarkets.isEmpty {
                Section {
                    ForEach(rows(for: nationwideMarkets)) { BranchPickerRow(row: $0) }
                } header: {
                    Text("Überregionale Angebote")
                } footer: {
                    Text("Filiale unbekannt – Angebote gelten deutschlandweit")
                }
            }

            if !isSearching { chosenSection }

            // Hier stand bis zum 2026-07-30 die Konsum-Zeile („keine Daten
            // verfügbar", nicht wählbar). Scotts Entscheidung, sie ganz zu
            // entfernen — die Begründung steht in „Le Chariot Entscheidungen".

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
                // Anzeige statt nur grauem Text (Anklam, 02.08.): Ohne
                // sichtbares Zeichen sieht „wird geholt" genauso aus wie
                // „hier ist nichts". Der Kreisel steht für einen Lauf, der
                // wirklich läuft — einen erfundenen Fortschrittsbalken gibt es
                // bewusst nicht, wir kennen den Fortschritt nicht.
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text(areaFetchNotice)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.Spacing.sm)
                .background(.bar)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("markets.areaFetching")
            }
        }
        // **Der Hinweis und das, was unter ihm hervorkommt, gehören zu
        // demselben Wechsel.** Gemeldet am 31.07.: Der graue Streifen blendet
        // langsam aus (die Vorgabe-Kurve des blanken `withAnimation` in
        // `marketRow`), während der grüne Aufklapper darunter schlagartig
        // erscheint — ohne Übergang, weil er keinen trug. Beide hängen an
        // derselben Berührung und laufen jetzt in derselben Transaktion mit
        // derselben Kurve: Der Streifen geht sofort (siehe
        // `Theme.Motion.transition`), und die Liste wächst gefedert in den
        // frei werdenden Platz. Eine Bewegung statt zweier verschiedener.
        .safeAreaInset(edge: .bottom) {
            if !hasAnyFavorites && !isLoading {
                Text("Wähle mindestens eine Filiale, um fortzufahren.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(.bar)
                    .accessibilityHidden(true)
                    .stateTransition(.element)
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

    // MARK: Ketten statt Filialen auf der ersten Seite

    /// Die schon gewählten Filialen, quer über alle Ketten.
    ///
    /// **Sie stehen unten, seit dem 08.08.** Bis dahin standen sie oben, mit
    /// der Begründung, man solle eine Wahl wieder los werden, ohne zu erraten,
    /// hinter welcher Kettenseite sie liegt. Erreichbar sind sie dort
    /// weiterhin — der Abschnitt ist nur ans Ende gewandert. Was die alte
    /// Reihenfolge übersah: Der Abschnitt **wächst mit jeder Wahl**, und was
    /// er wegschiebt, sind genau die Ketten, die man als Nächstes dazunehmen
    /// will. Scott am 08.08.: „the markets we already decided should go down
    /// so i dont have to scroll down to reach penny rewe etc."
    ///
    /// **Am Bild gemessen** (Wähler mit **zwei** gewählten Filialen, die vier
    /// Kettenzeilen am Monogramm abgezählt): Sie standen bei **53/60/68/76 %**
    /// der Bildschirmhöhe, jetzt bei **31/39/46/54 %**. Eine Zeile ist rund
    /// 8 % hoch — **jede weitere Wahl schob die Ketten um weitere 8 % nach
    /// unten**, und genau das ist der Fall, den Scott hat.
    ///
    /// Dieselbe Ordnung wie „Erledigt" in der Einkaufsliste: Was erledigt ist,
    /// steht unten. Die Kettenzeile trägt „1 gewählt" und ein Häkchen, die
    /// Auswahl ist oben also weiterhin **abzulesen** — nur nicht mehr
    /// auszubreiten.
    ///
    /// Beim Suchen entfällt der Abschnitt: Dann stehen die Treffer flach da,
    /// und eine gewählte Filiale wäre zweimal im Bild.
    @ViewBuilder
    private var chosenSection: some View {
        let chosen = rows(for: filtered.filter { store.isFavorite($0) })
        if !chosen.isEmpty {
            Section {
                ForEach(chosen) { BranchPickerRow(row: $0) }
            } header: {
                Text("Deine Filialen")
            }
        }
    }

    /// Eine Zeile je Kette; die Filialen liegen eine Seite tiefer.
    ///
    /// Vorher standen bis zu drei Filialen je Kette direkt hier, und „14
    /// weitere EDEKA-Filialen" klappte im selben Bildschirm auf. Gemeldet am
    /// 2026-08-01: Wer drei Ketten durchgeht, scrollt an allen vorbei. Neun
    /// Ketten sind jetzt neun Zeilen, unabhängig davon, wie viele Filialen
    /// dahinter liegen — in Dresden sind das 113.
    @ViewBuilder
    private var chainSection: some View {
        if !chainGroups.isEmpty {
            Section {
                ForEach(chainGroups, id: \.chain) { group in
                    chainRow(chain: group.chain, markets: group.markets)
                }
            } header: {
                Text(chainSectionTitle)
            } footer: {
                Text("Tippe eine Kette an, um ihre Filialen zu sehen.")
            }
        }
    }

    /// **„In deiner Nähe" sagt nicht, wie nah** (Scott, 06.08.: „vlt etwas
    /// große Reichweite").
    ///
    /// Er hat recht, und das Problem war nicht der Umkreis, sondern dass ihn
    /// niemand nannte: In Dresden liegen im Zehn-Kilometer-Kreis über hundert
    /// Filialen, und eine Überschrift, die sie alle „in deiner Nähe" nennt,
    /// behauptet mehr Nähe, als die Zahl hergibt.
    ///
    /// Die Reichweite steht jetzt dabei, und zwar **gemessen** statt
    /// angenommen: die Entfernung der weitesten geladenen Filiale. Der Umkreis
    /// wächst auf dem Land automatisch mit (`nearbyWideningIfSparse`) — eine
    /// feste Zahl in der Überschrift wäre dort schlicht falsch.
    private var chainSectionTitle: String {
        let weiteste = chainGroups
            .flatMap(\.markets)
            .compactMap { distance(for: $0) }
            .max()
        guard let weiteste else { return "Ketten in deiner Nähe" }
        return "Ketten im Umkreis von \(MarketFilter.distanceLabel(weiteste))"
    }

    private func chainRow(chain: String, markets: [Market]) -> some View {
        let selected = markets.filter { store.isFavorite($0) }.count
        let subtitle = MarketFilter.chainSubtitle(
            branchCount: markets.count,
            selectedCount: selected,
            // **Null Kilometer heißt „keine Angabe", nicht „du stehst drin".**
            // Am 06.08. im Wähler gesehen: „REWE · nächste 0,0 km". Filialen
            // ohne Koordinate im Verzeichnis liefern 0, und die Zeile machte
            // daraus eine Behauptung, die kein Mensch glaubt. Ohne Entfernung
            // fällt der Teil jetzt weg — dafür ist `nearestKm` optional.
            nearestKm: markets.compactMap { distance(for: $0) }.filter { $0 > 0 }.min()
        )
        return NavigationLink {
            ChainBranchesView(chain: chain, rows: rows(for: markets))
        } label: {
            HStack {
                // Das Monogramm der Kette statt ihres Logos — siehe `ChainMark`
                // für die ganze Abwägung.
                ChainMark(chain: chain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(chain)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                if selected > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                        .font(.title3)
                }
            }
        }
        .accessibilityLabel("\(chain), \(subtitle)")
        .accessibilityHint("Öffnet die Filialen dieser Kette")
        .accessibilityIdentifier("picker.chain.\(chain)")
    }

    /// Fertig beschriftete Zeilen. Titel und Untertitel rechnet der Wähler,
    /// weil nur er Verzeichnis und Standort kennt.
    private func rows(for markets: [Market]) -> [BranchPickerRow.Row] {
        markets.map {
            BranchPickerRow.Row(
                market: $0, title: rowTitle(for: $0), subtitle: subtitle(for: $0)
            )
        }
    }

    /// Der Zeilentitel: der Kettenname nur bei den bundesweiten Katalogen, sonst
    /// der um die Kette gekürzte Filialname (siehe `MarketFilter.branchLabel`).
    private func rowTitle(for market: Market) -> String {
        if market.isNationwide { return market.chain }
        return rowTitles[market.marketId]
            ?? MarketFilter.branchLabel(name: market.branchName, chain: market.chain)
    }

    /// Die Titel aller Zeilen auf einmal — siehe `MarketFilter.titles`.
    ///
    /// Auf einmal und nicht je Zeile, weil ein Titel erst im Vergleich mit den
    /// **anderen** gezeigten Zeilen gut oder schlecht ist: „Dresden" ist als
    /// einzelne Zeile schon nichtssagend, „Striesen-Süd" erst als zweite.
    /// Straße und Stadt kommen aus dem Verzeichnis; Zeilen aus `markets`
    /// tragen sie nicht und behalten den gekürzten Namen.
    private var rowTitles: [String: String] {
        MarketFilter.titles(for: markets.map { market in
            let branch = plan?.byMarketId[market.marketId]?.branch
            return MarketFilter.Row(
                id: market.marketId,
                name: market.branchName,
                chain: market.chain,
                street: branch?.street,
                city: branch?.city
            )
        })
    }

    /// What the user needs to tell two stores of the same chain apart: the
    /// street, and how far it is. Falls back to the postcode when the row came
    /// from `markets` instead of the directory — that one has no address.
    private func subtitle(for market: Market) -> String {
        if market.isNationwide { return "Deutschlandweit" }
        let entry = plan?.byMarketId[market.marketId]
        let address = entry?.address ?? ""
        let distance = distance(for: market).map { km -> String in
            let label = MarketFilter.distanceLabel(km)
            // Without the phone's position the number is measured from a
            // postcode centre, and with several regions a different one per
            // row. Then it has to say which — an unlabelled number that
            // silently changes its reference point is what caused the report.
            //
            // **Seit dem 02.08. bei jeder Region, nicht erst ab der zweiten.**
            // Scott las in Anklam Entfernungen, die er sich nicht erklären
            // konnte, und vermutete den falschen Bezugspunkt. Nachgemessen war
            // der Punkt richtig (die PLZ-Mitte 17389 liegt 0,44 km vom Penny
            // entfernt) — die Zahlen stimmten, die Liste reichte nur bis ins
            // 11 km entfernte Ducherow, weil vor Ort nichts im Verzeichnis
            // stand. Genau diese Frage beantwortet die Herkunft, und sie
            // beantwortet sie auch bei einer einzigen Region.
            guard deviceAnchor == nil, let plz = entry?.anchorPLZ else { return label }
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
                anchor: candidate.anchor.marketId,
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

/// Eine wählbare Filialzeile. Eigener Typ, weil Wähler, Suchtreffer und
/// Kettenseite dieselbe Zeile zeigen.
struct BranchPickerRow: View {
    /// Fertig beschriftete Zeile — siehe `MarketPickerView.rows(for:)`.
    struct Row: Identifiable {
        let market: Market
        let title: String
        let subtitle: String
        var id: String { market.marketId }
    }

    @Environment(RegionStore.self) private var store
    @Environment(BranchRequestStore.self) private var branchRequests
    let row: Row

    var body: some View {
        let market = row.market
        let isFav = store.isFavorite(market)
        return Button {
            // Eine Transaktion für alles, was an dieser Berührung hängt: die
            // Zeile selbst, der Hinweis an der Unterkante und die Zeilen, die
            // dabei ihren Platz ändern.
            withAnimation(Theme.Motion.element.animation) { store.toggleFavorite(market) }
            // Eine Filiale, die das Backend nie geholt hat, ist der ganze Grund
            // für `branch_requests` — der Regionslauf holte je Kette nur eine.
            // Gemessen 2026-07-25: rund 40 s, deshalb still im Hintergrund.
            if store.isFavorite(market) {
                Task { await branchRequests.request(market.marketId) }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(row.subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                // Häkchen, kein Stern: eine Auswahl, keine Bewertung — und
                // `Color.yellow` maß auf der cremefarbenen Fläche 1,37:1.
                Image(systemName: isFav ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isFav ? Theme.accent : Color.secondary)
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
            }
            // Ohne das reagiert die Zeile nur dort, wo etwas gezeichnet ist —
            // und in der Mitte sitzt der `Spacer`.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Kein `.accessibilityElement(children: .ignore)`: auf einem Button
        // verdeckt es das Element, das VoiceOver fokussiert, und das Label
        // darunter fiel still weg. Die Kette bleibt im Label, weil VoiceOver
        // die Abschnittsüberschrift nicht mitliest.
        .accessibilityLabel(
            "\(market.chain), \(market.isNationwide ? "deutschlandweit" : row.title)"
        )
        // Adresse und Entfernung in den Hinweis, nicht ins Label: Das Label ist
        // der Name, auf den die UI-Journeys zeigen.
        .accessibilityHint(
            [row.subtitle, isFav ? "Doppeltippen zum Entfernen" : "Doppeltippen zum Hinzufügen"]
                .joined(separator: ". ")
        )
        .accessibilityValue(isFav ? "ausgewählt" : "nicht ausgewählt")
        .accessibilityAddTraits(isFav ? [.isSelected] : [])
    }
}

/// Alle Filialen **einer** Kette, auf einer eigenen Seite mit eigenem „Fertig".
///
/// Scotts Weg vom 2026-08-01: Kette antippen, die drei Kaufland wählen,
/// „Fertig", zurück, nächste Kette. Der Wähler wächst dabei nicht mit.
private struct ChainBranchesView: View {
    @Environment(\.dismiss) private var dismiss
    let chain: String
    let rows: [BranchPickerRow.Row]

    var body: some View {
        List {
            Section {
                ForEach(rows) { BranchPickerRow(row: $0) }
            } footer: {
                Text("Mehrere Filialen einer Kette sind erlaubt — nur deren Angebote zählen für deine Liste.")
            }
            .listRowBackground(Theme.surface)
        }
        .themedScreen()
        .navigationTitle(chain)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                // Nie gesperrt: Diese Seite ist nicht die Stelle, an der über
                // „mindestens eine Filiale" entschieden wird — das tut der
                // Wähler darunter. Wer eine Kette nur ansieht, muss auch
                // wieder heraus.
                Button("Fertig") { dismiss() }
                    .accessibilityIdentifier("chain.done")
            }
        }
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
