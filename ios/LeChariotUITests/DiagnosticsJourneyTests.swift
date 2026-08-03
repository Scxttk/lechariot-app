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

    /// **Scotts Punkt 3 vom 03.08.: „Ich finde das Werkzeug nicht."**
    ///
    /// Die Geste feuerte — aber erst nach einer vollen Sekunde. Am 03.08. mit
    /// gestuften Druckdauern nachgemessen: 0,6 s nichts, 0,8 s nichts, 1,0 s
    /// auf. Wer bei 0,8 s loslässt, bekommt **keinerlei** Rückmeldung und
    /// schließt daraus, dass es die Geste nicht gibt. Genau das ist passiert.
    ///
    /// Diese Journey hält die neue Untergrenze fest. Gegen `2ad621d` fällt sie.
    func testAShorterPressIsEnough() {
        scrollToVersion()
        versionRow.press(forDuration: 0.7)

        XCTAssertTrue(
            app.buttons["settings.diagnostics"].waitForExistence(timeout: 5),
            "0,7 s müssen reichen — eine Sekunde trifft nur, wer die Zahl kennt\n"
            + app.debugDescription
        )
    }

    /// Die Gegenrichtung: Ein Tipp ist keine Geste. Ohne diesen Fall wäre die
    /// Lockerung oben der Weg zu einer Diagnose, die jeder aus Versehen findet.
    func testAPlainTapStillRevealsNothing() {
        scrollToVersion()
        versionRow.tap()

        XCTAssertFalse(app.buttons["settings.diagnostics"].waitForExistence(timeout: 3),
                       "ein Tipp darf das Werkzeug nicht aufmachen")
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

        // Der Bildercache-Abschnitt schiebt „Verstecken" unter die Kante —
        // erst hinscrollen, dann tippen.
        let verstecken = app.buttons["diagnostics.hide"]
        var versuche = 0
        while !verstecken.isHittable && versuche < 6 {
            app.swipeUp()
            versuche += 1
        }
        XCTAssertTrue(verstecken.waitForExistence(timeout: 5))
        verstecken.tap()
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
