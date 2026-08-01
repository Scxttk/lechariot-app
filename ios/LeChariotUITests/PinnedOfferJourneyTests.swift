import XCTest

/// **Die eigene Wahl auf der Liste.**
///
/// Gemeldet am 2026-07-31: Die App wählt je Eintrag das billigste Angebot, und
/// im Treffer-Blatt kann man Alternativen zwar sehen, aber nicht nehmen — das ✕
/// ist Rückmeldung, keine Auswahl. „Ich will aber lieber rot angezeigt haben,
/// weil ich das Produkt lieber will. Dann kann ich mir meine Einkaufsliste
/// gleich modifizieren."
///
/// Die Fixtures führen dafür zwei Milchangebote bei derselben Kette: „Bio
/// Vollmilch" für 0,99 € (das billigste) und „Landliebe Frische Vollmilch" für
/// 1,49 €. Geheftet wird hier immer das teurere — eine Wahl, die zufällig
/// dasselbe Ergebnis hätte wie keine Wahl, beweist nichts.
final class PinnedOfferJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    private let billigstes = "Bio Vollmilch"
    private let gewaehltes = "Landliebe Frische Vollmilch"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: Journeys

    /// **Ein zweiter Pin ersetzt den ersten nicht, er kommt dazu** ([UI-7],
    /// von Scott am 01.08. durchentschieden).
    ///
    /// Der Fall dahinter ist die Bio-Milch: „Milch" kann Bio-Milch *und*
    /// normale Milch meinen, und bis hierher galt ein Eintrag = ein Suchwort =
    /// **genau ein** getroffenes Angebot. Gegen den alten Stand fällt dieser
    /// Test durch — dort hätte der zweite Pin den ersten überschrieben und die
    /// Zeile trüge nur ein Produkt.
    func testASecondPinAddsAPositionInsteadOfReplacingTheFirst() {
        launch()
        addItem("Vollmilch")

        pinTheDearerOffer()
        XCTAssertTrue(waitForRowLabel(containing: gewaehltes))

        alsoPinTheCheapestOffer()

        // Beide Wahlen stehen als eigene Kacheln auf der Zeile.
        let zweite = app.buttons["list.matches.more"].firstMatch
        XCTAssertTrue(zweite.waitForExistence(timeout: 10),
                      "Der zweite Pin hat den ersten ersetzt statt danebenzustehen")
        let beide = rowLabel() + " " + zweite.label
        XCTAssertTrue(beide.contains(billigstes) && beide.contains(gewaehltes),
                      "Beide Produkte müssen auf der Zeile stehen: \(beide)")
        XCTAssertTrue(app.staticTexts["2 Produkte"].exists,
                      "Ohne Abzeichen sehen zwei Kacheln nach einem Fehler aus")
    }


    /// Der gemeldete Fall, von vorn bis hinten: Das teurere Angebot wird
    /// geheftet, steht danach auf der Hauptseite — und die Heftung lässt sich
    /// an derselben Stelle wieder lösen.
    func testPinningTheDearerOfferPutsItOnTheListAndCanBeUndone() {
        launch()
        addItem("Vollmilch")

        let zeile = app.buttons["list.matches"].firstMatch
        XCTAssertTrue(zeile.waitForExistence(timeout: 15))
        XCTAssertTrue(zeile.label.contains(billigstes),
                      "Ohne Heftung steht das billigste da: \(zeile.label)")

        pinTheDearerOffer()

        XCTAssertTrue(
            waitForRowLabel(containing: gewaehltes),
            "Nach dem Heften muss die eigene Wahl auf der Liste stehen: \(rowLabel())"
        )
        XCTAssertTrue(rowLabel().contains("Deine Wahl"),
                      "Und sie muss als Wahl kenntlich sein, nicht als „günstigstes Angebot“")

        // Zurück ins Blatt und die Heftung lösen — der Weg dahin ist derselbe,
        // den man zum Heften gegangen ist. Wäre er es nicht, hätte man eine
        // Einbahnstraße gebaut.
        app.buttons["list.matches"].firstMatch.tap()
        let loesen = app.buttons.matching(identifier: "matches.pin").element(boundBy: 1)
        XCTAssertTrue(loesen.waitForExistence(timeout: 10))
        XCTAssertEqual(loesen.label, "Heftung lösen", "Derselbe Knopf muss die Heftung zurücknehmen")
        loesen.tap()
        app.buttons["Fertig"].firstMatch.tap()

        XCTAssertTrue(
            waitForRowLabel(containing: billigstes),
            "Nach dem Lösen rechnet die App wieder mit dem billigsten: \(rowLabel())"
        )
    }

    /// **Die Heftung überlebt den Neustart.** Genau darum geht es dem Melder:
    /// „dauerhaft auf der Hauptseite ‚Liste' angezeigt". Eine Wahl, die beim
    /// nächsten Öffnen weg ist, ist keine.
    func testThePinIsStillThereAfterARestart() {
        launch()
        addItem("Vollmilch")
        pinTheDearerOffer()
        XCTAssertTrue(waitForRowLabel(containing: gewaehltes))

        app.terminate()
        launch(keepState: true)

        XCTAssertTrue(
            waitForRowLabel(containing: gewaehltes),
            "Nach dem Neustart steht wieder das billigste da: \(rowLabel())"
        )
    }

    /// **Und wenn es die Wahl nächste Woche nicht mehr gibt, sagt die Zeile
    /// das.** Nachgestellt wird der Wegfall über die Filialen: Geheftet wird
    /// ein Aldi-Angebot, danach startet die App mit Lidl allein — das
    /// geheftete Produkt ist dann nirgends mehr im Angebot, genau wie nach
    /// einer Rotation, die es aus dem Prospekt nimmt.
    ///
    /// Ein stiller Rückfall aufs billigste wäre hier die bequeme Lösung und
    /// genau die unsichtbare Ableitung, gegen die am 2026-07-31 entschieden
    /// wurde.
    func testAPinWhoseOfferIsGoneSaysSoOnTheRow() {
        launch(allBranches: true)
        addItem("Orangen")

        let zeile = app.buttons["list.matches"].firstMatch
        XCTAssertTrue(zeile.waitForExistence(timeout: 15))
        zeile.tap()
        let heften = app.buttons.matching(identifier: "matches.pin").firstMatch
        XCTAssertTrue(heften.waitForExistence(timeout: 10))
        heften.tap()
        app.buttons["Fertig"].firstMatch.tap()
        XCTAssertTrue(waitForRowLabel(containing: "Spanische Orangen"))

        // Neustart, diesmal ohne die Aldi-Filiale.
        app.terminate()
        launch(keepState: true)

        let hinweis = app.buttons["list.pin.dormant"]
        XCTAssertTrue(hinweis.waitForExistence(timeout: 15),
                      "Die Zeile muss sagen, dass die geheftete Wahl gerade fehlt")
        XCTAssertEqual(hinweis.label,
                       "Spanische Orangen ist diese Woche nicht im Angebot — und sonst passt diese Woche nichts.")

        // **Und der Weg aus der Heftung heraus bleibt offen**, obwohl das
        // Produkt in keiner Trefferliste mehr auftaucht und die Zeile gar keine
        // Angebotskachel mehr trägt. Ohne diesen Weg wäre die Heftung eine
        // Sackgasse — der Hinweis selbst ist deshalb der Knopf.
        hinweis.tap()
        let loesen = app.buttons["matches.unpin.dormant"]
        XCTAssertTrue(loesen.waitForExistence(timeout: 10),
                      "Das Blatt muss die schlafende Heftung zeigen und lösen lassen")
        loesen.tap()
        app.buttons["Fertig"].firstMatch.tap()

        XCTAssertFalse(app.buttons["list.pin.dormant"].waitForExistence(timeout: 5),
                       "Nach dem Lösen darf der Hinweis nicht stehen bleiben")
    }

    // MARK: Helfer

    private func launch(keepState: Bool = false, allBranches: Bool = false) {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
            + (allBranches ? ["-uiTestingOnboardedAllBranches"] : [])
            + (keepState ? ["-uiTestingKeepState"] : [])
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
    }

    private func addItem(_ text: String) {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
        feld.typeText(text + "\n")
        dismissQuantitySheet()
    }
    /// Schließt das Mengen-Menü, das seit [UI-8] beim Anlegen von selbst
    /// aufgeht. Die Journeys unten testen nicht das Menü, sondern was danach
    /// kommt — für sie ist es ein Zwischenschritt.
    private func dismissQuantitySheet() {
        let abbrechen = app.buttons["itemDetail.cancel"]
        if abbrechen.waitForExistence(timeout: 5) { abbrechen.tap() }
    }


    /// Öffnet das Treffer-Blatt und heftet die **zweite** Zeile an.
    ///
    /// Die Reihenfolge ist keine Zufälligkeit, auf die sich der Test stützt:
    /// `OfferMatcher` sortiert Direkttreffer nach Preis, das teurere Angebot
    /// steht also an zweiter Stelle. Wäre das einmal nicht so, fällt die
    /// Zusicherung danach mit dem Produktnamen im Text auf.
    private func pinTheDearerOffer() {
        app.buttons["list.matches"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts[gewaehltes].waitForExistence(timeout: 10),
                      "Die teurere Alternative fehlt im Blatt — siehe MockFixtures")
        let heften = app.buttons.matching(identifier: "matches.pin").element(boundBy: 1)
        XCTAssertTrue(heften.waitForExistence(timeout: 10))
        XCTAssertEqual(heften.label, "Auf die Liste heften")
        heften.tap()
        app.buttons["Fertig"].firstMatch.tap()
    }

    private func rowLabel() -> String {
        app.buttons["list.matches"].firstMatch.label
    }

    /// Heftet zusätzlich das billigste Angebot — der zweite Pin.
    private func alsoPinTheCheapestOffer() {
        app.buttons["list.matches"].firstMatch.tap()
        let heften = app.buttons.matching(identifier: "matches.pin").firstMatch
        XCTAssertTrue(heften.waitForExistence(timeout: 10))
        XCTAssertEqual(heften.label, "Auf die Liste heften",
                       "Der erste Pin darf diesen Knopf nicht schon umgeschaltet haben")
        heften.tap()
        app.buttons["Fertig"].firstMatch.tap()
    }

    private func waitForRowLabel(containing text: String) -> Bool {
        let zeile = app.buttons["list.matches"].firstMatch
        guard zeile.waitForExistence(timeout: 15) else { return false }
        let treffer = expectation(
            for: NSPredicate(format: "label CONTAINS %@", text),
            evaluatedWith: zeile
        )
        return XCTWaiter().wait(for: [treffer], timeout: 10) == .completed
    }
}
