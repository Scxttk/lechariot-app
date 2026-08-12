import XCTest

/// **Fünf Ziffern sind noch kein deutsches Gebiet** (#148).
///
/// Am 12.08. in Prod belegt: Zwei Installationen an der US-Westküste haben das
/// Onboarding mit einem US-ZIP durchlaufen — fünf Ziffern sind fünf Ziffern,
/// also war die Zahl eine PLZ. Dahinter stand eine App ohne Märkte und ohne
/// Erklärung: Es gibt keinen deutschen Anker, an dem eine Gebiets-Anforderung
/// hängen könnte.
///
/// Geprüft wird der Ablauf, nicht Apples Geocoder: Unter `-uiTestingPLZPruefung`
/// antwortet `CityLookup.pruefe` mit einem festen Urteil — dieselbe Naht wie
/// `-uiTestingCityLookup` beim Ortsnamen. Was die App aus Apples echten Feldern
/// rechnet, steht in `RegionQueryTests`, mit den am 12.08. gemessenen Werten.
final class AuslandJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    private var field: XCUIElement { app.textFields["region.input"] }
    private var primary: XCUIElement { app.buttons["onboarding.primary"] }
    private var fehler: XCUIElement { app.descendants(matching: .any)["region.error"] }

    /// Der US-ZIP aus dem Bericht, und was Apple darauf wirklich antwortet:
    /// Mexiko. Der Ort kommt aus der Sonde vom 12.08. — erfunden ist hier
    /// nichts außer dem Zeitpunkt.
    private let ausland = "95070>AUSLAND|Mexiko"

    private func starteBeimOrtsschritt() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingPLZPruefung", ausland]
        app.launch()
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")
        app.tippe(app.buttons["onboarding.skip"], "Überspringen im Assistenten")
        XCTAssertTrue(field.waitForExistence(timeout: 20))
    }

    private func tippe(_ text: String) {
        field.tap()
        field.typeText(text)
    }

    // MARK: Der Fall aus dem Bericht

    /// **Der ganze Befund in einer Journey:** tippen, „Weiter", und die App
    /// sagt, was Sache ist — statt weiterzuschalten.
    func testAnAmericanZipDoesNotPassOnboarding() {
        starteBeimOrtsschritt()
        tippe("95070")
        primary.tap()

        XCTAssertTrue(
            fehler.waitForExistence(timeout: 20),
            "Ohne Meldung landet der Tester in einer App ohne Märkte und ohne Grund\n" + app.debugDescription
        )
        XCTAssertTrue(fehler.isHittable, "Eine Meldung hinter der Tastatur ist keine Meldung")
        XCTAssertTrue(fehler.label.contains("nur in Deutschland"),
                      "Die Meldung muss den Grund nennen: \(fehler.label)")
        XCTAssertTrue(fehler.label.contains("Mexiko"),
                      "Wo Apple die Zahl verortet, gehört dazu: \(fehler.label)")

        // **Der Schritt bleibt stehen, und die Eingabe auch.** Dieselbe Zusage
        // wie beim gescheiterten Ortsnamen (#143): Ein Fehlschlag ändert nichts
        // als die Meldung.
        XCTAssertTrue(field.exists, "Nach dem Fehlschlag darf der Assistent nicht weiterschalten")
        XCTAssertEqual(field.value as? String, "95070", "Die eigene Eingabe bleibt stehen")
        XCTAssertFalse(app.descendants(matching: .any)["region.resolvedPlace"].exists,
                       "Nichts ist bestätigt worden")
    }

    /// **Und es bleibt nichts liegen.** Der zweite Weg in den Speicher —
    /// „Region hinzufügen" aus den Einstellungen — endet ebenso ohne Zeile in
    /// der Liste der Regionen.
    func testARefusedZipLeavesNoRegionBehind() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingPLZPruefung", ausland]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20))

        app.tabBars.buttons["Einstellungen"].tap()
        app.tippe(app.buttons["settings.places"], "Filialen und Regionen")
        app.tippe(app.buttons["Region hinzufügen"], "Region hinzufügen")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        tippe("95070")
        app.buttons["Weiter"].tap()

        XCTAssertTrue(fehler.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertFalse(app.staticTexts["PLZ 95070"].exists, "Nichts gespeichert heißt: keine Zeile")
    }

    /// Die Gegenprobe — sonst wäre die Prüfung nur eine Wand. Die deutsche PLZ
    /// geht mit **einem** Tipp durch, wie vorher.
    func testAGermanPostcodeStillPassesWithOneTap() {
        starteBeimOrtsschritt()
        tippe("01219")

        XCTAssertEqual(primary.label, "Weiter", "Für die PLZ bleibt es ein Knopf, kein Zwischenschritt")
        primary.tap()
        XCTAssertFalse(field.waitForExistence(timeout: 15), "Nach „Weiter“ muss der Schritt wechseln")
    }
}
