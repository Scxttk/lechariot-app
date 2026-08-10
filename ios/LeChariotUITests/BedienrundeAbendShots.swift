import XCTest

/// **Bilder für die Bedienrunde vom 10.08. Abend, Punkte 1, 2, 4 und 10.**
///
/// Drei der vier Punkte sind Sichtbefunde: ein Knopf, der im dunklen Modus
/// verschwindet, Zahlen, die zu klein für ihre Aussage stehen, und ein Blatt,
/// dessen Gewichtung sich umdreht. Kein Test findet so etwas — im
/// Bedienungshilfen-Baum steht jedes Element ordentlich da.
///
/// **Der dunkle Modus kommt vom Simulator, nicht aus der App.** Der
/// Darstellungs-Umschalter liegt in den Einstellungen, und der Assistent läuft
/// davor. Vor dem Lauf also
/// `xcrun simctl ui <udid> appearance dark`; die Bilder heißen entsprechend.
///
/// Die Bilder gehen als Anhang ins `.xcresult`; herausholen mit
/// `xcrun xcresulttool export attachments`.
final class BedienrundeAbendShots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: Punkt 1 und 4 — der Assistent

    /// **Punkt 1: der Weiter-Knopf am Wohnort-Schritt, in beiden Zuständen.**
    ///
    /// Der gemeldete Fehler steht auf dem *ersten* Bild: Solange nichts im Feld
    /// steht, ist der Knopf ausgeschaltet — und genau dieser Zustand war
    /// „dunkelgrau auf schwarz". Das zweite Bild ist die Gegenprobe mit
    /// getippter PLZ.
    func testWriteTheRegionStepPrimaryButton() {
        launchFresh()
        tapPrimary()                       // Willkommen
        let name = app.textFields["Vorname"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Scott")
        tapPrimary()                       // Name

        let feld = app.textFields["region.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15), "Der Wohnort-Schritt kommt nicht")
        // Die Tastatur weg — sie deckt sonst genau den Knopf ab, um den es geht.
        app.swipeDown()
        attach(name: "p1-wohnort-weiter-aus")

        feld.tap()
        feld.typeText("01219")
        app.swipeDown()
        attach(name: "p1-wohnort-weiter-an")
    }

    /// **Punkt 2: der Systemdialog zur Ortung, mit dem gekürzten Satz.**
    ///
    /// Der Purpose-String steht in keiner Ansicht dieser App — iOS setzt ihn in
    /// seinen eigenen Dialog, und wie viel Platz er dort frisst, sieht man
    /// nirgends sonst. Deshalb **`XCUIScreen.main`** und nicht `app.screenshot()`:
    /// Der Dialog gehört Springboard, im Bild der App steht er nicht.
    ///
    /// Vor dem Lauf muss die Erlaubnis zurückgesetzt sein, sonst fragt iOS gar
    /// nicht mehr:
    /// `xcrun simctl privacy <udid> reset location com.skoehler.lechariot`.
    func testWriteTheLocationPermissionDialog() throws {
        launchFresh()
        tapPrimary()                       // Willkommen
        let name = app.textFields["Vorname"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Scott")
        tapPrimary()                       // Name

        XCTAssertTrue(app.textFields["region.input"].waitForExistence(timeout: 15))
        app.swipeDown()                    // Tastatur weg
        app.buttons["Standort verwenden"].firstMatch.tap()

        // Der Dialog ist ein fremdes Fenster; er taucht in `app` nicht auf.
        // Springboard bekommt ihn — dort steht er unter „Erlauben".
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let erlauben = springboard.buttons["Beim Verwenden der App erlauben"]
        guard erlauben.waitForExistence(timeout: 20) else {
            throw XCTSkip("Kein Ortungsdialog — die Erlaubnis steht schon fest. "
                          + "Vorher: xcrun simctl privacy <udid> reset location com.skoehler.lechariot")
        }
        let bild = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        bild.name = "p2-ortungsdialog"
        bild.lifetime = .keepAlways
        add(bild)
    }

    /// **Punkt 4: der Belohnungsschritt mit seinen Zahlen.**
    func testWriteThePayoffNumbers() {
        launchFresh()
        walkToPayoff()
        attach(name: "p4-zahlen")
    }

    /// Dieselben Zahlen bei großer Schrift — die Prüfung, die zu „größer
    /// setzen" gehört: Was bei XXXL bricht, ist keine Verbesserung.
    func testWriteThePayoffNumbersAtLargeType() {
        launchFresh(extraArguments: ["-UIPreferredContentSizeCategoryName",
                                     "UICTContentSizeCategoryAccessibilityXXXL"])
        walkToPayoff()
        attach(name: "p4-zahlen-xxxl")
    }

    // MARK: Punkt 10 — das Artikelblatt

    /// **Punkt 10: womit das Blatt aufmacht.**
    ///
    /// Das erste Bild ist der Zustand, um den es geht — was man sieht, wenn das
    /// Halten das Blatt öffnet. Das zweite zeigt die Angaben, nachdem man sie
    /// angefordert hat.
    func testWriteTheItemSheetWeighting() {
        launchOnboarded()
        let feld = app.textFields["list.input"]
        feld.tapAndAwaitKeyboard(in: app)
        feld.typeText("Milch\n")
        app.buttons["list.input.done"].tap()
        _ = app.buttons["list.detailPanel.more"].waitForNonExistence(timeout: 10)

        app.openItemSheet(ofItem: "Milch")
        attach(name: "p10-blatt-oben")

        // Die Angaben — vor dem Umbau stehen sie schon oben, nachher hinter
        // dem Knopf. Beide Male ist dies das Bild, auf dem sie zu sehen sind.
        let knopf = app.buttons["itemSheet.angaben"]
        if knopf.waitForExistence(timeout: 3) {
            knopf.tap()
            attach(name: "p10-angaben-aufgeklappt")
        }

        let löschen = app.buttons["itemSheet.delete"].firstMatch
        for _ in 0..<8 where !löschen.exists || !löschen.isHittable { app.swipeUp() }
        attach(name: "p10-blatt-unten")
    }

    // MARK: Werkzeug

    private func launchFresh(extraArguments: [String] = []) {
        app.launchArguments = ["-uiTesting"] + extraArguments
        app.launch()
    }

    private func launchOnboarded() {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20),
                      "Der Start landet nicht in der Liste")
    }

    /// Willkommen → Name → Ort → Ketten → Belohnung.
    private func walkToPayoff() {
        tapPrimary()
        let name = app.textFields["Vorname"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Scott")
        tapPrimary()

        let feld = app.textFields["region.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
        feld.typeText("01219")
        tapPrimary()                       // Ort
        tapPrimary()                       // Ketten

        XCTAssertTrue(app.staticTexts["payoff.facts"].waitForExistence(timeout: 20),
                      "Der Belohnungsschritt kommt nicht:\n" + app.debugDescription)
    }

    private func tapPrimary() {
        let knopf = app.buttons["onboarding.primary"]
        XCTAssertTrue(knopf.waitForExistence(timeout: 15), "Hauptknopf fehlt")
        app.tippe(knopf, "der Hauptknopf")
    }

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
