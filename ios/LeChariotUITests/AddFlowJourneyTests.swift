import XCTest

/// **Scotts eigentliche Strecke, 03.08.: drei Produkte hintereinander tippen.**
///
/// Wörtlich: „Bei Bring! kann man das Menü schlicht ignorieren und sofort das
/// nächste Produkt tippen." Bis zum 03.08. ging das hier nicht — das
/// Mengen-Menü war ein Blatt, es nahm dem Eingabefeld den Fokus, und ohne
/// „Fertig" kam kein zweites Wort hinein.
///
/// **Warum diese Journeys über `app.typeText` gehen und nicht über
/// `feld.typeText`.** Der Unterschied ist der ganze Fund: `app.typeText`
/// schreibt in das, was gerade den Fokus hat, und **scheitert**, wenn nichts
/// ihn hat. Ein Test, der das Feld vor jedem Wort neu antippt, prüft nur, dass
/// man Artikel anlegen kann — nicht, dass die Tastatur dazwischen stehen
/// bleibt. Genau daran fällt der ganze Satz gegen den Stand vom 02.08.
final class AddFlowJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
    }

    /// **Der Kern.** Drei Artikel, ein einziger Tipp ins Feld, kein „Fertig".
    func testThreeItemsInARowWithNothingButTheKeyboard() {
        startTyping()
        app.typeText("Butter\n")
        app.typeText("Milch\n")
        app.typeText("Kaffee\n")

        for name in ["Butter", "Milch", "Kaffee"] {
            XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 10),
                          "\(name) ist nicht auf der Liste gelandet\n" + app.debugDescription)
        }
        XCTAssertFalse(app.buttons["itemSheet.done"].exists,
                       "Auf dem Weg lag ein Blatt mit \u{201E}Fertig\u{201C}")
    }

    /// **Ein ignoriertes Panel speichert nichts.** Es soll nichts kosten, an
    /// ihm vorbeizutippen — weder eine Angabe, die niemand gewählt hat, noch
    /// einen Handgriff.
    func testAnIgnoredPanelSavesNothing() {
        startTyping()
        app.typeText("Butter\n")
        app.typeText("Milch\n")

        XCTAssertTrue(app.buttons["Butter"].waitForExistence(timeout: 10))
        let mitAngabe = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Butter, ")
        )
        XCTAssertEqual(mitAngabe.count, 0,
                       "Am übergangenen Artikel darf keine Angabe kleben")
    }

    /// **Das Panel gehört dem zuletzt angelegten Artikel** — und ein Chip
    /// mitten im Fluss landet genau dort, nicht am ersten der Liste.
    func testAChipTappedMidFlowLandsOnTheRightItem() {
        startTyping()
        app.typeText("Butter\n")
        app.typeText("Milch\n")
        app.typeText("Kaffee\n")

        XCTAssertTrue(app.buttons["Angaben zu Kaffee"].waitForExistence(timeout: 10),
                      "Die Kachelzeile zeigt den neuesten Artikel nicht als aktiven")
        app.buttons["klein"].tap()

        XCTAssertTrue(app.buttons["Kaffee, klein"].waitForExistence(timeout: 10),
                      "Die Angabe steht nicht am zuletzt angelegten Artikel\n"
                      + app.debugDescription)
        XCTAssertFalse(app.buttons["Butter, klein"].exists)
        XCTAssertFalse(app.buttons["Milch, klein"].exists)
    }

    /// **Die Kachelzeile ist der Weg zurück.** Wer beim dritten Artikel merkt,
    /// dass der erste die große Packung sein muss, kommt ohne Umweg über die
    /// Liste dorthin — und tippt danach weiter, ohne das Feld neu anzufassen.
    func testAnOlderTileTakesThePanelBackAndTypingGoesOn() {
        startTyping()
        app.typeText("Butter\n")
        app.typeText("Milch\n")

        app.buttons["Angaben zu Butter"].tap()
        app.buttons["klein"].tap()
        XCTAssertTrue(app.buttons["Butter, klein"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Milch, klein"].exists)

        // Und der Fokus war nie weg: Das nächste Wort geht ohne einen Tipp ins
        // Feld durch.
        app.typeText("Brot\n")
        XCTAssertTrue(app.buttons["Brot"].waitForExistence(timeout: 10),
                      "Nach dem Kachel-Tipp war die Tastatur weg")
    }

    /// **Der Fluss endet mit dem Tippen, nicht mit einem Knopf.** Wer die
    /// Liste anfasst, ist fertig — die Schicht geht mit der Tastatur, ohne dass
    /// sie jemand wegräumen müsste.
    func testScrollingTheListEndsTheFlow() {
        startTyping()
        app.typeText("Butter\n")
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10))

        // Der Zug muss die **Liste** treffen — mit der vollen
        // Software-Tastatur liegt die Bildschirmmitte auf der Schicht selbst,
        // und ein Wisch dort prüft nichts. Siehe `dragTheListUp`.
        app.dragTheListUp()

        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForNonExistence(timeout: 5),
                      "Die Angaben-Schicht bleibt über der Liste stehen")
    }

    /// Die volle Fassung ist einen benannten Knopf weit weg — dort liegt der
    /// Freitext, den das Panel bewusst nicht trägt.
    func testTheFullSheetIsOneNamedButtonAway() {
        startTyping()
        app.typeText("Butter\n")

        // Erst warten, dann tippen: Die Schicht zieht auf, und ein `tap` ohne
        // `waitForExistence` prüft nur, wie schnell der Rechner gerade ist.
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10),
                      "Die Angaben-Schicht steht nach dem Anlegen nicht da")
        app.buttons["list.detailPanel.more"].tap()

        // Seit dem 10.08. führt „Notiz …" auf dasselbe Artikelblatt, das auch
        // das Halten öffnet (Punkt A) — nicht mehr auf ein eigenes Blatt.
        XCTAssertTrue(app.buttons["itemSheet.done"].waitForExistence(timeout: 10),
                      "Der Weg in die volle Fassung ist zu")
        XCTAssertTrue(app.staticTexts["Notiz"].exists, "Der Freitext steht dort")
    }

    // MARK: Helfer

    /// Einmal ins Feld tippen — danach schreibt jede Zeile über `app.typeText`,
    /// und das ist Absicht. Siehe die Überschrift dieser Datei.
    ///
    /// **Und dann auf die Tastatur warten.** Ohne das war diese Suite bei jedem
    /// Lauf anders rot: `feld.tap()` kommt zurück, bevor der Fokus liegt, und
    /// das erste `app.typeText` fiel mit „Neither element nor any descendant has
    /// keyboard focus". Nachgemessen am 03.08.: Wer nach dem Tipp eine Sekunde
    /// wartet, tippt sechs Wörter hintereinander durch, und die Schicht steht
    /// bei **jeder** Messung im 100-ms-Raster. Die Wackelei lag im Testlauf,
    /// nicht in der App — genau der Unterschied, den ein Test behaupten können
    /// muss.
    private func startTyping() {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
        feld.tapAndAwaitKeyboard(in: app)
    }
}
