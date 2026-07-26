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
        app.launchArguments = ["-uiTesting", "-uiTestingAreaJustFetched"]
        app.launch()
    }

    func testTheNoticeAppearsAfterRestartAndLeadsToTheBranchPicker() {
        completeOnboarding()

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
        completeOnboarding()

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

    private func completeOnboarding() {
        app.buttons["onboarding.primary"].tap()   // welcome
        app.buttons["onboarding.skip"].tap()      // name
        let plz = app.textFields["Postleitzahl"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15))
        plz.tap()
        plz.typeText("01219")
        app.buttons["onboarding.primary"].tap()
        app.buttons["onboarding.skip"].tap()      // household
        app.buttons["onboarding.skip"].tap()      // diet
        app.buttons["onboarding.primary"].tap()   // consent
        let branch = app.buttons["Lidl, Dresden Reick"]
        XCTAssertTrue(branch.waitForExistence(timeout: 15))
        branch.tap()
        app.buttons["markets.done"].tap()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }
}
