import SwiftUI

/// The answer the app exists to give, at the top of the shopping list: which
/// of the chosen branches covers today's list best, and what that costs.
///
/// The winner is stated in one line a person can read while walking. Everything
/// else — which items are covered, what is missing, how the other markets
/// compare — sits behind a disclosure, because on most days it is not needed.
struct ShoppingPlanCard: View {
    let ranks: [MarketListRank]

    @State private var isExpanded = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var winner: MarketListRank? { ranks.first }
    private var others: [MarketListRank] { Array(ranks.dropFirst()) }

    var body: some View {
        if let winner {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                headline(winner)

                if !winner.matchedItems.isEmpty || !others.isEmpty {
                    Divider()
                    disclosure(winner)
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
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
                // Inside a List row a Text defaults to a single truncated line;
                // this lets it grow downwards instead ("deckt 6 von …").
                .fixedSize(horizontal: false, vertical: true)
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

    private func headlineSummary(_ rank: MarketListRank) -> String {
        guard rank.matchedCount > 0 else {
            return "Kein Markt hat diese Woche Angebote für deine Liste."
        }
        var summary = "Am besten zu \(rank.chain), "
            + "deckt \(rank.matchedCount) von \(rank.itemCount) Artikeln ab"
        if let total = rank.total {
            summary += ", zusammen \(total.formatted(.currency(code: "EUR")))"
        }
        return summary
    }

    // MARK: Details

    private func disclosure(_ winner: MarketListRank) -> some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if !winner.matchedItems.isEmpty {
                    itemGroup(
                        title: "Bei \(winner.chain) im Angebot",
                        items: winner.matchedItems.map(\.item),
                        symbol: "checkmark.circle.fill",
                        color: Theme.success
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
                Text("Erst Abdeckung, dann Preis. Die Summe zählt nur die gefundenen Angebote — Normalpreise sind nicht dabei.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Theme.Spacing.sm)
        } label: {
            Text(isExpanded ? "Weniger anzeigen" : "Was heißt das?")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.accent)
        }
        .tint(Theme.accent)
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
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
            ForEach(others) { rank in
                HStack(spacing: Theme.Spacing.sm) {
                    Text(rank.chain)
                        .font(.subheadline)
                    Spacer(minLength: Theme.Spacing.sm)
                    Text("\(rank.matchedCount)/\(rank.itemCount)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let total = rank.total {
                        Text(total, format: .currency(code: "EUR"))
                            .font(.subheadline.monospacedDigit())
                            .frame(minWidth: 60, alignment: .trailing)
                    } else {
                        Text("–")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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

#Preview("Ohne Treffer") {
    ShoppingPlanCard(ranks: [
        MarketListRank(chain: "Lidl", matchedItems: [], missingItems: ["Zahnpasta"], total: nil),
    ])
    .padding()
    .background(Theme.background)
}
