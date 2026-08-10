import XCTest

/// **Die zwei Griffe an einer Kachel: tippen und halten.**
///
/// Scott am 08.08.: „Langes Halten öffnet die Treffer" — vorher lag der Weg
/// dorthin im Kontextmenü, also ein Griff weiter. Der Umbau legt ihn auf das
/// Halten selbst.
///
/// **Am 10.08. hat sich das Ziel geändert, nicht die Geste** (Punkt A): Das
/// Halten öffnet jetzt das Artikelblatt — Angaben *und* Treffer auf einem
/// Bildschirm (`ItemSheet`). Alles, was hier gemessen wird, gilt unverändert;
/// nur heißt „das Blatt steht" ab jetzt „`itemSheet.done` steht".
///
/// **Der Grund, warum das hier gemessen und nicht nur gebaut wird:** Ein
/// Erkenner für langes Drücken kann den Tipp verzögern — er muss abwarten, ob
/// aus dem Tipp noch ein Halten wird. Und der Tipp ist die eine Handlung, die
/// diese Kachel im Laden können muss. Also steht hier eine Zahl, kein Gefühl:
/// **vorher 0,739 s, nachher 0,772 s** vom Tipp bis „erledigt", Median aus je
/// fünf Durchgängen; die Streuung des Vorher-Laufs allein war 0,697–0,746 s.
/// Der Tipp wartet also nicht.
///
/// **Und ein zweiter Befund, der den Umbau geformt hat:** Blatt und
/// Kontextmenü können sich diese Geste nicht teilen — siehe
/// `testEveryHoldLengthOpensTheMatchesAndNotTheContextMenu`.
final class TileGestureJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: Der Tipp

    /// **Abhaken bleibt sofort.** Gemessen wird die Zeit vom Tipp bis zu dem
    /// Moment, in dem die Kachel „erledigt" meldet — fünfmal, damit ein
    /// einzelner Ausreißer der Simulator-Uhr nichts entscheidet.
    ///
    /// Die absolute Zahl trägt den Aufwand von XCUITest mit (Element suchen,
    /// Ereignis bauen, auf Ruhe warten); interessant ist sie deshalb im
    /// **Vergleich** vorher/nachher, und dafür steht sie im Protokoll. Die
    /// Schranke hier ist grob und fängt nur den Fall ab, der wirklich weh täte:
    /// ein Erkenner, der auf sein Zeitfenster wartet, bevor er den Tipp
    /// durchlässt.
    func testATapChecksTheItemWithoutWaitingForALongPress() {
        launch()
        addItem("Vollmilch")

        let kachel = kachelMitVollmilch()
        XCTAssertTrue(kachel.waitForExistence(timeout: 15))

        var messungen: [TimeInterval] = []
        for durchgang in 0..<5 {
            let willErledigt = durchgang % 2 == 0
            let start = Date()
            kachelMitVollmilch().tap()
            XCTAssertTrue(
                warteAufZustand(erledigt: willErledigt),
                "Der Tipp hat den Zustand nicht umgelegt (Durchgang \(durchgang))"
            )
            messungen.append(Date().timeIntervalSince(start))
        }

        let median = messungen.sorted()[messungen.count / 2]
        // Landet als Zahl im Protokoll — genau dafür ist der Test da.
        print("MESSUNG tipp-bis-erledigt median=\(String(format: "%.3f", median)) s "
              + "alle=\(messungen.map { String(format: "%.3f", $0) })")

        XCTAssertLessThan(
            median, 1.0,
            "Abhaken dauert \(String(format: "%.3f", median)) s — der Tipp wartet auf "
            + "den langen Druck, statt sofort zu greifen"
        )
    }

    // MARK: Das Halten

    /// **Halten öffnet die Treffer, ohne Umweg über ein Menü.**
    func testALongPressOpensTheItemSheetDirectly() {
        launch()
        addItem("Vollmilch")

        let kachel = kachelMitVollmilch()
        XCTAssertTrue(kachel.waitForExistence(timeout: 15))
        kachel.press(forDuration: 0.6)

        XCTAssertTrue(
            blatt.waitForExistence(timeout: 10),
            "Nach dem Halten steht das Artikelblatt nicht da:\n" + app.debugDescription
        )
        // Und es trägt beides: die Angebote als Bildschirm, die Angaben hinter
        // ihrem Knopf ganz oben (10.08. abends, Punkt 10).
        XCTAssertTrue(app.staticTexts["itemSheet.offers.header"].exists,
                      "Auf dem Blatt fehlen die Angebote:\n" + app.debugDescription)
        XCTAssertTrue(app.buttons["itemSheet.angaben"].exists,
                      "Auf dem Blatt fehlt der Weg zu den Angaben:\n" + app.debugDescription)
    }

    /// **Egal wie lange gehalten wird — es kommen die Treffer, nie das
    /// Kontextmenü.**
    ///
    /// Auf derselben Kachel liegen zwei Erkenner: der SwiftUI-Druck von hier
    /// und Apples `UIContextMenuInteraction`. Welcher gewinnt, steht in keiner
    /// Dokumentation; am 08.08. nachgemessen, und die Antwort war eindeutig:
    /// **bei 0,4 s, 0,7 s und 1,2 s öffnet das Trefferblatt und das Menü bleibt
    /// weg.** Sobald ein Blatt über der Kachel liegt, ist die Fläche fort, an
    /// der das Menü hängen würde.
    ///
    /// Das ist der Grund, warum Angaben und Löschen ins ⋯-Menü des Blattes
    /// gewandert sind. Und es ist die Regel, die kippen würde, wenn jemand die
    /// 0,35 s über die Schwelle des Kontextmenüs (~0,5 s) hebt: Dann käme bei
    /// langem Halten das Menü und der Nutzer bekäme zwei verschiedene Antworten
    /// auf dieselbe Geste. Dieser Test merkt das.
    func testEveryHoldLengthOpensTheSheetAndNotTheContextMenu() {
        for dauer in [0.4, 0.7, 1.2] {
            launch()
            addItem("Vollmilch")
            XCTAssertTrue(kachelMitVollmilch().waitForExistence(timeout: 15))
            kachelMitVollmilch().press(forDuration: dauer)

            XCTAssertTrue(blatt.waitForExistence(timeout: 10),
                          "Halten für \(dauer) s hat das Artikelblatt nicht geöffnet")
            // Dem Menü Zeit lassen: Es käme später als das Blatt, wenn es käme.
            _ = app.buttons["list.item.sheet"].waitForExistence(timeout: 2)
            XCTAssertFalse(app.buttons["list.item.sheet"].exists,
                           "Bei \(dauer) s stehen Blatt und Kontextmenü gleichzeitig da — "
                           + "dieselbe Geste gibt zwei Antworten")
            app.terminate()
        }
    }

    /// **Angaben und Löschen bleiben mit dem Finger erreichbar.** Das Halten
    /// ist besetzt, und gemessen ist, dass das Kontextmenü damit für den Finger
    /// weg ist (siehe oben). Die beiden Punkte dürfen deshalb nicht unter den
    /// Tisch fallen — sonst wäre ein Griff gespart und zwei Wege verloren.
    ///
    /// **Seit dem 10.08. liegen beide auf demselben Blatt**, das das Halten
    /// öffnet: die Angaben oben, das Löschen ganz unten. Der Umweg über ein
    /// ⋯-Menü ist damit weg — Scotts Punkt A, wörtlich: „the button in the left
    /// corner is only the Präferenzen menu and not löschen".
    ///
    /// **Seit dem Abend desselben Tages liegen die Angaben hinter einem Knopf**
    /// (Punkt 10). Erreichbar bleiben sie — und weil genau das hier geprüft
    /// wird, geht die Journey den Knopf mit, statt die Zusage zu verkleinern.
    func testTheOtherTileActionsAreStillReachable() {
        launch()
        addItem("Vollmilch")

        XCTAssertTrue(kachelMitVollmilch().waitForExistence(timeout: 15))
        app.openItemSheet(ofItem: "Vollmilch")
        app.öffneAngaben()

        XCTAssertTrue(app.buttons["Bio"].waitForExistence(timeout: 10),
                      "Die Angaben stehen nicht auf dem Blatt:\n" + app.debugDescription)

        let löschen = app.buttons["itemSheet.delete"]
        for _ in 0..<6 where !löschen.exists || !löschen.isHittable { app.swipeUp() }
        XCTAssertTrue(löschen.exists, "Kein Weg zum Löschen:\n" + app.debugDescription)
        löschen.tap()
        XCTAssertTrue(app.buttons["Vollmilch"].waitForNonExistence(timeout: 10),
                      "Der Artikel ist noch da")
    }

    // MARK: Helfer

    /// Das Artikelblatt — erkannt an seinem „Fertig", nicht an der Überschrift:
    /// Die ist seit dem 10.08. der Artikelname, und ein Name steht auch auf der
    /// Kachel darunter.
    private var blatt: XCUIElement { app.buttons["itemSheet.done"].firstMatch }

    /// Die Kachel über ihren Namen, nicht über `list.tile`: Beim Abhaken
    /// wandert sie in den Abschnitt „Erledigt", und `firstMatch` zeigte danach
    /// auf eine andere.
    private func kachelMitVollmilch() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Vollmilch")).firstMatch
    }

    /// **Eng abgefragt statt über `expectation(for:)`.** Der erste Anlauf
    /// benutzte eine Vorhersage-Erwartung und maß bei jedem Durchgang 1,83 s —
    /// dieselbe Zahl fünfmal, weil `XCTWaiter` im Sekundentakt nachsieht. Ein
    /// Messgerät mit einer Sekunde Auflösung kann eine Verzögerung von 0,3 s
    /// weder finden noch ausschließen. Die eigene Schleife fragt so schnell
    /// nach, wie eine Abfrage dauert (~0,05 s) — fein genug für die Frage, um
    /// die es geht.
    private func warteAufZustand(erledigt: Bool, frist: TimeInterval = 10) -> Bool {
        let kachel = kachelMitVollmilch()
        let ende = Date().addingTimeInterval(frist)
        while Date() < ende {
            let wert = (kachel.value as? String) ?? ""
            if wert.contains("erledigt") == erledigt { return true }
        }
        return false
    }

    private func launch() {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
    }

    private func addItem(_ text: String) {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
        feld.typeText(text + "\n")
        // Das Mengen-Menü geht beim Anlegen von selbst auf; hier ist es ein
        // Zwischenschritt, kein Prüfgegenstand.
        let panel = app.buttons["list.detailPanel.more"]
        if panel.waitForExistence(timeout: 3) {
            app.swipeUp()
            _ = panel.waitForNonExistence(timeout: 3)
        }
    }
}
