import SwiftUI

/// **Warum bei dieser Filiale nichts steht** — als reine Rechnung, damit der
/// Satz prüfbar ist, ohne eine Ansicht zu bauen.
///
/// Die Unterscheidung ist der ganze Punkt, und sie war am 02.08. in Anklam
/// falsch: `.failed(.timedOut)` teilte sich den Zweig mit `.ready` und
/// behauptete damit „veröffentlicht nichts online" über eine Filiale, die
/// gerade erst angefordert worden war. Der Penny Friedländer Straße trug
/// anderthalb Minuten später 283 Angebote.
enum NoOffersReason {
    /// `upcomingFrom` schlägt jeden Zustand: Wenn der nächste Prospekt schon
    /// da ist, ist die Frage „warum steht hier nichts" beantwortet — mit einem
    /// Datum statt mit einer Vermutung über den Markt.
    static func text(for state: BranchSyncState, upcomingFrom: Date? = nil) -> String {
        if let start = upcomingFrom {
            return "Der neue Prospekt gilt ab \(Self.dayFormatter.string(from: start)) — bis dahin steht hier nichts."
        }
        switch state {
        case .requested, .syncing:
            return "Die Angebote werden gerade geholt — das dauert etwa eine Minute."
        case .unknown:
            // Kommt nur noch vor, bevor die Prüfung beim Start durch ist.
            return "Die Angebote werden gleich geholt."
        case .failed(.network):
            return "Die Angebote konnten nicht geladen werden. Prüf deine Verbindung."
        case .failed(.timedOut):
            // Wir wissen hier ausschließlich, dass **wir** nicht mehr warten —
            // nichts über den Markt. Alles andere wäre geraten.
            return "Die Angebote sind noch unterwegs. Sie erscheinen, sobald der Markt gesynct ist — spätestens mit dem nächsten Nachtlauf."
        case .ready:
            // Das Backend war da und hat nichts gefunden. Bei EDEKA Böse in
            // Ahlbeck ist das der Dauerzustand: `edeka.de` gibt für diesen
            // Markt die Marktseite statt einer Angebotsliste zurück.
            return "Dieser Markt veröffentlicht seinen Prospekt nicht online."
        }
    }

    /// „Montag, 3. August" — der Wochentag gehört dazu, weil „ab 3.8." niemand
    /// ohne Kalender einordnet und die Frage immer „heute oder morgen?" ist.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.setLocalizedDateFormatFromTemplate("EEEE d. MMMM")
        return f
    }()

    /// Nur wenn wirklich eine Filiale fertig gesynct ist und nichts geliefert
    /// hat, stimmt der Satz „nicht jeder Markt stellt seinen Prospekt ins
    /// Netz". Über eine Filiale, auf die wir noch warten, ist er eine Ausrede
    /// — und über eine, deren Prospekt am Montag anfängt, schlicht falsch.
    static func footerApplies(to states: [BranchSyncState]) -> Bool {
        states.contains { $0 == .ready }
    }
}

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

    /// Sagt, ob gerade das Verzeichnis der Gegend geholt wird — der Zustand
    /// zwischen „eingecheckt" und „hier gibt es Märkte", der bis zum 02.08.
    /// wie eine Sackgasse aussah.
    @Environment(AreaRequestStore.self) private var areaRequests

    /// Suche, Filter, Sortierung und Markt-Leiste — geteilt mit der Vorschau,
    /// siehe `OfferBrowser`. Jeder Bildschirm hält seinen eigenen Zustand und
    /// füttert ihn mit seinem eigenen Topf; damit kann keiner die Zeilen des
    /// anderen sehen.
    @State private var browser = OfferBrowser()
    @State private var selectedOffer: Offer?

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
                .searchable(text: $browser.search, prompt: "Produkt suchen")
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
            browser.dropMarketFilterIfGone(from: updated)
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

    /// Siehe `MarketChipBar` — gebaut aus den Zeilen **dieses** Bildschirms.
    private var marketChips: some View {
        MarketChipBar(
            chains: browser.chipChains(in: store.offers),
            selection: $browser.market,
            identifier: "offers.marketChips"
        )
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
        if areaRequests.isFetchingArea {
            // **Der Zustand, den Anklam nicht hatte.** Wer frisch in eine
            // Gegend eincheckt, deren Verzeichnis noch geholt wird, sah hier
            // dieselbe Leere wie jemand, für den es nichts zu holen gibt.
            // Der Lauf ist echt, also darf er einen Kreisel haben.
            ContentUnavailableView {
                Label("Deine Gegend wird geholt", systemImage: "arrow.down.circle")
            } description: {
                Text("Wir sammeln gerade die Märkte um dich herum. Das dauert ein paar Minuten — die Angebote kommen danach, spätestens mit dem nächsten Nachtlauf.")
            } actions: {
                ProgressView()
            }
            .accessibilityIdentifier("offers.areaFetching")
        } else if !branchesWithoutOffers.isEmpty {
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
        OfferCoverage.branchesWithoutOffers(favorites: favoriteMarkets, offers: store.offers)
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
            if NoOffersReason.footerApplies(to: branchesWithoutOffers
                .filter { OfferCoverage.upcomingStart(for: $0, in: store.upcomingOffers) == nil }
                .map { branchRequests.state(for: $0.marketId) }) {
                Text("Nicht jeder Markt stellt seinen Prospekt ins Netz. Le Chariot kann nur zeigen, was die Kette selbst veröffentlicht.")
            }
        }
        .accessibilityIdentifier("offers.unavailableBranches")
    }

    private func reasonForNoOffers(_ market: Market) -> String {
        NoOffersReason.text(
            for: branchRequests.state(for: market.marketId),
            upcomingFrom: OfferCoverage.upcomingStart(for: market, in: store.upcomingOffers)
        )
    }

    private var offerList: some View {
        List {
            if store.isStale {
                staleBanner
            }
            let visible = browser.visible(in: store.offers)
            if visible.isEmpty {
                // Die drei Sackgassen stehen seit dem 2026-08-02 in
                // `OfferEmptyResultView`, weil die Vorschau dieselben drei hat.
                OfferEmptyResultView(
                    browser: browser,
                    scope: .current,
                    onResetFilters: { browser.resetFilters() },
                    onClearMarket: { browser.market = nil }
                )
            } else {
                topDealsSection
                ForEach(Array(OfferQuery.grouped(visible, by: browser.grouping).enumerated()), id: \.element.key) { index, section in
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
                if browser.isBrowsing, !branchesWithoutOffers.isEmpty {
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
        let deals = browser.isBrowsing ? OfferAnalytics.topDeals(store.offers, limit: 5) : []
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
        guard browser.grouping == .market else { return key }
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
            OfferFilterMenu(
                grouping: $browser.grouping,
                sort: $browser.sort,
                category: $browser.category,
                hasActiveFilter: browser.hasActiveFilter
            )
        }
    }
}

#Preview {
    OffersView(
        favoriteMarkets: MockFixtures.markets,
        store: OfferStore(repository: MockOfferRepository(), cache: nil),
        priceHistoryRepository: MockPriceHistoryRepository()
    )
    .environment(BranchRequestStore(repository: MockBranchRequestRepository()))
    .environment(AreaRequestStore(repository: MockAreaRequestRepository()))
}
