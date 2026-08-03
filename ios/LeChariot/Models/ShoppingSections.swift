import Foundation

/// Ein Abschnitt der Einkaufsliste — „Obst & Gemüse", „Molkerei & Eier", …
struct ShoppingSection: Identifiable, Equatable {
    let category: String
    let items: [ShoppingItem]
    var id: String { category }
    var isRest: Bool { category == ShoppingSections.restName }
}

/// **Die Liste in Kategorie-Abschnitte, wie Bring! sie zeigt.**
///
/// Aus Scotts Video vom 03.08.: „Die Liste selbst ist in Kategorie-Abschnitte
/// sortiert (Obst & Gemüse, Brot & Gebäck, Milch & Käse, …); einsortiert wird
/// automatisch."
///
/// **Einsortiert wird mit dem, was schon da ist.** Ein Eintrag ist Freitext
/// („Butter") und trägt keine Kategorie — die kommt aus **seinem besten
/// Treffer**, also aus `OfferMatcher` und den fünfzehn Kategorien, die der
/// Import ohnehin an jede Angebotszeile schreibt. Kein zweites Wörterbuch,
/// keine zweite Zuordnung: Zwei Listen, die dasselbe wissen müssen, gehen
/// auseinander (siehe `Categories.hasSymbol`).
///
/// **Der Preis dieser Wahl, und er gehört genannt:** Ein Artikel, für den es
/// gerade kein Angebot gibt, hat keine Kategorie und landet im Restabschnitt —
/// und er kann den Abschnitt wechseln, wenn nächste Woche ein anderer Prospekt
/// kommt. Das ist der Unterschied zu Bring!, das einen festen Katalog mitbringt.
/// Ein eigener Katalog wäre die dritte Stelle, an der Warenkunde gepflegt wird;
/// dafür ist der Nutzen zu klein und die Pflegelast zu groß.
enum ShoppingSections {
    /// Wo die landen, für die es gerade nichts gibt. **Nicht „Sonstiges"** —
    /// das ist eine der fünfzehn echten Kategorien, und ein Artikel ohne
    /// Treffer ist nicht dasselbe wie einer, den der Prospekt als Sonstiges
    /// führt.
    static let restName = "Noch nicht einsortiert"

    /// Die Kategorie eines Eintrags: die seines besten Treffers.
    ///
    /// `ShoppingListMatcher.matches` liefert direkte Treffer vor
    /// Kategorietreffern, jeweils nach Preis — der erste ist also der, den die
    /// App diesem Artikel ohnehin zuerst anbietet. Eine eigene Wahl hier wäre
    /// eine zweite Meinung über dieselbe Frage.
    static func category(forMatches matches: [OfferMatch]) -> String? {
        guard let category = matches.first?.offer.category,
              !category.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return category
    }

    /// **Die Kategorien aus dem Plan, der ohnehin gerechnet ist** — Artikeltext
    /// → Kategorie.
    ///
    /// **Gemessen, und der erste Entwurf ist daran gescheitert:** Zuerst holte
    /// die Ansicht für *jeden* Artikel die volle `ItemSuggestion`, um an seine
    /// Kategorie zu kommen. Das sah billig aus, weil die Zeile dieselbe Auskunft
    /// ohnehin braucht — ist es aber nicht: Eine `List` baut nur die sichtbaren
    /// Zeilen, also zahlte vorher **nur der sichtbare Teil** für das Matching.
    /// Ein Abschnitt muss dagegen jeden Artikel kennen, auch den, der weit unten
    /// steht.
    ///
    /// Am Messgeschirr kostete das die Liste **das Doppelte an Scroll-Ausrollzeit
    /// (0,9 s → 1,8 s)** und rund ein Fünftel mehr Instruktionen — zweimal
    /// gemessen, gegen `a21779d` in derselben Sitzung.
    ///
    /// Deshalb kommt die Kategorie jetzt aus `ranks`: Dieser Lauf geht ohnehin
    /// über alle Artikel und alle Ketten, für die Plan-Karte. **Ein zweiter
    /// Durchgang über denselben Vorrat ist der Preis, den niemand bemerkt hätte.**
    static func categories(from ranks: [MarketListRank]) -> [String: String] {
        var byQuery: [String: String] = [:]
        for rank in ranks {
            for matched in rank.matchedItems where byQuery[matched.item] == nil {
                let category = matched.offer.category.trimmingCharacters(in: .whitespaces)
                if !category.isEmpty { byQuery[matched.item] = category }
            }
        }
        return byQuery
    }

    /// Die Abschnitte, in der Reihenfolge von `Categories.all`, Rest zuletzt.
    ///
    /// Innerhalb eines Abschnitts bleibt die Reihenfolge der Liste — wer seine
    /// Artikel in einer bestimmten Folge eintippt, soll sie darin wiederfinden.
    static func build(
        items: [ShoppingItem],
        category: (ShoppingItem) -> String?
    ) -> [ShoppingSection] {
        var byCategory: [String: [ShoppingItem]] = [:]
        for item in items {
            byCategory[category(item) ?? restName, default: []].append(item)
        }
        var sections = Categories.all.compactMap { name -> ShoppingSection? in
            guard let items = byCategory[name], !items.isEmpty else { return nil }
            return ShoppingSection(category: name, items: items)
        }
        // Der Rest steht hinten — und Kategorien, die der Import kennt, der
        // Zeichensatz hier aber nicht, gehen nicht verloren.
        let known = Set(Categories.all)
        for (name, items) in byCategory.sorted(by: { $0.key < $1.key })
        where !known.contains(name) && name != restName {
            sections.append(ShoppingSection(category: name, items: items))
        }
        if let rest = byCategory[restName], !rest.isEmpty {
            sections.append(ShoppingSection(category: restName, items: rest))
        }
        return sections
    }

    /// **Überschriften nur, wenn sie etwas trennen.**
    ///
    /// Eine frische Liste ohne Filialen hat keinen einzigen Treffer — dann
    /// stünde über der ganzen Liste „Noch nicht einsortiert", und das ist
    /// schlechter als gar keine Überschrift. Ermessensentscheidung vom 03.08.
    static func needsHeaders(_ sections: [ShoppingSection]) -> Bool {
        !(sections.count <= 1 && sections.first?.isRest != false)
    }
}

/// **„Passende Artikel im Angebot!" — die Zeile aus dem Video.**
///
/// Bring! stellt sie *in* die Liste, nicht in einen eigenen Reiter, mit
/// Ketten-Chips samt Zählern („Netto 15 · Penny 3"). Genau das ist der
/// interessante Teil: die **Platzierung**, nicht das Matching.
///
/// Und deshalb rechnet hier nichts nach: Die Zahlen stehen bereits in
/// `MarketListRank.matchedCount`, aus dem Lauf, den die Plan-Karte ohnehin
/// macht. Ein zweiter Durchlauf über dieselben Angebote wäre eine zweite
/// Wahrheit über dieselbe Frage.
struct OfferHitSummary: Equatable {
    struct ChainHits: Equatable, Identifiable {
        let chain: String
        let count: Int
        var id: String { chain }
    }

    let chains: [ChainHits]

    var total: Int { chains.reduce(0) { $0 + $1.count } }
    var isEmpty: Bool { chains.isEmpty }

    /// Aus der Wertung, die für die Plan-Karte ohnehin läuft.
    ///
    /// Ketten ohne Treffer bekommen **keinen** Chip: „Netto 15 · ALDI 0" liest
    /// sich wie ein Angebot, das keines ist, und die Zeile heißt „passende
    /// Artikel im Angebot".
    init(ranks: [MarketListRank]) {
        chains = ranks
            .filter { $0.matchedCount > 0 }
            .sorted { ($0.matchedCount, $1.chain) > ($1.matchedCount, $0.chain) }
            .map { ChainHits(chain: $0.chain, count: $0.matchedCount) }
    }
}
