import SwiftUI
import Charts

/// Analyse tab: key figures and charts over the current week's offers for the
/// selected region and Wunschmärkte. One measure per chart, one accent hue.
struct AnalyseView: View {
    let plz: String
    let favoriteMarkets: [Market]

    @State private var store: OfferStore

    init(plz: String, favoriteMarkets: [Market], repository: OfferRepositoryProtocol) {
        self.plz = plz
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
                .background(Color(uiColor: .systemGroupedBackground))
        }
        .task(id: plz) { await store.load(plz: plz, chains: chains) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .loading:
            ProgressView("Angebote werden geladen…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: Charts

    private var marketCountCard: some View {
        let stats = OfferAnalytics.marketStats(store.offers)
        return chartCard("Angebote pro Markt") {
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
        return chartCard("Ø Rabatt pro Markt") {
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
        return chartCard("Kategorien") {
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

    private func chartCard(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard()
    }
}

#Preview {
    AnalyseView(
        plz: "01219",
        favoriteMarkets: MockFixtures.markets,
        repository: MockOfferRepository()
    )
}
