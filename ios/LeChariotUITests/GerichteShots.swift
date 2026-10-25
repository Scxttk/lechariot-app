import XCTest

/// **Bilder der Kochen-Bildschirme** für Scotts Bildabnahme: Einwilligung,
/// Vorschläge, Vorschlag im Einzelnen, gesuchtes Gericht.
///
/// Hell oder dunkel entscheidet der Simulator
/// (`xcrun simctl ui <udid> appearance dark`), der Bogen fotografiert nur.
/// Die Bilder gehen als Anhang ins `.xcresult`; herausholen mit
/// `xcrun xcresulttool export attachments`.
final class GerichteShots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testWriteTheKochenShots() {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingOnboardedThreeChains"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20))

        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tapAndAwaitKeyboard(in: app)
        for wort in ["Nudeln", "Tomaten", "Milch", "Eier"] {
            feld.typeText(wort)
            app.buttons["Artikel hinzufügen"].tap()
        }
        app.buttons["list.input.done"].firstMatch.tap()
        attach("0-liste-mit-kochen-knopf")

        app.buttons["list.kochen"].tap()
        XCTAssertTrue(app.buttons["gerichte.erlauben"].waitForExistence(timeout: 10))
        attach("1-einwilligung")
        app.buttons["gerichte.erlauben"].tap()

        let vorschlagen = app.buttons["gerichte.vorschlagen"]
        XCTAssertTrue(vorschlagen.waitForExistence(timeout: 10))
        attach("2-aus-der-liste-leer")
        vorschlagen.tap()
        XCTAssertTrue(app.buttons["gerichte.vorschlag"].firstMatch.waitForExistence(timeout: 10))
        attach("3-vorschlaege")

        app.buttons["gerichte.vorschlag"].firstMatch.tap()
        XCTAssertTrue(app.buttons["gerichte.hinzufuegen"].waitForExistence(timeout: 10))
        attach("4-vorschlag-zutaten")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.segmentedControls.buttons["Gericht"].tap()
        let gericht = app.textFields["gerichte.feld"]
        XCTAssertTrue(gericht.waitForExistence(timeout: 10))
        gericht.tap()
        gericht.typeText("Lasagne für 4\n")
        XCTAssertTrue(app.buttons["gerichte.hinzufuegen"].waitForExistence(timeout: 10))
        attach("5-gericht-zutaten")
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
