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

    /// Markenpalette: Grün führt in beiden Erscheinungsbildern.
    ///
    /// Jede Farbe ist gegen die Fläche gemessen, auf der sie sitzt (WCAG 2.1:
    /// Text ≥ 4,5:1, Grafik ≥ 3:1). Eine rohe SwiftUI-Farbe in einer Ansicht
    /// überspringt diese Prüfung — deshalb Tokens.
    /// Messwerte: [[Le Chariot Entscheidungen]], „Palette und Kontrast".
    static let accent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            // The light green lacks contrast on the dark surfaces; same hue, lifted.
            ? UIColor(red: 0.56, green: 0.74, blue: 0.58, alpha: 1)   // ~#8FBD94
            : UIColor(red: 0.247, green: 0.392, blue: 0.267, alpha: 1) // #3F6444
    })

    /// Beschriftung **auf** einer Akzentfläche (gefüllte Knöpfe).
    ///
    /// `.borderedProminent` setzt seine Schrift automatisch auf Weiß. Im hellen
    /// Modus stimmt das (6,74:1 auf `#3F6444`), im dunklen nicht: dort ist der
    /// Akzent das aufgehellte `#8FBD94`, und Weiß darauf erreicht **2,13:1** —
    /// am echten Gerät nachgemessen, auf dem Hauptknopf jedes
    /// Onboarding-Schritts. Auf dem hellen Grün gehört das dunkle Olivgrün.
    static let onAccent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.12, blue: 0.08, alpha: 1)   // ~#1A1F15, 7,9:1
            : .white
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

    /// Sekundärtext. Ersetzt Apples `.secondary`, das auf Creme nur 3,15:1
    /// erreichte — es ist für Weiß und Schwarz abgestimmt, nicht für Creme und
    /// Olive. Warm statt grau: Ein neutrales Grau wirkt auf Creme schmutzig.
    /// Messwerte: [[Le Chariot Entscheidungen]], „Palette und Kontrast".
    static let secondaryText = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.72, green: 0.72, blue: 0.64, alpha: 1)
            : UIColor(red: 0.42, green: 0.36, blue: 0.28, alpha: 1)
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

    /// Linien **auf** der Abdunklung des Rundgangs — in beiden
    /// Erscheinungsbildern dieselbe Farbe, weil die Abdunklung dieselbe ist.
    /// Der Akzent erreicht dort nur 1,01:1 und wäre unsichtbar.
    /// Herleitung: [[Le Chariot Entscheidungen]], „Palette und Kontrast".
    static let onScrim = Color(red: 0.86, green: 0.93, blue: 0.87) // #DBEDDE
}

// MARK: - Motion

extension Theme {
    /// **Wie ein Zustand den anderen ablöst — die eine Regel der App.**
    ///
    /// Zwei Hälften, die zusammengehören: der *Übergang* sitzt an der Ansicht,
    /// die kommt oder geht (`stateTransition`), die *Kurve* am gemeinsamen
    /// Behälter (`stateAnimation`) oder an der Transaktion, die den Zustand
    /// umsetzt. Wer nur eine Hälfte setzt, bekommt den gemeldeten Fehler
    /// zurück: eine Seite bewegt sich, die andere springt.
    /// Die drei Meldungen dahinter: [[Le Chariot Entscheidungen]], „Bewegung".
    enum Motion: CaseIterable {
        /// Ein ganzer Bildschirm löst einen anderen ab.
        case screen
        /// Ein Element erscheint oder verschwindet an seinem Platz.
        case element

        /// Sekunden. Ein Bildschirm darf etwas länger brauchen als eine Zeile;
        /// beide bleiben unter der Dauer, ab der ein Übergang sich wie Warten
        /// anfühlt.
        var duration: Double {
            switch self {
            case .screen: 0.3
            case .element: 0.22
            }
        }

        /// Dieselbe Familie für beide — `.snappy`, wie sie der Rundgang seit
        /// [#21](https://github.com/Scxttk/lechariot-app/pull/21) schon nutzt.
        /// Zwei Kurven für zwei Größenordnungen wären zwei Regeln.
        var animation: Animation { .snappy(duration: duration) }

        /// Nichts fliegt, wenn der Nutzer Bewegung abgestellt hat. `nil` heißt
        /// bei SwiftUI „sofort", nicht „Vorgabe" — der Wechsel findet also
        /// statt, nur ohne Weg dorthin.
        func animation(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : animation
        }

        /// Der neue Bildschirm blendet **ein**, der alte ist sofort weg.
        ///
        /// Kein Überblenden: Zwei Ansichten auf demselben Platz hießen, dass
        /// der abgelöste Bildschirm 0,3 s lang bedienbar und im
        /// Barrierefreiheits-Baum bleibt. Der Audit fand so zwei Knöpfe
        /// `onboarding.skip` und tippte den gehenden.
        /// Siehe [[Le Chariot Entscheidungen]], „Bewegung".
        var transition: AnyTransition {
            .asymmetric(insertion: .opacity, removal: .identity)
        }
    }
}

extension View {
    /// Der Übergang **dieser** Ansicht, wenn sie kommt oder geht. Gehört an
    /// die Ansicht selbst, nicht an die Stelle, die den Zustand umsetzt.
    func stateTransition(_ motion: Theme.Motion) -> some View {
        transition(motion.transition)
    }

    /// Die Kurve, mit der der Wechsel von `value` läuft. Gehört auf den
    /// gemeinsamen Behälter der Ansichten, die einander ablösen — von dort
    /// erreicht sie beide Seiten des Wechsels, auch die, die verschwindet.
    func stateAnimation<V: Equatable>(_ motion: Theme.Motion, value: V) -> some View {
        modifier(StateAnimationModifier(motion: motion, value: value))
    }
}

/// Trägt `accessibilityReduceMotion` an die Regel heran — als
/// `@Environment` braucht das eine Ansicht, eine freie Funktion sieht es nicht.
private struct StateAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let motion: Theme.Motion
    let value: V

    func body(content: Content) -> some View {
        content.animation(motion.animation(reduceMotion: reduceMotion), value: value)
    }
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
    /// Markenhintergrund statt der grauen Systemfläche, Inhalt in einer
    /// lesbaren Spalte (siehe `readableWidth()`).
    ///
    /// **Der Hintergrund ignoriert die sicheren Bereiche, der Inhalt nicht.**
    /// Sonst scheint an den unteren Displayecken neben der durchscheinenden
    /// Tastatur das schwarze Fenster durch — die schwarzen Ecken vom 31.07.
    /// Siehe [[Le Chariot Entscheidungen]], „Schwarze Ecken".
    func themedScreen() -> some View {
        scrollContentBackground(.hidden)
            .readableWidth()
            .background { Theme.background.ignoresSafeArea() }
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
    /// Kategorie und Produktname speisen den Rückfall — siehe
    /// `OfferImageContent.fallback(category:emoji:title:)`.
    var category: String? = nil
    var title: String? = nil
    var size: CGFloat = 48

    var body: some View {
        OfferImageContent(
            imageUrl: imageUrl,
            emoji: emoji,
            emojiSize: size * 0.5,
            contentMode: .fill,
            category: category,
            title: title
        )
        .frame(width: size, height: size)
        // Screen background as the tile: stays in the brand palette instead of
        // dropping a system gray onto the cream. Carries a cut-out product
        // photo too, now that the emoji no longer sits behind it.
        .background(
            Theme.background,
            in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
        )
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

/// Large product image for the offer detail sheet. Same fallback rules as
/// `OfferThumbnail`, but fits instead of fills: cropping a cut-out product
/// photo to a square loses the product.
struct OfferHeroImage: View {
    let imageUrl: String?
    let emoji: String?
    var category: String? = nil
    var title: String? = nil
    var height: CGFloat = 200

    var body: some View {
        OfferImageContent(
            imageUrl: imageUrl,
            emoji: emoji,
            emojiSize: height * 0.4,
            contentMode: .fit,
            category: category,
            title: title
        )
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        // Surface, not background: on the detail sheet this is a card among
        // cards, and on the cream page a background-colored tile would be
        // invisible apart from its stroke.
        .background(
            Theme.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.stroke)
        )
        // The header right below repeats product, price and market — an image
        // description here would only make VoiceOver say everything twice.
        .accessibilityHidden(true)
    }
}

/// Image-or-emoji, shared by `OfferThumbnail` and `OfferHeroImage`.
///
/// The emoji is a *fallback*, not a backdrop. It used to be a permanent ZStack
/// layer underneath the AsyncImage, which stayed invisible only as long as
/// every chain shipped JPEGs. REWE mirrors PNG→WebP (alpha preserved, on
/// purpose) and Netto delivers WebP cut-outs — through both, a 🥛 shone
/// straight through the product.
struct OfferImageContent: View {
    let imageUrl: String?
    let emoji: String?
    let emojiSize: CGFloat
    let contentMode: ContentMode
    /// Beide mit Vorgabe `nil`: Die Vorschauen und ältere Aufrufstellen
    /// bringen sie nicht mit, und ohne sie greift schlicht die nächste Stufe
    /// des Rückfalls.
    var category: String? = nil
    var title: String? = nil

    /// Womit die Kachel gefüllt wird, wenn kein Foto da ist: gezeichnetes
    /// Kategoriezeichen, sonst Import-Emoji, sonst Anfangsbuchstabe, sonst
    /// Einkaufswagen. Der Buchstabe ist gestaltet, keine Notlösung.
    enum Fallback: Equatable {
        case glyph(String)
        case emoji(String)
        case initial(String)
        case cart
    }

    static func fallback(category: String?, emoji: String?, title: String?) -> Fallback {
        if let category, Categories.hasSymbol(category) {
            return .glyph(category)
        }
        // Das Emoji des Imports ist ab jetzt die **zweite** Reserve, nicht die
        // erste: Es trägt ein Produkt genauer als eine Warengruppe, aber eine
        // Liste voll davon liest sich als Spielerei (Lidl, 2026-07-30).
        if let emoji, !emoji.isEmpty { return .emoji(emoji) }
        if let first = title?.trimmingCharacters(in: .whitespaces).first,
           first.isLetter || first.isNumber {
            return .initial(String(first).uppercased())
        }
        return .cart
    }

    /// Was auf der Kachel liegt — **entweder** das Foto **oder** der
    /// Rückfall, nie beides. Eigener Typ statt eines `switch` im `body`, weil
    /// ein Test die Kachel nicht ansehen kann, diese Entscheidung schon
    /// (Emoji schien durch freigestellte WebP, 24.07.).
    enum Layer: Equatable {
        case photo
        case fallback
    }

    static func layer(for phase: AsyncImagePhase) -> Layer {
        if case .success = phase { return .photo }
        // Laden und Fehlschlag zeigen beide das Emoji.
        return .fallback
    }

    /// Das geladene Bild. Beim ersten `body` schon gesetzt, wenn es im
    /// Speicher liegt — sonst blitzte bei jedem Zurückscrollen der Rückfall
    /// auf, obwohl das Foto längst da war.
    @State private var loaded: UIImage?

    var body: some View {
        if let url = imageUrl.flatMap(URL.init(string:)) {
            content(for: url)
                // `.task(id:)`, damit eine wiederverwendete Listenzeile mit
                // neuer Adresse auch wirklich neu lädt.
                .task(id: url) {
                    if let sofort = OfferImageLoader.shared.cached(url) {
                        loaded = sofort
                        return
                    }
                    loaded = nil
                    let bild = await OfferImageLoader.shared.image(for: url)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.2)) { loaded = bild }
                }
        } else {
            fallback
        }
    }

    /// **Der Wechsel Foto/Rückfall bleibt die eine Entscheidung, die ein Test
    /// ansehen kann** — siehe `Layer`. Sie hängt jetzt an `loaded` statt an
    /// `AsyncImagePhase`; die Regel ist dieselbe (laden und Fehlschlag zeigen
    /// beide den Rückfall).
    @ViewBuilder
    private func content(for url: URL) -> some View {
        if let loaded {
            Image(uiImage: loaded)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .transition(.opacity)
        } else {
            fallback
        }
    }

    /// **Beim Verschwinden wird nicht überblendet** — sonst lägen Foto und
    /// Emoji 0,2 s halbdurchsichtig übereinander, und bei freigestellten
    /// Produkten schiene das Emoji durch. Der Rückfall blendet weiter ein.
    @ViewBuilder
    private var fallback: some View {
        Group {
            switch Self.fallback(category: category, emoji: emoji, title: title) {
            case .glyph(let category):
                // Dieselbe optische Größe wie vorher das Systemzeichen: Die
                // Kachel ist auf 0,82 der Emoji-Größe eingestellt, und die
                // Zeile darf nicht springen, je nachdem was gerade greift.
                CategoryGlyphView(category: category, size: emojiSize * 0.82)
                    .foregroundStyle(Theme.accent)
            case .emoji(let text):
                Text(text).font(.system(size: emojiSize))
            case .initial(let letter):
                // Derselbe Platz wie ein Zeichen, damit die Zeile nicht
                // springt, je nachdem was gerade greift.
                Text(letter)
                    .font(.system(size: emojiSize * 0.82, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            case .cart:
                Text("🛒").font(.system(size: emojiSize))
            }
        }
        .transition(.asymmetric(insertion: .opacity, removal: .identity))
    }
}

// MARK: - Price text

/// Price label with tabular digits so columns of prices align optically.
struct PriceText: View {
    /// Type scale, independent of `emphasized` (which is about weight).
    enum Size {
        case regular
        /// The one price a screen is about — the detail sheet's headline price.
        case large
    }

    let amount: Double
    var emphasized = true
    var size: Size = .regular

    var body: some View {
        Text(amount, format: .currency(code: "EUR"))
            .font(font)
    }

    private var font: Font {
        switch (size, emphasized) {
        // .title2, not .title: at AX5 a .title price breaks the € onto its own line.
        case (.large, _): .title2.bold().monospacedDigit()
        case (.regular, true): .body.bold().monospacedDigit()
        case (.regular, false): .caption.monospacedDigit()
        }
    }
}

// MARK: - Card container

/// Where a row sits inside its section — which corners it has to round.
enum GroupedRowPosition {
    case only, first, middle, last

    /// Builds the position from an index, so callers do not repeat the
    /// off-by-one that a single-row section invites.
    init(index: Int, count: Int) {
        switch (index, count) {
        case (_, 1): self = .only
        case (0, _): self = .first
        case (count - 1, _): self = .last
        default: self = .middle
        }
    }

    var roundsTop: Bool { self == .first || self == .only }
    var roundsBottom: Bool { self == .last || self == .only }
}

extension View {
    /// Standard elevated card on the grouped background: surface fill,
    /// hairline edge, and a soft two-layer shadow. The shadow is nearly
    /// invisible in dark mode — there the stroke does the separating.
    func themeCard() -> some View {
        padding(Theme.Spacing.lg)
            .cardSurface()
    }

    /// Zeilenhintergrund, der die Rundung des Abschnitts selbst trägt.
    ///
    /// Eine flache Farbe weiß nicht, dass sie oben oder unten in einem
    /// gerundeten Abschnitt sitzt — beim Wischen zeigt die Zeile eine harte
    /// Kante im runden Rahmen (gemeldet 30.07.). Nur für Zeilen nötig, die
    /// sich bewegen können.
    func groupedRowBackground(_ position: GroupedRowPosition) -> some View {
        let radius = Theme.Radius.card
        let top = position.roundsTop ? radius : 0
        let bottom = position.roundsBottom ? radius : 0
        return listRowBackground(
            UnevenRoundedRectangle(
                topLeadingRadius: top,
                bottomLeadingRadius: bottom,
                bottomTrailingRadius: bottom,
                topTrailingRadius: top,
                style: .continuous
            )
            .fill(Theme.surface)
        )
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
            // Ohne das ist nur der gezeichnete Inhalt antippbar — bei einem
            // Icon in einem 44-pt-Rahmen also der Glyph, nicht der Rahmen.
            // Der Accessibility-Audit hat genau das am Weglegen-Knopf gemeldet;
            // dieselbe Falle wie die tote Mitte der Filialzeile in Phase 8.
            .contentShape(Rectangle())
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
            nationwide: false
        )
    }
}

#Preview("Bausteine") {
    VStack(spacing: Theme.Spacing.lg) {
        HStack {
            DiscountBadge(percent: 33)
            PriceText(amount: 1.99, size: .large)
            PriceText(amount: 1.99)
            PriceText(amount: 2.49, emphasized: false)
        }
        .themeCard()

        // Regression anchor for the transparency bug: the first tile loads a
        // cut-out with an alpha channel (REWE/Netto ship those). No emoji may
        // remain visible behind it once it has loaded — the second tile is what
        // a missing image is supposed to look like.
        HStack(spacing: Theme.Spacing.md) {
            OfferThumbnail(
                imageUrl: "https://cddubgdnasmzvcfhmrzj.supabase.co/storage/v1/object/public/offer-images/"
                    + "be7a9b49efa5913c541f1866936ac77b9fc04620335dce190d892cdb8e9f01e8.png",
                emoji: "🧀"
            )
            OfferThumbnail(imageUrl: nil, emoji: "🥛")
            OfferHeroImage(imageUrl: nil, emoji: "🍊", height: 120)
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
