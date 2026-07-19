import SwiftUI

/// One shopping-list entry: check circle, item text, and (for open items with
/// a match) the cheapest current offer as a suggestion line.
struct ShoppingListRowView: View {
    let item: ShoppingItem
    let match: OfferMatch?
    let onToggle: () -> Void
    /// Opens the match-detail sheet; nil hides the affordance (checked items).
    var onShowMatches: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Button(action: onToggle) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Theme.accent : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    // 44-pt hit area despite the small glyph.
                    .frame(width: 44, height: 44, alignment: .center)
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityLabel(item.isChecked ? "Als offen markieren" : "Als erledigt markieren")

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(item.text)
                    .font(.body.weight(.medium))
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)

                if !item.isChecked {
                    suggestion
                }
            }
            .padding(.vertical, Theme.Spacing.sm)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var suggestion: some View {
        if let match {
            let offer = match.offer
            Button(action: { onShowMatches?() }) {
                HStack(spacing: Theme.Spacing.sm) {
                    OfferThumbnail(imageUrl: offer.imageUrl, emoji: offer.emoji, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(offer.product)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            MatchKindBadge(kind: match.kind)
                        }
                        Text(offer.market)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    if let discount = offer.discountPercent {
                        DiscountBadge(percent: discount)
                    }
                    if let price = offer.price {
                        PriceText(amount: price)
                    }
                }
                .padding(Theme.Spacing.sm)
                // Screen background as nested fill: reads as "recessed into
                // the row" and stays in the brand palette instead of system gray.
                .background(
                    Theme.background,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                        .strokeBorder(Theme.stroke)
                )
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(suggestionSummary(match))
            .accessibilityHint("Zeigt alle passenden Angebote")
        } else {
            Text("Kein Angebot diese Woche")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    /// One VoiceOver utterance for the suggestion tile: product, price,
    /// discount and market.
    private func suggestionSummary(_ match: OfferMatch) -> String {
        let offer = match.offer
        var parts = ["Günstigstes Angebot: \(offer.product)"]
        if let price = offer.price {
            parts.append(price.formatted(.currency(code: "EUR")))
        }
        if let discount = offer.discountPercent {
            parts.append("\(discount) Prozent reduziert")
        }
        parts.append("bei \(offer.market)")
        parts.append(match.kind == .direct ? "direkter Treffer" : "Kategorie-Treffer")
        return parts.joined(separator: ", ")
    }
}

/// Small pill distinguishing exact hits from category fallback hits.
struct MatchKindBadge: View {
    let kind: MatchKind

    var body: some View {
        Text(kind == .direct ? "Direkt" : "Kategorie")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                kind == .direct ? Theme.accent.opacity(0.15) : Color.secondary.opacity(0.15),
                in: Capsule()
            )
            .foregroundStyle(kind == .direct ? Theme.accent : Color.secondary)
    }
}

#Preview {
    List {
        ShoppingListRowView(
            item: ShoppingItem(text: "Milch"),
            match: OfferMatch(offer: MockFixtures.offers[0], kind: .direct),
            onToggle: {}
        )
        ShoppingListRowView(
            item: ShoppingItem(text: "Zahnpasta"),
            match: nil,
            onToggle: {}
        )
        ShoppingListRowView(
            item: ShoppingItem(text: "Orangen", isChecked: true),
            match: nil,
            onToggle: {}
        )
    }
}
