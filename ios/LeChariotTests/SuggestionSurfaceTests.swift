import XCTest
@testable import LeChariot

/// **Wann die Vorschlagsfläche offen steht.**
///
/// Kein Test kann einer Fläche beim Aufziehen zusehen, aber jeder kann die
/// Entscheidung dahinter prüfen. Vier Regeln, die am fertigen Bildschirm
/// ununterscheidbar aussehen — man sieht offen oder zu, nie warum.
final class SuggestionSurfaceTests: XCTestCase {

    // MARK: Der Vorgabefall

    func testAnEmptyListShowsTheSuggestions() {
        XCTAssertTrue(SuggestionSurface.isExpanded(
            choice: nil, listIsEmpty: true, isTyping: false
        ))
    }

    /// Sobald etwas auf der Liste steht, gehört der Platz der Liste.
    func testOnceSomethingIsOnTheListTheSurfaceIsClosed() {
        XCTAssertFalse(SuggestionSurface.isExpanded(
            choice: nil, listIsEmpty: false, isTyping: false
        ))
    }

    // MARK: Was der Nutzer zuletzt getan hat

    /// **Der Fall, der schon einmal ein Fehler war.** Wer eine Kachel antippt,
    /// legt damit einen Artikel auf die Liste — und ohne diese Regel klappte
    /// die Fläche im selben Moment unter dem Daumen zu. Der zweite Vorschlag
    /// wäre wieder einen Knopfdruck weit weg, genau wie vor dem 2026-07-26,
    /// als der Streifen noch am Leerzustand hing.
    func testTakingASuggestionKeepsTheSurfaceOpenEvenThoughTheListIsNoLongerEmpty() {
        XCTAssertTrue(SuggestionSurface.isExpanded(
            choice: true, listIsEmpty: false, isTyping: false
        ))
    }

    /// Die Gegenrichtung: Wer in die Zeile tippt, weiß, was er braucht.
    func testTypingClosesTheSurfaceEvenOnAnEmptyList() {
        XCTAssertFalse(SuggestionSurface.isExpanded(
            choice: false, listIsEmpty: true, isTyping: false
        ))
    }

    // MARK: Der Rundgang — die Regel, die es nicht mehr gibt

    /// **Der Rundgang hatte hier Vorfahrt, und sie ist am 09.08. gefallen.**
    ///
    /// Bis dahin stand die Fläche offen, solange er lief: Sein zweiter Rahmen
    /// leuchtete die Kacheln aus, eine zugeklappte Fläche trägt keinen Anker,
    /// und ein Rahmen ohne Ziel überspringt sich selbst. Der Rundgang zum
    /// Mitmachen zeigt statt der Kacheln den **Knopf** und wartet darauf, dass
    /// der Nutzer ihn drückt (`TutorialStep.Deed.opensSuggestions`) — eine
    /// Fläche, die von allein offen steht, nähme genau diesem Rahmen sein Ziel.
    ///
    /// Was hier bleibt, ist die Gegenprobe: Der Zustand hängt an nichts mehr
    /// außer an den drei Eingaben. Nach dem Anlegen eines Artikels ist die
    /// Fläche zu (`ShoppingListView.addItem` setzt die Wahl), und genau davor
    /// steht der Rahmen.
    func testTheTourNoLongerForcesTheSurfaceOpen() {
        XCTAssertFalse(SuggestionSurface.isExpanded(
            choice: false, listIsEmpty: false, isTyping: false
        ))
    }

    /// Und danach gilt weiterhin, was der Nutzer eingestellt hatte.
    func testTheUsersChoiceIsTheOneThatCounts() {
        XCTAssertFalse(SuggestionSurface.isExpanded(
            choice: false, listIsEmpty: true, isTyping: false
        ))
    }

    // MARK: Tippen (Punkt C-1, 2026-08-08)

    /// **Der Fall, um den es Scott ging.** Auf der leeren Liste stand die
    /// Fläche offen, und der erste Buchstabe hielt sie offen — nur eben mit
    /// dem Wörterbuch-Raster darin. Jetzt gibt Tippen den Platz zurück.
    func testTypingClosesTheSurfaceEvenWhileTheListIsStillEmpty() {
        XCTAssertFalse(SuggestionSurface.isExpanded(
            choice: nil, listIsEmpty: true, isTyping: true
        ))
    }

    /// **Aber nicht gegen eine ausdrückliche Wahl.** Wer den Winkel-Knopf
    /// gedrückt hat, will die Wörter sehen — auch beim nächsten Buchstaben.
    /// Ohne diese Reihenfolge wäre der Knopf beim Tippen wirkungslos, und das
    /// ist genau der Zustand, den er auflösen soll.
    func testTheButtonBeatsTyping() {
        XCTAssertTrue(SuggestionSurface.isExpanded(
            choice: true, listIsEmpty: false, isTyping: true
        ))
    }

}
