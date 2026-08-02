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
        let covered = Set(store.upcomingOffers.map(\.market))
        return Set(favoriteMarkets.map(\.chain))
            .subtracting(covered)
            .sorted()
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
                    chains: browser.chipChains(in: store.upcomingOffers),
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
            if visible.isEmpty {
                OfferEmptyResultView(
                    browser: browser,
                    scope: .upcoming,
                    onResetFilters: { browser.resetFilters() },
                    onClearMarket: { browser.market = nil }
                )
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
                        .listRowBackground(Theme.surface)
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
    }

    /// Abschnittstitel wie in der laufenden Woche: Bei einer einzigen gewählten
    /// Filiale einer Kette steht ihr Name statt der Kette.
    private func sectionTitle(_ key: String) -> String {
        guard browser.grouping == .market else { return key }
        return Market.displayTitle(chain: key, favorites: favoriteMarkets)
    }

    /// Sagt in einem Satz, was der Bildschirm ist — und was er nicht ist.
    private var explainer: some View {
        Section {
            Text("Diese Preise gelten **noch nicht**. Sie zeigen, was demnächst günstig wird — damit du es heute stehen lassen kannst.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .listRowBackground(Theme.background)
                .accessibilityIdentifier("nextWeek.explainer")
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
            .listRowBackground(Theme.surface)
        } header: {
            Text("Ohne Vorschau")
        }
        .accessibilityIdentifier("nextWeek.withoutPreview")
    }
}
