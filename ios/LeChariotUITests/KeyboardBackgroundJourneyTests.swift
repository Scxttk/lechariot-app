import XCTest

/// Bildschirme mit offener Tastatur, als Bild geprüft.
///
/// Gemeldet am 2026-07-31 vom Gerät: Über der Tastatur schließt die App flach
/// ab, und an den unteren Bildschirmrändern — dort, wo die Tastatur als
/// freistehende Fläche Luft lässt und die Displayecken rund sind — steht
/// Schwarz. Klassische Ursache: `.background(Theme.background)` weicht der
/// Tastatur aus, statt unter ihr weiterzulaufen, und was dann durchscheint,
/// ist das schwarze Fenster.
///
/// Kein Element-Test kann eine Hintergrundfarbe sehen; deshalb misst dieser
/// Test Pixel im Screenshot. Er vergleicht die Ecken unter der Tastatur mit
/// einer Referenz aus der sicher app-gefärbten Bildmitte — absolut wäre die
/// Messung an den Farbmodus gekettet.
///
/// **Zwei Bildschirme, ein Prüfstand.** Gemeldet war die Namenseingabe; die
/// Ursache saß in `themedScreen()` und damit unter neun weiteren Bildschirmen.
/// Die Einkaufsliste steht hier als der zweite Zeuge: eigene Eingabezeile,
/// eigener `.bar`-Streifen, derselbe geteilte Hintergrund. Ginge die Reparatur
/// beim Aufräumen wieder verloren, fiele sie hier genauso auf wie dort.
final class KeyboardBackgroundJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    func testTheThemeBackgroundReachesUnderTheKeyboard() throws {
        // Willkommen → Namenseingabe; das Feld fokussiert sich selbst.
        let primary = app.buttons["onboarding.primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 15))
        primary.tap()

        let field = app.textFields["Vorname"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()

        try assertBackgroundRunsUnderTheKeyboard(named: "Namenseingabe mit Tastatur")
    }

    /// Dasselbe an der Eingabezeile der Einkaufsliste — dem Bildschirm, den
    /// `themedScreen()` färbt, und dem meistbenutzten Textfeld der App.
    func testTheThemeBackgroundReachesUnderTheKeyboardOnTheShoppingList() throws {
        completeOnboarding()

        let input = app.textFields["list.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Keine Eingabezeile")
        input.tap()

        try assertBackgroundRunsUnderTheKeyboard(named: "Einkaufsliste mit Tastatur")
    }

    // MARK: Prüfstand

    /// Wartet auf die Tastatur, hängt den Screenshot an den Bericht und misst
    /// die unterste Bildzeile.
    private func assertBackgroundRunsUnderTheKeyboard(named name: String) throws {
        // Mit angeschlossener Hardware-Tastatur erscheint keine Software-
        // Tastatur — dann gibt es nichts zu messen, und ein grüner Lauf wäre
        // eine Behauptung.
        try XCTSkipUnless(
            app.keyboards.firstMatch.waitForExistence(timeout: 5),
            "Software-Tastatur erscheint nicht (Hardware-Tastatur verbunden?)"
        )
        // Einblende-Animation der Tastatur abwarten.
        _ = app.buttons["nonexistent.settle"].waitForExistence(timeout: 1.5)

        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let cg = shot.image.cgImage else {
            return XCTFail("Screenshot ohne CGImage")
        }
        let w = cg.width
        let h = cg.height

        // Nur im hellen Modus messbar: Dort ist der Creme-Hintergrund warm
        // (Blau deutlich unter Rot/Grün) und das schwarze Fenster neutral.
        // Referenzpunkt am linken Rand auf halber Höhe — sicher App-Hintergrund
        // auf beiden geprüften Bildschirmen.
        let reference = try pixel(in: cg, x: 6, y: h / 2)
        try XCTSkipUnless(
            reference.brightness > 0.5,
            "Dunkler Modus — die Warm-Messung trägt dort nicht"
        )

        // Unterste Zeile, unter den Tasten: Die Tastatur ist durchscheinend,
        // also verrät ihre Färbung, was hinter ihr liegt. Über dem
        // Creme-Hintergrund gemessen (223,222,205): warm, Blau ~18 unter
        // Rot/Grün. Über dem schwarzen Fenster (226,228,232): neutral-kühl.
        // Drei Punkte, damit keine einzelne Taste oder Ecke die Messung kippt.
        let points = [
            (x: 8, y: h - 12, name: "unten links"),
            (x: w / 2, y: h - 12, name: "unten Mitte"),
            (x: w - 8, y: h - 12, name: "unten rechts"),
        ]
        for point in points {
            let value = try pixel(in: cg, x: point.x, y: point.y)
            XCTAssertGreaterThan(
                value.warmth, 5,
                "\(name), \(point.name) (RGB \(value.rgb)) ist nicht warm getönt — "
                + "hinter der Tastatur liegt das schwarze Fenster statt des "
                + "App-Hintergrunds, der Hintergrund endet an der Tastatur"
            )
        }
    }

    private struct Pixel {
        let rgb: (r: Double, g: Double, b: Double)
        var brightness: Double { (0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b) / 255 }
        /// Wie weit Blau unter dem Mittel aus Rot und Grün liegt — das
        /// Erkennungszeichen des Creme-Hintergrunds hinter einer
        /// durchscheinenden Fläche.
        var warmth: Double { (rgb.r + rgb.g) / 2 - rgb.b }
    }

    /// Ein Pixel, über einen 1×1-Kontext gelesen — unabhängig vom Byte-Layout
    /// des Screenshots.
    private func pixel(in image: CGImage, x: Int, y: Int) throws -> Pixel {
        guard let tile = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else {
            throw NSError(domain: "pixel", code: 1)
        }
        var data = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "pixel", code: 2)
        }
        context.draw(tile, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return Pixel(rgb: (Double(data[0]), Double(data[1]), Double(data[2])))
    }

    // MARK: Helfer

    /// Derselbe Weg wie in `ShoppingListInputJourneyTests` — durch das
    /// Onboarding bis zur Liste.
    private func completeOnboarding() {
        app.buttons["onboarding.primary"].tap()   // Willkommen
        app.buttons["onboarding.skip"].tap()      // Name
        let plz = app.textFields["Postleitzahl"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15))
        plz.tap()
        plz.typeText("01219")
        app.buttons["onboarding.primary"].tap()
        app.buttons["onboarding.skip"].tap()      // Haushalt
        app.buttons["onboarding.skip"].tap()      // Ernährung
        app.buttons["onboarding.primary"].tap()   // Einwilligung
        let branch = app.buttons["Lidl, Dresden Reick"]
        XCTAssertTrue(branch.waitForExistence(timeout: 15))
        branch.tap()
        app.buttons["markets.done"].tap()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }
}
