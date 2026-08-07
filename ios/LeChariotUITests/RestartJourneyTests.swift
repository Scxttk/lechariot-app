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
        // Hinter dem Assistenten: Was hier geprüft wird, ist die Darstellung,
        // nicht der Weg dorthin.
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20))

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

        app.launchArguments = ["-uiTesting", "-uiTestingKeepState", "-uiTestingOnboarded"]
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
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")
        let nameField = app.textFields["Vorname"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 15))
        nameField.tap()
        nameField.typeText(name)
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")
        let plz = app.textFields["region.input"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15))
        plz.tap()
        plz.typeText("01219")
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")
        // **Warten, bis der Ort-Schritt wirklich weg ist.** Die Ortssuche ist
        // asynchron; ohne diese Zeile liefen die drei Tipps danach an ihr
        // vorbei, der Assistent stand am Ende einen Bildschirm zu früh, und
        // der Fehler zeigte sich als „die Liste kommt nicht" — eine Zeile
        // weiter oben, in einer anderen Frage. Dieselbe Ursache wie in
        // `AccessibilityAuditTests.enterPLZ`.
        let weg = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: plz
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [weg], timeout: 15), .completed,
            "Der Ort-Schritt steht noch: die Suche ist nicht durch"
        )
        app.tippe(app.buttons["onboarding.skip"], "Überspringen im Assistenten")      // Ketten: „Später"
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")   // Belohnung
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")   // Einwilligung
    }
}
