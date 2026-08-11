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
/// **Ein eigener Lauf für die Schilder, weil sie unter `-uiTesting` aus sind.**
/// Ohne `-uiTestingTips` baut `ContextTipStore` gar nichts (`isEnabled`) — ein
/// Lauf ohne das Argument könnte eine Regression in der Schilder-Schicht nicht
/// sehen. Der Unterschied zwischen den Läufen ist deshalb selbst eine Messung.
/// Und weil „mit Schildern" nichts wert ist, wenn keines steht, schreibt die
/// Sonde mit, **welches** stand.
///
/// **Zwei Grenzen dieser Sonde, beide am 11.08. gemessen und beide wichtig:**
///
/// - **Sie misst die Maschine mit.** Derselbe Griff, dieselbe Fassung: 667 ms
///   auf ruhiger Maschine, 735 ms während eine zweite Sitzung baute. 11 %
///   Rauschen sind mehr, als eine Regression dieser Art groß ist — die Klasse
///   steht deshalb in `SERIELL` und `OHNE_CI` (`tools/testlauf.sh`).
/// - **Sie sieht keine Kosten, die kleiner sind als die Animation, die sie
///   abwartet.** `tap()` kehrt erst bei Ruhe zurück; eine Kachel wird animiert.
///   Zwischen fünf Fixture-Zeilen und 1 200 Prospektzeilen bewegte sich das
///   Abhaken um 2 ms — obwohl die App dabei nachweislich zehnmal mehr rechnet
///   (`TippKostenProbe`). Wer Rechenzeit sucht, nimmt `XCTCPUMetric`
///   (`testRechenzeitDerAppJeTipp`) und nicht die Wanduhr.
///
/// **Was hier offen bleibt: das Messwerkzeug selbst.** Scott sieht die
/// Verzögerung *am Messtool*, und dessen Live-Anzeige hängt an einem
/// `CADisplayLink` im Bildschirmtakt (`PerformanceHUD`) — ein Werkzeug, das
/// selbst kostet, wäre eine Erklärung für „bei **jedem** Antippen", die keinem
/// Merge zuzuordnen ist. Ein Lauf, der das Werkzeug über die Einstellungen
/// anschaltet, stand hier und ist **wieder herausgenommen**: Er ist dreimal an
/// der Bedienung gescheitert (der Schalter liegt nicht in der Mitte seiner
/// Zeile; der Tab behält seinen Stapel; die Liste behält ihren Scrollstand) und
/// danach zweimal an `Mach error -308` des Simulator-Dienstes, auch auf einem
/// frisch gelöschten Gerät. Ein wackelnder Test ist schlimmer als keiner — die
/// Frage ist damit **ungemessen**, nicht beantwortet, und gehört an ein ruhiges
/// Gerät und in einen eigenen Posten.
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

    // MARK: Die Läufe

    func testTippdauerOhneSchilder() {
        miss(schilder: false)
    }

    func testTippdauerMitSchildern() {
        miss(schilder: true)
    }

    /// **Der Lauf mit einem Prospekt in Scotts Größe** — drei Ketten, je 400
    /// Zeilen.
    ///
    /// Das Fixture-Verzeichnis hat eine Handvoll Angebote; Scott hat eine
    /// Woche. Und die Liste rechnet an der Zahl der Angebote: `firstOpenHasMatch`
    /// sucht im Rumpf von `ShoppingListView` den billigsten Treffer der ersten
    /// offenen Zeile, und der Rumpf läuft bei **jeder** Zustandsänderung. Was
    /// mit der Eingabegröße wächst, ist an fünf Fixture-Zeilen nicht zu sehen —
    /// dieselbe Lehre wie am Wähler (`MarktwahlProbe`, #124).
    ///
    /// 400 ist die Zahl des Messgeschirrs (`tools/perf.sh`), damit die beiden
    /// Messstände dieselbe Größe meinen.
    func testTippdauerMitVollemProspekt() {
        miss(schilder: true, vollerProspekt: true)
    }

    /// **Die Rechenzeit der App je Tipp — und nicht die des Messgeräts.**
    ///
    /// Die Zahlen oben tragen den Aufschlag von XCUITest mit, und der ist hier
    /// groß: Ein Tipp kostet allein für das Finden des Elements, das Bauen des
    /// Ereignisses und das Warten auf Ruhe rund 380 ms. Schlimmer noch, er
    /// **wächst mit dem Bedienungshilfen-Baum** — gemessen an `boden-abfrage`:
    /// mit stehendem Schild 82 ms je Abfrage statt 49. Ein Tipp, der langsamer
    /// wird, weil der Baum größer wurde, ist für einen Menschen kein Tipp, der
    /// langsamer wurde.
    ///
    /// `XCTCPUMetric` fragt deshalb den **Prozess der App**: Was hat sie
    /// gerechnet, während vier Griffe passiert sind? Dieselbe Metrik benutzt
    /// `PerformanceJourneyTests` fürs Scrollen, und derselbe Vorrat (400 Zeilen
    /// je Kette) — damit sind die beiden Messstände vergleichbar.
    func testRechenzeitDerAppJeTipp() {
        rechenzeit(vollerProspekt: true)
    }

    /// **Dieselben vier Griffe, aber mit einer Handvoll Angebote.**
    ///
    /// Der Vergleich der beiden Zahlen sagt, **wie viel von der Rechenzeit je
    /// Tipp an der Menge der Angebote hängt** — und damit, ob die Ursache in
    /// den Funktionen liegt, die den Prospekt durchgehen (`ShoppingListRanking.rank`,
    /// `ShoppingListMatcher.cheapestMatch`). Eine Einzelzahl könnte das nicht
    /// sagen; erst die Steigung über die Eingabegröße kann es (Lehre von
    /// `MarktwahlProbe`).
    func testRechenzeitDerAppJeTippOhneProspekt() {
        rechenzeit(vollerProspekt: false)
    }

    /// **Dieselben vier Griffe mit abgeschaltetem Plan-Merker** — der Zustand
    /// vor dem Fix, im selben Bauwerk und derselben Minute gemessen.
    ///
    /// Ein Vorher/Nachher über zwei Builds wäre hier nicht zu trauen: Zwischen
    /// zwei Läufen derselben Sonde lagen am 11.08. 20 %, weil nebenher eine
    /// zweite Sitzung baute. Siehe `UITestSupport.bypassesPlanMemo`.
    func testRechenzeitDerAppJeTippOhneMerker() {
        rechenzeit(vollerProspekt: true, ohneMerker: true)
    }

    private func rechenzeit(vollerProspekt: Bool, ohneMerker: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingTips"]
            + (vollerProspekt
               ? ["-uiTestingOnboardedThreeChains", "-uiTestingBulkOffers", "400"]
               : [])
            + (ohneMerker ? ["-uiTestingOhnePlanMerker"] : [])
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 60))
        for wort in ["Vollmilch", "Butter", "Kartoffeln"] { lege(wort, in: app) }
        XCTAssertTrue(kachel("Vollmilch", in: app).waitForExistence(timeout: 20))

        let optionen = XCTMeasureOptions()
        optionen.iterationCount = 5
        // Vier Griffe je Durchlauf, und sie stellen den Ausgangszustand wieder
        // her: abhaken, aufmachen, Tab hin, Tab zurück.
        measure(metrics: [XCTCPUMetric(application: app)], options: optionen) {
            kachel("Vollmilch", in: app).tap()
            kachel("Vollmilch", in: app).tap()
            app.tabBars.buttons["Angebote"].tap()
            app.tabBars.buttons["Liste"].tap()
        }
    }

    // MARK: Ein Lauf

    private func miss(schilder: Bool, vollerProspekt: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
            + (schilder ? ["-uiTestingTips"] : [])
            + (vollerProspekt
               ? ["-uiTestingOnboardedThreeChains", "-uiTestingBulkOffers", "400"]
               : [])
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
        // **Aufschreiben, ob wirklich ein Schild stand.** Ohne diese Zeile
        // vergleicht der A/B-Lauf womöglich „Schild" gegen „kein Schild" und
        // nennt das eine Regression der Zeichnung. Wer eine Anwesenheit
        // annimmt, braucht eine Stelle, die sie aufschreibt (Lehre vom 10.08.).
        print("PROBE schild-nach-dem-abhaken=\(sichtbaresSchild(app) ?? "keins")")
        reihen.append(tabWechsel(app))
        reihen.append(tabWechselNachKoordinate(app))
        reihen.append(blatt(app))
        reihen.append(waehler(app))

        let kopf: String
        if vollerProspekt { kopf = "voller-prospekt" }
        else if schilder { kopf = "mit-schildern" }
        else { kopf = "ohne-schilder" }
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

    /// **Derselbe Tab-Wechsel, aber auf einen Punkt statt auf ein Element.**
    ///
    /// Der Grund ist ein Messfehler, den die Reihe darüber nicht ausschließen
    /// kann: `app.tabBars.buttons["Angebote"]` muss erst gefunden werden, und
    /// **Suchen kostet mit der Größe des Bedienungshilfen-Baums** — mit
    /// stehendem Schild misst `boden-abfrage` 82 ms je Abfrage statt 49. Ein
    /// Tipp, der nur deshalb länger dauert, ist für einen Menschen kein
    /// langsamerer Tipp.
    ///
    /// Ein Punkt in Fensterkoordinaten braucht keinen Baum. Die Tab-Leiste liegt
    /// unten und rührt sich nicht, egal ob über der Liste ein Schild steht —
    /// dieselben zwei Punkte treffen auf beiden Ständen dieselben zwei Knöpfe.
    private func tabWechselNachKoordinate(_ app: XCUIApplication) -> Reihe {
        // Drei Tab-Knöpfe: Mitten bei 1/6, 3/6, 5/6 der Breite. Senkrecht in
        // der Leiste über der sicheren Fläche.
        let liste = app.coordinate(withNormalizedOffset: CGVector(dx: 1.0 / 6, dy: 0.933))
        let angebote = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.933))
        var ms: [Double] = []
        for i in 0..<6 {
            let ziel = i % 2 == 0 ? angebote : liste
            let t0 = Date()
            ziel.tap()
            ms.append(Date().timeIntervalSince(t0) * 1000)
        }
        // Der Lauf geht auf der Liste weiter.
        liste.tap()
        _ = app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20)
        return Reihe(name: "tab-koordinate", ms: ms)
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
        // **Erst nach oben, dann fragen.** Ein Tab merkt sich, wie weit seine
        // Liste gescrollt war — und der Messtool-Lauf hat sie vorher bis zur
        // „Version" ganz unten gezogen. `settings.places` steht oben, war damit
        // außerhalb des Bildes, und eine `List` baut nicht, was niemand sieht:
        // Die Reihe kam leer zurück und der Lauf war rot, ohne dass an der App
        // etwas war. Dieselbe Falle wie am 03.08. („Erst scrollen, dann
        // fragen"), nur in die andere Richtung.
        for _ in 0..<6 where !orte.exists { app.swipeDown() }
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

    /// Welches der vier Schilder gerade auf dem Bildschirm steht — erkannt an
    /// seiner Überschrift, denn einen Bezeichner setzt `TipView` selbst
    /// (`ContextTipViews`).
    private func sichtbaresSchild(_ app: XCUIApplication) -> String? {
        let titel = ["Mehr als das eine Angebot", "Menge, Größe, Notiz",
                     "Abhaken und Löschen", "Was ab Montag billiger wird"]
        return titel.first { app.staticTexts[$0].exists }
    }

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
