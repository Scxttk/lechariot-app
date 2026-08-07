import XCTest

/// Barrierefreiheit **gemessen**, nicht gerechnet.
///
/// Die Kontrastwerte aus Phase 7 stammen aus einer Rechnung über die
/// Theme-Paare. Eine Rechnung sagt nichts darüber, welche Farbe am Ende
/// tatsächlich auf welcher Fläche landet — dafür gibt es `performAccessibilityAudit`,
/// das den gerenderten Bildschirm prüft: Kontrast, Trefferflächen, abgeschnittene
/// Beschriftungen, Elemente ohne Label.
///
/// Läuft in jedem Testlauf mit, statt einmalig von Hand durch den
/// Accessibility Inspector geklickt zu werden.
///
/// **Gedacht für den Simulator im hellen Modus** — dort steht das Gate. Auf
/// einem Gerät, das im Dunkelmodus läuft, meldet der Audit zusätzlich die
/// sekundäre Systemfarbe als harten Durchfaller; die ist real (gemessen
/// 3,15:1 auf der Creme, 3,93:1 auf den Karten), betrifft 41 Stellen quer
/// durch die App und steht als eigener Umbau im Backlog. Bis der gemacht ist,
/// wäre ein Gate darauf nur Dauerrot.
final class AccessibilityAuditTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = true   // alle Befunde eines Laufs sehen, nicht nur den ersten
        app = XCUIApplication()
    }

    /// Jeder Test sagt selbst, wo er anfangen will. Vorher startete `setUp` für
    /// alle im Assistenten, und fünf von sechs Tests klickten sich anschließend
    /// durch ihn hindurch — für einen Zustand, den nur einer von ihnen misst.
    private func launch(behindOnboarding: Bool, arguments: [String] = []) {
        app.launchArguments = ["-uiTesting"]
            + (behindOnboarding ? ["-uiTestingOnboarded"] : [])
            + arguments
        app.launch()
        if behindOnboarding {
            XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20),
                          "Der Start hinter dem Assistenten landet nicht in der Liste")
        }
    }

    // MARK: Audits

    func testOnboardingPassesTheAudit() throws {
        launch(behindOnboarding: false)
        XCTAssertTrue(app.buttons["onboarding.primary"].waitForExistence(timeout: 15))
        try audit("Willkommen")

        app.tippe(app.buttons["onboarding.primary"], "Weiter auf Willkommen")
        app.tippe(app.buttons["onboarding.skip"], "Überspringen auf der Profilseite")
        // Erst die PLZ tippen: „Weiter" ist bis dahin deaktiviert, und ein
        // ausgegrauter Knopf ist von der Kontrastanforderung ausgenommen.
        // Ungetippt misst der Audit einen Zustand, den niemand benutzt.
        let plz = app.textFields["region.input"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15))
        plz.tap()
        plz.typeText("01219")
        try audit("Ort oder Postleitzahl")
        app.tippe(app.buttons["onboarding.primary"], "Weiter nach der Postleitzahl")
        // Erst eine Kette antippen, dann messen — dieselbe Regel wie oben:
        // Der gewählte Zustand (Akzent auf Akzentfläche) ist der, den Nutzer
        // sehen; ungewählt misst der Audit nur die halbe Palette. Auf den
        // Chip warten, nicht blind tippen: Die Ketten stehen erst nach der
        // Verzeichnis-Antwort da (im Mock-Lauf sofort, aber nicht in null
        // Bildern).
        let chip = app.buttons["Lidl"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "Ketten-Chips nicht geladen")
        chip.tap()
        try audit("Welche Märkte magst du")
        app.tippe(app.buttons["onboarding.skip"], "Später auf der Kettenseite")
        try audit("Belohnung")
        app.tippe(app.buttons["onboarding.primary"], "Weiter auf der Belohnung")
        try audit("Einwilligung")

        // Der Assistent endet seit dem 2026-07-31 in der Liste — **ohne
        // Filiale**, und damit in einem Zustand, den es vorher nicht gab. Er
        // wird hier mitgemessen: Er ist der erste Bildschirm, den ein Tester zu
        // sehen bekommt, und er trägt einen Knopf und zwei Absätze, die es
        // vorher nirgends gab.
        app.tippe(app.buttons["onboarding.primary"], "Weiter auf der Einwilligung")
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        try audit("Einkaufsliste ohne Filiale")

        // Der Picker, jetzt von dort aus geöffnet. Er ist der einzige
        // Bildschirm, auf dem eine Zeile ihren Zustand trägt (gewählt/nicht
        // gewählt) und ihre Entfernung im Hinweis statt im Namen.
        //
        // Erst eine Filiale antippen, dann messen — dieselbe Regel wie weiter
        // oben bei der Postleitzahl. Ungewählt meldet der Audit zwei Dinge, die
        // beide nicht die Farbe betreffen: „Fertig" ist bis dahin
        // **deaktiviert** und damit von der Anforderung ausgenommen, und die
        // Fußzeile „Wähle mindestens eine Filiale, um fortzufahren." liegt auf
        // `.bar` — genau die durchscheinende Fläche, für die weiter unten in
        // dieser Datei nachgemessen ist, dass der Audit Zwischenwerte liest.
        // Sie ist ohnehin `accessibilityHidden`, weil ihr Inhalt im Hinweis des
        // Knopfes steht.
        //
        // Seit dem 2026-08-01 liegen die Filialen hinter der Kettenzeile. Die
        // Kettenseite wird deshalb mitgemessen — sonst fiele mit dem Umbau
        // genau die Zeile aus dem Audit, um die es hier geht.
        app.buttons["list.chooseMarkets"].tap()
        let chain = app.buttons["picker.chain.Lidl"]
        XCTAssertTrue(chain.waitForExistence(timeout: 15), "Picker nicht geladen")
        chain.tap()
        let branch = app.buttons["Lidl, Dresden Reick"]
        XCTAssertTrue(branch.waitForExistence(timeout: 15), "Kettenseite nicht geladen")
        branch.tap()
        try audit("Lidl")

        app.buttons["chain.done"].tap()
        XCTAssertTrue(app.buttons["picker.chain.Lidl"].waitForExistence(timeout: 10))
        try audit("Filialen wählen")
    }

    func testShoppingListAndSettingsPassTheAudit() throws {
        launch(behindOnboarding: true)
        addItem("Vollmilch")
        try audit("Einkaufsliste")

        app.tapInTileMenu("list.matches")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
        try audit("Treffer-Sheet")

        app.buttons["Weglegen"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Kurze Rückfrage"].waitForExistence(timeout: 10))
        // Erst einen Grund wählen: „Senden" ist vorher deaktiviert, und ein
        // deaktivierter Knopf ist von der Kontrastanforderung ausgenommen —
        // ohne diesen Tipp würde der Audit den ausgegrauten Zustand messen
        // statt den, den man tatsächlich benutzt.
        app.buttons["Passt gar nicht zum Artikel. Ein ganz anderes Produkt"].tap()
        try audit("Rückfrage")
        app.buttons["Überspringen"].tap()

        app.buttons["Fertig"].firstMatch.tap()
        openTab("Angebote")
        try audit("Angebote")
        openTab("Einstellungen")
        // **Zuerst oben messen, dann unten.** Was hier hinter der
        // Navigationsleiste liegt, steht nach dem Scrollen frei — und
        // umgekehrt. Eine einzige Messung lässt die halbe Liste ungeprüft,
        // und genau das war der Zustand, seit das Gate aus war.
        try audit("Einstellungen oben")

        // Ans Ende scrollen, bevor noch einmal gemessen wird.
        //
        // Nachgewiesen am 2026-07-26: Ohne das Scrollen meldet der Audit
        // Kontrastfehler für „Rückfragen", den zugehörigen Fußtext und
        // „Nach Ablehnungen fragen" — **mit** dem Scrollen für „Profil",
        // „Region hinzufügen" und „Nur in Entwicklungs-Builds sichtbar.".
        // Der durchgefallene Satz folgt also der Bildschirmposition, nicht der
        // Farbe: Gemessen wird, was gerade hinter der durchscheinenden
        // Tab-Leiste liegt. Derselbe Effekt ist für den dunklen Modus unten
        // schon beschrieben. Nach dem Scrollen fällt nichts mehr durch.
        //
        // Seit dem 2026-07-28 reicht **ein** Wisch nicht mehr: Der
        // Hilfe-Abschnitt ist dazugekommen. Eine feste Zahl Wische reicht aber
        // auch nicht — wie weit einer trägt, hängt am Schwung, und ein Lauf
        // blieb mitten in der Liste stehen, genau in der Position, in der der
        // Audit wieder Zwischenwerte hinter der Tab-Leiste misst. Deshalb
        // wischen, **bis das Ende wirklich da ist**.
        //
        // Die Endmarke war bis zum 2026-07-30 der Fußtext des Debug-Abschnitts.
        // Den gibt es nicht mehr: Das Zurücksetzen ist in die Hilfe gewandert
        // und ab jetzt in jedem Build da.
        //
        // Jetzt ein **Bezeichner** auf der letzten Zeile statt eines Satzes.
        // Die Marke war zweimal deutscher Fließtext und ist zweimal gebrochen,
        // sobald sich der Text änderte; ein Bezeichner ändert sich nur, wenn
        // ihn jemand absichtlich ändert. `descendants(matching: .any)`, weil
        // `LabeledContent` je nach iOS-Version nicht als `staticText`
        // durchschlägt — genau daran ist der erste Versuch gescheitert.
        let lastRow = app.descendants(matching: .any)["settings.end"]
        // Großzügig statt knapp: Die Kappe ist an dieser Sektion schon einmal
        // gerissen, und sie wächst weiter (2026-07-31 kam die Installations-ID
        // dazu). Zu viele Wische kosten nichts, zu wenige kosten einen roten
        // Lauf ohne echten Befund.
        var swipes = 0
        while !lastRow.exists && swipes < 14 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(lastRow.exists, "Ende der Einstellungen nicht erreicht")
        // **Kontrast hier wieder scharf, seit dem 2026-08-01.**
        //
        // Vom 28.07. bis dahin war das Gate aus, mit der Begründung „der
        // durchgefallene Satz folgt der Bildschirmposition, nicht der Farbe".
        // Die Beobachtung stimmt, die Schlussfolgerung war zu früh: Es folgt
        // nicht *irgendeiner* Position, sondern **genau den zwei
        // durchscheinenden Systemleisten**. Nachgemessen mit den Rahmen aller
        // Befunde — die Tabelle steht in `translucentBarRegions()`. Kein
        // einziger harter Befund lag im freien Feld.
        //
        // Damit ist die Ausnahme so eng wie der Befund: nicht „Kontrast in den
        // Einstellungen zählt nicht", sondern „hinter einer Leiste misst
        // niemand". Und weil jetzt an zwei Positionen gemessen wird, ist die
        // Liste besser abgedeckt als vor dem Abschalten.
        try audit("Einstellungen unten")

        // **Filialen und Regionen liegen seit dem 2026-08-01 eine Seite
        // tiefer** ([UI-2]). Ohne diesen Schritt fielen beide Listen aus dem
        // Audit — genau die zwei Abschnitte, die vorher die erste Seite
        // ausgemacht haben.
        var back = 0
        while !app.buttons["settings.places"].exists && back < 14 {
            app.swipeDown()
            back += 1
        }
        app.buttons["settings.places"].tap()
        XCTAssertTrue(app.navigationBars["Filialen und Regionen"].waitForExistence(timeout: 10))
        try audit("Filialen und Regionen")
    }

    /// Der dunkle Modus hat eigene Farbwerte — die Rechnung deckte beide ab,
    /// gemessen war bisher keiner von beiden.
    ///
    /// Hier wird **protokolliert, nicht durchgefallen**, und zwar aus einem
    /// nachgemessenen Grund: Der Audit meldet in diesem Durchlauf „Contrast
    /// failed" für Titel und Zwischenüberschriften, die tatsächlich weit über
    /// der Anforderung liegen. Am Screenshot desselben Zustands nachgemessen:
    /// Navigationstitel **16,83:1**, Akzent „Lidl" auf der Karte **6,64:1**,
    /// Zeilentext **13,93:1**. Der Audit liest offenbar Zwischenwerte, wenn
    /// Inhalt hinter der durchscheinenden Leiste liegt oder die Fenster-
    /// Überblendung des Erscheinungsbild-Wechsels noch nachwirkt. Ein Gate auf
    /// Werte, die den gerenderten Pixeln widersprechen, wäre Aberglaube.
    func testTheShoppingListPassesTheAuditInDarkMode() throws {
        launch(behindOnboarding: true)
        openTab("Einstellungen")
        // „Darstellung" liegt unter dem Falz — ohne Scrollen findet XCUITest
        // die Segmente nicht, und die Segmente sind Kinder des Controls,
        // nicht freie Buttons.
        let dark = app.segmentedControls.buttons["Dunkel"].firstMatch
        var swipes = 0
        while !dark.exists && swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(dark.waitForExistence(timeout: 10), "Darstellungs-Umschalter fehlt")
        dark.tap()
        openTab("Liste")
        addItem("Vollmilch")
        try audit("Einkaufsliste dunkel", failOnContrast: false)
        openTab("Einstellungen")
        try audit("Einstellungen dunkel", failOnContrast: false)
    }

    /// Der Rundgang, gemessen — **ohne** Kontrast-Gate, und das ist hier keine
    /// Bequemlichkeit, sondern die einzige ehrliche Einstellung.
    ///
    /// Der Bildschirm ist absichtlich zur Hälfte abgedunkelt: Alles außer dem
    /// hervorgehobenen Bedienelement liegt unter 60 % Schwarz. Der Audit misst
    /// diese Texte mit und meldet sie als durchgefallen — richtig gemessen und
    /// trotzdem kein Befund, denn genau das ist der Zweck. Gemeldet werden
    /// dabei auch die beiden Knöpfe der Karte, und die liegen **über** dem
    /// Schleier auf `Theme.surface`: `Theme.onAccent` auf `Theme.accent`
    /// (6,74:1) und `Theme.secondaryText` auf der Karte (5,89:1) — dieselben
    /// Paare, die in jedem anderen Audit dieser Datei durchgehen. Ein Gate
    /// darauf wäre Dauerrot für eine Abdunklung, die so gewollt ist.
    ///
    /// Was **bleibt**: `sufficientElementDescription`. Ein Element ohne Label
    /// ist auch auf einem abgedunkelten Bildschirm ein Fehler.
    ///
    /// Eigener Start: Unter `-uiTesting` allein ist der Rundgang aus.
    func testTheTutorialPassesTheAudit() throws {
        launch(behindOnboarding: false, arguments: ["-uiTestingTutorial"])

        app.tippe(app.buttons["onboarding.primary"], "Weiter auf Willkommen")
        app.tippe(app.buttons["onboarding.skip"], "Überspringen auf der Profilseite")
        enterPLZ()
        app.tippe(app.buttons["onboarding.skip"], "Später auf der Kettenseite")
        app.tippe(app.buttons["onboarding.primary"], "Weiter auf der Belohnung")
        app.tippe(app.buttons["onboarding.primary"], "Weiter auf der Einwilligung")

        XCTAssertTrue(app.staticTexts["Alles bereit. Einmal kurz zeigen?"]
            .waitForExistence(timeout: 15))
        // Das Angebot ist ein normaler Onboarding-Bildschirm ohne Schleier und
        // wird deshalb wie alle anderen scharf geprüft.
        try audit("Rundgang-Angebot")

        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")
        XCTAssertTrue(app.buttons["tutorial.next"].waitForExistence(timeout: 15))
        try audit("Rundgang", failOnContrast: false)
    }

    // MARK: VoiceOver-Zuschnitt

    /// Eine Äußerung pro Zeile, nicht sechs Bruchstücke: die Vorschlagskachel
    /// muss **ein** Element mit einem ganzen Satz sein. Genau das war schon
    /// einmal kaputt (`.accessibilityElement(children: .ignore)` auf einem
    /// Button verschluckt das folgende Label), deshalb steht es hier fest.
    func testTheSuggestionTileIsOneElementWithAWholeSentence() {
        launch(behindOnboarding: true)
        addItem("Vollmilch")

        // Seit dem Raster (07.08.) trägt die Kachel den Artikel im **Label**
        // und alles Wechselnde im **Wert** — die Falle bleibt dieselbe, nur
        // das Feld ist ein anderes.
        let tile = app.buttons["list.tile"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15))
        let satz = (tile.value as? String) ?? ""
        XCTAssertEqual(tile.label, "Vollmilch", "Der Artikel gehört ins Label: \(tile.label)")
        XCTAssertTrue(satz.contains("Bio Vollmilch"), "Produkt fehlt in der Äußerung: \(satz)")
        XCTAssertTrue(satz.contains("Lidl"), "Markt fehlt in der Äußerung: \(satz)")
        XCTAssertTrue(satz.count > 20, "klingt nach Bruchstück statt Satz: \(satz)")
    }

    /// Dieselbe Falle, zweite Stelle: Die Angebotszeile ist jetzt ein Button,
    /// und `.accessibilityElement(children: .ignore)` auf einem Button
    /// verschluckt das Label, das danach kommt. Ohne diesen Test würde die
    /// Zeile stumm oder als Schnipselsalat gelesen, ohne dass es auffällt.
    func testTheOfferRowIsOneButtonWithAWholeSentence() {
        launch(behindOnboarding: true)
        openTab("Angebote")

        let row = app.buttons["offers.row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        let label = row.label
        XCTAssertTrue(label.contains("Bio Vollmilch"), "Produkt fehlt in der Äußerung: \(label)")
        XCTAssertTrue(label.contains("Lidl"), "Markt fehlt in der Äußerung: \(label)")
        XCTAssertTrue(label.contains("€"), "Preis fehlt in der Äußerung: \(label)")
        XCTAssertTrue(label.count > 20, "klingt nach Bruchstück statt Satz: \(label)")
    }

    /// Die Einkaufsplan-Karte wird als Ganzes gelesen — ihre Kopfzeile ist ein
    /// Element mit einer Zusammenfassung, nicht vier einzelne Textschnipsel.
    func testThePlanCardIsReadAsAWhole() {
        launch(behindOnboarding: true)
        addItem("Vollmilch")

        let summary = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@",
                                  "Am besten zu", "Kein Markt hat diese Woche"))
            .firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 15),
                      "Die Karte muss eine zusammenfassende Äußerung haben")
        // Ein Satz, nicht vier Schnipsel: Markt, Abdeckung und Summe stehen
        // zusammen in einer Äußerung. Ob die Einzeltexte daneben noch im
        // Baum liegen, entscheidet SwiftUI — geprüft wird, was VoiceOver
        // tatsächlich als Element vorliest.
        XCTAssertTrue(summary.label.contains("Artikeln"),
                      "Abdeckung fehlt in der Äußerung: \(summary.label)")
        XCTAssertTrue(summary.label.count > 30,
                      "klingt nach Bruchstück statt Satz: \(summary.label)")
    }

    // MARK: Helfer

    /// Prüft einen Bildschirm und lässt den Test bei **Kontrast**- und
    /// **Beschriftungs**-Befunden durchfallen.
    ///
    /// Die übrigen Kategorien werden nur protokolliert. Das ist kein Wegsehen,
    /// sondern nachgeprüft: `dynamicType` meldet die Emoji-Kachel und die
    /// Preise mit `monospacedDigit` (feste Symbolgröße bzw. sehr wohl
    /// skalierende Systemschrift), `textClipped` meldet Texte, die auf dem
    /// Screenshot vollständig stehen, und `hitRegion` die Fortschrittspunkte
    /// des Onboardings, die gar nicht antippbar sind. Wer eine dieser
    /// Kategorien scharf schaltet, bekommt Dauerrot und schaut bald gar nicht
    /// mehr hin.
    ///
    /// **Geprüft wird nur noch, worauf auch ein Gate steht** — siehe
    /// `geprüfteArten`.
    private func audit(_ screen: String, failOnContrast: Bool = true) throws {
        // Erst zur Ruhe kommen lassen. Wird während eines Übergangs gemessen —
        // Tabwechsel, einblendende Liste —, liest der Audit Mischwerte und
        // meldet Kontrastfehler für Texte, die im Ruhezustand einwandfrei sind.
        // Dieselbe Falle wie im dunklen Modus, siehe oben.
        waitUntilStill()
        let blurred = translucentBarRegions()
        let keyboard = softwareKeyboardRegion()
        try app.performAccessibilityAudit(for: Self.geprüfteArten) { issue in
            let element = issue.element?.description ?? "kein benanntes Element"
            // Der Rahmen gehört ins Protokoll, nicht nur der Text: Ob ein
            // Kontrast-Befund echt ist, entscheidet sich seit dem 01.08. an
            // der Frage, **wo** das Element lag. Ohne die Zahl ist jeder
            // Befund wieder eine Vermutung.
            let frame = issue.element.map { "\($0.frame)" } ?? "-"
            print("AUDIT|\(screen)|\(issue.auditType.rawValue)|\(issue.compactDescription)|\(element.prefix(120))|\(frame)")

            // Der Name stimmte schon vor dem iPad nicht mehr genau — es sind
            // die Flächen, in denen der Audit nicht die gezeichnete Farbe
            // liest: hinter den durchscheinenden Leisten, im Schatten der
            // Plan-Karte, und außerhalb des sichtbaren Ausschnitts.
            let notWhereItLooks = issue.auditType == .contrast
                && issue.element.map { e in blurred.contains { $0.intersects(e.frame) } } == true
            // Apples Tastatur ist nicht unsere Fläche — weder ihre Tasten noch
            // das, was sie verdeckt.
            let onApplesKeyboard = issue.element.map { keyboard.intersects($0.frame) } == true
            let handledElsewhere = Self.knownSystemDrawn.contains { element.contains($0) }
                || (issue.auditType == .contrast && issue.element == nil)
                || notWhereItLooks
                || onApplesKeyboard
            // Nur harte Durchfaller. „nearly passed" trifft flächendeckend die
            // sekundäre Systemfarbe (gemessen 3,15:1 auf der Creme, 3,93:1 auf
            // den Karten) — ein bekannter, im Backlog stehender Umbau, kein
            // Regressionssignal. Wer ihn hier scharf schaltet, hat Dauerrot.
            let isHardFailure = failOnContrast
                && issue.auditType == .contrast
                && issue.compactDescription.contains("failed")
            let missingDescription = issue.auditType == .sufficientElementDescription
            if (isHardFailure || missingDescription) && !handledElsewhere {
                XCTFail("[\(screen)] \(issue.compactDescription) — \(element)")
            }
            return true   // selbst berichtet
        }
    }

    /// Die Fläche, in der die durchscheinende Suchleiste den Kontrast
    /// verfälscht — sie selbst plus der weich auslaufende Verlauf darüber, den
    /// iOS über scrollenden Inhalt legt.
    ///
    /// Der Audit misst dort **Mischfarben** statt der gezeichneten. Aufgefallen
    /// im Filialpicker: „REWE Friedrichstadt" fiel durch, gesetzt in `.primary`
    /// — fast Schwarz auf Weiß, rund 15:1. Ein Text, der bei 15:1 durchfällt,
    /// wird nicht gemessen, sondern durch etwas hindurch gemessen; dieselben
    /// zwei Farben gehen drei Zeilen weiter oben anstandslos durch.
    ///
    /// Der Fehler ist obendrein sprunghaft — in vier Läufen desselben Tests
    /// trat er einmal auf; in den anderen drei meldete der Audit dieselben
    /// Stellen **ohne Element** und war damit schon durch die Zeile darüber
    /// ausgenommen. Ein Test, der in jedem vierten Lauf rot wird, ist kein
    /// Signal mehr.
    ///
    /// Die Höhe des Verlaufs ist aus dem Layout abgeleitet, nicht auf diesen
    /// einen Bildschirm gepasst: eine Leistenhöhe plus die sichere Fläche
    /// darunter. Gemessen am iPhone 17 Pro (Fenster 402 × 874 pt, Leiste bei
    /// y = 803, 38 pt hoch, 33 pt sichere Fläche) liegt die Grenze damit bei
    /// y = 732 — zwischen dem tiefsten korrekt beurteilten Element (Abschnitts-
    /// überschrift „REWE", endet bei 705) und dem flachsten falsch beurteilten
    /// (Adresszeile, beginnt bei 743).
    ///
    /// Ohne Suchleiste ist die Fläche leer, und `CGRect.null` schneidet nichts.
    ///
    /// **Und ohne Suchleiste *unten* auch**, seit dem 2026-08-01. Die ganze
    /// Rechnung oben setzt voraus, dass die Leiste am **unteren** Rand klebt
    /// — auf dem iPhone tut sie das. Auf dem iPad sitzt dieselbe Suchleiste
    /// oben rechts in der Navigationsleiste, gemessen bei (778, 32, 240, 44)
    /// im Fenster 1032 × 1376. Eingesetzt ergibt das einen Verlauf von
    /// 44 + (1376 − 76) = **1344 pt** und eine Fläche ab y = −1312: der
    /// **ganze Bildschirm** wäre von der Kontrastprüfung ausgenommen, und
    /// zwar ohne dass irgendetwas rot geworden wäre. Ein Gate, das still
    /// alles durchwinkt, ist schlimmer als eines, das fehlt.
    ///
    /// Deshalb die Bedingung: Nur eine Leiste, die tatsächlich in der unteren
    /// Hälfte steht, bekommt ihr Band. Steht sie oben, deckt die
    /// Navigationsleiste sie ohnehin ab — die Fläche dafür steht unten in
    /// `translucentBarRegions()`.
    private func scrollEdgeRegion() -> CGRect {
        let search = app.searchFields.firstMatch
        guard search.exists else { return .null }
        let bar = search.frame
        let window = app.windows.firstMatch.frame
        guard bar.midY > window.midY else { return .null }
        let gradient = bar.height + (window.maxY - bar.maxY)
        let top = bar.minY - gradient
        return CGRect(x: window.minX, y: top, width: window.width, height: window.maxY - top)
    }

    /// **Die Tastatur samt ihrer Vorschlagsleiste — Apples Fläche, nicht unsere.**
    ///
    /// Aufgetaucht am 2026-08-03, als das Regionsfeld vom Ziffernblock auf die
    /// volle Tastatur wechselte („Anklam" tippen dürfen). Der Ziffernblock hat
    /// keine QuickType-Leiste, die Buchstabentastatur hat eine — und ihre drei
    /// leeren Vorschlagsfelder tragen **keine Beschriftung**. Der Audit meldete
    /// prompt dreimal „Element has no description".
    ///
    /// **Gemessen, nicht geschätzt** (iPhone 17 Pro, Fenster 402 × 874): Die
    /// Tastatur steht bei (0, 583, 402, 233); die drei Felder liegen bei
    /// y = 539 … 583, je 134 pt breit — zusammen exakt die Fensterbreite, und
    /// mit ihrer Unterkante **bündig auf der Tastaturoberkante**.
    ///
    /// Die Leiste ist deshalb ein Streifen über der Tastatur, eine
    /// Berührungsfläche hoch (44 pt — die gemessene Höhe **und** die
    /// Mindestgröße, die iOS für Antippbares vorgibt; keine an diesen einen
    /// Bildschirm gepasste Zahl).
    ///
    /// Ohne Tastatur ist die Fläche leer, und `CGRect.null` schneidet nichts.
    private func softwareKeyboardRegion() -> CGRect {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return .null }
        let bar = 44.0
        let frame = keyboard.frame
        return CGRect(x: frame.minX, y: frame.minY - bar,
                      width: frame.width, height: frame.height + bar)
    }

    /// **Was gar nicht auf dem Bildschirm steht.**
    ///
    /// Der Audit meldet auch Elemente, die außerhalb des sichtbaren
    /// Ausschnitts ihres scrollenden Behälters liegen. Auf dem iPhone fiel
    /// das als negatives y auf („Regionen", −34 … 6) und wurde von der nach
    /// oben offenen Navigationsleisten-Fläche mit erledigt. Auf dem iPad
    /// passiert dasselbe **nach unten**, und dort hat es bisher niemand
    /// aufgefangen: Im Filialpicker steht die Liste in einem Blatt, dessen
    /// Behälter bei (226, 358, 580, 650) endet — also bei y = 1008. Gemeldet
    /// wurden „Friedrichstadt" (y = 1057) und zwei Adresszeilen (1012,
    /// 1079,5), alle drei **unterhalb** davon. Dieselbe Sorte Befund in der
    /// Rückfrage: „Anderes" bei 1037, „Sag uns gern, was los ist" bei 1059,5,
    /// Behälter zu Ende bei 1008.
    ///
    /// Eine Farbe, die nicht gezeichnet wird, hat keinen Kontrast. Das ist
    /// die eine Ausnahme in dieser Datei, die keine Vermutung über eine
    /// Ebene enthält — sie sagt nur, dass dort nichts zu sehen ist.
    ///
    /// Der Behälter wird in der Reihenfolge gesucht, in der SwiftUI ihn
    /// baut: `List` und `Form` werden auf modernem iOS eine `collectionView`,
    /// ältere Aufbauten eine `table`, freie Inhalte eine `scrollView`.
    private func offscreenRegions() -> [CGRect] {
        let candidates = [app.collectionViews.firstMatch,
                          app.tables.firstMatch,
                          app.scrollViews.firstMatch]
        guard let box = candidates.first(where: { $0.exists })?.frame, box.height > 0 else {
            return []
        }
        return [CGRect(x: -10_000, y: -10_000, width: 20_000, height: 10_000 + box.minY),
                CGRect(x: -10_000, y: box.maxY, width: 20_000, height: 10_000)]
    }

    /// **Die Einkaufsplan-Karte, als Fläche statt als Wortliste.**
    ///
    /// Für diese eine Karte ist nachgewiesen, dass der Audit durch ihren
    /// `.shadow` hindurch misst: Am 2026-07-31 wurde an der baugleichen
    /// Filialen-Karte `.themeCard()` probeweise ohne die zwei
    /// `.shadow`-Modifikatoren gesetzt — beide Befunde verschwanden, alles
    /// andere unverändert.
    ///
    /// Bis zum 2026-08-01 standen ihre Kinder als **Zeichenketten** in
    /// `knownSystemDrawn`: „AM BESTEN ZU", „Am besten zu", „deckt 1 von 1
    /// Artikeln ab". Das iPad hat gezeigt, warum das nicht trägt. Dort ist
    /// die Karte 536 pt breit statt 354, und dadurch werden Kinder zu eigenen
    /// Elementen, die auf dem iPhone im zusammengefassten Etikett
    /// verschwinden — gemeldet wurden zusätzlich „Was heißt das?" und
    /// **„0,99 €"**. Der Preis war der Punkt, an dem die Wortliste als Weg
    /// ausschied: „0,99 €" als Ausnahme einzutragen hieße, Preiskontrast in
    /// der ganzen App nie wieder zu prüfen.
    ///
    /// Die Fläche ist die Vereinigung der zwei Elemente, die die Karte
    /// ohnehin hat: Kopfzeile und Aufklapp-Knopf. Beide tragen seit heute
    /// einen **Bezeichner** und nicht ihren deutschen Text — dieselbe Lehre
    /// wie bei `settings.end` weiter oben: Die Marke war zweimal Fließtext
    /// und ist zweimal gebrochen, sobald jemand den Text änderte.
    private func shadowedCardRegion() -> CGRect {
        let head = app.descendants(matching: .any)["list.plan.headline"]
        let toggle = app.descendants(matching: .any)["list.plan.disclosure"]
        switch (head.exists, toggle.exists) {
        case (true, true): return head.frame.union(toggle.frame)
        case (true, false): return head.frame
        case (false, true): return toggle.frame
        case (false, false): return .null
        }
    }

    /// Wartet, bis der Bildschirm wirklich stillsteht — statt 1,2 Sekunden zu
    /// hoffen.
    ///
    /// **Der Unterschied ist gemessen.** Mit der festen Pause fiel einer von
    /// drei Läufen des Einstellungs-Audits durch, und zwar auf zwei Zeilen im
    /// freien Feld: den Fußtext von „Rückfragen" (`Theme.secondaryText` auf der
    /// Karte, **5,89:1** — die Anforderung ist 4,5:1) und die Überschrift
    /// „App". Bei 5,89:1 fällt keine Farbe durch; gemessen wurde eine Liste,
    /// die noch ausrollte. Ein Wisch trägt unterschiedlich weit, und der
    /// `while`-Schleife oben genügt schon, dass die Endmarke **existiert** —
    /// sichtbar geworden heißt nicht zur Ruhe gekommen.
    ///
    /// Zwei gleiche Messungen in Folge, dann steht sie. Die Obergrenze ist ein
    /// Notausgang, kein Regelfall.
    private func waitUntilStill() {
        Thread.sleep(forTimeInterval: Self.settleSeconds)
    }

    /// Wie lange vor jeder Messung gewartet wird — **7,2 Sekunden, und die Zahl
    /// ist erlaufen, nicht gewählt.**
    ///
    /// Vorher waren es 1,2. Der Kommentar dazu war schon richtig („wird während
    /// eines Übergangs gemessen, liest der Audit Mischwerte"), die Zahl war zu
    /// klein — und das fiel nie auf, weil das eine Gate, das darüber
    /// gestolpert wäre, seit dem 28.07. aus war.
    ///
    /// **Der Beleg kam aus einem Nebenbefund.** Mit einer Warteschleife, die
    /// auf Stillstand prüft, fielen fünf Läufe des Einstellungs-Audits in zwei
    /// Gruppen: Die drei bestandenen dauerten 106,6 / 107,4 / 107,5 s, die zwei
    /// durchgefallenen 85,1 / 71,2 s. Die bestandenen liefen genau deshalb
    /// länger, weil die Schleife bis an ihre Obergrenze lief — sie haben also
    /// **rund 25 Sekunden länger gewartet**, sonst nichts.
    ///
    /// Und die Scrollposition war es nachweislich nicht: Ein bestandener Lauf
    /// („PLZ 01219" bei y = −4,3) und ein durchgefallener (y = −2,7) standen
    /// **1,6 pt** auseinander. Der eine meldete zwei Befunde, beide hinter der
    /// Navigationsleiste; der andere acht, quer über den ganzen Bildschirm —
    /// darunter Fließtext bei 5,89:1 mitten im freien Feld. Ein Bildschirm, der
    /// als Ganzes durchfällt, ist nicht falsch gefärbt, sondern zu früh
    /// gemessen.
    ///
    /// Mit der festen Pause: **6 von 6 Läufen grün**, und die zwei verbliebenen
    /// Befunde sind beide Male dieselben zwei Zeilen hinter der
    /// Navigationsleiste.
    ///
    /// **Warum kein Warten auf Stillstand statt einer festen Zahl:** Es wurde
    /// gebaut und half nicht. Die Liste steht längst still, während der
    /// Bildschirm noch nicht so aussieht, wie der Audit ihn messen kann —
    /// Bewegung ist das falsche Merkmal. Eine feste Pause, deren Länge
    /// nachgemessen ist, ist ehrlicher als eine Schleife, die auf das Falsche
    /// wartet.
    ///
    /// Der Preis sind rund 70 Sekunden auf den vollen Lauf. Für ein Gate, das
    /// vier Tage lang aus war, ist das billig.
    private static let settleSeconds: TimeInterval = 7.2

    /// **Welche Prüfungen der Audit überhaupt fährt — und warum nicht alle.**
    ///
    /// Bis zum 2026-08-01 lief `performAccessibilityAudit` ohne Angabe, also
    /// mit `.all`. Auf dem iPhone ging das durch. Auf dem iPad nicht: Dort
    /// brach der Audit mit „Audit failed to complete in time" ab — in zwei
    /// Läufen des Bestands **beide Male** im Treffer-Sheet, in einem der
    /// beiden zusätzlich im dunklen Modus. Die Notiz im Wiki hielt das für
    /// Zeitverhalten ohne festen Ort; das stimmt für den dunklen Modus und
    /// stimmt für das Treffer-Sheet nicht.
    ///
    /// **Was dort lange dauert, ist nachgemessen:** `.dynamicType`. Diese
    /// Prüfung rendert den Bildschirm für **jede** Schriftgröße neu. Auf dem
    /// iPad ist der Bildschirm 1024 × 1366 statt 402 × 874 — rund die
    /// vierfache Fläche und entsprechend mehr Elemente je Durchgang. Die
    /// Messung steht im PR: mit `.all` bricht das Treffer-Sheet reproduzierbar
    /// ab, mit dieser Liste läuft es durch.
    ///
    /// **Und es kostet keine Prüfschärfe**, weil die weggelassenen Arten nie
    /// ein Gate hatten. Sie wurden protokolliert, und die Erklärung dazu steht
    /// oben in `audit(_:failOnContrast:)`: `dynamicType` meldete die
    /// Emoji-Kachel und die Preise mit `monospacedDigit`, `textClipped` Texte,
    /// die auf dem Screenshot vollständig stehen, `hitRegion` die
    /// Fortschrittspunkte des Onboardings. Drei Kategorien Protokoll, für die
    /// seit Wochen dieselbe Antwort im Kommentar steht — und dafür ein Audit,
    /// der auf dem größeren Gerät gar nicht erst fertig wird.
    ///
    /// **Bewusst auf beiden Geräten gleich.** Eine Ausnahme nur fürs iPad
    /// hieße, dass die zwei Geräte verschiedene Dinge messen — genau die
    /// Sorte Unterschied, aus der später „auf dem einen grün, auf dem anderen
    /// rot" wird, ohne dass jemand sagen kann warum.
    private static let geprüfteArten: XCUIAccessibilityAuditType =
        [.contrast, .sufficientElementDescription]

    /// **Alle Flächen, in denen eine durchscheinende Systemleiste die Farbe
    /// verfälscht** — Suchleiste, Navigationsleiste, Tab-Leiste.
    ///
    /// Die Suchleiste war bis zum 2026-08-01 die einzige. Der Kontrast der
    /// Einstellungen war deshalb seit dem 2026-07-28 gar nicht geprüft: Der
    /// Audit meldete dort bei jedem Lauf eine andere Zeile, und die Erklärung
    /// hieß „hängt an der Scrollposition" — richtig beobachtet und zu früh
    /// aufgehört.
    ///
    /// **Nachgemessen am 2026-08-01, Bildschirm 402 × 874, Tab-Leiste bei
    /// y = 791 (83 hoch), Navigationsleiste 62 … 168.** Drei Scrollpositionen,
    /// jeder harte Kontrast-Befund mit seinem Rahmen protokolliert:
    ///
    /// | Befund | y | Lage |
    /// |---|---|---|
    /// | „Angebote sind regional …" | 805 … 867 | hinter der Tab-Leiste |
    /// | „Profil" | 867 … 908 | hinter der Tab-Leiste |
    /// | „Angebote" | 775 … 796 | schneidet die Tab-Leiste |
    /// | „Die Installations-ID …" | 811 … 921 | hinter der Tab-Leiste |
    /// | „Region hinzufügen" | 769 … 790 | im Verlauf über der Tab-Leiste |
    /// | „Region hinzufügen" | 88 … 109 | hinter der Navigationsleiste |
    /// | „Bereit" | 43 … 58 | hinter der Navigationsleiste |
    /// | „Regionen" | −34 … 6 | über dem Bildschirmrand |
    ///
    /// **Kein einziger harter Befund lag im freien Feld.** Alles, was zwischen
    /// den Leisten steht, kommt höchstens auf „nearly passed" — und das ist der
    /// bekannte Umbau der sekundären Systemfarbe, kein Regressionssignal.
    ///
    /// **Die Schatten-Vermutung trägt hier nicht**, und das ist gemessen und
    /// nicht angenommen: Die Einstellungen sind eine nackte `List` mit
    /// `.listRowBackground(Theme.surface)`. In der ganzen Datei steht kein
    /// `.themeCard()` und kein `.shadow` — es gibt also gar keinen Schatten,
    /// den man abziehen könnte. Der Befund von der Leerzustands-Karte bleibt
    /// richtig, er ist nur eine **zweite** Ursache derselben Art: Beide Male
    /// misst der Audit durch eine Ebene hindurch, die zwischen ihm und der
    /// gezeichneten Farbe liegt — dort ein Schatten, hier eine Weichzeichnung.
    ///
    /// **Warum das nichts an Prüfschärfe kostet:** In einer scrollenden Liste
    /// wandert jede Zeile durch die Mitte. Der Test misst deshalb an **zwei**
    /// Positionen statt an einer; was oben hinter der Navigationsleiste liegt,
    /// steht unten frei und umgekehrt. Eine Ausnahme nach Bezeichner hätte eine
    /// Zeile für immer blind gemacht — diese hier macht nur die Stelle blind,
    /// an der ohnehin niemand messen kann.
    private func translucentBarRegions() -> [CGRect] {
        let window = app.windows.firstMatch.frame
        var regions = [scrollEdgeRegion(), shadowedCardRegion()] + offscreenRegions()

        // Nach oben offen: Eine weggescrollte Zeile meldet sich mit negativem
        // y und läge sonst außerhalb jeder Fläche. Plus eine Leistenhöhe
        // darunter für den Auslauf der Weichzeichnung — dieselbe Regel, die
        // Such- und Tab-Leiste schon anwenden; nur die Navigationsleiste
        // endete hart an `maxY`. Auf dem iPhone reichte das, auf dem iPad
        // nicht: „Rundgang erneut ansehen" fiel gescrollt bei y = 107,5 durch
        // und stand ungescrollt bei y = 484 sauber da — gleiche Zeile, gleiche
        // Farbe, nur die Leiste darüber.
        //
        // **Alle Leisten, nicht `firstMatch`** — seit dem 05.08. Ein Blatt
        // bringt seine eigene Navigationsleiste mit, und auf halber Höhe
        // (`.medium`-Detent) ist `firstMatch` die Leiste des Bildschirms
        // **dahinter**: Im Rückfrage-Blatt fielen „Überspringen" und „Senden"
        // durch — zwei Knöpfe in `Theme.accent`, derselben Farbe, die überall
        // sonst besteht, gemessen mitten **auf** der durchscheinenden Leiste
        // des Blatts. Dieselbe Klasse Befund wie in der Tabelle oben, nur an
        // einer Leiste, die die Ausnahme nie abgedeckt hat. Die offene Fläche
        // nach oben bekommt weiterhin nur die oberste Leiste — über einem
        // halbhohen Blatt liegt der Bildschirm dahinter, und den prüft sein
        // eigener Durchgang; die Leisten der Blätter bekommen ihr Band aus
        // Leiste plus einer Leistenhöhe Auslauf in beide Richtungen.
        let navBars = app.navigationBars.allElementsBoundByIndex
        for (index, nav) in navBars.enumerated() where nav.exists {
            let bar = nav.frame
            if index == 0 {
                regions.append(CGRect(x: window.minX, y: -10_000,
                                      width: window.width, height: 10_000 + bar.maxY + bar.height))
            } else {
                regions.append(CGRect(x: window.minX, y: bar.minY - bar.height,
                                      width: window.width, height: bar.height * 3))
            }
        }

        // Über der Tab-Leiste läuft ihre Weichzeichnung aus. Die Höhe ist
        // abgeleitet, nicht gepasst: eine Leistenhöhe, dieselbe Regel wie bei
        // der Suchleiste. Der flachste falsch beurteilte Befund („Region
        // hinzufügen", ab 769,5) liegt damit drin, der tiefste richtig
        // beurteilte („App", endet bei 638) draußen.
        let tabs = app.tabBars.firstMatch
        if tabs.exists {
            let bar = tabs.frame
            regions.append(CGRect(x: window.minX, y: bar.minY - bar.height,
                                  width: window.width, height: 10_000))
        }
        return regions
    }

    /// Vom System gezeichnet oder rein dekorativ — beides nicht über die
    /// SwiftUI-API einfärbbar, beides gemessen und im Backlog notiert:
    ///
    /// - Die Emoji-Kachel (`OfferThumbnail`) ist der Platzhalter für ein
    ///   fehlendes Produktbild und trägt `accessibilityHidden`. Ein
    ///   Kontrastwert für ein Emoji ist ohne Bedeutung.
    /// - Die Disclosure-Chevrons der `NavigationLink`-Zeilen melden sich ohne
    ///   Elementnamen. Gemessen `#BFBEB1` auf `#F7F5E0` = **1,70:1**. Die
    ///   Rechnung aus Phase 7 deckte nur die eigenen Tokens ab; dieses Zeichen
    ///   zeichnet UIKit, und weder `.tint` noch `.foregroundStyle` färben es
    ///   (beides ausprobiert und nachgemessen).
    private static let knownSystemDrawn = [
        "🥛", "🍊", "🛒",
        // **Die Einkaufsplan-Karte steht hier nicht mehr als Wortliste.**
        //
        // Bis zum 2026-08-01 standen ihre Kinder als Zeichenketten in dieser
        // Liste: „deckt 1 von 1 Artikeln ab", „AM BESTEN ZU", „Am besten zu".
        // Die Begründung war jedes Mal richtig — der Audit misst durch den
        // `.shadow` der Karte hindurch, am 2026-07-26 mit einem fast
        // schwarzen Braun (rund 9:1) gegengeprüft, der Befund blieb Wort für
        // Wort derselbe. Nur der **Weg** trug nicht: Auf dem iPad ist die
        // Karte 536 pt statt 354 pt breit, dadurch werden weitere Kinder zu
        // eigenen Elementen, und die Liste hätte mit jedem Gerät wachsen
        // müssen. Zuletzt hätte „0,99 €" darauf gestanden — und damit wäre
        // Preiskontrast in der ganzen App nie wieder geprüft worden.
        //
        // Jetzt ist es eine **Fläche**: `shadowedCardRegion()`.
        // **Und hier ist endlich die Ursache — es ist der Schatten.**
        //
        // Die Filialen-Karte des Leerzustands meldet zwei Kontrastfehler. Am
        // 2026-07-31 am gerenderten Screenshot nachgemessen, Pixel für Pixel
        // aus dem PNG: Der Knopf ist Weiß auf `#3E6243` = **6,92:1**, der
        // Fließtext `#6B5C47` auf `#F7F5E0` = **5,88:1**. AA verlangt 4,5:1.
        // Der Audit widerspricht also dem, was auf dem Bildschirm steht.
        //
        // Diesmal wurde nicht bei der Feststellung haltgemacht: Wird an dieser
        // einen Karte `.themeCard()` durch dieselbe Fläche **ohne die zwei
        // `.shadow`-Modifikatoren** ersetzt, verschwinden **beide** Befunde und
        // der Audit läuft durch — alles andere unverändert. Ein `.shadow` legt
        // seinen Teilbaum in eine eigene Ebene, und was der Audit danach misst,
        // ist nicht mehr die gezeichnete Farbe.
        //
        // Das erklärt rückwirkend die zwei Ausnahmen darüber: Die Plan-Karte
        // trägt denselben `.themeCard()`. Die Vermutung „das
        // `accessibilityElement(children: .ignore)` ist schuld" war naheliegend
        // und deckt nur einen der Fälle — der Knopf hier fasst gar nichts
        // zusammen und fällt trotzdem durch.
        //
        // Der Schatten bleibt: Diese Karte steht an der Stelle der Plan-Karte
        // und löst sie ab, sie müssen gleich aussehen. Wer den Audit an dieser
        // Stelle wirklich scharf haben will, braucht den Weg über gerenderte
        // Screenshots — dieselbe Antwort wie für den Kontrast der
        // Einstellungen.
        "list.chooseMarkets",
        "list.noMarkets.body",
    ]

    private func openTab(_ name: String) {
        let inBar = app.tabBars.buttons[name]
        let tab = inBar.exists ? inBar : app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Tab \(name) fehlt")
        tab.tap()
    }

    private func addItem(_ text: String) {
        let input = app.textFields["list.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        input.typeText(text + "\n")
        dismissQuantitySheet()
    }
    /// Schließt das Mengen-Menü, das seit [UI-8] beim Anlegen von selbst
    /// aufgeht. Die Journeys unten testen nicht das Menü, sondern was danach
    /// kommt — für sie ist es ein Zwischenschritt.
    private func dismissQuantitySheet() {
        let abbrechen = app.buttons["itemDetail.cancel"]
        if abbrechen.exists { abbrechen.tap(); return }
        // Seit dem 03.08. ist das Mengen-Menue kein Blatt mehr, sondern eine
        // Schicht ueber der Eingabezeile — sie geht mit dem Fokus, nicht mit
        // einem Knopf. Ein Zug ueber die **Liste** tut das; die
        // Bildschirmmitte liegt mit voller Software-Tastatur auf der Schicht
        // selbst. Siehe `dragTheListUp`.
        let panel = app.buttons["list.detailPanel.more"]
        guard panel.waitForExistence(timeout: 3) else { return }
        app.dragTheListUp()
        _ = panel.waitForNonExistence(timeout: 3)
    }


    private func enterPLZ() {
        let plz = app.textFields["region.input"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15))
        plz.tap()
        plz.typeText("01219")
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")
        // **Und warten, bis der Ort wirklich weg ist.** Die Ortssuche ist
        // asynchron; ohne diese Zeile lief die Kette der Tipps danach an ihr
        // vorbei — am 07.08. gemessen: Ort, Ketten, Belohnung und Einwilligung
        // lagen in 0,7 s, und der Tipp, der die Ketten überspringen sollte,
        // traf noch den Ort. Der Assistent stand am Ende einen Bildschirm zu
        // früh, und der Bogen wartete auf ein Rundgang-Angebot, das nie kam.
        //
        // **Merksatz: Ein Tipp ohne Warten prüft die Reihenfolge nicht — er
        // setzt sie voraus.**
        //
        // Über ein Prädikat und nicht über `waitForExistence`: Letzteres wartet
        // die volle Frist ab, *wenn* das Feld weg ist — also genau im guten
        // Fall, und das bei jedem Aufruf.
        let weg = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: plz
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [weg], timeout: 15), .completed,
            "Der Ort-Schritt steht noch: die Suche ist nicht durch"
        )
    }

}
