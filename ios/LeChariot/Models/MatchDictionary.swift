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
    /// Begriff → Zahl seiner Synonyme, siehe `synonymCount(for:)`.
    private static let counts: [String: Int] = loaded.counts
    /// Begriff → seine Synonyme **in der Schreibweise der Datei**, siehe
    /// `words(of:)`.
    private static let byTerm: [String: [String]] = loaded.byTerm
    /// Sorte → Topf, siehe `oberbegriff(of:)`.
    private static let ueber: [String: String] = loaded.ueber
    /// Begriff → seine gesperrten Einzelwörter bzw. Wendungen.
    private static let blockWords: [String: Set<String>] = loaded.blockWords
    private static let blockPhrases: [String: Set<String>] = loaded.blockPhrases

    /// **Sagt das Wörterbuch, dass dieser Titel nicht ist, wonach gefragt
    /// wurde?**
    ///
    /// Die Sperrlisten gab es immer schon, aber gefragt wurden sie nur, wenn
    /// das Suchwort **nicht** im Titel stand. Genau dort, wo es wörtlich
    /// dasteht, ging der Treffer ungeprüft durch — „MILCH-SCHNITTE" bei der
    /// Suche nach Milch, „Leckermäulchen Milch-Quark", „Schinken-Käse-
    /// Croissant" bei Käse. Das sind 30 der 186 Feedback-Fälle aus dreißig
    /// Tagen und die am häufigsten gemeldeten überhaupt, und das Wörterbuch
    /// wusste die Antwort die ganze Zeit.
    ///
    /// **Was der Suchende selbst getippt hat, sperrt nicht.** `salami` sperrt
    /// „pizza", damit die Tiefkühlpizza nicht als Wurst durchgeht — wer aber
    /// „Pizza Salami" sucht, meint genau sie. Ohne diese Ausnahme fände die
    /// Anfrage nichts mehr.
    ///
    /// Gesperrt ist nur, was **jeder** gemeinte Begriff sperrt: Zeigt ein
    /// Wort auf zwei Begriffe und hat einer nichts dagegen, bleibt der
    /// Treffer.
    static func rejects(
        token: String, titleTokens: Set<String>, normalizedTitle: String, typed: Set<String>
    ) -> Bool {
        let terms = meaning(forToken: token)
        guard !terms.isEmpty else { return false }
        return terms.allSatisfy { term in
            (blockWords[term] ?? []).contains { titleTokens.contains($0) && !typed.contains($0) }
                || (blockPhrases[term] ?? []).contains { phrase in
                    normalizedTitle.contains(phrase)
                        && !phrase.split(separator: " ").allSatisfy { typed.contains(String($0)) }
                }
        }
    }

    /// **Der Topf, in dem diese Sorte liegt** — `salami` → `wurst`, `gouda` →
    /// `käse`. `nil` für jeden Begriff, der selbst einer ist.
    ///
    /// Gebraucht dort, wo eine Sorte noch nichts Eigenes hat: `ItemGlyph`
    /// nimmt das Bild des Topfes, solange die Sorte keine eigene Zeichnung
    /// bekommen hat. Ein Wörterbuch mit 435 Begriffen und 91 neuen Sorten
    /// wartet sonst darauf, dass jemand 91 Bilder zeichnet, bevor die Suche
    /// besser werden darf.
    static func oberbegriff(of term: String) -> String? { ueber[term] }
    /// Begriff → Regal, siehe `warengruppe(of:)`.
    private static let byShelf: [String: String] = loaded.byShelf

    /// Die Begriffe, die dieses einzelne Suchwort meinen kann. Leer, wenn das
    /// Wörterbuch es nicht kennt — dann bleibt nur der Titeltreffer.
    static func terms(forToken token: String) -> Set<String> {
        byWord[token] ?? []
    }

    /// **Was ein Suchwort meint — der engste Begriff, nicht jeder, der es
    /// führt.**
    ///
    /// `terms(forToken:)` gibt jeden Begriff zurück, in dessen Synonymliste
    /// das Wort steht, und das sind seit der Wörterbuch-Runde vom 2026-08-25
    /// meistens zwei: die Sorte und die Warengruppe darüber. „Salami" zeigt
    /// auf `salami` **und** auf `wurst`.
    ///
    /// Fürs **Taggen** ist beides richtig — ein Salami-Angebot trägt beide
    /// Tags, und wer „Wurst" auf die Liste schreibt, soll es sehen. Für die
    /// **Suche** ist es das nicht: Wer „Salami" tippt, bekam über `wurst`
    /// alle 216 Wurstangebote der Woche (gemessen am Bestand vom 25.08.),
    /// wer „Frankfurter" tippt, dieselben 216. Das ist die häufigste
    /// Beschwerde in `match_feedback`.
    static func meaning(forToken token: String) -> Set<String> {
        engste(terms(forToken: token), für: token)
    }

    /// **Welcher Begriff gemeint ist, wenn ein Wort auf mehrere zeigt.**
    ///
    /// 1. **Heißt ein Begriff wie das Wort, ist er es.** „Kuchen" meint
    ///    `kuchen` und nicht `backwaren`, auch wenn `backwaren` das Wort in
    ///    seiner Synonymliste führt.
    /// 2. **Sonst gewinnt der feinere** — gemessen an der Zahl seiner
    ///    Synonyme. Ein Begriff, der fünfzig Wörter einsammelt, ist eine
    ///    Warengruppe; einer mit dreien ist ein Ding.
    ///
    /// Bei Gleichstand bleiben beide stehen: Eine Trefferliste verträgt zwei
    /// Begriffe, ein Bild nicht — wer einen einzigen braucht, nimmt den
    /// alphabetisch ersten (`ItemGlyphTerm`).
    ///
    /// Die Regel stand bis zum 25.08. in `ItemGlyphTerm` und galt nur fürs
    /// Zeichen. Sie steht hier, weil die Suche dieselbe Frage stellt und zwei
    /// Antworten darauf auseinanderlaufen würden.
    static func engste(_ kandidaten: Set<String>, für wort: String) -> Set<String> {
        if kandidaten.contains(wort) { return [wort] }
        guard let engste = kandidaten.map({ synonymCount(for: $0) }).min() else { return kandidaten }
        return kandidaten.filter { synonymCount(for: $0) == engste }
    }

    /// Die Begriffe, die die ganze Anfrage als Wendung meint.
    static func terms(forPhrase phrase: String) -> Set<String> {
        byPhrase[phrase.split(separator: " ").joined(separator: " ")] ?? []
    }

    /// Wie viele Suchwörter das Wörterbuch kennt — nur für Tests und Diagnose.
    static var wordCount: Int { byWord.count }

    /// **Die Synonyme eines Begriffs — die Rückrichtung von
    /// `terms(forToken:)`.**
    ///
    /// Gebraucht für die Sorten-Zeile im Angaben-Panel: Was `tomaten` an
    /// Sorten kennt, steht längst hier (Rispen-, Cherry-, Strauch-,
    /// Roma-, Cocktailtomaten), und was `milch` kennt ebenso (Frisch-, Voll-,
    /// Buttermilch, Mandel-, Hafer-, Sojadrink). **Ein zweiter Katalog wäre
    /// die dritte Stelle, an der Warenkunde gepflegt wird** — und die erste,
    /// die auseinanderläuft.
    ///
    /// Zurück kommt die **Schreibweise der Datei**, nicht die normalisierte
    /// Form: „Brötchen" soll auf einem Chip nicht „Broetchen" heißen. Doppelt
    /// geschriebene Synonyme („broetchen"/„brötchen") fallen über ihre
    /// normalisierte Form zusammen; behalten wird die erste Schreibweise.
    static func words(of term: String) -> [String] { byTerm[term] ?? [] }

    /// Wie viele Synonyme dieser Begriff führt — **das Maß dafür, wie grob er
    /// ist.**
    ///
    /// `brokkoli` trägt Chicorée, Chinakohl, Porree, Staudensellerie und
    /// Zuckermais mit, `chicorée` trägt Chicorée. Wenn ein Wort auf beide
    /// zeigt, ist der mit der kürzeren Liste der gemeinte. Gebraucht von
    /// `ItemGlyphTerm`, wo aus dem Begriff ein Bild wird und ein grober
    /// Begriff sichtbar falsch ist.
    static func synonymCount(for term: String) -> Int { counts[term] ?? 0 }

    /// **Das Regal, in das dieser Begriff gehört** — „Molkerei & Eier" für
    /// `eier`, „Backwaren" für `brot`.
    ///
    /// Kommt aus dem Wörterbuch (Feld `warengruppe`, Backend-#87) und damit
    /// aus derselben Keyword-Tabelle, die der Import den Angebotszeilen
    /// anlegt. **Kein zweiter Katalog**, dieselbe Begründung wie in
    /// `ShoppingSections` und `ItemGlyphTerm` — nur weiß die App es jetzt auch
    /// für einen Artikel, für den diese Woche kein Angebot existiert.
    ///
    /// `nil`, wo die Tabelle schweigt (120 von 435 Begriffen, meist
    /// Drogerie- und Haushaltskram): Ein geratenes Regal wäre schlechter als
    /// gar keins, denn der Artikel stünde dann falsch statt unsortiert.
    static func warengruppe(of term: String) -> String? { byShelf[term] }

    /// Alle Begriffe des Wörterbuchs — nur für Tests und Diagnose.
    static var allTerms: [String] { Array(Set(byWord.values.flatMap { $0 })).sorted() }

    /// Die Suchwörter, die mit diesem Präfix beginnen — **nicht** die Begriffe
    /// dahinter.
    ///
    /// Das Raster beim Tippen zeigt Wörter, keine Schlüssel: „Buttermilch" ist
    /// das, was jemand sucht, `milch` das, was daraus wird. Ein Raster aus
    /// Schlüsseln wäre eine kürzere Liste derselben vier Kacheln, alle mit
    /// demselben Wort beschriftet.
    ///
    /// Ungeordnet — die Reihenfolge entscheidet der Aufrufer, weil sie von der
    /// Eingabe abhängt und nicht vom Wörterbuch.
    static func words(startingWith prefix: String) -> [String] {
        guard !prefix.isEmpty else { return [] }
        return byWord.keys.filter { $0.hasPrefix(prefix) }
    }

    // MARK: Laden

    private struct Entry: Decodable {
        let exact: [String]?
        let block: [String]?
        /// Der Topf, in dem diese Sorte liegt — `salami` → `wurst`. Fehlt bei
        /// jedem Begriff, der selbst einer ist.
        let oberbegriff: String?
        /// Das Regal des Begriffs, vom Backend mitgeschrieben. Optional, weil
        /// eine ältere Kopie der Datei es noch nicht trägt — dann verhält sich
        /// die App wie vorher.
        let warengruppe: String?
    }

    private struct File: Decodable {
        let begriffe: [String: Entry]
    }

    private final class BundleToken {}

    private static let loaded: (
        byWord: [String: Set<String>], byPhrase: [String: Set<String>], counts: [String: Int],
        byTerm: [String: [String]], ueber: [String: String],
        blockWords: [String: Set<String>], blockPhrases: [String: Set<String>],
        byShelf: [String: String]
    ) = {
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
            return ([:], [:], [:], [:], [:], [:], [:], [:])
        }

        var byWord: [String: Set<String>] = [:]
        var byPhrase: [String: Set<String>] = [:]
        var counts: [String: Int] = [:]
        var byTerm: [String: [String]] = [:]
        var seenPerTerm: [String: Set<String>] = [:]
        var ueber: [String: String] = [:]
        var blockWords: [String: Set<String>] = [:]
        var blockPhrases: [String: Set<String>] = [:]
        var byShelf: [String: String] = [:]

        for (term, entry) in file.begriffe {
            if let topf = entry.oberbegriff { ueber[term] = topf }
            if let shelf = entry.warengruppe, !shelf.isEmpty { byShelf[term] = shelf }
            for roh in entry.block ?? [] {
                let b = normalized(roh)
                guard !b.isEmpty else { continue }
                if b.contains(" ") { blockPhrases[term, default: []].insert(b) }
                else { blockWords[term, default: []].insert(b) }
            }
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
                counts[term, default: 0] += 1
                // Für die Sorten-Zeile: die Schreibweise der Datei, einmal je
                // normalisierter Form.
                if seenPerTerm[term, default: []].insert(key).inserted {
                    byTerm[term, default: []].append(raw)
                }
            }
        }
        return (byWord, byPhrase, counts, byTerm, ueber, blockWords, blockPhrases, byShelf)
    }()

    /// Dieselbe Normalisierung wie in `OfferMatcher`, damit Suchwort und
    /// Synonym in derselben Form verglichen werden.
    private static func normalized(_ text: String) -> String {
        OfferMatcher.normalize(text)
            .split(separator: " ")
            .joined(separator: " ")
    }
}
