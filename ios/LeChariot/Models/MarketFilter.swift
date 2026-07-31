import Foundation

/// Search filter for the cross-chain branch picker: case- and
/// diacritic-insensitive substring match on chain, branch name and PLZ.
enum MarketFilter {
    /// Markennamen, die hinter dem Kettennamen noch einmal die Kette nennen.
    ///
    /// „Netto Marken-Discount Dresden-Strehlen" heißt unter der Überschrift
    /// „Netto" nach dem Abschneiden der Kette „Marken-Discount
    /// Dresden-Strehlen" — der Rest ist immer noch Marke, nicht Ort. Bewusst
    /// eine kurze Liste und keine Heuristik: Was hier fehlt, wird höchstens
    /// nicht gekürzt, und das ist der harmlose Ausgang.
    private static let brandPrefixes = ["Marken-Discount"]

    /// Der Zeilentitel innerhalb eines Ketten-Abschnitts.
    ///
    /// Die Überschrift sagt bereits, welche Kette es ist; „REWE" über „REWE
    /// Friedrichstadt" schreibt denselben Namen zweimal untereinander und
    /// nimmt dem, was die Filialen tatsächlich unterscheidet, den Platz weg.
    /// Gemeldet am 2026-07-30 („Ketten-Header plus Zeile ist doppelt
    /// gemoppelt").
    ///
    /// Bleibt nach dem Kürzen nichts übrig, gewinnt der ursprüngliche Name:
    /// Eine Zeile ohne Titel wäre schlimmer als eine mit einem doppelten.
    static func branchLabel(name: String, chain: String) -> String {
        var rest = name.trimmingCharacters(in: .whitespaces)
        for prefix in [chain] + brandPrefixes {
            rest = stripLeading(prefix, from: rest)
        }
        return rest.isEmpty ? name : rest
    }

    /// Schneidet `prefix` vorn ab, samt der Trennzeichen dahinter. Diakritik-
    /// und Groß-/Kleinschreibung-unempfindlich, weil die Ketten ihre eigenen
    /// Namen unterschiedlich schreiben („ALDI SÜD" gegen „Aldi Süd").
    private static func stripLeading(_ prefix: String, from text: String) -> String {
        guard let range = text.range(
            of: prefix,
            options: [.caseInsensitive, .diacriticInsensitive, .anchored]
        ) else { return text }
        return text[range.upperBound...]
            .trimmingCharacters(in: CharacterSet(charactersIn: " -–,·").union(.whitespaces))
    }

    static func matches(_ market: Market, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return [market.chain, market.branchName, market.plz].contains {
            $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    static func filter(_ markets: [Market], query: String) -> [Market] {
        markets.filter { matches($0, query: query) }
    }
}
