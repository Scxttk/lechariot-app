import XCTest

/// **Bilder für die drei kleinen Punkte vom 10.08.** — die Umbenennung, der
/// Sonntagszustand im Angebote-Tab und die zwei Kleinigkeiten am Kachelbereich.
///
/// Der Bogen läuft gegen **beide** Stände: Er fasst nichts an, was die Runde
/// geändert hat, sondern fotografiert nur. Auf dem Stand von `main` liefert er
/// das Vorher, auf dem Zweig das Nachher — dieselben Fixtures, dieselben
/// Griffe, damit die zwei Bilder wirklich vergleichbar sind und nicht zwei
/// verschiedene Läufe zeigen.
///
/// **Der Sonntag kommt aus `-uiTestingSunday`**, nicht aus dem Kalender: Zwei
/// gewählte Ketten ohne gültige Angebote, eine mit. Auf einen echten Sonntag
/// zu warten hieße, den Zustand einen Tag die Woche prüfen zu können — siehe
/// `MockFixtures.sunday`.
///
/// Die Bilder gehen als Anhang ins `.xcresult`; herausholen mit
/// `xcrun xcresulttool export attachments`.
final class KleinkramShots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: 1 — Die Überschrift des Vorschlagsstreifens

    /// Die eine Stelle, an der der Name steht. Kein Messgerät nötig — das Bild
    /// ist die ganze Behauptung.
    func testWriteTheSuggestionHeadingShot() {
        launch()
        // Der Streifen steht im Leerzustand von allein offen. Gesucht wird auf
        // **beiden** Ständen dasselbe: „Häufig …" — der Rest des Satzes ist
        // genau das, was diese Runde ändert, und danach zu suchen hieße, den
        // Bogen auf einem der zwei Stände scheitern zu lassen.
        let ueberschrift = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Häufig")).firstMatch
        XCTAssertTrue(ueberschrift.waitForExistence(timeout: 15),
                      "Der Vorschlagsstreifen steht nicht:\n" + app.debugDescription)
        attach(name: "1-vorschlagsstreifen")
    }

    // MARK: 2 — Der Sonntag im Angebote-Tab

    /// Drei Ketten, drei Zustände: Lidl liefert, Aldi ruht mit Vorschau, Netto
    /// ruht ohne. Was die Leiste davon zeigt, ist der ganze Punkt.
    func testWriteTheSundayShots() {
        launch(sunday: true)
        openTab("Angebote")
        XCTAssertTrue(app.buttons["offers.row"].firstMatch.waitForExistence(timeout: 25),
                      "Der Angebote-Tab lädt nicht:\n" + app.debugDescription)
        attach(name: "2a-angebote-sonntag-leiste")

        // Und was hinter einem Chip steht, dessen Kette gerade nichts hat.
        // Vorher gibt es diesen Chip nicht — dann hält das Bild genau das fest,
        // und der Bogen bleibt trotzdem grün.
        let aldi = app.buttons["Aldi, zurzeit ohne Angebote"].firstMatch
        let aldiAlt = app.buttons["Aldi"].firstMatch
        if aldi.waitForExistence(timeout: 5) {
            aldi.tap()
        } else if aldiAlt.exists {
            aldiAlt.tap()
        } else {
            // Auf dem Stand von `main` gibt es diesen Chip nicht — und das
            // **ist** der Befund. Der Bogen hält ihn fest und bleibt grün;
            // rot zu werden wäre hier eine Behauptung über den Zweig, nicht
            // über den Bildschirm.
            attach(name: "2b-kein-aldi-chip")
            zeigeAbschnittOhneAngebote()
            return
        }
        _ = app.staticTexts.matching(identifier: "offers.restingChain")
            .firstMatch.waitForExistence(timeout: 10)
        attach(name: "2b-aldi-gefiltert")

        let alle = app.buttons["Alle Märkte"].firstMatch
        if alle.exists { alle.tap() }
        zeigeAbschnittOhneAngebote()
    }

    // MARK: 3 — Die zwei Kleinigkeiten am Kachelbereich

    /// Fünf Artikel hintereinander, ohne die Schicht zwischendurch wegzulegen:
    /// Genau dann ist die Kachelzeile länger als ihr Platz, und der aktive Chip
    /// ist der letzte.
    func testWriteTheActiveChipShot() {
        launch()
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
        for wort in ["Vollmilch", "Bananen", "Waschmittel", "Kaffeebohnen", "Zahnpasta"] {
            feld.typeText(wort + "\n")
        }
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10),
                      "Die Angaben-Schicht steht nicht:\n" + app.debugDescription)
        // Die Zeile darf sich noch bewegen — gewartet wird auf zwei gleiche
        // Messungen, nicht auf eine feste Zeit. Dieselbe Falle wie in
        // `AddFlowZonesJourneyTests`.
        warteBisRuhig(app.buttons["list.detailPanel.recent"])
        // Dasselbe Bild trägt **beide** Kleinigkeiten: rechts den aktiven Chip
        // an der Kante zu „Notiz …", oben die Kachelreihe, die in dieser Lage
        // unter die Uhr läuft. Deshalb liegt die Messung hier und nicht nur im
        // Bogen darunter.
        attach(name: "3a-kachelzeile-aktiver-chip")
        misseObersteKachel(name: "3a-obere-kacheln")
    }

    /// Die obere Zone beim Tippen: Was von der Liste über dem Block steht, und
    /// wie es oben endet.
    func testWriteTheTopZoneShot() {
        launch()
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
        // Genug Artikel, dass die Liste am oberen Anschlag wirklich scrollt —
        // bei zwei Kacheln gibt es nichts, was unter die Uhr fahren könnte.
        for wort in ["Vollmilch", "Bananen", "Waschmittel", "Kaffeebohnen",
                     "Zahnpasta", "Brot", "Butter", "Eier", "Käse", "Nudeln",
                     "Reis", "Joghurt"] {
            feld.typeText(wort + "\n")
        }
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10),
                      "Die Angaben-Schicht steht nicht:\n" + app.debugDescription)
        // **Sofort, ohne auf das Einschwingen zu warten** — das ist der
        // Moment, den Scott beim Tippen sieht: Die Liste zieht dem letzten
        // Artikel nach, und was oben hinausläuft, läuft in dieser Zehntel-
        // sekunde unter die Uhr. Wer erst wartet, fotografiert eine Liste,
        // die schon zur Ruhe gekommen ist, und trifft den Befund nicht.
        attach(name: "3b-obere-zone-beim-tippen")
        misseObersteKachel(name: "3b-obere-kachel")

        warteBisRuhig(app.buttons["list.detailPanel.recent"])
        attach(name: "3c-obere-zone-eingeschwungen")
    }

    /// Wo die oberste sichtbare Kachel steht — als Zahl neben dem Bild.
    ///
    /// Die sichere Fläche eines Geräts mit Dynamic Island ist 59 pt hoch. Eine
    /// Kachel, deren Oberkante darunter liegt, steht **in** dem Streifen, in
    /// dem die Uhr steht; nur ob das hart abgeschnitten aussieht oder
    /// ausblendet, sagt die Zahl nicht — dafür ist das Bild da.
    private func misseObersteKachel(name: String) {
        let kacheln = app.buttons.matching(
            NSPredicate(format: "identifier == %@", "list.tile")
        )
        var zeilen = ["sichere Fläche oben (17 Pro): 59 pt"]
        for i in 0..<min(kacheln.count, 4) {
            let k = kacheln.element(boundBy: i)
            guard k.exists else { continue }
            zeilen.append("\(k.label): minY \(k.frame.minY), maxY \(k.frame.maxY)")
        }
        let text = XCTAttachment(string: zeilen.joined(separator: "\n"))
        text.name = name
        text.lifetime = .keepAlways
        add(text)
    }

    /// Ganz nach unten: Dort steht der Abschnitt „Ohne Angebote", der die
    /// Filialen Zeile für Zeile begründet — auf beiden Ständen, nur mit
    /// verschiedenen Sätzen.
    private func zeigeAbschnittOhneAngebote() {
        for _ in 0..<6 { app.swipeUp() }
        attach(name: "2c-ohne-angebote-abschnitt")
    }

    // MARK: Helfer

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Wartet, bis dasselbe Element zweimal hintereinander an derselben Stelle
    /// steht. Wer gleich nach dem letzten Wort fotografiert, fotografiert eine
    /// Bewegung mitten in der Fahrt.
    private func warteBisRuhig(_ element: XCUIElement) {
        var vorher: CGRect = .null
        for _ in 0..<20 {
            guard element.firstMatch.exists else { break }
            let jetzt = element.firstMatch.frame
            if jetzt == vorher { return }
            vorher = jetzt
            Thread.sleep(forTimeInterval: 0.25)
        }
    }

    private func launch(sunday: Bool = false) {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded",
                               "-uiTestingOnboardedThreeChains"]
        if sunday { app.launchArguments.append("-uiTestingSunday") }
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20),
                      "Der Start landet nicht in der Liste")
    }

    private func openTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "Kein Reiter \(name)")
        tab.tap()
    }
}
