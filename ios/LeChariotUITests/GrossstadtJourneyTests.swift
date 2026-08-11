import XCTest

/// **Großstadt mit Vorschlägen — Scotts Weg vom 11.08. (#143).**
///
/// > „i tried stuttgart as location, then clicked on the summoned containers
/// > with stuttgart, bade würtemberg etc., clicked them, app said didnt find it
/// > and changed automatically to 01219"
///
/// Zwei Fehler ineinander, beide am 11.08. an Apples Schnittstellen gemessen,
/// bevor eine Zeile Code entstand:
///
/// 1. Der Vervollständiger antwortet auf „Stuttgart" mit **„Stuttgart" /
///    „Baden-Württemberg, Deutschland"**. Angetippt ging beides zusammen als
///    Ortsname an den Geocoder — der antwortete richtig (70173), und der eigene
///    Namensfilter warf die Antwort weg, weil „Stuttgart, Baden-Württemberg,
///    Deutschland" nicht in „Stuttgart" steckt. Danach sechzehn Länder-Fragen
///    derselben Sorte, am Ende „kennt Apple nicht".
/// 2. In der Vorschlagsliste steht, gemessen mit dem Kartenausschnitt um
///    Dresden, an zweiter Stelle **„Stuttgarter Straße, 01189 Dresden"**. Eine
///    Adresse beantwortet sich selbst (Regel vom 06.08.) — angetippt wurde
///    daraus kommentarlos eine PLZ aus der *alten* Gegend. Das ist der stille
///    Rückfall aus dem Bericht.
///
/// **Was diese Journeys prüfen und was nicht.** Die Entscheidungsregel selbst
/// steht in `RegionQueryTests` (reine Rechnung, ohne Netz, mit den gemessenen
/// Placemark-Feldern). Hier läuft der **Weg**: dass der getippte Text den Tipp
/// auf einen Vorschlag überlebt, dass ein Fehlschlag als Fehlschlag dasteht und
/// dass dabei nichts Altes an die Stelle der Eingabe tritt.
final class GrossstadtJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    /// Die Vorschläge, die Apple am 11.08. für „Stuttgart" wirklich lieferte —
    /// ohne Leerzeichen, weil `launchArguments` keine durchreichen.
    private let vorschlaege =
        "Stuttgart|Baden-Württemberg,Deutschland;Stuttgarter-Straße|01189-Dresden,Deutschland"

    /// Die Vorgabe ist **je Frage** gestellt: Der Vorschlag schickt eine andere
    /// Zeichenkette los als die, die getippt wurde, und genau dieser
    /// Unterschied ist der Fehler gewesen. Eine Vorgabe, die für jede Frage
    /// dasselbe antwortet, könnte ihn gar nicht abbilden.
    private let ortsantworten =
        "Stuttgart,Baden-Württemberg,Deutschland>Stuttgart|70173|Baden-Württemberg"
        + ";Stuttgart>Stuttgart|70173|Baden-Württemberg"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private var field: XCUIElement { app.textFields["region.input"] }
    private var primary: XCUIElement { app.buttons["onboarding.primary"] }

    private func starteBeimOrtsschritt(antworten: String? = nil) {
        app.launchArguments = [
            "-uiTesting",
            "-uiTestingAddressSuggestions", vorschlaege,
            "-uiTestingCityLookup", antworten ?? ortsantworten,
        ]
        app.launch()
        app.tippe(app.buttons["onboarding.primary"], "Weiter im Assistenten")
        app.tippe(app.buttons["onboarding.skip"], "Überspringen im Assistenten")
        XCTAssertTrue(field.waitForExistence(timeout: 20))
    }

    private func tippeOrt(_ text: String) {
        field.tap()
        field.typeText(text)
    }

    private func vorschlag(_ index: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "region.suggestion").element(boundBy: index)
    }

    // MARK: Der Weg, der scheiterte

    /// **Der Kern von #143:** Vorschlag antippen setzt den gewählten Ort.
    func testTappingTheBigCitySuggestionSetsThatCity() {
        starteBeimOrtsschritt()
        tippeOrt("Stuttgart")

        XCTAssertTrue(vorschlag(0).waitForExistence(timeout: 10),
                      "Keine Vorschläge zu einer Großstadt:\n" + app.debugDescription)
        vorschlag(0).tap()

        let verstanden = app.descendants(matching: .any)["region.resolvedPlace"]
        XCTAssertTrue(verstanden.waitForExistence(timeout: 20),
                      "Der Vorschlag hat den Ort nicht gesetzt:\n" + app.debugDescription)
        XCTAssertTrue(verstanden.label.contains("70173"),
                      "Es muss die PLZ des gewählten Orts sein, nicht irgendeine")
        XCTAssertEqual(primary.label, "Weiter", "Nach dem Vorschlag ist der Ort bestätigt")
    }

    /// Und der Fehler, den Scott sah, darf nicht mehr auftreten.
    func testTheBigCitySuggestionDoesNotEndInNotFound() {
        starteBeimOrtsschritt()
        tippeOrt("Stuttgart")
        XCTAssertTrue(vorschlag(0).waitForExistence(timeout: 10))
        vorschlag(0).tap()

        XCTAssertTrue(app.descendants(matching: .any)["region.resolvedPlace"].waitForExistence(timeout: 20))
        XCTAssertFalse(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS %@", "kennt Apple nicht als Ort")
            ).firstMatch.exists,
            "Der Weg, der die Mehrdeutigkeit lösen soll, scheitert an seinem eigenen Ergebnis"
        )
    }

    // MARK: Kein stiller Rückfall

    /// **Ein Fehlschlag heißt Fehlschlag** — und die Meldung nennt, was der
    /// Mensch getippt hat, nicht Apples Vorschlagstext.
    func testAFailedLookupSaysSoInTheUsersOwnWords() {
        // Nur die getippte Frage hat eine Antwort; der Vorschlagstext nicht.
        starteBeimOrtsschritt(antworten: "Quatschhausen>Quatschhausen|99999|Sachsen")
        tippeOrt("Stuttgart")
        XCTAssertTrue(vorschlag(0).waitForExistence(timeout: 10))
        vorschlag(0).tap()

        let fehler = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "kennt Apple nicht als Ort")
        ).firstMatch
        XCTAssertTrue(fehler.waitForExistence(timeout: 20),
                      "Ein gescheiterter Vorschlag muss es sagen:\n" + app.debugDescription)
        XCTAssertTrue(fehler.label.contains("Stuttgart"),
                      "Die Meldung soll die Frage des Menschen nennen: \(fehler.label)")
        // **Im Baum ist nicht auf dem Schirm.** Im Bild vom 11.08. stand die
        // Vorschlagsliste nach dem Tipp wieder da und schob die Meldung hinter
        // die Tastatur — der Test war grün, der Mensch sah nichts.
        XCTAssertTrue(fehler.isHittable, "Die Meldung steht im Baum, aber nicht im Bild")
        XCTAssertFalse(
            app.descendants(matching: .any).matching(identifier: "region.suggestion")
                .element(boundBy: 0).exists,
            "Nach der Wahl darf die Vorschlagsliste nicht zurückkommen"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["region.resolvedPlace"].exists,
            "Nach einem Fehlschlag darf kein Ort bestätigt dastehen"
        )
        XCTAssertEqual(primary.label, "Ort suchen",
                       "Ohne bestätigten Ort führt der Knopf zu Apple, nicht in die App")
    }

    /// **Die zweite Hälfte des Berichts: kein Rückfall auf die alte PLZ.**
    ///
    /// Startet mit einer gespeicherten Region (01219) — ohne sie gäbe es gar
    /// nichts, worauf zurückzufallen wäre, und der Test wäre wertlos. Nach dem
    /// gescheiterten Vorschlag muss die Liste der Regionen unverändert sein und
    /// das Feld darf nicht die alte Zahl tragen.
    func testAFailedLookupNeverPutsTheOldPostcodeInItsPlace() {
        app.launchArguments = [
            "-uiTesting", "-uiTestingOnboarded",
            "-uiTestingAddressSuggestions", vorschlaege,
            "-uiTestingCityLookup", "Quatschhausen>Quatschhausen|99999|Sachsen",
        ]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 20))

        app.tabBars.buttons["Einstellungen"].tap()
        app.tippe(app.buttons["settings.places"], "Filialen und Regionen")
        app.tippe(app.buttons["Region hinzufügen"], "Region hinzufügen")

        XCTAssertTrue(field.waitForExistence(timeout: 15))
        tippeOrt("Stuttgart")
        XCTAssertTrue(vorschlag(0).waitForExistence(timeout: 10))
        vorschlag(0).tap()

        XCTAssertTrue(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS %@", "kennt Apple nicht als Ort")
            ).firstMatch.waitForExistence(timeout: 20),
            "Ohne Meldung merkt niemand, dass nichts übernommen wurde"
        )
        XCTAssertNotEqual(field.value as? String, "01219",
                          "Die App hat die zuvor gespeicherte PLZ ins Feld gesetzt")

        // Und gespeichert wurde erst recht nichts.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["PLZ 01219"].waitForExistence(timeout: 15),
                      "Die bestehende Region ist verschwunden")
        XCTAssertFalse(app.staticTexts["PLZ 70173"].exists,
                       "Ein gescheiterter Ort darf keine Region hinterlassen")
    }
}
