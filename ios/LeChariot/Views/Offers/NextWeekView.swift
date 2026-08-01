import SwiftUI

/// „Nächste Woche" — die Vorschau auf die Angebote der Folgewoche.
///
/// Ein eigener Bildschirm, kein Abschnitt in der Angebotsliste. Finns Fall ist
/// **„was kaufe ich heute bewusst nicht"**, und der trägt nur, solange keine
/// Zeile darin mit einem heutigen Preis verwechselt werden kann. Deshalb: eigene
/// Überschrift, eigener Ton, und auf jeder Zeile das Startdatum.
///
/// Zahlen und Herleitung: [[Le Chariot Backlog]], „Finns zweiter Wunsch".
struct NextWeekView: View {
    let favoriteMarkets: [Market]
    let store: OfferStore

    var priceHistoryRepository: PriceHistoryRepositoryProtocol = AppRepositories.priceHistory

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

    private var sections: [(key: String, offers: [Offer])] {
        OfferQuery.grouped(store.upcomingOffers, by: .market)
    }

    /// Gewählte Ketten, zu denen die Vorschau nichts hat — mit dem Grund.
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
            List {
                explainer
                ForEach(sections, id: \.key) { section in
                    Section(section.key) {
                        ForEach(section.offers) { offer in
                            Button { selectedOffer = offer } label: {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                    OfferRowView(offer: offer)
                                    startsLabel(offer)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(voiceOver(offer))
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
                if !chainsWithoutRows.isEmpty { withoutPreviewSection }
            }
            .refreshable { await store.refresh() }
            .accessibilityIdentifier("nextWeek.list")
        }
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
