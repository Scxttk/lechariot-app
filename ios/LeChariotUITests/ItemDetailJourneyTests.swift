import XCTest

/// **Die Angaben am Artikel, einmal durchgespielt** (L-5a).
///
/// Der Unit-Test prüft die Regeln des Vokabulars; hier geht es um den Weg
/// dorthin: dass der Artikelname überhaupt anfassbar ist, dass „Abbrechen"
/// wirklich nichts behält, und dass die Zeile danach am Artikel steht.
final class ItemDetailJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
    }

    func testChoosingChipsPutsANoteUnderTheItem() {
        waitForList()
        addItem("Vollmilch")

        app.buttons["list.item.detail"].firstMatch.tap()
        XCTAssertTrue(app.buttons["itemDetail.done"].waitForExistence(timeout: 10),
                      "Das Blatt mit den Angaben ist nicht aufgegangen")

        tapChip("1 l")
        tapChip("Bio")
        app.buttons["itemDetail.done"].tap()

        XCTAssertTrue(app.buttons["Vollmilch, 1 l · Bio"].waitForExistence(timeout: 10),
                      "Die Angabe muss unter dem Artikel stehen\n" + app.debugDescription)
        // Der Artikel selbst bleibt das Gattungswort — daran hängt, dass die
        // Suche ihn weiter findet. Die Beschriftung oben beweist das schon
        // („Vollmilch, 1 l · Bio", nicht „1 l Bio Vollmilch"); hier steht die
        // Gegenprobe, dass die Angabe **allein** keinen Artikel bildet.
        XCTAssertFalse(app.buttons["1 l · Bio"].exists,
                       "Der Listeneintrag darf sich nicht in die Angabe verwandeln")
    }

    /// „Abbrechen" heißt abbrechen. Ein Blatt, das die Auswahl trotzdem behält,
    /// wäre schlimmer als eines ohne Abbrechen-Knopf.
    func testCancellingKeepsNothing() {
        waitForList()
        addItem("Vollmilch")

        app.buttons["list.item.detail"].firstMatch.tap()
        XCTAssertTrue(app.buttons["itemDetail.cancel"].waitForExistence(timeout: 10))
        tapChip("Bio")
        app.buttons["itemDetail.cancel"].tap()

        XCTAssertTrue(app.buttons["Vollmilch"].waitForExistence(timeout: 10),
                      "Ohne Angabe ist die Beschriftung genau der Artikelname")
        XCTAssertFalse(app.buttons["Vollmilch, Bio"].exists,
                       "Abgebrochen ist abgebrochen")
    }

    /// **Das Mengen-Menü kommt von selbst** ([UI-8], Scott 01.08.) — **seit dem
    /// 03.08. als Schicht statt als Blatt** (Scott, nach dem Bring!-Video).
    ///
    /// Der Moment nach dem Anlegen bleibt der einzige, in dem jemand noch weiß,
    /// welche Größe er meint; was sich geändert hat, ist der Preis dafür. Die
    /// drei Wortschatz-Gruppen stehen weiter da — nur eben ohne „Fertig", ohne
    /// Modalität und ohne dem Eingabefeld den Fokus zu nehmen.
    ///
    /// Die drei Fälle, die hier bis zum 03.08. standen, sind nicht verloren,
    /// sondern umgezogen: Was das Blatt konnte, prüft jetzt
    /// `AddFlowJourneyTests` am Fluss.
    func testTheQuantityPanelOpensByItselfWhenAnItemIsCreated() {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tapAndAwaitKeyboard(in: app)
        feld.typeText("Butter\n")

        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10),
                      "Nach dem Anlegen muss die Angaben-Schicht dastehen")
        XCTAssertTrue(app.staticTexts["Menge"].exists)
        XCTAssertTrue(app.staticTexts["Größe"].exists)
        XCTAssertFalse(app.buttons["itemDetail.done"].exists,
                       "Es gibt nichts zu bestätigen — jeder Chip schreibt sofort durch")
    }

    /// **Der eigentliche Unterschied ist nicht die Höhe, sondern die
    /// Bedienbarkeit.**
    ///
    /// Das halbe Blatt vom 02.08. ließ die Liste *sehen* und war trotzdem
    /// modal: Ein Tipp auf die Zeile dahinter kam nirgends an. Die Schicht
    /// nimmt weniger Platz **und** lässt darunter alles zu — gemessen an
    /// `isHittable`, nicht an `exists`, weil nur das den Unterschied trifft.
    ///
    /// Die Zahl daneben ist die Untergrenze: Ein knappes Drittel Bildschirm
    /// bleibt der Liste, auch mit stehender Tastatur.
    func testTheListStaysLiveUnderneathThePanel() {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tapAndAwaitKeyboard(in: app)
        feld.typeText("Butter\n")

        let kachel = app.buttons["Angaben zu Butter"]
        XCTAssertTrue(kachel.waitForExistence(timeout: 10))

        let zeile = app.buttons["list.item.detail"].firstMatch
        XCTAssertTrue(zeile.exists && zeile.isHittable,
                      "Die Liste unter der Schicht muss bedienbar bleiben\n"
                      + app.debugDescription)

        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThan(
            kachel.frame.minY, screen.height * 0.3,
            "Die Angaben-Schicht frisst die Liste — Oberkante bei "
            + "\(kachel.frame.minY) von \(screen.height)"
        )
    }

    /// Der Freitext landet unter dem Artikel — und nirgends sonst. Er liegt
    /// seit dem 03.08. in der vollen Fassung hinter „Notiz …", weil ein
    /// Textfeld in der Schicht genau den Fokus nähme, den sie schützt.
    func testTheFreeTextNoteEndsUpUnderTheItem() {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tapAndAwaitKeyboard(in: app)
        feld.typeText("Butter\n")

        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10))
        app.buttons["list.detailPanel.more"].tap()

        let notiz = app.textViews["itemDetail.note"].exists
            ? app.textViews["itemDetail.note"]
            : app.textFields["itemDetail.note"]
        XCTAssertTrue(notiz.waitForExistence(timeout: 10), "Kein Freitextfeld")
        notiz.tap()
        notiz.typeText("die im blauen Becher")
        app.buttons["itemDetail.done"].tap()

        XCTAssertTrue(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS[c] %@", "blauen Becher")
            ).firstMatch.waitForExistence(timeout: 10),
            "Die Notiz steht nicht unter dem Artikel"
        )
    }

    // MARK: Helfer

    private func addItem(_ text: String) {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tapAndAwaitKeyboard(in: app)
        feld.typeText(text + "\n")
        dismissQuantitySheet()
        XCTAssertTrue(app.buttons[text].waitForExistence(timeout: 10))
    }
    /// Tippt einen Chip im Mengen-Menü an und scrollt vorher, falls er unter
    /// der Blattkante liegt.
    ///
    /// Nötig seit dem halben Blatt (02.08.): Auf `.medium` steht „Menge" oben,
    /// „Art" liegt darunter — genau wie bei Bring!. Ein Test, der ohne Scrollen
    /// tippt, prüft nicht das Vokabular, sondern die Blatthöhe, und die hat
    /// ihren eigenen Fall weiter oben.
    private func tapChip(_ label: String) {
        let chip = app.buttons[label].firstMatch
        for _ in 0..<4 {
            if chip.exists && chip.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Chip nicht gefunden: \(label)")
        chip.tap()
    }

    /// Beendet den Tipp-Fluss, der seit [UI-8] beim Anlegen von selbst aufgeht.
    /// Die Journeys oben testen nicht ihn, sondern was danach kommt.
    ///
    /// **Seit dem 03.08. gibt es nichts mehr wegzuklicken:** Das Menü ist kein
    /// Blatt, sondern eine Schicht über der Eingabezeile, und sie geht mit dem
    /// Fokus. Ein Wisch über die Liste tut das (`scrollDismissesKeyboard`).
    private func dismissQuantitySheet() {
        let abbrechen = app.buttons["itemDetail.cancel"]
        if abbrechen.exists { abbrechen.tap(); return }
        let panel = app.buttons["list.detailPanel.more"]
        guard panel.waitForExistence(timeout: 3) else { return }
        app.swipeUp()
        _ = panel.waitForNonExistence(timeout: 3)
    }


    /// Startet hinter dem Assistenten (`-uiTestingOnboarded`) und wartet, bis
    /// die Liste steht.
    ///
    /// Vorher lief hier der ganze Onboarding-Assistent — sieben Bildschirme für
    /// einen Zustand, den diese Journey nur durchquert. Gemessen am 2026-07-31:
    /// Der Assistent ist 72 % der 20-Minuten-Suite.
    private func waitForList() {
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
    }
}
