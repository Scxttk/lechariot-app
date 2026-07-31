import XCTest

/// **Die Zusage aus der Datenschutzerklärung, am Bildschirm nachgeprüft.**
///
/// Dort steht: „Weil wir bewusst nicht wissen, wer du bist, brauchen wir für
/// Auskunft oder Löschung deine Installations-ID … dann sagen wir dir, wo du
/// sie findest." Bis zum 2026-07-31 gab es diesen Ort nicht — die ID stand in
/// keinem Bildschirm der App. Ein Recht, das man nur mit einer Angabe
/// wahrnehmen kann, die nirgends abzulesen ist, ist keins.
///
/// Deshalb steht hier nicht nur „eine Zeile existiert", sondern auch, dass sie
/// **die ID selbst** zeigt: Eine Zeile mit der Überschrift und ohne Wert wäre
/// genau die Halbwahrheit, die dieselbe Woche schon zweimal gekostet hat.
final class InstallIdJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        completeOnboarding()
    }

    func testTheInstallIdIsFindableAndCopyable() {
        openSettings()
        let zeile = scrollToInstallId()

        // Der Wert steht wirklich da, nicht nur die Überschrift. Über den
        // Barrierefreiheits-Wert gelesen, weil die zwei Zeilen im Knopf zu
        // einem Element zusammenfallen.
        let wert = zeile.value as? String ?? ""
        XCTAssertTrue(
            istUUID(wert),
            "Die Zeile zeigt keine Installations-ID, sondern „\(wert)“"
        )

        XCTAssertTrue(
            app.buttons["Installations-ID kopieren"].exists,
            "Ohne Kopieren muss der Nutzer 36 Zeichen abtippen"
        )
        zeile.tap()

        // Der Zustand steht im Namen und nicht nur im Häkchen — ein Zeichen,
        // das nur zu sehen ist, bestätigt niemandem etwas, der VoiceOver
        // benutzt.
        XCTAssertTrue(
            app.buttons["Installations-ID kopiert"].waitForExistence(timeout: 5),
            "Nach dem Tippen sagt nichts, dass kopiert wurde"
        )
    }

    /// Der Bestätigungsdialog des Zurücksetzens muss die Folge nennen, die
    /// niemand rückgängig machen kann: Es gibt danach eine neue ID, und die
    /// alten hochgeladenen Zeilen sind von niemandem mehr zu benennen.
    func testTheResetDialogWarnsThatTheIdChanges() {
        openSettings()
        let reset = app.descendants(matching: .any)["settings.reset"]
        var swipes = 0
        while !reset.exists && swipes < 14 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(reset.exists, "„App zurücksetzen" + "“ nicht gefunden")
        reset.tap()

        let hinweis = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "neue Installations-ID")
        ).firstMatch
        XCTAssertTrue(
            hinweis.waitForExistence(timeout: 5),
            "Der Dialog verschweigt, dass die ID danach eine andere ist"
        )
        // Aufräumen, aber nicht behaupten: Wo der Abbrechen-Knopf eines
        // `confirmationDialog` im Elementbaum landet, ist nicht zugesichert
        // (`app.buttons` findet ihn nicht). Die Zusicherung dieses Tests steht
        // oben; das Schließen ist Hygiene und darf nicht der Grund sein,
        // aus dem er rot wird.
        let abbrechen = app.descendants(matching: .button)["Abbrechen"].firstMatch
        if abbrechen.waitForExistence(timeout: 3) { abbrechen.tap() }
    }

    /// **„Vorschläge vergessen" steht neben dem Zurücksetzen, nicht darin.**
    ///
    /// Eine Kaufhistorie sagt etwas über Ernährung, Alkohol, Kinder,
    /// Gesundheit. Wer sie loswerden will, soll dafür nicht Filialen, Profil
    /// und Onboarding mit aufgeben müssen — und der Dialog muss sagen, dass
    /// die auch wirklich bleiben.
    func testForgettingSuggestionsIsItsOwnButtonAndSaysWhatSurvives() {
        openSettings()
        let vergessen = app.descendants(matching: .any)["settings.forgetSuggestions"]
        var swipes = 0
        while !vergessen.exists && swipes < 14 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(vergessen.exists, "Kein eigener Knopf für die Vorschläge")
        vergessen.tap()

        let hinweis = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Filialen und deine Angaben bleiben")
        ).firstMatch
        XCTAssertTrue(
            hinweis.waitForExistence(timeout: 5),
            "Der Dialog sagt nicht, was das Vergessen *nicht* anfasst"
        )
        let abbrechen = app.descendants(matching: .button)["Abbrechen"].firstMatch
        if abbrechen.waitForExistence(timeout: 3) { abbrechen.tap() }
    }

    // MARK: Helfer

    private func istUUID(_ text: String) -> Bool {
        UUID(uuidString: text) != nil
    }

    private func scrollToInstallId() -> XCUIElement {
        let zeile = app.descendants(matching: .any)["settings.installId"]
        var swipes = 0
        while !zeile.exists && swipes < 14 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(zeile.exists, "Die Installations-ID steht nirgends in den Einstellungen")
        return zeile
    }

    private func openSettings() {
        let tab = app.tabBars.buttons["Einstellungen"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
    }

    private func completeOnboarding() {
        app.buttons["onboarding.primary"].tap()   // Willkommen
        app.buttons["onboarding.skip"].tap()      // Name
        let plz = app.textFields["Postleitzahl"]
        XCTAssertTrue(plz.waitForExistence(timeout: 15))
        plz.tap()
        plz.typeText("01219")
        app.buttons["onboarding.primary"].tap()
        app.buttons["onboarding.skip"].tap()      // Haushalt
        app.buttons["onboarding.skip"].tap()      // Ernährung
        app.buttons["onboarding.primary"].tap()   // Einwilligung
        let branch = app.buttons["Lidl, Dresden Reick"]
        XCTAssertTrue(branch.waitForExistence(timeout: 15))
        branch.tap()
        app.buttons["markets.done"].tap()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15))
    }
}
