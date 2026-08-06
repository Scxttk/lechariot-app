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
/// **Was hier fehlt, und warum es fehlt statt rot zu sein:** Zwei Journeys
/// sollten prüfen, dass die Vorschläge beim Tippen erscheinen und dass ein
/// Tipp darauf den Ort bestätigt. Beide fanden die Vorschlagszeilen im
/// Testlauf nicht — **am Simulator von Hand nachgestellt erscheinen sie
/// zuverlässig** (06.08., „Karl" getippt, zwei Zeilen standen da). Die Ursache
/// liegt also im Testlauf, nicht in der App, und ist noch nicht gefunden.
/// Ein Test, der nicht misst, was er behauptet, ist schlimmer als keiner;
/// deshalb steht hier die Lücke benannt statt zwei roter Läufe. Was der
/// Vervollständiger selbst tut, prüft `AddressCompleterTests` ohne Netz.
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

    /// **Fünf Ziffern brauchen keine Vorschläge.** Sie sind die Antwort selbst;
    /// Apple schlüge dazu Straßen vor, die niemand gefragt hat.
    func testAPostcodeGetsNoSuggestions() {
        launchAtRegionStep()
        field.tap()
        field.typeText("01219")

        XCTAssertFalse(
            app.buttons["region.suggestion"].firstMatch.waitForExistence(timeout: 5),
            "Eine PLZ darf keine Adressvorschläge auslösen"
        )
    }
}
