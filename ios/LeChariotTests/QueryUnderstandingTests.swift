import XCTest
@testable import LeChariot

/// **Die drei Fälle, für die die Zeile gebaut wurde** — und die Gegenprobe,
/// dass sie schweigt, wenn es nichts zu sagen gibt.
///
/// Die Zeile beantwortet eine Frage, die die App bisher nur still beantwortet
/// hat: als was ist mein Wort in die Suche gegangen? Wenn dieser Test grün ist
/// und die Anzeige trotzdem falsch, dann liegt es an der Ansicht — die
/// Rechnung selbst steht hier, absichtlich außerhalb von SwiftUI.
final class QueryUnderstandingTests: XCTestCase {

    // MARK: Ein Regal, auf dem die Ableitungen sichtbar werden

    /// Ein Titel mit dem Wort, ein Titel ohne — genau die Paarung, an der sich
    /// Titel- und Tag-Weg unterscheiden.
    private static func offer(_ product: String, tags: [String] = []) -> Offer {
        Offer(
            marketId: "lidl-01219-1", market: "Lidl", product: product,
            price: 1.0, regularPrice: nil, unit: nil, category: "Test",
            emoji: nil, validFrom: .now, validUntil: .now,
            basePrice: nil, baseUnit: nil, nationwide: false,
            matchKey: tags
        )
    }

    private let regal: [Offer] = [
        QueryUnderstandingTests.offer("Deutsche Markenbutter 250 g", tags: ["butter"]),
        QueryUnderstandingTests.offer("GRÜNLÄNDER Schnittkäse 400 g", tags: ["käse"]),
        QueryUnderstandingTests.offer("Speck-Käse-Twister", tags: ["backwaren"]),
        QueryUnderstandingTests.offer("Zwetschgen Klasse I, 500 g", tags: ["pfirsich"]),
        QueryUnderstandingTests.offer("Mühlen Filets Typ Hähnchen", tags: ["tofu"]),
    ]

    // MARK: Fall 1 — vertippt

    /// „Schnittkäs" steht in keinem Wörterbuch; nur die Tippfehler-Toleranz
    /// zieht es auf das Titelwort `schnittkäse`. **Das ist die Ableitung, die
    /// heute niemand sieht.**
    func testTypoIsReportedAsTheWordItWasPulledOnto() {
        let reading = QueryUnderstanding.of(query: "Schnittkäs", in: regal)
        XCTAssertEqual(reading.words.map(\.reading), [.corrected("schnittkäse")])
        XCTAssertEqual(reading.headline, "Verstanden als Schnittkäse")
        // Und **kein** Satz über ein unbekanntes Wort: Die Korrektur hat
        // gegriffen, das Wort ist damit beantwortet.
        XCTAssertNil(reading.unknownNote)
    }

    /// **Der Beispielfall aus dem Backlog trifft heute gar nichts, und das
    /// hält dieser Test fest.** „Butetr" ist ein *Dreher*: gleich lang wie
    /// „Butter" und mit Levenshtein-Abstand 2. `OfferMatcher.tokensMatch`
    /// verlangt aber **unterschiedliche** Längen (sonst würde „Butter" auf
    /// „Bitter" passen, echte Meldung vom 21.07.) und Abstand ≤ 1. Die
    /// Toleranz fängt also einen verschluckten oder doppelten Buchstaben und
    /// Einzahl/Mehrzahl — keinen Dreher.
    ///
    /// Die Anzeige darf das nicht schönen: Sie sagt hier „kennt das Wort
    /// nicht", und das ist die Wahrheit über die Suche, die wirklich läuft.
    func testTheTransposedTypoFromTheBacklogIsNotCorrectedToday() {
        XCTAssertFalse(OfferMatcher.tokensMatch("butetr", "butter"))
        let reading = QueryUnderstanding.of(query: "Butetr", in: regal)
        XCTAssertEqual(reading.words.map(\.reading), [.unknown])
        XCTAssertNil(reading.headline)
        XCTAssertNotNil(reading.unknownNote)
    }

    /// Die Gegenprobe zur Korrektur: Ein Wort, das das Wörterbuch kennt, wird
    /// nicht auf ein Titelwort gezogen, auch wenn eines danebensteht.
    func testAKnownWordIsNeverReportedAsACorrection() {
        let reading = QueryUnderstanding.of(query: "Butter", in: regal)
        XCTAssertEqual(reading.words.map(\.reading), [.asTyped])
        // Nichts abgeleitet, also nichts zu sagen — die Zeile bleibt weg.
        XCTAssertNil(reading.headline)
        XCTAssertNil(reading.unknownNote)
    }

    // MARK: Fall 2 — bewusst grober Begriff

    /// `pfirsich` fasst im Wörterbuch alles Steinobst zusammen. Das ist Absicht
    /// und wird hier zur **sichtbaren** Tatsache statt zum Rätsel: Wer
    /// „Zwetschgen" tippt und Pfirsiche bekommt, liest ab jetzt, warum.
    func testACoarseTermIsNamedAsItIs() {
        let reading = QueryUnderstanding.of(query: "Zwetschgen", in: regal)
        XCTAssertEqual(reading.words.map(\.reading), [.term("pfirsich")])
        XCTAssertEqual(reading.headline, "Verstanden als Pfirsich")
    }

    /// Dieselbe Form, der Fall aus dem Backlog: „Hafermilch" ist `milch`.
    func testDictionarySynonymIsNamed() {
        XCTAssertEqual(
            QueryUnderstanding.of(query: "Buttermilch", in: regal).headline,
            "Verstanden als Milch"
        )
    }

    // MARK: Fall 3 — das Wort kennt niemand

    /// **Der Fall, der am meisten trägt.** Ohne diesen Satz sieht „das Wort
    /// kennt das Wörterbuch nicht" genauso aus wie „diese Woche gibt es dazu
    /// nichts" — und genau daran hing „vegan Schnitzel" vom 21.07. bis 31.07.
    func testAWordTheDictionaryDoesNotKnowSaysSo() {
        let reading = QueryUnderstanding.of(query: "Schnitzel", in: regal)
        XCTAssertEqual(reading.words.map(\.reading), [.unknown])
        XCTAssertNil(reading.headline)
        XCTAssertEqual(
            reading.unknownNote,
            "\u{201E}Schnitzel\u{201C} steht nicht im Wörterbuch — "
                + "gesucht wird das Wort genau so im Angebotstitel."
        )
    }

    /// Der gemeldete Fall in ganzer Länge: Ein Wort ist abgeleitet, das andere
    /// unbekannt. **Beide Auskünfte stehen, und sie stehen getrennt** — ein
    /// Satz, der beides zusammenfasst, verschweigt die Hälfte.
    func testAMixedQuerySaysBothThings() {
        let reading = QueryUnderstanding.of(query: "vegan Schnitzel", in: regal)
        XCTAssertEqual(reading.headline, "\u{201E}Vegan\u{201C} als Tofu")
        XCTAssertEqual(
            reading.unknownNote,
            "\u{201E}Schnitzel\u{201C} steht nicht im Wörterbuch — "
                + "gesucht wird das Wort genau so im Angebotstitel."
        )
    }

    /// Ein Wort ohne Wörterbucheintrag bleibt unbekannt, auch wenn es wörtlich
    /// im Prospekt steht — die Auskunft ist über das Wörterbuch, nicht über
    /// diese Woche. Und die Korrektur darf hier **nicht** greifen: „twister"
    /// steht selbst da, es wurde nichts gezogen.
    func testALiteralWordWithoutADictionaryEntryStaysUnknown() {
        let reading = QueryUnderstanding.of(query: "Twister", in: regal)
        XCTAssertEqual(reading.words.map(\.reading), [.unknown])
    }

    // MARK: Die Wendung

    /// „crème fraîche" ist einzeln nichts und zusammen `sahne`. Dann trägt der
    /// Kopf den Begriff — und **kein** Satz über zwei unbekannte Wörter.
    func testAPhraseIsReadAsAWhole() {
        let reading = QueryUnderstanding.of(query: "creme fraiche", in: regal)
        XCTAssertEqual(reading.phraseTerm, "sahne")
        XCTAssertEqual(reading.headline, "Verstanden als Sahne")
        XCTAssertNil(reading.unknownNote)
    }

    // MARK: Woher eine einzelne Zeile kommt

    /// Der Kern des vertauschten Screenshots: Bei „Käse" trägt der
    /// Speck-Käse-Twister das Wort **wörtlich** im Titel, der GRÜNLÄNDER
    /// Schnittkäse nur als Tag. Die Zeile sagt ab jetzt genau das — und
    /// behauptet nicht mehr, welcher der bessere Treffer ist.
    func testTheRowNoteNamesTheTagThatCarriedTheHit() {
        let twister = regal[2]
        let gruenlaender = regal[1]
        XCTAssertNil(QueryUnderstanding.rowNote(for: "Käse", of: twister, namesWords: false))
        XCTAssertEqual(
            QueryUnderstanding.rowNote(for: "Käse", of: gruenlaender, namesWords: false),
            "über Käse"
        )
    }

    /// Bei mehrwortigen Anfragen muss die Zeile sagen, **welches** Wort sie
    /// über einen Tag erfüllt hat — sonst zeigt sie einen Begriff, der zu
    /// keinem sichtbaren Wort gehört.
    func testTheRowNoteNamesTheWordWhenTheQueryHasSeveral() {
        XCTAssertEqual(
            QueryUnderstanding.rowNote(for: "vegan Filets", of: regal[4], namesWords: true),
            "\u{201E}Vegan\u{201C} über Tofu"
        )
        // Die Gegenprobe zur Gegenprobe: „Filets" steht im Titel und darf
        // deshalb **nicht** in der Zeile auftauchen.
        XCTAssertFalse(
            QueryUnderstanding.rowNote(for: "vegan Filets", of: regal[4], namesWords: true)?
                .contains("Filets") ?? true
        )
    }

    // MARK: Die Anzeige selbst

    /// Begriffe stehen kleingeschrieben im Wörterbuch; auf dem Bildschirm sind
    /// es deutsche Substantive. Umlaute inbegriffen — `capitalized` hätte
    /// „Crème Fraîche" daraus gemacht, deshalb nur der erste Buchstabe.
    func testTermsAreShownAsGermanNouns() {
        XCTAssertEqual(QueryUnderstanding.display("käse"), "Käse")
        XCTAssertEqual(QueryUnderstanding.display("creme fraiche"), "Creme fraiche")
    }

    /// Eine leere Anfrage rechnet nichts und sagt nichts.
    func testAnEmptyQuerySaysNothing() {
        let reading = QueryUnderstanding.of(query: "  ", in: regal)
        XCTAssertTrue(reading.words.isEmpty)
        XCTAssertNil(reading.headline)
        XCTAssertNil(reading.unknownNote)
    }
}
