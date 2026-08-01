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

    private func launch(previewOn: Bool) {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded",
                               "-uiTestingOnboardedAllBranches"]
            + (previewOn ? ["-feature.nextWeekPreview"] : [])
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
}
