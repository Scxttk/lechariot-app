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
        app.buttons["list.matches"].firstMatch.tap()

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
    func testAWordWithoutADictionaryEntrySaysSoOnTheListItself() {
        addItem("Schnitzel")

        let hinweis = app.buttons["list.matches.empty"]
        XCTAssertTrue(hinweis.waitForExistence(timeout: 10),
                      "Die Zeile ohne Treffer ist kein Weg ins Trefferblatt")
        XCTAssertTrue(hinweis.label.contains("nicht im Wörterbuch"),
                      "Die Zeile sagt nicht, dass das Wort unbekannt ist: \(hinweis.label)")
        XCTAssertTrue(hinweis.label.contains("Diese Woche nirgends im Angebot"),
                      "Die alte Auskunft darf nicht verschwinden — beide Gründe zählen")
        attach("liste-unbekanntes-wort")

        // Und der Hinweis ist selbst der Knopf: Er führt ins Trefferblatt, wo
        // derselbe Satz noch einmal steht — dort mit dem Weg zur Rückmeldung.
        hinweis.tap()
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
        feld.tap()
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
        // einem Knopf. Ein Wisch ueber die Liste tut das.
        let panel = app.buttons["list.detailPanel.more"]
        guard panel.waitForExistence(timeout: 3) else { return }
        app.swipeUp()
        _ = panel.waitForNonExistence(timeout: 3)
    }


    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
