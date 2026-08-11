import XCTest

/// **Eine Gegend, die noch niemand geholt hat (#144).**
///
/// > „the like markets windows is trash for a new location becuase the big
/// > stuttgart showed only penny and kaufland there, so its uselless, it should
/// > show everything and it should show directly that new markets are loaded in"
///
/// Die Datenlage stimmt: In `branches` sind nur **Kaufland und Penny**
/// bundesweit, alles andere entsteht erst durch die Gebiets-Anforderung
/// (Verzeichnis ~3 min, Angebote mit der Nightly). Der Wähler zeigte in einer
/// frischen Gegend also ehrlich zwei Ketten — **sagte aber nichts dazu**, und
/// zwei Ketten ohne Erklärung sind von „hier gibt es nichts" nicht zu
/// unterscheiden.
///
/// Der Hinweis hing bis zum 11.08. an `isFetchingArea`, und das wird erst nach
/// zwei Netzrunden wahr. Jetzt hängt er daran, was das Verzeichnis **schon
/// gerechnet hat**: nur bundesweite Ketten im Umkreis.
///
/// **Angekündigt wird das Laden, nicht die Ketten.** Welche Läden in einer
/// Gegend stehen, weiß vorher niemand — eine Liste zu versprechen, die dann
/// anders ausfällt, wäre die schlechtere Antwort auf „zeig alles an".
///
/// Die Fixtures: um 17419 (Ahlbeck) steht ausschließlich Penny, um 01219
/// (Dresden) stehen fünf Ketten. Der Übergang „läuft noch → fertig" kommt aus
/// `-uiTestingGegendWirdFertig`; drei Minuten kann eine Journey nicht warten.
final class FrischeGegendJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    private func starte(_ extra: [String] = []) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"] + extra
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
    }

    private var hinweis: XCUIElement {
        app.descendants(matching: .any)["markets.areaFetching"]
    }

    // MARK: Der frische Zustand

    /// **Die Zeile, die gefehlt hat.**
    func testAFreshAreaSaysThatMoreIsBeingFetched() {
        starte(["-uiTestingGegendWirdFertig"])
        fuegeRegionHinzu("17419")
        oeffneWaehler()

        XCTAssertTrue(hinweis.waitForExistence(timeout: 20),
                      "Eine frische Gegend sieht aus wie eine leere:\n" + app.debugDescription)
        XCTAssertTrue(hinweis.label.contains("Neue Märkte werden gerade geladen"),
                      "Die Zeile sagt es nicht in Scotts Worten: \(hinweis.label)")
        XCTAssertTrue(hinweis.label.contains("bundesweiten"),
                      "Ohne den Grund liest sich die kurze Liste weiter als Ergebnis: \(hinweis.label)")
    }

    /// **Und sie löst sich auf, wenn der Lauf landet** — mit den Ketten, die
    /// er gebracht hat. Ohne diese Hälfte wäre die Zeile ein Kreisel, hinter
    /// dem nichts passiert.
    func testTheNoticeResolvesWhenTheDirectoryArrives() {
        starte(["-uiTestingGegendWirdFertig"])
        fuegeRegionHinzu("17419")
        oeffneWaehler()
        XCTAssertTrue(hinweis.waitForExistence(timeout: 20))

        let netto = app.buttons["picker.chain.Netto"]
        XCTAssertTrue(netto.waitForExistence(timeout: 40),
                      "Nach dem Gebiets-Lauf fehlen die neuen Ketten:\n" + app.debugDescription)
        XCTAssertFalse(hinweis.exists,
                       "Die Ladezeile steht noch da, obwohl die Gegend versorgt ist")
    }

    /// **Kein Wolf-Geschrei.** Wo das Verzeichnis etwas hergibt, hat die Zeile
    /// nichts zu suchen — sonst steht sie überall und sagt nichts mehr.
    func testAWellStockedAreaShowsNoSuchNotice() {
        starte()
        oeffneWaehler()

        XCTAssertTrue(app.buttons["picker.chain.REWE"].waitForExistence(timeout: 20),
                      "Der Wähler lädt nicht:\n" + app.debugDescription)
        XCTAssertFalse(hinweis.exists, "In Dresden wird nichts nachgeladen")
    }

    /// **Eine Anforderung, die nicht herausgeht, sagt das** — statt einen
    /// Kreisel zu drehen, hinter dem nichts läuft.
    func testAFailedAreaRequestIsVisibleAndOffersARetry() {
        starte(["-uiTestingGegendScheitert"])
        fuegeRegionHinzu("17419")
        oeffneWaehler()

        let fehler = app.descendants(matching: .any)["markets.areaFailed"]
        XCTAssertTrue(fehler.waitForExistence(timeout: 30),
                      "Die gescheiterte Gebiets-Anforderung bleibt unsichtbar:\n" + app.debugDescription)
        XCTAssertTrue(app.buttons["Erneut"].exists, "Ohne zweiten Versuch ist die Meldung eine Sackgasse")
    }

    // MARK: Helfer

    private func fuegeRegionHinzu(_ plz: String) {
        app.tabBars.buttons["Einstellungen"].tap()
        oeffnePlaces()
        app.tippe(app.buttons["Region hinzufügen"], "Region hinzufügen")

        let field = app.textFields["region.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText(plz)
        app.buttons["Weiter"].tap()

        XCTAssertTrue(app.staticTexts["PLZ \(plz)"].waitForExistence(timeout: 20),
                      "Die Region wurde nicht übernommen")
    }

    private func oeffneWaehler() {
        if !app.navigationBars["Filialen und Regionen"].exists {
            app.tabBars.buttons["Einstellungen"].tap()
        }
        oeffnePlaces()
        app.tippe(app.buttons["Filialen bearbeiten"], "Filialen bearbeiten")
        XCTAssertTrue(app.navigationBars["Filialen wählen"].waitForExistence(timeout: 20))
    }

    private func oeffnePlaces() {
        guard !app.navigationBars["Filialen und Regionen"].exists else { return }
        app.tippe(app.buttons["settings.places"], "Filialen und Regionen")
    }
}
