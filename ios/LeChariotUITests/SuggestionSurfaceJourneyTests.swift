import XCTest

/// **Die Vorschläge kleben an der Eingabezeile** (L-2).
///
/// Der Streifen war ein Abschnitt mitten in der Liste und rutschte mit jeder
/// weiteren Zeile weiter aus dem Daumenbereich. Die Rückmeldung der ersten
/// Testerin von außen — „nicht einhändig erreichbar" — meinte nicht das Feld,
/// sondern alles, was zum Hinzufügen dazugehört.
///
/// Der erste Test hier prüft deshalb die **Lage** und nicht die Existenz: Dass
/// es Kacheln gibt, war vorher auch wahr.
final class SuggestionSurfaceJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    /// Die Kacheln liegen **über** der Eingabezeile und unter der Liste — und
    /// zwar am Bildschirm gemessen, nicht in der Elementhierarchie.
    func testTheSuggestionsSitDirectlyAboveTheInputBar() {
        completeOnboarding()

        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15), "Keine Eingabezeile")
        let kachel = app.buttons["Milch hinzufügen"]
        XCTAssertTrue(kachel.waitForExistence(timeout: 10), "Keine Vorschlagskachel")

        XCTAssertLessThanOrEqual(
            kachel.frame.maxY, feld.frame.minY + 1,
            "Die Kacheln müssen über der Zeile liegen, nicht irgendwo in der Liste"
        )
        // **Die Zusicherung, die wirklich trägt.** Die Zeile darüber galt auch
        // vorher: Im Leerzustand lagen die Kacheln unter der Begrüßung, also
        // ebenfalls über dem Feld — nur eben oben am Bildschirm. Erst die Lage
        // in der unteren Hälfte ist das, worum es bei L-2 geht: der
        // Daumenbereich.
        //
        // Erster Versuch war der Abstand zwischen Kachel und Zeile („unter
        // 80 pt"): gemessen 123 pt, und das ist richtig so — „Milch" steht in
        // der **obersten** Reihe des Rasters, der Abstand ist also die Höhe des
        // Streifens und nicht sein Abstand zur Zeile.
        XCTAssertGreaterThan(
            kachel.frame.minY, app.frame.midY,
            "Der Streifen gehört in die untere Bildschirmhälfte, in Daumenreichweite"
        )
    }

    /// Tippen schließt die Fläche, der Knopf holt sie zurück.
    ///
    /// Die beiden Richtungen zusammen in einem Test, weil ein zugeklappter
    /// Streifen allein nicht zu unterscheiden ist von einem, der gar nicht
    /// mehr da ist.
    func testTypingClosesTheSurfaceAndTheButtonBringsItBack() {
        completeOnboarding()

        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Milch hinzufügen"].waitForExistence(timeout: 10),
                      "Vor dem ersten Artikel steht die Fläche offen")

        feld.tap()
        feld.typeText("Vollmilch\n")
        XCTAssertTrue(app.staticTexts["Vollmilch"].waitForExistence(timeout: 10),
                      "Der Artikel ist nicht auf der Liste gelandet")

        let knopf = app.buttons["list.suggestions.toggle"]
        XCTAssertTrue(knopf.waitForExistence(timeout: 5), "Der Knopf muss bleiben")
        XCTAssertEqual(knopf.label, "Vorschläge einblenden",
                       "Der Zustand gehört in den Namen, ein gedrehtes Winkelzeichen sagt nichts")
        XCTAssertFalse(app.buttons["Milch hinzufügen"].exists,
                       "Wer tippt, weiß was er braucht — die Fläche gibt den Platz zurück")

        knopf.tap()
        XCTAssertTrue(app.buttons["Milch hinzufügen"].waitForExistence(timeout: 5),
                      "Der Knopf muss sie zurückholen")
        XCTAssertEqual(app.buttons["list.suggestions.toggle"].label, "Vorschläge ausblenden")
    }

    // MARK: Helfer

    private func completeOnboarding() {
        app.buttons["onboarding.primary"].tap()   // Willkommen
        app.buttons["onboarding.skip"].tap()      // Name
        let plz = app.textFields["Postleitzahl"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15))
        plz.tap()
        plz.typeText("01219")
        app.buttons["onboarding.primary"].tap()
        app.buttons["onboarding.skip"].tap()      // Haushalt
        app.buttons["onboarding.skip"].tap()      // Ernährung
        app.buttons["onboarding.primary"].tap()   // Einwilligung
        let branch = app.buttons["Lidl, Dresden Reick"]
        XCTAssertTrue(branch.waitForExistence(timeout: 15))
        branch.tap()
        app.buttons["markets.done"].tap()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }
}
