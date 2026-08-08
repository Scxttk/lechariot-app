import XCTest

/// **Ein Vertrag, drei Wege hinein.**
///
/// Scotts Feldtest von Build `2026.0803.1440`, Punkte 8 und 9: Das Mengen-Menü
/// sei „schlecht skaliert", wenn man von Hand tippt — und aus „Häufig gekauft"
/// heraus gebe es „keinen Weg hinaus".
///
/// Beides ist derselbe Fund aus zwei Richtungen: Die Angaben-Schicht hing an
/// **einem** Ausgang („die Tastatur ist unten"), und auf dem Weg über die
/// Vorschlagskacheln steht nie eine Tastatur. Dazu standen dort beide Flächen
/// gleichzeitig.
///
/// Die Zusage lautet deshalb ab jetzt auf **jedem** Weg gleich, und jede
/// Journey hier prüft sie an einem Weg:
/// 1. die Schicht steht,
/// 2. sie lässt sich **ohne Tastatur** weglegen,
/// 3. der Block unten bleibt unter einem gemessenen Deckel.
final class AddFlowContractJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded",
                               "-uiTestingOnboardedThreeChains"]
        app.launch()
    }

    private var input: XCUIElement { app.textFields["list.input"] }
    private var panel: XCUIElement { app.buttons["list.detailPanel.more"] }
    /// **Der Ausgang liegt seit dem 08.08. unten links** (Punkt C-3): „Fertig"
    /// an der Eingabezeile statt ✗ oben in der Schicht. Die Zusage dieser Datei
    /// ist unverändert — auf jedem Weg gibt es einen Weg hinaus, auch ohne
    /// Tastatur; nur der Knopf ist ein anderer.
    private var dismiss: XCUIElement { app.buttons["list.input.done"] }

    /// Die Oberkante des Blocks unten — der Vorschlagsfläche, wo sie steht,
    /// sonst der Angaben-Schicht.
    private var blockTop: CGFloat {
        let surface = app.staticTexts["Häufig gekauft"]
        let candidates = [
            surface.exists ? surface.frame.minY : nil,
            panel.exists ? panel.frame.minY - 8 : nil,
        ].compactMap { $0 }
        return candidates.min() ?? app.windows.firstMatch.frame.maxY
    }

    /// Wie viel vom Bildschirm der Block unten frisst — **unser** Block,
    /// ohne Apples Tastatur.
    ///
    /// Bis zum 05.08. rechnete die Messung bis zur Bildschirmunterkante und
    /// zählte damit die Tastatur mit. Das ging nur zufällig gut: Auf Läufen
    /// mit offenem Simulator-Fenster (Hardware-Tastatur angeschlossen) ist
    /// die Software-Tastatur nur die Minileiste. Auf einem kopflosen
    /// Simulator steht die volle — allein 291 pt von 852 (34 %), und der
    /// Deckel riss bei 59,97 %, **auf `origin/main` vor dem Merge
    /// (e79b2f7) auf die Stelle genau gleich**. Ein Deckel, der auf dem
    /// unveränderten Stand reißt, misst nicht die App, sondern Apples
    /// Tastaturhöhe.
    ///
    /// Abgezogen wird dieselbe Fläche, die der Accessibility-Audit ausnimmt
    /// (`softwareKeyboardRegion`): die Tastatur plus eine Berührungsfläche
    /// (44 pt) QuickType-Leiste darüber. Was der Deckel bewacht, bleibt
    /// unverändert scharf: Der 55-%-Fall vom 03.08. stand **ohne** Tastatur
    /// da und risse auch heute.
    private var blockShare: Double {
        let screen = app.windows.firstMatch.frame
        let keyboard = app.keyboards.firstMatch
        let unten = keyboard.exists
            ? min(screen.maxY, keyboard.frame.minY - 44)
            : screen.maxY
        return Double((unten - blockTop) / screen.height)
    }

    /// **Der Deckel.** Gemessen am 03.08. gegen `4311709`: Der Weg über eine
    /// Vorschlagskachel brachte den Block auf **482 pt von 874 = 55 %** — für
    /// das Anlegen *eines* Artikels, ohne dass überhaupt eine Tastatur im Spiel
    /// war. Von der Liste, in die man gerade etwas einträgt, blieb eine Zeile.
    ///
    /// 45 % ist bewusst großzügiger als der gemessene neue Wert (39 %): Der
    /// Deckel bewacht die Klasse Fehler, nicht die Dezimalstelle.
    private let ceiling = 0.45

    private func assertBlockFits(_ weg: String) {
        XCTAssertLessThan(
            blockShare, ceiling,
            "Der Block unten frisst \(Int(blockShare * 100)) % des Bildschirms (\(weg))"
        )
    }

    private func startTyping() {
        XCTAssertTrue(input.waitForExistence(timeout: 20))
        input.tapAndAwaitKeyboard(in: app)
    }

    // MARK: Weg 1 — von Hand getippt

    func testTypedByHandFitsAndCanBeDismissedWithoutTheKeyboard() {
        startTyping()
        app.typeText("Grillfackeln\n")
        XCTAssertTrue(panel.waitForExistence(timeout: 10), "Die Schicht steht nicht")
        assertBlockFits("von Hand getippt")

        dismiss.tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5),
                      "Die Schicht lässt sich nicht weglegen")
        XCTAssertTrue(app.buttons["Grillfackeln"].exists,
                      "Weglegen ist kein Abbrechen — der Artikel bleibt")
    }

    // MARK: Weg 2 — aus „Häufig gekauft"

    /// **Scotts Punkt 9, wörtlich.** Auf diesem Weg steht keine Tastatur, also
    /// half auch der bisherige Ausgang nicht: Gegen `4311709` bleibt die Schicht
    /// stehen, auch nach dem Scrollen der Liste.
    func testAStapleChipLeavesAWayOutWithoutAnyKeyboard() {
        XCTAssertTrue(input.waitForExistence(timeout: 20))
        app.buttons["Milch hinzufügen"].tap()

        XCTAssertTrue(panel.waitForExistence(timeout: 10), "Die Schicht steht nicht")
        XCTAssertEqual(app.keyboards.count, 0,
                       "Dieser Weg soll ohne Tastatur laufen — sonst prüft die Journey den anderen")
        assertBlockFits("aus „Häufig gekauft“")

        dismiss.tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5),
                      "Aus „Häufig gekauft“ heraus gibt es keinen Weg hinaus")
        XCTAssertTrue(app.buttons["Milch"].exists, "Der Artikel bleibt auf der Liste")
    }

    /// Und der zweite Vorschlag bleibt **einen Tipp** weit weg — die Fläche
    /// schrumpft neben der Schicht, sie verschwindet nicht. Genau das war am
    /// 26.07. schon einmal kaputt.
    func testTheNextSuggestionStaysOneTapAwayWhileThePanelIsUp() {
        XCTAssertTrue(input.waitForExistence(timeout: 20))
        app.buttons["Milch hinzufügen"].tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 10))

        let zweite = app.buttons["Brot hinzufügen"]
        XCTAssertTrue(zweite.waitForExistence(timeout: 5),
                      "Der nächste Vorschlag ist nicht mehr erreichbar")
        zweite.tap()
        XCTAssertTrue(app.buttons["Brot"].waitForExistence(timeout: 10))
    }

    // MARK: Weg 3 — über eine Wörterbuch-Kachel

    func testADictionaryChipFollowsTheSameContract() {
        startTyping()
        app.typeText("Milc")
        // Seit dem 08.08. startet die Fläche beim Tippen zugeklappt (Punkt
        // C-1) — das Wörterbuch-Raster liegt hinter dem Winkel-Knopf. Der
        // Vertrag dieser Datei gilt für den Weg dahinter unverändert.
        app.buttons["list.suggestions.toggle"].tap()
        let kachel = app.buttons["Milch hinzufügen"]
        XCTAssertTrue(kachel.waitForExistence(timeout: 10),
                      "Das Wörterbuch schlägt zu „Milc“ nichts vor")
        kachel.tap()

        XCTAssertTrue(panel.waitForExistence(timeout: 10), "Die Schicht steht nicht")
        assertBlockFits("über eine Wörterbuch-Kachel")

        dismiss.tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5),
                      "Die Schicht lässt sich nicht weglegen")
    }

    // MARK: Der Wortschatz wird nicht mitten durch geschnitten

    /// **Scotts Punkt 8 an der Stelle, an der man ihn sieht.**
    ///
    /// Bei 128 pt stand die erste Gruppe („Menge") ganz da und die zweite
    /// („Größe") wurde **mitten durch die Chips** von der Eingabezeile
    /// abgeschnitten — der Kommentar im Code versprach „zwei Reihen plus ein
    /// angeschnittener Rest" und hielt das nie. Gegen `4311709` liegt „klein"
    /// halb über und halb unter der Kante.
    ///
    /// Geprüft wird die Regel, nicht die Zahl: **Kein Chip darf halb
    /// dastehen.** Ganz sichtbar oder gar nicht — der Schnitt gehört auf eine
    /// Kante, nicht durch eine Beschriftung.
    func testNoVocabularyChipIsCutInHalfByTheInputBar() {
        startTyping()
        app.typeText("Grillfackeln\n")
        XCTAssertTrue(panel.waitForExistence(timeout: 10))

        let kante = input.frame.minY
        for wort in ["1", "klein"] {
            let chip = app.buttons[wort].firstMatch
            guard chip.exists else { continue }
            let f = chip.frame
            let ganzOben = f.maxY <= kante + 1
            let ganzUnten = f.minY >= kante - 1
            XCTAssertTrue(
                ganzOben || ganzUnten,
                "Der Chip „\(wort)“ \(f) wird von der Eingabezeile (Kante \(kante)) angeschnitten"
            )
        }
    }
}
