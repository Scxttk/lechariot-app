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
    static func text(
        for state: BranchSyncState, upcomingFrom: Date? = nil, endedOn: Date? = nil
    ) -> String {
        if let start = upcomingFrom {
            // **Das Ende gehört dazu, sobald wir es kennen** (10.08.). Ohne
            // es sagt der Satz nur, dass etwas kommt, und lässt offen, ob
            // hier je etwas stand — genau die Lücke, die am Sonntag wie ein
            // Ausfall aussieht. Fehlt das Datum, fällt der halbe Satz weg;
            // behauptet wird nichts.
            guard let ended = endedOn else {
                return "Der neue Prospekt gilt ab \(Self.dayFormatter.string(from: start)) — bis dahin steht hier nichts."
            }
            return "Die Angebote endeten \(Self.dayFormatter.string(from: ended)). Der neue Prospekt gilt ab \(Self.dayFormatter.string(from: start))."
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
            // **Ein bekanntes Ende schlägt diesen Satz** (10.08.). „Dieser
            // Markt veröffentlicht seinen Prospekt nicht online" ist eine
            // Aussage über den Markt, und über eine Kette, deren Woche
            // nachweislich am Samstag geendet hat, ist sie falsch — dieselbe
            // Klasse Fehler wie am 02.08. in Ahlbeck, nur aus der anderen
            // Richtung. Der Satz bleibt für den Fall, für den er gedacht war:
            // Wir waren da, es gab nie etwas.
            if let ended = endedOn {
                return "Die Angebote endeten \(Self.dayFormatter.string(from: ended)). Der neue Prospekt ist noch nicht da."
            }
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
    /// Der zweite Weg in die Vorschau — für den Knopf im Leerzustand einer
    /// ruhenden Kette. Der Knopf in der Werkzeugleiste bleibt ein
    /// `NavigationLink`; beide landen auf demselben Bildschirm.
    @State private var showsNextWeek = false

    /// Die Einmal-Tipps und die Ernährungsfrage — optional, damit Previews
    /// ohne sie auskommen. Siehe `ContextTipStore`.
    @Environment(ContextTipStore.self) private var tips: ContextTipStore?
    /// Nur für die Ernährungsfrage — ebenfalls optional, aus demselben Grund.
    @Environment(ProfileStore.self) private var profile: ProfileStore?

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
                // **Nullhöhen-Marker unterhalb der Navigationsleiste** — der
                // einzige Griff, den SwiftUI auf eine von UIKit gezeichnete
                // Leiste hergibt. „Nächste Woche" ist ein `ToolbarItem` und
                // liegt außerhalb des Baums, aus dem die Anker kommen; siehe
                // `TutorialOverlay.navBarBand`.
                //
                // **Er sitzt hier und nicht in `ContentView`, und das ist der
                // Fund vom 03.08.:** Dort lag er außerhalb dieses
                // `NavigationStack` und meldete damit die Oberkante der
                // sicheren Fläche — also die Kante **über** der Leiste. Das
                // Band lief von 0 bis 66 pt und leuchtete die Uhr aus, während
                // die Karte „oben links" sagte und der Knopf darunter im
                // Dunkeln lag.
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .allowsHitTesting(false)
                        .tutorialAnchor(.navBarBottom)
                }
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
                .navigationDestination(isPresented: $showsNextWeek) {
                    NextWeekView(
                        favoriteMarkets: favoriteMarkets,
                        store: store,
                        priceHistoryRepository: priceHistoryRepository
                    )
                }
                // Jeder Tab-Wechsel hierher ruft das erneut; einmal je Sitzung
                // zählen ist Sache des Stores. `nextWeekAvailable` ist Schalter
                // **und** Filialen: Ohne Filialen steht dieser Bildschirm gar
                // nicht (siehe `ContentView.allRegionScoped`), aber die Fassung
                // ohne Flag hat schlicht keinen Knopf „Nächste Woche".
                .onAppear {
                    tips?.offersAppeared(
                        nextWeekAvailable: FeatureFlags.nextWeekPreview
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
            List(Offer.skeleton) { OfferRowView(offer: $0).listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke) }
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

    /// Siehe `MarketChipBar` — gebaut aus den Zeilen **dieses** Bildschirms,
    /// plus den Ketten, die gerade ruhen (`restingChains`).
    private var marketChips: some View {
        MarketChipBar(
            chains: browser.chipChains(in: store.offers, resting: restingChains),
            selection: $browser.market,
            identifier: "offers.marketChips",
            resting: restingChains
        )
    }

    /// Gewählte Ketten ohne gültige Angebote, deren Grund wir kennen.
    private var restingChains: Set<String> {
        OfferCoverage.restingChains(
            favorites: favoriteMarkets,
            current: store.offers,
            windows: store.chainWindows
        )
    }

    /// Gesetzt, wenn die Liste gerade auf eine ruhende Kette gefiltert ist —
    /// dann steht hinter dem leeren Ergebnis der Grund und nicht „Nichts für
    /// diesen Filter".
    private var restingWindow: OfferCoverage.ChainOfferWindow? {
        guard let chain = browser.market, restingChains.contains(chain) else { return nil }
        return store.chainWindows[chain]
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
            .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
        } header: {
            Text("Ohne Angebote")
        } footer: {
            if NoOffersReason.footerApplies(to: branchesWithoutOffers
                .filter { OfferCoverage.upcomingStart(for: $0, in: store.upcomingOffers) == nil }
                .map { branchRequests.state(for: $0.marketId) }) {
                Text("Nicht jeder Markt stellt seinen Prospekt ins Netz. \(AppBrand.name) kann nur zeigen, was die Kette selbst veröffentlicht.")
            }
        }
        .accessibilityIdentifier("offers.unavailableBranches")
    }

    private func reasonForNoOffers(_ market: Market) -> String {
        NoOffersReason.text(
            for: branchRequests.state(for: market.marketId),
            upcomingFrom: OfferCoverage.upcomingStart(for: market, in: store.upcomingOffers),
            endedOn: store.chainWindows[market.chain]?.endedOn
        )
    }

    /// Die Bilder der obersten Zeilen im Voraus holen.
    ///
    /// **40 und nicht alle:** Ein Prospekt trägt über tausend Zeilen, und ein
    /// Vorauslauf über alle wäre ein Denial of Service gegen sechs fremde CDNs
    /// — am 03.08. gemessen zwischen 266 und 2 751 ms je Bild, 30 bis 480 kB.
    /// Vierzig deckt mehrere Bildschirmhöhen ab; was danach kommt, lädt beim
    /// Scrollen und liegt dann im Speicher.
    private var prefetchURLs: [URL] {
        browser.visible(in: store.offers)
            .prefix(40)
            .compactMap { $0.imageUrl.flatMap(URL.init(string:)) }
    }

    private var offerList: some View {
        List {
            if store.isStale {
                staleBanner
            }
            // Der Vorschau-Tipp steht oben, direkt unter dem Knopf, den er
            // erklärt — siehe `ContextTipCard`.
            Section {
                ContextTipCard(store: tips, screen: .offers)
                    .listRowInsets(EdgeInsets(
                        top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                        bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                    ))
            }
            .listRowBackground(Color.clear)
            dietPrompt
            let visible = browser.visible(in: store.offers)
            if visible.isEmpty {
                // Die drei Sackgassen stehen seit dem 2026-08-02 in
                // `OfferEmptyResultView`, weil die Vorschau dieselben drei hat.
                OfferEmptyResultView(
                    browser: browser,
                    scope: .current,
                    onResetFilters: { browser.resetFilters() },
                    onClearMarket: { browser.market = nil },
                    restingWindow: restingWindow,
                    // **Am selben Schalter wie der Knopf in der
                    // Werkzeugleiste.** Ohne diese Bedingung böte der
                    // Leerzustand einen Weg in einen Bildschirm an, den der
                    // Rest der App gerade versteckt — und `nextWeekLink` ist
                    // die einzige andere Tür dorthin.
                    onShowNextWeek: FeatureFlags.nextWeekPreview
                        ? { showsNextWeek = true } : nil
                )
                // **Der weiße Kasten war keiner der drei Sackgassen zugedacht,
                // er war schlicht die Vorgabe** — am gerenderten Bild gesehen:
                // Der Leertext saß als einzige Zeile dieser Liste auf
                // `systemBackground`, ein weißer Block auf Creme. Jede andere
                // Zeile dieses Bildschirms setzt das seit dem 06.08.; diese
                // war beim Herausziehen nach `OfferEmptyResultView`
                // übersehen worden.
                .listRowBackground(Color.clear)
            } else {
                topDealsSection
                ForEach(Array(OfferQuery.grouped(visible, by: browser.grouping).enumerated()), id: \.element.key) { index, section in
                    Section(sectionTitle(section.key)) {
                        ForEach(section.offers) { offerRow($0) }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
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
        // Der Vorauslauf hängt an dem, was gerade sichtbar wäre — also auch an
        // Suche und Filter. Wer nach „Butter" sucht, bekommt Butter-Bilder
        // geholt und nicht die der Zeilen darüber.
        .task(id: prefetchURLs.map(\.absoluteString)) {
            OfferImageLoader.shared.prefetch(prefetchURLs)
        }
        // **Dieselbe Grammatik wie die Einkaufsliste** (06.08.): Zeilen auf
        // der Seite, getrennt durch eine Haarlinie, statt Blöcken in
        // gerundeten Flächen. Ohne `.listStyle` wäre das `insetGrouped`, die
        // Vorgabe von iOS — und genau die hat die halbe App wie eine
        // Systemeinstellung aussehen lassen.
        //
        // **Die Einstellungen bleiben bewusst gruppiert.** Sie sind ein
        // Formular, kein Inhalt: Dort trennen die Flächen Zusammengehöriges,
        // und ein Nutzer erwartet an dieser Stelle genau das, was iOS überall
        // sonst zeigt. Scotts Beschwerde galt den Inhaltsbildschirmen.
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// Die Ernährungsfrage — nur über einer geladenen Liste, nur nach dem
    /// zweiten Besuch, nur bis zur ersten Antwort. Regeln und Begründung:
    /// `ContextTipRules.showsDietPrompt` und `DietPromptCard`.
    @ViewBuilder
    private var dietPrompt: some View {
        if let profile, let tips,
           tips.showsDietPrompt(dietAnswered: !profile.profile.dietTags.isEmpty) {
            Section {
                DietPromptCard(profile: profile) {
                    withAnimation(.snappy) { tips.dismissDietPrompt() }
                }
                .listRowInsets(EdgeInsets(
                    top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                    bottom: Theme.Spacing.sm, trailing: Theme.Spacing.lg
                ))
            }
            .listRowBackground(Color.clear)
        }
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
            .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
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
