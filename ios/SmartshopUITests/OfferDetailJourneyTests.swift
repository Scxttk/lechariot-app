import XCTest

/// Journey around the offer detail sheet.
///
/// The promise being tested: an offer in the list is not a dead end. Tapping it
/// opens everything the row had to leave out — the image, the full validity,
/// and what the product cost in the weeks before — and closing it puts the user
/// back where they were.
final class OfferDetailJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    /// Fixture offer of the Lidl branch picked during onboarding.
    private let fixtureOffer = "Bio Vollmilch"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        completeOnboarding()
    }

    func testTappingAnOfferOpensItsDetailsAndClosesAgain() {
        openTab("Angebote")

        let row = app.buttons["offers.row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "the offer list must have tappable rows")
        row.tap()

        let done = app.buttons["Fertig"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10), "the tap must open the detail sheet")
        XCTAssertTrue(app.staticTexts[fixtureOffer].firstMatch.exists,
                      "the sheet must name the product it is about")
        XCTAssertTrue(app.staticTexts["Grundpreis"].exists,
                      "the base price is one of the things the row had no room for")

        done.tap()

        XCTAssertFalse(app.buttons["Fertig"].firstMatch.waitForExistence(timeout: 3),
                       "Fertig must close the sheet")
        XCTAssertTrue(app.navigationBars["Angebote"].waitForExistence(timeout: 10),
                      "closing must lead back to the list")
    }

    /// The fixture has three recorded weeks, so the section must be there.
    /// With fewer than two it stays hidden on purpose — see `PriceHistoryStore`.
    func testTheSheetShowsThePriceHistoryWhenThereIsSomethingToCompare() {
        openTab("Angebote")
        app.buttons["offers.row"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Fertig"].firstMatch.waitForExistence(timeout: 10))

        XCTAssertTrue(app.staticTexts["Preisverlauf"].waitForExistence(timeout: 10),
                      "three recorded weeks must produce a price history")
    }

    // MARK: Helpers

    private func openTab(_ name: String) {
        let inBar = app.tabBars.buttons[name]
        let tab = inBar.exists ? inBar : app.buttons[name].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "tab \(name) missing")
        tab.tap()
    }

    private func completeOnboarding() {
        app.buttons["onboarding.primary"].tap()   // welcome
        app.buttons["onboarding.skip"].tap()      // name
        let plz = app.textFields["Postleitzahl"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15))
        plz.tap()
        plz.typeText("01219")
        app.buttons["onboarding.primary"].tap()
        app.buttons["onboarding.skip"].tap()      // household
        app.buttons["onboarding.skip"].tap()      // diet
        app.buttons["onboarding.primary"].tap()   // consent
        let branch = app.buttons["Lidl, Dresden Reick"]
        XCTAssertTrue(branch.waitForExistence(timeout: 15))
        branch.tap()
        app.buttons["markets.done"].tap()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }
}
