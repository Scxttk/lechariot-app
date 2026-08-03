import XCTest

/// **„Scotts Build hat es, der Tester-Build nicht" — im selben Build.**
///
/// Der Prüfpunkt ist der erste Test: Wer die Geste nicht kennt, findet in den
/// Einstellungen nichts. Alles Weitere hängt daran.
final class DiagnosticsJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
        openSettings()
    }

    private func openSettings() {
        let inBar = app.tabBars.buttons["Einstellungen"]
        let tab = inBar.exists ? inBar : app.buttons["Einstellungen"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "Tab Einstellungen fehlt")
        tab.tap()
    }

    private var versionRow: XCUIElement { app.descendants(matching: .any)["settings.version"] }

    /// **Erst scrollen, dann fragen.** Eine `List` baut nur, was zu sehen ist —
    /// die Version steht ganz unten und *existiert* vorher gar nicht. Wer hier
    /// auf `waitForExistence` wartet, wartet auf eine Zeile, die niemand
    /// gebaut hat.
    private func scrollToVersion() {
        var tries = 0
        while !versionRow.exists && tries < 12 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(
            versionRow.waitForExistence(timeout: 10),
            "die Zeile „Version“ muss am Ende der Einstellungen stehen\n" + app.debugDescription
        )
        tries = 0
        while !versionRow.isHittable && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(versionRow.isHittable, "die Version muss erreichbar sein")
    }

    // MARK: Der eigentliche Prüfpunkt

    func testATesterNeverSeesTheDiagnosticsRow() {
        scrollToVersion()
        XCTAssertFalse(
            app.buttons["settings.diagnostics"].exists,
            "ohne die Geste darf es den Eintrag nicht geben\n" + app.debugDescription
        )
    }

    func testALongPressOnTheVersionOpensTheTool() {
        scrollToVersion()
        versionRow.press(forDuration: 1.5)

        let row = app.buttons["settings.diagnostics"]
        XCTAssertTrue(
            row.waitForExistence(timeout: 5),
            "langer Druck auf die Version ist der Schaltweg\n" + app.debugDescription
        )
        row.tap()
        XCTAssertTrue(app.navigationBars["Diagnose"].waitForExistence(timeout: 10))
        // Der Schalter für die Live-Anzeige ist **aus**, nicht nur da.
        let hud = app.switches["diagnostics.hud"]
        XCTAssertTrue(hud.waitForExistence(timeout: 5))
        XCTAssertEqual(hud.value as? String, "0", "die Anzeige geht nicht mit dem Bildschirm an")
    }

    /// Verstecken nimmt den Eintrag wieder weg — der Weg zurück ist dieselbe
    /// Geste.
    func testHidingPutsTheRowAwayAgain() {
        scrollToVersion()
        versionRow.press(forDuration: 1.5)
        XCTAssertTrue(app.buttons["settings.diagnostics"].waitForExistence(timeout: 5))
        app.buttons["settings.diagnostics"].tap()
        XCTAssertTrue(app.navigationBars["Diagnose"].waitForExistence(timeout: 10))

        app.buttons["diagnostics.hide"].tap()
        scrollToVersion()
        XCTAssertFalse(
            app.buttons["settings.diagnostics"].exists,
            "verstecken muss den Eintrag wirklich entfernen"
        )
    }

    /// Ohne Bericht steht dort ein Satz und keine leere Liste — eine leere
    /// Liste sieht aus wie ein Fehler.
    func testAnEmptyToolSaysWhyItIsEmpty() {
        scrollToVersion()
        versionRow.press(forDuration: 1.5)
        app.buttons["settings.diagnostics"].tap()
        XCTAssertTrue(
            app.staticTexts["diagnostics.empty"].waitForExistence(timeout: 10),
            "„noch kein Bericht“ ist eine Antwort, eine leere Liste ist keine"
        )
    }
}
