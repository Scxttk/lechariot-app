import XCTest

/// **Ins Feld tippen und warten, bis der Fokus wirklich liegt.**
///
/// `tap()` kommt zurück, sobald die Berührung zugestellt ist — nicht, sobald
/// das Textfeld erster Responder ist. Das nächste `typeText` fällt dann mit
///
///     Failed to synthesize event: Neither element nor any descendant has
///     keyboard focus
///
/// und zwar **manchmal**: Am 03.08. war `AddFlowJourneyTests` bei jedem Lauf
/// anders rot, zwei bis vier von sechs. Nachgemessen war die App unschuldig —
/// wer nach dem Tipp eine Sekunde wartet, tippt sechs Wörter hintereinander
/// durch, und die Angaben-Schicht steht bei jeder Messung im 100-ms-Raster.
///
/// **Ein wackelnder Test ist schlimmer als keiner:** Er kostet jedes Mal die
/// Frage, ob diesmal die App gemeint war.
extension XCUIElement {
    func tapAndAwaitKeyboard(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        tap()
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 10),
            "Nach dem Tipp ins Feld steht keine Tastatur",
            file: file, line: line
        )
    }
}

extension XCUIApplication {
    /// **Ein Zug an der Liste — nicht ein Wisch in die Bildschirmmitte.**
    ///
    /// Der Vertrag heißt „wer die Liste anfasst, beendet den Tipp-Fluss"
    /// (`ShoppingListView`, `scrollDismissesKeyboard` plus DragGesture), und
    /// bis zum 05.08. prüfte ihn überall ein `app.swipeUp()`. Der wischt in
    /// der Mitte des Fensters — und traf dort nur zufällig die Liste:
    ///
    /// Auf einem kopflosen Simulator (ohne Simulator-Fenster, also ohne
    /// angeschlossene Hardware-Tastatur) steht die **volle**
    /// Software-Tastatur. Gemessen am 05.08. auf `merge-sim` (393 × 852):
    /// Tastatur ab y = 561, Angaben-Schicht ab y = 341 — die Mitte (y = 426)
    /// liegt auf der Schicht, deren waagerecht scrollender Wortschatz den
    /// senkrechten Zug schluckt, und der Fluss endet nie. Auf Läufen mit
    /// offenem Simulator-Fenster ist die Tastatur nur die Minileiste, die
    /// Mitte lag frei — deshalb ist das nie aufgefallen, und deshalb war
    /// dieselbe Suite am selben Stand mal grün und mal rot, je nachdem, wer
    /// sie startete.
    ///
    /// Der Zug hier startet im sichtbaren Listenstreifen unter der
    /// Navigationsleiste (y ≈ 0,32 → 0,16 der Fensterhöhe) — über der
    /// Schicht in **jeder** Tastaturlage, unter der Navigationsleiste auf
    /// iPhone wie iPad.
    /// **Am 08.08. noch einmal nach oben gerückt, und aus demselben Grund wie
    /// beim ersten Mal.** Seit die Angaben-Schicht Bring!s Höhe hat, fängt der
    /// Block unten bei y = 183 von 874 an — der bisherige Startpunkt (0,32 →
    /// y = 280) lag damit **auf der Schicht**, deren waagerecht scrollende
    /// Chipreihen den senkrechten Zug schluckten, und der Fluss endete nie.
    /// Dieselbe Falle, dieselbe Lehre: Der Zug muss die **Liste** treffen, und
    /// wo die liegt, hat sich verschoben.
    ///
    /// 0,16 → 0,09 (y = 140 → 79) liegt in **jeder** Lage im Listenstreifen:
    /// beim Tippen im Streifen zwischen Statusleiste (62) und Block (183),
    /// ohne Tipp-Fluss unter der Titelleiste (116).
    func dragTheListUp() {
        let fenster = windows.firstMatch
        let von = fenster.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.16))
        let nach = fenster.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.09))
        von.press(forDuration: 0.05, thenDragTo: nach)
    }
}

// MARK: - Die zwei Griffe an einer Kachel

/// **Seit dem 07.08. ist die Liste ein Raster** (`ShoppingGridTile`), und die
/// Kachel trägt genau eine Trefferfläche: den Tipp, der abhakt.
///
/// **Seit dem 08.08. führt das Halten direkt ins Trefferblatt** (Scotts „ein
/// Griff weniger"). Vorher ging es über das Kontextmenü, und die Journeys
/// tippten dort auf `list.matches`. Dieser Punkt ist damit weg — der lange
/// Druck *ist* er. Angaben und Löschen liegen jetzt im ⋯-Menü desselben
/// Blattes.
///
/// Beides steht hier und nur hier: Sonst stünde der lange Druck zwanzigmal im
/// Testbestand und wäre beim nächsten Umbau zwanzigmal falsch.
extension XCUIApplication {
    /// Hält die Kachel und wartet, bis das Trefferblatt oben steht.
    ///
    /// `press(forDuration:)` statt `tap()`: Ein kurzer Tipp würde den Artikel
    /// abhaken — genau die Handlung, die die Kachel im Laden können muss.
    @discardableResult
    func openTileMatches(
        ofItem itemLabel: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let kachel = itemLabel.map { label in
            buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
        } ?? buttons["list.tile"].firstMatch
        XCTAssertTrue(kachel.waitForExistence(timeout: 15),
                      "Keine Kachel \(itemLabel ?? "list.tile") gefunden", file: file, line: line)
        kachel.press(forDuration: 0.6)

        let blatt = navigationBars.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Treffer für")
        ).firstMatch
        XCTAssertTrue(blatt.waitForExistence(timeout: 15),
                      "Das Halten hat das Trefferblatt nicht geöffnet", file: file, line: line)
        return blatt
    }

    /// Öffnet das Trefferblatt und darin den Punkt aus dem ⋯-Menü —
    /// `matches.item.detail` oder `matches.item.delete`.
    func tapInItemMenu(
        _ menuIdentifier: String,
        ofItem itemLabel: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        openTileMatches(ofItem: itemLabel, file: file, line: line)

        let mehr = buttons["matches.more"].firstMatch
        XCTAssertTrue(mehr.waitForExistence(timeout: 10),
                      "Im Trefferblatt fehlt das ⋯-Menü", file: file, line: line)
        mehr.tap()

        let punkt = buttons[menuIdentifier].firstMatch
        XCTAssertTrue(punkt.waitForExistence(timeout: 10),
                      "Der Punkt \(menuIdentifier) steht nicht im ⋯-Menü",
                      file: file, line: line)
        punkt.tap()
    }
}

// MARK: - Tippen im Assistenten

extension XCUIApplication {
    /// Tippt erst, wenn das Element **erreichbar** ist — nicht schon, wenn es
    /// im Baum steht.
    ///
    /// Der Unterschied hat am 07.08. zwei Läufe gekostet, und beim zweiten Mal
    /// an drei anderen Stellen als beim ersten. Der Assistent fährt den neuen
    /// Bildschirm über 0,3 s herein (siehe `Theme.Motion`); währenddessen
    /// existiert `onboarding.skip` bereits, sitzt aber noch halb außerhalb.
    /// Ein `tap()` darauf geht ins Leere, die Seite bleibt stehen, und der
    /// nächste Schritt sucht die Postleitzahl auf der Profilseite.
    ///
    /// **Erst als es das zweite Mal woanders aufschlug, war klar, dass es kein
    /// Einzelfall ist**, sondern jeder blinde Tipp im Assistenten. Deshalb
    /// steht das hier und nicht in einem Bogen.
    ///
    /// `isHittable` ist die Wartebedingung, die `waitForExistence` nicht hat.
    func tippe(_ element: XCUIElement, _ was: String,
               file: StaticString = #filePath, line: UInt = #line) {
        let erreichbar = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: element
        )
        XCTAssertEqual(XCTWaiter().wait(for: [erreichbar], timeout: 15), .completed,
                       "\(was) ist nicht antippbar", file: file, line: line)
        element.tap()
    }


}
