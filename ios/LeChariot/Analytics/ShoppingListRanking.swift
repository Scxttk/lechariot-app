import Foundation

/// One list item paired with the offer a market has for it. Carries the whole
/// `OfferMatch` rather than just the offer, so callers that reuse this as the
/// row suggestion keep the true direct-vs-category kind instead of guessing.
struct RankedItemMatch: Equatable, Identifiable {
    let item: String
    let match: OfferMatch
    /// Ob dieses Angebot die geheftete Wahl ist und nicht das billigste.
    var isPinned: Bool = false

    var offer: Offer { match.offer }
    var id: String { item }
}

/// Ein Artikel, dessen geheftete Wahl es bei **dieser** Kette nicht gibt.
///
/// Eigener Topf statt `missingItems`, weil die zwei Sätze verschieden sind:
/// „Lidl hat diese Woche keinen Käse im Angebot" und „Lidl hat Käse, aber nicht
/// deinen" sind für jemanden, der einen Einkauf plant, nicht dasselbe.
struct PinnedElsewhere: Equatable, Identifiable {
    let item: String
    let pin: PinnedOffer

    var id: String { item }
    /// Wie die Karte die Zeile schreibt: „Käse — GRÜNLÄNDER bei Netto".
    var line: String { "\(item) — \(pin.product) bei \(pin.market)" }
}

/// One market's result for the current shopping list: which of the open items
/// it covers with offers, which it does not, and what the matched offers add
/// up to.
struct MarketListRank: Equatable, Identifiable {
    let chain: String
    /// Covered items with the cheapest offer each, in list order.
    let matchedItems: [RankedItemMatch]
    /// Items this market has nothing for, in list order.
    let missingItems: [String]
    /// Artikel, deren geheftete Wahl bei einer anderen Kette liegt.
    var pinnedElsewhere: [PinnedElsewhere] = []
    /// Sum over the cheapest priced match per item; nil when no match has a price.
    let total: Double?

    var id: String { chain }
    var matchedCount: Int { matchedItems.count }
    var itemCount: Int {
        matchedItems.count + missingItems.count + pinnedElsewhere.count
    }
    /// Ob in dieser Wertung eine geheftete Wahl steckt — die Karte erklärt dann
    /// ihre Summe anders.
    var hasPinnedItems: Bool {
        matchedItems.contains(where: \.isPinned) || !pinnedElsewhere.isEmpty
    }
}

/// Ranking of the chosen branches for the shopping list. Coverage beats price:
/// a market matching 5/6 items always ranks above one matching 2/6, however
/// cheap the 2 are. Price only breaks coverage ties. The totals compare offer
/// prices only — items without a matched offer contribute nothing, so this is
/// "cheapest for the matched offers", not a full-basket price.
///
/// **Eine geheftete Wahl zählt mit — mit ihrem Preis und in der Abdeckung.**
/// Sonst rechnet die Karte einen Einkauf aus, den der Nutzer nicht macht: Wer
/// den GRÜNLÄNDER für 0,99 € will, spart die 0,69 € des Speck-Käse-Twisters
/// eben nicht. Die Regel dazu hat zwei Hälften, und beide sind nötig:
///
/// 1. **Solange es das geheftete Produkt diese Woche irgendwo gibt, gilt die
///    Wahl** — und nur die Kette, die es führt, deckt den Artikel ab. Die
///    anderen landen in `pinnedElsewhere` statt in `missingItems`, damit die
///    Karte den Unterschied aussprechen kann. Damit **kann** eine Heftung den
///    günstigsten Markt kippen; das ist gewollt und wird in der Karte gesagt
///    (siehe `winnerWithoutPins`).
/// 2. **Ist das Produkt diese Woche nirgends im Angebot, schläft die Heftung**
///    und es zählt wieder das billigste. Alles andere hieße, dass ein Artikel,
///    dessen Wahl ausgelaufen ist, überall als unabgedeckt gilt — eine
///    Abdeckungszahl, die von einem verschwundenen Prospekt erzählt statt vom
///    Einkauf. Die Zeile in der Liste sagt trotzdem, dass die Wahl gerade nicht
///    zu haben ist; still ist der Rückfall nie.
enum ShoppingListRanking {
    static func rank(
        items: [ShoppingItem],
        offers: [Offer],
        chains: [String],
        isRejected: (String, Offer) -> Bool = { _, _ in false }
    ) -> [MarketListRank] {
        guard !items.isEmpty else { return [] }
        let byChain = Dictionary(grouping: offers, by: \.market)
        // Hälfte 2 der Regel, einmal für alle Ketten: Welche Heftungen gibt es
        // diese Woche überhaupt? Die Frage ist eine über die Woche, nicht über
        // den Markt — sie darf deshalb nicht je Kette beantwortet werden.
        let livingPins = livingPins(items: items, offers: offers)

        return chains
            .map { chain -> MarketListRank in
                let chainOffers = byChain[chain] ?? []
                var matched: [RankedItemMatch] = []
                var missing: [String] = []
                var elsewhere: [PinnedElsewhere] = []
                var total: Double?

                func count(_ offer: Offer) {
                    if let price = offer.price { total = (total ?? 0) + price }
                }

                for item in items {
                    // `query`, nicht `text`: Die Angabe am Artikel (L-5a) ist eine
                    // Notiz und darf die Abdeckungszahl nicht bewegen.
                    // Mehrere Heftungen sind mehrere **Positionen**: „Milch"
                    // mit Bio-Milch und normaler Milch kostet beides. Eine
                    // Kette, die nur eine davon führt, deckt auch nur eine —
                    // untergeschoben wird weiterhin nichts.
                    let pins = livingPins[item.id] ?? []
                    if !pins.isEmpty {
                        for pin in pins {
                            guard let offer = ShoppingListMatcher.pinnedOffer(pin, in: chainOffers)
                            else {
                                elsewhere.append(PinnedElsewhere(item: item.query, pin: pin))
                                continue
                            }
                            matched.append(RankedItemMatch(
                                item: item.query,
                                match: OfferMatch(
                                    offer: offer,
                                    kind: ShoppingListMatcher.kind(of: offer, for: item.query)
                                ),
                                isPinned: true
                            ))
                            count(offer)
                        }
                        continue
                    }

                    guard let match = ShoppingListMatcher.cheapestMatch(
                        for: item.query, in: chainOffers,
                        isRejected: { isRejected(item.query, $0) }
                    ) else {
                        missing.append(item.query)
                        continue
                    }
                    matched.append(RankedItemMatch(item: item.query, match: match))
                    count(match.offer)
                }
                return MarketListRank(
                    chain: chain, matchedItems: matched,
                    missingItems: missing, pinnedElsewhere: elsewhere, total: total
                )
            }
            .sorted { lhs, rhs in
                if lhs.matchedCount != rhs.matchedCount {
                    return lhs.matchedCount > rhs.matchedCount
                }
                let l = lhs.total ?? .infinity, r = rhs.total ?? .infinity
                if l != r { return l < r }
                return lhs.chain < rhs.chain
            }
    }

    /// Welche Kette gewönne, wenn nichts geheftet wäre — `nil`, wenn die
    /// Heftungen am Sieger nichts ändern.
    ///
    /// Die Karte darf das aussprechen dürfen: Eine Heftung, die den
    /// empfohlenen Markt kippt, ist eine Folge, die man selbst ausgelöst hat,
    /// und niemand sollte sie erraten müssen. Gerechnet wird durch echtes
    /// Zweitranking statt durch eine Abschätzung — die Regel oben hat zwei
    /// Hälften und eine Abdeckungswirkung, die kein Preisvergleich nachbildet.
    /// - Parameter currentWinner: Der Sieger **mit** Heftungen, wenn er schon
    ///   bekannt ist. Die Ansicht hat ihn immer; ihn nicht durchzureichen hieße,
    ///   dieselbe Rangfolge in jedem Bilddurchlauf ein drittes Mal zu rechnen.
    static func winnerWithoutPins(
        items: [ShoppingItem],
        offers: [Offer],
        chains: [String],
        currentWinner: String? = nil,
        isRejected: (String, Offer) -> Bool = { _, _ in false }
    ) -> String? {
        guard items.contains(where: { !$0.pinnedOffers.isEmpty }) else { return nil }
        let sieger = currentWinner
            ?? rank(items: items, offers: offers, chains: chains, isRejected: isRejected).first?.chain
        let ohne = items.map { item -> ShoppingItem in
            var kopie = item
            kopie.pins = nil
            return kopie
        }
        let ohneHeftung = rank(items: ohne, offers: offers, chains: chains, isRejected: isRejected)
        guard let sieger, let anderer = ohneHeftung.first?.chain, sieger != anderer else {
            return nil
        }
        return anderer
    }

    /// Die Heftungen, deren Produkt diese Woche irgendwo im Vorrat steht.
    private static func livingPins(
        items: [ShoppingItem],
        offers: [Offer]
    ) -> [UUID: [PinnedOffer]] {
        var living: [UUID: [PinnedOffer]] = [:]
        for item in items {
            let alive = item.pinnedOffers.filter {
                ShoppingListMatcher.pinnedOffer($0, in: offers) != nil
            }
            if !alive.isEmpty { living[item.id] = alive }
        }
        return living
    }
}

// MARK: - Der Plan, einmal je Änderung

/// **Die Wertung ist teuer, und der Rumpf ruft sie mehrfach** — dieser Merker
/// steht dazwischen.
///
/// Gemessen am 11.08. (`TippKostenProbe`, Debug/Simulator, 1 200 Prospektzeilen,
/// fünf Artikel, drei Ketten): **42 ms je `rank`-Aufruf** — und 52 ms, wenn
/// nebenher eine zweite Sitzung baut. Im Rumpf von
/// `ShoppingListView` hängen drei Leser daran — `listBody`, `openGroups` und
/// `firstMatchArrived` —, und ein Rumpf läuft bei **jeder** Zustandsänderung:
/// jeder Haken, jeder Buchstabe im Eingabefeld, jedes Blatt, jeder Tab-Wechsel.
/// Ein Tipp kostete damit ein Mehrfaches der Wertung, und das ist genau die
/// „Verzögerung bei jedem Antippen", die das Messwerkzeug meldete
/// ([#138](https://github.com/Scxttk/lechariot-app/issues/138)).
///
/// **Der Merker rechnet nur neu, wenn sich eine Eingabe geändert hat**, und
/// „Eingabe" heißt hier genau das, was `rank` liest: die offenen Artikel mit
/// ihren Heftungen, der Vorrat, die Ketten, die Ablehnungen. Was davon nicht im
/// Schlüssel steht, wäre ein stehengebliebener Plan — deshalb steht der
/// Schlüssel neben der Funktion, die er schützt, und nicht in der Ansicht.
///
/// **Der Vorrat steht als Kennung im Schlüssel, nicht als Feld.** Zwei
/// Prospekte auf Gleichheit zu prüfen kostet selbst über tausend Vergleiche.
/// Die Kennung ist `OfferStore.generation`, ein Zähler über jede Zuweisung an
/// `offers`. Zeitpunkt plus Zeilenzahl waren der erste Entwurf und **wären
/// falsch gewesen**: Wer die Filiale wechselt, bekommt aus dem Cache denselben
/// `fetchedAt`, und die Zeilenzahl kann dieselbe sein — der Plan hätte auf die
/// alte Filiale gezeigt.
///
/// **Kein `@Observable`.** Der Merker wird *aus dem Rumpf heraus* beschrieben.
/// Beobachtete Eigenschaften wären damit eine Änderung während des Zeichnens
/// und würden den nächsten Rumpf auslösen — eine Schleife. Hier wird nichts
/// beobachtet: Die Ansicht liest ihn, wo sie vorher die Funktion gerufen hat.
@MainActor
final class ShoppingListPlan {
    private struct ItemKey: Equatable {
        let id: UUID
        let query: String
        let pins: [PinnedOffer]
    }

    private struct Key: Equatable {
        let items: [ItemKey]
        let offerGeneration: Int
        let chains: [String]
        let rejections: Set<String>
    }

    private var key: Key?
    private var value: [MarketListRank] = []

    /// Wie oft wirklich gerechnet wurde — nur für die Tests, die genau das
    /// zusichern (`ShoppingListPlanTests`).
    private(set) var berechnungen = 0

    /// Ob der Merker abgeschaltet ist. Nur im Messlauf, siehe
    /// `UITestSupport.bypassesPlanMemo` — im Release-Bauwerk gibt es die Stelle
    /// nicht, und damit auch keinen Weg, sie versehentlich anzuschalten.
    private static var bypasses: Bool {
        #if DEBUG
        UITestSupport.bypassesPlanMemo
        #else
        false
        #endif
    }

    func ranks(
        items: [ShoppingItem],
        offers: [Offer],
        offerGeneration: Int,
        chains: [String],
        rejections: Set<String>,
        isRejected: (String, Offer) -> Bool
    ) -> [MarketListRank] {
        let neu = Key(
            items: items.map { ItemKey(id: $0.id, query: $0.query, pins: $0.pinnedOffers) },
            offerGeneration: offerGeneration,
            chains: chains,
            rejections: rejections
        )
        if neu == key, !Self.bypasses { return value }
        key = neu
        berechnungen += 1
        value = ShoppingListRanking.rank(
            items: items, offers: offers, chains: chains, isRejected: isRejected
        )
        return value
    }
}
