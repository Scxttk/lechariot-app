import XCTest

/// **Bilder für die Bedienrunde vom 08.08.** — der Wähler, wie er auf dem
/// Gerät steht, mit einer Auswahl, die schon getroffen ist.
///
/// Warum eine Journey und nicht der Bilderbogen aus dem Unit-Ziel: Der Wähler
/// lädt sein Verzeichnis über die Repositories und geocodiert die PLZ. Beides
/// hängt an `AppRepositories.usesMockData`, das erst der Startschalter
/// `-uiTesting` umlegt. Im Unit-Ziel wäre das ein Nachbau — und ein Nachbau
/// beantwortet die Frage nicht, um die es hier geht: Was schiebt sich in der
/// **echten** Liste vor die Ketten.
///
/// Die Bilder gehen als Anhang ins `.xcresult`; herausholen mit
/// `xcrun xcresulttool export attachments`.
final class BedienrundeShots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // Drei Filialen sind schon gewählt — genau der Zustand, über den
        // Scott gestolpert ist. Mit einer einzigen wäre nichts zu sehen.
        app.launchArguments = [
            "-uiTesting", "-uiTestingOnboarded", "-uiTestingOnboardedThreeChains",
        ]
        app.launch()
    }

    func testWriteThePickerShot() {
        openBranchPicker()
        // Der Wähler baut seine Zeilen nach; ohne die Kettenzeile im Bild
        // wäre das Bild kein Beleg.
        XCTAssertTrue(app.buttons["picker.chain.Lidl"].waitForExistence(timeout: 20),
                      "Der Wähler ist nicht fertig geladen:\n" + app.debugDescription)

        attach(name: "wähler-oben")

        // Und einmal so weit gescrollt, wie ein Nutzer scrollen müsste, um an
        // die letzte Kette zu kommen.
        app.swipeUp()
        attach(name: "wähler-nach-einem-wisch")
    }

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func openBranchPicker() {
        let places = app.buttons["settings.places"]
        openTab("Einstellungen")
        XCTAssertTrue(places.waitForExistence(timeout: 20), "Kein Weg zu den Filialen")
        places.tap()
        let edit = app.buttons["Filialen bearbeiten"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        edit.tap()
        XCTAssertTrue(app.navigationBars["Filialen wählen"].waitForExistence(timeout: 20))
    }

    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "Kein Reiter \(name)")
        tab.tap()
    }
}
