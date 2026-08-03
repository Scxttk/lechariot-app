import XCTest

/// **„Orientiert die Liste viel mehr an Bring!" — die zwei Punkte zur
/// Listen-Gestalt** aus Scotts Video vom 03.08.
///
/// Gegen den Stand davor war die Liste **ein** Abschnitt ohne Überschrift, und
/// die Angebote standen nur im Angebote-Tab.
final class BringSectionsJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingOnboardedThreeChains"]
        app.launch()
    }

    private func startTyping() {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
    }

    /// **Der Kern: Vollmilch und Erdbeeren stehen unter verschiedenen
    /// Überschriften** — einsortiert hat das niemand von Hand.
    ///
    /// Der erste Anlauf tippte „Kaffee" und fiel: „Kaffee ganze Bohne" ist im
    /// Vorrat eine Zeile der **Folgewoche**. Der Test hatte unrecht, nicht die
    /// App — und nebenbei ist das die Leck-Regel von der anderen Seite: Was
    /// nächste Woche gilt, sortiert diese Woche nichts ein.
    func testTheListSortsItselfIntoCategorySections() {
        startTyping()
        app.typeText("Vollmilch\n")
        app.typeText("Erdbeeren\n")
        // Aus dem Fluss heraus, sonst verdeckt die Schicht die Liste.
        app.typeText("\n")

        XCTAssertTrue(app.buttons["Vollmilch"].waitForExistence(timeout: 10),
                      "Vollmilch ist nicht auf der Liste gelandet\n" + app.debugDescription)

        let molkerei = app.descendants(matching: .any)["list.section.Molkerei & Eier"]
        let obst = app.descendants(matching: .any)["list.section.Obst & Gemüse"]
        XCTAssertTrue(
            molkerei.waitForExistence(timeout: 10),
            "Vollmilch gehört unter „Molkerei & Eier“\n" + app.debugDescription
        )
        // Erst scrollen, dann fragen: Eine `List` baut nur, was zu sehen ist,
        // und der zweite Abschnitt liegt unter der Kante.
        var tries = 0
        while !obst.exists && tries < 8 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(
            obst.exists,
            "Erdbeeren gehören unter „Obst & Gemüse“\n" + app.debugDescription
        )
    }

    /// **Die Zeile aus dem Video, in der Liste statt im Angebote-Tab** — mit
    /// Ketten-Zählern, und sie führt zu **den Treffern dieser Liste**.
    ///
    /// Bis zum 03.08. abends führte sie in den Angebote-Tab, also in *alle*
    /// Angebote der Woche. Scott: „wirkt tot — nur ein Link." Die Zahl in der
    /// Zeile verspricht diese Treffer, nicht alle; siehe `OfferHitsView`.
    func testTheOfferHitsRowStandsInTheListAndLeadsToTheMatches() {
        startTyping()
        app.typeText("Vollmilch\n")
        app.typeText("\n")

        let zeile = app.descendants(matching: .any)["list.offerHits"]
        XCTAssertTrue(
            zeile.waitForExistence(timeout: 10),
            "„Passende Artikel im Angebot“ gehört in die Liste\n" + app.debugDescription
        )
        // Der Zähler steht in der Vorlesefassung — sonst wäre die Zeile für
        // VoiceOver vier Bruchstücke.
        XCTAssertTrue(
            zeile.label.contains("Passende Artikel im Angebot"),
            "gelesen wurde: \(zeile.label)"
        )

        zeile.tap()
        XCTAssertTrue(
            app.navigationBars["Passende Artikel"].waitForExistence(timeout: 10),
            "die Zeile muss zu den Treffern dieser Liste führen\n" + app.debugDescription
        )
    }

    /// **Eine Liste ohne einen einzigen Treffer bekommt keine Überschrift.**
    /// „Noch nicht einsortiert" über allem wäre schlechter als nichts.
    func testAListWithoutAnyMatchStaysHeaderless() {
        startTyping()
        app.typeText("Wunderkerzen\n")
        app.typeText("\n")

        XCTAssertTrue(app.buttons["Wunderkerzen"].waitForExistence(timeout: 10))
        XCTAssertFalse(
            app.descendants(matching: .any)["list.section.Noch nicht einsortiert"].exists,
            "über einer Liste ohne Treffer gehört keine Überschrift\n" + app.debugDescription
        )
    }
}
