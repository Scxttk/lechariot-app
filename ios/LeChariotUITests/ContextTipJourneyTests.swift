import XCTest

/// Die Einmal-Tipps, am Beispiel des ersten: „Nächste Woche" im Angebote-Tab.
///
/// Geprüft wird der ganze Vertrag, nicht nur das Erscheinen: Die Sprechblase
/// steht beim ersten Besuch — und **nur** beim ersten. Der zweite Teil läuft
/// über einen echten Neustart mit `-uiTestingKeepState`, denn genau da liegt
/// die Klasse Fehler, um die es geht: Ein Tipp, der wiederkommt, ist
/// schlimmer als keiner.
///
/// `-uiTestingTips` schaltet die Tipps ein; ohne den Schalter bleiben sie
/// unter `-uiTesting` aus, damit keine der bestehenden Journeys eine
/// Sprechblase im Weg hat (siehe `UITestSupport.showsContextTips`).
final class ContextTipJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Der Titel der Sprechblase — derselbe Text wie in `NextWeekContextTip`.
    private var tipTitle: XCUIElement {
        app.staticTexts["Was ab Montag billiger wird"]
    }

    func testTheNextWeekTipShowsOnceAndOnlyOnce() {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingTips"]
        app.launch()

        // Auf der Liste steht noch keine Sprechblase — der Angebote-Moment
        // gehört dem Angebote-Tab.
        XCTAssertFalse(tipTitle.exists)

        app.tabBars.buttons["Angebote"].tap()
        XCTAssertTrue(
            tipTitle.waitForExistence(timeout: 5),
            "Der erste Besuch im Angebote-Tab zeigt den Vorschau-Tipp nicht"
        )

        // Neustart mit behaltenem Zustand: Der Tipp gilt als gezeigt und
        // darf nicht wiederkommen — auch wenn niemand ihn weggedrückt hat.
        app.terminate()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded",
                               "-uiTestingKeepState", "-uiTestingTips"]
        app.launch()
        app.tabBars.buttons["Angebote"].tap()
        XCTAssertTrue(
            app.navigationBars["Angebote"].waitForExistence(timeout: 5),
            "Der Angebote-Tab steht nach dem Neustart nicht"
        )
        XCTAssertFalse(
            tipTitle.waitForExistence(timeout: 2),
            "Der Tipp kam nach dem Neustart wieder — genau das darf nie passieren"
        )
    }

    /// Ohne `-uiTestingTips` bleibt alles still — das ist der Riegel, der die
    /// übrigen 135 Journeys vor Sprechblasen schützt, also verdient er eine
    /// eigene Prüfung.
    func testWithoutTheSwitchNoTipAppears() {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
        app.tabBars.buttons["Angebote"].tap()
        XCTAssertTrue(app.navigationBars["Angebote"].waitForExistence(timeout: 5))
        XCTAssertFalse(tipTitle.waitForExistence(timeout: 2))
    }

    /// Der Tipp der **Liste**, am Beispiel der Angebotszeile. Eigene Journey,
    /// weil die Liste eine andere Fläche ist als der Angebote-Tab — und weil
    /// genau diese Lücke einmal verdeckt hat, dass gar kein Tipp erschien.
    ///
    /// Er kommt erst auf der **ruhenden** Liste: Solange der Tipp-Fluss läuft,
    /// tippt jemand, und dazwischen spricht niemand.
    func testTheListShowsItsTipOnlyOnceTheFlowIsClosed() {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingTips"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))

        let tip = app.staticTexts["Mehr als das eine Angebot"]
        app.buttons["Milch hinzufügen"].tap()

        let panel = app.buttons["list.detailPanel.more"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5),
                      "Das Mengen-Menü geht beim Anlegen von selbst auf")
        XCTAssertFalse(tip.exists, "Während getippt wird, spricht niemand dazwischen")

        app.dragTheListUp()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(tip.waitForExistence(timeout: 10),
                      "Die ruhende Liste mit einem Treffer ist der Moment")
    }

    /// Die Ernährungsfrage: **nicht** beim ersten Besuch, beim zweiten schon —
    /// und nach der Antwort nie wieder. Der zweite Besuch ist die zweite
    /// Sitzung (`ContextTipStore.offersAppeared` zählt je Sitzung einmal),
    /// deshalb läuft die Journey über einen echten Neustart.
    func testTheDietQuestionComesOnTheSecondVisitAndAnswersOnce() {
        // Die Überschrift der Karte als Anker: Ein Container-Bezeichner über
        // Chips und Knöpfen ist nicht verlässlich als Element zu greifen, die
        // Frage selbst schon.
        let card = app.staticTexts["Isst du irgendetwas nicht?"]

        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingTips"]
        app.launch()
        app.tabBars.buttons["Angebote"].tap()
        XCTAssertTrue(app.navigationBars["Angebote"].waitForExistence(timeout: 15))
        XCTAssertFalse(card.waitForExistence(timeout: 2),
                       "Beim ersten Besuch gehört der Moment dem Tab selbst")

        app.terminate()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded",
                               "-uiTestingKeepState", "-uiTestingTips"]
        app.launch()
        app.tabBars.buttons["Angebote"].tap()
        // Erst wenn die Angebote geladen sind, steht die Liste still. Vorher
        // baut sie sich noch um, und ein Element, das eben noch da war, ist im
        // nächsten Abbild wieder weg — das kostete diese Journey zwei Läufe.
        XCTAssertTrue(app.buttons["offers.row"].firstMatch.waitForExistence(timeout: 20),
                      "Die Angebote müssen geladen sein")
        XCTAssertTrue(card.waitForExistence(timeout: 15),
                      "Der zweite Besuch ist der Moment der Frage")

        // Ohne Auswahl heißt der Knopf, was er bedeutet — und mit Auswahl
        // ändert er seine Beschriftung. Beides ist Vertrag, siehe
        // `DietPromptCard`.
        let done = app.buttons["offers.dietPrompt.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10),
                      "Der Knopf gehört zur Karte")
        XCTAssertEqual(done.label, "Ich esse alles")
        app.buttons["offers.dietPrompt.vegetarisch"].tap()
        XCTAssertEqual(done.label, "Fertig",
                       "Mit einer Angabe ist \u{201E}Ich esse alles\u{201C} nicht mehr wahr")
        done.tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5),
                      "Die Antwort beendet die Frage")

        // Und sie bleibt beendet: Eine Frage, die nach dem Neustart wieder
        // dasteht, hat die Antwort nicht ernst genommen.
        app.terminate()
        app.launch()
        app.tabBars.buttons["Angebote"].tap()
        XCTAssertTrue(app.navigationBars["Angebote"].waitForExistence(timeout: 15))
        XCTAssertFalse(card.waitForExistence(timeout: 2),
                       "Die Frage kam nach dem Neustart wieder")
    }
    /// **Die Umkehrung von `testTheTourCoversTheAppCompletelyWhileItRuns`.**
    ///
    /// Der Rundgang legte sich modal über die App: Sperrflächen außen, ein Loch
    /// innen, das „Mehr"-Menü wurde gar nicht erst gebaut. Genau das war die
    /// Zusicherung, die diese Journey bis zum 10.08. festhielt — und genau das
    /// ist mit dem Abriss weg. Die neue Zusage lautet umgekehrt: **Während ein
    /// Schild steht, bleibt die App vollständig bedienbar.**
    ///
    /// Sie wird hier nicht behauptet, sondern durchgetippt: Tab wechseln,
    /// Menü öffnen, Artikel anlegen — alles, während das Schild dasteht.
    func testTheAppStaysUsableWhileASignStands() {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingTips"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))

        app.tabBars.buttons["Angebote"].tap()
        XCTAssertTrue(tipTitle.waitForExistence(timeout: 15), "Ohne Schild prüft die Journey nichts")

        // 1. Die Tab-Leiste trägt weiter. Der Rundgang schob hier zurück.
        app.tabBars.buttons["Liste"].tap()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 10),
                      "Der Tab-Wechsel muss durchgehen, während ein Schild steht")

        app.tabBars.buttons["Angebote"].tap()
        XCTAssertTrue(tipTitle.waitForExistence(timeout: 10),
                      "…und das Schild steht danach noch")

        // 2. Das ✗ nimmt das Schild weg, ohne sonst etwas anzufassen.
        let close = app.buttons["tip.dismiss"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Das Schild trägt sein ✗")
        close.tap()
        XCTAssertTrue(tipTitle.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Angebote"].exists,
                      "Weggetippt heißt: Schild weg, Bildschirm bleibt")

        // 3. Und das Ziel, auf das es zeigt, ist wirklich erreichbar — der
        //    Rundgang hat an dieser Stelle einen Riegel gebraucht, das Schild
        //    braucht keinen.
        let vorschau = app.buttons["offers.nextWeek"]
        XCTAssertTrue(vorschau.waitForExistence(timeout: 15))
        vorschau.tap()
        XCTAssertTrue(app.navigationBars["Nächste Woche"].waitForExistence(timeout: 20),
                      "Der Weg, den das Schild nennt, muss offen sein")
    }
}
