import XCTest

/// Journeys around rejecting a match and the follow-up question.
///
/// The thing worth testing here is not the sheet's looks but the promise
/// attached to it: the rejection happens immediately and stands on its own,
/// whether the user answers, skips, or has switched the question off entirely.
final class MatchFeedbackJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    /// Fixture offer that "Vollmilch" hits directly (Lidl, the fixture branch).
    private let fixtureOffer = "Bio Vollmilch"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
        waitForList()
    }

    // MARK: Journeys

    func testRejectingAsksWhyAndTheRejectionStandsAfterSkipping() {
        openMatchesFor("Vollmilch")

        app.buttons["Weglegen"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Kurze Rückfrage"].waitForExistence(timeout: 10),
                      "rejecting must offer the follow-up question")

        app.buttons["Überspringen"].tap()

        XCTAssertTrue(app.staticTexts["Weggelegt"].waitForExistence(timeout: 10),
                      "skipping the question must not undo the rejection")
    }

    func testAnAnswerCanBeSentAndAlsoLeavesTheRejectionInPlace() {
        openMatchesFor("Vollmilch")
        app.buttons["Weglegen"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Kurze Rückfrage"].waitForExistence(timeout: 10))

        let send = app.buttons["Senden"]
        XCTAssertFalse(send.isEnabled, "there is nothing to send before a reason is picked")

        app.buttons["Passt gar nicht zum Artikel. Ein ganz anderes Produkt"].tap()
        XCTAssertTrue(send.isEnabled)
        send.tap()

        XCTAssertTrue(app.staticTexts["Weggelegt"].waitForExistence(timeout: 10))
    }

    /// Switching the question off must stop the sheet, not the rejection.
    func testWithTheQuestionOffRejectingAsksNothing() {
        openTab("Einstellungen")
        let toggle = app.switches["Nach Ablehnungen fragen"].firstMatch
        // "Rückfragen" sits below the fold since the Hilfe section moved in
        // above it, and a List does not build rows nobody has scrolled to.
        var swipes = 0
        while !toggle.exists && swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 15), "the switch must be in the settings")
        XCTAssertEqual(toggle.value as? String, "1", "asking is on by default")
        // Hit the control itself: the element's frame spans the whole row, and
        // its centre is the label rather than the switch.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0", "tapping must actually switch it off")
        openTab("Liste")

        openMatchesFor("Vollmilch")
        app.buttons["Weglegen"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Weggelegt"].waitForExistence(timeout: 10),
                      "the rejection itself must work unchanged")
        XCTAssertFalse(app.navigationBars["Kurze Rückfrage"].exists,
                       "no question may appear once it is switched off")
    }

    // MARK: Helpers

    private func openMatchesFor(_ item: String) {
        let input = app.textFields["list.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        input.typeText(item + "\n")
        dismissQuantitySheet()

        let matches = app.buttons["list.matches"].firstMatch
        XCTAssertTrue(matches.waitForExistence(timeout: 15),
                      "\(item) must match a fixture offer — see MockFixtures")
        matches.tap()
        XCTAssertTrue(app.staticTexts[fixtureOffer].waitForExistence(timeout: 10))
    }

    private func openTab(_ name: String) {
        let inBar = app.tabBars.buttons[name]
        let tab = inBar.exists ? inBar : app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "tab \(name) missing")
        tab.tap()
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

    /// Schließt das Mengen-Menü, das seit [UI-8] beim Anlegen von selbst
    /// aufgeht.
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
