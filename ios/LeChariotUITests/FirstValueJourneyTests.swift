import XCTest

/// **Der geführte erste Artikel** (Onboarding-Forschung, Punkt 7/8).
///
/// Die leere Liste lädt zu genau einer konkreten Handlung ein: Mit Filialen
/// stehen echte Wochenangebote als Beispiel-Artikel da, ein Tipp legt eines
/// an — und der Artikel bekommt sofort seine Treffer-Kachel. Das ist der
/// Aha-Moment, und diese Journey läuft ihn einmal ab.
///
/// Im Fixture-Prospekt trägt genau eine Zeile ein Tag („milch" an der
/// Bärenmarke), also steht genau ein Beispiel da — gut so: Die Journey greift
/// es über seinen Bezeichner und bleibt stabil, solange das Fixture sein Tag
/// behält.
final class FirstValueJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
    }

    /// Ein Tipp auf das Beispiel, und der erste Artikel liegt auf der Liste —
    /// **mit** Treffer-Kachel. Danach hat die Fläche nichts mehr zu melden.
    func testTappingAnExamplePutsTheFirstItemOnTheListWithItsMatch() {
        waitForList()

        let example = app.buttons["list.firstItem.add.Milch"]
        XCTAssertTrue(example.waitForExistence(timeout: 15),
                      "Die leere Liste muss ihr Beispiel-Angebot zeigen")
        XCTAssertTrue(example.label.contains("im Angebot"),
                      "…und sagen, warum es dasteht: \(example.label)")
        example.tap()

        XCTAssertTrue(app.buttons["Milch"].waitForExistence(timeout: 10),
                      "Der Artikel ist nicht auf der Liste gelandet")
        XCTAssertTrue(app.buttons["list.matches"].waitForExistence(timeout: 10),
                      "Der Aha-Moment ist die Treffer-Kachel unter dem Artikel")
        XCTAssertFalse(app.buttons["list.firstItem.add.Milch"].exists,
                       "Mit dem ersten Artikel ist die Einladung erledigt")
        // Alle vier Punkte sind damit erfüllt (Profil, Markt, Artikel,
        // Treffer) — eine Checkliste, die jetzt noch aufginge, hätte nichts zu
        // sagen.
        XCTAssertFalse(app.staticTexts["Dein Start"].exists,
                       "Wem nichts fehlt, dem wird keine Checkliste gezeigt")
    }

    /// ✕ heißt nein: Der Vorschlag verschwindet, die Liste bleibt leer — und
    /// die Einladung fällt auf den einen Satz zurück, mit einem **anderen**
    /// Wort. Dieselbe Milch noch einmal anzubieten wäre Streit, kein
    /// Vorschlag.
    func testDismissingAnExampleLeavesTheListAlone() {
        waitForList()

        let dismiss = app.buttons["list.firstItem.dismiss.Milch"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 15))
        dismiss.tap()

        XCTAssertFalse(app.buttons["list.firstItem.add.Milch"].exists,
                       "Weggewischt ist weggewischt")
        XCTAssertFalse(app.buttons["Milch"].exists,
                       "…und nichts davon steht ungefragt auf der Liste")

        let prompt = app.buttons["list.firstItem.prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5),
                      "Ohne Beispiele bleibt der eine Satz")
        XCTAssertTrue(prompt.label.contains("Brot"),
                      "…mit einem anderen Wort als dem eben verworfenen: \(prompt.label)")

        prompt.tap()
        XCTAssertTrue(app.buttons["Brot"].waitForExistence(timeout: 10),
                      "Der Satz muss tun, was er sagt")
    }

    /// Die Checkliste führt weiter, sobald der erste Artikel liegt und noch
    /// etwas offen ist. Hier ist das der Treffer: „Brot" steht im Fixture in
    /// keinem Angebot, also bleibt genau ein Punkt offen — und die Karte sagt,
    /// dass er von allein kommt.
    func testTheChecklistTakesOverWhenSomethingIsStillMissing() {
        waitForList()

        // Das Beispiel wegwischen und stattdessen den einen Satz nehmen: So
        // liegt ein Artikel **ohne** Treffer auf der Liste.
        let dismiss = app.buttons["list.firstItem.dismiss.Milch"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 15))
        dismiss.tap()
        app.buttons["list.firstItem.prompt"].tap()
        XCTAssertTrue(app.buttons["Brot"].waitForExistence(timeout: 10))

        XCTAssertTrue(app.staticTexts["Dein Start"].waitForExistence(timeout: 10),
                      "Nach dem ersten Artikel übernimmt die Checkliste")
        // Eine erledigte Zeile ist **ein** Element mit einem Satz als Label
        // (`accessibilityElement(children: .ignore)`), kein StaticText —
        // deshalb die typoffene Suche.
        let doneRow = app.descendants(matching: .any)["Erledigt: Erster Artikel auf der Liste"]
        XCTAssertTrue(doneRow.waitForExistence(timeout: 5),
                      "…mit angefangenem Fortschritt, nicht bei null")
        XCTAssertFalse(app.buttons["list.checklist.item"].exists,
                       "Ein erledigter Punkt ist kein Knopf mehr")

        // Weggewischt ist weggewischt — auch über den Neustart.
        app.buttons["list.checklist.dismiss"].tap()
        XCTAssertTrue(app.staticTexts["Dein Start"].waitForNonExistence(timeout: 5))
    }

    // MARK: Helfer

    /// Startet hinter dem Assistenten (`-uiTestingOnboarded`) und wartet, bis
    /// die Liste steht.
    private func waitForList() {
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
    }
}
