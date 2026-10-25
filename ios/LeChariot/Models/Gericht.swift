import Foundation

/// Eine Zutat, wie die Edge Function `gerichte` sie liefert.
///
/// `begriff` ist immer ein Begriff aus `matching-woerterbuch.json` — die
/// Funktion wirft alles andere weg, bevor es die App erreicht. `name` ist ein
/// Synonym genau dieses Begriffs („Lasagneplatten" unter `lasagneblätter`) und
/// damit ein Wort, das die Suche wiederfindet. Auf die Liste kommt `name`.
struct Zutat: Codable, Equatable, Hashable, Identifiable {
    let begriff: String
    let name: String
    let menge: String

    var id: String { name }
}

struct Gericht: Codable, Equatable, Hashable, Identifiable {
    let name: String
    let portionen: Int
    let zutaten: [Zutat]

    var id: String { name }
}

/// Was beim Fragen schiefgehen kann — jeder Fall mit dem Satz, den der
/// Bildschirm zeigt.
enum GerichteFehler: Error, Equatable {
    /// Das Tageskontingent dieser Installation ist aufgebraucht.
    case kontingent(grenze: Int)
    /// Der gemeinsame Tagesdeckel aller Installationen ist erreicht.
    case gesamt
    /// Das Modell hat im Text kein Gericht erkannt.
    case keinGericht
    /// Funktion noch nicht ausgerollt oder ohne Schlüssel (404/503).
    case nichtErreichbar
    case netz

    var meldung: String {
        switch self {
        case let .kontingent(grenze):
            "Für heute sind die \(grenze) Anfragen aufgebraucht. Morgen geht es weiter."
        case .gesamt:
            "Heute haben schon sehr viele gefragt. Morgen geht es weiter."
        case .keinGericht:
            "Dazu ist kein Gericht eingefallen. Versuch es mit einem anderen Namen."
        case .nichtErreichbar:
            "Kochen ist gerade nicht erreichbar."
        case .netz:
            "Keine Verbindung. Versuch es gleich noch einmal."
        }
    }
}

/// **Was schon da ist und was fehlt** — gerechnet auf dem Gerät, mit
/// demselben Wörterbuch, mit dem die Liste ihre Angebote findet.
///
/// Das Modell könnte das auch sagen. Hier steht es, weil die Liste die
/// Wahrheit ist und nicht, was das Modell über sie vermutet: „Nudeln" auf der
/// Liste deckt die Spaghetti im Rezept, weil beide auf `nudeln` zeigen —
/// dieselbe Regel, nach der ein Spaghetti-Angebot unter „Nudeln" erscheint.
enum GerichtAbgleich {
    /// Die Begriffe, die die Liste schon abdeckt. Abgehakte zählen mit: Was
    /// heute gekauft wurde, liegt zu Hause.
    static func begriffe(der items: [ShoppingItem]) -> Set<String> {
        Set(items.compactMap { ItemGlyphTerm.term(for: $0.text) })
    }

    /// Ob die Liste diese Zutat schon hat.
    ///
    /// In beide Richtungen eine Stufe Oberbegriff: „Käse" auf der Liste deckt
    /// den Reibekäse im Rezept, und „Gouda" auf der Liste deckt ein Rezept,
    /// das nur „Käse" sagt.
    static func vorhanden(_ zutat: Zutat, in begriffe: Set<String>, texte: Set<String>) -> Bool {
        if texte.contains(zutat.name.lowercased()) { return true }
        if begriffe.contains(zutat.begriff) { return true }
        if let ober = MatchDictionary.oberbegriff(of: zutat.begriff), begriffe.contains(ober) {
            return true
        }
        return begriffe.contains { MatchDictionary.oberbegriff(of: $0) == zutat.begriff }
    }

    static func fehlende(_ gericht: Gericht, items: [ShoppingItem]) -> [Zutat] {
        let begriffe = begriffe(der: items)
        let texte = Set(items.map { $0.text.lowercased() })
        return gericht.zutaten.filter { !vorhanden($0, in: begriffe, texte: texte) }
    }

    /// Die Begriffe der Angebote dieser Woche, häufigste zuerst. Nur Begriffe,
    /// keine Titel, Preise oder Filialen — mehr braucht ein Vorschlag nicht.
    static func angebotsBegriffe(_ offers: [Offer], grenze: Int = 80) -> [String] {
        var zahl: [String: Int] = [:]
        for offer in offers {
            for key in offer.matchKeys where key != "nonfood" {
                zahl[key, default: 0] += 1
            }
        }
        return zahl
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(grenze)
            .map(\.key)
    }
}
