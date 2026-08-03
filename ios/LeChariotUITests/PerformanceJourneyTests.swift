import XCTest

/// **Das Messgeschirr.** Was die vier Kern-Bildschirme kosten, in Zahlen.
///
/// Ausgelöst von Scotts Meldung zu Build `2026.0801.1951`: „einige Stellen
/// ruckeln", ohne Ort und ohne Messung. Die Lehre aus Côte d'OS steht im
/// Backlog und gilt hier genauso — **erst ein Messstand, dann Optimierung.**
/// Wer ohne Zahl optimiert, ändert etwas und weiß hinterher nicht, ob es
/// besser wurde.
///
/// Drei Metriken je Strecke:
///
/// - `XCTOSSignpostMetric.scrollDecelerationMetric` — Hitches beim Ausrollen
///   einer Wischgeste. Das ist das, was ein Mensch „ruckelt" nennt: nicht ein
///   langsamer Durchschnitt, sondern einzelne Bilder, die zu spät kommen.
/// - `XCTCPUMetric(application:)` — was die App dabei rechnet.
/// - `XCTMemoryMetric(application:)` — und was sie dabei behält.
///
/// **Der Vorrat ist ein Prospekt in echter Größe.** Mit den sieben
/// Fixture-Zeilen ruckelt nichts, und eine Messung darauf wäre eine Zahl über
/// nichts. `-uiTestingBulkOffers 400` legt 400 Zeilen je Kette an, also 1 200
/// für die laufende Woche und 600 für die Vorschau — dieselbe Größenordnung
/// wie die 1 125 Zeilen, die eine Penny-Filiale am 01.08. in der Produktion
/// trug.
///
/// **Läuft lokal, nicht in CI.** Für die App gibt es ohnehin keinen
/// Test-Workflow (nur `woerterbuch-sync.yml`); wenn einer kommt, gehört diese
/// Klasse ausgeschlossen. Simulator-Zeiten auf geteilten Runnern sind Rauschen,
/// und ein Messstand, dem niemand glaubt, wird abgeschaltet statt gelesen.
///
/// **Vergleichbar wird eine Zahl nur gegen eine andere vom selben Gerät.** Die
/// Grundwerte liegen in `xcbaselines` und wurden auf dem iPhone 17 Pro dieses
/// Macs aufgenommen. Wer auf einem anderen misst, bekommt andere und soll sie
/// nicht gegen diese halten.
final class PerformanceJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    /// Zeilen je Kette. Drei Ketten, also das Dreifache in der Liste.
    ///
    /// Über die Umgebung drehbar (`LECHARIOT_PERF_BULK`), weil die
    /// interessanteste Frage an einen Messstand die nach der **Steigung** ist:
    /// Kostet die doppelte Prospektlänge doppelt so viel, ist etwas nicht faul,
    /// sondern nicht faul *genug*. Ohne Knopf misst ein Messstand genau einen
    /// Fall — und der Grundwert im Repo ist der bei 400.
    private var bulk: Int {
        Int(ProcessInfo.processInfo.environment["LECHARIOT_PERF_BULK"] ?? "") ?? 400
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(extraArguments: [String] = []) {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded",
                               "-uiTestingOnboardedThreeChains",
                               "-feature.nextWeekPreview",
                               "-uiTestingBulkOffers", "\(bulk)"] + extraArguments
        app.launch()
    }

    private var metrics: [XCTMetric] {
        [
            XCTOSSignpostMetric.scrollDecelerationMetric,
            XCTCPUMetric(application: app),
            XCTMemoryMetric(application: app),
        ]
    }

    /// Fünf Durchläufe statt der voreingestellten fünf — ausdrücklich gesetzt,
    /// damit die Zahl im Test steht und nicht in einer Voreinstellung, die
    /// Xcode einmal ändern kann.
    private var options: XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        return options
    }

    // MARK: Die vier Strecken

    /// **Liste.** Der Bildschirm, für den es die App gibt — und der einzige mit
    /// Treffer-Zeilen, die je Eintrag über den ganzen Prospekt suchen.
    func testListeScrolling() {
        launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 30))
        seedList(with: ["Milch", "Butter", "Kaffee", "Joghurt", "Käse", "Nudeln"])

        measure(metrics: metrics, options: options) {
            scrollAround(app.collectionViews.firstMatch)
        }
    }

    /// **Angebote.** Die lange Liste: 1 200 Zeilen, gruppiert nach Markt, mit
    /// Top-Deals und Bildplätzen.
    func testAngeboteScrolling() {
        launch()
        openTab("Angebote")
        XCTAssertTrue(app.staticTexts["Top-Deals der Woche"].waitForExistence(timeout: 30),
                      "die Angebote sind nicht geladen:\n\(app.debugDescription)")

        measure(metrics: metrics, options: options) {
            scrollAround(app.collectionViews.firstMatch)
        }
    }

    /// **Vorschau, in ihrer neuen vollen Form** — mit Markt-Leiste, Suche und
    /// Filter, und mit dem Datumszusatz auf jeder Zeile, den die laufende Woche
    /// nicht hat.
    func testVorschauScrolling() {
        launch()
        openTab("Angebote")
        let entry = app.buttons["offers.nextWeek"]
        XCTAssertTrue(entry.waitForExistence(timeout: 30))
        entry.tap()
        XCTAssertTrue(app.navigationBars["Nächste Woche"].waitForExistence(timeout: 20))

        measure(metrics: metrics, options: options) {
            scrollAround(app.collectionViews.firstMatch)
        }
    }

    /// **Rundgang.** Kein Scrollen, sondern sieben Rahmen mit einem Loch, das
    /// über den Bildschirm wandert — die einzige Strecke der App, die dauerhaft
    /// eine Maske über allem hält.
    ///
    /// Hier steht `scrollDecelerationMetric` bewusst **nicht** in der Liste: Es
    /// wird nicht gescrollt, die Metrik hätte nichts zu messen und trüge einen
    /// leeren Grundwert ins Repo.
    func testRundgangStepping() {
        launch(extraArguments: ["-uiTestingTutorial"])
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 30))

        // Der ganze Weg liegt **im** Block, nicht davor: Der Rundgang endet auf
        // der Liste (`ContentView` stellt den Tab zurück), der zweite Durchlauf
        // fände den Knopf sonst gar nicht mehr.
        measure(metrics: [XCTCPUMetric(application: app), XCTMemoryMetric(application: app)],
                options: options) {
            openTab("Einstellungen")
            let restart = settingsTutorialButton()
            restart.tap()
            var frames = 0
            while app.buttons["tutorial.next"].exists && frames < 12 {
                app.buttons["tutorial.next"].tap()
                frames += 1
            }
            XCTAssertGreaterThan(frames, 0, "der Rundgang ist gar nicht gelaufen")
        }
    }

    // MARK: Handgriffe

    /// Zwei schnelle Wischer hinunter und einer hinauf. Schnell, weil die
    /// Metrik das **Ausrollen** misst — eine langsame Geste rollt nicht aus
    /// und liefert keinen einzigen Messwert.
    private func scrollAround(_ element: XCUIElement) {
        element.swipeUp(velocity: .fast)
        element.swipeUp(velocity: .fast)
        element.swipeDown(velocity: .fast)
    }

    private func openTab(_ name: String) {
        let inBar = app.tabBars.buttons[name]
        let tab = inBar.exists ? inBar : app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 30), "Tab \(name) fehlt")
        tab.tap()
    }

    /// Der Hilfe-Abschnitt liegt unten in den Einstellungen; auf dem iPhone
    /// muss dafür gescrollt werden.
    private func settingsTutorialButton() -> XCUIElement {
        let restart = app.buttons["settings.tutorial"]
        var swipes = 0
        while !restart.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(restart.waitForExistence(timeout: 20),
                      "der Rundgang-Knopf fehlt:\n\(app.debugDescription)")
        return restart
    }

    /// **Nach jedem Artikel das Mengen-Menü schließen.**
    ///
    /// Seit [UI-8] geht es beim Anlegen von selbst auf und liegt über der
    /// Eingabezeile; der nächste `typeText` lief deshalb ins Leere („Neither
    /// element nor any descendant has keyboard focus", ab dem *zweiten*
    /// Artikel). Die Fehlermeldung zeigt auf die Tastatur und die Ursache ist
    /// ein Blatt — dieselbe Falle, in die schon zwei Journeys am 01.08. gelaufen
    /// sind. Für diesen Messlauf ist das Menü ein Zwischenschritt.
    private func seedList(with items: [String]) {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 20), "kein Eingabefeld:\n\(app.debugDescription)")
        // **Seit dem 03.08. gibt es hier nichts mehr wegzuklicken.** Das
        // Mengen-Menü ist kein Blatt mehr, sondern eine Schicht über der
        // Eingabezeile: Der Fokus bleibt im Feld, das nächste Wort ersetzt sie
        // einfach. Der Messlauf tippt deshalb in einem Zug durch — genau das
        // ist die Strecke, um die es geht.
        feld.tap()
        for item in items {
            feld.typeText(item + "\n")
        }
        // Am Ende einmal die Schicht schließen, damit der eigentliche Messlauf
        // dieselbe Liste vor sich hat wie vorher.
        let panel = app.buttons["list.detailPanel.more"]
        if panel.waitForExistence(timeout: 3) {
            app.swipeUp()
            _ = panel.waitForNonExistence(timeout: 3)
        }
    }
}
