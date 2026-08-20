import Foundation

/// How a shopping-list entry matched an offer.
enum MatchKind: Equatable {
    /// Stage 1: the query tokens appear in the product title (typo-tolerant).
    case direct
    /// Stage 2: the query names a dictionary term and the offer carries that
    /// `match_key` tag from the backend import.
    case category
}

struct OfferMatch: Equatable, Identifiable {
    let offer: Offer
    let kind: MatchKind
    var id: String { offer.id }
}

/// Two-stage matching of free-text list entries against the cached offers.
///
/// Stage 1 (direct): every query token must hit a product-title token —
/// exactly, or with Levenshtein distance ≤ 1 when both tokens have ≥ 5
/// characters, different lengths, and the same first three letters (catches
/// dropped letters and singular/plural, but keeps short words strict so
/// "Käse" never fuzzy-matches "Kekse", same-length words exact so "Butter"
/// never hits "Bitter", and a changed word start out so "Fisch" never hits
/// "Frisch").
///
/// Stage 2 (category): a query token that the title does not carry may still
/// be satisfied by the offer's `match_key` tags — either by tag equality, or
/// through `MatchDictionary`, which maps the *word the user typed* to the
/// terms it means ("Fleischersatz" → `tofu`). The tags come from the backend
/// dictionary, which already blocks false composites (Tomatenmark carries no
/// "tomaten" tag), so tag equality is safe without extra filtering.
///
/// **Und über beide Stufen bleibt UND.** Ein Angebot passt nur, wenn *jedes*
/// Suchwort erfüllt ist — egal ob über Titel oder Tag. Vorher war Stufe 2 ein
/// ODER, und genau daran hing der gemeldete Fall: „vegan Schnitzel" hätte mit
/// Synonym-Abbildung und ODER **Schweineschnitzel** geliefert, weil
/// „schnitzel" auf `schwein` zeigt. Für die Melderin ist das schlechter als
/// die leere Liste, die sie bekommen hat. Entschieden am 2026-07-31.
///
/// Der Preis dieser Wahl: Ein zweites Suchwort, das weder im Titel steht noch
/// im Wörterbuch, macht die Anfrage leer, statt sie auf das erste Wort zu
/// verkürzen. Das ist gewollt — eine Liste, die die halbe Anfrage ignoriert,
/// sieht aus wie ein Treffer und ist keiner.
enum OfferMatcher {
    /// Lowercase, drop ®*™, hyphens and any non-letter → space. Umlauts stay.
    static func normalize(_ text: String) -> String {
        String(
            text.lowercased().map { ch in
                ch.isLetter ? ch : " "
            }
        )
    }

    static func tokens(_ text: String) -> [String] {
        normalize(text).split(separator: " ").map(String.init).filter { $0.count >= 2 }
    }

    /// Wie viele Zeichen am Wortanfang übereinstimmen müssen, damit ein
    /// eingefügter Buchstabe noch als Tippfehler durchgeht.
    private static let sharedPrefixForTypo = 3

    /// Token equality with typo tolerance for longer tokens. Fuzziness only
    /// applies when the lengths differ (a dropped or doubled letter, or
    /// singular/plural) — a same-length substitution turns one word into
    /// another ("Butter" is not "Bitter", real user report 2026-07-21).
    ///
    /// **Und der Anfang muss stehen.** Verschiedene Länge bei Distanz 1 heißt
    /// genau ein eingefügter Buchstabe; wo er steht, entscheidet alles. Hinten
    /// ist es der Plural („Tomate"/„Tomaten"), in der Mitte ein verschluckter
    /// Buchstabe („limbuger"/„Limburger") — **vorn ist es ein anderes Wort**.
    /// „fisch"/„frisch" hat neun Fehltreffer der Feedback-Runde vom 2026-08-05
    /// erzeugt (Sensodyne „Extra Frisch", Gutfried, Bettine, FUNNY-FRISCH,
    /// WC-FRISCH), „lachs"/„flachs" ist dieselbe Form. Drei gemeinsame
    /// Anfangszeichen sperren das, ohne einen der gewollten Fälle zu kosten.
    static func tokensMatch(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard a.count >= 5, b.count >= 5, a.count != b.count else { return false }
        guard sharedPrefixLength(a, b) >= sharedPrefixForTypo else { return false }
        return levenshtein(a, b) <= 1
    }

    /// Länge des gemeinsamen Wortanfangs, gedeckelt bei
    /// `sharedPrefixForTypo` — mehr will niemand wissen.
    private static func sharedPrefixLength(_ a: String, _ b: String) -> Int {
        var n = 0
        for (x, y) in zip(a, b) {
            if x != y { break }
            n += 1
            if n == sharedPrefixForTypo { break }
        }
        return n
    }

    /// Plain Levenshtein distance; early-outs when lengths differ by > 1
    /// because callers only care about distance ≤ 1.
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let s = Array(a), t = Array(b)
        if abs(s.count - t.count) > 1 { return abs(s.count - t.count) }
        var prev = Array(0...t.count)
        var curr = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            curr[0] = i
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[t.count]
    }

    /// Alle Treffer einer Anfrage — **geordnet danach, was das Produkt ist,
    /// nicht danach, wie es gefunden wurde** (#106).
    ///
    /// Bis zum 20.08. standen alle Titeltreffer über allen Tag-Treffern. Das
    /// las sich wie eine Rangfolge und war eine Mechanik: Am 01.08. stand ein
    /// **Gebäckartikel** mit „Käse" im Namen über dem Schnittkäse, der das Wort
    /// nur zusammengeschrieben trägt. Ein Wort im Titel ist das **schwächere**
    /// Signal — das Wörterbuch hat den Titel schon durch alle Sperr- und
    /// Kompositaregeln geschickt, der rohe Name hat sie noch vor sich.
    ///
    /// Zuerst kommt deshalb, was **in das Regal des gesuchten Begriffs gehört**
    /// („Käse" → Molkerei & Eier), danach entscheidet der Preis. Kennt das
    /// Wörterbuch die Anfrage nicht — Markennamen, Fantasiewörter —, gibt es
    /// kein Regal und damit nichts zu ordnen: dann zählt allein der Preis, wie
    /// vorher.
    ///
    /// **Der Fundweg verschwindet nicht, er behauptet nur nichts mehr.** Welche
    /// Zeile über den Namen und welche über das Wörterbuch kam, steht weiter in
    /// `kind` und wird in der Zeile genannt (`QueryUnderstanding.rowNote`).
    ///
    /// Ein Angebot erscheint höchstens einmal — ein Titeltreffer wird nie als
    /// Tag-Treffer wiederholt.
    static func matches(for query: String, in offers: [Offer]) -> [OfferMatch] {
        let queryTokens = tokens(query)
        guard !queryTokens.isEmpty else { return [] }

        // Einmal vorab statt je Angebot: die Begriffe, die jedes Suchwort
        // meinen kann, und die der ganzen Anfrage als Wendung
        // („crème fraîche" → `sahne`, einzeln wäre „creme" nichts).
        let termsPerToken = queryTokens.map { MatchDictionary.terms(forToken: $0) }
        let phraseTerms = MatchDictionary.terms(forPhrase: normalize(query))

        var direct: [Offer] = []
        var category: [Offer] = []
        for offer in offers {
            let productTokens = tokens(offer.product)
            var viaTitleOnly = true
            var allSatisfied = true

            for (index, q) in queryTokens.enumerated() {
                if productTokens.contains(where: { tokensMatch(q, $0) }) { continue }
                // Ab hier trägt der Titel dieses Wort nicht mehr — dann ist es
                // kein Direkttreffer mehr, auch wenn die Tags einspringen.
                viaTitleOnly = false
                let terms = termsPerToken[index]
                let satisfiedByTag = offer.matchKeys.contains { tag in
                    tokensMatch(q, tag) || terms.contains(tag)
                }
                if !satisfiedByTag {
                    allSatisfied = false
                    break
                }
            }

            if allSatisfied {
                if viaTitleOnly { direct.append(offer) } else { category.append(offer) }
            } else if !phraseTerms.isEmpty,
                      offer.matchKeys.contains(where: { phraseTerms.contains($0) }) {
                // Die Anfrage ist als Ganzes ein Synonym, auch wenn ihre
                // einzelnen Wörter es nicht sind.
                category.append(offer)
            }
        }

        func byPrice(_ lhs: Offer, _ rhs: Offer) -> Bool {
            let l = lhs.price ?? .infinity, r = rhs.price ?? .infinity
            if l != r { return l < r }
            // Same price: prefer the better base price when known.
            return (lhs.basePrice ?? .infinity) < (rhs.basePrice ?? .infinity)
        }

        // Das Regal, das die Anfrage meint — leer, wenn das Wörterbuch sie
        // nicht kennt. Dann bleibt jede Zeile gleich weit vom Gesuchten weg
        // und der Preis ordnet allein.
        let regal = ShoppingSections.warengruppe(forItem: query)
        func gehörtInsRegal(_ offer: Offer) -> Bool {
            guard let regal else { return true }
            return offer.category == regal
        }

        let alle = direct.map { OfferMatch(offer: $0, kind: .direct) }
            + category.map { OfferMatch(offer: $0, kind: .category) }
        return alle.sorted { lhs, rhs in
            let l = gehörtInsRegal(lhs.offer), r = gehörtInsRegal(rhs.offer)
            if l != r { return l }
            if lhs.offer.price != rhs.offer.price || lhs.offer.basePrice != rhs.offer.basePrice {
                return byPrice(lhs.offer, rhs.offer)
            }
            // Gleiches Regal, gleicher Preis, gleicher Grundpreis: Swifts Sort
            // ist nicht stabil, und zwei Läufe derselben Liste dürfen nicht
            // zwei Reihenfolgen ergeben. Der Name entscheidet, damit es eine
            // gibt — nicht, weil er etwas über das Angebot sagt.
            return lhs.offer.product < rhs.offer.product
        }
    }
}
