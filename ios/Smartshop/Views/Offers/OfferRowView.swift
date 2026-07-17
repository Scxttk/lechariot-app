import SwiftUI

struct OfferRowView: View {
    let offer: Offer

    @Environment(\.dynamicTypeSize) private var typeSize

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d.M."
        return formatter
    }()

    var body: some View {
        // At accessibility sizes the trailing price column no longer fits next
        // to the product text; stack everything vertically instead of truncating.
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.md) {
                        OfferThumbnail(imageUrl: offer.imageUrl, emoji: offer.emoji)
                        productInfo
                    }
                    priceInfo(alignment: .leading)
                }
            } else {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    OfferThumbnail(imageUrl: offer.imageUrl, emoji: offer.emoji)
                    productInfo
                    Spacer()
                    priceInfo(alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var productInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(offer.product)
                .font(.body.weight(.medium))
            if let unit = offer.unit {
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let basePrice = offer.basePrice, let baseUnit = offer.baseUnit {
                Text("\(basePrice, format: .currency(code: "EUR")) / \(baseUnit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(validityText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
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
                Text(regular, format: .currency(code: "EUR"))
                    .font(.caption.monospacedDigit())
                    .strikethrough()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var validityText: String {
        let from = Self.day.string(from: offer.validFrom)
        let until = Self.day.string(from: offer.validUntil)
        return "Gültig \(from) – \(until)"
    }

    /// One sensible VoiceOver utterance: product, price, discount, regular
    /// price, market and validity instead of a scatter of fragments.
    private var accessibilitySummary: String {
        var parts: [String] = [offer.product]
        if let unit = offer.unit { parts.append(unit) }
        if let price = offer.price {
            parts.append(price.formatted(.currency(code: "EUR")))
        }
        if let discount = offer.discountPercent {
            parts.append("\(discount) Prozent reduziert")
        }
        if let regular = offer.regularPrice {
            parts.append("statt \(regular.formatted(.currency(code: "EUR")))")
        }
        parts.append("bei \(offer.market)")
        parts.append("gültig bis \(Self.day.string(from: offer.validUntil))")
        return parts.joined(separator: ", ")
    }
}

#Preview {
    List(MockFixtures.offers) { OfferRowView(offer: $0) }
}
