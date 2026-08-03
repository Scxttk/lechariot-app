import XCTest

/// **Ins Feld tippen und warten, bis der Fokus wirklich liegt.**
///
/// `tap()` kommt zurück, sobald die Berührung zugestellt ist — nicht, sobald
/// das Textfeld erster Responder ist. Das nächste `typeText` fällt dann mit
///
///     Failed to synthesize event: Neither element nor any descendant has
///     keyboard focus
///
/// und zwar **manchmal**: Am 03.08. war `AddFlowJourneyTests` bei jedem Lauf
/// anders rot, zwei bis vier von sechs. Nachgemessen war die App unschuldig —
/// wer nach dem Tipp eine Sekunde wartet, tippt sechs Wörter hintereinander
/// durch, und die Angaben-Schicht steht bei jeder Messung im 100-ms-Raster.
///
/// **Ein wackelnder Test ist schlimmer als keiner:** Er kostet jedes Mal die
/// Frage, ob diesmal die App gemeint war.
extension XCUIElement {
    func tapAndAwaitKeyboard(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        tap()
        XCTAssertTrue(
            app.keyboards.firstMatch.waitForExistence(timeout: 10),
            "Nach dem Tipp ins Feld steht keine Tastatur",
            file: file, line: line
        )
    }
}
