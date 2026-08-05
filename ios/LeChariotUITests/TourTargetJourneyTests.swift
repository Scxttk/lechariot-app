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

    // MARK: Die beiden Band-Rahmen

    /// Der Angebote-Rahmen zeigt auf die Tab-Leiste — die UIKit zeichnet und
    /// die deshalb keinen Anker trägt, sondern ein aus der sicheren Fläche
    /// hergeleitetes Band (`TutorialOverlay.tabBarBand`). Genau solche
    /// Herleitungen sind schon zweimal danebengegangen (Statusleiste statt
    /// Navigationsleiste, 03.08.); deshalb wird gerechnet statt geglaubt.
    func testTheOffersFrameHighlightsTheTabBar() {
        startTourFromSettings()
        advance(to: "Was diese Woche günstig ist")
        settle()
        assertHoleCovers(app.buttons["Angebote"].firstMatch, "der Angebote-Tab")
    }

    /// Und der letzte Rahmen: die Vereinigung aus Filial-Zeile und
    /// Rundgang-Knopf in den Einstellungen — nach einem Tab-Wechsel, dessen
    /// Anker erst hinter der Überblendung eintreffen.
    func testTheSettingsFrameHighlightsBothItsTargets() {
        startTourFromSettings()
        advance(to: "Hier stellst du alles um")
        settle()
        assertHoleCovers(app.buttons["settings.tutorial"], "der Rundgang-Knopf")
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
    ///
    /// **Gemessen wird die Fläche, in der die Karte danach steht — nicht die
    /// davor.** Die Karte wandert mit dem Loch: Der Angebote-Rahmen leuchtet
    /// die Tab-Leiste unten aus, die Karte steht darüber; der
    /// Einstellungs-Rahmen leuchtet zwei Zeilen in der Bildmitte aus, die
    /// Karte rutscht darunter. Ein vor dem Tipp gemerkter Ausschnitt liegt
    /// nach dem Wechsel über abgedunkeltem Hintergrund und klagte die
    /// Abdunklung an, wo die Karte nur umgezogen ist (05.08. gemessen: alte
    /// Fläche 0,19 — neue Fläche im selben Bild 0,88). Der Bildschirmabzug
    /// entsteht mitten in der Überblendung, der Ausschnitt wird danach
    /// erfragt; die Karte steht zu diesem Zeitpunkt bereits an ihrem Platz.
    func testTheCardSurvivesTheChangeToTheLastFrame() {
        startTourFromSettings()
        advance(to: "Was diese Woche günstig ist")
        settle()

        next.tap()
        // Mitten in der Überblendung: 0,15 s abblenden, 0,10 s halten,
        // 0,20 s aufblenden — siehe `TourTabTransition.standard`.
        Thread.sleep(forTimeInterval: 0.18)
        let shot = XCUIScreen.main.screenshot()

        settle()
        XCTAssertTrue(card.label.contains("Hier stellst du alles um"),
                      "Der Wechsel ist gar nicht angekommen: \(card.label)")
        let helligkeit = meanLuminance(of: shot, in: card.frame)

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
