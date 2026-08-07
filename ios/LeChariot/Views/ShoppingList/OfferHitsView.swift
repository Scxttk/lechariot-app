import SwiftUI

/// **Was hinter „Passende Artikel im Angebot" liegt.**
///
/// Scott, 03.08.: „wirkt tot — nur ein Link, sonst passiert nichts." Der Slice
/// aus [#68] war bewusst Platzierung plus Link; er führte in den Angebote-Tab,
/// also in *alle* Angebote der Woche. Die Zahl in der Zeile („Netto 15")
/// versprach aber etwas anderes: **diese fünfzehn**, die zu dieser Liste
/// passen. Ein Weg, der die Frage wechselt, statt sie zu beantworten, fühlt
/// sich tot an, auch wenn er funktioniert.
///
/// Bring! zeigt an dieser Stelle je Treffer „Aktion übernehmen". Das ist bei
/// uns das Anheften, das es seit [#57] gibt — hier steht es nur endlich dort,
/// wo die Zahl es verspricht.
///
/// **Kein neues Matching, und das ist der Punkt.** Dieser Bildschirm rechnet
/// nichts: Er bekommt `[MarketListRank]` gereicht — denselben Lauf, den die
/// Plan-Karte ohnehin macht und aus dem auch die Zähler der Zeile stammen. Ein
/// zweiter Durchlauf über dieselben Angebote wäre eine zweite Wahrheit über
/// dieselbe Frage, und die beiden gingen irgendwann auseinander.
struct OfferHitsView: View {
    /// Die Wertung aus der Liste. Nicht die Angebote — die Zuordnung.
    let ranks: [MarketListRank]
    let favoriteMarkets: [Market]
    /// Live aus dem Speicher: Die Heftung muss im selben Durchgang
    /// zurückkommen, und `ShoppingItem` ist ein Wert.
    @Environment(ShoppingListStore.self) private var list
    @Environment(\.dismiss) private var dismiss

    /// Auf welche Kette gefiltert ist — dieselbe Leiste wie in den Angeboten.
    @State private var chain: String?

    private var chains: [String] {
        ranks.filter { $0.matchedCount > 0 }
            .sorted { ($0.matchedCount, $1.chain) > ($1.matchedCount, $0.chain) }
            .map(\.chain)
    }

    private var shown: [MarketListRank] {
        let mit = ranks.filter { $0.matchedCount > 0 }
        guard let chain else {
            return mit.sorted { ($0.matchedCount, $1.chain) > ($1.matchedCount, $0.chain) }
        }
        return mit.filter { $0.chain == chain }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MarketChipBar(
                    chains: chains,
                    selection: $chain,
                    identifier: "hits.marketChips"
                )
                list_
            }
            .themedScreen()
            .navigationTitle("Passende Artikel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .accessibilityIdentifier("hits.done")
                }
            }
        }
    }

    /// `list_` mit Unterstrich: `list` ist hier der Einkaufslisten-Speicher.
    private var list_: some View {
        List {
            Section {
                Text("Zu diesen Artikeln deiner Liste gibt es diese Woche ein Angebot. Ein Tipp auf die Reißzwecke, und die Wahl steht dauerhaft auf der Liste.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Theme.background)
                    .accessibilityIdentifier("hits.explainer")
            }

            ForEach(shown) { rank in
                Section(Market.displayTitle(chain: rank.chain, favorites: favoriteMarkets)) {
                    ForEach(rank.matchedItems) { treffer in
                        row(treffer, chain: rank.chain)
                    }
                    .listRowBackground(Theme.surface)
                }
            }

            // **Der Vergleich, der bis zum 06.08. in der Plan-Karte aufklappte.**
            // Er gehört hierher: Die Karte auf der Liste beantwortet „wohin",
            // dieser Bildschirm beantwortet „warum". Beim Filter auf eine Kette
            // steht er nicht — dann vergleicht gerade niemand.
            if chain == nil, ranks.count > 1 {
                Section {
                    ForEach(ranks) { rank in
                        comparisonRow(rank)
                    }
                    .listRowBackground(Theme.surface)
                } header: {
                    Text("Deine Filialen im Vergleich")
                } footer: {
                    Text(footnote)
                        .accessibilityIdentifier("hits.footnote")
                }
            }
        }
        .accessibilityIdentifier("hits.list")
    }

    /// Eine Kette im Vergleich: wie viel sie abdeckt und was das kostet.
    private func comparisonRow(_ rank: MarketListRank) -> some View {
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

    /// Wie die Summe zustande kommt — und **nur dann** etwas über Heftungen,
    /// wenn eine im Spiel ist. Ein Satz über eine Funktion, die dieser Nutzer
    /// nicht benutzt, ist Rauschen.
    private var footnote: String {
        let basis = "Erst Abdeckung, dann Preis. Die Summe zählt nur die gefundenen Angebote — Normalpreise sind nicht dabei."
        guard ranks.contains(where: \.hasPinnedItems) else { return basis }
        return basis + " Angeheftete Artikel zählen mit deinem Preis, nicht mit dem billigsten."
    }

    /// Ein Treffer: der Artikel der Liste, das Angebot dazu, und der Knopf, der
    /// aus dem Vorschlag eine Wahl macht.
    private func row(_ treffer: RankedItemMatch, chain: String) -> some View {
        let offer = treffer.offer
        let item = listItem(for: treffer.item)
        let isPinned = item.map { eintrag in
            eintrag.pinnedOffers.contains { offer.matches($0) }
        } ?? false

        return HStack(spacing: Theme.Spacing.sm) {
            OfferThumbnail(
                imageUrl: offer.imageUrl, emoji: offer.emoji,
                category: offer.category, title: offer.product, size: 40,
                framed: offer.imageUrl != nil
            )
            VStack(alignment: .leading, spacing: 2) {
                // **Der Artikel führt, nicht das Produkt.** Dieser Bildschirm
                // beantwortet „was von meiner Liste ist im Angebot" — und die
                // Antwort fängt mit dem eigenen Wort an, nicht mit dem des
                // Prospekts.
                Text(treffer.item)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: Theme.Spacing.xs) {
                    if isPinned { PinnedBadge() }
                    Text(offer.product)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            if let price = offer.price { PriceText(amount: price) }

            Button {
                guard let item else { return }
                withAnimation(Theme.Motion.element.animation) {
                    list.togglePin(offer.asPin, for: item)
                }
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.title3)
                    .foregroundStyle(isPinned ? Theme.accent : Theme.secondaryText)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(TactileButtonStyle())
            .disabled(item == nil)
            .accessibilityIdentifier("hits.pin")
            .accessibilityLabel(isPinned
                                ? "Heftung für \(treffer.item) lösen"
                                : "\(offer.product) für \(treffer.item) übernehmen")
        }
        .accessibilityElement(children: .contain)
    }

    /// Der Listeneintrag zu einem Suchwort. Über `query` und nicht über den
    /// Text: Genau darüber ist die Wertung gerechnet.
    private func listItem(for query: String) -> ShoppingItem? {
        list.uncheckedItems.first { $0.query == query }
    }
}
