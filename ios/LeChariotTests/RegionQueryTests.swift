import XCTest
@testable import LeChariot

/// **Ort oder Zahl — und was passiert, wenn Apple die Frage nicht beantwortet.**
///
/// Die Zahlen in diesen Tests sind am 03.08. an Apples Geocoder gemessen, nicht
/// erfunden: `geoprobe`-Läufe über neun Ortsnamen und über die sechzehn
/// Bundesländer. Der wichtigste Befund steht in `testWolgastIsNotAnAnswerToNeustadt`.
final class RegionQueryTests: XCTestCase {

    // MARK: Was ist Zahl, was ist Name

    func testFiveDigitsAreAPostcode() {
        XCTAssertEqual(RegionQuery.classify("17389"), .postleitzahl("17389"))
        XCTAssertEqual(RegionQuery.classify(" 01219 "), .postleitzahl("01219"))
    }

    /// **Eine halbe PLZ ist kein Ortsname.** „0121" an den Geocoder zu geben,
    /// liefert irgendeine Hausnummer irgendwo — der alte Zustand („Weiter"
    /// bleibt grau, der Satz mit den fünf Ziffern steht da) ist der richtige.
    func testAPartialPostcodeIsNotACityName() {
        XCTAssertEqual(RegionQuery.classify("0121"), .zuKurz)
        XCTAssertEqual(RegionQuery.classify("173890"), .zuKurz)
        XCTAssertEqual(RegionQuery.classify(""), .zuKurz)
    }

    func testALetteredInputIsACityName() {
        XCTAssertEqual(RegionQuery.classify("Anklam"), .ortsname("Anklam"))
        XCTAssertEqual(RegionQuery.classify("Frankfurt am Main"), .ortsname("Frankfurt am Main"))
        // Gemischt darf auch: Apple versteht „17389 Anklam" ohne Weiteres.
        XCTAssertEqual(RegionQuery.classify("17389 Anklam"), .ortsname("17389 Anklam"))
    }

    /// Ein einzelner Buchstabe ist ein Tippanfang, keine Suche.
    func testASingleLetterIsNotWorthASearch() {
        XCTAssertEqual(RegionQuery.classify("A"), .zuKurz)
        XCTAssertEqual(RegionQuery.classify("An"), .ortsname("An"))
    }

    // MARK: Trifft die Antwort die Frage

    /// **Der Fund, der den Entwurf umgeworfen hat.**
    ///
    /// Auf „Neustadt" antwortet CoreLocation mit **Wolgast** (die Neustadt ist
    /// dort ein Ortsteil), MapKit mit **Neustadt (Dosse)** — je genau ein
    /// Treffer, und die beiden sind sich nicht einig. Ohne diese Prüfung
    /// speicherte die App stillschweigend die PLZ von Wolgast: derselbe Fehler
    /// wie Ahlbeck → 17373 am 30.07.
    func testWolgastIsNotAnAnswerToNeustadt() {
        XCTAssertFalse(
            PlaceMatch.answers("Neustadt", ort: "Wolgast", ortsteil: "Wolgast"),
            "Wer „Neustadt“ tippt, meint keinen Ort namens Wolgast"
        )
    }

    /// Die sieben echten Neustädte aus dem Länder-Fächer bleiben drin — der
    /// Filter darf nicht mehr wegwerfen als das Falsche.
    func testTheRealNeustaedteSurvive() {
        for ort in ["Titisee-Neustadt", "Neustadt", "Neustadt (Dosse)", "Neustadt (Wied)", "Neustadt/Vogtland"] {
            XCTAssertTrue(
                PlaceMatch.answers("Neustadt", ort: ort, ortsteil: nil),
                "\(ort) heißt Neustadt und muss zur Auswahl stehen"
            )
        }
        // Am Ohmberg heißt nicht Neustadt — sein **Ortsteil** aber schon.
        XCTAssertTrue(PlaceMatch.answers("Neustadt", ort: "Am Ohmberg", ortsteil: "Neustadt"))
    }

    /// Die Ausreißer des Fächers: Köln-Innenstadt, Bremen-Süd, Ganderkesee,
    /// Schleswig. Alle vier kamen auf die Frage „Neustadt" zurück.
    func testTheFanOutNoiseIsFilteredAway() {
        let noise = [("Köln", "Innenstadt"), ("Bremen", "Süd"), ("Ganderkesee", "Hengsterholz"), ("Schleswig", "Schleswig")]
        for (ort, ortsteil) in noise {
            XCTAssertFalse(
                PlaceMatch.answers("Neustadt", ort: ort, ortsteil: ortsteil),
                "\(ort) heißt nicht Neustadt"
            )
        }
    }

    func testSpellingAndUmlautsDoNotDecide() {
        XCTAssertTrue(PlaceMatch.answers("munchen", ort: "München", ortsteil: nil))
        XCTAssertTrue(PlaceMatch.answers("ANKLAM", ort: "Anklam", ortsteil: nil))
        XCTAssertTrue(PlaceMatch.answers(" anklam ", ort: "Anklam", ortsteil: nil))
    }

    func testAnEmptyQuestionHasNoAnswer() {
        XCTAssertFalse(PlaceMatch.answers("", ort: "Anklam", ortsteil: nil))
        XCTAssertFalse(PlaceMatch.answers("  ", ort: "Anklam", ortsteil: nil))
    }

    // MARK: Dubletten

    /// Der Fächer fragt sechzehnmal; mehrere Länder landen gern auf demselben
    /// Ort. Doppelt heißt **gleiche PLZ**.
    func testTheSamePostcodeIsOfferedOnce() {
        let list = [
            PlaceCandidate(plz: "16845", ort: "Neustadt (Dosse)", land: "Brandenburg"),
            PlaceCandidate(plz: "16845", ort: "Neustadt", land: "Brandenburg"),
            PlaceCandidate(plz: "93333", ort: "Neustadt", land: "Bayern"),
        ]
        let usable = PlaceMatch.usable(list)
        XCTAssertEqual(usable.count, 2)
        XCTAssertEqual(usable.map(\.plz), ["16845", "93333"])
    }

    // MARK: Was in der Auswahl steht

    /// Ohne das Bundesland stünden dort sieben Zeilen „Neustadt" — eine
    /// Auswahl, in der alles gleich heißt, ist keine.
    func testTheLabelCarriesTheStateAndThePostcode() {
        let candidate = PlaceCandidate(plz: "16845", ort: "Neustadt (Dosse)", land: "Brandenburg")
        XCTAssertEqual(candidate.label, "Neustadt (Dosse), Brandenburg · 16845")
    }

    func testALabelWithoutAStateStillNamesThePostcode() {
        let candidate = PlaceCandidate(plz: "17389", ort: "Anklam", land: nil)
        XCTAssertEqual(candidate.label, "Anklam · 17389")
    }
}
