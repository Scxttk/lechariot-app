import XCTest

/// **Der Fehler aus der Bedienrunde vom 10.08., am Gerät nachgestellt.**
///
/// Scott, wörtlich: „Big bug, if a product like Milch is erledigt I can't add a
/// new Milch item". Die Dubletten-Abweisung zählte erledigte Artikel mit, und
/// ein abgewiesenes `add` ist still — die App tat schlicht nichts, und der
/// Grund war auf dem Bildschirm nicht zu sehen.
///
/// Die Journey geht denselben Weg wie ein Mensch: Artikel anlegen, abhaken,
/// nächste Woche wieder anlegen. Ein Unit-Test auf `ShoppingListStore.add`
/// zeigt den Fehler auch; was er nicht zeigt, ist die Stille — dass am Ende
/// kein offener Artikel dasteht und niemand erfährt, warum.
final class ErledigtJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnboarded"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Einkaufsliste"].waitForExistence(timeout: 15),
                      "Der Start hinter dem Assistenten landet nicht in der Liste")
    }

    /// Milch anlegen, abhaken, Milch anlegen — und die Zeile ist wieder offen.
    func testACheckedItemCanBeAddedAgain() {
        anlegen("Milch")

        let kachel = app.buttons["Milch"].firstMatch
        XCTAssertTrue(kachel.waitForExistence(timeout: 10), "Milch liegt nicht auf der Liste")
        kachel.tap()
        XCTAssertTrue(
            wartetAuf(kachel, zustand: "erledigt"),
            "Der Tipp hakt nicht ab:\n" + app.debugDescription
        )

        anlegen("Milch")

        XCTAssertTrue(
            wartetAuf(kachel, zustand: "erledigt", enthalten: false),
            "Erledigtes blockiert weiter die Neuanlage — der Artikel bleibt abgehakt"
        )
        // **Eine Zeile, nicht zwei.** Bring! kennt einen Artikel entweder auf
        // der Liste oder nicht; ein zweites „Milch" daneben wäre die andere
        // mögliche Antwort und die schlechtere.
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "label == %@", "Milch")).count, 1,
            "Aus dem erneuten Anlegen darf keine zweite Milch entstehen"
        )
    }

    /// **Und das Abgehakte kommt in den Vorrat zurück** (Punkt D): Der Streifen
    /// sperrte bisher alles, was auf der Liste stand — auch das Erledigte.
    /// Damit gab es für ein gerade gekauftes Produkt gar keinen kurzen Weg
    /// zurück, und Scotts „the products clicked should go into zuletzt
    /// verwendet" war genau das.
    func testACheckedItemComesBackAsASuggestion() {
        anlegen("Milch")
        // Erst aus dem Tipp-Fluss heraus: Solange die Angaben-Schicht steht,
        // zeigt der Streifen sie und nicht die Vorschläge (`showsStapleSurface`).
        app.buttons["list.input.done"].firstMatch.tap()

        let kachel = app.buttons["Milch"].firstMatch
        XCTAssertTrue(kachel.waitForExistence(timeout: 10))
        kachel.tap()
        XCTAssertTrue(wartetAuf(kachel, zustand: "erledigt"), "Der Tipp hakt nicht ab")

        // **Die Fläche kommt mit der Tastatur** (10.08., Punkt E). Hier stand
        // bis zum Zusammenführen ein Tipp auf den Winkel-Knopf; den gibt es
        // nicht mehr, und er wird auch nicht gebraucht: Tastatur auf und Feld
        // leer heißt Vorschläge.
        app.textFields["list.input"].tapAndAwaitKeyboard(in: app)

        XCTAssertTrue(
            app.buttons["Milch hinzufügen"].waitForExistence(timeout: 10),
            "Abgehaktes taucht nicht wieder im Vorrat auf:\n" + app.debugDescription
        )
    }

    // MARK: Helfer

    private func anlegen(_ text: String) {
        let feld = app.textFields["list.input"]
        XCTAssertTrue(feld.waitForExistence(timeout: 15), "Keine Eingabezeile")
        feld.tapAndAwaitKeyboard(in: app)
        feld.typeText(text)
        app.buttons["Artikel hinzufügen"].tap()
    }

    /// Wartet, bis der Zustandstext der Kachel das Wort trägt — oder es los ist.
    ///
    /// `accessibilityValue` ändert sich ohne eigenes Ereignis; ein einzelnes
    /// Ablesen direkt nach dem Tipp trifft je nach Laune des Simulators noch
    /// den alten Wert.
    private func wartetAuf(
        _ element: XCUIElement,
        zustand: String,
        enthalten: Bool = true,
        timeout: TimeInterval = 10
    ) -> Bool {
        let ende = Date().addingTimeInterval(timeout)
        while Date() < ende {
            if ((element.value as? String) ?? "").contains(zustand) == enthalten { return true }
            usleep(200_000)
        }
        return false
    }
}
