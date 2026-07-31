import XCTest

/// **Der Platzhalter der Eingabezeile sagt, in welchem Zustand die Liste ist.**
///
/// Vorher stand dort immer „Artikel hinzufügen …" — eine Beschriftung des
/// Feldes, keine Ansprache. Vor der leeren Liste ist die Frage die eigentliche
/// Aufforderung; danach ist der einzige noch nützliche Hinweis, **dass es
/// weitergeht**. Von Bring! übernommen („Ich brauche …" / „Nächster
/// Artikel …"), Punkt L-6 aus dem Liste-Konzept.
///
/// Hier steht der deutsche Text ausdrücklich **als Zusicherung** und nicht als
/// Griff: Er ist das, was geprüft wird. Zum Anfassen hat das Feld seit
/// derselben Änderung `list.input` — genau weil vier andere Helfer es über
/// diesen Platzhalter griffen und mit ihm gebrochen wären.
final class ShoppingListInputJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
    }

    func testThePlaceholderAsksFirstAndThenSaysCarryOn() {
        waitForList()

        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15), "Keine Eingabezeile")
        XCTAssertEqual(
            feld.placeholderValue, "Was brauchst du?",
            "Vor dem ersten Artikel ist die Frage die Aufforderung"
        )

        feld.tap()
        feld.typeText("Butter")
        app.buttons["Artikel hinzufügen"].tap()

        XCTAssertEqual(
            app.textFields["list.input"].placeholderValue, "Nächster Artikel …",
            "Nach dem ersten Artikel soll der Platzhalter sagen, dass es weitergeht"
        )
        // Und der Zustand, den der Platzhalter behauptet, stimmt auch: Der
        // Artikel liegt auf der Liste, das Feld ist wieder leer.
        //
        // **Nicht** auf `app.keyboards` geprüft — ob der Simulator eine
        // Software-Tastatur zeigt, hängt an „Connect Hardware Keyboard" und
        // nicht an der App. Ein Test darauf misst die Einstellung des Rechners.
        XCTAssertTrue(
            app.buttons["Butter"].waitForExistence(timeout: 10),
            "Der Artikel ist nicht auf der Liste gelandet"
        )
        // Ein leeres Feld meldet als `value` seinen Platzhalter; stünde
        // „Butter" noch drin, stünde das hier.
        XCTAssertEqual(app.textFields["list.input"].value as? String, "Nächster Artikel …",
                       "Das Feld muss nach dem Hinzufügen wieder leer sein")
    }

    // MARK: Helfer

    /// Startet hinter dem Assistenten (`-uiTestingOnboarded`) und wartet, bis
    /// die Liste steht.
    ///
    /// Vorher lief hier der ganze Onboarding-Assistent — sieben Bildschirme für
    /// einen Zustand, den diese Journey nur durchquert. Gemessen am 2026-07-31:
    /// Der Assistent ist 72 % der 20-Minuten-Suite.
    private func waitForList() {
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
    }
}
