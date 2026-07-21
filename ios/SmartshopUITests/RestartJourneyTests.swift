import XCTest

/// Was einen App-Neustart überleben muss.
///
/// Die übrigen Journeys starten absichtlich immer frisch, damit sie
/// unabhängig voneinander sind — genau deshalb konnte keine von ihnen prüfen,
/// was nach einem Kill noch da ist. Diese hier startet die App ein zweites Mal
/// mit `-uiTestingKeepState` und schaut nach.
final class RestartJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Der Punkt aus dem Laufplan: Onboarding durchlaufen, App killen, sie muss
    /// in der Einkaufsliste aufmachen und das Profil noch haben.
    func testAfterAKillTheAppOpensOnTheListWithTheProfileIntact() {
        app.launchArguments = ["-uiTesting"]
        app.launch()
        completeOnboarding(name: "Scott")
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))

        app.terminate()

        app.launchArguments = ["-uiTesting", "-uiTestingKeepState"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20),
                      "nach dem Kill muss die App in der Liste aufmachen, nicht im Onboarding")
        XCTAssertFalse(app.buttons["onboarding.primary"].exists,
                       "kein Rückfall ins Onboarding")
        XCTAssertTrue(app.staticTexts["Was brauchst du, Scott?"].waitForExistence(timeout: 10),
                      "der Vorname muss den Neustart überleben — er liegt nur lokal")
    }

    /// Dasselbe im dunklen Erscheinungsbild: die Wahl selbst muss den Neustart
    /// ebenfalls überleben, sonst steht der Nutzer nach jedem Start wieder hell da.
    func testTheAppearanceChoiceSurvivesAKill() {
        app.launchArguments = ["-uiTesting"]
        app.launch()
        completeOnboarding(name: "Scott")

        openTab("Einstellungen")
        let dark = app.segmentedControls.buttons["Dunkel"].firstMatch
        var swipes = 0
        while !dark.exists && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(dark.waitForExistence(timeout: 10))
        dark.tap()
        // Segmente melden ihren Zustand über `isSelected`, nicht über `value` —
        // ein Schalter täte das, ein Segment nicht.
        XCTAssertTrue(dark.isSelected, "Dunkel muss nach dem Tippen gewählt sein")

        app.terminate()

        app.launchArguments = ["-uiTesting", "-uiTestingKeepState"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20))

        openTab("Einstellungen")
        let darkAgain = app.segmentedControls.buttons["Dunkel"].firstMatch
        swipes = 0
        while !darkAgain.exists && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(darkAgain.waitForExistence(timeout: 10))
        XCTAssertTrue(darkAgain.isSelected, "Dunkel muss nach dem Neustart noch gewählt sein")
    }

    // MARK: Helfer

    private func openTab(_ name: String) {
        let inBar = app.tabBars.buttons[name]
        let tab = inBar.exists ? inBar : app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Tab \(name) fehlt")
        tab.tap()
    }

    private func completeOnboarding(name: String) {
        XCTAssertTrue(app.buttons["onboarding.primary"].waitForExistence(timeout: 20))
        app.buttons["onboarding.primary"].tap()
        let nameField = app.textFields["Vorname"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 15))
        nameField.tap()
        nameField.typeText(name)
        app.buttons["onboarding.primary"].tap()
        let plz = app.textFields["Postleitzahl"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15))
        plz.tap()
        plz.typeText("01219")
        app.buttons["onboarding.primary"].tap()
        app.buttons["onboarding.skip"].tap()
        app.buttons["onboarding.skip"].tap()
        app.buttons["onboarding.primary"].tap()
        let branch = app.buttons["Lidl, Dresden Reick"]
        XCTAssertTrue(branch.waitForExistence(timeout: 20))
        branch.tap()
        app.buttons["markets.done"].tap()
    }
}
