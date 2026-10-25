import XCTest

/// **Kochen, beide Wege, gegen die Attrappe.**
///
/// `MockGerichteRepository` antwortet fest: Lasagne für das gesuchte Gericht,
/// drei Vorschläge für die Liste. Geprüft wird, was die App daraus macht —
/// die Einwilligung davor, die Auswahl, und was am Ende auf der Liste steht.
final class GerichteJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func starte(_ extra: [String] = []) {
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"] + extra
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start landet nicht in der Liste")
    }

    private func oeffneKochen() {
        let knopf = app.buttons["list.kochen"]
        XCTAssertTrue(knopf.waitForExistence(timeout: 10), "Kein Kochen-Knopf in der Liste")
        knopf.tap()
    }

    private func anlegen(_ woerter: [String]) {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15), "Keine Eingabezeile")
        feld.tapAndAwaitKeyboard(in: app)
        for wort in woerter {
            feld.typeText(wort)
            app.buttons["Artikel hinzufügen"].tap()
        }
        app.buttons["list.input.done"].firstMatch.tap()
    }

    /// Eine Kachel der Liste. Mit Notiz heißt sie „Hackfleisch, 300 g" —
    /// die Menge aus dem Rezept steht als Notiz darunter.
    private func kachel(_ text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "identifier == 'list.tile' AND (label == %@ OR label BEGINSWITH %@)", text, text + ","
        )).firstMatch
    }

    /// Alle Kachel-Beschriftungen der Liste, von oben bis unten durchgescrollt.
    /// Seit die Liste nach Regalen sortiert, liegen neun Zutaten nicht mehr
    /// alle über dem Falz, und eine Kachel unter dem Falz steht nicht im Baum.
    private func alleKacheln() -> Set<String> {
        var gesehen = Set<String>()
        for _ in 0..<6 {
            let vorher = gesehen.count
            for k in app.buttons.matching(identifier: "list.tile").allElementsBoundByIndex {
                gesehen.insert(k.label.components(separatedBy: ",")[0])
            }
            if gesehen.count == vorher && vorher > 0 { break }
            app.swipeUp()
        }
        return gesehen
    }

    /// Gericht → Zutaten: Einwilligung, Lasagne, eine Zutat abwählen, alles
    /// Übrige landet auf der Liste — die abgewählte nicht.
    func testEinGerichtWirdZuZutatenAufDerListe() {
        starte()
        oeffneKochen()

        let erlauben = app.buttons["gerichte.erlauben"]
        XCTAssertTrue(erlauben.waitForExistence(timeout: 10),
                      "Vor dem ersten Mal fehlt die Einwilligung:\n" + app.debugDescription)
        erlauben.tap()

        let feld = app.textFields["gerichte.feld"]
        XCTAssertTrue(feld.waitForExistence(timeout: 10), "Bei leerer Liste startet Kochen nicht beim Gericht")
        feld.tap()
        feld.typeText("Lasagne für 4\n")

        let knoblauch = app.buttons["gerichte.zutat.Knoblauch"]
        XCTAssertTrue(knoblauch.waitForExistence(timeout: 10),
                      "Die Zutaten erscheinen nicht:\n" + app.debugDescription)
        knoblauch.tap()

        let hinzufuegen = app.buttons["gerichte.hinzufuegen"]
        XCTAssertEqual(hinzufuegen.label, "8 Zutaten hinzufügen")
        hinzufuegen.tap()

        XCTAssertTrue(kachel("Zwiebeln").waitForExistence(timeout: 10),
                      "Die Zutaten landen nicht auf der Liste:\n" + app.debugDescription)
        let liste = alleKacheln()
        XCTAssertTrue(liste.isSuperset(of: ["Lasagneplatten", "Hackfleisch", "Reibekäse"]), "\(liste)")
        XCTAssertFalse(liste.contains("Knoblauch"), "Die abgewählte Zutat steht trotzdem auf der Liste")
        XCTAssertEqual(liste.count, 8, "\(liste)")
    }

    /// Gericht aus Zutaten: Mit Nudeln und Tomaten auf der Liste fehlen der
    /// Bolognese Hackfleisch und Zwiebeln — genau die kommen dazu.
    func testVorschlaegeAusDerListeFuellenNurDasFehlende() {
        starte(["-uiTestingGerichteErlaubt"])
        anlegen(["Nudeln", "Tomaten"])
        oeffneKochen()

        let vorschlagen = app.buttons["gerichte.vorschlagen"]
        XCTAssertTrue(vorschlagen.waitForExistence(timeout: 10),
                      "Mit voller Liste startet Kochen nicht bei den Vorschlägen:\n" + app.debugDescription)
        vorschlagen.tap()

        let karte = app.buttons["gerichte.vorschlag"].firstMatch
        XCTAssertTrue(karte.waitForExistence(timeout: 10), "Keine Vorschläge:\n" + app.debugDescription)
        XCTAssertTrue(karte.label.contains("Spaghetti Bolognese"), karte.label)
        XCTAssertTrue(karte.label.contains("Fehlt: Hackfleisch, Zwiebeln"),
                      "Spaghetti sind über „Nudeln“ abgedeckt, Tomaten stehen da: \(karte.label)")
        karte.tap()

        let hinzufuegen = app.buttons["gerichte.hinzufuegen"]
        XCTAssertTrue(hinzufuegen.waitForExistence(timeout: 10))
        XCTAssertEqual(hinzufuegen.label, "2 Zutaten hinzufügen")
        hinzufuegen.tap()

        XCTAssertTrue(kachel("Hackfleisch").waitForExistence(timeout: 10),
                      "Hackfleisch fehlt auf der Liste:\n" + app.debugDescription)
        XCTAssertTrue(kachel("Zwiebeln").exists)
        XCTAssertFalse(kachel("Spaghetti").exists, "Was die Liste schon deckt, kommt nicht doppelt")
    }

    /// Ohne Einwilligung geht nichts raus und das Blatt fragt beim nächsten
    /// Mal wieder.
    func testOhneEinwilligungBleibtKochenAus() {
        starte()
        oeffneKochen()
        let nein = app.buttons["gerichte.nichtErlauben"]
        XCTAssertTrue(nein.waitForExistence(timeout: 10))
        nein.tap()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 5))

        oeffneKochen()
        XCTAssertTrue(app.buttons["gerichte.erlauben"].waitForExistence(timeout: 10),
                      "Nach „Nicht erlauben“ muss die Frage wiederkommen")
        XCTAssertFalse(app.textFields["gerichte.feld"].exists)
    }

    /// Aufgebrauchtes Tageskontingent: Der Satz dazu steht da, statt dass das
    /// Blatt still leer bleibt.
    func testAufgebrauchtesKontingentWirdGesagt() {
        starte(["-uiTestingGerichteErlaubt", "-uiTestingGerichteKontingentAus"])
        oeffneKochen()
        let feld = app.textFields["gerichte.feld"]
        XCTAssertTrue(feld.waitForExistence(timeout: 10))
        feld.tap()
        feld.typeText("Lasagne\n")
        let fehler = app.staticTexts["gerichte.fehler"].firstMatch
        let alsZelle = app.cells.containing(.staticText, identifier: "gerichte.fehler").firstMatch
        XCTAssertTrue(fehler.waitForExistence(timeout: 10) || alsZelle.exists,
                      "Kein Satz zum Kontingent:\n" + app.debugDescription)
        XCTAssertTrue(app.staticTexts["Für heute sind die 20 Anfragen aufgebraucht. Morgen geht es weiter."]
            .exists)
    }
}
