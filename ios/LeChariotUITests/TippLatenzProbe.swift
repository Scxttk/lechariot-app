import XCTest

/// **Punkt 1 der Bedienrunde 11.08.: „verzögert oft, laut Messtool immer wenn
/// ich etwas anklicke."**
///
/// Scott am Morgen-Build vom 11.08. — also am Stand nach der Nacht-Runde
/// (#129 Wähler, #131 Schilder, #132 Blatt, #133 Zeichen). Verdacht ist eine
/// Regression, und der Auftrag lautet: **erst messen, dann greifen.**
///
/// **Die Bauart ist die von `MarktwahlProbe`, und zwar aus deren Lehre.** Dort
/// stand zuerst „tippen, dann abfragen, bis sich etwas ändert" — und hat nichts
/// gemessen, weil `XCUIElement.tap()` selbst erst zurückkehrt, wenn die App
/// **ruhig** ist. Genau darin steckt, was die App im Moment des Tipps rechnet.
/// Gemessen wird deshalb der Tipp selbst.
///
/// **Und gemessen wird mit einem Boden.** Ein fester Aufschlag des Messgeräts
/// (Element suchen, Ereignis bauen, Prozessgrenze) steckt in jeder Zahl; ohne
/// eine Messung, die *nichts* auslöst, ist nicht zu sagen, ob 300 ms viel sind.
/// Zwei Böden stehen hier: die blosse Abfrage und ein Tipp auf die
/// Navigationsleiste, der keine Handlung hat.
///
/// **Vier Griffe, weil Scott „bei jedem Antippen" sagt** — die Verzögerung soll
/// also nicht an einem Bildschirm hängen: Kachel abhaken (Liste), Tab wechseln
/// (die ganze Hierarchie), Blatt auf und zu (#132), Filialzeile im Wähler
/// (#129).
///
/// **Zwei Läufe, weil die Schilder unter `-uiTesting` aus sind.** Ohne
/// `-uiTestingTips` baut `ContextTipStore` gar nichts (`isEnabled`) — ein Lauf
/// ohne das Argument könnte eine Regression in der Schilder-Schicht nicht
/// sehen. Der Unterschied zwischen den beiden Läufen ist deshalb selbst eine
/// Messung.
final class TippLatenzProbe: XCTestCase {
    /// Eine Messreihe: derselbe Griff mehrfach, in Millisekunden.
    private struct Reihe {
        let name: String
        let ms: [Double]

        var median: Double {
            let s = ms.sorted()
            guard !s.isEmpty else { return 0 }
            return s[s.count / 2]
        }
        var kleinste: Double { ms.min() ?? 0 }
        var groesste: Double { ms.max() ?? 0 }
    }

    // MARK: Die zwei Läufe

    func testTippdauerOhneSchilder() {
        miss(schilder: false)
    }

    func testTippdauerMitSchildern() {
        miss(schilder: true)
    }

    // MARK: Ein Lauf

    private func miss(schilder: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
            + (schilder ? ["-uiTestingTips"] : [])
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 60),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
        for wort in ["Vollmilch", "Butter", "Kartoffeln"] {
            lege(wort, in: app)
        }

        var reihen: [Reihe] = []
        reihen.append(bodenAbfrage(app))
        reihen.append(bodenTipp(app))
        reihen.append(kachelAbhaken(app))
        reihen.append(tabWechsel(app))
        reihen.append(blatt(app))
        reihen.append(waehler(app))

        let kopf = schilder ? "mit-schildern" : "ohne-schilder"
        print("PROBE ---- Tippdauer (\(kopf)) ----")
        for r in reihen {
            print(String(format: "PROBE %@ %-22@ median=%6.0f ms  min=%6.0f  max=%6.0f  n=%d  alle=%@",
                         kopf as NSString, r.name as NSString,
                         r.median, r.kleinste, r.groesste, r.ms.count,
                         r.ms.map { String(format: "%.0f", $0) }.joined(separator: "/") as NSString))
        }

        XCTAssertEqual(reihen.filter { $0.ms.isEmpty }.map(\.name), [],
                       "Eine Reihe ist ohne Messwert geblieben")
    }

    // MARK: Die Böden

    /// Was eine Abfrage über die Prozessgrenze allein kostet — nichts ändert
    /// sich dabei.
    private func bodenAbfrage(_ app: XCUIApplication) -> Reihe {
        let kachel = kachel("Vollmilch", in: app)
        var ms: [Double] = []
        for _ in 0..<10 {
            let t0 = Date()
            _ = kachel.value as? String
            ms.append(Date().timeIntervalSince(t0) * 1000)
        }
        return Reihe(name: "boden-abfrage", ms: ms)
    }

    /// Ein Tipp, der keine Handlung hat: die Navigationsleiste. Damit steht der
    /// Aufschlag von `tap()` samt Warten auf Ruhe als eigene Zahl da.
    private func bodenTipp(_ app: XCUIApplication) -> Reihe {
        let leiste = app.navigationBars["Einkaufsliste"]
        var ms: [Double] = []
        for _ in 0..<5 {
            let t0 = Date()
            leiste.tap()
            ms.append(Date().timeIntervalSince(t0) * 1000)
        }
        return Reihe(name: "boden-tipp", ms: ms)
    }

    // MARK: Die vier Griffe

    /// Abhaken und wieder zurück — der Griff, den die App im Laden können muss.
    private func kachelAbhaken(_ app: XCUIApplication) -> Reihe {
        var ms: [Double] = []
        for _ in 0..<6 {
            let k = kachel("Vollmilch", in: app)
            guard k.waitForExistence(timeout: 15) else { continue }
            let t0 = Date()
            k.tap()
            ms.append(Date().timeIntervalSince(t0) * 1000)
        }
        return Reihe(name: "kachel-abhaken", ms: ms)
    }

    /// Liste ↔ Angebote. Ein Tab-Wechsel baut die halbe App neu und ist
    /// deshalb der Griff, an dem eine teure Regelauswertung am besten auffällt.
    private func tabWechsel(_ app: XCUIApplication) -> Reihe {
        var ms: [Double] = []
        for i in 0..<6 {
            let ziel = i % 2 == 0 ? "Angebote" : "Liste"
            let knopf = app.tabBars.buttons[ziel]
            guard knopf.waitForExistence(timeout: 15) else { continue }
            let t0 = Date()
            knopf.tap()
            ms.append(Date().timeIntervalSince(t0) * 1000)
        }
        // Zurück auf die Liste, egal wo die Reihe endete.
        let liste = app.tabBars.buttons["Liste"]
        if liste.exists { liste.tap() }
        return Reihe(name: "tab-wechsel", ms: ms)
    }

    /// Das Artikelblatt auf und zu (#132). Das Aufmachen ist ein **Halten**;
    /// die 0,6 s Haltezeit stecken in der Zahl und sind in jedem Lauf gleich —
    /// vergleichbar bleibt sie damit, absolut lesbar nicht.
    private func blatt(_ app: XCUIApplication) -> Reihe {
        var auf: [Double] = []
        var zu: [Double] = []
        for _ in 0..<3 {
            let k = kachel("Butter", in: app)
            guard k.waitForExistence(timeout: 15) else { continue }
            let t0 = Date()
            k.press(forDuration: 0.6)
            let fertig = app.buttons["itemSheet.done"].firstMatch
            guard fertig.waitForExistence(timeout: 20) else { continue }
            auf.append(Date().timeIntervalSince(t0) * 1000)

            let t1 = Date()
            fertig.tap()
            zu.append(Date().timeIntervalSince(t1) * 1000)
            _ = fertig.waitForNonExistence(timeout: 20)
        }
        // Beide Zahlen gehören zusammen und werden getrennt gebraucht: Das
        // Aufmachen trägt die Haltezeit, das Zumachen ist ein reiner Tipp.
        print(String(format: "PROBE blatt-auf median=%6.0f ms alle=%@",
                     Reihe(name: "", ms: auf).median,
                     auf.map { String(format: "%.0f", $0) }.joined(separator: "/") as NSString))
        return Reihe(name: "blatt-zu", ms: zu)
    }

    /// Eine Filialzeile im Wähler (#129) — dieselbe Stelle, die `MarktwahlProbe`
    /// am 10.08. gemessen hat, hier nur mit dem Fixture-Verzeichnis.
    private func waehler(_ app: XCUIApplication) -> Reihe {
        app.tabBars.buttons["Einstellungen"].tap()
        let orte = app.buttons["settings.places"]
        guard orte.waitForExistence(timeout: 30) else {
            return Reihe(name: "waehler-zeile", ms: [])
        }
        orte.tap()
        let bearbeiten = app.buttons["Filialen bearbeiten"]
        guard bearbeiten.waitForExistence(timeout: 30) else {
            return Reihe(name: "waehler-zeile", ms: [])
        }
        bearbeiten.tap()
        guard app.navigationBars["Filialen wählen"].waitForExistence(timeout: 30) else {
            return Reihe(name: "waehler-zeile", ms: [])
        }
        let kette = app.buttons["picker.chain.Lidl"]
        guard kette.waitForExistence(timeout: 30) else {
            return Reihe(name: "waehler-zeile", ms: [])
        }
        kette.tap()

        let zeilen = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Lidl,'"))
        guard zeilen.element(boundBy: 0).waitForExistence(timeout: 30) else {
            return Reihe(name: "waehler-zeile", ms: [])
        }
        var ms: [Double] = []
        for _ in 0..<4 {
            let zeile = zeilen.element(boundBy: 0)
            guard zeile.exists else { continue }
            let t0 = Date()
            zeile.tap()
            ms.append(Date().timeIntervalSince(t0) * 1000)
        }
        return Reihe(name: "waehler-zeile", ms: ms)
    }

    // MARK: Helfer

    /// Die Kachel über ihren Namen, nicht über `list.tile`: Abgehakt wandert
    /// sie in den Abschnitt „Erledigt", und `firstMatch` zeigte danach auf eine
    /// andere.
    private func kachel(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    private func lege(_ text: String, in app: XCUIApplication) {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 30))
        feld.tapAndAwaitKeyboard(in: app)
        app.typeText(text + "\n")
        // Das Mengen-Menü geht beim Anlegen von selbst auf; hier ist es ein
        // Zwischenschritt, kein Prüfgegenstand.
        let panel = app.buttons["list.detailPanel.more"]
        if panel.waitForExistence(timeout: 5) {
            app.dragTheListUp()
            _ = panel.waitForNonExistence(timeout: 5)
        }
    }
}
