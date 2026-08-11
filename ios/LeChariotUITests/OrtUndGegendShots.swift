import XCTest

/// **Bilder zu den Punkten 6 und 7 der Bedienrunde vom 11.08.** (#143, #144).
///
/// Sechs Zustände, die vorher entweder falsch waren oder gar nicht existierten:
/// die Vorschlagsliste zu einer Großstadt, der bestätigte Ort danach, die
/// ehrliche Fehlermeldung, die frische Gegend mit ihrer Ladezeile, dieselbe
/// Gegend nach dem Lauf und die gescheiterte Anforderung.
///
/// Der Bogen fotografiert nur. Auf dem Stand von `main` liefert er das Vorher
/// (die Fehlermeldung dort, wo jetzt der Ort steht; keine Ladezeile), auf dem
/// Zweig das Nachher — dieselben Fixtures, dieselben Griffe.
///
/// Die Bilder gehen als Anhang ins `.xcresult`; herausholen mit
/// `xcrun xcresulttool export attachments`.
final class OrtUndGegendShots: XCTestCase {
    private var app: XCUIApplication!

    private let vorschlaege =
        "Stuttgart|Baden-Württemberg,Deutschland;Stuttgarter-Straße|01189-Dresden,Deutschland"
    private let ortsantworten =
        "Stuttgart,Baden-Württemberg,Deutschland>Stuttgart|70173|Baden-Württemberg"
        + ";Stuttgart>Stuttgart|70173|Baden-Württemberg"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: 1 — Die Ortsauswahl

    func testWriteTheCityLookupShots() {
        starteBeimOrtsschritt(antworten: ortsantworten)
        let feld = app.textFields["region.input"]
        feld.tap()
        feld.typeText("Stuttgart")

        let vorschlag = app.descendants(matching: .any)
            .matching(identifier: "region.suggestion").element(boundBy: 0)
        XCTAssertTrue(vorschlag.waitForExistence(timeout: 15),
                      "Keine Vorschläge:\n" + app.debugDescription)
        attach(name: "1a-vorschlaege-grossstadt")

        vorschlag.tap()
        let verstanden = app.descendants(matching: .any)["region.resolvedPlace"]
        if verstanden.waitForExistence(timeout: 20) {
            attach(name: "1b-ort-bestaetigt")
        } else {
            // Auf dem Stand von `main` endet derselbe Griff in „nicht
            // gefunden" — und das **ist** der Befund. Der Bogen hält ihn fest
            // und bleibt grün.
            attach(name: "1b-nicht-gefunden-vorher")
        }
    }

    /// Der Fehlschlag, wie er aussehen soll: benannt, mit der Eingabe des
    /// Menschen, ohne dass irgendwo eine alte Zahl auftaucht.
    func testWriteTheHonestFailureShot() {
        starteBeimOrtsschritt(antworten: "Quatschhausen>Quatschhausen|99999|Sachsen")
        let feld = app.textFields["region.input"]
        feld.tap()
        feld.typeText("Stuttgart")

        let vorschlag = app.descendants(matching: .any)
            .matching(identifier: "region.suggestion").element(boundBy: 0)
        XCTAssertTrue(vorschlag.waitForExistence(timeout: 15))
        vorschlag.tap()

        let fehler = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "kennt Apple nicht")
        ).firstMatch
        _ = fehler.waitForExistence(timeout: 20)
        attach(name: "2-fehlschlag-ohne-rueckfall")
    }

    // MARK: 2 — Die frische Gegend

    func testWriteTheFreshAreaShots() {
        starteHinterDemAssistenten(["-uiTestingGegendWirdFertig"])
        fuegeRegionHinzu("17419")
        oeffneWaehler()

        let hinweis = app.descendants(matching: .any)["markets.areaFetching"]
        if hinweis.waitForExistence(timeout: 20) {
            attach(name: "3a-frische-gegend-laedt")
        } else {
            attach(name: "3a-frische-gegend-ohne-hinweis-vorher")
        }

        // Und derselbe Bildschirm, nachdem der Lauf gelandet ist.
        _ = app.buttons["picker.chain.Netto"].waitForExistence(timeout: 40)
        attach(name: "3b-gegend-versorgt")
    }

    func testWriteTheFailedAreaRequestShot() {
        starteHinterDemAssistenten(["-uiTestingGegendScheitert"])
        fuegeRegionHinzu("17419")
        oeffneWaehler()

        _ = app.descendants(matching: .any)["markets.areaFailed"].waitForExistence(timeout: 30)
        attach(name: "4-gebiets-anforderung-gescheitert")
    }

    // MARK: Helfer

    private func starteBeimOrtsschritt(antworten: String) {
        app.launchArguments = [
            "-uiTesting",
            "-uiTestingAddressSuggestions", vorschlaege,
            "-uiTestingCityLookup", antworten,
        ]
        app.launch()
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")
        app.tippe(app.buttons["onboarding.skip"], "Überspringen im Assistenten")
        XCTAssertTrue(app.textFields["region.input"].waitForExistence(timeout: 20))
    }

    private func starteHinterDemAssistenten(_ extra: [String]) {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"] + extra
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20))
    }

    private func fuegeRegionHinzu(_ plz: String) {
        app.tabBars.buttons["Einstellungen"].tap()
        oeffnePlaces()
        app.tippe(app.buttons["Region hinzufügen"], "Region hinzufügen")
        let feld = app.textFields["region.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
        feld.typeText(plz)
        app.buttons["Weiter"].tap()
        XCTAssertTrue(app.staticTexts["PLZ \(plz)"].waitForExistence(timeout: 20))
    }

    private func oeffneWaehler() {
        oeffnePlaces()
        app.tippe(app.buttons["Filialen bearbeiten"], "Filialen bearbeiten")
        XCTAssertTrue(app.navigationBars["Filialen wählen"].waitForExistence(timeout: 20))
    }

    private func oeffnePlaces() {
        guard !app.navigationBars["Filialen und Regionen"].exists else { return }
        app.tippe(app.buttons["settings.places"], "Filialen und Regionen")
    }

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
