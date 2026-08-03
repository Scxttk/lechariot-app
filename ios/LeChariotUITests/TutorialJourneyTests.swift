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

    private func launch(withTour: Bool, keepState: Bool = false, onboardingLost: Bool = false) {
        var arguments = ["-uiTesting"]
        if withTour { arguments.append("-uiTestingTutorial") }
        if keepState { arguments.append("-uiTestingKeepState") }
        if onboardingLost { arguments.append("-uiTestingOnboardingLost") }
        app.launchArguments = arguments
        app.launch()
    }

    // MARK: Scotts Meldung aus Build 2026.0801.1951

    /// **„Der Rundgang startet wieder automatisch los."**
    ///
    /// Der Assistent läuft ein zweites Mal — hier erzwungen mit
    /// `-uiTestingOnboardingLost`, das genau einen Merker abräumt und sonst
    /// nichts. Alles andere liegt unverändert da, **einschließlich** des
    /// „Rundgang gesehen"-Merkers.
    ///
    /// Bis zum 2026-08-02 bekam man in dieser Lage den Rundgang wieder
    /// vorgesetzt: `offersTour` gab `true` zurück, ohne den Merker je zu
    /// lesen, und `resume()` springt sofort auf diesen Schritt. Der Fall ist
    /// bewusst über den verlorenen Merker gestellt und nicht über eine
    /// vermutete Ursache — die Regel gilt für jede.
    func testASecondRunOfTheAssistantDoesNotOfferASeenTourAgain() {
        launch(withTour: true)
        completeOnboarding()
        XCTAssertTrue(app.staticTexts[tourTitle].waitForExistence(timeout: 15))
        app.buttons["onboarding.skip"].tap()          // gesehen: „Später" zählt
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))

        app.terminate()
        launch(withTour: true, keepState: true, onboardingLost: true)

        XCTAssertFalse(app.staticTexts[tourTitle].waitForExistence(timeout: 6),
                       "ein zweiter Lauf des Assistenten darf einen gesehenen Rundgang nicht wieder anbieten")
        XCTAssertFalse(tourCard.exists, "und erst recht nicht von allein starten")
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20),
                      "ohne Angebot ist der Assistent an dieser Stelle fertig — direkt in die Liste")
    }

    /// Die Gegenrichtung: Wer den Rundgang **nicht** gesehen hat, bekommt ihn
    /// im zweiten Lauf des Assistenten weiterhin angeboten. Ohne diesen Fall
    /// wäre der obige auch mit einem hart auf `false` verdrahteten Angebot grün.
    func testAnUnseenTourIsStillOfferedInASecondRun() {
        launch(withTour: true)
        completeOnboarding()
        XCTAssertTrue(app.staticTexts[tourTitle].waitForExistence(timeout: 15))
        // Kein Tipp auf „Los geht's" oder „Später": Die App wird mitten im
        // Angebot abgeschossen, der Merker bleibt also ungesetzt.
        app.terminate()

        launch(withTour: true, keepState: true, onboardingLost: true)
        XCTAssertTrue(app.staticTexts[tourTitle].waitForExistence(timeout: 20),
                      "ungesehen heißt: das Angebot steht weiter")
    }

    // MARK: Das Angebot am Ende des Onboardings

    func testTheTourIsOfferedAsTheLastOnboardingStep() {
        launch(withTour: true)
        completeOnboarding()

        XCTAssertTrue(app.staticTexts[tourTitle].waitForExistence(timeout: 15),
                      "nach der Einwilligung muss der Rundgang angeboten werden")
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
        // **`buttons`, nicht `staticTexts`** — und das ist keine Kosmetik.
        // Seit L-5a ist der Artikelname ein Knopf (er öffnet die Angaben), und
        // ein Knopf führt seinen Text nicht mehr als eigenes `staticText`. Die
        // Zeile stand hier als `staticTexts` und wurde beim Umbau **still
        // wahr**: Sie prüft eine Abwesenheit, und Abwesenheiten bekommt man
        // geschenkt, sobald das Element anders heißt. Aufgefallen ist es nur,
        // weil dieselbe Änderung sechs andere Zusicherungen umgeworfen hat.
        XCTAssertFalse(app.buttons["Butter"].exists,
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
        answerMarketQuestion("Nein")
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "danach steht der Nutzer wieder in der Liste")
    }

    /// „Tour beenden" gibt die App zurück — vollständig. Ein `exists` allein
    /// fiele auf eine liegengebliebene Sperrschicht herein, `isHittable` nicht.
    func testEndingTheTourGivesTheAppBack() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))
        app.buttons["tutorial.skip"].tap()
        answerMarketQuestion("Nein")

        let field = app.textFields["list.input"]
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
        answerMarketQuestion("Nein")
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        // Ebenfalls `buttons` — siehe oben, sonst prüft die Schleife nichts.
        for demo in ["Milch", "Butter", "Kaffee"] {
            XCTAssertFalse(app.buttons[demo].exists,
                           "\(demo) war nur geliehen und muss wieder von der Liste sein\n"
                           + app.debugDescription)
        }
    }

    /// **Der Befund, mit dem diese Runde angefangen hat.**
    ///
    /// Über einer Liste ohne Filialen hatten die Rahmen „plan" und „match"
    /// kein Ziel: Die Plan-Karte wurde gar nicht gebaut, und die Treffer-Zeile
    /// war ein grauer Satz ohne Anker. Beide überspringen sich dann über die
    /// Schonfrist von 1,2 s — rund sechs Sekunden Abdunklung über Bedienelemente,
    /// die nicht auf dem Bildschirm sind, zwischendurch zwei Karten übereinander.
    ///
    /// Gewartet wird hier **länger als die Schonfrist**, bevor gelesen wird:
    /// Ein Rahmen mit Ziel bleibt beliebig lange stehen, ein Rahmen ohne wäre
    /// nach 1,2 s weitergesprungen. Genau dieser Unterschied ist die Prüfung.
    func testTheFramesAboutOffersHaveATargetEvenWithoutBranches() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))

        next.tap()                                   // → details
        Thread.sleep(forTimeInterval: 0.5)
        next.tap()                                   // → chips
        Thread.sleep(forTimeInterval: 0.5)
        next.tap()                                   // → plan
        Thread.sleep(forTimeInterval: 2.5)           // über die Schonfrist hinaus
        XCTAssertTrue(
            app.staticTexts["tutorial.card"].label.contains("Ein Einkauf, ein Markt"),
            "Der Plan-Rahmen hat kein Ziel und hat sich übersprungen: "
            + app.staticTexts["tutorial.card"].label
        )

        next.tap()                                   // → match
        Thread.sleep(forTimeInterval: 2.5)
        XCTAssertTrue(
            app.staticTexts["tutorial.card"].label.contains("Das günstigste Angebot"),
            "Der Treffer-Rahmen hat kein Ziel und hat sich übersprungen: "
            + app.staticTexts["tutorial.card"].label
        )
    }

    /// **Der neue Rahmen bringt sein Ziel selbst mit** (03.08.).
    ///
    /// Er erklärt die Angaben-Schicht — die man ohne Hinweis nicht findet, weil
    /// sie nur nach dem Anlegen dasteht. Er darf deshalb nicht davon abhängen,
    /// dass der Tester im Rahmen davor wirklich getippt hat. Geprüft wie oben
    /// **über die Schonfrist hinaus**: Ein Rahmen ohne Ziel wäre nach 1,2 s
    /// weitergesprungen.
    func testTheDetailsFrameStandsEvenWhenNobodyTypedAnything() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))

        next.tap()                                   // → details
        Thread.sleep(forTimeInterval: 2.5)

        XCTAssertTrue(
            app.staticTexts["tutorial.card"].label.contains("Menge, Größe, Sorte"),
            "Der Angaben-Rahmen hat sich übersprungen: "
            + app.staticTexts["tutorial.card"].label
        )
        XCTAssertTrue(app.buttons["list.detailPanel.more"].exists,
                      "Die Schicht, die der Rahmen erklärt, steht gar nicht da")
    }

    // MARK: Die Frage am Ende

    /// **Der Ablauf, für den der ganze Umbau da ist** (Scotts Entscheidung vom
    /// 2026-07-31): Der Assistent endet in der Liste, der Rundgang zeigt sie,
    /// und erst am Ende steht die Filialauswahl — als Frage, nicht als Pflicht.
    func testTheQuestionAtTheEndLeadsToTheBranchPicker() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.staticTexts["Noch keine Filiale gewählt"].exists,
            "Der Rundgang läuft über einer Liste ohne Filialen — und die sagt das auch"
        )

        tapThrough()
        answerMarketQuestion("Ja")

        // Seit dem 2026-08-01 liegen die Filialen hinter der Kettenzeile.
        let chain = app.buttons["picker.chain.Lidl"]
        XCTAssertTrue(chain.waitForExistence(timeout: 15),
                      "„Ja“ muss in der Filialauswahl landen")
        chain.tap()
        let branch = app.buttons[fixtureBranch]
        XCTAssertTrue(branch.waitForExistence(timeout: 15))
        branch.tap()
        app.buttons["chain.done"].tap()
        app.buttons["markets.done"].tap()

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "und danach zurück in der Liste, von der man losgegangen ist")
        XCTAssertFalse(app.staticTexts["Noch keine Filiale gewählt"].exists,
                       "mit einer Filiale hat der Leerzustand nichts mehr zu melden")
    }

    /// „Nein" ist eine vollwertige Antwort: zurück in die Liste, ohne Umweg und
    /// ohne dass die Frage wiederkommt.
    func testAnsweringNoGoesBackToTheListAndStaysAnswered() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))
        tapThrough()
        answerMarketQuestion("Nein")

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.alerts["Märkte jetzt auswählen?"].exists,
                       "eine beantwortete Frage darf nicht wiederkommen")
        // Und der Weg bleibt offen — im Leerzustand der Liste, wo er hingehört.
        XCTAssertTrue(app.buttons["list.chooseMarkets"].exists,
                      "„Nein“ darf keine Sackgasse sein")
    }

    // MARK: Aus den Einstellungen

    /// **Die Bedingung, die bestehende Installationen schützt.** Wer den
    /// Rundgang aus den Einstellungen noch einmal ansieht, wird am Ende nicht
    /// nach Filialen gefragt — für ihn ändert sich durch den Umbau nichts.
    func testATourFromTheSettingsNeverAsksForMarkets() {
        launch(withTour: true)
        completeOnboarding()
        XCTAssertTrue(app.staticTexts[tourTitle].waitForExistence(timeout: 15))
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))

        openTab("Einstellungen")
        let restart = app.buttons["settings.tutorial"]
        XCTAssertTrue(restart.waitForExistence(timeout: 15))
        restart.tap()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))

        tapThrough()

        XCTAssertFalse(app.alerts["Märkte jetzt auswählen?"].waitForExistence(timeout: 5),
                       "aus den Einstellungen wird nicht gefragt")
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }

    /// **Der neue Vorschau-Rahmen — und der Tab-Wechsel, den er auslöst.**
    ///
    /// Zwei Dinge auf einmal, weil sie zusammengehören: Der Rahmen gibt es nur
    /// mit Filialen (ohne sie steht im Angebote-Tab kein Bildschirm), und sein
    /// Ziel ist die Navigationsleiste — die UIKit zeichnet und die deshalb
    /// keinen Anker trägt. Beides kann still schiefgehen: Ein Rahmen ohne
    /// aufgelöstes Ziel überspringt sich nach 1,2 s selbst, und niemand merkt
    /// es. Deshalb wird **über die Schonfrist hinaus** gewartet, bevor gelesen
    /// wird.
    func testThePreviewFrameStandsOnTheOffersTab() {
        app.launchArguments = ["-uiTesting", "-uiTestingTutorial", "-uiTestingOnboarded"]
        app.launch()

        openTab("Einstellungen")
        let restart = app.buttons["settings.tutorial"]
        XCTAssertTrue(restart.waitForExistence(timeout: 15))
        restart.tap()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))

        // input → details → chips → plan → match → check → tabs → nextWeek
        for _ in 0..<7 {
            next.tap()
            Thread.sleep(forTimeInterval: 0.9)
        }
        Thread.sleep(forTimeInterval: 2.5)

        XCTAssertTrue(
            app.staticTexts["tutorial.card"].label.contains("Was ab Montag billiger wird"),
            "Der Vorschau-Rahmen hat kein Ziel und hat sich übersprungen: "
            + app.staticTexts["tutorial.card"].label
        )
        XCTAssertTrue(app.buttons["offers.nextWeek"].exists,
                      "Der Rundgang steht nicht auf dem Angebote-Tab")
    }

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

    /// Bis einschließlich der Einwilligung — was danach kommt, ist der
    /// Prüfpunkt.
    ///
    /// **Die Filialauswahl steht seit dem 2026-07-31 nicht mehr dazwischen.**
    /// Der Assistent endet mit dem Angebot des Rundgangs und danach in der
    /// Liste; die Filialen kommen aus der Frage am Ende des Rundgangs.
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
    }

    /// Die Frage am Ende des Rundgangs. Sie steht auf jedem Weg aus einem
    /// Rundgang heraus, der aus dem Onboarding kam — „Fertig" wie
    /// „Tour beenden" —, und muss beantwortet werden, bevor die Liste wieder
    /// anfassbar ist.
    private func answerMarketQuestion(_ answer: String) {
        let question = app.alerts["Märkte jetzt auswählen?"]
        XCTAssertTrue(question.waitForExistence(timeout: 10),
                      "Nach dem Rundgang aus dem Onboarding muss nach Filialen gefragt werden")
        question.buttons[answer].tap()
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
