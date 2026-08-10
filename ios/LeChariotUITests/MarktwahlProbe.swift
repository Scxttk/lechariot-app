import XCTest

/// **Punkt #124: Wie lange dauert es vom Tipp bis zum sichtbaren Häkchen?**
///
/// Scott: „Tipp auf Filiale gibt nicht sofort sichtbares Feedback." Gemessen
/// wird deshalb die Zeit vom `tap()` bis die Zeile ihren Wert von „nicht
/// ausgewählt" auf „ausgewählt" umstellt — das ist derselbe Zustandswechsel,
/// den das Häkchen zeichnet, nur abfragbar.
///
/// **Das Verzeichnis ist der Punkt.** Mit den neun Fixture-Filialen ist hier
/// nichts zu sehen; Scott hat in Dresden 113. Der Lauf stellt sie mit
/// `-uiTestingDichtesVerzeichnis` her, sonst misst er einen Fall, den niemand
/// hat.
///
/// Der Boden der Messung ist die Abfrage selbst — XCUITest holt für jeden
/// Blick einen Schnappschuss der Oberfläche. Deshalb steht er im Ergebnis
/// daneben: Eine gemessene Latenz in der Größe des Bodens ist keine Latenz,
/// sondern das Messgerät.
final class MarktwahlProbe: XCTestCase {
    private var app: XCUIApplication!

    /// So viele Filialen, wie Dresden hat — die Zahl steht im Kommentar von
    /// `MarketFilter.titles`, gezählt an der Produktionsdatenbank.
    private let filialen = 113

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-uiTestingOnboarded",
            "-uiTestingDichtesVerzeichnis", String(filialen),
        ]
        app.launch()
    }

    func testMissDieRueckmeldungNachDemTipp() {
        oeffneWaehler()

        // Die Kettenseite ist Scotts Weg: Kette antippen, Filialen wählen.
        // ALDI Nord ist die dichteste Kette (25 von 113) — und die, deren
        // Filialen alle gleich heißen, also genau der teure Zweig.
        oeffneKette("ALDI Nord")

        let zeilen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'ALDI Nord,'"))
        XCTAssertTrue(zeilen.element(boundBy: 0).waitForExistence(timeout: 20),
                      "Keine ALDI-Zeilen auf der Kettenseite")

        let boden = messBoden(zeilen.element(boundBy: 0))

        var messungen: [Double] = []
        // Drei Filialen nacheinander: Die erste Wahl ist der Fall aus der
        // Meldung, die späteren zeigen, ob es mit der Zahl der Gewählten
        // schlimmer wird.
        for i in 0..<3 {
            let zeile = zeilen.element(boundBy: i)
            guard zeile.exists else { continue }
            let vorher = zeile.value as? String ?? ""
            let t0 = Date()
            zeile.tap()
            let ms = warteAufWechsel(zeile, weg: vorher)
            messungen.append(ms)
            print(String(format: "PROBE tipp-%d: %.0f ms (vorher: %@)", i + 1, ms, vorher as NSString))
            _ = t0
        }

        let schnitt = messungen.reduce(0, +) / Double(max(1, messungen.count))
        print("PROBE filialen=\(filialen)")
        print(String(format: "PROBE boden (blosse Abfrage): %.0f ms", boden))
        print(String(format: "PROBE latenz-schnitt: %.0f ms", schnitt))
        print(String(format: "PROBE latenz-max: %.0f ms", messungen.max() ?? 0))

        let schuss = XCTAttachment(screenshot: app.screenshot())
        schuss.name = "kettenseite-nach-drei-wahlen"
        schuss.lifetime = .keepAlways
        add(schuss)

        // Kein Grenzwert in der Probe: Sie misst, sie urteilt nicht. Der
        // Grenzwert steht in `MarktwahlLatenzTests`, wo er nach dem Fix auch
        // gehalten werden kann.
        XCTAssertFalse(messungen.isEmpty, "Keine einzige Messung zustande gekommen")
    }

    // MARK: Messwerkzeug

    /// Was eine Abfrage allein kostet, ohne dass sich etwas ändert. Zehn
    /// Blicke auf dieselbe unveränderte Zeile.
    private func messBoden(_ zeile: XCUIElement) -> Double {
        let t0 = Date()
        for _ in 0..<10 { _ = zeile.value as? String }
        return Date().timeIntervalSince(t0) * 1000 / 10
    }

    /// Fragt die Zeile so schnell wie möglich, bis ihr Wert nicht mehr `weg`
    /// ist, und gibt die verstrichenen Millisekunden zurück.
    private func warteAufWechsel(_ zeile: XCUIElement, weg: String) -> Double {
        let t0 = Date()
        let frist: TimeInterval = 10
        while Date().timeIntervalSince(t0) < frist {
            if (zeile.value as? String ?? "") != weg { break }
        }
        return Date().timeIntervalSince(t0) * 1000
    }

    // MARK: Weg zum Wähler

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

    private func oeffneKette(_ kette: String) {
        let zeile = app.buttons["picker.chain.\(kette)"]
        XCTAssertTrue(zeile.waitForExistence(timeout: 20), "Kettenzeile \(kette) fehlt")
        zeile.tap()
    }
}
