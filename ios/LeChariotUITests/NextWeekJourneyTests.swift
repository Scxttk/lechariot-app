import XCTest

/// „Nächste Woche" am laufenden Gerät.
///
/// Zwei Fragen, die keine Einheitenprüfung beantworten kann: Steht der Weg da,
/// wenn der Schalter aus ist (er darf nicht), und ist die Vorschau als Vorschau
/// zu erkennen, wenn er an ist?
///
/// **Dass die Folgewoche nicht in der laufenden Liste steht, wird hier NICHT
/// geprüft** — das ist die Wochengrenze, sie hängt nicht am Schalter und steht
/// in `WeekBoundaryJourneyTests`.
///
/// Die Fixtures tragen dafür seit dem 01.08. zwei Zeilen der Folgewoche
/// (`MockFixtures.nextWeekOffers`) — Kaffee, den es diese Woche gar nicht gibt,
/// und dieselbe Bio-Vollmilch billiger. **Genau Finns Fall:** Milch, die man
/// heute stehen lässt.
final class NextWeekJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    private let thisWeekOnly = "Spanische Orangen"
    private let nextWeekOnly = "Kaffee ganze Bohne"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// `threeChains` nimmt Netto dazu — nötig, sobald die Markt-Leiste der
    /// Vorschau im Spiel ist (sie erscheint erst ab zwei Ketten mit Zeilen).
    /// Siehe `UITestSupport.seededFavorites`.
    private func launch(previewOn: Bool, threeChains: Bool = false) {
        // Beide Richtungen ausdrücklich, nicht über die Vorgabe: Die Journey
        // soll sagen, was sie prüft, auch wenn der Schalter später kippt.
        var arguments = ["-uiTesting", "-uiTestingOnboarded",
                         "-uiTestingOnboardedAllBranches",
                         previewOn ? "-feature.nextWeekPreview"
                                   : "-feature.nextWeekPreview.aus"]
        if threeChains { arguments.append("-uiTestingOnboardedThreeChains") }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        openTab("Angebote")
    }

    private func openTab(_ name: String) {
        let inBar = app.tabBars.buttons[name]
        let tab = inBar.exists ? inBar : app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Tab \(name) fehlt")
        tab.tap()
    }


    /// Ohne Schalter gibt es den Weg nicht — kein halb fertiger Knopf.
    func testThePreviewEntryIsAbsentWhileTheFlagIsOff() {
        launch(previewOn: false)

        XCTAssertFalse(app.buttons["offers.nextWeek"].exists)
    }

    /// Mit Schalter: eigener Bildschirm, eigene Überschrift, und der Satz, der
    /// sagt, dass die Preise noch nicht gelten.
    func testThePreviewOpensAsItsOwnLabelledScreen() {
        launch(previewOn: true)

        let entry = app.buttons["offers.nextWeek"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "Der Weg in die Vorschau fehlt")
        entry.tap()

        XCTAssertTrue(app.navigationBars["Nächste Woche"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["nextWeek.explainer"].exists,
                      "Die Vorschau sagt nicht, dass die Preise noch nicht gelten")
        XCTAssertTrue(app.staticTexts[nextWeekOnly].waitForExistence(timeout: 10),
                      "Das Angebot der Folgewoche fehlt in der Vorschau")
    }

    /// Und zurück: Die laufende Liste bleibt, was sie war. Der Weg hin und her
    /// darf die Trennung nicht aufweichen.
    func testGoingBackLeavesTheRunningListUntouched() {
        launch(previewOn: true)

        app.buttons["offers.nextWeek"].tap()
        XCTAssertTrue(app.navigationBars["Nächste Woche"].waitForExistence(timeout: 10))
        app.navigationBars["Nächste Woche"].buttons.firstMatch.tap()

        XCTAssertTrue(app.staticTexts[thisWeekOnly].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts[nextWeekOnly].exists)
    }

    /// **Eine gewählte Kette ohne Vorschau darf nicht einfach fehlen.**
    /// Das Saatgut wählt Lidl und Aldi; nur Lidl hat Zeilen der Folgewoche.
    /// Aldi muss deshalb sichtbar dastehen — mit dem Grund, nicht als Lücke.
    ///
    /// Eine fehlende Kette sähe für den Nutzer genauso aus wie eine kaputte
    /// App; das ist der Fehler, den die Vorschau als Ganzes vermeiden soll.
    /// Welcher Satz zu welcher Kette gehört, prüft `NextWeekReasonTests`.
    func testAChosenChainWithoutRowsIsNamedWithItsReason() {
        launch(previewOn: true)

        app.buttons["offers.nextWeek"].tap()
        XCTAssertTrue(app.navigationBars["Nächste Woche"].waitForExistence(timeout: 10))

        // Die Zeile fasst Kettenname und Grund zu einem Element zusammen
        // (`accessibilityElement(children: .combine)`), deshalb wird auf das
        // kombinierte Label geprüft und nicht auf zwei getrennte Texte.
        let zeile = app.descendants(matching: .any).containing(
            NSPredicate(format: "label CONTAINS %@", "liegt hier noch nichts vor")
        ).firstMatch
        XCTAssertTrue(zeile.waitForExistence(timeout: 10),
                      "Aldi steht ohne Grund da — oder gar nicht:\n\(app.debugDescription)")
    }

    // MARK: Parität — Suche, Filter, Markt-Leiste (2026-08-02)

    /// **Die Leck-Regel, Richtung Vorschau.** Gesucht wird hier nur in der
    /// Folgewoche.
    ///
    /// „Spanische Orangen" gibt es diese Woche bei Aldi und nächste Woche
    /// nirgends. Wer in der Vorschau danach sucht, darf die laufende Zeile
    /// **nicht** angeboten bekommen — sonst stünde ein heutiger Preis unter
    /// einer Überschrift, die „gilt noch nicht" verspricht.
    func testThePreviewSearchNeverSurfacesACurrentWeekRow() {
        openPreview()
        search(for: thisWeekOnly)

        XCTAssertFalse(app.staticTexts[thisWeekOnly].waitForExistence(timeout: 4),
                       "eine Zeile der laufenden Woche in der Vorschau — genau das Leck aus #53, nur andersherum")
        // Und der Bildschirm sagt, was los ist, statt leer dazustehen.
        XCTAssertTrue(app.staticTexts["nextWeek.explainer"].exists)
    }

    /// **Dieselbe Regel am härtesten Fall: gleicher Produktname, zwei Wochen.**
    ///
    /// „Bio Vollmilch" steht diese Woche mit 0,99 € und nächste mit 0,79 € in
    /// den Fixtures. Ein Suchtreffer, der die Wochen verwechselt, fällt bei
    /// einem unterschiedlichen Namen auf — bei gleichem Namen nur am Preis.
    func testTheSameProductInBothWeeksShowsThePreviewPriceInThePreview() {
        openPreview()
        search(for: "Bio Vollmilch")

        // Über `CONTAINS` und ohne das Währungszeichen: `formatted(.currency)`
        // setzt zwischen Zahl und € ein schmales geschütztes Leerzeichen
        // (U+00A0), und ein Gleichheitsvergleich auf „0,79 €" findet deshalb
        // nichts — eine Stunde, die niemand zweimal verlieren muss.
        XCTAssertTrue(label(containing: "0,79").waitForExistence(timeout: 10),
                      "der Preis der Folgewoche fehlt:\n\(app.debugDescription)")
        XCTAssertFalse(label(containing: "0,99").exists,
                       "der heutige Preis darf in der Vorschau nicht auftauchen")
    }

    /// **Die Leck-Regel, Richtung laufende Woche.** Die Suche der Angebote
    /// findet keine Zeile der Folgewoche.
    ///
    /// „Rügenwalder Teewurst" gibt es nur nächste Woche bei Netto. Die #53er
    /// Journeys bewachen die *Liste*; die Suche ist ein zweiter Weg zu
    /// denselben Zeilen und braucht ihren eigenen Nachweis.
    func testTheCurrentWeekSearchNeverSurfacesAPreviewRow() {
        launch(previewOn: true, threeChains: true)
        search(for: nextWeekOnly)

        XCTAssertFalse(app.staticTexts[nextWeekOnly].waitForExistence(timeout: 4),
                       "ein Preis der Folgewoche in der laufenden Suche")
    }

    /// Die Markt-Leiste der Vorschau — dieselbe Bedienung wie in der laufenden
    /// Liste, auf den Zeilen der Folgewoche.
    func testThePreviewHasMarketTabsThatFilterOnlyPreviewRows() {
        openPreview(threeChains: true)

        let leiste = app.descendants(matching: .any)["nextWeek.marketChips"]
        XCTAssertTrue(leiste.waitForExistence(timeout: 10),
                      "die Markt-Leiste fehlt in der Vorschau:\n\(app.debugDescription)")

        // Aldi hat keine Zeilen der Folgewoche — also auch keinen Chip. Ein
        // Chip in die Sackgasse „Nichts für diesen Filter" wäre schlimmer als
        // keiner.
        XCTAssertFalse(leiste.buttons["Aldi"].exists,
                       "ein Chip für eine Kette ohne Vorschau führt ins Leere")

        leiste.buttons["Netto"].tap()
        XCTAssertTrue(app.staticTexts[nextWeekOnlyNetto].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts[nextWeekOnly].exists,
                       "der Chip filtert nicht — Lidls Zeile steht noch da")
        // Und was gefiltert wird, sind Zeilen der Folgewoche, keine heutigen.
        XCTAssertFalse(app.staticTexts["Deutsche Erdbeeren"].exists,
                       "Nettos laufende Zeile ist durch den Filter der Vorschau gerutscht")
    }

    /// **Der ehrliche Grund bleibt stehen, auch wenn gefiltert ist.**
    ///
    /// In der laufenden Woche ist die Fußnote der leeren Filialen eine
    /// Randnotiz und verschwindet unter Suche und Filter. Hier ist sie die
    /// Antwort auf „wo ist mein Aldi" — und die wird nicht falsch, weil jemand
    /// ins Suchfeld getippt hat. Wer sonst nach „Kaffee" sucht, sieht eine
    /// Liste ohne Aldi und hält die Vorschau für kaputt.
    func testTheHonestPerChainReasonSurvivesSearchAndFilter() {
        openPreview(threeChains: true)
        search(for: nextWeekOnly)

        let grund = app.descendants(matching: .any).containing(
            NSPredicate(format: "label CONTAINS %@", "liegt hier noch nichts vor")
        ).firstMatch
        XCTAssertTrue(grund.waitForExistence(timeout: 10),
                      "unter Suche fehlt der Grund je Kette:\n\(app.debugDescription)")
    }

    /// Eine Suche ohne Treffer sagt in der Vorschau „nächste Woche", nicht
    /// „diese Woche" — und bietet den Ausweg an.
    func testAFruitlessSearchInsideOneChainNamesTheRestriction() {
        openPreview(threeChains: true)
        app.descendants(matching: .any)["nextWeek.marketChips"].buttons["Netto"].tap()
        search(for: nextWeekOnly)          // Lidls Kaffee, aber Netto ist gewählt

        XCTAssertTrue(app.staticTexts["Nichts bei Netto"].waitForExistence(timeout: 10),
                      "\(app.debugDescription)")
        XCTAssertTrue(app.buttons["In allen Märkten suchen"].exists,
                      "die Sackgasse braucht ihren Ausweg")
    }

    // MARK: Helfer

    private let nextWeekOnlyNetto = "Rügenwalder Teewurst"

    private func openPreview(threeChains: Bool = false) {
        launch(previewOn: true, threeChains: threeChains)
        app.buttons["offers.nextWeek"].tap()
        XCTAssertTrue(app.navigationBars["Nächste Woche"].waitForExistence(timeout: 10))
    }

    private func label(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).containing(
            NSPredicate(format: "label CONTAINS %@", text)
        ).firstMatch
    }

    private func search(for text: String) {
        let feld = app.searchFields.firstMatch
        XCTAssertTrue(feld.waitForExistence(timeout: 10), "kein Suchfeld:\n\(app.debugDescription)")
        feld.tap()
        feld.typeText(text)
    }
}
