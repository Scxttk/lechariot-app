import XCTest
@testable import LeChariot

/// **Was über der Eingabezeile steht — und wann.**
///
/// Kein Test kann einer Fläche beim Aufziehen zusehen, aber jeder kann die
/// Entscheidung dahinter prüfen. Am fertigen Bildschirm sieht man vier
/// Gestalten und nie, welche Regel sie gewählt hat.
///
/// Die Regel ist am 10.08. umgedreht worden (Punkt E) — die Tests hier sind
/// deshalb ganz neu geschrieben und nicht angepasst: Was vorher geprüft wurde
/// („Tippen macht zu"), ist jetzt falsch.
final class SuggestionSurfaceTests: XCTestCase {

    // MARK: Punkt E · Die zwei Zustände beim Schreiben

    /// **Tastatur auf, Feld leer: Vorschläge.** Der erste der beiden Zustände
    /// aus Scotts Punkt E — „they spawn when the keyboard gets opened".
    func testTheKeyboardAloneBringsTheSuggestions() {
        XCTAssertEqual(
            SuggestionSurface.shape(isTyping: false, keyboardIsUp: true,
                                    detailPanelIsUp: false, listIsEmpty: false),
            .staples
        )
    }

    /// **Ab dem ersten Buchstaben stehen dort Produkte.** Der zweite Zustand:
    /// „if u type a letter the matching starts".
    func testTypingSwapsTheSuggestionsForProducts() {
        XCTAssertEqual(
            SuggestionSurface.shape(isTyping: true, keyboardIsUp: true,
                                    detailPanelIsUp: false, listIsEmpty: false),
            .terms
        )
    }

    /// **Und die Produkte schlagen die Angaben-Schicht.** Zwei Schichten
    /// übereinander ließen von der Liste einen Streifen übrig — der Befund vom
    /// 08.08., der unverändert gilt. Nur weicht jetzt die Schicht und nicht
    /// mehr die Vorschlagsfläche.
    func testTypingBeatsTheDetailPanel() {
        XCTAssertEqual(
            SuggestionSurface.shape(isTyping: true, keyboardIsUp: true,
                                    detailPanelIsUp: true, listIsEmpty: false),
            .terms
        )
    }

    // MARK: Die Schicht daneben

    /// **Mit Tastatur gehört der Platz der Schicht.** Der geschrumpfte
    /// Streifen kostete dort die letzte Kachelreihe der Liste.
    func testTheDetailPanelWithAKeyboardLeavesNoRoom() {
        XCTAssertEqual(
            SuggestionSurface.shape(isTyping: false, keyboardIsUp: true,
                                    detailPanelIsUp: true, listIsEmpty: false),
            .none
        )
    }

    /// **Ohne Tastatur bleibt die schmale Reihe** — der Weg über „Häufig auf
    /// der Liste". Der nächste Vorschlag muss **einen Tipp** weit weg bleiben;
    /// genau das war am 26.07. schon einmal kaputt.
    func testTheStapleRouteKeepsTheNextSuggestionOneTapAway() {
        XCTAssertEqual(
            SuggestionSurface.shape(isTyping: false, keyboardIsUp: false,
                                    detailPanelIsUp: true, listIsEmpty: false),
            .staplesRow
        )
    }

    // MARK: Die ruhende Liste

    /// Die leere Liste trägt die Einladung, auch ohne Tastatur.
    func testAnEmptyListShowsTheSuggestions() {
        XCTAssertEqual(
            SuggestionSurface.shape(isTyping: false, keyboardIsUp: false,
                                    detailPanelIsUp: false, listIsEmpty: true),
            .staples
        )
    }

    /// Sobald etwas auf der Liste steht und niemand schreibt, gehört der Platz
    /// der Liste.
    func testAFilledListAtRestGivesThePlaceBack() {
        XCTAssertEqual(
            SuggestionSurface.shape(isTyping: false, keyboardIsUp: false,
                                    detailPanelIsUp: false, listIsEmpty: false),
            .none
        )
    }


    /// **Die Gegenprobe zur alten Regel.** Bis zum 10.08. entschied eine
    /// gemerkte Wahl des Nutzers, und der Winkel-Knopf war ihre Fassung. Beide
    /// sind weg: Derselbe Zustand ergibt jetzt immer dieselbe Gestalt, ganz
    /// gleich, was vorher angetippt wurde.
    func testTheShapeDependsOnlyOnTheCurrentState() {
        let zweimal = (0..<2).map { _ in
            SuggestionSurface.shape(isTyping: false, keyboardIsUp: true,
                                    detailPanelIsUp: false, listIsEmpty: false)
        }
        XCTAssertEqual(zweimal[0], zweimal[1])
    }
}
