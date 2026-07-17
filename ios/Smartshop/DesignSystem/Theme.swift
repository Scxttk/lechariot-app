import SwiftUI

/// Design tokens shared by all tabs. One accent, one radius system, one
/// spacing scale — deviations are bugs, not taste.
enum Theme {
    // MARK: Spacing (4-pt grid)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Radii
    // Rule: cards/tiles 16, nested surfaces 10 (16 − 6 padding), badges capsule.

    enum Radius {
        static let card: CGFloat = 16
        static let inner: CGFloat = 10
    }

    // MARK: Colors

    /// Single brand accent: calibrated market green. Red stays reserved for
    /// discount semantics, yellow for favorites — never as decoration.
    static let accent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.78, blue: 0.47, alpha: 1)
            : UIColor(red: 0.09, green: 0.51, blue: 0.27, alpha: 1)
    })

    /// Discount badge background (semantic, not decorative).
    static let discount = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.92, green: 0.28, blue: 0.25, alpha: 1)
            : UIColor(red: 0.80, green: 0.16, blue: 0.14, alpha: 1)
    })

    /// Elevated surface for tiles/cards on the grouped background.
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
}

// MARK: - Discount badge

/// "-23 %" capsule. Single source of truth — used in offer rows, shopping
/// list suggestions and the top-deals list.
struct DiscountBadge: View {
    let percent: Int

    var body: some View {
        Text("-\(percent) %")
            .font(.caption.bold().monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.discount, in: Capsule())
            .foregroundStyle(.white)
    }
}

// MARK: - Price text

/// Price label with tabular digits so columns of prices align optically.
struct PriceText: View {
    let amount: Double
    var emphasized = true

    var body: some View {
        Text(amount, format: .currency(code: "EUR"))
            .font(emphasized ? .body.bold().monospacedDigit() : .caption.monospacedDigit())
    }
}

// MARK: - Stat tile

/// Compact key-figure tile for the Analyse tab.
struct StatTile: View {
    let title: String
    let value: String
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

// MARK: - Card container

extension View {
    /// Standard elevated card on the grouped background.
    func themeCard() -> some View {
        padding(Theme.Spacing.lg)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

#Preview("Bausteine") {
    VStack(spacing: Theme.Spacing.lg) {
        HStack(spacing: Theme.Spacing.md) {
            StatTile(title: "Angebote", value: "312", footnote: "diese Woche")
            StatTile(title: "Ø Rabatt", value: "27 %", footnote: "über alle Märkte")
        }
        HStack {
            DiscountBadge(percent: 33)
            PriceText(amount: 1.99)
            PriceText(amount: 2.49, emphasized: false)
        }
        .themeCard()
    }
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
