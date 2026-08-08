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
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
    }

    /// Die zweite Region bringt ihre eigenen Filialen mit — und die erste
    /// verschwindet dabei nicht.
    func testASecondRegionAddsItsOwnBranchesToThePicker() {
        waitForList()
        addRegion("17419")
        openBranchPicker()

        // Die Filiale der ersten Region ist gewählt und steht deshalb unter
        // „Deine Filialen" — seit dem 08.08. am Ende des Wählers statt oben;
        // die der zweiten liegt seit dem 2026-08-01 hinter ihrer Kettenzeile.
        XCTAssertTrue(
            app.buttons["Lidl, Dresden Reick"].waitForExistence(timeout: 15),
            "Die Filialen der ersten Region sind verschwunden"
        )
        openChain("Penny")
        XCTAssertTrue(
            // „Am Haff", nicht „Penny Am Haff": Die Überschrift nennt die Kette
            // schon, seit dem 2026-07-31 tut es die Zeile nicht mehr.
            app.buttons["Penny, Am Haff"].waitForExistence(timeout: 15),
            "Die Filialen der zweiten Region fehlen im Picker"
        )
    }

    /// **Sichtbar gekürzt, vorgelesen vollständig.**
    ///
    /// Die Zeile zeigt „Am Haff" — die Kette steht schon in der Überschrift.
    /// Das VoiceOver-Label trägt sie trotzdem weiter, denn beim Wandern von
    /// Zeile zu Zeile wird die Abschnittsüberschrift **nicht** mitgelesen; ohne
    /// die Kette bliebe „Am Haff" ohne Angabe, um wessen Filiale es geht.
    ///
    /// Steht hier als Test und nicht nur als Kommentar, weil genau diese
    /// Unterscheidung bei einem späteren Umbau als Dopplung gelesen und
    /// „aufgeräumt" wird.
    func testTheRowIsShortenedButVoiceOverStillNamesTheChain() {
        waitForList()
        addRegion("17419")
        openBranchPicker()

        openChain("Penny")
        let row = app.buttons["Penny, Am Haff"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.staticTexts["Am Haff"].exists,
            "Sichtbar soll nur der Ort stehen"
        )
        XCTAssertFalse(
            app.staticTexts["Penny Am Haff"].exists,
            "Der Kettenname darf in der Zeile nicht noch einmal auftauchen"
        )
    }

    /// Eine Region wird über einen sichtbaren Knopf gelöscht, nicht über eine
    /// Wischgeste, die im Fußtext erklärt werden muss. Genau daran ist der
    /// Tester gescheitert.
    func testARegionIsRemovedThroughAVisibleButtonAndTheBranchesStay() {
        waitForList()
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
        waitForList()
        app.tabBars.buttons["Einstellungen"].tap()
        openPlaces()

        let remove = app.buttons["Lidl Dresden Reick entfernen"]
        XCTAssertTrue(remove.waitForExistence(timeout: 15), "Kein Entfernen-Knopf an der Filiale")
        remove.tap()

        XCTAssertFalse(remove.waitForExistence(timeout: 3), "Die Filiale steht noch in der Liste")
    }

    // MARK: Helfer

    private func addRegion(_ plz: String) {
        app.tabBars.buttons["Einstellungen"].tap()
        openPlaces()
        let add = app.buttons["Region hinzufügen"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()

        let field = app.textFields["region.input"]
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
        openPlaces()
        let edit = app.buttons["Filialen bearbeiten"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        edit.tap()
        XCTAssertTrue(app.navigationBars["Filialen wählen"].waitForExistence(timeout: 15))
    }

    /// Öffnet „Filialen und Regionen" — seit dem 2026-08-01 liegen beide
    /// Listen eine Seite tiefer.
    ///
    /// Prüft zuerst, ob die Seite schon offen ist: `addRegion` landet dort und
    /// bleibt dort, und ein zweiter Tipp auf eine Zeile, die es gerade nicht
    /// gibt, wäre kein Befund über die App.
    private func openPlaces() {
        guard !app.navigationBars["Filialen und Regionen"].exists else { return }
        let row = app.buttons["settings.places"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Kein Weg zu den Filialen")
        row.tap()
    }

    /// Öffnet die Kettenseite — seit dem 2026-08-01 liegen die Filialen dort.
    private func openChain(_ chain: String) {
        let row = app.buttons["picker.chain.\(chain)"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Kettenzeile \(chain) fehlt")
        row.tap()
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
