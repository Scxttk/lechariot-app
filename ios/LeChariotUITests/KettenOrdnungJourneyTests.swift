import XCTest

/// **Punkt #123: Die Ordnung der Ketten-Abschnitte im Wähler.**
///
/// Ungewählte Ketten oben, gewählte sinken, die zuletzt gewählte ganz unten.
/// Verfeinerung von #91 — dort ging es um die Filialen *innerhalb* einer
/// Kette, hier um die Ketten selbst.
///
/// Der Fall dahinter ist derselbe wie beim Verschieben von „Deine Filialen"
/// ans Ende (08.08.): Wer drei Ketten nacheinander durchgeht, will die noch
/// offenen oben finden und nicht an den schon erledigten vorbeiscrollen.
///
/// Geprüft wird an der **Bildposition** der Kettenzeilen, nicht an einer
/// internen Liste: Die Meldung war eine über das, was auf dem Schirm steht.
final class KettenOrdnungJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    /// Die vier Ketten, die das Fixture-Verzeichnis um 01219 hergibt. Lidl ist
    /// durch `-uiTestingOnboarded` schon gewählt.
    private let ketten = ["Aldi", "Lidl", "Netto", "REWE"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
    }

    func testGewaehlteKettenSinkenUndDieLetzteStehtGanzUnten() {
        oeffneWaehler()

        // Ausgangslage: Lidl ist gewählt (Saatgut) und steht deshalb unten,
        // die drei ungewählten alphabetisch darüber.
        XCTAssertEqual(ordnung(), ["Aldi", "Netto", "REWE", "Lidl"],
                       "Die gewählte Kette steht nicht unten")

        // Erste Wahl: REWE wird gewählt und sinkt unter Lidl, weil es später
        // gewählt wurde.
        waehleFilialeIn("REWE")
        XCTAssertEqual(ordnung(), ["Aldi", "Netto", "Lidl", "REWE"],
                       "Die zuletzt gewählte Kette steht nicht zuunterst")

        // Zweite Wahl: Netto rutscht ganz nach unten, REWE eine Stufe hoch.
        // Übrig oben bleibt genau die eine Kette, die noch offen ist.
        waehleFilialeIn("Netto")
        XCTAssertEqual(ordnung(), ["Aldi", "Lidl", "REWE", "Netto"],
                       "Die Ordnung stimmt nach der zweiten Wahl nicht")

        let schuss = XCTAttachment(screenshot: app.screenshot())
        schuss.name = "ketten-ordnung-nach-zwei-wahlen"
        schuss.lifetime = .keepAlways
        add(schuss)
    }

    /// Eine abgewählte Kette steigt wieder nach oben — sonst wäre „gewählt
    /// sinkt" eine Einbahnstraße, und der Wähler behielte eine Ordnung, die
    /// zu seinem Inhalt nicht mehr passt.
    func testEineAbgewaehlteKetteSteigtWiederNachOben() {
        oeffneWaehler()
        waehleFilialeIn("REWE")
        XCTAssertEqual(ordnung().last, "REWE")

        waehleFilialeIn("REWE")   // derselbe Griff wählt wieder ab
        XCTAssertEqual(ordnung(), ["Aldi", "Netto", "REWE", "Lidl"],
                       "Die abgewählte Kette ist nicht wieder nach oben gestiegen")
    }

    // MARK: Helfer

    /// Die Kettenzeilen von oben nach unten, wie sie auf dem Schirm stehen.
    private func ordnung() -> [String] {
        ketten
            .map { (kette: $0, zeile: app.buttons["picker.chain.\($0)"]) }
            .filter { $0.zeile.exists }
            .sorted { $0.zeile.frame.minY < $1.zeile.frame.minY }
            .map(\.kette)
    }

    /// Öffnet die Kettenseite, tippt die erste Filiale an und kommt zurück.
    private func waehleFilialeIn(_ kette: String) {
        let zeile = app.buttons["picker.chain.\(kette)"]
        XCTAssertTrue(zeile.waitForExistence(timeout: 15), "Kettenzeile \(kette) fehlt")
        zeile.tap()

        let filiale = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "\(kette),")
        ).element(boundBy: 0)
        XCTAssertTrue(filiale.waitForExistence(timeout: 15), "Keine Filiale unter \(kette)")
        filiale.tap()

        app.buttons["chain.done"].tap()
        XCTAssertTrue(app.navigationBars["Filialen wählen"].waitForExistence(timeout: 15),
                      "Der Weg zurück in den Wähler ist verstellt")
    }

    private func oeffneWaehler() {
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
        app.tabBars.buttons["Einstellungen"].tap()
        let orte = app.buttons["settings.places"]
        XCTAssertTrue(orte.waitForExistence(timeout: 20), "Kein Weg zu den Filialen")
        orte.tap()
        let bearbeiten = app.buttons["Filialen bearbeiten"]
        XCTAssertTrue(bearbeiten.waitForExistence(timeout: 20))
        bearbeiten.tap()
        XCTAssertTrue(app.navigationBars["Filialen wählen"].waitForExistence(timeout: 20))
    }
}
