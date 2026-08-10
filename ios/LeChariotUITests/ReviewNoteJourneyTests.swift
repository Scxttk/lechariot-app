import XCTest

/// **Der Weg, den die Beta App Review geht — Schritt für Schritt nachgelaufen.**
///
/// Die Anmerkung in `docs/RELEASE.md` ist eine nummerierte Anleitung, die Scott
/// bei jeder Einreichung in App Store Connect einfügt. Sie war bis zum
/// 2026-07-31 die einzige Beschreibung des ersten Starts, die niemand geprüft
/// hat — und mit dem Umbau des Ablaufs wurde ihr Schritt 3 („Im Filialpicker
/// zwei bis drei Läden auswählen") schlicht falsch: Den Picker gibt es an
/// dieser Stelle nicht mehr.
///
/// Eine Anleitung, die nicht zur App passt, ist ein Ablehnungsgrund. Deshalb
/// läuft sie hier mit: **Jeder nummerierte Schritt der Anmerkung ist eine
/// Zusicherung dieses Tests.** Ändert sich der Ablauf noch einmal, fällt der
/// Test, und die Anmerkung wird mitgezogen statt vergessen.
///
/// Was hier **nicht** geprüft werden kann: die Standortfreigabe abzulehnen. Das
/// ist ein Systemdialog, und ein UI-Lauf ohne Ortungsdienste bekommt ihn nie zu
/// sehen. Der Test läuft deshalb genau den Weg, auf dem die Ablehnung landet —
/// die Postleitzahl von Hand.
final class ReviewNoteJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    func testTheReviewNoteDescribesTheAppThatShips() {
        // 1. Vorname eingeben, dann PLZ 01219
        let start = app.buttons["onboarding.primary"]
        XCTAssertTrue(start.waitForExistence(timeout: 20),
                      "Schritt 1: Der erste Start beginnt nicht auf dem Willkommensbildschirm")
        start.tap()

        let name = app.textFields["Vorname"]
        XCTAssertTrue(name.waitForExistence(timeout: 15), "Schritt 1: keine Namenseingabe")
        name.tap()
        name.typeText("Alex")
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")

        // Der Weg der abgelehnten Standortfreigabe: die PLZ von Hand.
        let plz = app.textFields["region.input"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15), "Schritt 1: keine PLZ-Eingabe")
        XCTAssertTrue(app.buttons["Standort verwenden"].exists,
                      "Die Anmerkung warnt vor diesem Knopf — er muss auch da sein")
        plz.tap()
        plz.typeText("01219")
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")

        // 2. Die Frage nach den Lieblingsmärkten kann übersprungen werden,
        //    danach zeigt die App, was es in der Gegend gibt.
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15),
                      "Schritt 2: die Marktfrage lässt sich nicht überspringen")
        skip.tap()
        XCTAssertTrue(
            app.staticTexts["4 Ketten, 5 Filialen in deiner Nähe."].waitForExistence(timeout: 15),
            "Schritt 2: nach der Marktfrage fehlt der Bildschirm mit den Zahlen der Gegend"
        )
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")   // Belohnung
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")   // Einwilligung

        // 3. Der Assistent endet in der Einkaufsliste — **ohne** Filialauswahl.
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20),
                      "Schritt 3: Der Assistent endet nicht in der Einkaufsliste")

        // 4. „Filialen wählen" steht auf der Liste, nicht im Assistenten.
        let choose = app.buttons["list.chooseMarkets"]
        XCTAssertTrue(choose.waitForExistence(timeout: 15),
                      "Schritt 4: Auf der Liste fehlt der Weg zu den Filialen")
        choose.tap()
        let chain = app.buttons["picker.chain.Lidl"]
        XCTAssertTrue(chain.waitForExistence(timeout: 20),
                      "Schritt 4: Die Filialauswahl zeigt keine Ketten zu 01219")
        chain.tap()
        let branch = app.buttons["Lidl, Dresden Reick"]
        XCTAssertTrue(branch.waitForExistence(timeout: 20),
                      "Schritt 4: Die Kettenseite zeigt keine Läden zu 01219")
        branch.tap()
        app.buttons["chain.done"].tap()
        app.buttons["markets.done"].tap()

        // 5. Ein Wort auf die Liste — und die Karte sagt, wo es am günstigsten ist.
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        let input = app.textFields["list.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15), "Schritt 5: keine Eingabezeile")
        input.tap()
        input.typeText("Vollmilch\n")
        dismissQuantitySheet()

        XCTAssertTrue(app.buttons["Vollmilch"].waitForExistence(timeout: 15),
                      "Schritt 5: Der Artikel landet nicht auf der Liste")
        let plan = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Am besten zu"))
            .firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 15),
                      "Schritt 6: Die App sagt nicht, welcher Markt die Liste abdeckt")
    }

    /// Schließt das Mengen-Menü, das seit [UI-8] beim Anlegen von selbst
    /// aufgeht.
    ///
    /// **Über „Fertig", seit dem 09.08.** Bis dahin stand hier ein
    /// `app.swipeUp()` — aus der Zeit, als die Schicht mit dem Fokus ging und
    /// es keinen Ausgang gab. Seit #91/#93 gibt es beides nicht mehr so: Die
    /// Schicht nimmt 45 % des Bildschirms ein, der Wisch beginnt also **in
    /// ihr** und scrollt ihre Chipreihen, statt sie wegzulegen. Auf einem
    /// iPhone 17 Pro unter iOS 26.2 ging er trotzdem durch, unter 26.1 nicht —
    /// die Journey hing an 10 pt Tastaturhöhe. „Fertig" unten links ist der
    /// Weg, den die App seit C-3 anbietet, und der, den ein Prüfer nimmt.
    private func dismissQuantitySheet() {
        let panel = app.buttons["list.detailPanel.more"]
        guard panel.waitForExistence(timeout: 3) else { return }
        app.buttons["list.input.done"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5),
                      "\u{201E}Fertig\u{201C} r\u{00E4}umt die Angaben-Schicht nicht weg")
    }

}
