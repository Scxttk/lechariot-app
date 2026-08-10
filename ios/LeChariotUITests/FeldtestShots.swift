import XCTest

/// **Bilder für den Feldtest vom 09.08.** — der Weg zu den Angaben eines
/// Artikels, der schon auf der Liste steht.
///
/// Scott im Feldtest: „Kohl steht auf der Liste und ich komme an seine
/// Angaben nicht mehr heran." Diese Bilder halten fest, was der Finger
/// wirklich vorfindet — vor und nach dem Umbau.
///
/// Die Bilder gehen als Anhang ins `.xcresult`; herausholen mit
/// `xcrun xcresulttool export attachments`.
final class FeldtestShots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Der neue Weg: ein sichtbarer Knopf auf der Kachel, ein Griff, und es
    /// steht dieselbe Angaben-Schicht da wie beim Anlegen.
    func testWriteTheNewDetailPathShots() {
        launch()
        addItem("Kohl")

        let kachel = kachel(mit: "Kohl")
        XCTAssertTrue(kachel.waitForExistence(timeout: 15),
                      "Die Kachel steht nicht:\n" + app.debugDescription)
        attach(name: "n1-liste-mit-kohl")

        let knopf = app.buttons["list.tile.detail"].firstMatch
        XCTAssertTrue(knopf.waitForExistence(timeout: 10),
                      "Die Kachel trägt keinen sichtbaren Weg zu den Angaben:\n"
                      + app.debugDescription)
        knopf.tap()

        // Die Schicht ist da, wenn ihre Chips da sind — und „Fertig" ist der
        // Ausgang, der keine Tastatur braucht.
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10),
                      "Die Angaben-Schicht kommt nicht:\n" + app.debugDescription)
        attach(name: "n2-angaben-schicht")
    }

    /// **Das volle Raster** — drei Spalten, und darunter Artikel mit
    /// Preisfähnchen. Der neue Knopf sitzt in derselben Ecke wie das Fähnchen;
    /// ob sich die beiden ins Gehege kommen, entscheidet kein Argument,
    /// sondern dieses Bild.
    func testWriteTheFullGridShot() {
        launch()
        for artikel in ["Vollmilch", "Kohl", "Butter", "Bananen", "Brot"] {
            addItem(artikel)
        }
        // Die Schicht aus dem letzten Anlegen weg, sonst verdeckt sie das Raster.
        let fertig = app.buttons["list.input.done"]
        if fertig.waitForExistence(timeout: 5) { fertig.tap() }

        XCTAssertTrue(kachel(mit: "Vollmilch").waitForExistence(timeout: 15))
        attach(name: "n3-raster-mit-fahnen")

        // Und abgehakt: Die Kachel tritt zurück, und der Angaben-Knopf muss
        // mitgehen — sonst leuchtet ein Bedienelement auf etwas Erledigtem.
        kachel(mit: "Butter").tap()
        _ = kachel(mit: "Kohl").waitForExistence(timeout: 5)
        attach(name: "n4-abgehakt")
    }

    /// Der Weg, wie er heute ist: Liste → Halten → Trefferblatt → ⋯ → Angaben.
    func testWriteTheDetailPathShots() {
        launch()
        addItem("Kohl")

        let kachel = kachel(mit: "Kohl")
        XCTAssertTrue(kachel.waitForExistence(timeout: 15),
                      "Die Kachel steht nicht:\n" + app.debugDescription)

        attach(name: "1-liste-mit-kohl")

        // Halten ist der einzige Weg, den der Finger hat — und nichts auf der
        // Kachel sagt das.
        kachel.press(forDuration: 0.6)
        XCTAssertTrue(
            app.navigationBars.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "Treffer für")
            ).firstMatch.waitForExistence(timeout: 10),
            "Das Trefferblatt kommt nicht:\n" + app.debugDescription
        )
        attach(name: "2-trefferblatt-ohne-treffer")

        // Und dort oben links das ⋯, hinter dem die Angaben liegen.
        let mehr = app.buttons["matches.more"]
        XCTAssertTrue(mehr.waitForExistence(timeout: 10), "Kein ⋯-Menü im Blatt")
        mehr.tap()
        XCTAssertTrue(app.buttons["matches.item.detail"].waitForExistence(timeout: 5),
                      "Das ⋯-Menü hat keinen Punkt „Angaben“")
        attach(name: "3-menue-offen")

        app.buttons["matches.item.detail"].tap()
        XCTAssertTrue(app.buttons["itemDetail.cancel"].waitForExistence(timeout: 10),
                      "Das Angaben-Blatt kommt nicht")
        attach(name: "4-angaben-blatt")
    }

    // MARK: Helfer

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func kachel(mit text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    private func launch() {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start landet nicht in der Liste")
    }

    private func addItem(_ text: String) {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
        feld.typeText(text + "\n")
        let panel = app.buttons["list.detailPanel.more"]
        if app.buttons["itemDetail.cancel"].exists {
            app.buttons["itemDetail.cancel"].tap()
        } else if panel.waitForExistence(timeout: 3) {
            app.swipeUp()
            _ = panel.waitForNonExistence(timeout: 3)
        }
    }
}
