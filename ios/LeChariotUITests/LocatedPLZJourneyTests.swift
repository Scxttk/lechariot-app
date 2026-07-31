import XCTest

/// **Die erkannte Postleitzahl muss der Mensch zu sehen bekommen.**
///
/// Gemeldet von Scott am Gerät (Build `2026.0731.1147`): „Standort verwenden"
/// sprang sofort weiter. `useLocation()` schrieb die PLZ ins Feld und rief in
/// derselben Runde `submit(…)` — sie stand **null Bilder** lang auf dem Schirm.
///
/// Das ist kein Schönheitsfehler. Genau hier hätte Scotts Bruder am 30.07.
/// gesehen, dass für Ahlbeck **17373** erkannt wurde statt 17419 — die PLZ des
/// 24,5 km entfernten Ueckermünde. Stattdessen lief alles grün durch: eine
/// gestempelte Gebiets-Anforderung, dreizehn Filialen, drei fehlende Ketten,
/// und niemand konnte sagen warum. **Eine Ableitung, die der Nutzer nie zu
/// sehen bekommt, kann er auch nicht korrigieren.**
///
/// Geprüft wird deshalb der Ablauf und nicht die Ortung: Unter
/// `-uiTestingLocatedPLZ` liefert der Locator eine feste PLZ, ohne
/// Systemdialog und ohne Geocoder. Die Ortung war nie kaputt.
final class LocatedPLZJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    /// Bewusst **nicht** 01219: Das ist die PLZ, die alle anderen Journeys
    /// tippen. Stünde sie hier, ließe sich „erkannt" nicht von „eingetippt"
    /// unterscheiden.
    private let erkannt = "01067"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingLocatedPLZ", erkannt]
        app.launch()
    }

    func testTheDetectedPostcodeIsShownAndTheStepWaits() {
        app.buttons["onboarding.primary"].tap()   // Willkommen
        app.buttons["onboarding.skip"].tap()      // Name

        let feld = app.textFields["Postleitzahl"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))

        app.buttons["Standort verwenden"].tap()

        // 1. Die Zahl steht im Feld.
        XCTAssertEqual(
            feld.value as? String, erkannt,
            "Die erkannte PLZ muss im Feld stehen, nicht nur im Speicher"
        )
        // 2. **Der Schritt ist noch da.** Das ist der eigentliche Prüfpunkt:
        //    Vorher war dieser Bildschirm hier schon weg.
        XCTAssertTrue(
            feld.exists,
            "Der Schritt darf nicht von allein weiterspringen — sonst sieht niemand die PLZ"
        )
        // 3. Und die App sagt, dass die Zahl abgeleitet ist und korrigierbar.
        XCTAssertTrue(
            app.descendants(matching: .any)["region.locatedHint"].exists,
            "Ohne den Hinweis liest sich die erkannte PLZ wie eine eigene Eingabe\n"
            + app.debugDescription
        )

        // 4. Weiter geht es, wenn der Mensch es sagt.
        app.buttons["onboarding.primary"].tap()
        XCTAssertFalse(
            app.textFields["Postleitzahl"].waitForExistence(timeout: 10),
            "Nach „Weiter“ muss der Schritt wechseln"
        )
    }

    /// Wer die erkannte Zahl überschreibt, bekommt den Hinweis nicht mehr —
    /// dann ist es wieder seine eigene Eingabe und nichts Abgeleitetes.
    func testOverwritingTheDetectedCodeRetiresTheHint() {
        app.buttons["onboarding.primary"].tap()
        app.buttons["onboarding.skip"].tap()

        let feld = app.textFields["Postleitzahl"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        app.buttons["Standort verwenden"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["region.locatedHint"].exists)

        feld.tap()
        feld.typeText("9")   // 010679 — nicht mehr die erkannte Zahl
        XCTAssertFalse(
            app.descendants(matching: .any)["region.locatedHint"].exists,
            "Der Hinweis gehört zur erkannten Zahl, nicht zum Feld"
        )
    }
}
