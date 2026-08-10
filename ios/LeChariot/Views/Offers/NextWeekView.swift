import SwiftUI

/// „Nächste Woche" — die Vorschau auf die Angebote der Folgewoche.
///
/// Ein eigener Bildschirm, kein Abschnitt in der Angebotsliste. Finns Fall ist
/// **„was kaufe ich heute bewusst nicht"**, und der trägt nur, solange keine
/// Zeile darin mit einem heutigen Preis verwechselt werden kann. Deshalb: eigene
/// Überschrift, eigener Ton, und auf jeder Zeile das Startdatum.
///
/// **Seit dem 2026-08-02 kann sie, was die Angebotsliste kann** — Suche, Filter,
/// Sortierung, Markt-Leiste. Scotts Meldung aus Build `2026.0801.1951`: Der
/// Bildschirm soll sich anfühlen wie die normale Liste. Die Bauteile sind
/// dieselben (`OfferBrowser`, `MarketChipBar`, `OfferFilterMenu`,
/// `OfferEmptyResultView`), nicht Kopien davon.
///
/// **Und die Wochengrenze bleibt, wo sie war.** Der Browser hält keine
/// Angebote; er bekommt hier `store.upcomingOffers` gereicht und sonst nichts.
/// Eine Zeile der laufenden Woche kann in dieser Suche gar nicht auftauchen,
/// weil sie diesen Bildschirm nie erreicht.
///
/// Zahlen und Herleitung: [[Le Chariot Backlog]], „Finns zweiter Wunsch".
struct NextWeekView: View {
    let favoriteMarkets: [Market]
    let store: OfferStore

    var priceHistoryRepository: PriceHistoryRepositoryProtocol = AppRepositories.priceHistory

    @State private var browser = OfferBrowser()
    @State private var selectedOffer: Offer?

    /// Optional wie überall, wo eine Ansicht auch in einer Preview stehen soll —
    /// gebraucht wird er nur, um dem Rundgang zu melden, dass die Vorschau offen
    /// steht.
    @Environment(TutorialStore.self) private var tutorial: TutorialStore?

    /// Ketten, die nachweislich nichts im Voraus veröffentlichen.
    ///
    /// Gemessen am 01.08.2026 im Browser: EDEKAs Angebotsseite zeigt am Tag vor
    /// dem Wochenwechsel kein „nächste Woche", weder im Text noch in den Links.
    /// Steht hier und nicht im Backend, weil nur die App den Satz sagen muss.
    static let chainsWithoutPreview: Set<String> = ["EDEKA"]

    /// Warum zu dieser Kette nichts dasteht.
    ///
    /// **Zwei verschiedene Wahrheiten, nicht ein Sammelsatz.** „Veröffentlicht
    /// nichts im Voraus" ist ein Dauerzustand — wer ihn liest, hört auf zu
    /// warten. „Noch nichts da" geht vorbei, und wer ihn liest, schaut morgen
    /// wieder her. Ein gemeinsamer Satz für beide wäre für die eine Hälfte der
    /// Ketten gelogen.
    ///
    /// Eigene Funktion statt Ternär in der Ansicht, damit beide Zweige geprüft
    /// werden können — der Satz ist die Zusage, nicht die Deko.
    static func reason(for chain: String) -> String {
        chainsWithoutPreview.contains(chain)
            ? "\(chain) veröffentlicht seine Angebote nicht im Voraus."
            : "Für nächste Woche liegt hier noch nichts vor."
    }

    /// Die sichtbaren Zeilen — **nur** aus der Folgewoche.
    private var visible: [Offer] {
        browser.visible(in: store.upcomingOffers)
    }

    private var sections: [(key: String, offers: [Offer])] {
        OfferQuery.grouped(visible, by: browser.grouping)
    }

    /// Gewählte Ketten, zu denen die Vorschau nichts hat — mit dem Grund.
    ///
    /// Gerechnet über **alle** Zeilen der Folgewoche, nicht über die gerade
    /// sichtbaren: Eine Suche nach „Kaffee" macht aus einer Kette, die etwas
    /// hat, keine ohne Vorschau. Der Abschnitt beantwortet die Frage „warum
    /// steht mein Kaufland nicht da", und die hängt nicht am Suchfeld.
    private var chainsWithoutRows: [String] {
        Set(favoriteMarkets.map(\.chain))
            .subtracting(chainsWithRows)
            .sorted()
    }

    private var chainsWithRows: Set<String> {
        Set(store.upcomingOffers.map(\.market))
    }

    /// **Dieselben Reiter wie in den Angeboten** — Scotts Punkt 6.
    ///
    /// Bis Build `2026.0803.1440` waren es die Ketten mit **Vorschau-Zeilen**,
    /// und die Leiste erscheint erst ab zweien. In den Fixtures fällt das nicht
    /// auf; in Anklam veröffentlicht in aller Regel höchstens eine Kette im
    /// Voraus — also stand dort **gar keine** Leiste, während der Angebote-Tab
    /// eine hatte. Geteilt war das Bauteil längst; zu eng war die Bedingung,
    /// genau wie Scott vermutet hat.
    ///
    /// **Die Umkehr einer Entscheidung vom 02.08., und sie gehört benannt:**
    /// Damals bekam eine Kette ohne Vorschau-Zeilen bewusst *keinen* Chip, weil
    /// er in die Sackgasse „Nichts für diesen Filter" führte. Der Einwand war
    /// richtig — die Antwort war es nicht. Ein Reiter, der fehlt, beantwortet
    /// die Frage „wo ist mein Aldi" gar nicht; ein Reiter, der den **Grund**
    /// zeigt, beantwortet sie. Deshalb gibt es beides: den Chip und, dahinter,
    /// denselben ehrlichen Satz, der sonst unten im Abschnitt „Ohne Vorschau"
    /// steht.
    ///
    /// Die Wochengrenze rührt das nicht an: Chips sind **Namen**. Die Zeilen
    /// kommen weiter ausschließlich aus `store.upcomingOffers`.
    private var chipChains: [String] {
        Set(favoriteMarkets.map(\.chain))
            .union(chainsWithRows)
            .sorted()
    }

    /// Gefiltert auf eine Kette, die im Voraus nichts veröffentlicht.
    private var filteredChainWithoutPreview: String? {
        guard let chain = browser.market, !chainsWithRows.contains(chain) else { return nil }
        return chain
    }

    var body: some View {
        content
            .themedScreen()
            .navigationTitle("Nächste Woche")
            .navigationBarTitleDisplayMode(.inline)
            // `navigationBarDrawer(displayMode: .always)`, nicht die Vorgabe:
            // Auf einem geschobenen Bildschirm mit `.inline`-Titel klappt das
            // Suchfeld sonst ein und ist erst nach einem Zug nach unten da —
            // am Simulator gesehen, die Journeys fanden schlicht kein Feld.
            .searchable(
                text: $browser.search,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Produkt suchen"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    OfferFilterMenu(
                        grouping: $browser.grouping,
                        sort: $browser.sort,
                        category: $browser.category,
                        hasActiveFilter: browser.hasActiveFilter
                    )
                }
            }
            .onChange(of: favoriteMarkets.map(\.chain)) { _, updated in
                browser.dropMarketFilterIfGone(from: updated)
            }
            .sheet(item: $selectedOffer) { offer in
                OfferDetailView(
                    offer: offer,
                    favoriteMarkets: favoriteMarkets,
                    historyRepository: priceHistoryRepository
                )
            }
            // Der Rundgang wartet an dieser Stelle darauf, dass jemand die
            // Vorschau wirklich aufmacht — siehe `TutorialStep.Deed`. Gemeldet
            // wird immer; ob es einen Rahmen weiterschaltet, entscheidet der
            // Store.
            .onAppear { tutorial?.report(.opensNextWeek) }
    }

    @ViewBuilder
    private var content: some View {
        if store.upcomingOffers.isEmpty && chainsWithoutRows.isEmpty {
            ContentUnavailableView {
                Label("Noch keine Vorschau", systemImage: "calendar")
            } description: {
                Text("Die Ketten veröffentlichen ihre nächste Woche meist erst gegen Ende der laufenden. Schau in ein, zwei Tagen wieder her.")
            }
            .accessibilityIdentifier("nextWeek.empty")
        } else {
            VStack(spacing: 0) {
                MarketChipBar(
                    chains: chipChains,
                    selection: $browser.market,
                    identifier: "nextWeek.marketChips"
                )
                list
            }
        }
    }

    private var list: some View {
        List {
            explainer
            if let chain = filteredChainWithoutPreview {
                // **Der Grund statt der Sackgasse.** „Nichts für diesen Filter"
                // wäre hier eine Halbwahrheit: Es liegt nicht am Filter,
                // sondern daran, dass diese Kette im Voraus nichts
                // veröffentlicht — derselbe Satz, der unten im Abschnitt „Ohne
                // Vorschau" steht, nur an der Stelle, an der die Frage gerade
                // gestellt wird.
                noPreviewForChain(chain)
            } else if visible.isEmpty {
                OfferEmptyResultView(
                    browser: browser,
                    scope: .upcoming,
                    onResetFilters: { browser.resetFilters() },
                    onClearMarket: { browser.market = nil }
                )
                // Siehe `OffersView.offerList` — derselbe weiße Kasten, und er
                // gehört auf beiden Bildschirmen weg, sonst sähe die Vorschau
                // an derselben Stelle anders aus als die laufende Woche.
                .listRowBackground(Color.clear)
            } else {
                ForEach(sections, id: \.key) { section in
                    Section(sectionTitle(section.key)) {
                        ForEach(section.offers) { offer in
                            Button { selectedOffer = offer } label: {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                    OfferRowView(offer: offer)
                                    startsLabel(offer)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(voiceOver(offer))
                            .accessibilityIdentifier("nextWeek.row")
                        }
                        .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
                    }
                }
            }
            // **Auch unter Filter.** In der laufenden Woche steht die Fußnote
            // der leeren Filialen nur ohne Suche und Filter — dort ist sie eine
            // Randnotiz. Hier ist sie die Antwort auf „wo ist mein Kaufland",
            // und die wird nicht falsch, weil jemand ins Suchfeld getippt hat.
            // Wer nach „Kaffee" sucht und nichts findet, hat Anspruch darauf zu
            // erfahren, dass drei seiner Ketten überhaupt nichts geliefert
            // haben — sonst hält er die Vorschau für kaputt.
            if !chainsWithoutRows.isEmpty { withoutPreviewSection }
        }
        .refreshable { await store.refresh() }
        .accessibilityIdentifier("nextWeek.list")
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

    /// Abschnittstitel wie in der laufenden Woche: Bei einer einzigen gewählten
    /// Filiale einer Kette steht ihr Name statt der Kette.
    private func sectionTitle(_ key: String) -> String {
        guard browser.grouping == .market else { return key }
        return Market.displayTitle(chain: key, favorites: favoriteMarkets)
    }

    /// Sagt in einem Satz, was der Bildschirm ist — und was er nicht ist.
    ///
    /// **Fett in grauer Fußnote trug die Unterscheidung nicht** (Scott,
    /// 08.08.). Bis dahin stand hier ein `.footnote` in `secondaryText` mit
    /// `**noch nicht**` darin — und Fett ist genau die Auszeichnung, die
    /// verschwindet, sobald die Schrift klein und die Farbe zurückgenommen
    /// ist. Der ganze Bildschirm hängt an diesem einen Wort: Diese Preise
    /// gelten **noch nicht**.
    ///
    /// Jetzt trägt es dasselbe Gewand wie das Veraltet-Banner in der laufenden
    /// Woche — Warnfarbe, getönte Zeile, Zeichen davor. Das ist ein bestehendes,
    /// gemessenes Muster und keine neue Erfindung.
    ///
    /// **Beide Zeilen stehen in `warning`, und das ist gemessen, nicht
    /// gewählt:** `secondaryText` auf der getönten Zeile erreicht im hellen
    /// Modus nur **3,71:1** und wäre dort schlechter lesbar als vorher.
    /// `warning` misst dort 4,95:1 und im dunklen 7,36:1
    /// (`PaletteContrastTests.testTheNextWeekNoticeIsReadableOnItsTint`).
    private var explainer: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.subheadline)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    // Der Satz steht ohne `**` — die Auszeichnung sitzt jetzt in
                    // Farbe, Gewicht und Größe, nicht im Markdown.
                    Text("Diese Preise gelten noch nicht.")
                        .font(.subheadline.weight(.semibold))
                        // Die Kennung bleibt auf einem `Text`: Die Rundgänge
                        // suchen sie als `staticTexts`, und ein zusammengefasstes
                        // Element wäre dort keins mehr.
                        .accessibilityIdentifier("nextWeek.explainer")
                    Text("Sie zeigen, was demnächst günstig wird — damit du es heute stehen lassen kannst.")
                        .font(.footnote)
                }
            }
            .foregroundStyle(Theme.warning)
            // Der Anker der Schlusskarte des Rundgangs. Auf der Zeile, nicht auf
            // dem Abschnitt: Ein `Section` meldet auch seine Ränder mit, und das
            // Loch stünde dann um eine Listeneinrückung zu weit außen.
            .tutorialAnchor(.nextWeekNotice)
            .listRowBackground(Theme.warningSurface)
        }
    }

    private func startsLabel(_ offer: Offer) -> some View {
        Text("ab \(DateFormatter.offerDay.string(from: offer.validFrom))")
            .font(.caption.weight(.medium))
            // `brandSecondary`, nicht `accent`: Der Akzent misst über der Creme
            // 1,01:1 und wäre als Text nicht zu sehen — dieselbe Falle wie beim
            // Rundgang-Ring am 31.07.
            .foregroundStyle(Theme.brandSecondary)
    }

    /// „gilt ab" statt „gültig bis": Für eine künftige Zeile ist der Anfang die
    /// Nachricht, nicht das Ende.
    private func voiceOver(_ offer: Offer) -> String {
        var parts: [String] = [offer.product]
        if let price = offer.price {
            parts.append(price.formatted(.currency(code: "EUR")))
        }
        parts.append("bei \(offer.market)")
        parts.append("gilt ab \(DateFormatter.offerDayLong.string(from: offer.validFrom))")
        return parts.joined(separator: ", ")
    }

    /// Der Reiter steht, die Kette hat nichts — und hier steht, warum.
    private func noPreviewForChain(_ chain: String) -> some View {
        ContentUnavailableView {
            Label("Nichts von \(chain)", systemImage: "calendar")
        } description: {
            Text(Self.reason(for: chain))
        } actions: {
            Button("Alle Märkte zeigen") { browser.market = nil }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Theme.onAccent)
        }
        .listRowBackground(Theme.background)
        .accessibilityIdentifier("nextWeek.chainWithoutPreview")
    }

    /// Der Grund je Kette — siehe `reason(for:)`.
    private var withoutPreviewSection: some View {
        Section {
            ForEach(chainsWithoutRows, id: \.self) { chain in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(chain).font(.subheadline.weight(.medium))
                    Text(Self.reason(for: chain))
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Theme.stroke)
        } header: {
            Text("Ohne Vorschau")
        }
        .accessibilityIdentifier("nextWeek.withoutPreview")
    }
}
