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

/// **Was gefragt ist, und was nur Kontext ist.**
///
/// Apples Vervollständiger antwortet nicht mit „Stuttgart", sondern mit
/// „Stuttgart, Baden-Württemberg, Deutschland" — und genau dieser Text ging bis
/// zum 11.08. als *Ortsname* in den Abgleich. Am 11.08. gemessen:
///
///     Frage an den Geocoder: „Stuttgart, Baden-Württemberg, Deutschland,
///     Deutschland" → locality Stuttgart, PLZ 70173 — **richtig**.
///     Danach `PlaceMatch.answers`: steckt „Stuttgart, Baden-Württemberg,
///     Deutschland" in „Stuttgart"? **Nein.** → Fächer über sechzehn Länder,
///     sechzehnmal dasselbe, am Ende „kennt Apple nicht als Ort".
///
/// Der Geocoder hat also nie versagt; unser eigener Filter hat seine richtige
/// Antwort verworfen. Deshalb wird die Eingabe hier zerlegt, **bevor** jemand
/// sie mit einer Antwort vergleicht: Das Bundesland ist die Einschränkung der
/// Frage, nicht Teil des Namens, und „Deutschland" sagt nur, was ohnehin gilt.
struct PlaceQuery: Equatable {
    /// Der Ort (oder die Adresse), um den es geht.
    let name: String
    /// Das Bundesland, falls die Eingabe eines mitbrachte — dann ist die Frage
    /// schon eingeschränkt und der Fächer erübrigt sich.
    let land: String?

    /// Die sechzehn Länder — der einzige Weg, an mehr als einen Treffer zu
    /// kommen (siehe `CityLookup.alternatives`), und zugleich die Liste, an der
    /// hier ein angehängtes Land wiedererkannt wird. **Eine Liste, zwei
    /// Verwendungen**: Laufen sie auseinander, erzeugt der Fächer Zeichenketten,
    /// die der Zerleger nicht mehr versteht — genau der Fehler von #143.
    static let laender = [
        "Baden-Württemberg", "Bayern", "Berlin", "Brandenburg", "Bremen", "Hamburg",
        "Hessen", "Mecklenburg-Vorpommern", "Niedersachsen", "Nordrhein-Westfalen",
        "Rheinland-Pfalz", "Saarland", "Sachsen", "Sachsen-Anhalt",
        "Schleswig-Holstein", "Thüringen",
    ]

    private static let land = "Deutschland"

    static func parse(_ raw: String) -> PlaceQuery {
        var teile = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        while let letztes = teile.last, letztes.caseInsensitiveCompare(land) == .orderedSame {
            teile.removeLast()
        }
        var land: String?
        if let letztes = teile.last, let treffer = laender.first(where: {
            $0.caseInsensitiveCompare(letztes) == .orderedSame
        }) {
            land = treffer
            teile.removeLast()
        }

        let name = teile.joined(separator: ", ")
        // Wer nur „Bayern" tippt, hat einen Namen genannt, kein Land zu einer
        // Frage. Ohne diesen Fall bliebe die Frage leer.
        guard !name.isEmpty else {
            return PlaceQuery(name: raw.trimmingCharacters(in: .whitespacesAndNewlines), land: nil)
        }
        return PlaceQuery(name: name, land: land)
    }

    /// Dieselbe Frage, auf ein Land eingeschränkt — der Fächer.
    func im(_ land: String) -> PlaceQuery {
        PlaceQuery(name: name, land: land)
    }

    /// Was der Geocoder zu sehen bekommt. „Deutschland" steht immer dahinter:
    /// Ohne Land beantwortet eine fünfstellige Zahl sich weltweit.
    var geocoderString: String {
        [name, land, Self.land].compactMap { $0 }.joined(separator: ", ")
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
