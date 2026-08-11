import XCTest

/// **Die vier Schilder, fotografiert** — der Nachfolger von `RundgangShots`.
///
/// Warum es den Bogen weiter gibt, obwohl der Rundgang weg ist: Die zwei
/// Fehler vom 09.08. hat **nur das gerenderte Bild** gezeigt (die Kachel im
/// Loch bei 38,6 Helligkeit gegen 14,1 daneben), und die Kontrastfehler, die
/// Scott am 10.08. meldet, sind dieselbe Klasse. Ein Schild ist Creme auf
/// Creme; ob seine doppelte Kante trägt, ist am Bild zu entscheiden und nicht
/// am Absatz.
///
/// **Hell und dunkel kommen vom Simulator, nicht von einem Startschalter.** Die
/// App steht auf „System"; `xcrun simctl ui <udid> appearance dark` vor dem Lauf
/// dreht beide Bilder.
///
///     xcrun simctl ui <udid> appearance light
///     tools/tests.sh SchilderShots --result /tmp/bogen-hell.xcresult
///     xcrun simctl ui <udid> appearance dark
///     tools/tests.sh SchilderShots --result /tmp/bogen-dunkel.xcresult
///     xcrun xcresulttool export attachments --path … --output-path …
final class SchilderShots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-uiTestingOnboarded", "-uiTestingTips",
            "-uiTestingOnboardedThreeChains",
        ]
        app.launch()
    }

    /// Zwei Bilder, die beiden Flächen: das Schild im Angebote-Tab und eines
    /// auf der Liste. Mehr geht in einem Lauf nicht — je Fläche steht eines,
    /// und das ist der Vertrag (`ContextTipTuning.tipsPerSurfaceAndSession`).
    func testWriteTheSigns() {
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20))

        // Die Liste zuerst: Ein Artikel mit Treffer, dann die ruhende Liste.
        app.buttons["Milch hinzufügen"].tap()
        app.dragTheListUp()
        let listenSchild = app.staticTexts["Mehr als das eine Angebot"]
        if listenSchild.waitForExistence(timeout: 15) {
            Thread.sleep(forTimeInterval: 1.0)
            attach(name: "schild-liste")
        } else {
            attachTree(name: "schild-liste-fehlt")
            XCTFail("Auf der ruhenden Liste steht kein Schild:\n\(app.debugDescription)")
        }

        app.tabBars.buttons["Angebote"].tap()
        let vorschauSchild = app.staticTexts["Was ab Montag billiger wird"]
        XCTAssertTrue(vorschauSchild.waitForExistence(timeout: 20),
                      "Im Angebote-Tab steht kein Schild")
        Thread.sleep(forTimeInterval: 1.0)
        attach(name: "schild-angebote")
    }

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func attachTree(name: String) {
        let anhang = XCTAttachment(string: app.debugDescription)
        anhang.name = name
        anhang.lifetime = .keepAlways
        add(anhang)
    }
}
