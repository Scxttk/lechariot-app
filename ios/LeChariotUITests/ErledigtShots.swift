import XCTest

/// **Bilder zu C und D vom 10.08.** — die Liste mit abgehakten Artikeln, und
/// der Moment, in dem eine abgehakte Milch wieder angelegt wird.
///
/// Der Bogen läuft gegen **beide** Stände: Er ändert nichts, er fotografiert
/// nur, und er greift auf beiden Ständen dieselben Elemente. Auf `main` liefert
/// er das Vorher (Milch bleibt abgehakt, „Erledigt" ohne Lebensdauer), auf dem
/// Zweig das Nachher. Dieselben Artikel in derselben Reihenfolge, damit die
/// zwei Bilder wirklich vergleichbar sind und nicht zwei verschiedene Läufe
/// zeigen.
///
/// Die Bilder gehen als Anhang ins `.xcresult`; herausholen mit
/// `xcrun xcresulttool export attachments`.
final class ErledigtShots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: 1 — Die Liste mit abgehakten Artikeln

    /// Drei offene, zwei abgehakte. Was der Abschnitt „Erledigt" über sich
    /// selbst sagt, ist der ganze Unterschied.
    func testWriteTheCheckedListShot() {
        launch()
        anlegen(["Milch", "Brot", "Butter", "Bananen", "Kaffee"])
        tastaturWeg()

        abhaken("Bananen")
        abhaken("Kaffee")

        // Ganz nach unten, damit der Abschnitt „Erledigt" vollständig im Bild
        // steht — er ist der letzte.
        for _ in 0..<3 { app.swipeUp() }
        attach(name: "1-liste-mit-erledigten")
    }

    // MARK: 2 — Der Fehler selbst

    /// Milch abhaken, Milch wieder anlegen, hinsehen. Auf `main` passiert an
    /// dieser Stelle **nichts** — genau das ist das Vorher-Bild.
    func testWriteTheReAddShot() {
        launch()
        anlegen(["Milch", "Brot"])
        tastaturWeg()
        abhaken("Milch")
        attach(name: "2a-milch-erledigt")

        anlegen(["Milch"])
        tastaturWeg()
        attach(name: "2b-milch-erneut-angelegt")

        // Und die Zahl daneben, damit das Bild nicht allein steht: Wie viele
        // Kacheln „Milch" heißen und was ihr Zustand ist.
        misseMilch()
    }

    // MARK: 3 — Der Vorrat

    /// Der Vorschlagsstreifen, nachdem Milch abgehakt wurde. Auf `main` fehlt
    /// die Kachel „Milch" dort — abgehakt galt als „steht schon auf der Liste".
    func testWriteThePoolShot() {
        launch()
        anlegen(["Milch"])
        tastaturWeg()
        abhaken("Milch")

        let knopf = app.buttons["list.suggestions.toggle"]
        if knopf.waitForExistence(timeout: 10) { knopf.tap() }
        _ = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Häufig")
        ).firstMatch.waitForExistence(timeout: 10)
        attach(name: "3-vorrat-nach-dem-abhaken")
    }

    // MARK: Helfer

    private func launch() {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded",
                               "-uiTestingOnboardedThreeChains"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20),
                      "Der Start landet nicht in der Liste")
    }

    private func anlegen(_ wörter: [String]) {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15), "Keine Eingabezeile")
        feld.tap()
        for wort in wörter { feld.typeText(wort + "\n") }
    }

    /// Aus dem Tipp-Fluss heraus — sonst steht die Angaben-Schicht über der
    /// halben Liste, und das Bild zeigt sie statt der Artikel.
    private func tastaturWeg() {
        let fertig = app.buttons["list.input.done"].firstMatch
        if fertig.waitForExistence(timeout: 5) { fertig.tap() }
        _ = app.buttons["list.detailPanel.more"].waitForNonExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 0.4)
    }

    private func abhaken(_ wort: String) {
        let kachel = app.buttons[wort].firstMatch
        XCTAssertTrue(kachel.waitForExistence(timeout: 10), "\(wort) liegt nicht auf der Liste")
        kachel.tap()
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// Die Zahl neben dem Bild: wie viele Milch-Kacheln es gibt und wie ihr
    /// Zustand lautet. Ein Bild allein lässt „abgehakt" und „durchgestrichen,
    /// aber offen" leicht verwechseln.
    private func misseMilch() {
        let treffer = app.buttons.matching(NSPredicate(format: "label == %@", "Milch"))
        var zeilen = ["Kacheln mit dem Namen „Milch\u{201C}: \(treffer.count)"]
        for i in 0..<treffer.count {
            let k = treffer.element(boundBy: i)
            guard k.exists else { continue }
            zeilen.append("[\(i)] Zustand: \((k.value as? String) ?? "—")")
        }
        let text = XCTAttachment(string: zeilen.joined(separator: "\n"))
        text.name = "2c-milch-zustand"
        text.lifetime = .keepAlways
        add(text)
    }

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
