import SwiftUI

/// Everything about one offer that does not fit into a list row: the product
/// image at a size worth looking at, the price in full, base price, validity,
/// branch — and what the product cost in the weeks before.
struct OfferDetailView: View {
    let offer: Offer
    /// Only used to name the branch when the chain has exactly one favorited
    /// one (`Market.displayTitle`) — the same rule as the list sections.
    let favoriteMarkets: [Market]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var history: PriceHistoryStore

    init(
        offer: Offer,
        favoriteMarkets: [Market],
        historyRepository: PriceHistoryRepositoryProtocol,
        presentation: Presentation = .sheet
    ) {
        self.offer = offer
        self.favoriteMarkets = favoriteMarkets
        self.presentation = presentation
        _history = State(initialValue: PriceHistoryStore(repository: historyRepository))
    }

    /// Presented as a sheet from the Angebote tab, and **pushed** from the
    /// match list in the shopping list — where a second sheet on top of the
    /// first would stack two cards for one drill-down.
    enum Presentation {
        case sheet
        case pushed
    }

    var presentation: Presentation = .sheet

    var body: some View {
        Group {
            switch presentation {
            case .sheet:
                NavigationStack { content }
            case .pushed:
                content
            }
        }
        // At accessibility sizes the medium detent shows the image and nothing
        // else — then the sheet may as well open full height right away.
        // Detents are a sheet thing; on a pushed screen they do nothing.
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        // Without this a scroll inside the sheet resizes the sheet instead of
        // scrolling its content.
        .presentationContentInteraction(.scrolls)
        .task { await history.load(for: offer) }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                OfferHeroImage(
                    imageUrl: offer.imageUrl, emoji: offer.emoji,
                    category: offer.category, title: offer.product,
                    height: heroHeight
                )
                header
                facts
                PriceHistorySection(store: history)
                provenance
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .themedScreen()
        .navigationTitle(offer.product)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Nur im Sheet: Auf einem geschobenen Bildschirm gibt es den
            // Zurück-Pfeil, und ein „Fertig" daneben wäre ein zweiter Ausgang
            // mit anderer Bedeutung.
            if presentation == .sheet {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    /// The image must not grow with the text: at accessibility sizes a 200 pt
    /// hero pushes every word below the fold.
    private var heroHeight: CGFloat {
        typeSize.isAccessibilitySize ? 120 : 200
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(offer.product)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let unit = offer.unit {
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            priceBlock
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
    }

    @ViewBuilder
    private var priceBlock: some View {
        let parts = Group {
            if let discount = offer.discountPercent {
                DiscountBadge(percent: discount)
            }
            if let price = offer.price {
                PriceText(amount: price, size: .large)
            }
            if let regular = offer.regularPrice {
                Text(regular, format: .euro)
                    .font(.subheadline.monospacedDigit())
                    .strikethrough()
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        // Badge, price and struck-through price stop fitting on one line at
        // accessibility sizes; stack them rather than truncate a price.
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) { parts }
                .accessibilityElement(children: .combine)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) { parts }
                .accessibilityElement(children: .combine)
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let basePrice = offer.basePrice, let baseUnit = offer.baseUnit {
                factRow(
                    "Grundpreis",
                    "\(basePrice.formatted(.euro)) / \(baseUnit)",
                    monospaced: true
                )
            }
            factRow("Gültig", validityLong)
            factRow("Markt", Market.displayTitle(chain: offer.market, favorites: favoriteMarkets))
            factRow("Kategorie", offer.category)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
    }

    private func factRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        // Label above value, not a two-column grid: at accessibility sizes a
        // grid squeezes one side down to two characters per line.
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            Text(value)
                .font(monospaced ? .body.monospacedDigit() : .body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Woher der Preis kommt und wann er geholt wurde — siehe
    /// `OfferProvenance`.
    ///
    /// Unter dem Preisverlauf und bewusst klein: Es ist keine Angabe, die
    /// jemand beim Einkaufen braucht, sondern die, die man sucht, wenn man dem
    /// Preis nicht glaubt.
    private var provenance: some View {
        Text(offer.provenanceLine())
            .font(.caption)
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("offer.provenance")
    }

    private var validityLong: String {
        let from = DateFormatter.offerDayLong.string(from: offer.validFrom)
        let until = DateFormatter.offerDayLong.string(from: offer.validUntil)
        return "\(from) – \(until)"
    }
}

// MARK: - Price history

/// What the product cost in the recorded weeks before. A bonus, not a screen:
/// while it loads, and whenever there is too little data to compare, the
/// section is simply absent — see `PriceHistoryStore.points`.
private struct PriceHistorySection: View {
    let store: PriceHistoryStore

    /// Six weeks fill the sheet; older ones are scrolling for its own sake.
    private let maxRows = 6

    /// **Die Überschrift steht immer da** ([UI-5], 2026-08-01).
    ///
    /// Vorher fiel der ganze Abschnitt weg, solange weniger als zwei Wochen
    /// erfasst waren — mit Begründung („eine Überschrift über einer einzigen
    /// Zahl ist kein Verlauf"), aber mit der Folge, dass er auf den meisten
    /// Angeboten **gar nicht existierte**. Daraus wurde Scotts Frage „where can
    /// i see the preisverlauf?": Er hat den Weg gefunden und nichts vorgefunden.
    ///
    /// Die Tabelle ist jung, das bleibt so. Was sich ändert, ist die Auskunft.
    var body: some View {
        switch store.state {
        case .idle, .loading:
            frame {
                Text("wird geladen …")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        case .failed(let message):
            frame {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
            }
        case .loaded:
            if let points = store.points {
                card(points)
            } else {
                frame {
                    Text("Für dieses Produkt ist bisher nur diese Woche erfasst. Sobald es ein zweites Mal im Angebot war, steht hier, ob es teurer oder billiger geworden ist.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Überschrift plus Inhalt, in derselben Karte wie der fertige Verlauf.
    private func frame<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Preisverlauf").font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
    }

    private func card(_ points: [PriceHistoryPoint]) -> some View {
        // Newest first — "what did it cost before" is asked from today backwards.
        let shown = Array(points.suffix(maxRows).reversed())
        let cheapest = points.compactMap(\.price).min()
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Preisverlauf")
                .font(.headline)
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, point in
                // The next element in `shown` is the week before this one.
                row(point, previous: shown.dropFirst(index + 1).first)
            }
            if let cheapest {
                Text("Günstigster erfasster Preis: \(cheapest.formatted(.euro))")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
    }

    private func row(_ point: PriceHistoryPoint, previous: PriceHistoryPoint?) -> some View {
        let delta = Self.delta(from: previous, to: point)
        return HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("KW \(point.weekOfYear)")
                    .font(.subheadline)
                Text(point.windowText)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: Theme.Spacing.sm)
            if let delta {
                Label(
                    abs(delta).formatted(.euro),
                    systemImage: delta < 0 ? "arrow.down" : "arrow.up"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(delta < 0 ? Theme.success : Theme.warning)
            }
            if let price = point.price {
                PriceText(amount: price, emphasized: false)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(
            Theme.background,
            in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
        )
        // A plain container, not a Button — collapsing it into one utterance is
        // safe here, and four fragments per week would be unbearable.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.voiceOver(point, delta: delta))
    }

    /// Price change against the week before, or nil when it cannot be computed
    /// or rounds to nothing.
    private static func delta(from previous: PriceHistoryPoint?, to point: PriceHistoryPoint) -> Double? {
        guard let price = point.price, let earlier = previous?.price else { return nil }
        let delta = price - earlier
        return abs(delta) >= 0.005 ? delta : nil
    }

    private static func voiceOver(_ point: PriceHistoryPoint, delta: Double?) -> String {
        var parts = ["Kalenderwoche \(point.weekOfYear)", point.windowText]
        if let price = point.price {
            parts.append(price.formatted(.euro))
        }
        if let delta {
            let amount = abs(delta).formatted(.euro)
            parts.append(delta < 0
                ? "\(amount) günstiger als in der Woche davor"
                : "\(amount) teurer als in der Woche davor")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    OfferDetailView(
        offer: MockFixtures.offers[0],
        favoriteMarkets: MockFixtures.markets,
        historyRepository: MockPriceHistoryRepository()
    )
}
