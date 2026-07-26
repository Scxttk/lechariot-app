import SwiftUI

/// Sheet listing every offer matched for one list item — direct hits and
/// category hits labeled — with per-offer rejection. Rejections persist via
/// MatchRejectionStore and expire with the offer week.
struct MatchDetailView: View {
    let item: ShoppingItem
    let offers: [Offer]
    /// The chosen branches — only used to name the branch in the detail view,
    /// same rule as the offer list sections.
    var favoriteMarkets: [Market] = []
    /// Only the detail view needs it, and only after a tap.
    var priceHistoryRepository: PriceHistoryRepositoryProtocol = AppRepositories.priceHistory

    @Environment(MatchRejectionStore.self) private var rejections
    @Environment(MatchFeedbackStore.self) private var feedback
    @Environment(\.dismiss) private var dismiss

    /// The match whose rejection is currently being asked about, if any.
    @State private var askingAbout: OfferMatch?

    private var allMatches: [OfferMatch] {
        ShoppingListMatcher.matches(for: item.text, in: offers)
    }

    private var active: [OfferMatch] {
        allMatches.filter { !rejections.isRejected(itemText: item.text, offer: $0.offer) }
    }

    private var rejected: [OfferMatch] {
        allMatches.filter { rejections.isRejected(itemText: item.text, offer: $0.offer) }
    }

    var body: some View {
        NavigationStack {
            List {
                if active.isEmpty && rejected.isEmpty {
                    ContentUnavailableView(
                        "Keine Treffer",
                        systemImage: "magnifyingglass",
                        description: Text("Kein Angebot passt diese Woche zu „\(item.text)\u{201C}.")
                    )
                    .listRowBackground(Color.clear)
                }

                if !active.isEmpty {
                    Section {
                        ForEach(active) { match in
                            matchRow(match, isRejected: false)
                        }
                    } footer: {
                        Text("Passt ein Angebot nicht zu deinem Artikel? Leg es weg — dann schlägt Le Chariot es nicht mehr vor.")
                    }
                    .listRowBackground(Theme.surface)
                }

                if !rejected.isEmpty {
                    Section("Weggelegt") {
                        ForEach(rejected) { match in
                            matchRow(match, isRejected: true)
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .themedScreen()
            .navigationTitle("Treffer für „\(item.text)\u{201C}")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $askingAbout) { match in
                RejectionFeedbackSheet(itemText: item.text, match: match)
                    .environment(feedback)
            }
            // Geschoben, nicht als zweites Sheet: Das hier IST schon ein
            // Sheet, und zwei gestapelte Karten für ein Aufklappen sind eine
            // Karte zu viel. Der Zurück-Pfeil führt dorthin zurück, wo man
            // hergekommen ist — ein „Fertig" auf einem Sheet über einem Sheet
            // wäre mehrdeutig.
            .navigationDestination(for: Offer.self) { offer in
                OfferDetailView(
                    offer: offer,
                    favoriteMarkets: favoriteMarkets,
                    historyRepository: priceHistoryRepository,
                    presentation: .pushed
                )
            }
        }
    }

    private func matchRow(_ match: OfferMatch, isRejected: Bool) -> some View {
        let offer = match.offer
        return HStack(spacing: Theme.Spacing.sm) {
            // Die Zeile führt jetzt ins Detail. Vorher war sie ein reiner
            // HStack: Man sah Produkt, Markt und Preis — und kam nicht weiter.
            // Ausgerechnet hier, wo man vor dem Einkauf entscheidet, fehlte
            // Packungsgröße, Gültigkeit und Preisverlauf.
            NavigationLink(value: offer) {
                HStack(spacing: Theme.Spacing.sm) {
                    OfferThumbnail(imageUrl: offer.imageUrl, emoji: offer.emoji, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.product)
                            .font(.subheadline)
                            .lineLimit(2)
                        HStack(spacing: Theme.Spacing.xs) {
                            MatchKindBadge(kind: match.kind)
                            Text(offer.market)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    if let price = offer.price {
                        PriceText(amount: price)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(offer.voiceOverSummary)
            .accessibilityHint("Öffnet die Details zum Angebot")
            Button {
                withAnimation {
                    if isRejected {
                        rejections.unreject(itemText: item.text, offer: offer)
                    } else {
                        rejections.reject(itemText: item.text, offer: offer)
                        // The rejection is already done and persisted; the
                        // question is an optional afterthought on top of it.
                        if feedback.isAskingEnabled { askingAbout = match }
                    }
                }
            } label: {
                Image(systemName: isRejected ? "arrow.uturn.backward.circle" : "xmark.circle")
                    .font(.title3)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityLabel(isRejected ? "Wieder vorschlagen" : "Weglegen")
        }
        .opacity(isRejected ? 0.5 : 1)
    }
}

#Preview {
    MatchDetailView(item: ShoppingItem(text: "Milch"), offers: MockFixtures.offers)
        .environment(MatchRejectionStore())
        // Beide neu seit der Rückfrage: die Ablehnung liest den Schalter,
        // das Sheet die install_id. Fehlt einer, stürzt die Preview beim
        // ersten Tippen auf ✕ ab statt sie nur anders auszusehen.
        .environment(MatchFeedbackStore())
        .environment(ProfileStore())
}
