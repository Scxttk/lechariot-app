import XCTest

/// **Die Vorschläge kleben an der Eingabezeile** (L-2).
///
/// Der Streifen war ein Abschnitt mitten in der Liste und rutschte mit jeder
/// weiteren Zeile weiter aus dem Daumenbereich. Die Rückmeldung der ersten
/// Testerin von außen — „nicht einhändig erreichbar" — meinte nicht das Feld,
/// sondern alles, was zum Hinzufügen dazugehört.
///
/// Der erste Test hier prüft deshalb die **Lage** und nicht die Existenz: Dass
/// es Kacheln gibt, war vorher auch wahr.
final class SuggestionSurfaceJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
    }

    /// Die Kacheln liegen **über** der Eingabezeile und unter der Liste — und
    /// zwar am Bildschirm gemessen, nicht in der Elementhierarchie.
    func testTheSuggestionsSitDirectlyAboveTheInputBar() {
        waitForList()

        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15), "Keine Eingabezeile")
        let kachel = app.buttons["Milch hinzufügen"]
        XCTAssertTrue(kachel.waitForExistence(timeout: 10), "Keine Vorschlagskachel")

        XCTAssertLessThanOrEqual(
            kachel.frame.maxY, feld.frame.minY + 1,
            "Die Kacheln müssen über der Zeile liegen, nicht irgendwo in der Liste"
        )
        // **Die Zusicherung, die wirklich trägt.** Die Zeile darüber galt auch
        // vorher: Im Leerzustand lagen die Kacheln unter der Begrüßung, also
        // ebenfalls über dem Feld — nur eben oben am Bildschirm. Erst die Lage
        // in der unteren Hälfte ist das, worum es bei L-2 geht: der
        // Daumenbereich.
        //
        // Erster Versuch war der Abstand zwischen Kachel und Zeile („unter
        // 80 pt"): gemessen 123 pt, und das ist richtig so — „Milch" steht in
        // der **obersten** Reihe des Rasters, der Abstand ist also die Höhe des
        // Streifens und nicht sein Abstand zur Zeile.
        XCTAssertGreaterThan(
            kachel.frame.minY, app.frame.midY,
            "Der Streifen gehört in die untere Bildschirmhälfte, in Daumenreichweite"
        )
    }

    /// Tippen schließt die Fläche, der Knopf holt sie zurück.
    ///
    /// Die beiden Richtungen zusammen in einem Test, weil ein zugeklappter
    /// Streifen allein nicht zu unterscheiden ist von einem, der gar nicht
    /// mehr da ist.
    func testTypingClosesTheSurfaceAndTheButtonBringsItBack() {
        waitForList()

        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Milch hinzufügen"].waitForExistence(timeout: 10),
                      "Vor dem ersten Artikel steht die Fläche offen")

        feld.tapAndAwaitKeyboard(in: app)
        feld.typeText("Vollmilch\n")
        dismissQuantitySheet()
        XCTAssertTrue(app.buttons["Vollmilch"].waitForExistence(timeout: 10),
                      "Der Artikel ist nicht auf der Liste gelandet")

        let knopf = app.buttons["list.suggestions.toggle"]
        XCTAssertTrue(knopf.waitForExistence(timeout: 5), "Der Knopf muss bleiben")
        XCTAssertEqual(knopf.label, "Vorschläge einblenden",
                       "Der Zustand gehört in den Namen, ein gedrehtes Winkelzeichen sagt nichts")
        XCTAssertFalse(app.buttons["Milch hinzufügen"].exists,
                       "Wer tippt, weiß was er braucht — die Fläche gibt den Platz zurück")

        knopf.tap()
        XCTAssertTrue(app.buttons["Milch hinzufügen"].waitForExistence(timeout: 5),
                      "Der Knopf muss sie zurückholen")
        XCTAssertEqual(app.buttons["list.suggestions.toggle"].label, "Vorschläge ausblenden")
    }

    // MARK: Helfer

    /// Startet hinter dem Assistenten (`-uiTestingOnboarded`) und wartet, bis
    /// die Liste steht.
    ///
    /// Vorher lief hier der ganze Onboarding-Assistent — sieben Bildschirme für
    /// einen Zustand, den diese Journey nur durchquert. Gemessen am 2026-07-31:
    /// Der Assistent ist 72 % der 20-Minuten-Suite.
    private func waitForList() {
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
    }

    /// Schließt das Mengen-Menü, das seit [UI-8] beim Anlegen von selbst
    /// aufgeht. Diese Journey testet nicht das Menü, sondern die
    /// Vorschlagsfläche darunter.
    private func dismissQuantitySheet() {
        let abbrechen = app.buttons["itemDetail.cancel"]
        if abbrechen.exists { abbrechen.tap(); return }
        // Seit dem 03.08. ist das Mengen-Menue kein Blatt mehr, sondern eine
        // Schicht ueber der Eingabezeile — sie geht mit dem Fokus, nicht mit
        // einem Knopf. Ein Wisch ueber die Liste tut das.
        let panel = app.buttons["list.detailPanel.more"]
        guard panel.waitForExistence(timeout: 3) else { return }
        app.swipeUp()
        _ = panel.waitForNonExistence(timeout: 3)
    }

}
