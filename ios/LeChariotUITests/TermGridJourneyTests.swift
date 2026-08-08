import XCTest

/// **Beim Tippen steht über der Eingabezeile ein Raster aus Wörtern, die die
/// App versteht** — L-4 aus dem Liste-Konzept.
///
/// Zwei Dinge, die sich nur am laufenden Bildschirm zeigen: dass ein Tipp auf
/// eine Kachel wirklich das Wort auf die Liste legt, und dass die Fläche auch
/// dann etwas sagt, wenn nichts passt. Die Auswahlregel selbst steht in
/// `TermSuggestionsTests`.
final class TermGridJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingOnboardedAllBranches"]
        app.launch()
    }

    func testTypingOffersWordsTheMatcherUnderstands() {
        let feld = input()
        feld.tap()
        feld.typeText("voll")
        openTheSurface()

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
    func testAPrefixWithoutAnyMatchSaysSo() {
        let feld = input()
        feld.tap()
        // **Erst ein Anfang mit Treffern, dann der ohne.** Den Winkel-Knopf
        // gibt es nur, wo es etwas aufzuklappen gibt — „xyzq" von Anfang an
        // hätte hier nichts zu öffnen gehabt. Geprüft wird ohnehin der
        // Übergang: Die Fläche steht offen und **bleibt** stehen, wenn der
        // nächste Buchstabe alle Treffer wegnimmt.
        feld.typeText("mil")
        openTheSurface()
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
        let feld = input()
        feld.tap()
        // „v" kennt das Wörterbuch nicht, „vo" schon — und ohne Treffer gibt
        // es den Winkel-Knopf nicht. Die Messung fängt deshalb bei „vo" an.
        feld.typeText("vo")
        openTheSurface()

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

    /// **Seit dem 08.08. startet die Fläche beim Tippen zugeklappt** (Punkt
    /// C-1): Zwei Schichten übereinander — Wörterbuch-Raster über den Angaben
    /// des vorigen Artikels — ließen von der Liste einen Streifen übrig. Was
    /// diese Datei prüft, liegt jetzt einen Winkel-Knopf weiter; die Fläche
    /// selbst ist dieselbe geblieben.
    ///
    /// **Ohne getippten Text gibt es den Knopf nicht** in dem Zustand, den er
    /// hier öffnen soll — deshalb steht in jedem Test erst ein Buchstabe im
    /// Feld, dann dieser Aufruf.
    private func openTheSurface() {
        let knopf = app.buttons["list.suggestions.toggle"]
        XCTAssertTrue(knopf.waitForExistence(timeout: 10),
                      "Der Weg zu den Wörtern fehlt")
        knopf.tap()
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
