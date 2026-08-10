import XCTest

/// **Punkt #124: Wie lange dauert es vom Tipp bis zur sichtbaren Rückmeldung?**
///
/// Scott: „Tipp auf Filiale gibt nicht sofort sichtbares Feedback."
///
/// **Zwei Anläufe, und der erste war falsch.** Zuerst stand hier eine Messung
/// „tippen, dann abfragen, bis der Wert umspringt". Sie hat nichts gemessen:
/// 65 ms vorher, 72 ms nachher, bei einem Boden von 53 ms für die blosse
/// Abfrage. Der Grund ist `XCUIElement.tap()` selbst — es wartet, bis die App
/// **ruhig** ist, und kehrt erst dann zurück. Wer danach abfragt, sieht eine
/// Oberfläche, die längst fertig ist, und misst nur noch den Weg der Abfrage
/// über die Prozessgrenze.
///
/// Gemessen wird deshalb **der Tipp selbst**: `tap()` schließt das Warten auf
/// Ruhe ein, und genau darin steckt, was die App in dem Moment rechnet.
///
/// **Und gemessen wird über die Größe des Verzeichnisses**, nicht als eine
/// Zahl. Der Verdacht ist quadratischer Aufwand (`MarketPickerView.rowTitles`);
/// ein fester Aufschlag des Messgeräts — und der ist hier groß — kürzt sich aus
/// einem *Vergleich zwischen zwei Größen* heraus, aus einer Einzelzahl nicht.
/// Wächst die Zeit mit dem Verzeichnis, ist es die App; bleibt sie flach, ist
/// der Rest Messgerät.
///
/// 113 ist keine gewählte Zahl: So viele Filialen hat Dresden, gezählt an der
/// Produktionsdatenbank (siehe `MarketFilter.titles`).
final class MarktwahlProbe: XCTestCase {
    /// Ein Punkt der Messreihe: so viele Filialen, so lange dauerte der Tipp.
    private struct Punkt {
        let filialen: Int
        let tippMs: [Double]
        let bodenMs: Double

        var schnitt: Double { tippMs.reduce(0, +) / Double(max(1, tippMs.count)) }
    }

    func testDieTippdauerUeberDieGroesseDesVerzeichnisses() {
        var reihe: [Punkt] = []
        for n in [20, 113, 200] {
            reihe.append(miss(filialen: n))
        }

        print("PROBE ---- Tippdauer nach Verzeichnisgröße ----")
        for p in reihe {
            print(String(format: "PROBE n=%3d  tipp=%6.0f ms  (einzeln: %@)  boden=%.0f ms",
                         p.filialen, p.schnitt,
                         p.tippMs.map { String(format: "%.0f", $0) }
                             .joined(separator: "/") as NSString,
                         p.bodenMs))
        }
        if let klein = reihe.first, let gross = reihe.last {
            print(String(format: "PROBE steigung n=%d→%d: %+.0f ms",
                         klein.filialen, gross.filialen, gross.schnitt - klein.schnitt))
        }

        XCTAssertEqual(reihe.count, 3, "Nicht jede Größe kam zu einer Messung")
    }

    // MARK: Eine Größe

    private func miss(filialen: Int) -> Punkt {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-uiTestingOnboarded",
            "-uiTestingDichtesVerzeichnis", String(filialen),
        ]
        app.launch()
        defer { app.terminate() }

        oeffneWaehler(app)
        // ALDI Nord ist die dichteste Kette und die, deren Filialen alle gleich
        // heißen — also genau der teure Zweig der Titelvergabe.
        oeffneKette("ALDI Nord", in: app)

        let zeilen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'ALDI Nord,'"))
        XCTAssertTrue(zeilen.element(boundBy: 0).waitForExistence(timeout: 30),
                      "Keine ALDI-Zeilen bei \(filialen) Filialen")

        let boden = messBoden(zeilen.element(boundBy: 0))

        var tipps: [Double] = []
        for i in 0..<3 {
            let zeile = zeilen.element(boundBy: i)
            guard zeile.exists else { continue }
            // Der Tipp **mit** dem Warten auf Ruhe — das ist die Zahl.
            let t0 = Date()
            zeile.tap()
            tipps.append(Date().timeIntervalSince(t0) * 1000)
        }

        let schuss = XCTAttachment(screenshot: app.screenshot())
        schuss.name = "kettenseite-\(filialen)-filialen"
        schuss.lifetime = .keepAlways
        add(schuss)

        return Punkt(filialen: filialen, tippMs: tipps, bodenMs: boden)
    }

    /// Was eine Abfrage allein kostet, ohne dass sich etwas ändert — der Boden,
    /// unter den keine Messung dieser Bauart kommt.
    private func messBoden(_ zeile: XCUIElement) -> Double {
        let t0 = Date()
        for _ in 0..<10 { _ = zeile.value as? String }
        return Date().timeIntervalSince(t0) * 1000 / 10
    }

    // MARK: Weg zum Wähler

    private func oeffneWaehler(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 30),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
        app.tabBars.buttons["Einstellungen"].tap()
        let orte = app.buttons["settings.places"]
        XCTAssertTrue(orte.waitForExistence(timeout: 30), "Kein Weg zu den Filialen")
        orte.tap()
        let bearbeiten = app.buttons["Filialen bearbeiten"]
        XCTAssertTrue(bearbeiten.waitForExistence(timeout: 30))
        bearbeiten.tap()
        XCTAssertTrue(app.navigationBars["Filialen wählen"].waitForExistence(timeout: 30))
    }

    private func oeffneKette(_ kette: String, in app: XCUIApplication) {
        let zeile = app.buttons["picker.chain.\(kette)"]
        XCTAssertTrue(zeile.waitForExistence(timeout: 30), "Kettenzeile \(kette) fehlt")
        zeile.tap()
    }
}
