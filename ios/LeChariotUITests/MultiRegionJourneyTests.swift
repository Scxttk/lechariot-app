import XCTest

/// Zwei Regionen, weit auseinander — der Fall aus dem Fehlerbericht vom
/// 2026-07-30.
///
/// Die Regionen sind für PLZ-Grenzen gebaut, und mit Nachbar-PLZ fällt nichts
/// davon auf. Ein Tester hat sie für zwei Wohnorte 450 km auseinander benutzt,
/// und dabei brach dreierlei: Entfernungen ohne gemeinsamen Bezugspunkt, ein
/// Verzeichnis, das für die zweite Region nie nachgeladen wurde, und ein
/// Löschen, das niemand fand.
///
/// Die Fixtures liegen um 04626 und 17419; ein Lauf mit nur 01219 sieht sie
/// nicht, deshalb ändern die bestehenden Journeys sich nicht.
final class MultiRegionJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    /// Die zweite Region bringt ihre eigenen Filialen mit — und die erste
    /// verschwindet dabei nicht.
    func testASecondRegionAddsItsOwnBranchesToThePicker() {
        completeOnboarding()
        addRegion("17419")
        openBranchPicker()

        XCTAssertTrue(
            app.buttons["Penny, Penny Am Haff"].waitForExistence(timeout: 15),
            "Die Filialen der zweiten Region fehlen im Picker"
        )
        XCTAssertTrue(
            app.buttons["Lidl, Dresden Reick"].exists,
            "Die Filialen der ersten Region sind verschwunden"
        )
    }

    /// Eine Region wird über einen sichtbaren Knopf gelöscht, nicht über eine
    /// Wischgeste, die im Fußtext erklärt werden muss. Genau daran ist der
    /// Tester gescheitert.
    func testARegionIsRemovedThroughAVisibleButtonAndTheBranchesStay() {
        completeOnboarding()
        addRegion("17419")

        let remove = app.buttons["PLZ 17419 entfernen"]
        XCTAssertTrue(remove.waitForExistence(timeout: 15), "Kein sichtbarer Entfernen-Knopf")
        remove.tap()

        // Der Dialog sagt, was *nicht* passiert — die gewählten Filialen
        // bleiben stehen, weil die App eine vergessene nicht von einer bewusst
        // über die Grenze gewählten unterscheiden kann.
        XCTAssertTrue(
            app.staticTexts["PLZ 17419 entfernen?"].waitForExistence(timeout: 5),
            "Kein Hinweis darauf, was das Entfernen anrichtet"
        )
        app.buttons["Entfernen"].tap()

        XCTAssertFalse(remove.waitForExistence(timeout: 3), "Die Region steht noch da")
        XCTAssertTrue(
            app.buttons["Lidl Dresden Reick entfernen"].exists,
            "Die gewählte Filiale ist mit der Region verschwunden"
        )
    }

    /// Bis hierher gab es überhaupt keinen Weg, eine Filiale wieder
    /// loszuwerden — nur zurück in den Picker und dort abwählen. Wer nach einem
    /// Umzug eine falsch gewordene Filiale stehen hat, sucht sie aber hier.
    func testABranchIsRemovedInTheSettings() {
        completeOnboarding()
        app.tabBars.buttons["Einstellungen"].tap()

        let remove = app.buttons["Lidl Dresden Reick entfernen"]
        XCTAssertTrue(remove.waitForExistence(timeout: 15), "Kein Entfernen-Knopf an der Filiale")
        remove.tap()

        XCTAssertFalse(remove.waitForExistence(timeout: 3), "Die Filiale steht noch in der Liste")
    }

    // MARK: Helfer

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

    private func addRegion(_ plz: String) {
        app.tabBars.buttons["Einstellungen"].tap()
        let add = app.buttons["Region hinzufügen"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()

        let field = app.textFields["Postleitzahl"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText(plz)
        app.buttons["Weiter"].tap()

        XCTAssertTrue(
            app.staticTexts["PLZ \(plz)"].waitForExistence(timeout: 15),
            "Die Region wurde nicht übernommen"
        )
    }

    private func openBranchPicker() {
        let edit = app.buttons["Filialen bearbeiten"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        edit.tap()
        XCTAssertTrue(app.navigationBars["Filialen wählen"].waitForExistence(timeout: 15))
    }
}
