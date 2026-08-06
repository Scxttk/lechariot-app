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
    /// **Vier Artikel, nicht zwei — und das ist seit dem 06.08. der Punkt.**
    /// Eine Überschrift steht erst, wenn im Schnitt zwei Artikel auf einen
    /// Abschnitt kommen; über einer einzelnen Zeile sortiert sie nichts. Mit
    /// den alten zwei Artikeln prüfte diese Journey ab jetzt den Fall, in dem
    /// es zu Recht keine Überschriften gibt.
    func testTheListSortsItselfIntoCategorySections() {
        startTyping()
        app.typeText("Vollmilch\n")
        app.typeText("Milch\n")
        app.typeText("Erdbeeren\n")
        app.typeText("Orangen\n")
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

    /// **Ein Weg zu den Treffern, und er liegt in der Plan-Karte.**
    ///
    /// Bis zum 03.08. abends führte er in den Angebote-Tab, also in *alle*
    /// Angebote der Woche. Scott: „wirkt tot — nur ein Link." Bis zum 06.08.
    /// stand er dann in einer **eigenen zweiten Karte** unter der Plan-Karte,
    /// mit denselben Ketten noch einmal als Chips. Zwei Kästen, eine Frage;
    /// jetzt einer. Das Ziel ist unverändert `OfferHitsView`.
    func testThePlanCardLeadsToTheMatchesOfThisList() {
        startTyping()
        app.typeText("Vollmilch\n")
        app.typeText("\n")

        let weg = app.descendants(matching: .any)["list.plan.disclosure"]
        XCTAssertTrue(
            weg.waitForExistence(timeout: 10),
            "Der Weg zu den Treffern gehört in die Plan-Karte\n" + app.debugDescription
        )

        weg.tap()
        XCTAssertTrue(
            app.navigationBars["Passende Artikel"].waitForExistence(timeout: 10),
            "der Weg muss zu den Treffern dieser Liste führen\n" + app.debugDescription
        )
    }

    /// **Die zweite Karte ist weg und darf nicht zurückkommen.**
    func testTheSecondCardIsGone() {
        startTyping()
        app.typeText("Vollmilch\n")
        app.typeText("\n")

        XCTAssertTrue(
            app.descendants(matching: .any)["list.plan.headline"].waitForExistence(timeout: 10)
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["list.offerHits"].exists,
            "„Passende Artikel im Angebot“ steht wieder als eigene Karte in der Liste"
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
