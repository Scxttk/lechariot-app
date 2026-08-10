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
/// weggefallen ist** — der Rundgang war auf drei Rahmen geschrumpft.
///
/// **Seit dem 09.08. sind es sechs, und jeder bis auf den letzten wartet auf
/// eine Handlung des Nutzers.** Damit kommt hier eine zweite Frage dazu, die
/// vorher keine war: *Geht ein Rahmen ohne die Handlung wirklich nicht weiter?*
/// Auch das ist eine Rechnung und keine Meinung — gewartet wird über beide
/// Fristen des Rundgangs hinaus (Einschwingen 0,7 s, Schonfrist 1,2 s), und
/// danach muss derselbe Rahmen stehen.
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

    /// Bis zu dem Rahmen mitmachen, dessen Titel passt. Über die Karte und nicht
    /// über eine Zählung: Der Rundgang hat mit und ohne Filialen verschiedene
    /// Längen, und ein „achtmal tippen" wäre still falsch, sobald einer dazukommt.
    ///
    /// **Mitmachen statt blättern** (09.08.): „Weiter" gibt es nicht mehr, der
    /// Weg zum nächsten Rahmen führt durch die Handlung, um die er bittet.
    private func advance(to title: String, maxSteps: Int = 9) {
        for _ in 0..<maxSteps {
            if card.label.contains(title) { return }
            guard app.doTheTourDeed() else { break }
        }
        XCTFail("Rahmen „\(title)“ nicht erreicht, zuletzt: \(card.label)")
    }

    /// Wartet über die Schonfrist (1,2 s) und das Einschwing-Fenster hinaus,
    /// damit gemessen wird, was stehen bleibt — nicht was gerade fliegt.
    private func settle() {
        Thread.sleep(forTimeInterval: 2.2)
    }

    /// Wartet, bis die Karte diesen Rahmen trägt. `waitForExistence` hilft hier
    /// nicht: Das Element steht die ganze Zeit da, nur sein Text wechselt.
    private func waitForCard(toContain title: String, timeout: TimeInterval = 8) -> Bool {
        let frist = Date().addingTimeInterval(timeout)
        while Date() < frist {
            if card.label.contains(title) { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
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

    /// Der erste Rahmen zeigt auf die Eingabezeile — die Gegenrichtung zu
    /// allem, was unten steht, damit „das Loch deckt sein Ziel" nicht einfach
    /// „alles ist ein großes Loch" heißt.
    func testTheFirstFrameStillHighlightsTheInputBar() {
        startTourFromSettings()
        settle()
        assertHoleCovers(app.textFields["list.input"], "die Eingabezeile")
    }

    /// **Das Loch bleibt im Bildschirm** (09.08.).
    ///
    /// Am Bild gemessen: Die Eingabezeile liegt über die volle Breite, mit den
    /// acht Punkten Luft ringsherum stand das Loch von **−16 bis 418** auf einem
    /// 402 pt breiten Gerät — die zwei runden Ecken lagen draußen, und was man
    /// sah, war ein Balken am unteren Rand statt einer Hervorhebung.
    func testTheHoleNeverRunsOffTheScreen() {
        startTourFromSettings()
        settle()

        XCTAssertTrue(hole.exists)
        let bildschirm = app.frame
        XCTAssertGreaterThanOrEqual(hole.frame.minX, bildschirm.minX,
                                    "Das Loch \(hole.frame) hängt links heraus")
        XCTAssertLessThanOrEqual(hole.frame.maxX, bildschirm.maxX,
                                 "Das Loch \(hole.frame) hängt rechts heraus")
    }

    // MARK: Die zwei Stellen aus Scotts Liste (Bedienrunde 08.08., Punkt A)

    /// **Der Rahmen zum Vorschläge-Menü ist am 10.08. ausgefallen**, und mit
    /// ihm die zwei Journeys, die hier standen (Loch auf dem Winkel-Knopf,
    /// Warten auf seinen Tipp). Der Knopf existiert nicht mehr: Die Fläche
    /// steht von selbst, sobald die Tastatur kommt (Punkt E). Was der Rundgang
    /// stattdessen zeigen soll, entscheidet Punkt F.

    /// **Die Schlusskarte steht auf der Vorschau und leuchtet die Hinweiszeile
    /// aus** — die aus #90, die sagt, dass diese Preise noch nicht gelten. Das
    /// ist die zweite Stelle aus Scotts Liste, und der Weg dahin sind zwei
    /// Tipper des Nutzers: Tab-Leiste, dann „Nächste Woche".
    func testTheTourEndsOnTheNextWeekNotice() {
        startTourFromSettings()
        advance(to: "Das war")
        settle()
        assertHoleCovers(app.staticTexts["nextWeek.explainer"], "die Hinweiszeile der Vorschau")
        XCTAssertTrue(app.buttons["tutorial.next"].exists,
                      "und die Schlusskarte hat ihren einen Knopf")
    }

    // MARK: Der Nutzer tippt selbst — und nur er

    /// **Der Nachweis für den Prinzipwechsel: Ein Rahmen geht ohne die Handlung
    /// nicht weiter.**
    ///
    /// Gemessen wird gegen die zwei Fristen, die der Rundgang kennt — das
    /// Einschwing-Fenster (0,7 s) und die Schonfrist (1,2 s), nach der sich ein
    /// Rahmen **ohne Ziel** selbst überspringt. Wer länger wartet als beide und
    /// denselben Rahmen vorfindet, hat die Zusicherung: Hier passiert nichts von
    /// allein.
    ///
    /// Drei Sachen zusammen, weil sie erst zusammen etwas beweisen: Es gibt
    /// keinen „Weiter"-Knopf, Warten schaltet nicht weiter, und die Handlung
    /// schaltet weiter. Ohne die dritte wäre ein Rundgang, der überhaupt nicht
    /// mehr weitergeht, grün.
    func testAFrameWaitsForTheDeedAndNothingElse() {
        startTourFromSettings()
        XCTAssertTrue(card.label.contains("Schreib deinen ersten Artikel auf"),
                      "Der erste Rahmen steht nicht: \(card.label)")

        XCTAssertFalse(app.buttons["tutorial.next"].exists,
                       "Ein Rahmen, der auf eine Handlung wartet, hat kein „Weiter“")

        // Weit über beide Fristen hinaus: 0,7 s Einschwingen + 1,2 s Schonfrist.
        Thread.sleep(forTimeInterval: 4.0)
        XCTAssertTrue(
            card.label.contains("Schreib deinen ersten Artikel auf"),
            "Der Rahmen ist von allein weitergegangen: \(card.label)"
        )

        // Und ein Tipp **daneben** zählt auch nicht. Über eine Koordinate und
        // nicht über ein Element: Gemeint ist „irgendwo außerhalb des Lochs",
        // und ein benanntes Element wäre eine Aussage über dieses Element.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(
            card.label.contains("Schreib deinen ersten Artikel auf"),
            "Ein Tipp außerhalb des Lochs hat weitergeschaltet: \(card.label)"
        )

        // Jetzt die Handlung, um die der Rahmen bittet.
        let feld = app.textFields["list.input"]
        feld.tap()
        feld.typeText("Zahnstocher\n")

        XCTAssertTrue(
            waitForCard(toContain: "Im Laden abhaken"),
            "Die Handlung hat nicht weitergeschaltet: \(card.label)"
        )
    }

    /// **Der erste Rahmen lud zum Tippen ein und ließ es nicht zu.**
    ///
    /// `ContentView` sperrte die ganze `TabView`, solange der Rundgang läuft —
    /// samt Eingabefeld. Gegen `fb8699b` fällt diese Journey mit dem Satz, der
    /// in dieser Runde schon einmal die Ursache war:
    /// `Failed to synthesize event: Neither element nor any descendant has
    /// keyboard focus` — und im Baum stand `TextField … Disabled`.
    ///
    /// Seit dem 09.08. ist das Tippen **der Weg weiter** und nicht mehr nur
    /// erlaubt; der Nachweis, dass der Artikel wirklich auf der Liste landet,
    /// bleibt trotzdem hier.
    func testTheFirstFrameReallyLetsYouType() {
        startTourFromSettings()
        let field = app.textFields["list.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Zahnstocher\n")

        XCTAssertTrue(app.buttons["Zahnstocher"].waitForExistence(timeout: 10),
                      "Was der Rahmen zu tippen einlädt, muss auch auf der Liste landen")
    }

    /// Der Riegel dazu: Die Tab-Leiste bleibt auch auf einem Mitmach-Rahmen
    /// zu. Ohne diesen Fall wäre die Lockerung oben ein Loch in der Führung.
    func testTheTabBarStaysShutEvenOnAHandsOnFrame() {
        startTourFromSettings()
        XCTAssertTrue(card.label.contains("Schreib deinen ersten Artikel auf"),
                      card.label)
        openTab("Angebote")
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].exists,
                      "die Tab-Leiste darf während der Führung nicht wechseln")
        XCTAssertTrue(card.exists, "und der Rundgang muss stehen geblieben sein")
    }
}
