import XCTest
@testable import LeChariot

/// **Das Raster darf nur Wörter zeigen, die halten, was die Kachel verspricht.**
///
/// Ein Vorschlag ist ein Versprechen: Wer ihn antippt, bekommt etwas. Zwei
/// Wege, es zu brechen — ein Wort, das der Matcher nicht kennt (dann steht es
/// als toter Eintrag auf der Liste), und ein Wort, zu dem es diese Woche in
/// den gewählten Filialen nichts gibt (dann liest man nach dem Tippen „Diese
/// Woche nirgends im Angebot"). Beide werden hier zugehalten.
final class TermSuggestionsTests: XCTestCase {

    private static func offer(_ product: String, tags: [String] = []) -> Offer {
        Offer(
            marketId: "lidl-01219-1", market: "Lidl", product: product,
            price: 1.0, regularPrice: nil, unit: nil, category: "Test",
            emoji: nil, validFrom: .now, validUntil: .now,
            basePrice: nil, baseUnit: nil, nationwide: false,
            matchKey: tags
        )
    }

    /// Milch ist da, Käse ist da — Fleisch nicht. Genau daran muss sich das
    /// Raster unterscheiden.
    private let regal: [Offer] = [
        TermSuggestionsTests.offer("Bio Vollmilch 1 l", tags: ["milch"]),
        TermSuggestionsTests.offer("GRÜNLÄNDER Schnittkäse 400 g", tags: ["käse"]),
        TermSuggestionsTests.offer("Landliebe Frische Vollmilch", tags: ["milch"]),
    ]

    // MARK: Das Versprechen der Kachel

    /// Der Fall aus dem Konzept: „mil" führt zu Milchwörtern.
    func testTypingAPrefixOffersTheDictionaryWordsBehindIt() {
        let words = TermSuggestions.words(for: "mil", in: regal)
        XCTAssertFalse(words.isEmpty, "mil bietet nichts an")
        XCTAssertTrue(words.contains("Milch"), "Der naheliegendste Begriff fehlt: \(words)")
        // Und jedes angebotene Wort findet wirklich etwas — das ist der Punkt.
        for word in words {
            XCTAssertFalse(
                OfferMatcher.matches(for: word, in: regal).isEmpty,
                "\(word) wird angeboten, findet aber nichts"
            )
        }
    }

    /// **Die Regel, die das Raster von einem Wörterbuchauszug unterscheidet.**
    /// „Fleisch" steht im Wörterbuch, aber in diesem Regal liegt keins — die
    /// Kachel darf nicht kommen, sonst tippt man sie an und liest „Diese Woche
    /// nirgends im Angebot".
    func testAWordWithoutAnOfferThisWeekIsNotOffered() {
        let words = TermSuggestions.words(for: "fleisch", in: regal)
        XCTAssertTrue(words.isEmpty, "Ein Wort ohne Angebot wird angeboten: \(words)")
        // Gegenprobe am selben Wort: Mit einem passenden Angebot kommt es.
        let mitFleisch = regal + [Self.offer("Hackfleisch gemischt 500 g", tags: ["hackfleisch"])]
        XCTAssertFalse(
            TermSuggestions.words(for: "hack", in: mitFleisch).isEmpty,
            "Mit Angebot muss der Begriff kommen"
        )
    }

    /// Ein Wort, das das Wörterbuch **nicht** kennt, taucht nie auf — auch
    /// dann nicht, wenn es wörtlich im Titel steht. Sonst führte das Raster
    /// zurück in genau den Zustand, den es abschaffen soll.
    func testOnlyDictionaryWordsAreOffered() {
        XCTAssertTrue(
            TermSuggestions.words(for: "grünl", in: regal).isEmpty,
            "Ein Markenname aus dem Titel ist kein Wörterbuchwort"
        )
    }

    // MARK: Reihenfolge und Menge

    /// Das genau getippte Wort zuerst, danach das kürzeste. Wer „milch" tippt,
    /// will „Milch" nicht auf Platz vier suchen.
    func testTheExactWordComesFirstAndShortOnesNext() {
        let words = TermSuggestions.words(for: "milch", in: regal)
        XCTAssertEqual(words.first, "Milch")
        let lengths = words.dropFirst().map(\.count)
        XCTAssertEqual(lengths, lengths.sorted(), "Nach dem Volltreffer gehört das Kürzeste nach vorn")
    }

    /// Zwei Reihen zu dritt — mehr passt nicht in die Fläche, ohne die
    /// Eingabezeile zu verschieben.
    ///
    /// Gemessen auf dem **vollen** Regal: Ohne ein Angebot je Begriff siebt der
    /// Vorrat so viel weg, dass die Kappe nie greift und der Test nichts sagt.
    func testNeverMoreThanTheGridHolds() {
        for prefix in ["ka", "sc", "br", "kä", "ge", "to"] {
            let words = TermSuggestions.words(for: prefix, in: Self.vollesRegal)
            XCTAssertTrue(words.count <= TermSuggestions.limit,
                          "\(prefix) liefert \(words.count) Kacheln")
        }
        // Und mindestens ein Präfix muss die Kappe wirklich erreichen, sonst
        // prüft der Test eine Grenze, an die nie jemand stößt.
        XCTAssertEqual(
            TermSuggestions.words(for: "sc", in: Self.vollesRegal).count,
            TermSuggestions.limit
        )
    }

    /// Ein erfundenes Angebot je Begriff — dasselbe Verfahren wie in
    /// `MatchShelfTests`, nur ohne die Titel: Hier zählt nur, dass jeder
    /// Begriff **irgendwo** vorkommt.
    private static let vollesRegal: [Offer] = MatchDictionary.allTerms
        .map { offer("Testartikel \($0)", tags: [$0]) }

    /// **Der erste Buchstabe schlägt schon vor** (10.08., Punkt E: „if u type a
    /// letter the matching starts").
    ///
    /// Bis dahin galt das Gegenteil, und die Begründung war eine geerbte:
    /// `OfferMatcher.tokens` wirft Wörter unter zwei Zeichen weg, weil ein
    /// einzelner Buchstabe in einem **Prospekttitel** nichts bedeutet. Für
    /// einen getippten **Anfang** bedeutet er etwas — deshalb hat
    /// `TermSuggestions` seit heute seine eigene Zerlegung.
    ///
    /// Die zweite Zusicherung hält fest, dass die Grenze der Suche unberührt
    /// geblieben ist: Es sind jetzt zwei Regeln, und das ist Absicht.
    func testASingleLetterAlreadySuggests() {
        XCTAssertTrue(TermSuggestions.words(for: "m", in: regal).contains("Milch"),
                      "Der erste Buchstabe schlägt nichts vor")
        XCTAssertTrue(TermSuggestions.words(for: "", in: regal).isEmpty)
        XCTAssertTrue(OfferMatcher.tokens("m").isEmpty,
                      "Die Ein-Zeichen-Grenze der **Suche** darf bleiben, wo sie war")
    }

    /// Gewertet wird das **letzte** Wort: Wer „bio mil" tippt, meint „mil".
    func testTheLastWordIsTheOneBeingTyped() {
        XCTAssertEqual(
            TermSuggestions.words(for: "bio mil", in: regal),
            TermSuggestions.words(for: "mil", in: regal)
        )
    }

    // MARK: Wie viel ein Präfix hergibt — gemessen, nicht geschätzt

    /// Kein Gate auf eine Zahl, sondern ein Protokoll: Wie viele Wörter das
    /// Wörterbuch je Präfix überhaupt kennt, bevor der Vorrat aussiebt.
    ///
    /// Die Zahl steht im PR. Sie ist die Antwort auf „reicht ein Raster aus
    /// sechs Kacheln" — und sie kann sich mit jeder Pflegerunde ändern.
    func testHowManyWordsATypicalPrefixHas() {
        for prefix in ["mi", "mil", "kä", "bro", "app", "sch", "to", "zwe", "nu", "ei"] {
            let all = MatchDictionary.words(startingWith: prefix)
            let voll = TermSuggestions.words(for: prefix, in: Self.vollesRegal)
            let klein = TermSuggestions.words(for: prefix, in: regal)
            print("PRÄFIX|\(prefix)|Wörterbuch=\(all.count)|volles Regal=\(voll.count)|drei Angebote=\(klein.count)")
        }
        XCTAssertGreaterThan(MatchDictionary.wordCount, 500, "Das Wörterbuch ist nicht geladen")
        XCTAssertGreaterThan(MatchDictionary.allTerms.count, 50, "Die Begriffe fehlen")
    }
}
