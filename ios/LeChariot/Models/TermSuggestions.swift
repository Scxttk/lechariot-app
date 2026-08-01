import Foundation

/// **Beim Tippen ein Raster aus Wörtern, die der Matcher wirklich versteht.**
///
/// L-4 aus [[Le Chariot Liste-Konzept]]: „Das Tippen führt zum Raster." Wer
/// „mil" tippt, bekommt Milch, Buttermilch, Hafermilch, Kondensmilch — und
/// tippt damit nicht länger gegen ein Wörterbuch an, das er nicht sehen kann.
///
/// **Zwei Regeln, und beide sind der ganze Punkt:**
///
/// 1. **Nur Wörter aus dem Wörterbuch.** Ein `match_key` und seine Synonyme
///    sind konstruktionsbedingt das, was `OfferMatcher` wiederfindet. Ein Tipp
///    auf eine Kachel kann deshalb nicht ins Leere laufen, weil die App das
///    Wort nicht kennt — genau der Fall, der „vegan Schnitzel" zehn Tage lang
///    versteckt hat.
/// 2. **Nur Wörter, die *diese Woche* etwas treffen.** Ein Raster, das
///    „Kondensmilch" anbietet, obwohl in keiner gewählten Filiale welche im
///    Prospekt steht, ist eine Kachel, die man antippt und dann „Diese Woche
///    nirgends im Angebot" liest. Das Versprechen der Kachel ist, dass etwas
///    dahinter ist.
///
/// **Die Vorschau ist kein zweiter Matcher.** Geprüft wird gegen dieselben zwei
/// Stufen, die `OfferMatcher` fährt — Titel-Token und `match_key` —, nur
/// vorberechnet statt je Wort einmal durch alle Angebote. Ein Vorschlag, der
/// nach einer anderen Regel entsteht als die Suche danach, ist ein Vorschlag,
/// der irgendwann ins Leere zeigt.
enum TermSuggestions {

    /// Wie viele Kacheln höchstens.
    ///
    /// Die Reihe scrollt zur Seite, die Zahl kostet also keine Bildschirmhöhe —
    /// sie ist eine Grenze gegen das Suchen, nicht gegen den Platz. Gemessen am
    /// Wörterbuch (Stand `b063fa0`): Ein Präfix aus zwei bis vier Zeichen kennt
    /// typischerweise 1 bis 6 Wörter, im schlimmsten gemessenen Fall 25
    /// („sch"). Wer nach acht Kacheln nicht dabei ist, tippt weiter — das ist
    /// schneller als 25 Kacheln zu lesen.
    static let limit = 8

    /// Die Vorschläge zum getippten Text.
    ///
    /// - Parameters:
    ///   - typed: der rohe Feldinhalt. Gewertet wird sein **letztes** Wort:
    ///     Wer „bio mil" tippt, meint mit „mil" das nächste Wort, nicht die
    ///     ganze Anfrage.
    ///   - offers: der Vorrat der gewählten Filialen.
    static func words(for typed: String, in offers: [Offer]) -> [String] {
        // **Ein einzelner Buchstabe schlägt nichts vor, und diese Regel steht
        // nicht hier.** `OfferMatcher.tokens` wirft Wörter unter zwei Zeichen
        // weg — das Raster erbt sie damit von der Suche selbst, statt sie ein
        // zweites Mal zu formulieren. Eine eigene Grenze hier wäre eine zweite
        // Regel, die eines Tages von der ersten abweicht. (Zuerst stand hier
        // `prefix.count >= 2`; die Gegenprobe zeigte, dass sie nie greift.)
        let prefix = OfferMatcher.tokens(typed).last ?? ""
        guard !prefix.isEmpty else { return [] }

        let reachable = reachableVocabulary(in: offers)
        let candidates = MatchDictionary.words(startingWith: prefix).filter { word in
            // Erreichbar heißt: über den Tag (Stufe 2) oder wörtlich im Titel
            // (Stufe 1). Beide Wege zählen, weil beide der Matcher geht.
            reachable.tags.contains(where: { MatchDictionary.terms(forToken: word).contains($0) })
                || reachable.titleTokens.contains(word)
        }

        // Das genau getippte Wort zuerst, dann das kürzeste — „Milch" vor
        // „Buttermilch" vor „Kondensmilch". Bei gleicher Länge alphabetisch,
        // damit die Reihenfolge nicht an der Reihenfolge der Angebotszeilen
        // hängt.
        return candidates
            .sorted {
                ($0 == prefix ? 0 : 1, $0.count, $0) < ($1 == prefix ? 0 : 1, $1.count, $1)
            }
            .prefix(limit)
            .map(QueryUnderstanding.display)
    }

    /// Was der Vorrat dieser Woche überhaupt hergibt — einmal gerechnet statt
    /// je Kandidat.
    private static func reachableVocabulary(
        in offers: [Offer]
    ) -> (tags: Set<String>, titleTokens: Set<String>) {
        var tags: Set<String> = []
        var titleTokens: Set<String> = []
        for offer in offers {
            tags.formUnion(offer.matchKeys)
            titleTokens.formUnion(OfferMatcher.tokens(offer.product))
        }
        return (tags, titleTokens)
    }
}
