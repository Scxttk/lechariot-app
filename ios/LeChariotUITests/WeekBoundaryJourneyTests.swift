import XCTest

/// Die Wochengrenze am laufenden Gerät.
///
/// Die Einheitentests messen `store.offers`; dieser hier misst den Bildschirm.
/// Beides ist nötig, weil zwischen beiden noch der Suchpfad, die Chip-Leiste
/// und die Gruppierung liegen — und der Fehler saß genau in dem Trichter, den
/// sie sich teilen.
///
/// Die Fixtures tragen seit dem 01.08. zwei Zeilen der Folgewoche
/// (`MockFixtures.nextWeekOffers`): Kaffee, den es diese Woche gar nicht gibt,
/// und dieselbe Bio-Vollmilch billiger.
final class WeekBoundaryJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    private let thisWeekOnly = "Spanische Orangen"
    private let nextWeekOnly = "Kaffee ganze Bohne"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded",
                               "-uiTestingOnboardedAllBranches"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }

    private func openTab(_ name: String) {
        let inBar = app.tabBars.buttons[name]
        let tab = inBar.exists ? inBar : app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Tab \(name) fehlt")
        tab.tap()
    }

    /// **Der Regressionstest am Gerät.** Kein Angebot der Folgewoche darf in
    /// der Angebotsliste stehen.
    func testNextWeekNeverAppearsInTheRunningOfferList() {
        openTab("Angebote")

        XCTAssertTrue(app.staticTexts[thisWeekOnly].waitForExistence(timeout: 15),
                      "Die laufende Woche fehlt")
        XCTAssertFalse(app.staticTexts[nextWeekOnly].exists,
                       "Ein Angebot der Folgewoche steht in der laufenden Liste")
    }

    /// Und die Suche ist kein zweiter Weg an der Grenze vorbei: Wer den Kaffee
    /// der Folgewoche ausdrücklich sucht, findet ihn diese Woche **nicht**.
    ///
    /// Der Fall ist nicht ausgedacht — `OfferQuery.apply` filtert auf
    /// `store.offers`, und wäre die Trennung eine Ebene höher gebaut worden
    /// (etwa erst in der Listenansicht), stünde er hier.
    func testTheSearchDoesNotReachNextWeekEither() {
        openTab("Angebote")
        XCTAssertTrue(app.staticTexts[thisWeekOnly].waitForExistence(timeout: 15))

        let feld = app.searchFields.firstMatch
        XCTAssertTrue(feld.waitForExistence(timeout: 10), "Suchfeld fehlt")
        feld.tap()
        feld.typeText("Kaffee")

        XCTAssertFalse(
            app.staticTexts[nextWeekOnly].waitForExistence(timeout: 3),
            "Die Suche findet ein Angebot, das diese Woche nicht gilt"
        )
    }
}
