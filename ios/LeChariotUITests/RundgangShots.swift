import XCTest

/// **Der Rundgang, Rahmen für Rahmen fotografiert** — Vorlage für die
/// Bildentscheidung aus Punkt A der Bedienrunde vom 08.08.
///
/// Scotts Befund lautet „its ugly", ohne Angabe woran. Ring, Schleier,
/// Textkasten oder die Abfolge — das ist am Bild zu entscheiden und nicht am
/// Absatz. Also erst ansehen, dann umbauen.
///
/// Warum eine Journey und kein Bilderbogen im Unit-Ziel: Das Overlay hängt per
/// `.overlayPreferenceValue` über der `TabView` und lebt von Ankern, die erst
/// ein echter Layout-Durchgang der laufenden App meldet. Ein Nachbau zeigte ein
/// Loch, das jemand hingerechnet hat, und genau darüber ist hier nicht zu
/// urteilen.
///
/// **Hell und dunkel kommen vom Simulator, nicht von einem Startschalter.** Die
/// App steht auf „System"; `xcrun simctl ui <udid> appearance dark` vor dem Lauf
/// dreht beide Bilder.
///
///     xcrun simctl ui <udid> appearance light
///     tools/tests.sh RundgangShots
///     xcrun simctl ui <udid> appearance dark
///     tools/tests.sh RundgangShots
///     xcrun xcresulttool export attachments --path … --output-path …
final class RundgangShots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Mit drei Filialen, damit die Plan-Karte etwas zu sagen hat: Über
        // einer Liste ohne Märkte zeigt Rahmen 2 auf den Leerzustand, und das
        // ist nicht der Rahmen, über den zu urteilen ist.
        app.launchArguments = [
            "-uiTesting", "-uiTestingTutorial", "-uiTestingOnboarded",
            "-uiTestingOnboardedThreeChains",
        ]
        app.launch()
    }

    func testWriteEveryTourFrame() {
        app.buttons["Einstellungen"].firstMatch.tap()
        app.scrollToTutorialButton().tap()

        let card = app.staticTexts["tutorial.card"]
        XCTAssertTrue(card.waitForExistence(timeout: 20))

        var frame = 1
        while card.exists && frame <= 9 {
            // Über die Schonfrist und das Einschwing-Fenster hinaus warten:
            // Fotografiert wird, was stehen bleibt, nicht was gerade fliegt.
            Thread.sleep(forTimeInterval: 2.2)
            attach(name: String(format: "rundgang-%02d", frame))
            guard app.doTheTourDeed() else { break }
            frame += 1
        }

        XCTAssertGreaterThan(frame, 1, "Kein einziger Rahmen fotografiert")
    }

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
