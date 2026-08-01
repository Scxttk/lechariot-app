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
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
        waitForList()
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

    /// **Das Löschversprechen ist einlösbar, nicht nur nennbar** ([UI-4],
    /// 01.08.). Bis dahin gab es nur „App zurücksetzen" (rein lokal) und die
    /// kopierbare ID — der Nutzer konnte seine ID nennen und warten.
    ///
    /// Der Test schaut auf den **Satz danach**: Die App muss sagen, was
    /// wirklich verschwunden ist. Ein „Erledigt" ohne Zahl wäre genau die
    /// Behauptung, gegen die dieser Weg gebaut wurde.
    func testUploadedDataCanBeDeletedFromTheDevice() {
        openSettings()
        let löschen = scrollTo("settings.deleteUploaded")
        löschen.tap()

        let bestätigen = app.descendants(matching: .button)["Löschen"].firstMatch
        XCTAssertTrue(bestätigen.waitForExistence(timeout: 5))
        bestätigen.tap()

        let ergebnis = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH[c] %@", "Gelöscht:")
        ).firstMatch
        XCTAssertTrue(
            ergebnis.waitForExistence(timeout: 10),
            "Nach dem Löschen sagt nichts, was tatsächlich gelöscht wurde"
        )
    }

    /// Der Export legt eine Datei bereit und bietet sie zum Teilen an — ein
    /// Auskunftsrecht ohne Ausgang wäre keins.
    func testTheExportProducesAFileToShare() {
        openSettings()
        scrollTo("settings.export").tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["settings.export.share"].waitForExistence(timeout: 10),
            "Der Export lässt sich nicht weitergeben"
        )
    }

    // MARK: Helfer

    private func istUUID(_ text: String) -> Bool {
        UUID(uuidString: text) != nil
    }

    private func scrollTo(_ identifier: String) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        var swipes = 0
        while !element.exists && swipes < 14 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.exists, "\(identifier) steht nirgends in den Einstellungen")
        return element
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
