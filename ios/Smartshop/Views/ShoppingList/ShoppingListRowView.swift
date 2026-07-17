import SwiftUI

/// One shopping-list entry: check circle, item text, and (for open items with
/// a match) the cheapest current offer as a suggestion line.
struct ShoppingListRowView: View {
    let item: ShoppingItem
    let match: Offer?
    let onToggle: () -> Void

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
            .buttonStyle(.plain)
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
            HStack(spacing: Theme.Spacing.sm) {
                Text(match.emoji ?? "🛒")
                VStack(alignment: .leading, spacing: 2) {
                    Text(match.product)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(match.market)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: Theme.Spacing.sm)
                if let discount = match.discountPercent {
                    DiscountBadge(percent: discount)
                }
                if let price = match.price {
                    PriceText(amount: price)
                }
            }
            .padding(Theme.Spacing.sm)
            .background(
                Color(uiColor: .tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
            )
        } else {
            Text("Kein Angebot diese Woche")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    List {
        ShoppingListRowView(
            item: ShoppingItem(text: "Milch"),
            match: MockFixtures.offers[0],
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
