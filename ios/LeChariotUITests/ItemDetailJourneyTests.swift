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
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
    }

    func testChoosingChipsPutsANoteUnderTheItem() {
        waitForList()
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
        waitForList()
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

    /// **Das Mengen-Menü kommt von selbst** ([UI-8], Scott 01.08.).
    ///
    /// Der Moment nach dem Anlegen ist der einzige, in dem jemand noch weiß,
    /// welche Größe er meint. Gegen den alten Stand fällt dieser Test durch:
    /// Dort öffnete sich nichts, bis jemand den Namen antippte.
    func testTheQuantityMenuOpensByItselfWhenAnItemIsCreated() {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
        feld.typeText("Butter\n")

        XCTAssertTrue(app.buttons["itemDetail.done"].waitForExistence(timeout: 10),
                      "Nach dem Anlegen muss das Mengen-Menü offen stehen")
        XCTAssertTrue(app.staticTexts["Menge"].exists)
        XCTAssertTrue(app.staticTexts["Größe"].exists)
        XCTAssertTrue(app.staticTexts["Art"].exists)
        XCTAssertTrue(app.staticTexts["Notiz"].exists, "Der Freitext ist neu und muss dastehen")
    }

    /// Der Freitext landet unter dem Artikel — und nirgends sonst.
    func testTheFreeTextNoteEndsUpUnderTheItem() {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
        feld.typeText("Butter\n")

        let notiz = app.textViews["itemDetail.note"].exists
            ? app.textViews["itemDetail.note"]
            : app.textFields["itemDetail.note"]
        XCTAssertTrue(notiz.waitForExistence(timeout: 10), "Kein Freitextfeld")
        notiz.tap()
        notiz.typeText("die im blauen Becher")
        app.buttons["itemDetail.done"].tap()

        XCTAssertTrue(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS[c] %@", "blauen Becher")
            ).firstMatch.waitForExistence(timeout: 10),
            "Die Notiz steht nicht unter dem Artikel"
        )
    }

    // MARK: Helfer

    private func addItem(_ text: String) {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
        feld.typeText(text + "\n")
        dismissQuantitySheet()
        XCTAssertTrue(app.buttons[text].waitForExistence(timeout: 10))
    }
    /// Schließt das Mengen-Menü, das seit [UI-8] beim Anlegen von selbst
    /// aufgeht. Die Journeys unten testen nicht das Menü, sondern was danach
    /// kommt — für sie ist es ein Zwischenschritt.
    private func dismissQuantitySheet() {
        let abbrechen = app.buttons["itemDetail.cancel"]
        if abbrechen.waitForExistence(timeout: 5) { abbrechen.tap() }
    }


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
