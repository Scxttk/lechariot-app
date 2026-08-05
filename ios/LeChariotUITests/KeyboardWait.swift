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

extension XCUIApplication {
    /// **Ein Zug an der Liste — nicht ein Wisch in die Bildschirmmitte.**
    ///
    /// Der Vertrag heißt „wer die Liste anfasst, beendet den Tipp-Fluss"
    /// (`ShoppingListView`, `scrollDismissesKeyboard` plus DragGesture), und
    /// bis zum 05.08. prüfte ihn überall ein `app.swipeUp()`. Der wischt in
    /// der Mitte des Fensters — und traf dort nur zufällig die Liste:
    ///
    /// Auf einem kopflosen Simulator (ohne Simulator-Fenster, also ohne
    /// angeschlossene Hardware-Tastatur) steht die **volle**
    /// Software-Tastatur. Gemessen am 05.08. auf `merge-sim` (393 × 852):
    /// Tastatur ab y = 561, Angaben-Schicht ab y = 341 — die Mitte (y = 426)
    /// liegt auf der Schicht, deren waagerecht scrollender Wortschatz den
    /// senkrechten Zug schluckt, und der Fluss endet nie. Auf Läufen mit
    /// offenem Simulator-Fenster ist die Tastatur nur die Minileiste, die
    /// Mitte lag frei — deshalb ist das nie aufgefallen, und deshalb war
    /// dieselbe Suite am selben Stand mal grün und mal rot, je nachdem, wer
    /// sie startete.
    ///
    /// Der Zug hier startet im sichtbaren Listenstreifen unter der
    /// Navigationsleiste (y ≈ 0,32 → 0,16 der Fensterhöhe) — über der
    /// Schicht in **jeder** Tastaturlage, unter der Navigationsleiste auf
    /// iPhone wie iPad.
    func dragTheListUp() {
        let fenster = windows.firstMatch
        let von = fenster.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
        let nach = fenster.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.16))
        von.press(forDuration: 0.05, thenDragTo: nach)
    }
}
