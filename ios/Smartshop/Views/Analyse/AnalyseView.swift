import SwiftUI
import Charts

/// Analyse tab: key figures and charts over the current week's offers for the
/// selected region and Wunschmärkte. One measure per chart, one accent hue.
struct AnalyseView: View {
    let regions: [String]
    let favoriteMarkets: [Market]

    @Environment(ShoppingListStore.self) private var list
    @Environment(MatchRejectionStore.self) private var rejections
    @State private var store: OfferStore

    init(regions: [String], favoriteMarkets: [Market], repository: OfferRepositoryProtocol) {
        self.regions = regions
        self.favoriteMarkets = favoriteMarkets
        _store = State(initialValue: OfferStore(repository: repository, cache: try? OfferCache()))
    }

    private var chains: [String] {
        Array(Set(favoriteMarkets.map(\.chain))).sorted()
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Analyse")
                .background(Theme.background)
        }
        .task(id: regions) { await store.load(regions: regions, chains: chains) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .loading:
            // Skeleton matching the loaded layout — no jump when data arrives.
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: Theme.Spacing.md), GridItem(.flexible())],
                    spacing: Theme.Spacing.md
                ) {
                    StatTile(title: "Angebote", value: "000", footnote: "diese Woche")
                    StatTile(title: "Märkte", value: "0", footnote: "mit Angeboten")
                    StatTile(title: "Ø Rabatt", value: "00 %", footnote: "wo bekannt")
                    StatTile(title: "Top-Rabatt", value: "00 %", footnote: "beste Ersparnis")
                }
                .padding(Theme.Spacing.lg)
            }
            .redacted(reason: .placeholder)
            .disabled(true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Analyse wird geladen")
        case .empty:
            ContentUnavailableView(
                "Keine Daten",
                systemImage: "chart.bar",
                description: Text("Für deine Region und Märkte liegen aktuell keine Angebote vor.")
            )
        case .error(let message):
            ContentUnavailableView {
                Label("Fehler beim Laden", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Erneut versuchen") {
                    Task { await store.refresh() }
                }
                .buttonStyle(.borderedProminent)
            }
        case .loaded:
            analytics
        }
    }

    private var analytics: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                statTiles
                listRankingCard
                marketCountCard
                marketDiscountCard
                categoryCard
                topDealsCard
            }
            .padding(Theme.Spacing.lg)
        }
        .refreshable { await store.refresh() }
    }

    // MARK: Key figures

    private var statTiles: some View {
        let stats = OfferAnalytics.overall(store.offers)
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Theme.Spacing.md), GridItem(.flexible())],
            spacing: Theme.Spacing.md
        ) {
            StatTile(title: "Angebote", value: "\(stats.offerCount)", footnote: "diese Woche")
            StatTile(title: "Märkte", value: "\(stats.marketCount)", footnote: "mit Angeboten")
            StatTile(
                title: "Ø Rabatt",
                value: stats.avgDiscount.map { "\($0) %" } ?? "–",
                footnote: "wo bekannt"
            )
            StatTile(
                title: "Top-Rabatt",
                value: stats.maxDiscount.map { "\($0) %" } ?? "–",
                footnote: "beste Ersparnis"
            )
        }
    }

    // MARK: Listen-Ranking

    /// Which Wunschmarkt covers the shopping list best — coverage before
    /// price, honest wording: the totals compare matched offer prices only.
    @ViewBuilder
    private var listRankingCard: some View {
        let ranks = ShoppingListRanking.rank(
            items: list.uncheckedItems,
            offers: store.offers,
            chains: chains
        ) { rejections.isRejected(itemText: $0, offer: $1) }

        if !ranks.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Bester Markt für deine Liste")
                    .font(.headline)
                VStack(spacing: 0) {
                    ForEach(Array(ranks.enumerated()), id: \.element.id) { index, rank in
                        rankRow(rank, position: index + 1)
                            .padding(.vertical, Theme.Spacing.xs)
                        if rank.id != ranks.last?.id {
                            Divider()
                        }
                    }
                }
                Text("Rangfolge: erst Abdeckung, dann Preis. Die Summe zählt nur die gematchten Angebote — Artikel ohne Treffer und Normalpreise sind nicht eingerechnet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard()
        }
    }

    private func rankRow(_ rank: MarketListRank, position: Int) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("\(position).")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(rank.chain)
                    .font(.subheadline.weight(position == 1 ? .semibold : .regular))
                Text("\(rank.matchedCount)/\(rank.itemCount) Artikel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Theme.Spacing.sm)
            if let total = rank.total {
                Text(total, format: .currency(code: "EUR"))
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(position == 1 ? .semibold : .regular)
            } else {
                Text("–")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Platz \(position): \(rank.chain), \(rank.matchedCount) von \(rank.itemCount) Artikeln"
            + (rank.total.map { String(format: ", %.2f Euro", $0) } ?? "")
        )
    }

    // MARK: Charts

    private var marketCountCard: some View {
        let stats = OfferAnalytics.marketStats(store.offers)
        let summary = stats.map { "\($0.chain) \($0.offerCount) Angebote" }.joined(separator: ", ")
        return chartCard("Angebote pro Markt", accessibilitySummary: summary) {
            Chart(stats) { stat in
                BarMark(
                    x: .value("Angebote", stat.offerCount),
                    y: .value("Markt", stat.chain)
                )
                .foregroundStyle(Theme.accent)
                .cornerRadius(4)
                .annotation(position: .trailing, alignment: .leading) {
                    Text("\(stat.offerCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .frame(height: rowHeight * CGFloat(stats.count))
        }
    }

    private var marketDiscountCard: some View {
        let stats = OfferAnalytics.marketStats(store.offers)
            .filter { $0.avgDiscount != nil }
            .sorted { ($0.avgDiscount ?? 0) > ($1.avgDiscount ?? 0) }
        let summary = stats
            .map { "\($0.chain) durchschnittlich \($0.avgDiscount ?? 0) Prozent" }
            .joined(separator: ", ")
        return chartCard("Ø Rabatt pro Markt", accessibilitySummary: stats.isEmpty ? nil : summary) {
            if stats.isEmpty {
                Text("Keine Rabattdaten in dieser Woche.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(stats) { stat in
                    BarMark(
                        x: .value("Ø Rabatt", stat.avgDiscount ?? 0),
                        y: .value("Markt", stat.chain)
                    )
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(4)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(stat.avgDiscount ?? 0) %")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: rowHeight * CGFloat(stats.count))
            }
        }
    }

    private var categoryCard: some View {
        let stats = OfferAnalytics.categoryBreakdown(store.offers)
        let summary = stats.map { "\($0.category) \($0.count) Angebote" }.joined(separator: ", ")
        return chartCard("Kategorien", accessibilitySummary: summary) {
            Chart(stats) { stat in
                BarMark(
                    x: .value("Angebote", stat.count),
                    y: .value("Kategorie", "\(stat.emoji) \(stat.category)")
                )
                .foregroundStyle(Theme.accent)
                .cornerRadius(4)
                .annotation(position: .trailing, alignment: .leading) {
                    Text("\(stat.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .frame(height: rowHeight * CGFloat(stats.count))
        }
    }

    private var topDealsCard: some View {
        let deals = OfferAnalytics.topDeals(store.offers)
        return chartCard("Top-Deals der Woche") {
            if deals.isEmpty {
                Text("Keine Rabattdaten in dieser Woche.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(deals) { offer in
                        OfferRowView(offer: offer)
                            .padding(.vertical, Theme.Spacing.xs)
                        if offer.id != deals.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private let rowHeight: CGFloat = 32

    /// `accessibilitySummary` replaces the chart for VoiceOver with a spoken
    /// list of the values; nil keeps the default element structure.
    private func chartCard(
        _ title: String,
        accessibilitySummary: String? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
        .modifier(ChartSummaryModifier(title: title, summary: accessibilitySummary))
    }
}

/// Collapses a chart card into a single VoiceOver element that speaks the
/// chart's values, instead of an unlabeled picture of bars.
private struct ChartSummaryModifier: ViewModifier {
    let title: String
    let summary: String?

    func body(content: Content) -> some View {
        if let summary {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(title). \(summary)")
        } else {
            content
        }
    }
}

#Preview {
    AnalyseView(
        regions: ["01219"],
        favoriteMarkets: MockFixtures.markets,
        repository: MockOfferRepository()
    )
    .environment(ShoppingListStore())
    .environment(MatchRejectionStore())
}
