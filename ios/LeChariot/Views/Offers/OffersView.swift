import SwiftUI

/// Angebote tab: cached-first offer list of the chosen branches. Decoupled
/// from RegionStore — it takes the markets, nothing else.
struct OffersView: View {
    let favoriteMarkets: [Market]

    /// Shared with the shopping list — see `ContentView.offerStore`.
    let store: OfferStore

    /// Only the detail sheet needs it, and only after a tap — defaulted so
    /// neither `ContentView` nor the preview has to know about it.
    var priceHistoryRepository: PriceHistoryRepositoryProtocol = AppRepositories.priceHistory

    /// Sagt, ob eine Filiale ohne Angebote gerade geholt wird oder dauerhaft
    /// nichts liefert — siehe `unavailableBranchesSection`.
    @Environment(BranchRequestStore.self) private var branchRequests

    @State private var search = ""
    @State private var selectedOffer: Offer?
    @State private var grouping: OfferGrouping = .market
    @State private var sort: OfferSort = .standard
    @State private var categoryFilter: String?
    @State private var marketFilter: String?

    private var chains: [String] {
        Array(Set(favoriteMarkets.map(\.chain))).sorted()
    }

    /// The chosen branches themselves. Since the backend keys offers by branch
    /// (migration v13), this is the filter that actually matches what the user
    /// picked — the chain list above only still exists for the section labels.
    /// The market chips above the list are computed from the loaded offers
    /// instead, so no chip can lead to an empty result — see `chipChains`.
    private var branchIds: [String] {
        favoriteMarkets.map(\.marketId).sorted()
    }

    var body: some View {
        NavigationStack {
            content
                .themedScreen()
                .navigationTitle("Angebote")
                .searchable(text: $search, prompt: "Produkt suchen")
                .toolbar {
                    filterMenu
                    nextWeekLink
                }
                .sheet(item: $selectedOffer) { offer in
                    OfferDetailView(
                        offer: offer,
                        favoriteMarkets: favoriteMarkets,
                        historyRepository: priceHistoryRepository
                    )
                }
        }
        .task(id: branchIds) {
            await store.load(branchIds: branchIds, chains: chains)
        }
        // A market filter can outlive the branch it names — unfavourite Netto in
        // the settings and the Angebote tab was left filtering on a chain that no
        // longer has offers, i.e. permanently empty with no visible cause.
        .onChange(of: chains) { _, updated in
            if let marketFilter, !updated.contains(marketFilter) {
                self.marketFilter = nil
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .loading:
            // Skeleton matching the loaded list shape — no layout jump when
            // real offers arrive. Bare rows on purpose: a disabled Button would
            // dim the already-redacted placeholder a second time, and the list
            // carries its own "wird geladen" label below.
            List(Offer.skeleton) { OfferRowView(offer: $0).listRowBackground(Theme.surface) }
                .redacted(reason: .placeholder)
                .disabled(true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Angebote werden geladen")
        case .empty:
            emptyState
        case .error(let message):
            ContentUnavailableView {
                Label("Fehler beim Laden", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Erneut versuchen") {
                    Task { await store.refresh() }
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Theme.onAccent)
            }
        case .loaded:
            VStack(spacing: 0) {
                marketChips
                offerList
            }
        }
    }

    // MARK: Markt-Leiste

    /// Die Ketten, für die die Leiste einen Chip zeigt.
    ///
    /// Gerechnet aus den **geladenen Angeboten**, nicht aus den gewählten
    /// Filialen. Ein Chip für eine Kette, die diese Woche nichts hat, wäre
    /// ein Tipp in die Sackgasse „Nichts für diesen Filter"; dass eine
    /// gewählte Filiale leer ist, erklärt der Abschnitt „Ohne Angebote" am
    /// Ende der Liste, und zwar mit dem Grund.
    ///
    /// Die aktive Kette bleibt drin, auch wenn sie gerade aus den Angeboten
    /// fällt (eine Aktualisierung kann das). Sonst verschwände mit dem Chip
    /// der einzige sichtbare Hinweis darauf, warum die Liste leer ist — und
    /// das ist genau die Fehlerklasse, gegen die diese Runde antritt.
    private var chipChains: [String] {
        var ketten = Set(store.offers.map(\.market))
        if let marketFilter { ketten.insert(marketFilter) }
        return ketten.sorted()
    }

    /// Ein Tipp statt einer Scroll-Lotterie.
    ///
    /// Den Marktfilter gab es schon, aber als vierten Picker in einem Menü
    /// der Werkzeugleiste — wer zu Lidl wollte, scrollte trotzdem. Die Leiste
    /// steht deshalb **über** der Liste und scrollt nicht mit ihr weg.
    ///
    /// Bei genau einer Kette filtert sie nichts und wäre reine Höhe; dann
    /// bleibt sie weg. Dieselbe Regel wie bei der Konsum-Zeile im Picker: Was
    /// fast niemandem hilft, darf nicht jeder bezahlen.
    @ViewBuilder
    private var marketChips: some View {
        let ketten = chipChains
        if ketten.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    marketChip("Alle", chain: nil)
                    ForEach(ketten, id: \.self) { marketChip($0, chain: $0) }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
            }
            .background(Theme.background)
            .accessibilityIdentifier("offers.marketChips")
        }
    }

    /// Mindestens 44 pt hoch, nicht die hübscheren 36: `performAccessibilityAudit`
    /// misst Trefferflächen mit, und der Angebote-Bildschirm steht in
    /// `AccessibilityAuditTests` unter Gate.
    private func marketChip(_ title: String, chain: String?) -> some View {
        let aktiv = marketFilter == chain
        return Button {
            // Ein zweiter Tipp auf den aktiven Chip hebt ihn auf. „Alle" liegt
            // am anderen Ende der Leiste, und dorthin zurückzuscrollen wäre
            // wieder genau die Lotterie, gegen die die Leiste gebaut ist.
            marketFilter = aktiv ? nil : chain
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(aktiv ? Theme.onAccent : Color.primary)
                .padding(.horizontal, Theme.Spacing.lg)
                .frame(minHeight: 44)
                .background(aktiv ? Theme.accent : Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(aktiv ? Color.clear : Theme.stroke))
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel(chain == nil ? "Alle Märkte" : title)
        .accessibilityAddTraits(aktiv ? [.isSelected] : [])
    }

    /// Region is ready, but there are no offers to show.
    ///
    /// Steht **jede** gewählte Filiale ohne Angebote da, erklärt die Liste
    /// unten das Filiale für Filiale, statt einen Satz über alle zu sagen. Für
    /// einen Tester, dessen einziger Markt seinen Prospekt nicht online stellt,
    /// war „Für deine Filialen liegen gerade keine Angebote vor" schlicht
    /// falsch: Da liegt nichts, und da wird auch nächste Woche nichts liegen.
    @ViewBuilder
    private var emptyState: some View {
        if !branchesWithoutOffers.isEmpty {
            List {
                unavailableBranchesSection
            }
            .refreshable { await store.refresh() }
        } else {
            ContentUnavailableView {
                Label("Keine Angebote", systemImage: "basket")
            } description: {
                Text(store.hasFavoriteChains
                    ? "Für deine Filialen liegen gerade keine Angebote vor. Nimm in den Einstellungen weitere Filialen dazu, um mehr zu sehen."
                    : "Für deine Region liegen aktuell keine Angebote vor. Schau später noch einmal vorbei.")
            } actions: {
                // The empty state has no list, so there is nothing to pull down —
                // without this button a user who suspects a hiccup can only kill
                // the app and hope.
                Button("Erneut laden") {
                    Task { await store.refresh() }
                }
                .buttonStyle(.bordered)
            }
            .accessibilityLabel(store.hasFavoriteChains
                ? "Keine Angebote für deine Filialen"
                : "Keine Angebote für deine Region")
        }
    }

    // MARK: Filialen ohne Angebote

    /// Gewählte Filialen, zu denen keine einzige Zeile geladen wurde.
    ///
    /// Über `marketId` gerechnet, **nicht** über die Sektionen: Die gruppieren
    /// nach Kettenname, und zwei Filialen derselben Kette — davon eine leer —
    /// wären dort nicht zu unterscheiden.
    ///
    /// Bundesweite Einträge (die beiden ALDI-Kataloge) bleiben draußen: Deren
    /// Zeilen tragen die synthetische ID `ALDI_NORD_DE` und nie die der Filiale,
    /// sie stünden also immer fälschlich hier.
    private var branchesWithoutOffers: [Market] {
        let covered = Set(store.offers.compactMap(\.marketId))
        return favoriteMarkets
            .filter { !$0.isNationwide && !covered.contains($0.marketId) }
            .sorted { ($0.chain, $0.branchName) < ($1.chain, $1.branchName) }
    }

    /// Sagt je Filiale, **warum** dort nichts steht.
    ///
    /// Die Unterscheidung ist der ganze Punkt. Bis zum 2026-07-30 verschwand
    /// eine Filiale ohne Angebote spurlos aus der Liste, und der Nutzer meldete
    /// „keine Angebote" — für einen Markt, der gerade geholt wurde, für einen,
    /// der noch nie angefordert worden war, und für einen, der online nichts
    /// veröffentlicht, sah das identisch aus. Es sind drei verschiedene Dinge,
    /// und nur eins davon geht vorbei.
    @ViewBuilder
    private var unavailableBranchesSection: some View {
        Section {
            ForEach(branchesWithoutOffers) { market in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(market.branchName.isEmpty ? market.chain : market.branchName)
                        .font(.subheadline.weight(.medium))
                    Text(reasonForNoOffers(market))
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(Theme.surface)
        } header: {
            Text("Ohne Angebote")
        } footer: {
            Text("Nicht jeder Markt stellt seinen Prospekt ins Netz. Le Chariot kann nur zeigen, was die Kette selbst veröffentlicht.")
        }
        .accessibilityIdentifier("offers.unavailableBranches")
    }

    private func reasonForNoOffers(_ market: Market) -> String {
        switch branchRequests.state(for: market.marketId) {
        case .requested, .syncing:
            "Die Angebote werden gerade geholt — das dauert etwa eine Minute."
        case .unknown:
            // Kommt nur noch vor, bevor die Prüfung beim Start durch ist.
            "Die Angebote werden gleich geholt."
        case .failed(.network):
            "Die Angebote konnten nicht geladen werden. Prüf deine Verbindung."
        case .ready, .failed(.timedOut):
            // Das Backend war da und hat nichts gefunden. Bei EDEKA Böse in
            // Ahlbeck ist das der Dauerzustand: `edeka.de` gibt für diesen
            // Markt die Marktseite statt einer Angebotsliste zurück.
            "Dieser Markt veröffentlicht seinen Prospekt nicht online."
        }
    }

    /// Everything was filtered away. Distinct from `emptyState`: here the data
    /// is fine and the user's own filter is in the way, so the fix is one tap.
    private var noFilterMatchState: some View {
        ContentUnavailableView {
            Label("Nichts für diesen Filter", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text("Für die gewählte Kategorie oder den gewählten Markt gibt es diese Woche keine Angebote.")
        } actions: {
            Button("Filter zurücksetzen") { resetFilters() }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Theme.onAccent)
        }
    }

    private func resetFilters() {
        categoryFilter = nil
        marketFilter = nil
        sort = .standard
    }

    /// Gesucht **innerhalb** einer Kette und nichts gefunden.
    ///
    /// `ContentUnavailableView.search` sagt an dieser Stelle nur „Keine
    /// Ergebnisse für ‚Butter'" — und verschweigt, dass die Suche gerade auf
    /// einen Markt eingeschränkt ist. Bei den anderen liegt vielleicht Butter.
    /// Dieselbe Halbwahrheit wie der Leertext, der EDEKA Böse ein „schau
    /// später noch einmal vorbei" mitgab: ein Satz, der eine Lage behauptet,
    /// die er nicht geprüft hat. Der Ausweg steht daneben und kostet einen Tipp.
    private func noSearchHitInOneMarket(_ chain: String) -> some View {
        ContentUnavailableView {
            Label("Nichts bei \(chain)", systemImage: "magnifyingglass")
        } description: {
            Text("„\(search.trimmingCharacters(in: .whitespaces))" + "“ steht diese Woche nicht in den Angeboten von \(chain). Die anderen Märkte sind gerade ausgeblendet.")
        } actions: {
            Button("In allen Märkten suchen") { marketFilter = nil }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Theme.onAccent)
        }
    }

    private var offerList: some View {
        List {
            if store.isStale {
                staleBanner
            }
            let visible = OfferQuery.apply(
                store.offers, search: search,
                category: categoryFilter, market: marketFilter, sort: sort
            )
            if visible.isEmpty {
                // Drei Sackgassen, die einmal identisch aussahen. Eine leere
                // Suche zeigte die Suchleere („Keine Ergebnisse für ‚'"),
                // obwohl nur ein Filter im Weg stand — und eine Suche
                // innerhalb einer Kette verschwieg, dass sie eingeschränkt ist.
                if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                    if let marketFilter {
                        noSearchHitInOneMarket(marketFilter)
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                } else {
                    noFilterMatchState
                }
            } else {
                topDealsSection
                ForEach(Array(OfferQuery.grouped(visible, by: grouping).enumerated()), id: \.element.key) { index, section in
                    Section(sectionTitle(section.key)) {
                        ForEach(section.offers) { offerRow($0) }
                    }
                    .listRowBackground(Theme.surface)
                    // Reserved ad position: after the first market section, so a
                    // creative can never be read as part of a group. Renders
                    // nothing today — see `AdSlot`.
                    if index == 0 {
                        AdSlotView(slot: .offerListInline)
                    }
                }
                // Ganz unten und nur ohne Suche/Filter: Eine Filiale, die diese
                // Woche nichts hat, ist eine Fußnote zur Liste, kein Ergebnis
                // in ihr — und wer nach „Butter" sucht, will sie erst recht
                // nicht dazwischen haben.
                if search.trimmingCharacters(in: .whitespaces).isEmpty,
                   categoryFilter == nil, marketFilter == nil,
                   !branchesWithoutOffers.isEmpty {
                    unavailableBranchesSection
                }
            }
        }
        .refreshable { await store.refresh() }
    }

    /// A row whose whole width opens the detail sheet.
    ///
    /// The Button owns the accessibility element — no
    /// `.accessibilityElement(children: .ignore)` anywhere in this chain, or
    /// the label below is swallowed (see `OfferRowView`). `TactileButtonStyle`
    /// brings its own `.contentShape(Rectangle())`, so the gap between product
    /// text and price is tappable too.
    private func offerRow(_ offer: Offer) -> some View {
        Button {
            selectedOffer = offer
        } label: {
            OfferRowView(offer: offer)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel(offer.voiceOverSummary)
        .accessibilityHint("Zeigt Details und Preisverlauf")
        // Stable handle for the UI journeys — the label itself is a whole
        // sentence built from whichever offer happens to be live.
        .accessibilityIdentifier("offers.row")
    }

    /// The five deepest discounts, pinned above the grouped list. Hidden as
    /// soon as the user searches or filters — then they are looking for
    /// something specific and a "best of" list is only in the way.
    @ViewBuilder
    private var topDealsSection: some View {
        let isBrowsing = search.isEmpty && !hasActiveFilter
        let deals = isBrowsing ? OfferAnalytics.topDeals(store.offers, limit: 5) : []
        if !deals.isEmpty {
            Section {
                ForEach(deals) { offerRow($0) }
            } header: {
                Text("Top-Deals der Woche")
            }
            .listRowBackground(Theme.surface)
        }
    }

    private var staleBanner: some View {
        Label(
            store.isOffline
                ? "Offline – zeige zuletzt geladene Angebote"
                : "Angebote sind möglicherweise veraltet",
            systemImage: "exclamationmark.triangle"
        )
        .font(.footnote)
        .foregroundStyle(Theme.warning)
        .listRowBackground(Theme.warningSurface)
    }

    /// Market sections show the branch name when the chain has exactly one
    /// favorited branch across the shown regions.
    private func sectionTitle(_ key: String) -> String {
        guard grouping == .market else { return key }
        return Market.displayTitle(chain: key, favorites: favoriteMarkets)
    }

    /// Der Weg in die Vorschau — beschriftet, nicht als Reiter neben „Angebote".
    ///
    /// Ein Reiter stünde gleichrangig neben der laufenden Woche und wäre genau
    /// die Verwechslung, die die Vorschau nicht haben darf. Als eigener
    /// Bildschirm hinter einem benannten Knopf muss man ihn absichtlich öffnen.
    @ToolbarContentBuilder
    private var nextWeekLink: some ToolbarContent {
        if FeatureFlags.nextWeekPreview {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    NextWeekView(
                        favoriteMarkets: favoriteMarkets,
                        store: store,
                        priceHistoryRepository: priceHistoryRepository
                    )
                } label: {
                    Label("Nächste Woche", systemImage: "calendar")
                }
                .accessibilityIdentifier("offers.nextWeek")
            }
        }
    }

    private var filterMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Gruppierung", selection: $grouping) {
                    ForEach(OfferGrouping.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Sortierung", selection: $sort) {
                    ForEach(OfferSort.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Kategorie", selection: $categoryFilter) {
                    Text("Alle Kategorien").tag(String?.none)
                    ForEach(Categories.all, id: \.self) { Text($0).tag(String?.some($0)) }
                }
                // Kein „Markt"-Picker mehr: Das steht seit dem 2026-07-31 als
                // Chip-Leiste über der Liste, sichtbar statt vier Ebenen tief.
                // Zwei Bedienelemente für denselben Zustand sind die Sorte
                // Ballast, die dieselbe Runde im Filial-Picker abgeräumt hat.
            } label: {
                Label("Filter", systemImage: hasActiveFilter
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
            }
        }
    }

    private var hasActiveFilter: Bool {
        categoryFilter != nil || marketFilter != nil || sort == .deals
    }
}

#Preview {
    OffersView(
        favoriteMarkets: MockFixtures.markets,
        store: OfferStore(repository: MockOfferRepository(), cache: nil),
        priceHistoryRepository: MockPriceHistoryRepository()
    )
    .environment(BranchRequestStore(repository: MockBranchRequestRepository()))
}
