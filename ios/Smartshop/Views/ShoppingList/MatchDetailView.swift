import SwiftUI

/// Sheet listing every offer matched for one list item — direct hits and
/// category hits labeled — with per-offer rejection. Rejections persist via
/// MatchRejectionStore and expire with the offer week.
struct MatchDetailView: View {
    let item: ShoppingItem
    let offers: [Offer]

    @Environment(MatchRejectionStore.self) private var rejections
    @Environment(\.dismiss) private var dismiss

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
                        Text("Passt ein Treffer nicht, lehne ihn mit ✕ ab — er wird dann nicht mehr vorgeschlagen.")
                    }
                    .listRowBackground(Theme.surface)
                }

                if !rejected.isEmpty {
                    Section("Abgelehnt") {
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
        }
    }

    private func matchRow(_ match: OfferMatch, isRejected: Bool) -> some View {
        let offer = match.offer
        return HStack(spacing: Theme.Spacing.sm) {
            OfferThumbnail(imageUrl: offer.imageUrl, emoji: offer.emoji, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(offer.product)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: Theme.Spacing.xs) {
                    MatchKindBadge(kind: match.kind)
                    Text(offer.market)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            if let price = offer.price {
                PriceText(amount: price)
            }
            Button {
                withAnimation {
                    if isRejected {
                        rejections.unreject(itemText: item.text, offer: offer)
                    } else {
                        rejections.reject(itemText: item.text, offer: offer)
                    }
                }
            } label: {
                Image(systemName: isRejected ? "arrow.uturn.backward.circle" : "xmark.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRejected ? "Ablehnung zurücknehmen" : "Treffer ablehnen")
        }
        .opacity(isRejected ? 0.5 : 1)
    }
}

#Preview {
    MatchDetailView(item: ShoppingItem(text: "Milch"), offers: MockFixtures.offers)
        .environment(MatchRejectionStore())
}
