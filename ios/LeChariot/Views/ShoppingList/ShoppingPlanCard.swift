import SwiftUI

/// The answer the app exists to give, at the top of the shopping list: which
/// of the chosen branches covers today's list best, and what that costs.
///
/// **Eine Karte, ein Weg.** Bis zum 06.08. standen hier zwei Kästen
/// übereinander — diese Karte mit einer aufklappbaren Aufschlüsselung und
/// darunter „Passende Artikel im Angebot" mit denselben Ketten noch einmal als
/// Chips. Zusammen 209 pt, und der erste Artikel der Liste fing erst bei 535
/// von 874 pt an. Beide beantworteten dieselbe Frage; die Aufschlüsselung steht
/// jetzt einmal, hinter dem Weg zu den Treffern.
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
    /// Der Weg zu den Treffern. Ohne ihn zeigt die Karte nur die Antwort.
    var onShowHits: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var typeSize

    private var winner: MarketListRank? { ranks.first }

    private var hasMatches: Bool { ranks.contains { $0.matchedCount > 0 } }

    var body: some View {
        if let winner {
            VStack(alignment: .leading, spacing: 0) {
                headline(winner)

                if hasMatches, let onShowHits {
                    Divider()
                        .padding(.vertical, Theme.Spacing.md)
                    hitsButton(onShowHits)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard()
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
                Text($0, format: .euro)
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
        // Nur als Anker für den Barrierefreiheits-Audit: Diese Karte trägt
        // `.themeCard()` mit zwei `.shadow`-Modifikatoren, und durch eine
        // Schattenebene misst `performAccessibilityAudit` nicht mehr die
        // gezeichnete Farbe. Die Ausnahme dafür war eine Liste deutscher
        // Textschnipsel und wuchs mit jedem Gerät; jetzt ist sie eine Fläche,
        // und die braucht zwei Bezeichner statt drei Sätze. Siehe
        // `shadowedCardRegion()` in `AccessibilityAuditTests`.
        .accessibilityIdentifier("list.plan.headline")
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
            summary += ", zusammen \(total.formatted(.euro))"
        }
        // Die Kopfzeile ist **ein** Element (`children: .ignore`) — was hier
        // nicht mitkommt, existiert für VoiceOver nicht.
        if let flipLine { summary += ". " + flipLine }
        return summary
    }

    // MARK: Weg zu den Treffern

    /// **Ein Weg statt einer Aufklappung.** „Was heißt das?" legte die
    /// Aufschlüsselung auf denselben Bildschirm, auf dem schon die Liste steht;
    /// dahinter liegt jetzt der Bildschirm, der dieselben Treffer zeigt und an
    /// dem man sie auch anheften kann.
    private func hitsButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "tag.fill")
                Text("Angebote zu deiner Liste")
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.accent)
            // The row centre is a Spacer and would otherwise not react —
            // the same dead-zone that made the branch rows untappable.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Zeigt die Angebote zu den Artikeln deiner Liste")
        // Die zweite Ecke der Schattenfläche — siehe `list.plan.headline`.
        .accessibilityIdentifier("list.plan.disclosure")
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
