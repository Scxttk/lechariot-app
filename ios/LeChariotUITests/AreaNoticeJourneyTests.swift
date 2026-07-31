import XCTest

/// Der Hinweis, dass die Gegend nachgeladen wurde.
///
/// Warum das eine eigene Journey braucht: Der Gebiets-Lauf dauert etwa drei
/// Minuten und überspannt Sitzungen — wer ihn auslöst, hat die App längst
/// zugemacht. Der Hinweis ist damit **die einzige** Stelle, an der der Nutzer
/// je erfährt, dass jetzt mehr zur Auswahl steht. Fällt er still aus, bleibt
/// die kurze Liste vom Onboarding für immer die Wahrheit, die er kennt — und
/// zwar ohne dass irgendwo etwas fehlschlägt.
///
/// Drei Minuten kann ein Test nicht warten, deshalb startet er mit dem
/// Zustand, den ein früherer Start hinterlassen hätte (`-uiTestingAreaJustFetched`).
final class AreaNoticeJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingAreaJustFetched"]
        app.launch()
    }

    func testTheNoticeAppearsAfterRestartAndLeadsToTheBranchPicker() {
        waitForList()

        let notice = app.staticTexts["Deine Gegend ist jetzt vollständig"]
        XCTAssertTrue(
            notice.waitForExistence(timeout: 15),
            "Kein Hinweis auf das nachgeladene Gebiet — der Nutzer erführe nie davon"
        )

        app.buttons["Filialen wählen"].tap()

        XCTAssertTrue(
            app.navigationBars["Einstellungen"].waitForExistence(timeout: 15),
            "Der Hinweis führt nicht dorthin, wo man Filialen wählt"
        )
    }

    /// Weggetippt ist weggetippt. Ein Hinweis, der nach dem Ausblenden wieder
    /// dasteht, wird nicht gelesen, sondern weggewischt.
    func testTheNoticeStaysGoneAfterItIsDismissed() {
        waitForList()

        let notice = app.staticTexts["Deine Gegend ist jetzt vollständig"]
        XCTAssertTrue(notice.waitForExistence(timeout: 15))

        app.buttons["Hinweis ausblenden"].tap()
        XCTAssertFalse(notice.exists, "Hinweis bleibt nach dem Ausblenden stehen")

        // Tabwechsel hin und zurück: Der Hinweis hängt am Zustand, nicht an
        // der gerade sichtbaren Ansicht.
        app.tabBars.buttons["Angebote"].tap()
        app.tabBars.buttons["Liste"].tap()
        XCTAssertFalse(notice.exists, "Hinweis kommt beim Tabwechsel zurück")
    }

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
}
