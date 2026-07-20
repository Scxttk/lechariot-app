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

    /// Brand palette: green + brown, green leads in BOTH appearances.
    /// Light mode: #3F6444 on cream #EDE9C0. Dark mode mirrors that look —
    /// brightened green on deep green-olive; brown is demoted to secondary
    /// there (brown surfaces on olive clashed).
    ///
    /// Every color below is measured against the surface it actually sits on,
    /// WCAG 2.1: text ≥ 4.5:1, graphics ≥ 3:1. Adding a raw SwiftUI color
    /// (`.red`, `.orange`, `.yellow`) in a view skips that check — use a token.
    ///
    /// Light accent was #507C55, which reached only 3.85:1 on the cream
    /// background and 3.63:1 as pill text on its own 15 % tint. Same hue, one
    /// step deeper: 5.43:1 on cream, 6.12:1 on surface, 6.74:1 for white text
    /// on top of it, 4.95:1 on the tint.
    static let accent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            // The light green lacks contrast on the dark surfaces; same hue, lifted.
            ? UIColor(red: 0.56, green: 0.74, blue: 0.58, alpha: 1)   // ~#8FBD94
            : UIColor(red: 0.247, green: 0.392, blue: 0.267, alpha: 1) // #3F6444
    })

    /// Non-dominant brand color (brown) in both appearances — warm tan in
    /// dark, deep brown in light. For secondary highlights only, never controls.
    static let brandSecondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.76, green: 0.60, blue: 0.44, alpha: 1)   // warm tan
            : UIColor(red: 0.28, green: 0.17, blue: 0.11, alpha: 1)   // #472C1B
    })

    /// Screen background behind lists and scroll views. Dark mode is a deep,
    /// desaturated green-olive — dark counterpart to the cream, not a hue swap.
    static let background = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.12, blue: 0.08, alpha: 1)   // ~#1A1F15
            : UIColor(red: 0.93, green: 0.91, blue: 0.75, alpha: 1)   // #EDE9C0
    })

    /// Discount badge background (semantic, not decorative). Both variants
    /// keep white caption text above the WCAG-AA 4.5:1 contrast ratio.
    static let discount = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.82, green: 0.22, blue: 0.20, alpha: 1)
            : UIColor(red: 0.80, green: 0.16, blue: 0.14, alpha: 1)
    })

    /// Hairline stroke separating cards from the background — warm neutral
    /// so it reads as an edge, not as a colored border.
    static let stroke = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(red: 0.28, green: 0.17, blue: 0.11, alpha: 0.10)
    })

    /// Elevated surface for tiles/cards/list rows on `background` — same
    /// hue family as the background, one step lifted, in both appearances.
    static let surface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.18, blue: 0.13, alpha: 1)   // lifted olive
            : UIColor(red: 0.97, green: 0.96, blue: 0.88, alpha: 1)   // lifted #EDE9C0
    })

    // MARK: Status colors
    //
    // System `.orange` / `.red` / `.green` are tuned for white and black
    // backgrounds, not for cream and olive: `.orange` on its own 12 % tint over
    // the cream reached 1.65:1, `.red` on the light surface 3.22:1. These
    // replacements are measured against `surface` and `warningSurface`.

    /// Warnings that are not errors — stale offers, "data may be outdated".
    /// 7.52:1 on surface, 5.39:1 on `warningSurface`.
    static let warning = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.72, blue: 0.35, alpha: 1)    // #FFB859
            : UIColor(red: 0.478, green: 0.247, blue: 0.0, alpha: 1)  // #7A3F00
    })

    /// Tinted row background behind `warning` text. Kept here rather than as an
    /// opacity in the view so the pair stays measured together.
    static let warningSurface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.72, blue: 0.35, alpha: 0.16)
            : UIColor(red: 0.478, green: 0.247, blue: 0.0, alpha: 0.14)
    })

    /// Failure states — sync errors, invalid input. 7.17:1 light / 5.25:1 dark
    /// on surface. Distinct from `discount`, which is a price semantic.
    static let error = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.45, blue: 0.42, alpha: 1)    // #FF736B
            : UIColor(red: 0.639, green: 0.078, blue: 0.059, alpha: 1) // #A3140F
    })

    /// Confirmations — markets found during the region sync. A deeper green
    /// than the accent so "done" never reads as "tappable". 5.76:1 / 7.48:1.
    static let success = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.56, green: 0.80, blue: 0.60, alpha: 1)
            : UIColor(red: 0.20, green: 0.42, blue: 0.24, alpha: 1)
    })
}

// MARK: - Appearance override

/// User-selected appearance (Einstellungen → Darstellung), persisted via
/// AppStorage under `Theme.appearanceKey`.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Hell"
        case .dark: "Dunkel"
        }
    }

    /// The choice as UIKit expresses it; `.unspecified` follows the system.
    /// The override is applied to the `UIWindow`
    /// rather than through `preferredColorScheme`, so navigation bar, tab bar
    /// and list backgrounds change in the same step as the content —
    /// see `AppearanceWindowBridge`.
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

extension Theme {
    static let appearanceKey = "appAppearance"
}

// MARK: - Themed screen background

extension View {
    /// Replaces the default grouped background of a List/ScrollView screen
    /// with the brand background (cream / dark olive), and keeps the content
    /// itself to a readable column — see `readableWidth()`.
    func themedScreen() -> some View {
        scrollContentBackground(.hidden)
            .readableWidth()
            .background(Theme.background)
    }
}

// MARK: - Reading width

extension Theme {
    /// Widest a column of text or form controls may get.
    ///
    /// Every screen here was drawn for a hand's width. On an iPad the same
    /// layout stretches a sentence across 1000 pt and turns "Los geht's" into a
    /// button the width of the display — legible, but nothing a person wants to
    /// read or aim at. 640 pt keeps line length near the usual 60–75 characters
    /// and leaves buttons a plausible size; on any iPhone it never applies.
    static let maxContentWidth: CGFloat = 640
}

extension View {
    /// Caps the content at `Theme.maxContentWidth` and centres it. No effect
    /// where the screen is narrower than that, i.e. on every iPhone.
    func readableWidth() -> some View {
        frame(maxWidth: Theme.maxContentWidth)
            .frame(maxWidth: .infinity)
    }
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
            .accessibilityLabel("\(percent) Prozent reduziert")
    }
}

// MARK: - Offer thumbnail

/// Product image for an offer, emoji as fallback. Single source of truth —
/// used in offer rows (Angebote, Top-Deals) and shopping-list suggestions.
/// Loads via AsyncImage/URLCache; the emoji tile shows while loading, on
/// failure, and when the offer has no image URL.
struct OfferThumbnail: View {
    let imageUrl: String?
    let emoji: String?
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            // Screen background as the fallback tile: stays in the brand
            // palette instead of dropping a system gray onto the cream.
            RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                .fill(Theme.background)
            Text(emoji ?? "🛒")
                .font(.system(size: size * 0.5))
            if let url = imageUrl.flatMap(URL.init(string:)) {
                // Fade the loaded image in over the emoji tile instead of popping.
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous))
        // Inset hairline so photo edges don't blur into the surface —
        // neutral alpha, never brand-tinted.
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .accessibilityHidden(true)
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

// MARK: - Card container

extension View {
    /// Standard elevated card on the grouped background: surface fill,
    /// hairline edge, and a soft two-layer shadow. The shadow is nearly
    /// invisible in dark mode — there the stroke does the separating.
    func themeCard() -> some View {
        padding(Theme.Spacing.lg)
            .cardSurface()
    }

    /// Surface + edge + shadow without the padding, for tiles that manage
    /// their own insets.
    fileprivate func cardSurface() -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.stroke)
            )
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
    }
}

// MARK: - Tactile button style

/// Press feedback for tappable tiles and icon buttons: slight scale-down and
/// dim, interruptible ease-out. Plain buttons otherwise give no feedback at all.
struct TactileButtonStyle: ButtonStyle {
    // Custom styles bypass the system's automatic disabled dimming.
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Skeleton fixtures

extension Offer {
    /// Fixed-shape placeholder rows for redacted loading states, so the
    /// skeleton matches the final list layout instead of a bare spinner.
    static let skeleton: [Offer] = (0..<6).map { index in
        Offer(
            market: "Markt",
            product: "Produktname Platzhalter",
            price: 1.99,
            regularPrice: 2.99,
            unit: "500 g Packung",
            category: "Sonstiges",
            emoji: "🛒",
            validFrom: .now,
            validUntil: .now,
            basePrice: nil,
            baseUnit: nil,
            region: "0000\(index)"
        )
    }
}

#Preview("Bausteine") {
    VStack(spacing: Theme.Spacing.lg) {
        HStack {
            DiscountBadge(percent: 33)
            PriceText(amount: 1.99)
            PriceText(amount: 2.49, emphasized: false)
        }
        .themeCard()

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Angebote sind möglicherweise veraltet", systemImage: "exclamationmark.triangle")
                .foregroundStyle(Theme.warning)
            Label("Synchronisierung fehlgeschlagen", systemImage: "xmark.octagon")
                .foregroundStyle(Theme.error)
            Label("Kaufland Strehlen gefunden", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.success)
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
    }
    .padding()
    .background(Theme.background)
}
