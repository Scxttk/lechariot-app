import XCTest

/// End-to-end journeys through the real UI.
///
/// The unit tests cover the stores; what they cannot catch is a step that no
/// longer leads anywhere — a button that stays disabled, a screen that does not
/// advance, a state that sends the user back to the start. Those are exactly
/// the failures a first-time user meets, so they get walked here.
///
/// Runs are hermetic: `-uiTesting` makes the app wipe its own defaults during
/// startup and serve fixtures instead of Supabase (see `UITestSupport`). PLZ
/// 01219 is the fixture region that comes back already synced, with the two
/// fixture branches "Dresden Reick" (Lidl) and "Dresden Prohlis" (Aldi).
final class OnboardingJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    private let fixtureBranch = "Lidl, Dresden Reick"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    // MARK: Journeys

    func testFirstLaunchWalksFromWelcomeToTheShoppingList() {
        XCTAssertTrue(primary.waitForExistence(timeout: 15),
                      "a fresh install must open on the welcome screen")
        XCTAssertEqual(primary.label, "Los geht's")

        completeOnboarding(name: "Scott")

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "onboarding must end in the shopping list, not anywhere else")
    }

    /// Every profile question is optional — a user who answers nothing still has
    /// to arrive in the app.
    func testOnboardingCanBeCompletedWithoutAnsweringAnything() {
        tapPrimary()               // welcome
        tapSkip()                  // "Ohne Namen weiter"
        enterPLZAndContinue()
        tapSkip()                  // household: "Überspringen"
        tapSkip()                  // diet: "Trifft nichts zu"
        tapPrimary()               // consent: "Fertig"
        pickFixtureBranchAndFinish()

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }

    /// The branch picker is the one place onboarding must not let you past
    /// empty-handed: without a branch there is nothing to compare.
    func testDoneStaysDisabledUntilABranchIsPicked() {
        tapPrimary()
        tapSkip()
        enterPLZAndContinue()
        tapSkip()
        tapSkip()
        tapPrimary()

        let done = app.buttons["markets.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15))
        XCTAssertFalse(done.isEnabled, "no branch chosen yet")
        XCTAssertTrue(
            app.staticTexts["Wähle mindestens eine Filiale, um fortzufahren."].exists,
            "and the reason has to be on screen, not just implied by a grey button"
        )

        app.buttons[fixtureBranch].tap()
        XCTAssertTrue(done.isEnabled)
    }

    // MARK: Regressions

    /// Removing the last branch used to flip `isOnboardingComplete` back to
    /// false, which tore the settings screen away mid-tap and dropped the user
    /// into onboarding. It must now be an ordinary empty state.
    func testRemovingTheLastBranchKeepsTheUserInTheApp() {
        completeOnboarding(name: "Scott")

        openTab("Einstellungen")
        app.buttons["Filialen bearbeiten"].tap()
        let branch = app.buttons[fixtureBranch]
        XCTAssertTrue(branch.waitForExistence(timeout: 15))
        branch.tap()

        XCTAssertFalse(app.staticTexts["Ein Einkauf, ein Markt, der beste Preis."].exists,
                       "must not restart onboarding")

        openTab("Liste")
        XCTAssertTrue(app.staticTexts["Keine Filiale gewählt"].waitForExistence(timeout: 10),
                      "the tab has nothing to show and has to say so")
        XCTAssertTrue(app.buttons["Zu den Einstellungen"].exists,
                      "…and offer the way out")
    }

    /// The reset has to be exact and repeatable, otherwise it is worse
    /// than useless — a half-reset run looks like a bug in the app.
    ///
    /// Seit dem 2026-07-30 sitzt er unter Einstellungen → Hilfe und ist in
    /// **jedem** Build da, nicht nur unter `#if DEBUG`: In TestFlight hatte
    /// jemand, der feststeckte, sonst nur den Weg über Löschen und
    /// Neuinstallieren.
    func testResetReturnsToTheWelcomeScreenAndCanBeRepeated() {
        for run in 1...2 {
            completeOnboarding(name: "Scott")

            openTab("Einstellungen")
            let reset = app.buttons["settings.reset"]
            // Lazy List — was nicht sichtbar ist, steht auch nicht im Baum.
            // Die Hilfe steht weit oben, ein Wisch reicht in aller Regel.
            for _ in 0..<6 where !reset.exists { app.swipeUp() }
            XCTAssertTrue(reset.waitForExistence(timeout: 10), "run \(run)")
            reset.tap()
            app.buttons["Zurücksetzen"].tap()

            XCTAssertTrue(
                app.staticTexts["Ein Einkauf, ein Markt, der beste Preis."].waitForExistence(timeout: 10),
                "run \(run): reset must land on the welcome screen"
            )
        }
    }

    /// The name is asked for once and used to greet; losing it silently would
    /// make the question feel pointless.
    func testTheNameSurvivesIntoTheApp() {
        completeOnboarding(name: "Scott")

        XCTAssertTrue(app.staticTexts["Was brauchst du, Scott?"].waitForExistence(timeout: 15))
    }

    func testAddingAnItemPutsItOnTheList() {
        completeOnboarding(name: "Scott")

        let field = app.textFields["Artikel hinzufügen …"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Milch\n")

        XCTAssertTrue(app.staticTexts["Milch"].waitForExistence(timeout: 5))
    }

    /// The quick-add chips used to sit behind the empty state alone, so the
    /// whole strip vanished with the first tap and the second staple had to be
    /// typed. Taking one must leave the rest reachable.
    func testTakingAQuickAddLeavesTheOtherSuggestionsReachable() {
        completeOnboarding(name: "Scott")

        let milch = app.buttons["Milch hinzufügen"]
        XCTAssertTrue(milch.waitForExistence(timeout: 15))
        milch.tap()

        XCTAssertTrue(app.staticTexts["Milch"].waitForExistence(timeout: 5))
        let brot = app.buttons["Brot hinzufügen"]
        XCTAssertTrue(brot.waitForExistence(timeout: 5),
                      "the remaining suggestions must survive the first tap")
        brot.tap()

        XCTAssertTrue(app.staticTexts["Brot"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Milch hinzufügen"].exists,
                       "a staple already on the list must stop being suggested")
    }

    // MARK: Helpers

    /// The onboarding steps are addressed by identifier rather than label: the
    /// software keyboard contributes its own "Weiter" and "Fertig" buttons.
    private var primary: XCUIElement { app.buttons["onboarding.primary"] }
    private var skip: XCUIElement { app.buttons["onboarding.skip"] }

    private func tapPrimary(_ file: StaticString = #filePath, _ line: UInt = #line) {
        XCTAssertTrue(primary.waitForExistence(timeout: 15), "primary button missing", file: file, line: line)
        XCTAssertTrue(primary.isEnabled, "primary button disabled: \(primary.label)", file: file, line: line)
        primary.tap()
    }

    private func tapSkip(_ file: StaticString = #filePath, _ line: UInt = #line) {
        XCTAssertTrue(skip.waitForExistence(timeout: 15), "skip button missing", file: file, line: line)
        skip.tap()
    }

    private func enterPLZAndContinue() {
        let field = app.textFields["Postleitzahl"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("01219")
        tapPrimary()
    }

    private func pickFixtureBranchAndFinish() {
        let branch = app.buttons[fixtureBranch]
        XCTAssertTrue(branch.waitForExistence(timeout: 15), "fixture branch missing")
        branch.tap()
        app.buttons["markets.done"].tap()
    }

    /// The tab bar is a floating control on current iOS, so query it by button
    /// label rather than assuming a `tabBars` container exists. On iPad the
    /// same tab turns up more than once in the hierarchy — both are the real
    /// control, so take the first rather than failing on the ambiguity.
    private func openTab(_ name: String) {
        let inBar = app.tabBars.buttons[name]
        let tab = inBar.exists ? inBar : app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "tab \(name) missing")
        tab.tap()
    }

    private func completeOnboarding(name: String) {
        tapPrimary()                       // welcome
        let nameField = app.textFields["Vorname"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 15))
        nameField.tap()
        nameField.typeText(name)
        tapPrimary()                       // name
        enterPLZAndContinue()
        tapPrimary()                       // household
        tapPrimary()                       // diet
        tapPrimary()                       // consent
        pickFixtureBranchAndFinish()
    }
}
