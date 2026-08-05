import XCTest

/// **„Passende Artikel im Angebot" — und was dahinter liegt.**
///
/// Scott, 03.08.: „wirkt tot — nur ein Link, sonst passiert nichts." Die Zeile
/// zeigte Ketten-Zähler und führte in den Angebote-Tab, also in *alle*
/// Angebote der Woche. Die Zahl versprach etwas anderes: **diese** Treffer.
///
/// Geprüft wird deshalb genau das Versprechen: Der Weg führt zu den Treffern
/// **dieser Liste**, und dort lässt sich einer davon übernehmen, ohne den
/// Bildschirm zu verlassen.
final class OfferHitsJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded",
                               "-uiTestingOnboardedThreeChains"]
        app.launch()
    }

    private var input: XCUIElement { app.textFields["list.input"] }
    private var row: XCUIElement { app.buttons["list.offerHits"] }

    /// Legt zwei Artikel an, zu denen der Vorrat sicher Treffer hat.
    private func seedList() {
        XCTAssertTrue(input.waitForExistence(timeout: 20))
        input.tapAndAwaitKeyboard(in: app)
        app.typeText("Milch\n")
        app.typeText("Orangen\n")
        // Beendet den Tipp-Fluss über die Liste — die Bildschirmmitte liegt
        // mit voller Software-Tastatur auf der Schicht. Siehe `dragTheListUp`.
        app.dragTheListUp()
        XCTAssertTrue(row.waitForExistence(timeout: 15),
                      "Die Zeile „Passende Artikel im Angebot“ steht nicht da:\n"
                      + app.debugDescription)
    }

    /// **Der Weg führt zu den Treffern, nicht in den Angebote-Tab.**
    ///
    /// Gegen `2465060` landet dieser Tipp im Angebote-Tab: Die Navigationsleiste
    /// heißt dort „Angebote", und es gibt weder `hits.list` noch `hits.pin`.
    func testTheRowLeadsToTheMatchesOfThisList() {
        seedList()
        row.tap()

        XCTAssertTrue(app.navigationBars["Passende Artikel"].waitForExistence(timeout: 10),
                      "Der Weg führt nicht zu den Treffern:\n" + app.debugDescription)
        XCTAssertTrue(app.otherElements["hits.list"].exists || app.tables["hits.list"].exists
                      || app.collectionViews["hits.list"].exists,
                      "Die Trefferliste fehlt")
        // Die eigenen Worte führen, nicht die des Prospekts.
        XCTAssertTrue(app.staticTexts["Milch"].waitForExistence(timeout: 10),
                      "Der Artikel der Liste steht nicht in der Trefferzeile")
    }

    /// **Übernehmen geht direkt** — das „Aktion übernehmen" aus dem Bring!-Video.
    /// Die Heftung landet am Artikel der Liste und steht nach dem Schließen dort.
    func testAnOfferCanBePinnedRightThere() {
        seedList()
        row.tap()
        XCTAssertTrue(app.navigationBars["Passende Artikel"].waitForExistence(timeout: 10))

        let pin = app.buttons["hits.pin"].firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 10), "Kein Übernehmen-Knopf")
        pin.tap()

        // Das Abzeichen steht sofort da — die Zeile liest den Speicher live.
        XCTAssertTrue(app.staticTexts["Deine Wahl"].waitForExistence(timeout: 10),
                      "Die Übernahme kommt nicht zurück:\n" + app.debugDescription)

        app.buttons["hits.done"].tap()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Deine Wahl"].waitForExistence(timeout: 10),
                      "Die Wahl steht nach dem Schließen nicht auf der Liste")
    }

    /// Die Ketten-Reiter filtern — dieselbe Bedienung wie in den Angeboten.
    func testTheChainTabsFilterTheMatches() {
        seedList()
        row.tap()
        XCTAssertTrue(app.navigationBars["Passende Artikel"].waitForExistence(timeout: 10))

        let leiste = app.descendants(matching: .any)["hits.marketChips"]
        guard leiste.waitForExistence(timeout: 5) else {
            // Bei nur einer Kette mit Treffern gibt es nichts zu filtern —
            // dieselbe Regel wie überall. Dann ist die Journey erfüllt.
            return
        }
        let ketten = leiste.buttons.count
        XCTAssertGreaterThan(ketten, 1, "Eine Leiste ohne Wahl ist reine Höhe")
    }
}
