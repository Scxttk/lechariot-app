import SwiftUI

/// One shopping-list entry: check circle, item text, and (for open items with
/// a match) the cheapest current offer as a suggestion line.
struct ShoppingListRowView: View {
    let item: ShoppingItem
    /// Das Angebot der Zeile — und ob es die eigene Wahl ist. Siehe
    /// `ItemSuggestion`.
    var suggestion: ItemSuggestion = ItemSuggestion(match: nil)
    /// Ob überhaupt Filialen gewählt sind. Trennt die zwei Gründe für eine
    /// leere Treffer-Zeile: „diese Woche nichts gefunden" ist eine Aussage über
    /// die Angebote, „noch keine Filiale" eine über die Einrichtung — und nur
    /// die zweite kann der Nutzer beheben.
    var hasMarkets = true
    /// Trägt die Anker für den Rundgang. Nur die erste offene Zeile setzt das —
    /// siehe `ShoppingListView.itemList`.
    var carriesTutorialAnchors = false
    /// Der Satz zu Suchwörtern, die das Wörterbuch nicht kennt — siehe
    /// `QueryUnderstanding.unknownNote`.
    ///
    /// **Nur diese Zeile kann ihn zeigen, und deshalb steht er hier.** Ohne
    /// Treffer gibt es kein Trefferblatt zu öffnen, in dem der Kopf ihn
    /// tragen könnte; „Diese Woche nirgends im Angebot" war bisher die
    /// einzige Auskunft — und sie sagt über ein Wort, das die App gar nicht
    /// kennt, genau das Falsche. Genau daran hing „vegan Schnitzel"
    /// vom 21.07. bis zum 31.07.
    ///
    /// Gerechnet wird er in `ShoppingListView`, weil nur die den Vorrat hat.
    var unknownWordNote: String? = nil
    let onToggle: () -> Void
    /// Opens the match-detail sheet; nil hides the affordance (checked items).
    var onShowMatches: (() -> Void)? = nil
    /// Opens the detail chips; nil leaves the name a plain label.
    var onEditDetail: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Button(action: onToggle) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? Theme.accent : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    // 44-pt hit area despite the small glyph.
                    .frame(width: 44, height: 44, alignment: .center)
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityLabel(item.isChecked ? "Als offen markieren" : "Als erledigt markieren")
            .tutorialAnchor(.rowCheck, when: carriesTutorialAnchors)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                name

                if !item.isChecked {
                    offerBlock
                }
            }
            .padding(.vertical, Theme.Spacing.sm)

            Spacer(minLength: 0)
        }
    }

    /// The item name, with its detail underneath.
    ///
    /// Tapping the name opens the chips — the same gesture as Bring!, and the
    /// only affordance for it. A second one (swipe, a button in the row) would
    /// crowd a row that already has a check circle, an offer tile and a
    /// destructive swipe.
    @ViewBuilder
    private var name: some View {
        let text = VStack(alignment: .leading, spacing: 2) {
            Text(item.text)
                .font(.body.weight(.medium))
                .strikethrough(item.isChecked)
                .foregroundStyle(item.isChecked ? .secondary : .primary)

            // Deliberately not struck through with the item: what the note says
            // stays true after the thing is in the trolley, and a struck-out
            // "1 l · Bio" is harder to read for no gain.
            if let line = item.detailLine {
                Text(line)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if let onEditDetail {
            Button(action: onEditDetail) { text }
                .buttonStyle(TactileButtonStyle())
                .accessibilityLabel(item.detailLine.map { "\(item.text), \($0)" } ?? item.text)
                .accessibilityHint("Öffnet die Angaben zum Artikel")
                .accessibilityIdentifier("list.item.detail")
        } else {
            text
        }
    }

    /// Die Angebotshälfte der Zeile — und, wenn nötig, der Satz darüber.
    ///
    /// **Der Satz kommt zuerst und ist nicht wegdrückbar.** Wessen Wahl es
    /// diese Woche nicht gibt, sieht darunter zwar wieder das billigste
    /// Angebot, erfährt aber, dass das ein Rückfall ist. Ein stiller Rückfall
    /// wäre genau die unsichtbare Ableitung, gegen die am 2026-07-31
    /// entschieden wurde.
    @ViewBuilder
    private var offerBlock: some View {
        if let pin = suggestion.dormantPin {
            dormantNotice(pin)
        }
        // Ohne Rückfall trägt die Zeile darüber schon alles. Sonst stünden hier
        // zwei Sätze übereinander, die fast dasselbe sagen („… ist diese Woche
        // nicht im Angebot" / „Diese Woche nirgends im Angebot") — am
        // Simulator gesehen, nicht vermutet.
        if suggestion.match != nil || suggestion.dormantPin == nil {
            suggestionTile
        }
    }

    /// Der Hinweis auf die schlafende Wahl — **und der Weg zu ihr zurück.**
    ///
    /// Er ist antippbar, und das ist keine Bequemlichkeit: Ohne Angebot gibt es
    /// keine Kachel, und ohne Kachel führte nichts mehr ins Treffer-Blatt. Eine
    /// Heftung, deren Produkt aus dem Prospekt gefallen ist, wäre dann nicht
    /// mehr zu lösen — eine Sackgasse, die genau dann zuschnappt, wenn man sie
    /// am wenigsten erwartet. Am Simulator gesehen, nicht überlegt.
    @ViewBuilder
    private func dormantNotice(_ pin: PinnedOffer) -> some View {
        let text = Text(dormantLine(pin))
            .font(.caption)
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

        if let onShowMatches {
            Button(action: onShowMatches) { text }
                .buttonStyle(TactileButtonStyle())
                .accessibilityIdentifier("list.pin.dormant")
                .accessibilityLabel(dormantLine(pin))
                .accessibilityHint("Zeigt deine geheftete Wahl und die passenden Angebote")
        } else {
            text.accessibilityIdentifier("list.pin.dormant")
        }
    }

    /// Der Satz über der Kachel. Er sagt in beiden Fällen zuerst, **was fehlt**
    /// — und dann, was stattdessen dasteht, damit der Rückfall kein stiller
    /// ist.
    private func dormantLine(_ pin: PinnedOffer) -> String {
        suggestion.match == nil
            ? "\(pin.absenceLine) — und sonst passt diese Woche nichts."
            : "\(pin.absenceLine). Solange steht hier das billigste:"
    }

    @ViewBuilder
    private var suggestionTile: some View {
        if let match = suggestion.match {
            Button(action: { onShowMatches?() }) {
                suggestionContent(match.offer)
                    // Screen background as nested fill: reads as "recessed into
                    // the row" and stays in the brand palette instead of system gray.
                    .padding(Theme.Spacing.sm)
                    .background(
                        Theme.background,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.inner, style: .continuous)
                            .strokeBorder(Theme.stroke)
                    )
            }
            .buttonStyle(TactileButtonStyle())
            // See MarketPickerView.marketRow: `.accessibilityElement(children:
            // .ignore)` on a Button drops the label that follows it, so the tile
            // was read out as its raw parts instead of one sentence.
            .accessibilityLabel(suggestionSummary(match))
            .accessibilityHint("Zeigt alle passenden Angebote")
            // Stable handle for the UI journeys — the label is a whole
            // sentence built from whatever offer happens to match.
            .accessibilityIdentifier("list.matches")
            .tutorialAnchor(.rowMatch, when: carriesTutorialAnchors)
        } else if !hasMarkets {
            // Trägt den Anker, obwohl hier nichts anzutippen ist: Ohne ihn
            // überspringt sich der Rahmen, der erklärt, **was** an dieser
            // Stelle einmal stehen wird — und genau das ist der Grund, Filialen
            // zu wählen. Der Rahmentext spricht dann dieselbe Zeitform, siehe
            // `TutorialStep.tour(hasMarkets:)`.
            Text("Sobald du Filialen gewählt hast, steht hier das günstigste Angebot.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tutorialAnchor(.rowMatch, when: carriesTutorialAnchors)
        } else {
            emptyNotice
        }
    }

    /// Die Zeile ohne Treffer — **und ab jetzt der Weg ins Trefferblatt.**
    ///
    /// Sie war ein nackter `Text`, und damit war ausgerechnet der Bildschirm
    /// unerreichbar, auf dem die Frage brennt: Ohne Kachel gibt es nichts
    /// anzutippen, also kam man an den Kopf mit „verstanden als …" nie heran.
    /// Dieselbe Sackgasse wie beim schlafenden Pin — und dieselbe Lösung: Der
    /// Hinweis ist selbst der Knopf.
    @ViewBuilder
    private var emptyNotice: some View {
        let lines = ["Diese Woche nirgends im Angebot"] + (unknownWordNote.map { [$0] } ?? [])
        // Abstand statt der üblichen 2 pt: Ohne ihn lasen sich die zwei Sätze
        // als einer, der mitten drin die Richtung wechselt — am Simulator
        // gesehen, nicht überlegt.
        let text = VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if let onShowMatches {
            Button(action: onShowMatches) { text }
                .buttonStyle(TactileButtonStyle())
                .accessibilityIdentifier("list.matches.empty")
                .accessibilityLabel(lines.joined(separator: ". "))
                .accessibilityHint("Zeigt, als was Le Chariot dein Wort verstanden hat")
        } else {
            text.accessibilityIdentifier("list.matches.empty")
        }
    }

    /// At accessibility sizes the price no longer fits beside a truncated
    /// product name; stack the tile instead of shrinking it to nothing.
    @ViewBuilder
    private func suggestionContent(_ offer: Offer) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    OfferThumbnail(
                        imageUrl: offer.imageUrl, emoji: offer.emoji,
                        category: offer.category, title: offer.product, size: 32
                    )
                    offerText(offer, lineLimit: nil)
                    Spacer(minLength: 0)
                }
                HStack(spacing: Theme.Spacing.sm) {
                    if let discount = offer.discountPercent {
                        DiscountBadge(percent: discount)
                    }
                    if let price = offer.price {
                        PriceText(amount: price)
                    }
                }
            }
        } else {
            HStack(spacing: Theme.Spacing.sm) {
                OfferThumbnail(
                        imageUrl: offer.imageUrl, emoji: offer.emoji,
                        category: offer.category, title: offer.product, size: 32
                    )
                // Two lines: real product names ("Landliebe Butter Original")
                // truncated to "Landliebe B…" at one line, which is not enough
                // to tell whether the match is right.
                offerText(offer, lineLimit: 2)
                Spacer(minLength: Theme.Spacing.sm)
                if let discount = offer.discountPercent {
                    DiscountBadge(percent: discount)
                }
                if let price = offer.price {
                    PriceText(amount: price)
                }
            }
        }
    }

    private func offerText(_ offer: Offer, lineLimit: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(offer.product)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(lineLimit)
            HStack(spacing: 4) {
                // Die Heftung steht in derselben Zeile wie der Markt, weil sie
                // dieselbe Frage beantwortet: **woher** kommt das hier. Ein
                // eigenes Abzeichen daneben wäre eine dritte Zeile in einer
                // Kachel, die schon Bild, Name, Rabatt und Preis trägt.
                if suggestion.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.accent)
                    Text("Deine Wahl ·")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                Text(offer.market)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    /// One VoiceOver utterance for the suggestion tile: product, price,
    /// discount and market.
    private func suggestionSummary(_ match: OfferMatch) -> String {
        let offer = match.offer
        // „Günstigstes Angebot" wäre bei einer Heftung schlicht falsch — sie
        // ist ja meistens genau das nicht.
        var parts = [(suggestion.isPinned ? "Deine Wahl: " : "Günstigstes Angebot: ") + offer.product]
        if let price = offer.price {
            parts.append(price.formatted(.currency(code: "EUR")))
        }
        if let discount = offer.discountPercent {
            parts.append("\(discount) Prozent reduziert")
        }
        parts.append("bei \(offer.market)")
        return parts.joined(separator: ", ")
    }
}

#Preview {
    List {
        ShoppingListRowView(
            item: ShoppingItem(text: "Milch"),
            suggestion: ItemSuggestion(
                match: OfferMatch(offer: MockFixtures.offers[0], kind: .direct)
            ),
            onToggle: {}
        )
        ShoppingListRowView(
            item: ShoppingItem(text: "Käse", pinned: MockFixtures.offers[2].asPin),
            suggestion: ItemSuggestion(
                match: OfferMatch(offer: MockFixtures.offers[2], kind: .direct),
                isPinned: true
            ),
            onToggle: {}
        )
        ShoppingListRowView(
            item: ShoppingItem(text: "Käse"),
            suggestion: ItemSuggestion(
                match: OfferMatch(offer: MockFixtures.offers[0], kind: .category),
                dormantPin: PinnedOffer(
                    marketKey: "netto-01219-1", market: "Netto",
                    product: "GRÜNLÄNDER Schnittkäse"
                )
            ),
            onToggle: {}
        )
        ShoppingListRowView(item: ShoppingItem(text: "Zahnpasta"), onToggle: {})
        ShoppingListRowView(
            item: ShoppingItem(text: "Orangen", isChecked: true),
            onToggle: {}
        )
    }
}
