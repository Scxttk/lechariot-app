import SwiftUI

/// **„Passende Artikel im Angebot" — die Zeile aus Scotts Bring!-Video.**
///
/// Der interessante Teil ist die **Platzierung**: Bring! stellt sie *in* die
/// Liste, nicht in einen eigenen Reiter. Wer seine Liste durchgeht, sieht
/// dort, dass sich ein Blick in die Angebote lohnt — statt ihn selbst
/// einfallen zu müssen.
///
/// **Gerechnet wird hier nichts.** Die Zähler kommen aus `MarketListRank`, aus
/// dem Lauf, den die Plan-Karte ohnehin macht (`OfferHitSummary`). Ein zweiter
/// Durchlauf über dieselben Angebote wäre eine zweite Wahrheit über dieselbe
/// Frage.
///
/// **Unsere Sprache, nicht Bring!s.** Dort ist die Zeile rot und ruft mit
/// Ausrufezeichen; hier führt Grün, und die Zeile sagt, was sie weiß.
struct OfferHitsRow: View {
    let summary: OfferHitSummary
    var onOpen: () -> Void = {}

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(Theme.accent)
                    Text("Passende Artikel im Angebot")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }

                // Die Ketten mit ihren Zählern — „Netto 15 · Penny 3".
                // Ketten ohne Treffer stehen nicht dabei; „ALDI 0" liest sich
                // wie ein Angebot und ist keines.
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 88), spacing: Theme.Spacing.sm)],
                    alignment: .leading,
                    spacing: Theme.Spacing.sm
                ) {
                    ForEach(summary.chains) { hits in
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(hits.chain)
                                .font(.caption.weight(.medium))
                            Text("\(hits.count)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(
                            Theme.surface,
                            in: Capsule()
                        )
                        .overlay(Capsule().strokeBorder(Theme.stroke))
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.surface,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("list.offerHits")
        // Eine Zeile, ein Satz — sonst liest VoiceOver „Netto", „15", „Penny",
        // „3" als vier Bruchstücke vor.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceOverLabel)
        .accessibilityHint("Öffnet die Angebote")
        .accessibilityAddTraits(.isButton)
    }

    private var voiceOverLabel: String {
        let chains = summary.chains
            .map { "\($0.chain) \($0.count)" }
            .joined(separator: ", ")
        return "Passende Artikel im Angebot: \(chains)"
    }
}

#Preview {
    OfferHitsRow(summary: OfferHitSummary(ranks: []))
        .padding()
}
