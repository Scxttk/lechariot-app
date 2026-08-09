import XCTest

/// **Den Rundgang so durchspielen, wie ein Tester ihn durchspielt** — an einer
/// Stelle für alle Journeys.
///
/// Bis zum 09.08. war das eine Schleife über `tutorial.next`: dreimal „Weiter",
/// fertig. Den Knopf gibt es nicht mehr. Jeder Rahmen wartet auf **die** Handlung,
/// die sein Text ansagt (`TutorialStep.Deed`), und eine Journey, die den Rundgang
/// nur durchqueren will, muss sie tun.
///
/// **Erkannt wird der Rahmen an seiner Überschrift und nicht an einer Zählung.**
/// Der Rundgang hat mit Filialen sechs Rahmen und ohne vier; „viermal das
/// Richtige tun" wäre in der einen Fassung still falsch. Steht eine Überschrift
/// hier nicht, ist das ein Fehlschlag und keine stille Schleife — sonst liefe
/// jede Journey nach einem neuen Rahmen in ihren Deckel statt in eine Meldung.
extension XCUIApplication {
    private var tourCard: XCUIElement { staticTexts["tutorial.card"] }

    /// Erledigt die Handlung des Rahmens, der gerade steht.
    /// - Returns: `false`, wenn kein Rahmen mehr steht — der Rundgang ist durch.
    @discardableResult
    func doTheTourDeed(_ file: StaticString = #filePath, _ line: UInt = #line) -> Bool {
        guard tourCard.exists else { return false }
        let rahmen = tourCard.label

        switch true {
        case rahmen.contains("Schreib deinen ersten Artikel auf"):
            let feld = textFields["list.input"]
            XCTAssertTrue(feld.waitForExistence(timeout: 15),
                          "Kein Eingabefeld im Loch", file: file, line: line)
            feld.tap()
            // Ein Wort, zu dem der Vorrat garantiert nichts hat: Der Rahmen
            // danach hängt an der Kachel, nicht an einem Angebot.
            //
            // **Und beim zweiten Mal ein anderes.** `ShoppingListStore.add`
            // weist Doppelte ab — dann landet kein Artikel auf der Liste, der
            // Rahmen bekommt seine Handlung nie gemeldet und wartet ewig.
            // Gefunden im vollen Lauf: `PerformanceJourneyTests` misst den
            // Rundgang fünfmal hintereinander, und ab dem zweiten Durchgang
            // stand „Zahnstocher" schon da.
            feld.typeText(nextWord() + "\n")

        case rahmen.contains("Du musst nicht alles tippen"):
            let winkel = buttons["list.suggestions.toggle"]
            XCTAssertTrue(winkel.waitForExistence(timeout: 15),
                          "Kein Winkel-Knopf:\n" + debugDescription, file: file, line: line)
            winkel.tap()

        case rahmen.contains("Im Laden abhaken"):
            tapTheHole(what: "die Kachel", file, line)

        case rahmen.contains("Alle Angebote deiner Filialen"):
            buttons["Angebote"].firstMatch.tap()

        case rahmen.contains("Schon nächste Woche sehen"):
            let vorschau = buttons["offers.nextWeek"]
            XCTAssertTrue(vorschau.waitForExistence(timeout: 15),
                          "Kein Vorschau-Knopf:\n" + debugDescription, file: file, line: line)
            vorschau.tap()

        case buttons["tutorial.next"].exists:
            // Die Schlusskarte — der einzige Rahmen mit einem Knopf.
            buttons["tutorial.next"].tap()

        default:
            XCTFail("Unbekannter Rahmen im Rundgang: \(rahmen)", file: file, line: line)
            return false
        }

        // Eine Atempause je Rahmen. Ohne sie tippt XCUITest schneller, als der
        // nächste Rahmen sein Loch bekommt — und der Tipp, der den Rundgang
        // beendet, landet noch einmal auf dem Bildschirm darunter.
        Thread.sleep(forTimeInterval: 0.9)
        return true
    }

    /// Ein Wort, das noch nicht auf der Liste steht. Beim ersten Mal schlicht
    /// „Zahnstocher", damit die Journeys danach suchen können, was sie schon
    /// immer gesucht haben.
    private func nextWord() -> String {
        let wort = "Zahnstocher"
        guard buttons[wort].exists else { return wort }
        return "\(wort) \(buttons.matching(identifier: "list.tile").count + 1)"
    }

    /// **Dorthin tippen, wo der Rundgang hinzeigt** — auf die Mitte des Lochs,
    /// nicht auf die Mitte eines Elements.
    ///
    /// Der Unterschied hat einen ganzen Nachmittag gekostet. Eine Kachel meldet
    /// XCUITest als `Button {{0.0, 258.7}, {402.0, 120.0}}` — **bildschirmbreit**,
    /// obwohl sie 112 pt breit gezeichnet ist; der Knopf trägt den ganzen
    /// Rasterplatz. Ein `tap()` darauf zielt auf die Mitte dieses Rahmens, und
    /// die liegt **neben** dem Loch, also auf einer Sperrfläche: „Failed to not
    /// hittable". Der Tipp war richtig gemeint und landete am falschen Ort.
    ///
    /// Die Sonde `tutorial.hole` liegt im Testlauf genau auf dem Loch (siehe
    /// `TutorialOverlay.holeProbe`) und ist damit die einzige Stelle, die
    /// „dorthin, wo der Rundgang zeigt" wirklich ausdrückt.
    private func tapTheHole(what: String,
                            _ file: StaticString = #filePath, _ line: UInt = #line) {
        let loch = images["tutorial.hole"]
        XCTAssertTrue(loch.waitForExistence(timeout: 15),
                      "Kein Loch für \(what):\n" + debugDescription, file: file, line: line)
        loch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Den ganzen Rundgang mitmachen, bis er zu Ende ist.
    ///
    /// Gedeckelt: Ein Rahmen, dessen Ziel nie erscheint, überspringt sich selbst
    /// — bliebe er stehen, liefe die Schleife hier gegen die Grenze statt
    /// endlos.
    func walkTheWholeTour(maxFrames: Int = 10,
                          _ file: StaticString = #filePath, _ line: UInt = #line) {
        var rahmen = 0
        while rahmen < maxFrames, doTheTourDeed(file, line) {
            rahmen += 1
        }
        XCTAssertLessThan(rahmen, maxFrames,
                          "Der Rundgang hört nicht auf:\n" + debugDescription,
                          file: file, line: line)
    }
}
