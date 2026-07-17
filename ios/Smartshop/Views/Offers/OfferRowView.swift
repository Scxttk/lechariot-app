import SwiftUI

struct OfferRowView: View {
    let offer: Offer

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d.M."
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            OfferThumbnail(imageUrl: offer.imageUrl, emoji: offer.emoji)
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
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
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
        .padding(.vertical, 2)
    }

    private var validityText: String {
        let from = Self.day.string(from: offer.validFrom)
        let until = Self.day.string(from: offer.validUntil)
        return "Gültig \(from) – \(until)"
    }
}

#Preview {
    List(MockFixtures.offers) { OfferRowView(offer: $0) }
}
