import XCTest

/// **Die Frage nach den Filialen am Ende des Assistenten**, durchgelaufen wie
/// ein Tester sie erlebt.
///
/// Sie hing bis zum 10.08. am Ende des Rundgangs und am „Später" seines
/// Angebots; beide Türen sind mit ihm abgerissen. Was bleibt, ist der Ablauf,
/// für den der Umbau vom 2026-07-31 da war: Der Assistent endet in der Liste,
/// und erst danach steht die Filialauswahl — als Angebot, nicht als Pflicht.
///
/// Diese Journeys laufen bewusst **durch den Assistenten hindurch** (kein
/// `-uiTestingOnboarded`): Geprüft wird sein Ausgang.
final class MarketPromptJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    private let fixtureBranch = "Lidl, Dresden Reick"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(keepState: Bool = false) {
        var arguments = ["-uiTesting"]
        if keepState { arguments.append("-uiTestingKeepState") }
        app.launchArguments = arguments
        app.launch()
    }

    /// **„Märkte wählen" führt in die Filialauswahl im selben Sheet** — erst
    /// schließen und dann neu öffnen wäre der Zwei-Sheets-Tanz, der in SwiftUI
    /// regelmäßig den zweiten verliert.
    func testTheMarketSheetLeadsToTheBranchPicker() {
        launch()
        completeOnboarding()
        answerMarketPrompt(choose: true)

        // Seit dem 2026-08-01 liegen die Filialen hinter der Kettenzeile.
        let chain = app.buttons["picker.chain.Lidl"]
        XCTAssertTrue(chain.waitForExistence(timeout: 15),
                      "„Märkte wählen“ muss in der Filialauswahl landen")
        chain.tap()
        let branch = app.buttons[fixtureBranch]
        XCTAssertTrue(branch.waitForExistence(timeout: 15))
        branch.tap()
        app.buttons["chain.done"].tap()
        app.buttons["markets.done"].tap()

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "und danach zurück in der Liste, von der man losgegangen ist")
        XCTAssertFalse(app.staticTexts["Noch keine Filiale gewählt"].exists,
                       "mit einer Filiale hat der Leerzustand nichts mehr zu melden")
    }

    /// „Später" ist eine vollwertige Antwort: zurück in die Liste, ohne Umweg
    /// und ohne dass das Sheet wiederkommt — auch nicht nach einem Neustart.
    func testLaterGoesBackToTheListAndStaysAnswered() {
        launch()
        completeOnboarding()
        answerMarketPrompt(choose: false)

        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["marketPrompt.title"].exists,
                       "eine beantwortete Frage darf nicht wiederkommen")

        // **Und der Weg bleibt offen — auf der Liste, wo er hingehört.**
        // Welche der beiden Flächen ihn trägt, entscheidet `ListGuidance`;
        // die Zusicherung gilt dem **Weg**, nicht der Fläche.
        let karte = app.buttons["list.chooseMarkets"]
        let checkliste = app.buttons["list.checklist.markets"]
        XCTAssertTrue(karte.exists || checkliste.exists,
                      "„Später“ darf keine Sackgasse sein:\n" + app.debugDescription)

        app.terminate()
        launch(keepState: true)
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["marketPrompt.title"].waitForExistence(timeout: 3),
                       "das Sheet ist ein Angebot und keine Mahnung")
    }

    /// **Der Assistent endet in der Liste** — sechs Schritte, kein siebter.
    /// Bis zum 10.08. stand hier das Angebot des Rundgangs.
    func testTheAssistantEndsInTheListWithoutATourOffer() {
        launch()
        completeOnboarding()
        XCTAssertFalse(app.staticTexts["Alles bereit. Einmal kurz zeigen?"].exists,
                       "das Rundgang-Angebot ist abgerissen")
        answerMarketPrompt(choose: false)
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }

    // MARK: Helpers

    private var primary: XCUIElement { app.buttons["onboarding.primary"] }

    private func tapPrimary() {
        XCTAssertTrue(primary.waitForExistence(timeout: 15))
        primary.tap()
    }

    private func tapSkip() {
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15))
        skip.tap()
    }

    /// Bis einschließlich der Einwilligung — was danach kommt, ist der
    /// Prüfpunkt.
    private func completeOnboarding() {
        tapPrimary()               // Willkommen
        tapSkip()                  // „Ohne Namen weiter"
        let plz = app.textFields["region.input"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15))
        plz.tap()
        plz.typeText("01219")
        tapPrimary()
        tapSkip()                  // Ketten: „Später"
        tapPrimary()               // Belohnung
        tapPrimary()               // Einwilligung
    }

    /// Das Markt-Sheet nach dem Assistenten. Es steht auf jedem Weg ohne
    /// Filialen und muss beantwortet werden, bevor die Liste wieder anfassbar
    /// ist. Seit dem 05.08. ein gestaltetes Sheet, kein System-Alert mehr.
    private func answerMarketPrompt(choose: Bool) {
        let title = app.staticTexts["marketPrompt.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 25),
                      "Ohne Filialen muss das Markt-Sheet stehen")
        app.buttons[choose ? "marketPrompt.choose" : "marketPrompt.later"].tap()
    }
}
