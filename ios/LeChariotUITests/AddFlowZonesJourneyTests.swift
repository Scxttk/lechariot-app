import XCTest

/// **Die drei Zonen beim Tippen** — Scotts Punkt C vom 2026-08-08, nach dem
/// Bring!-Video Bild für Bild ausgewertet.
///
/// > „in bring you got 3 views if you type in a product"
///
/// Am Referenzvideo gemessen (604 × 1314, Bilder bei 0:18–0:44): Tastatur
/// **33 %** von unten, Angaben plus Eingabezeile **46 %**, und der Rest oben —
/// **21 %** — ist die laufende App. Dort steht bei Bring! die Kachelreihe mit
/// dem gerade angelegten Artikel.
///
/// Drei Änderungen daraus, und jede hat hier ihre Journey:
///
/// 1. Die Vorschlagsfläche und die Angaben-Schicht teilen sich einen Platz —
///    es steht immer genau eine da (am 10.08. umgedreht, siehe unten).
/// 2. Der obere Rest **folgt dem zuletzt angelegten Artikel**.
/// 3. „Fertig" sitzt **unten links** an der Tastatur.
///
/// **Der Fokus ist der Preis, auf den hier zu achten ist.** Alle drei fassen
/// den Block an, in dem seit dem 03.08. `keepTyping` den Fokus im Feld hält
/// (siehe `AddFlowJourneyTests`) — deshalb prüft jede Journey hier am Ende,
/// dass weitergetippt werden kann, ohne das Feld neu anzufassen.
final class AddFlowZonesJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
    }

    private var input: XCUIElement { app.textFields["list.input"] }
    /// Den Knopf gibt es seit dem 10.08. nicht mehr (Punkt B-2) — er steht
    /// hier nur noch, damit die Gegenproben ihn benennen können.
    private var toggle: XCUIElement { app.buttons["list.suggestions.toggle"] }
    private var done: XCUIElement { app.buttons["list.input.done"] }

    // MARK: C-1 · Die Fläche folgt dem Tippen (umgedreht am 10.08.)

    /// **Hier stand bis zum 10.08. das Gegenteil.** Der Test hieß
    /// „testTypingStartsWithTheSurfaceCollapsedAndTheChevronOpensIt" und hielt
    /// fest, was Scott am 08.08. wollte: Die Fläche startet beim Tippen
    /// zugeklappt, der Winkel-Knopf holt sie zurück.
    ///
    /// Punkt E der Bedienrunde vom 10.08. dreht es um — nach demselben
    /// Referenzvideo, nur eine Stelle weiter: Bring! zeigt die Vorschläge,
    /// sobald die Tastatur steht, und tauscht sie ab dem ersten Buchstaben
    /// gegen passende Produkte. Der Anlass der alten Regel bleibt trotzdem
    /// gültig und wird hier mitgeprüft: **zwei Schichten übereinander gibt es
    /// nicht.** Nur weicht jetzt die Angaben-Schicht statt der Fläche.
    func testTypingSwapsTheSurfaceInsteadOfStackingTwoLayers() {
        waitForList()

        input.tapAndAwaitKeyboard(in: app)
        app.typeText("Mil")
        XCTAssertTrue(app.staticTexts["list.terms.title"].waitForExistence(timeout: 10),
                      "Die Produkte kommen beim Tippen nicht von selbst\n"
                      + app.debugDescription)
        XCTAssertFalse(toggle.exists, "Der Winkel-Knopf ist wieder da")

        // Anlegen: Jetzt steht die Angaben-Schicht dort, wo eben die Produkte
        // standen — eine Schicht, nie zwei.
        app.typeText("ch\n")
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10),
                      "Nach dem Anlegen fehlt die Angaben-Schicht")
        XCTAssertFalse(app.staticTexts["list.terms.title"].exists,
                       "Produkte und Angaben stehen übereinander")

        // Und beim nächsten Buchstaben tauschen sie zurück.
        app.typeText("B")
        XCTAssertTrue(app.staticTexts["list.terms.title"].waitForExistence(timeout: 10),
                      "Der nächste Buchstabe holt die Produkte nicht zurück")
        XCTAssertFalse(app.buttons["list.detailPanel.more"].exists,
                       "Die Angaben-Schicht bleibt beim Weitertippen stehen")

        // Und der Fokus hat das überstanden: Weitertippen ohne Tipp ins Feld.
        app.typeText("utter\n")
        XCTAssertTrue(app.buttons["Butter"].waitForExistence(timeout: 10),
                      "Nach dem Tauschen war die Tastatur weg")
    }

    // MARK: C-2 · Der obere Rest folgt dem letzten Artikel

    /// **Die Liste scrollt mit, statt an ihrem Anfang stehen zu bleiben.**
    ///
    /// Zwölf Artikel füllen den sichtbaren Streifen über der Angaben-Schicht
    /// mehrfach. Ohne das Mitscrollen stünde dort weiter die Plan-Karte samt
    /// den ersten Kacheln — richtige Auskunft, falscher Moment.
    ///
    /// **Die Gegenprobe steht dabei**, sonst hieße „der letzte ist sichtbar"
    /// nur, dass alles auf einen Bildschirm passt: Der **erste** Artikel muss
    /// aus dem Streifen heraus sein.
    func testTheVisibleStripFollowsTheItemJustTyped() {
        waitForList()
        input.tapAndAwaitKeyboard(in: app)

        let wörter = ["Butter", "Milch", "Kaffee", "Brot", "Eier", "Käse",
                      "Nudeln", "Reis", "Salat", "Gurke", "Zwiebeln", "Joghurt"]
        for wort in wörter { app.typeText("\(wort)\n") }

        let letzte = tile(wörter.last!)
        XCTAssertTrue(letzte.waitForExistence(timeout: 15),
                      "Der zuletzt getippte Artikel steht nirgends\n" + app.debugDescription)
        let ruhe = settled(letzte)

        // **Nicht mehr die Titelleiste**: Die ist beim Tippen ausgeblendet
        // (siehe `ShoppingListView`), und ein Test, der auf sie wartet, wartet
        // auf etwas, das es in diesem Zustand nicht gibt. Oberkante ist die
        // Statusleiste.
        let oben: CGFloat = 44
        let unten = blockTop
        XCTAssertGreaterThanOrEqual(
            ruhe.minY, oben,
            "Der zuletzt angelegte Artikel liegt über der sichtbaren Fläche: "
            + "\(ruhe) | \(lageAller(wörter))"
        )
        XCTAssertLessThanOrEqual(
            ruhe.maxY, unten,
            "Der zuletzt angelegte Artikel liegt unter der sichtbaren Fläche "
            + "(Block ab \(unten)): \(lageAller(wörter))"
        )

        // **Die Gegenprobe.** Ohne sie hieße „der letzte ist sichtbar" nur,
        // dass zwölf Kacheln auf einen Bildschirm passen — der Test wäre auch
        // gegen den Stand von gestern grün. Geprüft wird die **Oberkante** der
        // ersten Kachel: Ihre Unterkante ragte bei zwölf Artikeln um 3 pt in
        // den Streifen hinein, und daran wäre eine richtige Messung
        // gescheitert.
        let erste = tile(wörter.first!)
        XCTAssertTrue(!erste.exists || erste.frame.minY < oben,
                      "Nichts ist gescrollt — die Probe misst nichts: \(erste.frame)")

        // Der Fluss hat das überlebt: das dreizehnte Wort geht ohne einen Tipp
        // ins Feld durch.
        app.typeText("Zucker\n")
        XCTAssertTrue(tile("Zucker").waitForExistence(timeout: 10),
                      "Nach dem Mitscrollen war die Tastatur weg")
    }


    /// **Der aktive Chip steht ganz im Bild** (10.08.).
    ///
    /// Die Kachelzeile der Angaben-Schicht endet an „Notiz …", und der aktive
    /// Chip ist immer der **letzte** — also genau der, den die Kante frisst.
    /// Am gerenderten Bild vom 08.08. war er ab dem vierten Artikel halb
    /// abgeschnitten und ab dem fünften gar nicht mehr da: gefärbt, aber
    /// unlesbar.
    ///
    /// **Gefunden hat das kein Test, und das ist der Grund für diesen hier.**
    /// Die bestehenden Journeys fragen `frame` und `label` der Zeile, und
    /// beide stimmen auch für einen Chip, von dem die Hälfte fehlt. Geprüft
    /// wird deshalb die eine Frage, die das Bild stellt: Liegt der aktive Chip
    /// **vollständig** links von „Notiz …" und rechts vom Bildschirmrand?
    func testTheActiveChipStaysFullyVisibleNextToTheNoteButton() {
        waitForList()
        input.tapAndAwaitKeyboard(in: app)

        let wörter = ["Vollmilch", "Bananen", "Waschmittel", "Kaffeebohnen", "Zahnpasta"]
        for wort in wörter { app.typeText("\(wort)\n") }

        let notiz = app.buttons["list.detailPanel.more"]
        XCTAssertTrue(notiz.waitForExistence(timeout: 15),
                      "Die Angaben-Schicht steht nicht\n" + app.debugDescription)

        // Der aktive Chip trägt den zuletzt getippten Artikel — siehe
        // `ItemDetailPanel.recentChip`; sein Name ist „Angaben zu …", damit er
        // nicht mit der Kachelzeile der Liste kollidiert.
        let aktiv = app.buttons["Angaben zu \(wörter.last!)"].firstMatch
        XCTAssertTrue(aktiv.waitForExistence(timeout: 10),
                      "Der aktive Chip steht nicht in der Zeile\n" + app.debugDescription)
        let rahmen = settled(aktiv)
        let notizRahmen = settled(notiz)

        XCTAssertGreaterThanOrEqual(
            rahmen.minX, 0,
            "Der aktive Chip fängt links außerhalb des Bildschirms an: \(rahmen)"
        )
        XCTAssertLessThanOrEqual(
            rahmen.maxX, notizRahmen.minX,
            "Der aktive Chip läuft unter „Notiz …“: Chip \(rahmen), Notiz \(notizRahmen)"
        )

        // **Die Gegenprobe.** Ohne sie hieße „der letzte ist ganz sichtbar"
        // nur, dass fünf Chips nebeneinander passen — der Test wäre auch gegen
        // den Stand von gestern grün. Nach dem Nachziehen muss der **erste**
        // links hinausgescrollt sein.
        let erster = app.buttons["Angaben zu \(wörter.first!)"].firstMatch
        XCTAssertTrue(!erster.exists || erster.frame.minX < 0,
                      "Nichts ist nachgezogen — die Probe misst nichts: \(erster.frame)")

        // Und der Fluss hat es überlebt: Weitertippen geht ohne einen Tipp
        // ins Feld.
        app.typeText("Zucker\n")
        XCTAssertTrue(app.buttons["Angaben zu Zucker"].firstMatch.waitForExistence(timeout: 10),
                      "Nach dem Nachziehen der Kachelzeile war die Tastatur weg")
    }

    // MARK: Die Aufteilung selbst

    /// **Die drei Zonen als Zahlen** — Scotts Nachrunde vom 08.08.: „Bring!
    /// gibt dem Angaben-Panel ~45 %, du gibst ihm 25 % — genau deshalb liest
    /// es sich nicht wie Bring!."
    ///
    /// Gemessen am Referenzvideo (604 × 1314): oben **20,5 %**, Mitte
    /// **44,8 %**, Tastatur **34,7 %**. Geprüft wird mit ±5 Punkten — der Test
    /// bewacht die Aufteilung, nicht die Dezimalstelle.
    ///
    /// **Nur auf der Geometrie, auf der die Zahlen entstanden sind** (09.08.).
    /// Die drei Anteile wurden auf einem iPhone 17 Pro unter iOS 26.2
    /// abgenommen — 874 pt Fenster, 233 pt Tastatur. Sie sind kein Gesetz für
    /// jeden Bildschirm: Schon eine 10 pt höhere Tastatur (iOS 26.1) lässt die
    /// 44,8 % und eine ganze Kachelreihe über dem Block nicht mehr
    /// gleichzeitig zu, und dann gilt die Kachelreihe
    /// (`testAWholeTileRowStaysAboveTheBlock`, `ItemDetailPanel.vocabulary`).
    /// Gemessen mit drei statt vier Chipreihen: 26.1 **38 %**, iPhone 16e
    /// **39 %** — beides richtig, nur eben nicht die Referenz.
    ///
    /// Übersprungen statt gelockert: Ein Anteil mit ±10 Punkten bewacht nichts
    /// mehr.
    func testTheThreeZonesMatchTheReference() throws {
        waitForList()
        input.tapAndAwaitKeyboard(in: app)
        app.typeText("Haferflocken\n")
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10))

        let hoehe = app.windows.firstMatch.frame.height
        let tastaturOben = app.keyboards.firstMatch.frame.minY
        let tastaturHoehe = app.keyboards.firstMatch.frame.height
        try XCTSkipUnless(
            hoehe == 874 && tastaturHoehe == 233,
            "Die Referenzanteile gelten für 874 pt Fenster und 233 pt Tastatur; "
            + "hier sind es \(Int(hoehe)) und \(Int(tastaturHoehe))"
        )
        let oben = blockTop / hoehe
        let mitte = (tastaturOben - blockTop) / hoehe
        let tastatur = (hoehe - tastaturOben) / hoehe

        XCTAssertEqual(mitte, 0.448, accuracy: 0.05,
                       "Die Angaben-Schicht trifft Bring!s Anteil nicht: \(Int(mitte * 100)) %")
        XCTAssertEqual(oben, 0.205, accuracy: 0.05,
                       "Die App-Ansicht trifft Bring!s Anteil nicht: \(Int(oben * 100)) %")
        XCTAssertEqual(tastatur, 0.347, accuracy: 0.05,
                       "Die Tastatur ist nicht mehr ein Drittel: \(Int(tastatur * 100)) %")
    }

    /// **Der Boden unter der Aufteilung, und er ist die eigentliche Grenze.**
    ///
    /// Ein Anteil allein sagt nichts darüber, ob oben noch etwas *steht*. Seit
    /// #91 ist eine Kachelreihe 112 pt hoch — passt sie nicht mehr über den
    /// Block, ist die obere Zone Zierrat, und genau so sah der erste Anlauf
    /// dieser Runde aus (73 pt übrig, keine ganze Kachel).
    func testAWholeTileRowStaysAboveTheBlock() {
        waitForList()
        input.tapAndAwaitKeyboard(in: app)
        app.typeText("Haferflocken\n")
        let kachel = tile("Haferflocken")
        XCTAssertTrue(kachel.waitForExistence(timeout: 10))
        let ruhe = settled(kachel)

        XCTAssertLessThanOrEqual(ruhe.maxY, blockTop,
                                 "Die Kachelreihe ragt unter den Block")
        // Unter der Statusleiste, nicht dahinter. Die Titelleiste ist beim
        // Tippen weg — deshalb ist die Statusleiste die Oberkante.
        XCTAssertGreaterThanOrEqual(ruhe.minY, 44,
                                    "Die Kachel steht hinter der Statusleiste")
    }

    // MARK: C-3 · „Fertig" unten links

    /// **Die Lage, nicht die Existenz** — der Knopf gab es vorher auch, nur
    /// oben rechts in der Angaben-Schicht.
    func testDoneSitsAtTheBottomLeftAndEndsTheTyping() {
        waitForList()
        input.tapAndAwaitKeyboard(in: app)
        app.typeText("Butter\n")

        XCTAssertTrue(done.waitForExistence(timeout: 10),
                      "Kein Weg hinaus\n" + app.debugDescription)
        XCTAssertLessThanOrEqual(done.frame.maxX, input.frame.minX + 1,
                                 "\u{201E}Fertig\u{201C} geh\u{00F6}rt links neben das Feld")
        XCTAssertFalse(toggle.exists,
                       "Neben \u{201E}Fertig\u{201C} steht wieder ein zweiter Knopf")
        XCTAssertEqual(done.frame.midY, input.frame.midY, accuracy: 4,
                       "\u{201E}Fertig\u{201C} geh\u{00F6}rt auf die H\u{00F6}he der Eingabezeile, an die Tastatur")
        XCTAssertGreaterThan(done.frame.minY, app.frame.midY,
                             "Der Daumen liegt unten, nicht in der Bildschirmmitte")

        XCTAssertFalse(app.buttons["list.detailPanel.dismiss"].exists,
                       "Das alte ✗ steht noch in der Schicht")

        done.tap()
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForNonExistence(timeout: 5),
                      "\u{201E}Fertig\u{201C} r\u{00E4}umt die Angaben-Schicht nicht weg")
        XCTAssertEqual(app.keyboards.count, 0, "Die Tastatur bleibt stehen")
        XCTAssertTrue(app.buttons["Butter"].exists,
                      "\u{201E}Fertig\u{201C} ist kein Abbrechen \u{2014} der Artikel bleibt")
    }

    /// **Und ohne Tastatur genauso.** Der Weg über „Häufig auf der Liste" war
    /// Scotts Punkt 9 vom 03.08.; bis heute trug ihn das ✗ der Schicht.
    func testDoneIsTheWayOutWithoutAnyKeyboardToo() {
        waitForList()
        app.buttons["Milch hinzufügen"].tap()

        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.keyboards.count, 0,
                       "Dieser Weg soll ohne Tastatur laufen — sonst prüft die Journey den anderen")
        XCTAssertTrue(done.exists, "Ohne Tastatur gibt es keinen Weg hinaus")

        done.tap()
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Milch"].exists)
    }

    // MARK: Der Bilderbogen

    /// **Ein Bild des Tipp-Bildschirms, so wie er läuft** — für den Vergleich
    /// mit dem Bring!-Video nebeneinander.
    ///
    /// Läuft nur auf Zuruf, sonst schreibt jeder Testlauf ein PNG:
    ///
    ///     TEST_RUNNER_LECHARIOT_ZONES_SHOT=/pfad/bild.png xcodebuild test …
    ///
    /// **Das Präfix `TEST_RUNNER_` gehört dazu** — `xcodebuild` reicht nur so
    /// präfigierte Variablen an den Prozess weiter, in dem die Tests laufen.
    /// Ohne es wird der Bogen still übersprungen (derselbe Nebenfund wie am
    /// 08.08. bei `ListDirectionShots`).
    ///
    /// Ein Bildschirmfoto und kein Nachbau: Was hier zu vergleichen ist, sind
    /// **Anteile** — und die entstehen aus Tastatur, Schicht und Liste
    /// zusammen, also genau aus dem, was nur die laufende App hat.
    func testWriteTheThreeZones() throws {
        // **Übersprungen, nicht rot** — eine Suite, in der immer ein Test rot
        // ist, hört auf, etwas zu bedeuten.
        guard let ziel = ProcessInfo.processInfo.environment["LECHARIOT_ZONES_SHOT"] else {
            throw XCTSkip("ohne LECHARIOT_ZONES_SHOT wird nichts geschrieben")
        }
        waitForList()
        input.tapAndAwaitKeyboard(in: app)
        for wort in ["Butter", "Milch", "Kaffee", "Brot", "Eier", "Käse",
                     "Nudeln", "Reis", "Joghurt", "Haferflocken"] {
            app.typeText("\(wort)\n")
        }
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10))
        let ruhe = settled(tile("Haferflocken"))
        print("ZONEN letzte=\(ruhe)")

        let bild = XCUIScreen.main.screenshot()
        try bild.pngRepresentation.write(to: URL(fileURLWithPath: ziel))

        // Die Kanten, aus denen die Anteile gerechnet werden — im Protokoll,
        // damit die Zahlen im Bild nicht abgelesen werden müssen.
        print("ZONEN fenster=\(app.windows.firstMatch.frame)")
        print("ZONEN block=\(blockTop)")
        print("ZONEN tastatur=\(app.keyboards.firstMatch.frame)")
    }

    // MARK: Helfer

    /// Wo alle Kacheln stehen — nur für die Fehlermeldung, und deshalb als
    /// Funktion: Die Meldung eines `XCTAssert` wird erst im Fehlerfall
    /// ausgewertet, zwölf Abfragen an den Elementbaum kosten sonst jeden Lauf.
    private func lageAller(_ namen: [String]) -> String {
        namen.map { name in
            let k = tile(name)
            return "\(name)=\(k.exists ? "\(k.frame)" : "-")"
        }.joined(separator: " ")
    }

    /// **Warten, bis das Mitscrollen zu Ende ist** — und zwar am Bild, nicht
    /// an einer Wartezeit. Zwölf Artikel hintereinander heißen zwölf
    /// Scroll-Bewegungen; wer gleich nach dem letzten Wort misst, misst eine
    /// davon mitten in der Fahrt (gemessen: y = −3, während die Kachel
    /// hinterher bei 236 stand).
    ///
    /// Zwei gleiche Messungen hintereinander sind das Signal. Ein festes
    /// `sleep` wäre die andere Möglichkeit und die schlechtere: Es ist auf
    /// einem langsamen Rechner zu kurz und auf jedem anderen zu lang.
    private func settled(_ element: XCUIElement) -> CGRect {
        var vorher = element.frame
        var ruhig = 0
        for _ in 0..<60 {
            usleep(100_000)
            let jetzt = element.frame
            ruhig = jetzt == vorher ? ruhig + 1 : 0
            vorher = jetzt
            // Vier gleiche Messungen, nicht zwei: Zwölf Artikel heißen zwölf
            // aneinandergereihte Bewegungen, und zwischen zweien davon steht
            // das Bild kurz still.
            if ruhig >= 4 { return jetzt }
        }
        return vorher
    }

    /// Die Kachel eines Artikels. Ihre Beschriftung trägt Angaben und Angebot
    /// mit, deshalb `BEGINSWITH` — siehe `ShoppingGridTile`.
    ///
    /// **Der Bezeichner gehört dazu, und das ist gemessen.** Ohne ihn traf
    /// `firstMatch` mal die Kachel (84 pt breit) und mal die Rasterzeile, die
    /// sie enthält (402 pt) — und damit maß derselbe Test zweimal etwas
    /// anderes.
    private func tile(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND label BEGINSWITH %@", "list.tile", name
        )).firstMatch
    }

    /// Die Oberkante des Blocks unten: die Angaben-Schicht, wo sie steht,
    /// sonst die Eingabezeile. Dasselbe Maß wie in
    /// `AddFlowContractJourneyTests`, nur von der anderen Seite gebraucht.
    /// **Die Oberkante des Blocks unten — an der Kachelzeile, nicht an
    /// „Notiz …".** Seit dem Umbau auf ein hohes Panel steht die Notiz
    /// **unten** im Block; sie als Oberkante zu nehmen maß den Block um seine
    /// ganzen Chipreihen zu kurz.
    private var blockTop: CGFloat {
        let kacheln = app.buttons["list.detailPanel.recent"].firstMatch
        return kacheln.exists ? kacheln.frame.minY - 8 : input.frame.minY - 8
    }

    private func waitForList() {
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Keine Eingabezeile")
    }
}
