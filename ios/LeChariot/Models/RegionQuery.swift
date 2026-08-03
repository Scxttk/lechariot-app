import Foundation

/// **Was jemand ins Regionsfeld getippt hat.**
///
/// Scotts Wunsch vom 02.08. aus Ahlbeck: „Anklam" tippen dürfen statt 17389.
/// Intern bleibt die PLZ der Suchschlüssel — diese Entscheidung sagt nur, ob
/// die Eingabe schon eine ist oder erst über Apples Geocoder zu einer wird.
///
/// Reine Rechnung über Zeichenketten wie `PlaceName`: Die Klassifikation ist
/// prüfbar, ohne dass jemand ein Netz braucht.
enum RegionQuery: Equatable {
    /// Fünf Ziffern — der Weg von vorher, unverändert.
    case postleitzahl(String)
    /// Ein Name, den Apple erst nachschlagen muss.
    case ortsname(String)
    /// Noch nichts, womit man suchen könnte.
    case zuKurz

    static func classify(_ raw: String) -> RegionQuery {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .zuKurz }

        // **Eine halbe PLZ ist kein Ortsname.** „0121" an den Geocoder zu
        // geben, liefert irgendeinen Treffer irgendwo — die Ziffernfolge sieht
        // für ihn aus wie eine Hausnummer. Wer Ziffern tippt, meint eine PLZ.
        if trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) {
            return PLZValidator.isValid(trimmed) ? .postleitzahl(trimmed) : .zuKurz
        }

        // Ein einzelner Buchstabe ist kein Ort, sondern ein Tippanfang.
        let letters = trimmed.filter { $0.isLetter }
        return letters.count >= 2 ? .ortsname(trimmed) : .zuKurz
    }
}

/// Ein Ort, den Apple auf eine Eingabe hin genannt hat — mit der PLZ, die
/// intern weiterläuft.
struct PlaceCandidate: Identifiable, Equatable, Hashable {
    let plz: String
    /// `locality`, also die Stadt.
    let ort: String
    /// `administrativeArea` — das Bundesland trennt die Neustädte voneinander.
    let land: String?

    var id: String { "\(plz)|\(ort)" }

    /// Was in der Auswahl steht: „Neustadt (Dosse), Brandenburg · 16845".
    var label: String {
        let ortMitLand = land.map { "\(ort), \($0)" } ?? ort
        return "\(ortMitLand) · \(plz)"
    }
}

/// **Trifft die Antwort überhaupt die Frage?**
///
/// Am 03.08. an Apple gemessen, und der Befund hat den Entwurf umgeworfen:
/// Auf „Neustadt" antwortet der Geocoder mit **Wolgast**, MapKit mit
/// **Neustadt (Dosse)** — je ein einziger Treffer, und die beiden sind sich
/// nicht einmal einig. Ein Feld, das daraufhin stillschweigend die PLZ von
/// Wolgast speichert, ist derselbe Fehler wie Ahlbeck → 17373 am 30.07.:
/// **eine Ableitung, die niemand zu sehen bekommt, kann niemand korrigieren.**
///
/// Diese Prüfung ist der Filter dagegen. Sie fragt nur eines: Steckt der
/// getippte Name in dem, was zurückkam? Wolgast fällt damit raus, „Titisee-
/// Neustadt" und „Neustadt/Vogtland" bleiben drin.
enum PlaceMatch {
    /// Schreibung und Diakritika zählen nicht — wer „Munchen" tippt, meint
    /// München, und wer „NEUSTADT" tippt, auch.
    static func answers(_ query: String, ort: String?, ortsteil: String?) -> Bool {
        let needle = fold(query)
        guard !needle.isEmpty else { return false }
        return [ort, ortsteil]
            .compactMap { $0 }
            .contains { fold($0).contains(needle) }
    }

    /// Aus mehreren Antworten die brauchbaren, ohne Dubletten.
    ///
    /// Doppelt heißt **gleiche PLZ**: Der Länder-Fächer fragt sechzehnmal, und
    /// mehrere Länder landen gern auf demselben Ort.
    static func usable(_ candidates: [PlaceCandidate]) -> [PlaceCandidate] {
        var seen: Set<String> = []
        return candidates.filter { seen.insert($0.plz).inserted }
    }

    private static func fold(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
