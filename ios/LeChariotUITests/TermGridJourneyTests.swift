import XCTest

/// **Beim Tippen steht über der Eingabezeile ein Raster aus Wörtern, die die
/// App versteht** — L-4 aus dem Liste-Konzept.
///
/// Zwei Dinge, die sich nur am laufenden Bildschirm zeigen: dass ein Tipp auf
/// eine Kachel wirklich das Wort auf die Liste legt, und dass die Fläche auch
/// dann etwas sagt, wenn nichts passt. Die Auswahlregel selbst steht in
/// `TermSuggestionsTests`.
///
/// **Seit dem 10.08. steht die Fläche beim Tippen von selbst da** (Punkt E).
/// Zwischen dem 08.08. und heute lag sie hinter einem Winkel-Knopf, und jeder
/// Test hier fing mit einem Tipp darauf an; diese Zeilen sind ersatzlos weg.
final class TermGridJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// **Der Startzustand gehört zum Test, nicht ins `setUp`.**
    ///
    /// Seit #142 prüft eine der Journeys hier den Fall *ohne* Filiale, und der
    /// unterscheidet sich von den übrigen genau in einem Startargument. Ein
    /// `setUp`, das immer denselben Zustand hinlegt, könnte ihn nicht
    /// herstellen.
    private func start(ohneFiliale: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
            + [ohneFiliale ? "-uiTestingOnboardedNoBranches" : "-uiTestingOnboardedAllBranches"]
        app.launch()
    }

    func testTypingOffersWordsTheMatcherUnderstands() {
        start()
        let feld = input()
        feld.tap()
        feld.typeText("voll")

        let kachel = app.buttons["Vollmilch hinzufügen"]
        XCTAssertTrue(kachel.waitForExistence(timeout: 10),
                      "Zu voll wird kein Wörterbuchwort angeboten")
        XCTAssertTrue(app.staticTexts["list.terms.title"].exists)
        attach("raster-voll")

        // Der Tipp legt das **Wort** auf die Liste, nicht den getippten Anfang.
        kachel.tap()
        XCTAssertTrue(app.buttons["Vollmilch"].waitForExistence(timeout: 10),
                      "Die Kachel legt den Begriff nicht auf die Liste")
        XCTAssertEqual(app.textFields["list.input"].value as? String, "Nächster Artikel …",
                       "Das Feld muss nach dem Tippen auf eine Kachel leer sein")
    }

    /// **Wenn nichts passt, sagt die Fläche das** — statt sich stillschweigend
    /// zu schließen. Dieselbe Unterscheidung wie im Kopf des Trefferblatts:
    /// „kenne ich nicht" ist eine Auskunft, kein Fehler.
    /// **Ohne gewählte Filiale schlägt das Wörterbuch trotzdem vor** — Scotts
    /// Punkt 5 der Bedienrunde vom 11.08. (#142).
    ///
    /// > „Wörterbuch matching klappt ohne Markt nicht, also wenn ich kartof
    /// > eingebe kommt das Schlagwort Kartoffeln wie sonst nicht, ich hatte in
    /// > diesem edge case keine Märkte ausgewählt."
    ///
    /// Der Zustand ist der, in dem er stand: Assistent durchlaufen, PLZ da,
    /// Filialen alle abgewählt — also **kein einziges Angebot** im Vorrat. Bis
    /// heute siebte `TermSuggestions` jeden Kandidaten an genau diesem Vorrat
    /// aus, und ein leerer Vorrat siebt alles weg. Die Journey steht hier und
    /// nicht nur als Unit-Test, weil der Fehler zwei Stockwerke hat: die
    /// Auswahlregel und die Fläche, die sie zeichnet.
    func testTypingSuggestsFromTheDictionaryWithoutAnyMarket() {
        start(ohneFiliale: true)
        let feld = input()
        feld.tapAndAwaitKeyboard(in: app)
        feld.typeText("kartof")

        let kachel = app.buttons["Kartoffeln hinzufügen"]
        XCTAssertTrue(kachel.waitForExistence(timeout: 10),
                      "Ohne Filiale schlägt \u{201E}kartof\u{201C} nichts vor")
        attach("raster-ohne-filiale")

        // Und der Weg dahinter trägt auch ohne Vorrat: Der Tipp legt das Wort
        // auf die Liste. Ein Vorschlag, den man nicht antippen kann, wäre nur
        // die halbe Reparatur.
        kachel.tap()
        XCTAssertTrue(app.buttons["Kartoffeln"].waitForExistence(timeout: 10),
                      "Die Kachel legt den Begriff nicht auf die Liste")
    }

    func testAPrefixWithoutAnyMatchSaysSo() {
        start()
        let feld = input()
        feld.tap()
        // **Erst ein Anfang mit Treffern, dann der ohne.** Geprüft wird der
        // Übergang: Die Fläche steht und **bleibt** stehen, wenn der nächste
        // Buchstabe alle Treffer wegnimmt.
        feld.typeText("mil")
        feld.typeText("chxyzq")

        let hinweis = app.staticTexts["list.terms.empty"]
        XCTAssertTrue(hinweis.waitForExistence(timeout: 10),
                      "Ohne Treffer sagt die Fläche nichts")
        XCTAssertTrue(hinweis.label.contains("milchxyzq"),
                      "Der Hinweis nennt das Wort nicht: \(hinweis.label)")
        // Und der Weg bleibt offen: Aufschreiben geht weiter.
        XCTAssertTrue(app.buttons["Artikel hinzufügen"].isEnabled)
        attach("raster-ohne-treffer")
    }

    /// **Weder die Eingabezeile noch die Vorschlagsfläche wandern, während man
    /// tippt** — die Bedingung aus PR #29, und die einzige, die man nicht durch
    /// Hinsehen prüfen kann.
    ///
    /// Die Trefferzahl ist mit jedem Buchstaben eine andere: „v" kennt nichts,
    /// „vo" eins, „vollx" wieder nichts. Gemessen wird deshalb bei jedem
    /// Tastendruck **beides** — die Zeile und die Oberkante der Fläche darüber.
    ///
    /// **Die Zeile allein wäre die zu leichte Probe.** Sie ist das unterste
    /// Element des Blocks und klebt an der Tastaturkante; sie kann gar nicht
    /// wandern, und ein Test darauf ginge auch dann durch, wenn die Kacheln
    /// unter dem zielenden Finger auf und ab hüpften. Nachgeprüft, indem die
    /// feste Höhe probeweise entfernt wurde: Die Zeile blieb stehen, der Test
    /// blieb grün — er hätte nichts gemerkt. Deshalb die Oberkante dazu.
    func testNothingMovesUnderTheThumbWhileTyping() {
        start()
        let feld = input()
        feld.tap()
        feld.typeText("vo")

        var zeile: [CGRect] = []
        var oberkante: [CGFloat] = []
        var wortzahl: [Int] = []
        for buchstabe in ["l", "l", "x"] {
            feld.typeText(buchstabe)
            zeile.append(app.textFields["list.input"].frame)
            oberkante.append(app.staticTexts["list.terms.title"].frame.minY)
            wortzahl.append(app.buttons.matching(
                NSPredicate(format: "label ENDSWITH %@", " hinzufügen")
            ).count)
        }

        // Erst der Beweis, dass die Probe überhaupt etwas beweist: Die Zahl der
        // Kacheln muss sich unterwegs geändert haben, sonst stünde alles still,
        // weil sich nichts geändert hat.
        XCTAssertGreaterThan(Set(wortzahl).count, 1,
                             "Die Trefferzahl bleibt gleich — die Probe misst nichts: \(wortzahl)")
        for (index, frame) in zeile.enumerated() {
            XCTAssertEqual(frame, zeile[0],
                           "Die Eingabezeile ist beim \(index + 1). Buchstaben gewandert")
        }
        for (index, y) in oberkante.enumerated() {
            XCTAssertEqual(y, oberkante[0], accuracy: 0.5,
                           "Die Vorschlagsfläche ist beim \(index + 1). Buchstaben gewandert")
        }
    }

    // MARK: Helfer

    private func input() -> XCUIElement {
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15), "Keine Eingabezeile")
        return feld
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
