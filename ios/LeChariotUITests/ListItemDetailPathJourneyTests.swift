import XCTest

/// **Der Weg zu den Angaben eines Artikels, der schon auf der Liste steht**
/// (Feldtest 09.08.).
///
/// Scott im Laden: „Kohl steht auf der Liste und ich komme an seine Angaben
/// nicht mehr heran." Nachgestellt war der Befund eindeutig — und *fast*
/// richtig. Einen Weg gab es, aber er lief über das Halten (das nichts
/// ankündigt), von dort ins Trefferblatt und dort ins ⋯-Menü. Für „Kohl" trug
/// dieses Blatt die Überschrift „Treffer für ‚Kohl'" und die Meldung „Keine
/// Treffer" — niemand sucht Menge und Bio auf einem Bildschirm, der ihm gerade
/// gesagt hat, dass hier nichts ist.
///
/// Diese Journeys halten die Zusage fest, die daraus folgt: **Jeder Artikel
/// auf der Liste hat einen sichtbaren Weg zu seinen Angaben, ganz gleich ob es
/// zu ihm Treffer gibt.** Und dieser Weg führt in dieselbe Schicht wie das
/// Anlegen, nicht in eine zweite Fassung.
final class ListItemDetailPathJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
    }

    /// **Der gemeldete Fall.** „Kohl" hat in den Testdaten kein einziges
    /// Angebot — genau der Artikel, an dem der alte Weg in eine Sackgasse
    /// führte. Ein sichtbarer Griff, und die Angaben stehen da.
    func testAnItemWithoutAnyOffersStillReachesItsDetails() {
        waitForList()
        addItem("Kohl")

        let knopf = detailKnopf(von: "Kohl")
        XCTAssertTrue(
            knopf.waitForExistence(timeout: 15),
            "Die Kachel trägt keinen sichtbaren Weg zu den Angaben:\n" + app.debugDescription
        )
        knopf.tap()

        XCTAssertTrue(
            app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10),
            "Ein Artikel ohne Treffer kommt nicht an seine Angaben:\n" + app.debugDescription
        )
    }

    /// **Es ist dieselbe Schicht wie beim Anlegen, kein zweiter Wortschatz.**
    /// Die Probe ist ein Chip, den nur das Wörterbuch zu „Kohl" kennt: Steht
    /// „Rotkohl" da, kommen die Reihen aus `ItemDetailVocabulary.groups(for:)`
    /// — derselben Quelle wie im Tipp-Fluss.
    func testTheDetailsAreTheSameLayerAsWhenAddingAnItem() {
        waitForList()
        addItem("Kohl")

        detailKnopf(von: "Kohl").tap()
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10))

        XCTAssertTrue(
            app.buttons["Rotkohl"].waitForExistence(timeout: 5),
            "Die Reihen kommen nicht aus dem Wörterbuch des Artikels:\n" + app.debugDescription
        )
        // Und die volle Fassung liegt hier, wo sie im Tipp-Fluss auch liegt.
        XCTAssertTrue(app.buttons["list.detailPanel.more"].exists,
                      "Der Weg zu Notiz und voller Fassung fehlt")
    }

    /// **Ein Chip schreibt durch, und die Kachel trägt ihn danach.** Der Weg
    /// wäre wertlos, wenn er nur eine Ansicht öffnete, aus der nichts
    /// zurückkommt.
    func testAChipChosenFromTheListLandsOnTheTile() {
        waitForList()
        addItem("Kohl")

        detailKnopf(von: "Kohl").tap()
        XCTAssertTrue(app.buttons["list.detailPanel.more"].waitForExistence(timeout: 10))
        app.buttons["Rotkohl"].tap()

        // „Fertig" beendet nur das Aufschreiben; gespeichert ist längst.
        app.buttons["list.input.done"].tap()

        XCTAssertTrue(
            app.buttons["Kohl, Rotkohl"].waitForExistence(timeout: 10),
            "Die Angabe steht nicht unter dem Artikel:\n" + app.debugDescription
        )
    }

    /// **Abhaken bleibt der Tipp auf die Kachel.** Der neue Knopf liegt über
    /// der Kachelfläche, und ein Knopf über einem Knopf ist genau die Stelle,
    /// an der eine Geste der anderen den Rang abläuft. Hier steht, dass es
    /// nicht passiert ist.
    func testTheNewButtonDoesNotSwallowTheCheckOffTap() {
        waitForList()
        addItem("Kohl")

        let kohl = kachel(von: "Kohl")
        XCTAssertTrue(kohl.waitForExistence(timeout: 15))
        kohl.tap()

        let ende = Date().addingTimeInterval(10)
        while Date() < ende {
            if ((kachel(von: "Kohl").value as? String) ?? "").contains("erledigt") { return }
        }
        XCTFail("Der Tipp auf die Kachel hakt nicht mehr ab:\n" + app.debugDescription)
    }

    // MARK: Helfer

    /// Der Angaben-Knopf **dieser** Kachel. `list.tile.detail` allein träfe den
    /// der ersten Kachel — bei mehreren Artikeln die falsche.
    private func detailKnopf(von text: String) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label == %@",
                        "list.tile.detail", "Angaben zu \(text) ändern")
        ).firstMatch
    }

    private func kachel(von text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    private func waitForList() {
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start landet nicht in der Liste")
    }

    private func addItem(_ text: String) {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15))
        feld.tap()
        feld.typeText(text + "\n")
        // Die Schicht geht beim Anlegen von selbst auf. Hier ist sie ein
        // Zwischenschritt: Der Prüfgegenstand ist der Weg **zurück** hinein.
        let fertig = app.buttons["list.input.done"]
        if fertig.waitForExistence(timeout: 5) { fertig.tap() }
        _ = app.buttons["list.detailPanel.more"].waitForNonExistence(timeout: 5)
    }
}
