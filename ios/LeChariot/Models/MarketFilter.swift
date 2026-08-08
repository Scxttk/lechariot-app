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

    // MARK: Zeilentitel, die sich unterscheiden

    /// Das Rohmaterial einer Zeile. `street` und `city` kommen aus dem
    /// Verzeichnis und fehlen, wenn die Zeile aus `markets` stammt.
    struct Row: Equatable {
        let id: String
        let name: String
        let chain: String
        var street: String?
        var city: String?

        init(id: String, name: String, chain: String, street: String? = nil, city: String? = nil) {
            self.id = id
            self.name = name
            self.chain = chain
            self.street = street
            self.city = city
        }
    }

    /// Titel für Zeilen, die **zusammen** angezeigt werden — der Punkt ist das
    /// „zusammen".
    ///
    /// **Gemeldet am 2026-07-31 von Scotts Gerät:** Unter „ALDI Nord" standen
    /// fünfundzwanzig Zeilen, alle mit dem Text „Dresden". `branchLabel`
    /// schneidet den Kettennamen ab, und in `branches` heißen alle
    /// fünfundzwanzig Dresdner ALDI-Nord-Filialen wörtlich „ALDI Nord Dresden".
    /// Übrig bleibt die Stadt, fünfundzwanzigmal.
    ///
    /// **An der Produktion nachgemessen, und der Befund ist größer als die
    /// Meldung.** In Dresden (113 Filialen, alle mit Straße):
    ///
    /// | Kette | Zeilen | verschiedene Namen |
    /// |---|---|---|
    /// | ALDI Nord | 25 | **1** |
    /// | Netto | 24 | **1** |
    /// | EDEKA | 14 | 12 |
    /// | Lidl | 22 | 21 |
    /// | REWE | 13 | 9 |
    /// | Kaufland | 9 | 9 |
    /// | Penny | 6 | 6 |
    ///
    /// **Fünf von sieben Ketten** haben Dubletten, nicht zwei — Lidl hat
    /// „Lidl Striesen-Süd" zweimal, REWE dreimal „Nahkauf" (eine Marke, nicht
    /// einmal ein Ort). Eine Regel, die nur auf „Titel gleich Stadt" prüft,
    /// hätte ALDI Nord, Netto und EDEKA erwischt und die anderen beiden Fälle
    /// stehen lassen.
    ///
    /// Deshalb entscheidet **Eindeutigkeit unter den gezeigten Zeilen**, nicht
    /// Gleichheit mit der Stadt. Der Stadtname ist nur der Sonderfall, der
    /// schon bei einer einzigen Zeile nichts sagt.
    ///
    /// Bleibt eine Dublette, weil keine Straße bekannt ist, bleibt sie stehen:
    /// Eine Zeile ohne Titel wäre schlimmer als eine doppelte.
    static func titles(for rows: [Row]) -> [String: String] {
        var chosen: [String: String] = [:]
        for row in rows {
            let base = branchLabel(name: row.name, chain: row.chain)
            // Stadtname allein sagt nichts, auch nicht bei einer einzigen
            // Zeile — „Dresden" unter „ALDI Nord" ist keine Filialangabe.
            chosen[row.id] = isSameText(base, row.city) ? (street(of: row) ?? base) : base
        }

        var seen: [String: Int] = [:]
        for title in chosen.values { seen[title.lowercased(), default: 0] += 1 }
        for row in rows {
            guard let title = chosen[row.id], seen[title.lowercased(), default: 0] > 1,
                  let street = street(of: row) else { continue }
            chosen[row.id] = street
        }
        return chosen
    }

    private static func street(of row: Row) -> String? {
        guard let street = row.street?.trimmingCharacters(in: .whitespaces),
              !street.isEmpty else { return nil }
        return street
    }

    private static func isSameText(_ lhs: String, _ rhs: String?) -> Bool {
        guard let rhs, !rhs.isEmpty else { return false }
        return lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
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

    // MARK: Beschriftungen des Wählers

    /// „1,2 km" — eine Nachkommastelle unter 10 km, keine darüber.
    ///
    /// `locale:` ist der Punkt: ohne es schreibt `String(format:)` einen Punkt
    /// statt des Kommas.
    static func distanceLabel(_ km: Double) -> String {
        km < 10
            ? String(format: "%.1f km", locale: .current, km)
            : String(format: "%.0f km", locale: .current, km)
    }

    /// Die Unterzeile einer Kettenzeile im Wähler: wie viele Filialen in
    /// Reichweite sind, wie weit die nächste ist, wie viele davon gewählt.
    ///
    /// Die Wahl steht zuletzt: Wer die Kette antippt, sucht eine Filiale — was
    /// er schon hat, steht am Ende des Wählers unter „Deine Filialen". Das
    /// „n gewählt" hier ist seit dem 08.08. die Stelle, an der die Auswahl auf
    /// der ersten Bildschirmhöhe **abzulesen** ist, ohne sie auszubreiten.
    static func chainSubtitle(
        branchCount: Int, selectedCount: Int, nearestKm: Double?
    ) -> String {
        // **Die Entfernung zuerst** (06.08.). Vorher führte die Filialzahl —
        // „24 Filialen · nächste 1,2 km". Beim Wählen einer Kette ist aber die
        // Frage „wie weit muss ich fahren", nicht „wie viele gibt es"; die
        // große Zahl vorn war der Grund, warum die Reichweite zu groß wirkte.
        var parts: [String] = []
        if let nearestKm { parts.append("nächste \(distanceLabel(nearestKm))") }
        parts.append(branchCount == 1 ? "1 Filiale" : "\(branchCount) Filialen")
        if selectedCount > 0 { parts.append("\(selectedCount) gewählt") }
        return parts.joined(separator: " · ")
    }
}
