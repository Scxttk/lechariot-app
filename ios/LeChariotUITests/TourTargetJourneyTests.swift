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
        let restart = app.buttons["settings.tutorial"]
        XCTAssertTrue(restart.waitForExistence(timeout: 20))
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

    /// **Der Rahmen zu den Angaben leuchtete die Eingabezeile aus.**
    ///
    /// Gemessen am 03.08. gegen den Stand `fb8699b`: Das Loch stand auf
    /// `(-16, 723, 418, 186)`, die Schicht, die der Rahmen erklärt, auf
    /// `(311, 569, 75, 32)` — **volle 186 pt daneben**, exakt eine Panelhöhe
    /// tiefer. Ursache war `.move(edge: .bottom)` an der Schicht: Der Anker
    /// nimmt den Versatz der Einblendung mit und wird danach nicht noch einmal
    /// gemeldet. Was Scott sah, war ein Loch, das beim Weiterschalten von allein
    /// nach unten wanderte statt auf sein Ziel.
    func testTheDetailsFrameHighlightsThePanelAndNotTheInputBar() {
        startTourFromSettings()
        advance(to: "Menge, Größe, Sorte")
        settle()
        assertHoleCovers(app.buttons["list.detailPanel.more"], "die Angaben-Schicht")
    }

    /// Die Gegenrichtung, damit der Fix nicht einfach „alles ist ein großes
    /// Loch" heißt: Der erste Rahmen zeigt weiter auf die Eingabezeile.
    func testTheFirstFrameStillHighlightsTheInputBar() {
        startTourFromSettings()
        settle()
        assertHoleCovers(app.textFields["list.input"], "die Eingabezeile")
    }

    // MARK: Der vorletzte Rahmen

    /// **Der Rahmen zur Vorschau leuchtete die Uhr aus.**
    ///
    /// Sein Ziel ist der Knopf „Nächste Woche" oben links. Gemessen gegen
    /// `fb8699b`: Loch `(12, 0, 378, 66)` — die Statusleiste. Der Marker für
    /// `navBarBottom` lag außerhalb des `NavigationStack` und meldete damit die
    /// Kante **über** der Leiste statt darunter. Jetzt: `(12, 0, 378, 230)`.
    func testThePreviewFrameHighlightsTheNextWeekButton() {
        startTourFromSettings()
        advance(to: "Was ab Montag billiger wird")
        settle()
        assertHoleCovers(app.buttons["offers.nextWeek"], "der Knopf „Nächste Woche“")
    }

    // MARK: Der Rahmen, der sich selbst übersprang

    /// **Ein Wort ohne Treffer genügte, und der Rundgang schaltete allein weiter.**
    ///
    /// Der Rahmen „Das günstigste Angebot" hängt am Anker der Treffer-Kachel.
    /// Hat der **erste offene** Artikel diese Woche nirgends ein Angebot, gab es
    /// die Kachel nicht — nur den grauen Satz „Diese Woche nirgends im
    /// Angebot", und der trug keinen Anker. Ohne Ziel überspringt sich ein
    /// Rahmen nach 1,2 s selbst. Auf einer echten Einkaufsliste steht selten
    /// nur Gefundenes.
    ///
    /// Geprüft wird **über die Schonfrist hinaus**: Genau dieser Unterschied
    /// ist die Behauptung.
    func testTheMatchFrameStandsWhenTheFirstItemHasNoOffer() {
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

        advance(to: "Das günstigste Angebot")
        settle()
        XCTAssertTrue(
            card.label.contains("Das günstigste Angebot"),
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

    // MARK: Der Wechsel zum letzten Rahmen

    /// **„Visuell desaströs" in Zahlen: Der Bildschirm wurde ganz schwarz.**
    ///
    /// Der Rundgang blendet für den Tab-Wechsel ab — das ist gewollt, sonst
    /// tauscht die `TabView` ihren Inhalt in einem einzigen Bild aus. Die
    /// Abdunklung lag aber **über allem**, auch über der Karte, die man gerade
    /// liest. Am Simulator Bild für Bild belegt: 0,12 s nach dem Tipp war
    /// nichts als Schwarz auf dem Schirm, Statusleiste eingeschlossen.
    ///
    /// Gemessen wird die mittlere Helligkeit **in der Fläche der Karte**,
    /// unmittelbar nach dem Tipp. Die Karte ist hell (Sandton); gegen
    /// `fb8699b` liegt der Wert bei nahezu 0.
    func testTheCardSurvivesTheChangeToTheLastFrame() {
        startTourFromSettings()
        advance(to: "Was ab Montag billiger wird")
        settle()

        let cardArea = card.frame
        next.tap()
        // Mitten in der Überblendung: 0,15 s abblenden, 0,10 s halten,
        // 0,20 s aufblenden — siehe `TourTabTransition.standard`.
        Thread.sleep(forTimeInterval: 0.18)
        let helligkeit = meanLuminance(of: XCUIScreen.main.screenshot(), in: cardArea)

        XCTAssertGreaterThan(
            helligkeit, 0.35,
            "Während des Wechsels ist die Karte schwarz übermalt (mittlere Helligkeit \(helligkeit))"
        )
    }

    /// Mittlere Helligkeit eines Bildschirmausschnitts, 0…1.
    ///
    /// Der einzige Weg, „sieht desaströs aus" zu einer Zahl zu machen: Das Loch
    /// und die Abdunklung sind keine Elemente, und die Barrierefreiheits-
    /// Hierarchie meldet eine schwarze Fläche darüber gar nicht — die Karte
    /// „existiert" auch dann, wenn niemand sie sehen kann.
    private func meanLuminance(of shot: XCUIScreenshot, in rect: CGRect) -> Double {
        guard let cg = shot.image.cgImage else { return -1 }
        let scaleX = Double(cg.width) / Double(shot.image.size.width)
        let scaleY = Double(cg.height) / Double(shot.image.size.height)
        let px = CGRect(x: rect.minX * scaleX, y: rect.minY * scaleY,
                        width: rect.width * scaleX, height: rect.height * scaleY)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard px.width > 1, px.height > 1, let cut = cg.cropping(to: px) else { return -1 }

        let w = cut.width, h = cut.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return -1 }
        ctx.draw(cut, in: CGRect(x: 0, y: 0, width: w, height: h))

        var summe = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            summe += (0.2126 * Double(pixels[i])
                      + 0.7152 * Double(pixels[i + 1])
                      + 0.0722 * Double(pixels[i + 2])) / 255
        }
        return summe / Double(w * h)
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
