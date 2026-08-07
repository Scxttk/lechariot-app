import XCTest

/// **Zeigt jeder Rahmen des Rundgangs auf das, wovon er redet?**
///
/// Scotts Feldtest von Build `2026.0803.1440` meldete zwei Dinge, die von
/// außen wie eines aussehen: „Es gibt einen automatischen Weiterschritt zum
/// nächsten Punkt, und der sieht verbuggt aus" (Anfang) und „vorletzter →
/// letzter Punkt: visuell desaströs".
///
/// **Warum keine der bestehenden Journeys das gefunden hat:** Ein Loch ist ein
/// Stück *nicht* gezeichnete Abdunklung — kein Element, kein Rahmen, nichts,
/// worauf `XCTAssert` zeigen könnte. Alle Prüfungen bis hierher lasen deshalb
/// die **Karte** („steht der Rahmen noch?") und keine einzige das **Loch**.
/// Beide gemeldeten Fehler waren mit stehender Karte vereinbar.
///
/// Die Messstelle dafür ist `tutorial.hole` — eine durchsichtige Fläche, die
/// im Testlauf genau auf dem Loch liegt (siehe `TutorialOverlay.holeProbe`).
/// Damit ist „das Loch deckt sein Ziel" eine Rechnung auf zwei Rechtecken.
///
/// **Am 06.08. sind vier dieser Journeys weggefallen, weil ihr Gegenstand
/// weggefallen ist:** Der Rundgang hat statt neun Rahmen noch drei, und alle
/// drei spielen auf der Liste. Damit gibt es die Angaben-Schicht, die Vorschau
/// und die Treffer-Kachel als Rahmen nicht mehr — und auch keinen Tab-Wechsel
/// mehr, dessen Überblendung die Karte schwarz übermalen könnte. Was hier
/// steht, ist das, was der Rundgang noch behauptet.
final class TourTargetJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func startTourFromSettings(threeChains: Bool = true) {
        var args = ["-uiTesting", "-uiTestingTutorial", "-uiTestingOnboarded"]
        if threeChains { args.append("-uiTestingOnboardedThreeChains") }
        app.launchArguments = args
        app.launch()
        openTab("Einstellungen")
        let restart = app.scrollToTutorialButton()
        restart.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 20))
    }

    private var card: XCUIElement { app.staticTexts["tutorial.card"] }
    private var next: XCUIElement { app.buttons["tutorial.next"] }
    /// Das gezeichnete Loch. `images`, weil die Sonde eine Fläche ist und keine
    /// Beschriftung trägt, die man vorlesen wollte.
    private var hole: XCUIElement { app.images["tutorial.hole"] }

    private func openTab(_ name: String) {
        app.buttons[name].firstMatch.tap()
    }

    /// Bis zu dem Rahmen blättern, dessen Titel passt. Über die Karte und nicht
    /// über eine Zählung: Der Rundgang hat mit und ohne Filialen verschiedene
    /// Längen, und ein „achtmal tippen" wäre still falsch, sobald einer dazukommt.
    private func advance(to title: String, maxSteps: Int = 12) {
        for _ in 0..<maxSteps {
            if card.label.contains(title) { return }
            guard next.exists else { break }
            next.tap()
            Thread.sleep(forTimeInterval: 0.9)
        }
        XCTFail("Rahmen „\(title)“ nicht erreicht, zuletzt: \(card.label)")
    }

    /// Wartet über die Schonfrist (1,2 s) und das Einschwing-Fenster hinaus,
    /// damit gemessen wird, was stehen bleibt — nicht was gerade fliegt.
    private func settle() {
        Thread.sleep(forTimeInterval: 2.2)
    }

    private func assertHoleCovers(_ target: XCUIElement, _ what: String) {
        XCTAssertTrue(hole.exists, "Kein Loch — der Rahmen zeigt auf nichts")
        XCTAssertTrue(target.exists, "\(what) steht gar nicht auf dem Bildschirm")
        // Ein Punkt Toleranz: Die Kante der Hervorhebung liegt **auf** dem
        // Loch und nimmt ihm innen anderthalb Punkte weg, siehe `SpotlightRing`.
        let outer = hole.frame.insetBy(dx: -2, dy: -2)
        XCTAssertTrue(
            outer.contains(target.frame),
            "Das Loch \(hole.frame) deckt \(what) \(target.frame) nicht"
        )
    }

    // MARK: Der Anfang

    /// **Der Plan-Rahmen muss die Karte ausleuchten, von der er redet.**
    ///
    /// Der Vorfahre dieses Tests fing den Fund vom 03.08.: Ein Loch, das um
    /// eine ganze Panelhöhe neben seinem Ziel stand, weil der Anker den
    /// Versatz einer Einblendung mitgenommen hatte. Der Angaben-Rahmen ist mit
    /// der Kürzung vom 05.08. in die Kontext-Tipps gezogen; die Rechnung
    /// „Loch deckt Ziel" wird jetzt am Plan-Rahmen geführt — dem Rahmen mit
    /// dem Kernversprechen, dessen Karte er selbst erst herbeisät.
    func testThePlanFrameHighlightsThePlanCard() {
        startTourFromSettings()
        advance(to: "Ein Einkauf, ein Markt")
        settle()
        // Die Kopfzeile der Karte ist das messbare Element — die Karte selbst
        // trägt keinen Bezeichner, ihre Zusammenfassung schon (siehe
        // `AccessibilityAuditTests.testThePlanCardIsReadAsAWhole`).
        let summary = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@",
                                  "Am besten zu", "Kein Markt hat diese Woche"))
            .firstMatch
        assertHoleCovers(summary, "die Plan-Karte")
    }

    /// Die Gegenrichtung, damit der Fix nicht einfach „alles ist ein großes
    /// Loch" heißt: Der erste Rahmen zeigt weiter auf die Eingabezeile.
    func testTheFirstFrameStillHighlightsTheInputBar() {
        startTourFromSettings()
        settle()
        assertHoleCovers(app.textFields["list.input"], "die Eingabezeile")
    }

    // MARK: Der Rahmen, der sich selbst übersprang

    /// **Ein Wort ohne Treffer durfte den Rundgang nie weiterschalten.**
    ///
    /// Der alte Treffer-Rahmen hing am Anker der Treffer-Kachel; hatte der
    /// erste offene Artikel kein Angebot, übersprang er sich nach 1,2 s
    /// selbst. Sein Inhalt steckt jetzt im Plan-Rahmen, und der hängt an der
    /// Plan-Karte — die er über seine Beispiel-Artikel selbst herbeisät. Ob
    /// diese Rettung trägt, prüft genau dieser Fall: erster Artikel ohne
    /// Treffer, **über die Schonfrist hinaus** gewartet.
    func testThePlanFrameStandsWhenTheFirstItemHasNoOffer() {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded",
                               "-uiTestingOnboardedThreeChains", "-uiTestingTutorial"]
        app.launch()
        let field = app.textFields["list.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        field.tap()
        // Ein Wort, zu dem der Vorrat garantiert nichts hat — und das damit
        // der erste offene Artikel ohne Treffer ist.
        field.typeText("Zahnstocher\n")
        Thread.sleep(forTimeInterval: 0.8)
        app.swipeDown()

        openTab("Einstellungen")
        let restart = app.buttons["settings.tutorial"]
        XCTAssertTrue(restart.waitForExistence(timeout: 20))
        restart.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 20))

        advance(to: "Ein Einkauf, ein Markt")
        settle()
        XCTAssertTrue(
            card.label.contains("Ein Einkauf, ein Markt"),
            "Der Rahmen hat sich selbst übersprungen: \(card.label)"
        )
    }

    // MARK: „Probier es gleich aus"

    /// **Der erste Rahmen lud zum Tippen ein und ließ es nicht zu.**
    ///
    /// `ContentView` sperrte die ganze `TabView`, solange der Rundgang läuft —
    /// samt Eingabefeld. Gegen `fb8699b` fällt diese Journey mit dem Satz, der
    /// in dieser Runde schon einmal die Ursache war:
    /// `Failed to synthesize event: Neither element nor any descendant has
    /// keyboard focus` — und im Baum stand `TextField … Disabled`.
    func testTheFirstFrameReallyLetsYouType() {
        startTourFromSettings()
        let field = app.textFields["list.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Zahnstocher\n")
        Thread.sleep(forTimeInterval: 0.8)

        XCTAssertTrue(app.buttons["Zahnstocher"].waitForExistence(timeout: 10),
                      "Was der Rahmen zu tippen einlädt, muss auch auf der Liste landen")
        XCTAssertTrue(card.label.contains("Schreib auf, was du brauchst"),
                      "Mitmachen schaltet nicht weiter — jeder Rahmen wartet auf „Weiter“")
    }

    /// Der Riegel dazu: Die Tab-Leiste bleibt auch auf einem Mitmach-Rahmen
    /// zu. Ohne diesen Fall wäre die Lockerung oben ein Loch in der Führung.
    func testTheTabBarStaysShutEvenOnAHandsOnFrame() {
        startTourFromSettings()
        XCTAssertTrue(card.label.contains("Schreib auf, was du brauchst"))
        openTab("Angebote")
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].exists,
                      "die Tab-Leiste darf während der Führung nicht wechseln")
        XCTAssertTrue(card.exists, "und der Rundgang muss stehen geblieben sein")
    }
}
