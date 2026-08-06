import XCTest

/// **Vorschläge beim Tippen — Scotts „smart/autofilling" vom 06.08.**
///
/// Geprüft wird nicht Apples Vervollständiger, sondern was die App mit seiner
/// Antwort macht: dass die Vorschläge erscheinen, dass ein Tipp darauf den Text
/// setzt **und** den Ort bestätigt, und dass eine Postleitzahl gar keine
/// Vorschläge bekommt — fünf Ziffern sind die Antwort selbst.
///
/// Der Vervollständiger ist über `uiTestingAddressSuggestions` gestellt, aus
/// demselben Grund wie `uiTestingCityLookup`: Ein Test am Netz wird rot, ohne
/// dass etwas kaputt ist.
///
/// **Die zwei Journeys hier haben mich zweimal angelogen, und beide Male lag
/// es an mir.** Sie fielen mit „keine Vorschläge", obwohl die Vorschläge am
/// Gerät zuverlässig erschienen. Die Aufnahme des Testlaufs
/// (`-resultBundlePath`, dann das `.mp4` aus dem Bündel) zeigte sie in **jedem
/// Bild** auf dem Schirm — gesucht wurde nur falsch: `app.buttons[…]` findet
/// diese Zeilen nicht, `app.descendants(matching: .any)[…]` schon. Dieselbe
/// Schreibweise benutzt diese Suite an drei anderen Stellen; ich hatte sie
/// hier nicht.
///
/// **Merksatz: Wenn ein Test etwas nicht findet, ist die erste Frage nicht
/// „ist es da?", sondern „suche ich richtig?" — und die Aufnahme beantwortet
/// beide in dreißig Sekunden.**
final class AddressSuggestionJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// **Die Vorgabe trägt keine Leerzeichen**, und das ist kein Zufall: Über
    /// `launchArguments` landet sie in Apples Argument-Domäne, und ein Wert mit
    /// Leerzeichen kam dort nicht an. Die bestehenden Vorgaben dieser Suite
    /// (`uiTestingCityLookup`) haben aus demselben Grund keine.
    private func launchAtRegionStep() {
        app.launchArguments = [
            "-uiTesting",
            "-uiTestingAddressSuggestions",
            "Karl-Laux-Straße-6|01219-Dresden;Karl-Laux-Straße-12|01219-Dresden",
            "-uiTestingCityLookup", "Dresden|01219|Sachsen",
        ]
        app.launch()
        app.buttons["onboarding.primary"].tap()   // Willkommen
        app.buttons["onboarding.skip"].tap()      // Ohne Namen weiter
        XCTAssertTrue(app.textFields["region.input"].waitForExistence(timeout: 20))
    }

    private var field: XCUIElement { app.textFields["region.input"] }

    /// **Der Kern: Es schlägt beim Tippen vor.**
    func testTypingAPlaceOffersSuggestions() {
        launchAtRegionStep()
        field.tap()
        field.typeText("Karl")

        let vorschlag = app.descendants(matching: .any)["region.suggestion"].firstMatch
        XCTAssertTrue(vorschlag.waitForExistence(timeout: 10),
                      "Keine Vorschläge beim Tippen:\n" + app.debugDescription)
    }

    /// Ein Tipp auf einen Vorschlag setzt den Text **und** bestätigt den Ort —
    /// man muss danach nicht noch „Ort suchen" drücken.
    func testTakingASuggestionResolvesThePlace() {
        launchAtRegionStep()
        field.tap()
        field.typeText("Karl")

        let vorschlag = app.descendants(matching: .any)["region.suggestion"].firstMatch
        XCTAssertTrue(vorschlag.waitForExistence(timeout: 10))
        vorschlag.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["region.resolvedPlace"].waitForExistence(timeout: 20),
            "Der Vorschlag hat den Ort nicht bestätigt:\n" + app.debugDescription
        )
    }

    /// **Fünf Ziffern brauchen keine Vorschläge.** Sie sind die Antwort selbst;
    /// Apple schlüge dazu Straßen vor, die niemand gefragt hat.
    func testAPostcodeGetsNoSuggestions() {
        launchAtRegionStep()
        field.tap()
        field.typeText("01219")

        XCTAssertFalse(
            app.descendants(matching: .any)["region.suggestion"].firstMatch.waitForExistence(timeout: 5),
            "Eine PLZ darf keine Adressvorschläge auslösen"
        )
    }
}
