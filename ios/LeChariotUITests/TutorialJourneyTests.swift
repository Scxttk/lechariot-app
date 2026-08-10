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
        app.tippe(app.buttons["onboarding.skip"], "Überspringen im Assistenten")          // gesehen: „Später" zählt
        answerMarketPrompt(choose: false)             // und auch das Markt-Sheet zählt
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
        // Seit dem 2026-08-05 mit **eigenem** Fortschrittspunkt: Vorher
        // teilten sich Einwilligung und Angebot den sechsten, und die Leiste
        // behauptete einen Bildschirm weniger, als der Weg hatte.
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", "Schritt 7 von 7"))
                .firstMatch.exists,
            "das Rundgang-Angebot trägt seinen eigenen, letzten Punkt"
        )
    }

    /// **„Später" führt seit dem 05.08. zur Markt-Frage** — vorher sahen
    /// Überspringer sie nie: Sie hing nur am Ende des Rundgangs, und den
    /// hatten sie gerade abgelehnt. Das Sheet kommt einmal, ist wegwischbar,
    /// und danach steht die Liste da; der Rundgang wird nicht noch einmal
    /// angeboten, das Sheet auch nicht.
    func testLaterShowsTheMarketSheetOnceAndThenTheList() {
        launch(withTour: true)
        completeOnboarding()
        XCTAssertTrue(app.staticTexts[tourTitle].waitForExistence(timeout: 15))
        app.tippe(app.buttons["onboarding.skip"], "Überspringen im Assistenten")

        answerMarketPrompt(choose: false)
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        XCTAssertFalse(tourCard.waitForExistence(timeout: 3),
                       "abgelehnt heißt abgelehnt")

        app.terminate()
        launch(withTour: true, keepState: true)
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        XCTAssertFalse(tourCard.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["marketPrompt.title"].waitForExistence(timeout: 3),
                       "einmal beantwortet — das Sheet darf den Neustart nicht überleben")
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

    /// Jeder Rahmen ist erreichbar, und zwar auf dem Weg, den er ansagt: Wer
    /// tut, worum die Karte bittet, kommt bis zum Ende durch.
    func testEveryFrameIsReachableAndTheTourEnds() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))

        tapThrough()

        XCTAssertFalse(tourCard.exists,
                       "wer jede Handlung tut, muss am Ende ankommen")
        answerMarketPrompt(choose: false)
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "danach steht der Nutzer wieder in der Liste")
    }

    /// „Tour beenden" gibt die App zurück — vollständig. Ein `exists` allein
    /// fiele auf eine liegengebliebene Sperrschicht herein, `isHittable` nicht.
    func testEndingTheTourGivesTheAppBack() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))
        app.buttons["tutorial.skip"].tap()
        answerMarketPrompt(choose: false)

        let field = app.textFields["list.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertTrue(field.isHittable, "über der Liste darf keine Sperrschicht zurückbleiben")
    }

    /// Auf dem letzten Rahmen steht nur noch „Fertig". Vorher standen dort zwei
    /// Knöpfe nebeneinander, die dasselbe taten — gemeldet am 2026-07-30.
    ///
    /// **Und davor steht gar kein Primärknopf mehr** (09.08.): Ein Rahmen, der
    /// auf eine Handlung wartet, darf keinen Knopf haben, der sie überspringt.
    func testTheLastFrameOffersOnlyOneWayOut() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["tutorial.skip"].exists, "auf dem ersten Rahmen ist er eine Wahl")
        XCTAssertFalse(next.exists,
                       "solange ein Rahmen auf eine Handlung wartet, gibt es kein „Weiter“")

        // Bis zum letzten Rahmen mitmachen, ohne ihn zu verlassen.
        var handlungen = 0
        while app.buttons["tutorial.skip"].exists && card.exists && handlungen < 9 {
            app.doTheTourDeed()
            handlungen += 1
        }

        XCTAssertTrue(card.exists, "der Rundgang muss noch laufen")
        XCTAssertFalse(app.buttons["tutorial.skip"].exists,
                       "Abbruch und Fertig tun hier dasselbe, einer davon gehört weg")
        XCTAssertTrue(next.exists, "und die Schlusskarte hat ihren einen Knopf")
    }

    /// **Der Rundgang leiht sich seit dem 09.08. nichts mehr.**
    ///
    /// Bis dahin legte er Milch, Butter und Kaffee selbst auf die Liste, weil
    /// der Plan-Rahmen sonst auf einen Leerzustand gezeigt hätte, und räumte sie
    /// am Ende wieder ab. Jetzt schreibt der Nutzer im ersten Rahmen seinen
    /// eigenen Artikel — der bleibt stehen, denn er gehört ihm.
    func testTheTourBorrowsNothingAndKeepsWhatTheUserWrote() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))
        tapThrough()

        XCTAssertFalse(tourCard.exists, "der Rundgang muss zu Ende sein, bevor gezählt wird")
        answerMarketPrompt(choose: false)
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))

        for geliehen in ["Milch", "Butter", "Kaffee"] {
            XCTAssertFalse(app.buttons[geliehen].exists,
                           "\(geliehen) hat der Rundgang gar nicht mehr zu legen\n"
                           + app.debugDescription)
        }
        XCTAssertTrue(app.buttons["Zahnstocher"].exists,
                      "was der Nutzer im ersten Rahmen selbst geschrieben hat, bleibt")
    }

    // MARK: Die Frage am Ende

    /// **Der Ablauf, für den der ganze Umbau da ist** (Scotts Entscheidung vom
    /// 2026-07-31, seit dem 05.08. als gestaltetes Sheet statt als
    /// System-Alert): Der Assistent endet in der Liste, der Rundgang zeigt
    /// sie, und erst am Ende steht die Filialauswahl — als Angebot, nicht als
    /// Pflicht. „Märkte wählen" führt in die Filialauswahl **im selben
    /// Sheet**; erst schließen und dann neu öffnen wäre der Zwei-Sheets-Tanz,
    /// der in SwiftUI regelmäßig den zweiten verliert.
    func testTheMarketSheetAtTheEndLeadsToTheBranchPicker() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.staticTexts["Noch keine Filiale gewählt"].exists,
            "Der Rundgang läuft über einer Liste ohne Filialen — und die sagt das auch"
        )

        tapThrough()
        answerMarketPrompt(choose: true)

        // Seit dem 2026-08-01 liegen die Filialen hinter der Kettenzeile.
        let chain = app.buttons["picker.chain.Lidl"]
        XCTAssertTrue(chain.waitForExistence(timeout: 15),
                      "„Märkte wählen“ muss in der Filialauswahl landen")
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

    /// „Später" ist eine vollwertige Antwort: zurück in die Liste, ohne Umweg
    /// und ohne dass das Sheet wiederkommt.
    func testLaterGoesBackToTheListAndStaysAnswered() {
        startTour()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))
        tapThrough()
        answerMarketPrompt(choose: false)

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["marketPrompt.title"].exists,
                       "eine beantwortete Frage darf nicht wiederkommen")
        // **Und der Weg bleibt offen — auf der Liste, wo er hingehört.**
        //
        // Welche der beiden Flächen ihn trägt, hängt seit dem 09.08. davon ab,
        // was der Nutzer im Rundgang getan hat: Wer selbst einen Artikel
        // angelegt hat (Rahmen 1), hat damit den ersten Punkt der
        // Einrichtungs-Checkliste erledigt — und die löst die Filialen-Karte
        // ab (`ListGuidance.surface`). Beide führen zur Filialauswahl; die
        // Zusicherung gilt dem **Weg**, nicht der Fläche.
        let karte = app.buttons["list.chooseMarkets"]
        let checkliste = app.buttons["list.checklist.markets"]
        XCTAssertTrue(karte.exists || checkliste.exists,
                      "„Später“ darf keine Sackgasse sein:\n" + app.debugDescription)
    }

    // MARK: Aus den Einstellungen

    /// **Die Bedingung, die bestehende Installationen schützt.** Wer den
    /// Rundgang aus den Einstellungen noch einmal ansieht, wird am Ende nicht
    /// nach Filialen gefragt — für ihn ändert sich durch den Umbau nichts.
    ///
    /// Seit dem 05.08. schützen hier zwei Regeln zugleich: der Ursprung
    /// (Einstellungen fragen nie) und der Einmal-Merker (das „Später" nach dem
    /// Angebot hat die Frage schon verbraucht). Die Journey prüft das
    /// Zusammenspiel Ende-zu-Ende; die Ursprungs-Regel allein steht präzise in
    /// `TutorialStoreTests.testATourFromTheSettingsNeverAsks`.
    func testATourFromTheSettingsNeverAsksForMarkets() {
        launch(withTour: true)
        completeOnboarding()
        XCTAssertTrue(app.staticTexts[tourTitle].waitForExistence(timeout: 15))
        app.tippe(app.buttons["onboarding.skip"], "Überspringen im Assistenten")
        answerMarketPrompt(choose: false)
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))

        openTab("Einstellungen")
        let restart = app.scrollToTutorialButton()
        restart.tap()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))

        tapThrough()

        XCTAssertFalse(app.staticTexts["marketPrompt.title"].waitForExistence(timeout: 5),
                       "aus den Einstellungen wird nicht gefragt")
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }

    /// **Von allein wechselt der Rundgang den Tab nicht.**
    ///
    /// Bis zum 06.08. tat er es zweimal, und das war Scotts „visuell desaströs"
    /// vom 03.08.: Eine `TabView` blendet ihren Inhalt nicht über, sie tauscht
    /// ihn aus. Danach blieb er auf der Liste. **Seit dem 09.08. verlässt er sie
    /// wieder — aber nur, weil der Nutzer selbst unten auf „Angebote" tippt**,
    /// und der Rahmen, der darum bittet, steht noch auf der Liste.
    ///
    /// Diese Journey prüft die eine Hälfte, die dabei gleich bleiben muss: Bis
    /// zu diesem Tipp steht die Einkaufsliste, auch über die Schonfrist hinaus.
    func testTheTourStaysOnTheListUntilTheUserTapsTheTabBar() {
        app.launchArguments = ["-uiTesting", "-uiTestingTutorial", "-uiTestingOnboarded"]
        app.launch()

        openTab("Einstellungen")
        let restart = app.scrollToTutorialButton()
        restart.tap()
        XCTAssertTrue(tourCard.waitForExistence(timeout: 15))

        // `-uiTestingOnboarded` setzt eine Filiale, der Rundgang läuft also in
        // der langen Fassung. Bis zu dem Rahmen mitmachen, der um den Tipp auf
        // die Tab-Leiste bittet — und vor jedem Schritt messen, wo wir stehen.
        // **Gemessen am Angebote-Bildschirm, nicht an der Einkaufsliste.** Die
        // Titelleiste der Liste tritt beim Tippen ab (08.08., Punkt C) — auf
        // ihre Abwesenheit zu prüfen hieße, den Tipp-Fluss zu messen und nicht
        // den Tab.
        var erreicht = false
        for _ in 0..<5 {
            XCTAssertFalse(app.navigationBars["Angebote"].exists,
                           "Der Rundgang hat den Tab von allein gewechselt: " + tourCard.label)
            if tourCard.label.contains("Alle Angebote deiner Filialen") {
                erreicht = true
                break
            }
            app.doTheTourDeed()
        }
        XCTAssertTrue(erreicht, "Der Angebote-Rahmen kam nie: " + tourCard.label)

        Thread.sleep(forTimeInterval: 2.5)   // über die Schonfrist hinaus
        XCTAssertFalse(app.navigationBars["Angebote"].exists,
                       "auch nach der Schonfrist steht die Liste: " + tourCard.label)

        // Und der Tipp bringt ihn dann wirklich hinüber.
        app.doTheTourDeed()
        XCTAssertTrue(app.navigationBars["Angebote"].waitForExistence(timeout: 15),
                      "der eigene Tipp muss den Tab wechseln: " + tourCard.label)
    }

    func testTheTourCanBeStartedAgainFromTheSettings() {
        launch(withTour: true)
        completeOnboarding()
        XCTAssertTrue(app.staticTexts[tourTitle].waitForExistence(timeout: 15))
        app.tippe(app.buttons["onboarding.skip"], "Überspringen im Assistenten")
        // „Später" ohne Filialen führt seit dem 05.08. ins Markt-Sheet — es
        // liegt über der Tab-Leiste, und ohne Antwort käme dieser Test gar
        // nicht erst in die Einstellungen.
        answerMarketPrompt(choose: false)
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))

        openTab("Einstellungen")
        let restart = app.scrollToTutorialButton()
        restart.tap()

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

    /// **Die Karte, nicht ihr Knopf** (09.08.). Hier stand
    /// `buttons["tutorial.next"]` — solange jeder Rahmen ein „Weiter" trug, war
    /// das dasselbe. Seit der Knopf nur noch auf der Schlusskarte steht, hieße
    /// „der Rundgang läuft" plötzlich „der Rundgang ist am Ende".
    private var tourCard: XCUIElement { app.staticTexts["tutorial.card"] }
    private var card: XCUIElement { tourCard }
    private var next: XCUIElement { app.buttons["tutorial.next"] }
    private var primary: XCUIElement { app.buttons["onboarding.primary"] }

    /// Macht den Rundgang mit, Handlung für Handlung — siehe
    /// `XCUIApplication.walkTheWholeTour`. Bis zum 09.08. stand hier eine
    /// Schleife über „Weiter"; den Knopf gibt es nicht mehr.
    private func tapThrough() {
        app.walkTheWholeTour()
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
        let plz = app.textFields["region.input"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15))
        plz.tap()
        plz.typeText("01219")
        tapPrimary()
        tapSkip()                  // Ketten: „Später"
        tapPrimary()               // Belohnung
        tapPrimary()               // Einwilligung
    }

    /// Das Markt-Sheet nach dem Onboarding. Es steht auf jedem Weg ohne
    /// Filialen — nach dem Rundgang („Fertig" wie „Tour beenden") und nach
    /// dem abgelehnten Angebot — und muss beantwortet werden, bevor die Liste
    /// wieder anfassbar ist. Seit dem 05.08. ein gestaltetes Sheet, kein
    /// System-Alert mehr.
    private func answerMarketPrompt(choose: Bool) {
        let title = app.staticTexts["marketPrompt.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10),
                      "Ohne Filialen muss das Markt-Sheet stehen")
        app.buttons[choose ? "marketPrompt.choose" : "marketPrompt.later"].tap()
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

/// **Der Weg zum Rundgang-Knopf, seit „Hilfe" unten steht** (06.08.).
///
/// Bis dahin war „Hilfe" der zweite Abschnitt der Einstellungen, und der Knopf
/// stand ohne Scrollen da. Er stand dort aber nicht aus Überzeugung: Der letzte
/// Rahmen des Rundgangs zeigte auf die Filialzeile **und** die Hilfezeile
/// gleichzeitig, also mussten beide zusammen sichtbar sein. Seit der Rundgang
/// drei Rahmen hat und die Einstellungen gar nicht mehr zeigt, ist die Fessel
/// weg — und „Hilfe" liegt da, wo man sie sucht, wenn etwas hakt.
///
/// **Eine `List` baut nur, was zu sehen ist.** Erst scrollen, dann fragen;
/// dieselbe Falle, die in dieser Suite schon zweimal zugeschlagen hat.
extension XCUIApplication {
    func scrollToTutorialButton(_ file: StaticString = #filePath, _ line: UInt = #line) -> XCUIElement {
        let restart = buttons["settings.tutorial"]
        var versuche = 0
        while !restart.exists && versuche < 8 {
            swipeUp()
            versuche += 1
        }
        XCTAssertTrue(restart.waitForExistence(timeout: 15),
                      "Der Rundgang-Knopf steht nicht da:\n\(debugDescription)",
                      file: file, line: line)
        return restart
    }
}
