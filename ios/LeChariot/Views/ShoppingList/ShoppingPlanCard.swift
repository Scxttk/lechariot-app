import SwiftUI

/// The answer the app exists to give, at the top of the shopping list: which
/// of the chosen branches covers today's list best, and what that costs.
///
/// The winner is stated in one line a person can read while walking. Everything
/// else — which items are covered, what is missing, how the other markets
/// compare — sits behind a disclosure, because on most days it is not needed.
struct ShoppingPlanCard: View {
    let ranks: [MarketListRank]
    /// Die Kette, die ohne die gehefteten Wahlen gewönne — `nil`, wenn sie am
    /// Ergebnis nichts ändern.
    ///
    /// Eine Heftung darf den empfohlenen Markt kippen (sonst rechnete die Karte
    /// einen Einkauf aus, den niemand macht), und **dann muss die Karte das
    /// sagen dürfen**. Ein Sieger, der sich ohne erkennbaren Grund ändert,
    /// sieht aus wie ein Fehler der App statt wie die Folge der eigenen Wahl.
    var winnerWithoutPins: String? = nil

    @State private var isExpanded = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var winner: MarketListRank? { ranks.first }
    private var others: [MarketListRank] { Array(ranks.dropFirst()) }

    var body: some View {
        if let winner {
            // Spacing 0 with explicit padding: the details block must be able
            // to collapse to a true zero height, and a VStack spacing would
            // leave its gap behind even then.
            VStack(alignment: .leading, spacing: 0) {
                headline(winner)

                if !winner.matchedItems.isEmpty || !winner.pinnedElsewhere.isEmpty || !others.isEmpty {
                    Divider()
                        .padding(.vertical, Theme.Spacing.md)
                    disclosureButton
                    if isExpanded {
                        details(winner)
                            // Behält die eigene Höhe, statt sich von der noch
                            // wachsenden Karte stauchen zu lassen — das war die
                            // Ursache dafür, dass „Weniger anzeigen" und „Bei
                            // Lidl im Angebot" ein paar Bilder lang übereinander
                            // lagen. Was noch nicht freigelegt ist, schneidet
                            // das `.clipped()` unten weg.
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .themeCard()
            // One animation for the whole card. A `DisclosureGroup` inside a
            // `List` row animated in three separate steps — the row height by
            // the List, the content by itself, the card's rounded background
            // and shadow after both — which is what made the expansion judder.
            .animation(.snappy(duration: 0.28), value: isExpanded)
        }
    }

    // MARK: Headline

    private func headline(_ winner: MarketListRank) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(winner.matchedCount == 0 ? "Noch kein Treffer" : "Am besten zu")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.5)

            // Side by side normally; stacked at accessibility sizes, where the
            // two headlines together no longer fit on one line and the amount
            // would otherwise wrap between the digits and the euro sign.
            let chain = Text(winner.matchedCount == 0 ? "–" : winner.chain)
                .font(.title2.bold())
                .foregroundStyle(Theme.accent)
            let amount = winner.total.map {
                Text($0, format: .currency(code: "EUR"))
                    .font(.title3.bold().monospacedDigit())
            }

            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    chain
                    amount
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    chain
                    Spacer(minLength: Theme.Spacing.sm)
                    amount
                }
            }

            Text(coverageText(winner))
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                // Inside a List row a Text defaults to a single truncated line;
                // this lets it grow downwards instead ("deckt 6 von …").
                .fixedSize(horizontal: false, vertical: true)

            // Steht **oben** und nicht hinter „Was heißt das?": Eine Karte, die
            // ihren Ausschlag erst nach einem Tipp verrät, sagt ihn nicht.
            if let flipLine {
                Text(flipLine)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(headlineSummary(winner))
    }

    private func coverageText(_ rank: MarketListRank) -> String {
        guard rank.matchedCount > 0 else {
            return "Für deine Liste gibt es diese Woche keine Angebote in deinen Filialen."
        }
        return "deckt \(rank.matchedCount) von \(rank.itemCount) Artikeln ab"
    }

    /// Der Satz, der den Ausschlag der eigenen Wahl benennt.
    private var flipLine: String? {
        winnerWithoutPins.map { "Deine Wahl gibt den Ausschlag — ohne sie wäre \($0) am besten." }
    }

    private func headlineSummary(_ rank: MarketListRank) -> String {
        guard rank.matchedCount > 0 else {
            return "Kein Markt hat diese Woche Angebote für deine Liste."
        }
        var summary = "Am besten zu \(rank.chain), "
            + "deckt \(rank.matchedCount) von \(rank.itemCount) Artikeln ab"
        if let total = rank.total {
            summary += ", zusammen \(total.formatted(.currency(code: "EUR")))"
        }
        // Die Kopfzeile ist **ein** Element (`children: .ignore`) — was hier
        // nicht mitkommt, existiert für VoiceOver nicht.
        if let flipLine { summary += ". " + flipLine }
        return summary
    }

    // MARK: Details

    /// Plain button rather than a `DisclosureGroup`: the label stays put, the
    /// chevron turns with the same animation as the card, and the caption
    /// cross-fades instead of swapping halfway through the expansion.
    private var disclosureButton: some View {
        Button { isExpanded.toggle() } label: {
            HStack(spacing: Theme.Spacing.sm) {
                // Bewusst ohne `contentTransition`: eine Kreuzblende zwischen
                // zwei verschieden langen Wörtern zeigt sie ein paar Bilder
                // lang übereinander, und „Weniger anzeigen" über „Was heißt
                // das?" ist genau das Matschbild, das hier weg sollte. Der
                // Wechsel fällt mit dem eigenen Tippen zusammen und liest sich
                // dadurch als Reaktion, nicht als Sprung.
                Text(isExpanded ? "Weniger anzeigen" : "Was heißt das?")
                    .font(.subheadline.weight(.medium))
                    .animation(nil, value: isExpanded)
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .foregroundStyle(Theme.accent)
            // The row centre is a Spacer and would otherwise not react —
            // the same dead-zone that made the branch rows untappable.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isExpanded ? "Blendet die Details aus" : "Zeigt Artikel und die anderen Filialen")
    }

    private func details(_ winner: MarketListRank) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !winner.matchedItems.isEmpty {
                itemGroup(
                    title: "Bei \(winner.chain) im Angebot",
                    items: winner.matchedItems.map(\.item),
                    symbol: "checkmark.circle.fill",
                    color: Theme.success
                )
            }
            // Eigene Gruppe, nicht unter „Zum Normalpreis": „Lidl hat keinen
            // Käse im Angebot" und „Lidl hat Käse, aber nicht deinen" sind für
            // jemanden, der einen Einkauf plant, zwei verschiedene Sätze.
            if !winner.pinnedElsewhere.isEmpty {
                itemGroup(
                    title: "Deine Wahl woanders",
                    items: winner.pinnedElsewhere.map(\.line),
                    symbol: "pin.fill",
                    color: Theme.accent
                )
            }
            if !winner.missingItems.isEmpty {
                itemGroup(
                    title: "Zum Normalpreis",
                    items: winner.missingItems,
                    symbol: "circle",
                    color: .secondary
                )
            }
            if !others.isEmpty {
                otherMarkets
            }
            Text(footnote(winner))
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Eigener Abstand nach oben statt VStack-Spacing: er gehört zur
        // gemessenen Höhe und verschwindet damit im eingeklappten Zustand mit.
        .padding(.top, Theme.Spacing.md)
    }

    /// Die Fußnote sagt, wie die Summe zustande kommt — und **nur dann**
    /// zusätzlich etwas über Heftungen, wenn eine im Spiel ist. Ein Satz über
    /// eine Funktion, die dieser Nutzer nicht benutzt, ist Rauschen.
    private func footnote(_ winner: MarketListRank) -> String {
        let basis = "Erst Abdeckung, dann Preis. Die Summe zählt nur die gefundenen Angebote — Normalpreise sind nicht dabei."
        guard winner.hasPinnedItems else { return basis }
        return basis + " Angeheftete Artikel zählen mit deinem Preis, nicht mit dem billigsten."
    }

    private func itemGroup(
        title: String,
        items: [String],
        symbol: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            ForEach(items, id: \.self) { item in
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: symbol)
                        .foregroundStyle(color)
                        .font(.caption)
                    Text(item)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(items.joined(separator: ", "))")
    }

    private var otherMarkets: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Deine anderen Filialen")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            ForEach(others) { rank in
                HStack(spacing: Theme.Spacing.sm) {
                    Text(rank.chain)
                        .font(.subheadline)
                    Spacer(minLength: Theme.Spacing.sm)
                    Text("\(rank.matchedCount)/\(rank.itemCount)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.secondaryText)
                    if let total = rank.total {
                        Text(total, format: .currency(code: "EUR"))
                            .font(.subheadline.monospacedDigit())
                            .frame(minWidth: 60, alignment: .trailing)
                    } else {
                        Text("–")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .frame(minWidth: 60, alignment: .trailing)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(rank.chain), \(rank.matchedCount) von \(rank.itemCount) Artikeln"
                    + (rank.total.map { ", \($0.formatted(.currency(code: "EUR")))" } ?? "")
                )
            }
        }
    }
}

#Preview("Mit Treffern") {
    ShoppingPlanCard(ranks: [
        MarketListRank(
            chain: "Lidl",
            matchedItems: [
                RankedItemMatch(item: "Milch", match: OfferMatch(offer: MockFixtures.offers[0], kind: .direct)),
                RankedItemMatch(item: "Brot", match: OfferMatch(offer: MockFixtures.offers[1], kind: .direct)),
            ],
            missingItems: ["Zahnpasta"],
            total: 4.27
        ),
        MarketListRank(
            chain: "Kaufland",
            matchedItems: [RankedItemMatch(item: "Milch", match: OfferMatch(offer: MockFixtures.offers[0], kind: .direct))],
            missingItems: ["Brot", "Zahnpasta"],
            total: 1.29
        ),
    ])
    .padding()
    .background(Theme.background)
}

#Preview("Mit geheftetem Artikel") {
    ShoppingPlanCard(
        ranks: [
            MarketListRank(
                chain: "Lidl",
                matchedItems: [
                    RankedItemMatch(item: "Milch", match: OfferMatch(offer: MockFixtures.offers[0], kind: .direct)),
                ],
                missingItems: [],
                pinnedElsewhere: [
                    PinnedElsewhere(item: "Käse", pin: PinnedOffer(
                        marketKey: "netto-01219-1", market: "Netto",
                        product: "GRÜNLÄNDER Schnittkäse"
                    )),
                ],
                total: 0.99
            ),
        ],
        winnerWithoutPins: "Netto"
    )
    .padding()
    .background(Theme.background)
}

#Preview("Ohne Treffer") {
    ShoppingPlanCard(ranks: [
        MarketListRank(chain: "Lidl", matchedItems: [], missingItems: ["Zahnpasta"], total: nil),
    ])
    .padding()
    .background(Theme.background)
}
