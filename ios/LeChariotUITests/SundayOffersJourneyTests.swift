import XCTest

/// **Der Sonntag im Angebote-Tab** — Scotts Feldtest vom 09.08.
///
/// Acht Filialen gewählt, sichtbar nur zwei. Sachlich richtig (die
/// Prospektwochen der übrigen sechs endeten Samstag), aber die App sagte es
/// nicht: Die Ketten-Chips verschwanden mit ihren Zeilen, und „wo ist mein
/// Netto" blieb unbeantwortet.
///
/// **Der Zustand kommt aus `-uiTestingSunday`, nicht aus dem Kalender.** Ein
/// Test, der auf einen echten Sonntag wartet, ist an sechs von sieben Tagen
/// kein Test. Siehe `MockFixtures.sunday`: Lidl liefert, Aldi ruht mit
/// Vorschau, Netto ruht ohne.
final class SundayOffersJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-uiTestingOnboarded",
            "-uiTestingOnboardedThreeChains", "-uiTestingSunday",
        ]
        app.launch()
    }

    /// Die Zusage in einem Satz: **Eine gewählte Kette verschwindet nicht.**
    func testARestingChainKeepsItsChip() {
        openOffers()

        XCTAssertTrue(app.buttons["Aldi, zurzeit ohne Angebote"].firstMatch.exists,
                      "Aldi ruht und ist trotzdem weg\n" + app.debugDescription)
        XCTAssertTrue(app.buttons["Netto, zurzeit ohne Angebote"].firstMatch.exists,
                      "Netto ruht und ist trotzdem weg\n" + app.debugDescription)
        // Die Gegenprobe: Wer liefert, trägt den ruhenden Namen **nicht** —
        // sonst prüfte der Test nur, dass irgendein Chip dasteht.
        XCTAssertTrue(app.buttons["Lidl"].firstMatch.exists,
                      "Die liefernde Kette heißt schlicht Lidl")
        XCTAssertFalse(app.buttons["Lidl, zurzeit ohne Angebote"].firstMatch.exists)
    }

    /// Und hinter dem Chip steht der Grund, nicht „Nichts für diesen Filter".
    func testTheRestingChipLeadsToTheReasonAndToNextWeek() {
        openOffers()
        app.buttons["Aldi, zurzeit ohne Angebote"].firstMatch.tap()

        // **Der Bezeichner sitzt auf den Kindern, nicht auf einem Behälter.**
        // `ContentUnavailableView` hat kein eigenes Element im Baum; gemessen
        // trägt jedes Kind (Bild, beide Texte, beide Knöpfe) den Bezeichner —
        // dieselbe Vererbung, vor der `ItemDetailPanel` seit dem 08.08. warnt.
        // Gesucht wird deshalb der Text und nicht ein `otherElement`.
        let grund = app.staticTexts.matching(identifier: "offers.restingChain").firstMatch
        XCTAssertTrue(grund.waitForExistence(timeout: 10),
                      "Hinter dem ruhenden Chip steht kein Grund\n" + app.debugDescription)
        XCTAssertFalse(app.staticTexts["Nichts für diesen Filter"].exists,
                       "Der Filter ist nicht im Weg — die Woche ist es")

        // Der Satz nennt beide Daten. Geprüft wird auf die zwei Wörter und
        // nicht auf ein Datum: Welcher Tag dort steht, hängt am Lauftag, und
        // ein Test, der ihn festschreibt, fällt am Dienstag.
        let satz = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "endeten")
        ).firstMatch
        XCTAssertTrue(satz.exists, "Kein Ende genannt\n" + app.debugDescription)
        XCTAssertTrue(satz.label.contains("gelten ab"),
                      "Aldi hat eine Vorschau — dann gehört ihr Anfang in den Satz: \(satz.label)")

        // Und der Weg dorthin ist einer, kein Hinweis.
        let weiter = app.buttons["Nächste Woche ansehen"]
        XCTAssertTrue(weiter.exists, "Kein Weg in die Vorschau\n" + app.debugDescription)
        weiter.tap()
        XCTAssertTrue(app.navigationBars["Nächste Woche"].waitForExistence(timeout: 15),
                      "Der Knopf führt nicht in die Vorschau\n" + app.debugDescription)
    }

    /// **Behauptet wird nur, was wir wissen.** Netto hat keine Vorschau — dann
    /// steht dort auch kein Satz über die nächste Woche und kein Knopf dorthin.
    func testAChainWithoutAPreviewIsNotPromisedOne() {
        openOffers()
        app.buttons["Netto, zurzeit ohne Angebote"].firstMatch.tap()

        XCTAssertTrue(
            app.staticTexts.matching(identifier: "offers.restingChain")
                .firstMatch.waitForExistence(timeout: 10),
            "Hinter dem ruhenden Chip steht kein Grund\n" + app.debugDescription
        )
        let satz = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "endeten")
        ).firstMatch
        XCTAssertTrue(satz.exists, "Kein Ende genannt\n" + app.debugDescription)
        XCTAssertFalse(satz.label.contains("gelten ab"),
                       "Netto hat keine Vorschau — dann darf keine versprochen werden: \(satz.label)")
        XCTAssertFalse(app.buttons["Nächste Woche ansehen"].exists,
                       "Ein Knopf in eine Vorschau, die es nicht gibt")

        // Der Ausweg bleibt trotzdem einen Tipp weit weg.
        app.buttons["Alle Märkte zeigen"].tap()
        XCTAssertTrue(app.buttons["offers.row"].firstMatch.waitForExistence(timeout: 10),
                      "Zurück zu allen Märkten führt nicht zur Liste")
    }

    /// **Und der Weg hängt am selben Schalter wie die Tür daneben.** Ohne die
    /// Bedingung böte der Leerzustand einen Bildschirm an, den der Rest der
    /// App gerade versteckt — ein zweiter, unangekündigter Weg, und das ist
    /// die Fehlerklasse vom 30.07.
    func testWithoutThePreviewFlagThereIsNoWayIntoIt() {
        app.terminate()
        app.launchArguments += ["-feature.nextWeekPreview.aus"]
        app.launch()
        openOffers()
        app.buttons["Aldi, zurzeit ohne Angebote"].firstMatch.tap()

        XCTAssertTrue(
            app.staticTexts.matching(identifier: "offers.restingChain")
                .firstMatch.waitForExistence(timeout: 10),
            "Der Grund steht auch ohne Vorschau da\n" + app.debugDescription
        )
        XCTAssertFalse(app.buttons["offers.nextWeek"].exists,
                       "Die Werkzeugleiste versteckt die Vorschau — die Probe misst also etwas")
        XCTAssertFalse(app.buttons["Nächste Woche ansehen"].exists,
                       "Zweiter Weg in einen abgeschalteten Bildschirm")
    }

    private func openOffers() {
        let tab = app.tabBars.buttons["Angebote"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "Kein Reiter Angebote")
        tab.tap()
        XCTAssertTrue(app.buttons["offers.row"].firstMatch.waitForExistence(timeout: 25),
                      "Der Angebote-Tab lädt nicht\n" + app.debugDescription)
    }
}
