import XCTest

/// **Bilder für die Bedienrunde vom 10.08., Punkte A, B und E.**
///
/// Der Bogen zeigt jeden Zustand, um den es in dieser Runde geht. Das ist hier
/// keine Förmlichkeit: Punkt B-1 ist ein Sichtfehler, den kein Test findet,
/// weil kein Element fehlt — die Abdunklung hinter einem Blatt ist eine Sache
/// der Deckkraft, und die steht in keinem Bedienungshilfen-Baum.
///
/// Er ersetzt `FeldtestShots` (#97): Dessen drei Bögen zeigten den Eck-Knopf
/// auf der Kachel und den Umweg Halten → Trefferblatt → ⋯ → Angaben. Beide
/// Wege gibt es nicht mehr.
///
/// Die Bilder gehen als Anhang ins `.xcresult`; herausholen mit
/// `xcrun xcresulttool export attachments`.
final class BedienrundeAbeShots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20),
                      "Der Start landet nicht in der Liste")
    }

    /// **Punkt E — die zwei Zustände über der Eingabezeile.**
    func testWriteTheSuggestionStates() {
        attach(name: "e1-leere-liste")

        let feld = app.textFields["list.input"]
        feld.tapAndAwaitKeyboard(in: app)
        attach(name: "e2-tastatur-feld-leer")

        // Ab dem **ersten** Buchstaben stehen dort Produkte, mit Artikelzeichen.
        feld.typeText("m")
        XCTAssertTrue(app.staticTexts["list.terms.title"].waitForExistence(timeout: 10),
                      "Der erste Buchstabe bringt keine Produkte:\n" + app.debugDescription)
        attach(name: "e3-ein-buchstabe")

        feld.typeText("il")
        attach(name: "e4-drei-buchstaben")

        // Und der Zustand ohne Treffer — eine Auskunft, kein Fehler.
        feld.typeText("chxyzq")
        _ = app.staticTexts["list.terms.empty"].waitForExistence(timeout: 10)
        attach(name: "e5-kein-treffer")
    }

    /// **Punkt B-2 — unten links steht genau ein Knopf.**
    func testWriteTheDetailLayerState() {
        let feld = app.textFields["list.input"]
        feld.tapAndAwaitKeyboard(in: app)
        feld.typeText("Milch\n")
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 15),
                      "Die Angaben-Schicht kommt beim Anlegen nicht:\n" + app.debugDescription)
        attach(name: "b1-angaben-schicht-mit-tastatur")
    }

    /// **Punkt A und B-1 — das geteilte Artikelblatt.**
    ///
    /// Das erste Bild ist das, an dem B-1 hängt: Über dem Blatt liegt der
    /// Streifen mit der Uhr, und **dort** stand der durchsichtige schwarze
    /// Behälter.
    func testWriteTheItemSheetStates() {
        let feld = app.textFields["list.input"]
        feld.tapAndAwaitKeyboard(in: app)
        feld.typeText("Milch\n")
        app.buttons["list.input.done"].tap()
        _ = app.buttons["list.detailPanel.more"].waitForNonExistence(timeout: 10)

        app.openItemSheet(ofItem: "Milch")
        attach(name: "a1-blatt-oben-angaben")

        // Und weiter unten auf demselben Bildschirm: die Treffer und das
        // Löschen.
        let überschrift = app.staticTexts["itemSheet.offers.header"]
        for _ in 0..<6 where !überschrift.exists || !überschrift.isHittable { app.swipeUp() }
        attach(name: "a2-blatt-unten-treffer-und-loeschen")
    }

    /// **Punkt A, der Fall aus dem Feldtest vom 09.08.** — ein Artikel, zu dem
    /// es kein einziges Angebot gibt. Der alte Bildschirm hieß „Treffer für
    /// ‚Kohl'" und meldete „Keine Treffer"; jetzt stehen oben seine Angaben.
    func testWriteTheSheetOfAnItemWithoutOffers() {
        let feld = app.textFields["list.input"]
        feld.tapAndAwaitKeyboard(in: app)
        feld.typeText("Kohl\n")
        app.buttons["list.input.done"].tap()
        _ = app.buttons["list.detailPanel.more"].waitForNonExistence(timeout: 10)

        app.openItemSheet(ofItem: "Kohl")
        attach(name: "a3-blatt-ohne-treffer-oben")
        let überschrift = app.staticTexts["itemSheet.offers.header"]
        for _ in 0..<6 where !überschrift.exists || !überschrift.isHittable { app.swipeUp() }
        attach(name: "a4-blatt-ohne-treffer-unten")
    }

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
