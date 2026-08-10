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
    private let fixtureChain = "Lidl"

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

    /// **Der Ablauf, den Scott am 2026-07-31 entschieden hat.**
    ///
    /// Der Assistent endete bis dahin in der Filialauswahl — einer langen,
    /// gesuchten Liste, bevor man gesehen hat, wofür man sie braucht. Jetzt
    /// endet er in der Einkaufsliste, und die ist **ohne Filiale benutzbar**:
    /// Eingabezeile, Vorschläge und Artikel funktionieren, und an der Stelle
    /// des Preisvergleichs steht, was fehlt.
    ///
    /// Das ist die eine Journey, die den ganzen Umbau festhält. Ohne sie könnte
    /// jemand das Filialen-Tor vor der Liste wieder einziehen, und alles
    /// Übrige — die Ankertexte des Rundgangs, die Frage am Ende — bliebe
    /// grün, während der erste Bildschirm wieder eine Sackgasse wäre.
    func testTheListWorksWithoutABranchAndSaysWhatIsMissing() {
        completeOnboarding(name: "Scott")

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Keine Filiale gewählt"].exists,
                       "die Liste steht nicht mehr hinter einem Filialen-Tor")
        XCTAssertTrue(app.staticTexts["Noch keine Filiale gewählt"].exists,
                      "…aber sie sagt, was fehlt")

        let field = app.textFields["list.input"]
        XCTAssertTrue(field.exists, "ohne Eingabezeile ist es keine Einkaufsliste")
        field.tap()
        field.typeText("Vollmilch\n")
        dismissQuantitySheet()
        XCTAssertTrue(app.buttons["Vollmilch"].waitForExistence(timeout: 10),
                      "Artikel müssen auch ohne Filiale auf die Liste gehen")
        // **Der Grund steht jetzt einmal statt unter jedem Artikel.** Bis zum
        // 07.08. trug jede Zeile ohne Filiale den Satz „Sobald du Filialen
        // gewählt hast …"; im Raster gibt es keine Zeile mehr, die ihn tragen
        // könnte. Verloren ist er nicht — die Karte oben sagt dasselbe und
        // trägt zusätzlich den Weg dorthin, geprüft eine Zusicherung weiter
        // oben („Noch keine Filiale gewählt").
        // Und die Kachel behauptet nichts, was ohne Filiale niemand wissen
        // kann: kein Preis, kein Angebot.
        let kachel = app.buttons["Vollmilch"].firstMatch
        XCTAssertFalse(((kachel.value as? String) ?? "").contains("Angebot"),
                       "Ohne Filiale darf keine Kachel ein Angebot behaupten: \(kachel.value ?? "–")")
    }

    /// Und der Weg aus dem Leerzustand heraus führt wirklich irgendwohin.
    func testTheEmptyStateLeadsIntoTheBranchPickerAndBack() {
        completeOnboarding(name: "Scott")
        pickFixtureBranchFromTheList()

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "nach dem Wählen steht man wieder in der Liste")
        XCTAssertFalse(app.staticTexts["Noch keine Filiale gewählt"].exists,
                       "und der Hinweis hat sich erledigt")
    }

    /// Every question is optional — a user who answers nothing still has
    /// to arrive in the app.
    func testOnboardingCanBeCompletedWithoutAnsweringAnything() {
        tapPrimary()               // welcome
        tapSkip()                  // "Ohne Namen weiter"
        enterPLZAndContinue()
        tapSkip()                  // Ketten: "Später"
        tapPrimary()               // Belohnung
        // **Seit dem 06.08. sind es zwei Knöpfe statt Schalter plus „Fertig".**
        // Wer nichts beantwortet, sagt hier ausdrücklich „Keine Angaben
        // übermitteln" — vorher hing dieselbe Wirkung an einem Schalter, den
        // man überklicken konnte, ohne etwas gesagt zu haben.
        tapSkip()                  // consent: "Keine Angaben übermitteln"

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }

    /// **Ketten statt Fragen** (2026-08-05): Nach dem Ort kommt „Welche Märkte
    /// magst du?" — die Ketten der Gegend als antippbare Chips, keine
    /// Filialsuche. Die Fragen zu Haushalt und Ernährung stehen nicht mehr im
    /// Assistenten.
    func testAfterTheRegionComeTheLocalChainsNotTheProfileQuestions() {
        tapPrimary()               // welcome
        tapSkip()                  // name
        enterPLZAndContinue()

        // Die Fixture-Gegend (Dresden) hat vier Ketten im Verzeichnis.
        let lidl = app.buttons["Lidl"]
        XCTAssertTrue(lidl.waitForExistence(timeout: 15),
                      "nach dem Ort gehören die Ketten der Gegend auf den Bildschirm")
        XCTAssertTrue(app.buttons["Netto"].exists)
        XCTAssertTrue(app.buttons["REWE"].exists)
        XCTAssertFalse(app.staticTexts["Wie kaufst du ein?"].exists,
                       "die Haushaltsfrage ist aus dem Assistenten raus")

        lidl.tap()
        XCTAssertTrue(lidl.isSelected, "ein Tipp merkt die Kette")
        lidl.tap()
        XCTAssertFalse(lidl.isSelected, "…und der zweite nimmt sie wieder raus")
    }

    /// **Der Belohnungsschritt zeigt echte Zahlen.** Ort und Ketten sollen
    /// sichtbar etwas gebracht haben — die Fixture-Gegend hat 4 Ketten mit 5
    /// Filialen im Verzeichnis, und genau die stehen da.
    func testThePayoffScreenShowsTheRealNumbersOfTheArea() {
        tapPrimary()               // welcome
        tapSkip()                  // name
        enterPLZAndContinue()
        XCTAssertTrue(app.buttons["Lidl"].waitForExistence(timeout: 15))
        app.buttons["Lidl"].tap()  // eine Kette merken
        tapPrimary()               // Ketten → Belohnung

        XCTAssertTrue(
            app.staticTexts["4 Ketten, 5 Filialen in deiner Nähe."].waitForExistence(timeout: 15),
            "die Belohnung muss die Zahlen der Gegend nennen, nicht irgendeinen Werbesatz"
        )
        // Die Zeile ist ein zusammengefasstes Element (Symbol + Satz), daher
        // über das Label statt über `staticTexts` gesucht.
        let liked = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "1 Kette hast du dir gemerkt."))
            .firstMatch
        XCTAssertTrue(liked.exists, "…und die getroffene Auswahl sichtbar machen")

        tapPrimary()               // Belohnung → Einwilligung
        tapSkip()                  // consent: "Keine Angaben übermitteln"

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }

    /// **Beide Antworten stehen als Knopf da, und beide führen in die App.**
    ///
    /// Scotts Befund vom 06.08.: „Darf Le Chariot mitlernen?" mit einem
    /// Schalter darunter liest sich wie jede App, die alle Daten will — „und
    /// deswegen klickt man bei der Seite einfach weiter." Wer durchklickte,
    /// hatte nicht Nein gesagt, sondern gar nichts. Dieser Test hält fest, dass
    /// die Frage nicht wieder in ein Bedienelement wandert, das man übersehen
    /// kann.
    func testTheConsentStepAsksWithTwoNamedButtons() {
        tapPrimary()               // welcome
        tapSkip()                  // Ohne Namen weiter
        enterPLZAndContinue()
        tapSkip()                  // Ketten
        tapPrimary()               // Belohnung

        XCTAssertTrue(primary.waitForExistence(timeout: 15))
        XCTAssertEqual(primary.label, "Angaben übermitteln")
        XCTAssertTrue(skip.exists, "die Gegenantwort fehlt")
        XCTAssertEqual(skip.label, "Keine Angaben übermitteln")

        primary.tap()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }

    /// Der Picker lässt niemanden mit leeren Händen abschließen: ohne Filiale
    /// gibt es nichts zu vergleichen. Er ist seit dem 2026-07-31 keine Station
    /// des Assistenten mehr, aber diese Regel gilt in ihm unverändert — wer ihn
    /// **öffnet**, soll ihn nicht versehentlich leer wieder zumachen. Der
    /// Ausweg für den, der es sich anders überlegt, heißt „Abbrechen".
    func testDoneStaysDisabledUntilABranchIsPicked() {
        completeOnboarding(name: "Scott")

        openBranchPicker()

        let done = app.buttons["markets.done"]
        XCTAssertFalse(done.isEnabled, "no branch chosen yet")
        XCTAssertTrue(
            app.staticTexts["Wähle mindestens eine Filiale, um fortzufahren."].exists,
            "and the reason has to be on screen, not just implied by a grey button"
        )

        openChain(fixtureChain)
        app.buttons[fixtureBranch].tap()
        app.buttons["chain.done"].tap()
        XCTAssertTrue(done.isEnabled)

        XCTAssertTrue(app.buttons["Abbrechen"].exists,
                      "wer den Picker öffnet, muss auch wieder heraus")
    }

    /// **Die erste Seite des Wählers zeigt Ketten, keine Filialen** (01.08.).
    /// Vorher standen bis zu drei Filialen je Kette gleich dort und „14
    /// weitere EDEKA-Filialen" klappte im selben Bildschirm auf.
    ///
    /// Der Test beißt an beiden Enden: Die Filiale darf oben **nicht** stehen,
    /// und hinter der Kette muss sie zu finden sein.
    func testTheFirstScreenListsChainsAndTheBranchesLiveOneTapDeeper() {
        completeOnboarding(name: "Scott")
        openBranchPicker()

        let chain = app.buttons["picker.chain.\(fixtureChain)"]
        XCTAssertTrue(chain.waitForExistence(timeout: 15),
                      "die Kette gehört auf die erste Seite")
        XCTAssertFalse(app.buttons[fixtureBranch].exists,
                       "…und die Filiale nicht, solange niemand gesucht hat")

        chain.tap()
        let branch = app.buttons[fixtureBranch]
        XCTAssertTrue(branch.waitForExistence(timeout: 15),
                      "hinter der Kette muss die Filiale stehen")
        branch.tap()

        // Das eigene „Fertig" der Kettenseite führt zurück in den Wähler,
        // nicht aus ihm heraus.
        app.buttons["chain.done"].tap()
        XCTAssertTrue(app.buttons["picker.chain.\(fixtureChain)"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["markets.done"].isEnabled)
    }

    /// **Gewählte Filialen stehen am Ende, nicht mehr oben** (08.08.).
    ///
    /// Zwei Zusagen auf einmal, und die zweite ist die neue: Die Wahl bleibt
    /// auf der ersten Seite erreichbar, ohne die Kette wieder aufzumachen —
    /// sonst wäre sie leichter getroffen als rückgängig gemacht. **Und sie
    /// steht unter den Ketten**, denn oben schob sie mit jeder weiteren Wahl
    /// genau die Ketten aus dem Bild, die man als Nächstes dazunehmen will
    /// (Scott, 08.08.).
    ///
    /// Geprüft an den Rahmen, nicht an der Reihenfolge im Baum: Die
    /// Abfragereihenfolge von XCUITest sagt nichts darüber, was der Nutzer
    /// zuerst sieht — die y-Koordinate schon.
    func testAChosenBranchStandsBelowTheChainsAndStaysReachable() {
        completeOnboarding(name: "Scott")
        pickFixtureBranchFromTheList()

        openTab("Einstellungen")
        openPlaces()
        app.buttons["Filialen bearbeiten"].tap()
        let überschrift = app.staticTexts["Deine Filialen"]
        XCTAssertTrue(überschrift.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons[fixtureBranch].exists,
                      "die getroffene Wahl steht auf der ersten Seite")

        let kette = app.buttons["picker.chain.\(fixtureChain)"]
        XCTAssertTrue(kette.waitForExistence(timeout: 15))
        XCTAssertLessThan(
            kette.frame.minY, überschrift.frame.minY,
            "Die Ketten müssen über der eigenen Auswahl stehen, sonst schiebt "
            + "jede weitere Wahl sie weiter aus dem Bild"
        )
    }

    /// Die Suche ist die Einschränkung: Wer tippt, bekommt Filialen, keine
    /// Kettenzeilen — sonst wäre der Treffer hinter einer Seite versteckt.
    func testSearchingShowsBranchesRatherThanChains() {
        completeOnboarding(name: "Scott")
        openBranchPicker()

        let field = app.searchFields.firstMatch
        if !field.waitForExistence(timeout: 10) {
            app.swipeDown()
        }
        XCTAssertTrue(field.waitForExistence(timeout: 15),
                      "Das Suchfeld des Filialwählers fehlt:\n" + app.debugDescription)
        field.tap()
        field.typeText("Reick")

        XCTAssertTrue(app.buttons[fixtureBranch].waitForExistence(timeout: 10),
                      "der Treffer gehört direkt auf den Bildschirm")
    }

    // MARK: Regressions

    /// Removing the last branch used to flip `isOnboardingComplete` back to
    /// false, which tore the settings screen away mid-tap and dropped the user
    /// into onboarding. It must now be an ordinary empty state.
    func testRemovingTheLastBranchKeepsTheUserInTheApp() {
        completeOnboarding(name: "Scott")
        pickFixtureBranchFromTheList()

        openTab("Einstellungen")
        openPlaces()
        app.buttons["Filialen bearbeiten"].tap()
        let branch = app.buttons[fixtureBranch]
        XCTAssertTrue(branch.waitForExistence(timeout: 15))
        branch.tap()

        XCTAssertFalse(app.staticTexts["Ein Einkauf, ein Markt, der beste Preis."].exists,
                       "must not restart onboarding")

        openTab("Liste")
        // Seit dem 2026-07-31 ist das **kein** Leerbildschirm mehr, sondern die
        // Liste mit ihrem Hinweis: Wer seine letzte Filiale entfernt, verliert
        // den Preisvergleich — nicht seine Einkaufsliste.
        XCTAssertTrue(app.staticTexts["Noch keine Filiale gewählt"].waitForExistence(timeout: 10),
                      "the tab has to say what is missing")
        XCTAssertTrue(app.textFields["list.input"].exists,
                      "…without taking the shopping list away")
        XCTAssertTrue(app.buttons["list.chooseMarkets"].exists,
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

        let field = app.textFields["list.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Milch\n")
        dismissQuantitySheet()

        XCTAssertTrue(app.buttons["Milch"].waitForExistence(timeout: 5))
    }

    /// The quick-add chips used to sit behind the empty state alone, so the
    /// whole strip vanished with the first tap and the second staple had to be
    /// typed. Taking one must leave the rest reachable.
    func testTakingAQuickAddLeavesTheOtherSuggestionsReachable() {
        completeOnboarding(name: "Scott")

        let milch = app.buttons["Milch hinzufügen"]
        XCTAssertTrue(milch.waitForExistence(timeout: 15))
        milch.tap()
        dismissQuantitySheet()

        XCTAssertTrue(app.buttons["Milch"].waitForExistence(timeout: 5))
        let brot = app.buttons["Brot hinzufügen"]
        XCTAssertTrue(brot.waitForExistence(timeout: 5),
                      "the remaining suggestions must survive the first tap")
        brot.tap()
        dismissQuantitySheet()

        XCTAssertTrue(app.buttons["Brot"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Milch hinzufügen"].exists,
                       "a staple already on the list must stop being suggested")
    }

    // MARK: Helpers

    /// The onboarding steps are addressed by identifier rather than label: the
    /// software keyboard contributes its own "Weiter" and "Fertig" buttons.
    private var primary: XCUIElement { app.buttons["onboarding.primary"] }
    private var skip: XCUIElement { app.buttons["onboarding.skip"] }

    /// **Den Filialwähler öffnen — und den Tipp wiederholen, wenn er ins Leere
    /// ging.**
    ///
    /// Am 06.08. gemessen: Dieser Test fiel in etwa jedem dritten Lauf, und
    /// zwar **nicht** am Suchfeld, wie die alte Zusicherung vermuten ließ.
    /// Aufgeschlüsselt mit einem Halt auf `markets.done`: Wenn er fällt, geht
    /// **das Blatt gar nicht auf**. Der Tipp landet, während der Leerzustand
    /// der Liste noch einschwingt — die Karte mit dem Knopf wird in dem Moment
    /// gerade eingeblendet, und ein Tipp auf etwas, das sich noch bewegt, wird
    /// verschluckt.
    ///
    /// Deshalb erst warten, dann tippen, und wenn das Blatt nach zehn Sekunden
    /// nicht steht, ein zweites Mal tippen. Ein Mensch macht genau das.
    ///
    /// **Merksatz: Ein Test, der mal fällt und mal nicht, misst die Maschine,
    /// nicht die App — und die Zusicherung, an der er fällt, ist selten die,
    /// die etwas weiß.**
    private func openBranchPicker(_ file: StaticString = #filePath, _ line: UInt = #line) {
        let opener = app.buttons["list.chooseMarkets"]
        XCTAssertTrue(opener.waitForExistence(timeout: 20),
                      "Der Knopf zum Filialwähler fehlt", file: file, line: line)
        opener.tap()

        let done = app.buttons["markets.done"]
        if !done.waitForExistence(timeout: 10), opener.exists {
            opener.tap()
        }
        XCTAssertTrue(done.waitForExistence(timeout: 20),
                      "Der Filialwähler ist nicht aufgegangen:\n" + app.debugDescription,
                      file: file, line: line)
    }

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
        let field = app.textFields["region.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("01219")
        tapPrimary()
    }

    /// Öffnet die Filialauswahl aus dem Leerzustand der Liste und wählt die
    /// Fixture-Filiale. **Der Weg dorthin ist seit dem 2026-07-31 dieser** —
    /// im Assistenten kommt sie nicht mehr vor.
    private func pickFixtureBranchFromTheList() {
        openBranchPicker()
        openChain(fixtureChain)
        let branch = app.buttons[fixtureBranch]
        XCTAssertTrue(branch.waitForExistence(timeout: 15), "fixture branch missing")
        branch.tap()
        app.buttons["chain.done"].tap()
        app.buttons["markets.done"].tap()
    }

    /// Öffnet „Filialen und Regionen". Seit dem 2026-08-01 liegen beide
    /// Listen eine Seite tiefer, damit die Filialliste die Einstellungen nicht
    /// mehr auffrisst.
    private func openPlaces() {
        let row = app.buttons["settings.places"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Kein Weg zu den Filialen")
        row.tap()
    }

    /// Öffnet die Kettenseite. Seit dem 2026-08-01 liegen die Filialen dort
    /// und nicht mehr auf der ersten Seite des Wählers.
    private func openChain(_ chain: String) {
        let row = app.buttons["picker.chain.\(chain)"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Kettenzeile \(chain) fehlt")
        row.tap()
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
        tapPrimary()                       // Ketten („Welche Märkte magst du?")
        tapPrimary()                       // Belohnung
        // **„Keine Angaben übermitteln"**, seit die Einwilligung am 06.08. mit
        // zwei benannten Knöpfen fragt. Vorher hieß derselbe Weg „Fertig" bei
        // ausgeschaltetem Schalter, also ebenfalls: nichts übermitteln. Diese
        // Journeys handeln nicht von der Einwilligung; sie sollen den Weg
        // nehmen, der nichts nebenbei anstößt.
        tapSkip()                          // consent
    }

    /// Schließt das Mengen-Menü, das seit [UI-8] beim Anlegen von selbst
    /// aufgeht.
    private func dismissQuantitySheet() {
        // Seit dem 03.08. ist das Mengen-Menue kein Blatt mehr, sondern eine
        // Schicht ueber der Eingabezeile — sie geht mit dem Fokus, nicht mit
        // einem Knopf. Ein Wisch ueber die Liste tut das.
        let panel = app.buttons["list.detailPanel.more"]
        guard panel.waitForExistence(timeout: 3) else { return }
        app.swipeUp()
        _ = panel.waitForNonExistence(timeout: 3)
    }

}
