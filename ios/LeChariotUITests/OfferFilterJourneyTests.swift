import XCTest

/// Die Chip-Leiste über der Angebotsliste.
///
/// Gemeldet am 2026-07-30 als „Scroll-Lotterie": Den Marktfilter gab es
/// schon, aber als vierten Picker in einem Menü der Werkzeugleiste — wer zu
/// einer bestimmten Kette wollte, scrollte trotzdem an allen anderen vorbei.
///
/// Zwei Filialen zweier Ketten sind der ganze Aufbau: Weniger, und die Leiste
/// blendet sich selbst aus (bei einer Kette filtert sie nichts). Genau das
/// prüft der letzte Test hier mit.
final class OfferFilterJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    /// Je ein Angebot je Kette in den Fixtures.
    private let lidlOffer = "Bio Vollmilch"
    private let aldiOffer = "Spanische Orangen"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Startet hinter dem Assistenten, mit einer oder beiden Fixture-Filialen.
    ///
    /// Vorher klickte sich jeder Test dafür durch das ganze Onboarding und
    /// tippte im Picker eine oder zwei Zeilen an. Die Wahl ist geblieben, sie
    /// steht nur nicht mehr im Weg — siehe `-uiTestingOnboardedAllBranches`.
    private func launch(withBothBranches beide: Bool) {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
            + (beide ? ["-uiTestingOnboardedAllBranches"] : [])
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
    }

    /// **Ein Tipp statt Scrollen.** Der Chip schränkt die Liste auf seine
    /// Kette ein, ein zweiter Tipp hebt das wieder auf — ohne den Weg zurück
    /// ans andere Ende der Leiste zu „Alle".
    func testAChainChipNarrowsTheListAndTappingItAgainWidensIt() {
        launch(withBothBranches: true)
        openTab("Angebote")

        XCTAssertTrue(
            app.staticTexts[lidlOffer].waitForExistence(timeout: 15),
            "Ohne Filter müssen beide Ketten dastehen"
        )
        XCTAssertTrue(app.staticTexts[aldiOffer].exists)

        let aldiChip = app.buttons["Aldi"]
        XCTAssertTrue(
            aldiChip.waitForExistence(timeout: 10),
            "Bei zwei Ketten muss die Chip-Leiste da sein"
        )
        aldiChip.tap()

        XCTAssertTrue(app.staticTexts[aldiOffer].waitForExistence(timeout: 10))
        XCTAssertFalse(
            app.staticTexts[lidlOffer].exists,
            "Der Chip filtert die andere Kette nicht weg"
        )

        // Derselbe Chip noch einmal — nicht der Umweg über „Alle".
        aldiChip.tap()
        XCTAssertTrue(
            app.staticTexts[lidlOffer].waitForExistence(timeout: 10),
            "Ein zweiter Tipp auf den aktiven Chip muss ihn aufheben"
        )
    }

    /// **Die Suche gehorcht dem Chip — und sagt es auch.**
    ///
    /// „Vollmilch" gibt es bei Lidl, nicht bei Aldi. Mit aktivem Aldi-Chip
    /// bleibt die Suche also leer, und das ist richtig; falsch wäre nur, das
    /// mit „Keine Ergebnisse für ‚Vollmilch'" zu erklären, als gäbe es
    /// nirgends welche. Der Bildschirm nennt die Kette und bietet den Ausweg
    /// mit einem Tipp an.
    func testASearchInsideOneMarketSaysThatItIsRestricted() {
        launch(withBothBranches: true)
        openTab("Angebote")

        let aldiChip = app.buttons["Aldi"]
        XCTAssertTrue(aldiChip.waitForExistence(timeout: 15))
        aldiChip.tap()

        let feld = app.searchFields["Produkt suchen"]
        XCTAssertTrue(feld.waitForExistence(timeout: 10), "Kein Suchfeld")
        feld.tap()
        feld.typeText("Vollmilch")

        XCTAssertTrue(
            app.staticTexts["Nichts bei Aldi"].waitForExistence(timeout: 10),
            "Die Leere muss sagen, dass sie nur für eine Kette gilt"
        )

        let ausweg = app.buttons["In allen Märkten suchen"]
        XCTAssertTrue(ausweg.exists, "Kein Weg aus der Einschränkung heraus")
        ausweg.tap()

        XCTAssertTrue(
            app.staticTexts[lidlOffer].waitForExistence(timeout: 10),
            "Der Ausweg muss die Suche über alle Märkte laufen lassen"
        )
    }

    /// Bei einer einzigen Kette filtert die Leiste nichts und wäre reine
    /// Höhe über jeder Sitzung. Steht als Test da, weil ein „ist doch
    /// konsistenter"-Umbau sie sonst genau dort wieder einblendet.
    func testWithOnlyOneChainThereIsNoChipBar() {
        launch(withBothBranches: false)
        openTab("Angebote")

        XCTAssertTrue(app.staticTexts[lidlOffer].waitForExistence(timeout: 15))
        // `descendants(matching: .any)` und nicht `otherElements`: Welchem
        // Elementtyp SwiftUI eine ScrollView zuordnet, ist nicht zugesichert,
        // und eine Abwesenheits-Zusicherung auf den falschen Typ ist immer
        // grün. (Genau daran ist die Endmarke des Einstellungs-Audits am
        // 30.07. zweimal vorbeigegangen.)
        XCTAssertFalse(
            app.descendants(matching: .any)["offers.marketChips"].exists,
            "Eine Leiste mit einer einzigen Kette filtert nichts"
        )
    }

    // MARK: Helfer

    private func openTab(_ name: String) {
        let inBar = app.tabBars.buttons[name]
        let tab = inBar.exists ? inBar : app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Tab \(name) fehlt")
        tab.tap()
    }

}
