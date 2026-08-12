import XCTest

/// **Bilder zu #148 und #107** — jeder Zustand einmal angesehen.
///
/// Sieben Bilder: die drei Ausgänge der PLZ-Prüfung (Ausland, gibt es nicht,
/// nicht prüfbar), die Liste ohne Filiale, die Angebote ohne Filiale, die
/// Auswahl einen Tipp dahinter und der Zustand ohne Region.
///
/// Hell und dunkel entstehen durch **zwei Läufe** desselben Bogens, davor
/// jeweils `xcrun simctl ui <udid> appearance dark|light` — wie bei
/// `BedienrundeAbendShots`. Die PNGs hängen am `.xcresult`; heraus mit
/// `xcrun xcresulttool export attachments`.
final class LandUndListeShots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: 1 — Was aus fünf Ziffern wird (#148)

    func testWriteThePostcodeCheckShots() {
        starteBeimOrtsschritt("95070>AUSLAND|Mexiko;10001>UNBEKANNT;40210>NICHTS")

        pruefe("95070", name: "1a-ausland-mexiko")
        pruefe("10001", name: "1b-keine-deutsche-plz")
        pruefe("40210", name: "1c-nicht-pruefbar")
    }

    // MARK: 2 — Ohne Filiale (#107)

    func testWriteTheWithoutBranchShots() {
        starteHinterDemAssistenten()
        attach(name: "2a-liste-ohne-filiale")

        app.tabBars.buttons["Angebote"].tap()
        _ = app.descendants(matching: .any)["tab.noMarkets"].waitForExistence(timeout: 15)
        attach(name: "2b-angebote-ohne-filiale")

        app.tippe(app.buttons["Filialen wählen"], "Filialen wählen")
        _ = app.navigationBars["Filialen wählen"].waitForExistence(timeout: 20)
        attach(name: "2c-auswahl-einen-tipp-dahinter")
    }

    /// Der Zustand ohne Region — erreichbar, indem man die einzige entfernt.
    func testWriteTheWithoutRegionShot() {
        starteHinterDemAssistenten()
        app.tabBars.buttons["Einstellungen"].tap()
        app.tippe(app.buttons["settings.places"], "Filialen und Regionen")
        app.tippe(app.buttons["PLZ 01219 entfernen"], "PLZ entfernen")
        app.tippe(app.buttons["Entfernen"], "Entfernen bestätigen")

        app.tabBars.buttons["Angebote"].tap()
        _ = app.descendants(matching: .any)["tab.noRegion"].waitForExistence(timeout: 15)
        attach(name: "3-keine-region")
    }

    // MARK: Helfer

    private func starteBeimOrtsschritt(_ pruefung: String) {
        app.launchArguments = ["-uiTesting", "-uiTestingPLZPruefung", pruefung]
        app.launch()
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")
        app.tippe(app.buttons["onboarding.skip"], "Überspringen im Assistenten")
        XCTAssertTrue(app.textFields["region.input"].waitForExistence(timeout: 20))
    }

    private func starteHinterDemAssistenten() {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingOnboardedNoBranches"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20))
    }

    /// Eine Zahl eingeben, prüfen lassen, fotografieren — und das Feld wieder
    /// leeren, damit die nächste bei null anfängt.
    private func pruefe(_ plz: String, name: String) {
        let feld = app.textFields["region.input"]
        feld.tap()
        feld.typeText(plz)
        app.buttons["onboarding.primary"].tap()
        _ = app.descendants(matching: .any)["region.error"].waitForExistence(timeout: 20)
        attach(name: name)

        feld.tap()
        feld.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: plz.count))
    }

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
