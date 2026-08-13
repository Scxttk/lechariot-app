import XCTest

/// **Der Zustand ohne gewählte Filiale — auf beiden Tabs** (#107).
///
/// Gefunden am 31.07.: Die Liste war ohne Filiale gar nicht die Einkaufsliste,
/// sondern eine `ContentUnavailableView` davor — keine Eingabezeile, keine
/// Vorschläge. Für die Liste ist das seit dem Abriss des Filialen-Tors erledigt;
/// gemessen hat es bis heute niemand, und über den **Angeboten** stand dieselbe
/// Fläche weiter — mit „Zu den Einstellungen" als einzigem Ausgang, drei Tipps
/// von der Marktauswahl entfernt.
///
/// Diese Journeys halten beides fest: dass die Liste ein Bildschirm ist, und
/// dass der Weg zur Auswahl von dort **einen** Tipp weit ist.
final class OhneFilialeJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    private func starteOhneFiliale() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingOnboardedNoBranches"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20))
    }

    // MARK: Die Liste

    /// **Die Liste ohne Filiale ist eine Liste.** Eingabezeile, Vorschläge, und
    /// die Karte, die sagt, was fehlt — der Startzustand, auf den der
    /// Onboarding-Ablauf setzt.
    func testTheListWithoutBranchesIsAScreen() {
        starteOhneFiliale()

        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15),
                      "Ohne Eingabezeile ist der Liste-Tab kein Bildschirm\n" + app.debugDescription)
        XCTAssertTrue(feld.isHittable, "Im Baum stehen reicht nicht — sie muss zu erreichen sein")

        // Die Vorschläge hängen am Wörterbuch, nicht an den Angeboten (#142).
        XCTAssertTrue(app.staticTexts["Häufig auf der Liste"].exists,
                      "Ohne Filiale bleiben die Vorschläge stehen\n" + app.debugDescription)

        let karte = app.buttons["list.chooseMarkets"]
        XCTAssertTrue(karte.exists, "Was fehlt, muss die Liste sagen")
        karte.tap()
        XCTAssertTrue(app.navigationBars["Filialen wählen"].waitForExistence(timeout: 20),
                      "Die Karte führt in die Auswahl\n" + app.debugDescription)
    }

    // MARK: Die Angebote

    /// **Ohne Filiale sind die Angebote wirklich nichts** — aber der Ausgang
    /// führt jetzt dorthin, wo sie entstehen, statt in die Einstellungen.
    func testTheOffersTabHandsOverTheWayToThePicker() {
        starteOhneFiliale()
        app.tabBars.buttons["Angebote"].tap()

        let leer = app.descendants(matching: .any)["tab.noMarkets"]
        XCTAssertTrue(leer.waitForExistence(timeout: 15),
                      "Der Zustand muss ein Bildschirm sein\n" + app.debugDescription)

        app.tippe(app.buttons["Filialen wählen"], "Filialen wählen")
        XCTAssertTrue(app.navigationBars["Filialen wählen"].waitForExistence(timeout: 20),
                      "Ein Tipp, nicht drei\n" + app.debugDescription)

        // Und zurück, ohne Sackgasse.
        app.tippe(app.buttons["Abbrechen"], "Abbrechen")
        XCTAssertTrue(leer.waitForExistence(timeout: 15))
    }

    // MARK: Ohne Region

    /// **Der Nachbarzustand, aus demselben Helfer** — und die Stelle, an der
    /// zwei Blätter hintereinander hochfahren: PLZ eingeben, und die
    /// Filialauswahl steht direkt dahinter. Ein `sheet`, das während der
    /// Auflösung des vorherigen gesetzt wird, erscheint **nicht**; dass es hier
    /// erscheint, ist der ganze Grund für diesen Test.
    func testWithoutARegionThePostcodeAndThePickerFollowEachOther() {
        starteOhneFiliale()
        entferneDieEinzigeRegion()

        app.tabBars.buttons["Angebote"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["tab.noRegion"].waitForExistence(timeout: 15),
                      "Ohne Region muss der Tab sagen, was fehlt\n" + app.debugDescription)

        app.tippe(app.buttons["Postleitzahl hinzufügen"], "Postleitzahl hinzufügen")
        let feld = app.textFields["region.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15), "Das Blatt mit dem Feld fehlt\n" + app.debugDescription)
        feld.tap()
        feld.typeText("01219")
        app.buttons["Weiter"].tap()

        XCTAssertTrue(app.navigationBars["Filialen wählen"].waitForExistence(timeout: 25),
                      "Nach der PLZ muss die Auswahl kommen, nicht wieder der leere Tab\n" + app.debugDescription)
    }

    private func entferneDieEinzigeRegion() {
        app.tabBars.buttons["Einstellungen"].tap()
        app.tippe(app.buttons["settings.places"], "Filialen und Regionen")
        app.tippe(app.buttons["PLZ 01219 entfernen"], "PLZ entfernen")
        app.tippe(app.buttons["Entfernen"], "Entfernen bestätigen")
    }
}
