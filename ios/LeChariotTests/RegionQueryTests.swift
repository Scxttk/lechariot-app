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

    // MARK: Der Vorschlag als Frage (#143)

    /// **Der gemessene Fehler vom 11.08.**
    ///
    /// Apples Vervollständiger antwortet auf „Stuttgart" mit dem Paar
    /// „Stuttgart" / „Baden-Württemberg, Deutschland", und die App schickte
    /// beides zusammen als *Ortsnamen* los. Der Geocoder hat es sogar richtig
    /// beantwortet (locality Stuttgart, 70173) — nur hieß der Ort danach nicht
    /// so wie die Frage, und der eigene Filter warf die richtige Antwort weg.
    func testASuggestionIsAPlaceAndAState() {
        let frage = PlaceQuery.parse("Stuttgart, Baden-Württemberg, Deutschland")
        XCTAssertEqual(frage.name, "Stuttgart")
        XCTAssertEqual(frage.land, "Baden-Württemberg")
    }

    /// Ohne Zusatz bleibt alles, wie es war.
    func testABareNameStaysABareName() {
        XCTAssertEqual(PlaceQuery.parse("Anklam"), PlaceQuery(name: "Anklam", land: nil))
        XCTAssertEqual(PlaceQuery.parse("Anklam, Deutschland"), PlaceQuery(name: "Anklam", land: nil))
    }

    /// Eine Adresse behält ihre Kommata — sie **ist** der Name, und nur das
    /// Land hinten ist Kontext.
    func testAnAddressKeepsItsParts() {
        let frage = PlaceQuery.parse("Karl-Laux-Straße 6, 01219 Dresden, Deutschland")
        XCTAssertEqual(frage.name, "Karl-Laux-Straße 6, 01219 Dresden")
        XCTAssertNil(frage.land)
    }

    /// Wer „Bayern" tippt, hat einen Namen genannt und keine Einschränkung.
    /// Ohne diesen Fall wäre die Frage leer und der Geocoder bekäme
    /// „, Bayern, Deutschland".
    func testAStateOnItsOwnIsTheQuestion() {
        XCTAssertEqual(PlaceQuery.parse("Bayern"), PlaceQuery(name: "Bayern", land: nil))
    }

    /// **Die Frage, die am 11.08. sechzehnmal gestellt wurde.** Ohne Zerleger
    /// hängte der Fächer sein Land an eine Zeichenkette, die schon eines hatte:
    /// „Stuttgart, Baden-Württemberg, Deutschland, Bayern, Deutschland".
    func testTheFanAsksOneCleanQuestionPerState() {
        let frage = PlaceQuery.parse("Stuttgart, Baden-Württemberg, Deutschland")
        XCTAssertEqual(frage.im("Bayern").geocoderString, "Stuttgart, Bayern, Deutschland")
        XCTAssertEqual(PlaceQuery.parse("Neustadt").im("Sachsen").geocoderString,
                       "Neustadt, Sachsen, Deutschland")
    }

    // MARK: Was die App aus der Antwort macht (#143)

    /// Die gemessene Antwort auf „Stuttgart, Baden-Württemberg, Deutschland":
    /// Vorwärts ohne PLZ, rückwärts 70173. Mit der zerlegten Frage als Maß
    /// **zählt** sie — vorher nicht.
    func testTheBigCityAnswerCounts() {
        let hit = CityLookup.entscheide(
            vorwärts: CityLookup.Antwort(locality: "Stuttgart", administrativeArea: "Baden-Württemberg"),
            rückwärts: CityLookup.Antwort(locality: "Stuttgart", administrativeArea: "Baden-Württemberg", postalCode: "70173"),
            mass: PlaceQuery.parse("Stuttgart, Baden-Württemberg, Deutschland")
        )
        XCTAssertEqual(hit?.candidate.plz, "70173")
        XCTAssertEqual(hit?.answersQuery, true, "Der Vorschlag scheitert an seinem eigenen Ergebnis")
    }

    /// Und ohne den Zerleger — der Zustand vor dem Fix — hieße die Antwort
    /// „passt nicht zur Frage". Steht hier, damit der Unterschied prüfbar ist
    /// und nicht nur behauptet.
    func testTheRawSuggestionTextWouldNotHaveCounted() {
        let hit = CityLookup.entscheide(
            vorwärts: CityLookup.Antwort(locality: "Stuttgart", administrativeArea: "Baden-Württemberg"),
            rückwärts: CityLookup.Antwort(locality: "Stuttgart", administrativeArea: "Baden-Württemberg", postalCode: "70173"),
            mass: PlaceQuery(name: "Stuttgart, Baden-Württemberg, Deutschland", land: nil)
        )
        XCTAssertEqual(hit?.answersQuery, false)
    }

    /// **Eine Straße beantwortet sich weiter selbst** (06.08.) — die Regel,
    /// die nicht kaputtgehen darf.
    func testAnAddressStillAnswersItself() {
        let hit = CityLookup.entscheide(
            vorwärts: CityLookup.Antwort(
                locality: "Dresden", subLocality: "Prohlis", thoroughfare: "Karl-Laux-Straße",
                administrativeArea: "Sachsen", postalCode: "01219"
            ),
            rückwärts: nil,
            mass: PlaceQuery.parse("Dresden Karl-Laux-Straße 6")
        )
        XCTAssertEqual(hit?.candidate.plz, "01219")
        XCTAssertEqual(hit?.answersQuery, true)
    }

    // MARK: Fünf Ziffern sind noch kein deutsches Gebiet (#148)

    /// **Der Fall aus Prod, 12.08.**: Ein US-ZIP lief durch das Onboarding,
    /// weil fünf Ziffern fünf Ziffern sind. Apple beantwortet ihn — sogar mit
    /// „, Deutschland" dahinter — aus **Mexiko**; das Land steht in der
    /// Antwort, es hat nur nie jemand gelesen.
    func testAnAmericanZipIsNotAGermanPostcode() {
        let ergebnis = CityLookup.entscheidePLZ(
            "95070",
            vorwärts: CityLookup.Antwort(
                locality: "Texhuacán", administrativeArea: "Ver.", postalCode: "95070",
                name: "95070", isoCountryCode: "MX", country: "Mexiko"
            ),
            rückwärts: nil
        )
        XCTAssertEqual(ergebnis, .ausland(land: "Mexiko"))
    }

    /// **Das Land allein reicht nicht.** Auf eine erfundene deutsche PLZ
    /// antwortet Apple mit einem beliebigen deutschen Ort — hier
    /// Annaberg-Buchholz mit der PLZ 09456. Eine Landesprüfung ohne den
    /// Abgleich der Ziffern hätte 10001 durchgelassen.
    func testAGermanAnswerWithAnotherPostcodeIsNoAnswer() {
        let ergebnis = CityLookup.entscheidePLZ(
            "10001",
            vorwärts: CityLookup.Antwort(
                locality: "Annaberg-Buchholz", administrativeArea: "Sachsen",
                name: "10000 Ritter", isoCountryCode: "DE", country: "Deutschland"
            ),
            rückwärts: CityLookup.Antwort(
                locality: "Annaberg-Buchholz", administrativeArea: "Sachsen",
                postalCode: "09456", isoCountryCode: "DE", country: "Deutschland"
            )
        )
        XCTAssertEqual(ergebnis, .unbekannt)
    }

    /// Dieselbe Klasse, ohne Ort: „99999, Deutschland" landet bei Apple
    /// irgendwo in Thüringen (99974).
    func testAnInventedPostcodeFallsBackToSomewhereElse() {
        let ergebnis = CityLookup.entscheidePLZ(
            "99999",
            vorwärts: CityLookup.Antwort(name: "Deutschland", isoCountryCode: "DE", country: "Deutschland"),
            rückwärts: CityLookup.Antwort(
                locality: "Mühlhausen/Thüringen", administrativeArea: "Thüringen",
                postalCode: "99974", isoCountryCode: "DE", country: "Deutschland"
            )
        )
        XCTAssertEqual(ergebnis, .unbekannt)
    }

    /// Und die echte PLZ geht durch — mit ihrem Ort, den `PlaceNameStore`
    /// danach nicht ein zweites Mal erfragen muss.
    func testARealGermanPostcodePasses() {
        let ergebnis = CityLookup.entscheidePLZ(
            "01219",
            vorwärts: CityLookup.Antwort(
                locality: "Dresden", administrativeArea: "Sachsen", postalCode: "01219",
                name: "01219", isoCountryCode: "DE", country: "Deutschland"
            ),
            rückwärts: nil
        )
        XCTAssertEqual(ergebnis, .deutsch(PlaceCandidate(plz: "01219", ort: "Dresden", land: "Sachsen")))
    }

    /// **10115 gibt es zweimal auf der Welt** — Berlin und Manhattan. Gefragt
    /// wird mit „, Deutschland", und Apple antwortet aus Berlin; die Prüfung
    /// darf daran nicht scheitern.
    func testAPostcodeThatExistsTwiceStaysGerman() {
        let ergebnis = CityLookup.entscheidePLZ(
            "10115",
            vorwärts: CityLookup.Antwort(
                locality: "Berlin", administrativeArea: "Berlin", postalCode: "10115",
                name: "10115", isoCountryCode: "DE", country: "Deutschland"
            ),
            rückwärts: nil
        )
        XCTAssertEqual(ergebnis, .deutsch(PlaceCandidate(plz: "10115", ort: "Berlin", land: "Berlin")))
    }

    /// Ein Ort dicht an der Grenze: Die Ziffern stimmen und stehen in
    /// Deutschland — dass die Rückwärtsrunde jenseits davon landet, ändert
    /// daran nichts.
    func testTheTypedDigitsBeatALookAcrossTheBorder() {
        let ergebnis = CityLookup.entscheidePLZ(
            "78266",
            vorwärts: CityLookup.Antwort(
                locality: "Büsingen am Hochrhein", administrativeArea: "Baden-Württemberg",
                postalCode: "78266", isoCountryCode: "DE", country: "Deutschland"
            ),
            rückwärts: CityLookup.Antwort(
                locality: "Schaffhausen", postalCode: "8238",
                isoCountryCode: "CH", country: "Schweiz"
            )
        )
        XCTAssertEqual(ergebnis, .deutsch(PlaceCandidate(
            plz: "78266", ort: "Büsingen am Hochrhein", land: "Baden-Württemberg"
        )))
    }
}
