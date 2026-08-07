import XCTest

/// **Was die App aus dem getippten Wort gemacht hat, steht ab jetzt auf dem
/// Bildschirm.**
///
/// Die Rechnung dahinter steht in `QueryUnderstandingTests`. Hier geht es um
/// die zwei Stellen, an denen sie ankommen muss — und die zweite ist der
/// eigentliche Grund für diese Journey: Eine Zeile **ohne** Treffer hatte
/// bisher gar keinen Weg ins Trefferblatt. Ein Test, der nur den Kopf des
/// Blattes prüft, hätte genau den Fall verpasst, um den es geht.
final class QueryUnderstandingJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded", "-uiTestingOnboardedAllBranches"]
        app.launch()
    }

    /// „Vollmilch" geht als `milch` in die Suche — eine Ableitung, die vorher
    /// nirgends stand. Und die Trefferliste sagt an der Zeile, die **nur** über
    /// das Tag gefunden wurde, dass sie darüber gefunden wurde.
    func testTheSheetSaysWhatTheTypedWordWasUnderstoodAs() {
        addItem("Vollmilch")
        app.tapInTileMenu("list.matches")

        let kopf = app.staticTexts["matches.understanding"]
        XCTAssertTrue(kopf.waitForExistence(timeout: 10),
                      "Das Trefferblatt sagt nicht, als was das Wort verstanden wurde")
        XCTAssertEqual(kopf.label, "Verstanden als Milch")
        attach("treffer-vollmilch")

        // Der Titel trägt „Vollmilch" nicht; nur das Tag `milch` bringt
        // „Bärenmarke Die Frische" herein — und die Zeile sagt das.
        XCTAssertTrue(
            app.staticTexts["Lidl · über Milch"].waitForExistence(timeout: 5),
            "Die Zeile, die nur über das Wörterbuch kam, nennt ihren Begriff nicht"
        )
        // Die Gegenprobe: Die Zeilen, die das Wort im Namen tragen, sagen das
        // auch — und keine von beiden behauptet mehr, die bessere zu sein.
        XCTAssertTrue(app.staticTexts["Lidl · im Namen"].exists,
                      "Eine Zeile mit dem Wort im Titel bekommt keine Herkunft")
        XCTAssertFalse(app.staticTexts["Genau das"].exists,
                       "Das alte Abzeichen behauptet immer noch Güte")
        XCTAssertFalse(app.staticTexts["Passt vielleicht"].exists,
                       "Das alte Abzeichen behauptet immer noch Güte")
    }

    /// **Der Fall, an dem „vegan Schnitzel" hing.** Ohne Treffer sah „das Wort
    /// kennt das Wörterbuch nicht" genauso aus wie „diese Woche gibt es dazu
    /// nichts" — und es gab keinen Weg, nachzusehen.
    func testAWordWithoutADictionaryEntrySaysSoOnTheTileItself() {
        // **Das Beispiel musste weichen, weil der Wortschatz es eingeholt
        // hat.** „Schnitzel" war hier das unbekannte Wort; seit Tranche 3 hat
        // es einen eigenen Begriff samt Zeichnung, und der Bogen prüfte
        // seitdem einen Fall, den es nicht mehr gibt. Ein Beispiel für „kennt
        // das Wörterbuch nicht" ist naturgemäß auf Zeit gebaut — dieselbe
        // Korrektur wie in `ItemGlyphTests` und `QueryUnderstandingTests`.
        addItem("Schnürsenkel")

        // **Die Kachel sagt es selbst, nur nicht mehr in einem Satz.** Bis zum
        // 07.08. stand unter dem Artikel „… steht nicht im Wörterbuch"; ein
        // Raster aus 76-pt-Kacheln trägt keinen Satz. Was bleibt, ist das
        // Fragezeichen statt eines Zeichens — und der Wert der Kachel, den
        // VoiceOver ausspricht. **Die Unterscheidung selbst darf nicht
        // verschwinden:** „das Wort kenne ich nicht" sah bis zum 31.07.
        // genauso aus wie „diese Woche gibt es dazu nichts", und daran hing
        // „vegan Schnitzel" zehn Tage lang.
        let kachel = app.buttons["Schnürsenkel"].firstMatch
        XCTAssertTrue(kachel.waitForExistence(timeout: 10), "Keine Kachel für den Artikel")
        XCTAssertTrue((kachel.value as? String ?? "").contains("nicht im Wörterbuch"),
                      "Die Kachel sagt nicht, dass das Wort unbekannt ist: \(kachel.value ?? "–")")
        attach("liste-unbekanntes-wort")

        // Und der Weg ins Trefferblatt steht weiter offen, wo derselbe Satz
        // noch einmal steht — dort mit dem Weg zur Rückmeldung.
        app.tapInTileMenu("list.matches.empty", ofItem: "Schnürsenkel")
        XCTAssertTrue(
            app.staticTexts["matches.understanding.unknown"].waitForExistence(timeout: 10),
            "Das leere Trefferblatt sagt nicht, dass das Wort unbekannt ist"
        )
        attach("treffer-unbekanntes-wort")
    }

    // MARK: Helfer

    private func addItem(_ text: String) {
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15), "Keine Eingabezeile")
        feld.tapAndAwaitKeyboard(in: app)
        feld.typeText(text)
        app.buttons["Artikel hinzufügen"].tap()
        dismissQuantitySheet()
        XCTAssertTrue(app.buttons[text].waitForExistence(timeout: 10),
                      "\(text) ist nicht auf der Liste gelandet")
    }
    /// Schließt das Mengen-Menü, das seit [UI-8] beim Anlegen von selbst
    /// aufgeht. Die Journeys unten testen nicht das Menü, sondern was danach
    /// kommt — für sie ist es ein Zwischenschritt.
    private func dismissQuantitySheet() {
        let abbrechen = app.buttons["itemDetail.cancel"]
        if abbrechen.exists { abbrechen.tap(); return }
        // Seit dem 03.08. ist das Mengen-Menue kein Blatt mehr, sondern eine
        // Schicht ueber der Eingabezeile — sie geht mit dem Fokus, nicht mit
        // einem Knopf. Ein Zug ueber die **Liste** tut das; die
        // Bildschirmmitte liegt mit voller Software-Tastatur auf der Schicht
        // selbst, und der Tipp auf `list.matches.empty` landete dann auf dem
        // Wortschatz statt auf der Zeile (Screenshot im Merge-PR). Siehe
        // `dragTheListUp`.
        let panel = app.buttons["list.detailPanel.more"]
        guard panel.waitForExistence(timeout: 3) else { return }
        app.dragTheListUp()
        _ = panel.waitForNonExistence(timeout: 3)
    }


    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
