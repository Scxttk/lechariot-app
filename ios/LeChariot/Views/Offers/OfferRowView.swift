import SwiftUI

/// One offer in the Angebote list.
///
/// Deliberately carries **no** accessibility element of its own: the callers
/// wrap it in a Button and put `offer.voiceOverSummary` there. An
/// `.accessibilityElement(children: .ignore)` on a Button swallows the label
/// that follows it — the same trap that once emptied the market picker
/// (`MarketPickerView.marketRow`).
struct OfferRowView: View {
    let offer: Offer

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At accessibility sizes the trailing price column no longer fits next
        // to the product text; stack everything vertically instead of truncating.
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.md) {
                        OfferThumbnail(
                            imageUrl: offer.imageUrl, emoji: offer.emoji,
                            category: offer.category, title: offer.product,
                            framed: offer.imageUrl != nil
                        )
                        productInfo
                    }
                    priceInfo(alignment: .leading)
                }
            } else {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    OfferThumbnail(
                            imageUrl: offer.imageUrl, emoji: offer.emoji,
                            category: offer.category, title: offer.product,
                        framed: offer.imageUrl != nil
                    )
                    productInfo
                    Spacer()
                    priceInfo(alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var productInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(offer.product)
                .font(.body.weight(.medium))
            if let unit = offer.unit {
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            if let basePrice = offer.basePrice, let baseUnit = offer.baseUnit {
                Text("\(basePrice, format: .euro) / \(baseUnit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.secondaryText)
            }
            Text(offer.validityText)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func priceInfo(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            if let discount = offer.discountPercent {
                DiscountBadge(percent: discount)
            }
            if let price = offer.price {
                PriceText(amount: price)
            }
            if let regular = offer.regularPrice {
                Text(regular, format: .euro)
                    .font(.caption.monospacedDigit())
                    .strikethrough()
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

#Preview {
    List(MockFixtures.offers) { offer in
        Button {} label: { OfferRowView(offer: offer) }
            .buttonStyle(TactileButtonStyle())
            .accessibilityLabel(offer.voiceOverSummary)
    }
}
