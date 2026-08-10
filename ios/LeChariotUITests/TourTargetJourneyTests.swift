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

    /// **Das Vorschläge-Menü, das seit dem 08.08. eingeklappt startet.** Ohne
    /// den Winkel-Knopf ist es nicht zu finden; der Rundgang zeigt genau ihn.
    /// Der alte Anker `.suggestions` hing an den Kacheln, und die stehen im
    /// Vorgabefall gerade nicht da.
    func testTheSuggestionsFrameHighlightsTheToggleAndNotTheTiles() {
        startTourFromSettings()
        advance(to: "Du musst nicht alles tippen")
        settle()
        assertHoleCovers(app.buttons["list.suggestions.toggle"], "der Winkel-Knopf")
    }

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
            waitForCard(toContain: "Du musst nicht alles tippen"),
            "Die Handlung hat nicht weitergeschaltet: \(card.label)"
        )
    }

    /// Dieselbe Zusicherung noch einmal mitten im Rundgang, damit sie nicht nur
    /// für den ersten Rahmen gilt — und an einem Rahmen, dessen Ziel ein Knopf
    /// ist und kein Textfeld.
    func testTheSuggestionsFrameWaitsForTheToggleToo() {
        startTourFromSettings()
        advance(to: "Du musst nicht alles tippen")

        Thread.sleep(forTimeInterval: 4.0)
        XCTAssertTrue(
            card.label.contains("Du musst nicht alles tippen"),
            "Der Rahmen ist von allein weitergegangen: \(card.label)"
        )

        app.buttons["list.suggestions.toggle"].tap()
        XCTAssertTrue(
            waitForCard(toContain: "Im Laden abhaken"),
            "Der Winkel-Knopf hat nicht weitergeschaltet: \(card.label)"
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

/// **Ein Rahmen ohne Ziel darf gar nicht erst zu sehen sein** (10.08.).
///
/// Scotts Meldung aus Build `2026.810.705`: „the tours first stop also gets
/// automatically skipped". Gemessen am Simulator ist es **nicht der erste**
/// Rahmen — der geht nur weiter, wenn man wirklich einen Artikel anlegt. Es ist
/// der **Vorschläge-Rahmen**, und er ist der erste, der sich *von selbst*
/// bewegen kann.
///
/// **Die Lage dazu ist herstellbar, nicht theoretisch.** `surfaceToggle` wird
/// nur gebaut, solange es etwas vorzuschlagen gibt (`surfaceHasContent ||
/// surfaceIsExpanded`). Läuft `ShoppingSuggestions.strip` leer — Sonntagsvorrat
/// ohne gültige Angebote zum Auffüllen, dazu alle acht festen Wörter schon auf
/// der Liste —, dann gibt es den Winkel-Knopf nicht, und der Rahmen, der auf
/// ihn zeigt, hat kein Ziel.
///
/// **Übersprungen werden darf er, gezeigt nicht.** Bis heute stand seine Karte
/// 1,2 s lang da und sprang dann ohne Zutun weiter — das ist die gemeldete
/// Beobachtung. Diese Journey tastet die Karte im 100-ms-Raster ab: Der Text
/// des Rahmens darf **nie** erscheinen, und der Rundgang muss trotzdem
/// durchlaufen.
final class TourSkippedFrameJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    /// Alle acht Wörter aus `ShoppingSuggestions.staples`.
    private let staples = ["Milch", "Brot", "Butter", "Eier",
                           "Käse", "Bananen", "Kaffee", "Nudeln"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingTutorial",
                               "-uiTestingOnboarded", "-uiTestingSunday"]
        app.launch()
    }

    func testAFrameWithoutATargetIsNeverSeen() {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 20))
        feld.tap()
        for wort in staples {
            feld.typeText(wort + "\n")
            Thread.sleep(forTimeInterval: 0.35)
        }
        if app.buttons["list.input.done"].exists { app.buttons["list.input.done"].tap() }
        Thread.sleep(forTimeInterval: 0.8)

        // Die Voraussetzung sagen, statt sie anzunehmen: Ohne diesen Befund
        // prüfte der Rest nur, dass ein Rahmen mit Ziel steht.
        XCTAssertFalse(app.buttons["list.suggestions.toggle"].exists,
                       "Vorbedingung: Der Streifen ist leer, also gibt es den Winkel nicht")

        app.buttons["Einstellungen"].firstMatch.tap()
        app.scrollToTutorialButton().tap()

        let karte = app.staticTexts["tutorial.card"]
        XCTAssertTrue(karte.waitForExistence(timeout: 20))
        XCTAssertTrue(karte.label.contains("Schreib deinen ersten Artikel auf"), karte.label)

        // Rahmen 1 erledigen — ein Wort, das noch nicht auf der Liste steht.
        let imLoch = app.textFields["list.input"]
        XCTAssertTrue(imLoch.waitForExistence(timeout: 15))
        imLoch.tap()
        imLoch.typeText("Zahnstocher\n")

        // Ab hier zählt jedes Zehntel: Die Schonfrist ist 1,2 s, die alte Karte
        // stand genau diese Zeit.
        var gesehen: [String] = []
        let start = Date()
        while Date().timeIntervalSince(start) < 3.5 {
            if karte.exists { gesehen.append(karte.label) }
            Thread.sleep(forTimeInterval: 0.1)
        }

        XCTAssertFalse(
            gesehen.contains { $0.contains("Du musst nicht alles tippen") },
            "Ein Rahmen ohne Ziel darf nicht erst stehen und sich dann selbst überspringen"
        )
        XCTAssertTrue(
            gesehen.contains { $0.contains("Im Laden abhaken") },
            "übersprungen heißt weiter, nicht stehengeblieben — zuletzt: \(gesehen.last ?? "—")"
        )
    }
}
