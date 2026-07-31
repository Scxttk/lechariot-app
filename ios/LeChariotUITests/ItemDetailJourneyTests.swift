import XCTest

/// **Die Angaben am Artikel, einmal durchgespielt** (L-5a).
///
/// Der Unit-Test prüft die Regeln des Vokabulars; hier geht es um den Weg
/// dorthin: dass der Artikelname überhaupt anfassbar ist, dass „Abbrechen"
/// wirklich nichts behält, und dass die Zeile danach am Artikel steht.
final class ItemDetailJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    func testChoosingChipsPutsANoteUnderTheItem() {
        completeOnboarding()
        addItem("Vollmilch")

        app.buttons["list.item.detail"].firstMatch.tap()
        XCTAssertTrue(app.buttons["itemDetail.done"].waitForExistence(timeout: 10),
                      "Das Blatt mit den Angaben ist nicht aufgegangen")

        app.buttons["1 l"].firstMatch.tap()
        app.buttons["Bio"].firstMatch.tap()
        app.buttons["itemDetail.done"].tap()

        XCTAssertTrue(app.buttons["Vollmilch, 1 l · Bio"].waitForExistence(timeout: 10),
                      "Die Angabe muss unter dem Artikel stehen\n" + app.debugDescription)
        // Der Artikel selbst bleibt das Gattungswort — daran hängt, dass die
        // Suche ihn weiter findet. Die Beschriftung oben beweist das schon
        // („Vollmilch, 1 l · Bio", nicht „1 l Bio Vollmilch"); hier steht die
        // Gegenprobe, dass die Angabe **allein** keinen Artikel bildet.
        XCTAssertFalse(app.buttons["1 l · Bio"].exists,
                       "Der Listeneintrag darf sich nicht in die Angabe verwandeln")
    }

    /// „Abbrechen" heißt abbrechen. Ein Blatt, das die Auswahl trotzdem behält,
    /// wäre schlimmer als eines ohne Abbrechen-Knopf.
    func testCancellingKeepsNothing() {
        completeOnboarding()
        addItem("Vollmilch")

        app.buttons["list.item.detail"].firstMatch.tap()
        XCTAssertTrue(app.buttons["itemDetail.cancel"].waitForExistence(timeout: 10))
        app.buttons["Bio"].firstMatch.tap()
        app.buttons["itemDetail.cancel"].tap()

        XCTAssertTrue(app.buttons["Vollmilch"].waitForExistence(timeout: 10),
                      "Ohne Angabe ist die Beschriftung genau der Artikelname")
        XCTAssertFalse(app.buttons["Vollmilch, Bio"].exists,
                       "Abgebrochen ist abgebrochen")
    }

    // MARK: Helfer

    private func addItem(_ text: String) {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
        feld.typeText(text + "\n")
        XCTAssertTrue(app.buttons[text].waitForExistence(timeout: 10))
    }

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
