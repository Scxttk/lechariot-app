import XCTest

/// **„Anklam" tippen dürfen** — Scotts Wunsch vom 02.08. aus Ahlbeck.
///
/// Gegen den Stand davor fallen diese Journeys mit derselben Ursache: Das
/// Regionsfeld war ein Ziffernblock mit PLZ-Prüfung, „Weiter" blieb bei
/// Buchstaben grau, und es gab keinen Knopf, der etwas anderes getan hätte.
///
/// Geprüft wird der Ablauf, **nicht Apples Geocoder**: Unter
/// `-uiTestingCityLookup` antwortet `CityLookup` mit einem festen Ort. Ein
/// Test, der am Netz hängt, wird rot, ohne dass etwas kaputt ist — dieselbe
/// Naht wie `-uiTestingLocatedPLZ` beim Ortungsknopf.
final class CityNameJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    private func start(cityLookup: String? = nil, alternatives: String? = nil) {
        continueAfterFailure = false
        app = XCUIApplication()
        var args = ["-uiTesting"]
        if let cityLookup { args += ["-uiTestingCityLookup", cityLookup] }
        if let alternatives { args += ["-uiTestingCityAlternatives", alternatives] }
        app.launchArguments = args
        app.launch()
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")   // Willkommen
        app.tippe(app.buttons["onboarding.skip"], "Überspringen im Assistenten")      // Name
    }

    private var field: XCUIElement { app.textFields["region.input"] }
    private var primary: XCUIElement { app.buttons["onboarding.primary"] }

    private func type(_ text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText(text)
    }

    // MARK: Der Hauptweg

    /// Scotts Satz in der Sprache des Testläufers: Ort tippen, suchen, weiter.
    func testTypingAnklamLeadsToItsPostcode() {
        start(cityLookup: "Anklam|17389|Mecklenburg-Vorpommern")
        type("Anklam")

        // 1. Der Knopf sucht, er schaltet nicht weiter. Ein Name ist noch
        //    keine Region.
        XCTAssertEqual(primary.label, "Ort suchen", "Bei einem Ortsnamen führt der Knopf zu Apple, nicht in die App")
        primary.tap()

        // 2. **Was Apple verstanden hat, steht da, bevor es gespeichert wird.**
        let verstanden = app.descendants(matching: .any)["region.resolvedPlace"]
        XCTAssertTrue(
            verstanden.waitForExistence(timeout: 10),
            "Ohne die Zeile speichert die App eine Ableitung, die niemand gesehen hat\n" + app.debugDescription
        )
        XCTAssertTrue(verstanden.label.contains("17389"), "Die PLZ gehört dazu — mit ihr wird gesucht")
        XCTAssertTrue(verstanden.label.contains("Anklam"))

        // 3. Erst jetzt geht es weiter, und der Schritt wechselt.
        XCTAssertEqual(primary.label, "Weiter")
        primary.tap()
        XCTAssertFalse(
            field.waitForExistence(timeout: 10),
            "Nach „Weiter“ muss der Schritt wechseln"
        )
    }

    /// Die PLZ-Eingabe bleibt, was sie war: tippen, „Weiter", fertig — **kein**
    /// Zwischenschritt „Ort suchen".
    func testTypingAPostcodeStillGoesStraightThrough() {
        start()
        type("01219")

        XCTAssertEqual(primary.label, "Weiter", "Fünf Ziffern brauchen keinen Geocoder")
        primary.tap()
        XCTAssertFalse(field.waitForExistence(timeout: 10), "Die PLZ-Strecke von vorher muss unverändert durchlaufen")
    }

    // MARK: Mehrdeutigkeit

    /// **„Meintest du …" — der Fall, den Apple selbst nicht anbietet.**
    ///
    /// Auf „Neustadt" nennt der Geocoder genau einen Ort (Wolgast, wo die
    /// Neustadt ein Ortsteil ist). Die Auswahl entsteht erst dadurch, dass die
    /// App über die sechzehn Bundesländer nachfragt.
    func testAnAmbiguousNameOffersAChoice() {
        start(cityLookup: "Neustadt (Dosse)|16845|Brandenburg;Neustadt|93333|Bayern;Neustadt/Vogtland|08223|Sachsen")
        type("Neustadt")
        primary.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["region.candidatesTitle"].waitForExistence(timeout: 10),
            "Bei mehreren Orten desselben Namens darf die App nicht einen davon aussuchen\n" + app.debugDescription
        )
        // Ohne Bundesland stünde dort dreimal dasselbe Wort.
        XCTAssertTrue(app.buttons["region.candidate.16845"].exists)
        XCTAssertTrue(app.buttons["region.candidate.93333"].exists)
        XCTAssertTrue(app.buttons["region.candidate.08223"].exists)

        // Gewählt wird der sächsische — und genau seine PLZ steht danach da.
        app.buttons["region.candidate.08223"].tap()
        let verstanden = app.descendants(matching: .any)["region.resolvedPlace"]
        XCTAssertTrue(verstanden.waitForExistence(timeout: 5))
        XCTAssertTrue(verstanden.label.contains("08223"))
        XCTAssertEqual(primary.label, "Weiter")
    }

    /// Auch wenn die erste Antwort passt, muss der andere Ort desselben Namens
    /// erreichbar bleiben — sonst ist die richtige Antwort auf die falsche
    /// Frage endgültig.
    func testAConfirmedPlaceCanStillBeExchanged() {
        start(
            cityLookup: "Neustadt (Dosse)|16845|Brandenburg",
            alternatives: "Neustadt (Dosse)|16845|Brandenburg;Neustadt/Vogtland|08223|Sachsen"
        )
        type("Neustadt")
        primary.tap()
        XCTAssertTrue(app.descendants(matching: .any)["region.resolvedPlace"].waitForExistence(timeout: 10))

        app.buttons["region.otherPlace"].tap()
        XCTAssertTrue(
            app.buttons["region.candidate.08223"].waitForExistence(timeout: 10),
            "„Anderer Ort …“ muss die übrigen Orte desselben Namens zeigen"
        )
    }

    // MARK: Wenn nichts passt

    func testAnUnknownNameSaysSoInsteadOfGuessing() {
        start(cityLookup: "NICHTS")
        type("Quatschhausen")
        primary.tap()

        let fehler = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "kennt Apple nicht als Ort")
        ).firstMatch
        XCTAssertTrue(
            fehler.waitForExistence(timeout: 10),
            "Ein Ort, den es nicht gibt, darf nicht stillschweigend zu irgendeiner PLZ werden\n" + app.debugDescription
        )
    }

    /// Ein bestätigter Ort gilt nur zu der Eingabe, aus der er stammt —
    /// dieselbe Regel wie beim Ortungs-Hinweis.
    func testTypingOnRetiresTheConfirmedPlace() {
        start(cityLookup: "Anklam|17389|Mecklenburg-Vorpommern")
        type("Anklam")
        primary.tap()
        XCTAssertTrue(app.descendants(matching: .any)["region.resolvedPlace"].waitForExistence(timeout: 10))

        field.tap()
        field.typeText("er")   // „Anklamer" — nicht mehr der bestätigte Ort
        XCTAssertFalse(
            app.descendants(matching: .any)["region.resolvedPlace"].exists,
            "Der bestätigte Ort gehört zur Eingabe, nicht zum Feld"
        )
        XCTAssertEqual(primary.label, "Ort suchen")
    }
}
