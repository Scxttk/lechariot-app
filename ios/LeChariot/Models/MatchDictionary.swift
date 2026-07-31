import Foundation

/// Das Begriffs-Wörterbuch des Backends — hier von der **Suchseite** her
/// gelesen.
///
/// Bisher kannte nur der Import das Wörterbuch: Es entscheidet dort, welche
/// `match_key`-Tags eine Angebotszeile bekommt („RÜGENWALDER Vegane Mühlen" →
/// `tofu`). Die App bekam davon nur das **Ergebnis** zu sehen, die Tag-Namen,
/// nie die Synonyme, die dorthin geführt haben. Wer „vegan" tippte, verglich
/// also gegen `tofu` — und traf nichts.
///
/// Dass „vegan" und „Schnitzel" einzeln trotzdem funktionierten, war Zufall:
/// Beide stehen wörtlich in Produkttiteln, Stufe 1 fing sie ab. Ein Synonym,
/// das **nicht** im Titel steht — „Fleischersatz", „Falafel" —, fand dagegen
/// nichts, obwohl die Zeilen sauber getaggt waren. Gemeldet am 2026-07-21 von
/// Samira als „vegan Schnitzel ohne Treffer"; nachgemessen am 2026-07-31 gab
/// es zu genau dieser Anfrage tatsächlich nie ein Angebot, aber die Lücke
/// dahinter war echt.
///
/// **Nur `exact`, nicht `suffix`.** Die Suffix-Regeln des Wörterbuchs sind
/// dafür gebaut, Produkt*texte* abzugrasen („…brötchen" → `brot`). Auf ein
/// Suchwort angewandt greifen sie zu weit: Der Nutzer tippt das Wort, das er
/// meint, und nicht die halbe Warengruppe. `block` gilt dagegen sehr wohl —
/// wer „Buttermilch" sucht, meint weder `butter` noch `milch`, und genau dafür
/// stehen die Sperrlisten im Wörterbuch.
enum MatchDictionary {
    /// Einwortige Synonyme: Suchwort → Begriffe, die es meint.
    private static let byWord: [String: Set<String>] = loaded.byWord
    /// Mehrwortige Synonyme („crème fraîche" → `sahne`), gegen die **ganze**
    /// normalisierte Anfrage geprüft. Einzeln tokenisiert wären sie nutzlos:
    /// „creme" allein ist kein Begriff.
    private static let byPhrase: [String: Set<String>] = loaded.byPhrase

    /// Die Begriffe, die dieses einzelne Suchwort meinen kann. Leer, wenn das
    /// Wörterbuch es nicht kennt — dann bleibt nur der Titeltreffer.
    static func terms(forToken token: String) -> Set<String> {
        byWord[token] ?? []
    }

    /// Die Begriffe, die die ganze Anfrage als Wendung meint.
    static func terms(forPhrase phrase: String) -> Set<String> {
        byPhrase[phrase.split(separator: " ").joined(separator: " ")] ?? []
    }

    /// Wie viele Suchwörter das Wörterbuch kennt — nur für Tests und Diagnose.
    static var wordCount: Int { byWord.count }

    // MARK: Laden

    private struct Entry: Decodable {
        let exact: [String]?
        let block: [String]?
    }

    private struct File: Decodable {
        let begriffe: [String: Entry]
    }

    private final class BundleToken {}

    private static let loaded: (byWord: [String: Set<String>], byPhrase: [String: Set<String>]) = {
        // Im Test-Bundle liegt die Datei nicht in `Bundle.main`, in der App
        // schon — beide Wege, damit dieselbe Klasse in beiden Fällen lädt.
        let bundles = [Bundle.main, Bundle(for: BundleToken.self)]
        guard let url = bundles.compactMap({
            $0.url(forResource: "matching-woerterbuch", withExtension: "json")
        }).first,
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            // Ohne Wörterbuch verhält sich die Suche wie vorher: Titeltreffer
            // und Tag-Gleichheit. Eine fehlende Datei darf die Suche nicht
            // abschalten.
            return ([:], [:])
        }

        var byWord: [String: Set<String>] = [:]
        var byPhrase: [String: Set<String>] = [:]

        for (term, entry) in file.begriffe {
            // Gesperrte Wörter dieses Begriffs: „milchreis" darf nie auf
            // `milch` zeigen.
            let blocked = Set((entry.block ?? []).map(normalized))
            // Der Begriffsname selbst zählt als sein eigenes Synonym — sonst
            // fände „käse" den Begriff `käse` nur, wenn er zufällig in der
            // exact-Liste steht.
            for raw in (entry.exact ?? []) + [term] {
                let key = normalized(raw)
                guard !key.isEmpty, !blocked.contains(key) else { continue }
                if key.contains(" ") {
                    byPhrase[key, default: []].insert(term)
                } else {
                    byWord[key, default: []].insert(term)
                }
            }
        }
        return (byWord, byPhrase)
    }()

    /// Dieselbe Normalisierung wie in `OfferMatcher`, damit Suchwort und
    /// Synonym in derselben Form verglichen werden.
    private static func normalized(_ text: String) -> String {
        OfferMatcher.normalize(text)
            .split(separator: " ")
            .joined(separator: " ")
    }
}
