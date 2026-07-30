import XCTest

/// Der Rundgang, durchgelaufen wie ein Tester ihn erlebt.
///
/// Er ist unter `-uiTesting` **aus** und wird hier mit `-uiTestingTutorial`
/// eingeschaltet. Das ist kein Testtrick, sondern die Bedingung dafür, dass die
/// fünf übrigen Journey-Suiten unverändert bleiben: Der Rundgang legt sich
/// modal über die Liste und nimmt der Barrierefreiheits-Hierarchie alles
/// darunter — sie würden reihenweise an einem Bildschirm hängenbleiben, an dem
/// nichts kaputt ist.
final class TutorialJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    private let fixtureBranch = "Lidl, Dresden Reick"
    private let tourTitle = "Alles bereit. Einmal kurz zeigen?"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(withTour: Bool, keepState: Bool = false) {
        var arguments = ["-uiTesting"]
        if withTour { arguments.append("-uiTestingTutorial") }
        if keepState { arguments.append("-uiTestingKeepState") }
        app.launchArguments = arguments
        app.launch()
    }

    // MARK: Das Angebot am Ende des Onboardings

    func testTheTourIsOfferedAsTheLastOnboardingStep() {
        launch(withTour: true)
        completeOnboarding()

        XCTAssertTrue(app.staticTexts[tourTitle].waitForExistence(timeout: 15),
                      "nach den Filialen muss der Rundgang angeboten werden")
        XCTAssertFalse(app.navigationBars["Einkaufsliste"].exists,
                       "das Angebot kommt vor der App, nicht über ihr")
    }

    /// „Später" ist kein Umweg: Es führt direkt in die Liste, und der Rundgang
    /// wird nicht noch einmal angeboten.
    func testLaterGoesStraightToTheListAndIsNotAskedAgain() {
        launch(withTour: true)
        completeOnboarding()
        XCTAssertTrue(app.staticTexts[tourTitle].waitForExistence(timeout: 15))
        app.buttons["onboarding.skip"].tap()

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        XCTAssertFalse(tourCard.waitForExistence(timeout: 3),
                       "abgelehnt heißt abgelehnt")

        app.terminate()
        launch(withTour: true, keepState: true)
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        XCTAssertFalse(tourCard.waitForExistence(timeout: 3))
    }

    // MARK: Der Rundgang

    /// Der eigentliche Zweck: Alles außer dem hervorgehobenen Bedienelement ist
    /// weg — nicht nur ausgegraut, sondern für Berührung und VoiceOver nicht da.
    /// Diese Behauptung ist der Grund, warum die anderen Suiten gekapselt sind;
    /// verschwindet sie, muss dieser Test rot werden.
    func testTheTourCoversTheAppCompletelyWhileItRuns() {
        startTour()

        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))

        // Das „Mehr"-Menü existiert nicht — es wird während des Rundgangs gar
        // nicht gebaut. Der eine Knopf der Navigationsleiste, der wirklich
        // Schaden anrichten könnte („Liste leeren"), ist damit weg statt nur
        // verdeckt.
        XCTAssertFalse(app.buttons["Mehr"].exists,
                       "Liste leeren darf während der Führung nicht erreichbar sein")

        // Alles andere ist **unerreichbar, nicht unsichtbar**: Die Sperrflächen
        // liegen darüber, `isHittable` ist damit falsch. Bewusst nicht auf
        // `exists` geprüft — die Elementhierarchie von XCUITest führt sie
        // weiter auf, und ein Test, der das Gegenteil behauptet, prüft eine
        // Eigenschaft, die dieses Werkzeug nicht misst.
        // Alles Weitere als **Verhalten** geprüft, nicht als Eigenschaft:
        // Weder `exists` noch `isHittable` messen, was hier behauptet wird.
        // Die Elementhierarchie führt die Bedienelemente weiter auf, und
        // `isHittable` kennt die Sperrflächen nicht — die sind vor der
        // Barrierefreiheit versteckt, genau wie es sein soll. Was zählt, ist
        // ob ein Tipp etwas bewirkt.
        let firstFrame = app.staticTexts["tutorial.card"].label

        // Eine Vorschlagskachel außerhalb des Lochs.
        app.buttons["Butter hinzufügen"].firstMatch.tap()
        XCTAssertFalse(app.staticTexts["Butter"].exists,
                       "ein Tipp außerhalb des Lochs darf nichts auf die Liste legen")

        // Die Tab-Leiste — der eine Fluchtweg, den keine Ansicht darüber
        // schließt, weil UIKit sie über dem Overlay zeichnet.
        app.buttons["Angebote"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].exists,
                      "die Tab-Leiste darf während der Führung nicht wechseln")

        XCTAssertTrue(tourCard.exists, "und der Rundgang muss stehen geblieben sein")
        XCTAssertEqual(app.staticTexts["tutorial.card"].label, firstFrame,
                       "kein Tipp von außen darf den Rahmen weiterschalten")
    }

    func testEveryFrameIsReachableAndTheTourEnds() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))

        tapThrough()

        XCTAssertFalse(tourCard.exists, "der Rundgang muss von allein zum Ende kommen")
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "danach steht der Nutzer wieder in der Liste")
    }

    /// „Tour beenden" gibt die App zurück — vollständig. Ein `exists` allein
    /// fiele auf eine liegengebliebene Sperrschicht herein, `isHittable` nicht.
    func testEndingTheTourGivesTheAppBack() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))
        app.buttons["tutorial.skip"].tap()

        let field = app.textFields["Artikel hinzufügen …"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertTrue(field.isHittable, "über der Liste darf keine Sperrschicht zurückbleiben")
    }

    /// Auf dem letzten Rahmen steht nur noch „Fertig". Vorher standen dort zwei
    /// Knöpfe nebeneinander, die dasselbe taten — gemeldet am 2026-07-30.
    func testTheLastFrameOffersOnlyOneWayOut() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["tutorial.skip"].exists, "auf dem ersten Rahmen ist er eine Wahl")

        // Bis zum letzten Rahmen blättern, ohne ihn zu verlassen.
        var taps = 0
        while app.buttons["tutorial.skip"].exists && tourCard.exists && taps < 12 {
            next.tap()
            taps += 1
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTAssertTrue(tourCard.exists, "der Rundgang muss noch laufen")
        XCTAssertFalse(app.buttons["tutorial.skip"].exists,
                       "Abbruch und Fertig tun hier dasselbe, einer davon gehört weg")
        XCTAssertTrue(next.exists)
    }

    /// Die Beispiel-Artikel sind geliehen. Nach dem Rundgang ist die Liste
    /// wieder so leer, wie der Tester sie hinterlassen hat.
    func testTheDemoItemsAreTidiedAwayAfterwards() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))
        tapThrough()

        XCTAssertFalse(tourCard.exists, "der Rundgang muss zu Ende sein, bevor gezählt wird")
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        for demo in ["Milch", "Butter", "Kaffee"] {
            XCTAssertFalse(app.staticTexts[demo].exists,
                           "\(demo) war nur geliehen und muss wieder von der Liste sein\n"
                           + app.debugDescription)
        }
    }

    // MARK: Aus den Einstellungen

    func testTheTourCanBeStartedAgainFromTheSettings() {
        launch(withTour: true)
        completeOnboarding()
        XCTAssertTrue(app.staticTexts[tourTitle].waitForExistence(timeout: 15))
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))

        openTab("Einstellungen")
        let restart = app.buttons["settings.tutorial"]
        XCTAssertTrue(restart.waitForExistence(timeout: 15))
        restart.tap()

        Thread.sleep(forTimeInterval: 3)
        print("HIERARCHY-START\n\(app.debugDescription)\nHIERARCHY-END")
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))
        app.buttons["tutorial.skip"].tap()
        // Der Rundgang spielt auf der Liste, also muss er den Tab mitnehmen —
        // sonst zeigte das erste Loch auf ein Feld auf einem anderen Bildschirm.
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }

    // MARK: Die Kapselung selbst

    /// Ohne `-uiTestingTutorial` gibt es weder Angebot noch Rundgang. Genau
    /// darauf verlassen sich die fünf übrigen Suiten.
    func testWithoutTheFlagOnboardingEndsInTheListAsBefore() {
        launch(withTour: false)
        completeOnboarding()

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts[tourTitle].exists)
        XCTAssertFalse(tourCard.exists)
    }

    // MARK: Helpers

    private var tourCard: XCUIElement { app.buttons["tutorial.next"] }
    private var next: XCUIElement { app.buttons["tutorial.next"] }
    private var primary: XCUIElement { app.buttons["onboarding.primary"] }

    /// Tippt sich bis ans Ende durch — mit einer Atempause je Rahmen.
    ///
    /// Ohne die Pause tippt XCUITest schneller, als der letzte Rahmen
    /// verschwindet: Der Tipp, der die Tour beendet, landet dann noch einmal
    /// auf dem Bildschirm darunter — und ausgerechnet dort, wo nach dem
    /// Aufräumen wieder eine Vorschlagskachel liegt. Ergebnis war ein
    /// „Beispiel-Artikel", den gar nicht der Rundgang gesetzt hatte.
    ///
    /// Gedeckelt: Ein Rahmen, dessen Ziel nie erscheint, überspringt sich
    /// selbst. Bliebe er stehen, liefe die Schleife hier gegen die Grenze.
    private func tapThrough(maxFrames: Int = 12) {
        var taps = 0
        while tourCard.exists && taps < maxFrames {
            next.tap()
            taps += 1
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    private func startTour() {
        launch(withTour: true)
        completeOnboarding()
        XCTAssertTrue(app.staticTexts[tourTitle].waitForExistence(timeout: 15))
        primary.tap()          // „Los geht's"
    }

    private func tapPrimary() {
        XCTAssertTrue(primary.waitForExistence(timeout: 15))
        primary.tap()
    }

    private func tapSkip() {
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15))
        skip.tap()
    }

    /// Bis einschließlich der Filialwahl — was danach kommt, ist der Prüfpunkt.
    private func completeOnboarding() {
        tapPrimary()               // Willkommen
        tapSkip()                  // „Ohne Namen weiter"
        let plz = app.textFields["Postleitzahl"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15))
        plz.tap()
        plz.typeText("01219")
        tapPrimary()
        tapSkip()                  // Haushalt
        tapSkip()                  // Ernährung
        tapPrimary()               // Einwilligung
        let branch = app.buttons[fixtureBranch]
        XCTAssertTrue(branch.waitForExistence(timeout: 15), "fixture branch missing")
        branch.tap()
        app.buttons["markets.done"].tap()
    }

    /// Die Tab-Leiste ist auf aktuellem iOS ein schwebendes Steuerelement —
    /// über die Beschriftung suchen, nicht über einen `tabBars`-Container.
    private func openTab(_ name: String) {
        let inBar = app.tabBars.buttons[name]
        let tab = inBar.exists ? inBar : app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "tab \(name) missing")
        tab.tap()
    }
}
