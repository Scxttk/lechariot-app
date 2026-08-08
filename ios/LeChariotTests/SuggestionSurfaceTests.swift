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
            choice: nil, listIsEmpty: true, isTyping: false, tourIsRunning: false
        ))
    }

    /// Sobald etwas auf der Liste steht, gehört der Platz der Liste.
    func testOnceSomethingIsOnTheListTheSurfaceIsClosed() {
        XCTAssertFalse(SuggestionSurface.isExpanded(
            choice: nil, listIsEmpty: false, isTyping: false, tourIsRunning: false
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
            choice: true, listIsEmpty: false, isTyping: false, tourIsRunning: false
        ))
    }

    /// Die Gegenrichtung: Wer in die Zeile tippt, weiß, was er braucht.
    func testTypingClosesTheSurfaceEvenOnAnEmptyList() {
        XCTAssertFalse(SuggestionSurface.isExpanded(
            choice: false, listIsEmpty: true, isTyping: false, tourIsRunning: false
        ))
    }

    // MARK: Der Rundgang

    /// Rahmen 2 leuchtet die Kacheln aus. Eine zugeklappte Fläche trägt keinen
    /// Anker, und ein Rahmen ohne Ziel überspringt sich selbst — der Rundgang
    /// ließe ausgerechnet den Tester, der bei Rahmen 1 mitgemacht hat, den
    /// Vorschlags-Rahmen nie sehen. Still, und nur ihn.
    func testTheTourOpensTheSurfaceNoMatterWhatTheListSays() {
        XCTAssertTrue(SuggestionSurface.isExpanded(
            choice: nil, listIsEmpty: false, isTyping: false, tourIsRunning: true
        ))
    }

    /// Und auch gegen eine ausdrückliche Wahl — sonst hinge ein Rahmen des
    /// Rundgangs daran, ob jemand vorher einen Knopf gedrückt hat.
    func testTheTourWinsAgainstAClosedSurface() {
        XCTAssertTrue(SuggestionSurface.isExpanded(
            choice: false, listIsEmpty: false, isTyping: false, tourIsRunning: true
        ))
    }

    /// Der Rundgang **überschreibt** die Wahl nicht, er übergeht sie nur:
    /// Danach gilt wieder, was der Nutzer eingestellt hatte.
    func testAfterTheTourTheUsersChoiceIsStillTheOneThatCounts() {
        XCTAssertFalse(SuggestionSurface.isExpanded(
            choice: false, listIsEmpty: true, isTyping: false, tourIsRunning: false
        ))
    }

    // MARK: Tippen (Punkt C-1, 2026-08-08)

    /// **Der Fall, um den es Scott ging.** Auf der leeren Liste stand die
    /// Fläche offen, und der erste Buchstabe hielt sie offen — nur eben mit
    /// dem Wörterbuch-Raster darin. Jetzt gibt Tippen den Platz zurück.
    func testTypingClosesTheSurfaceEvenWhileTheListIsStillEmpty() {
        XCTAssertFalse(SuggestionSurface.isExpanded(
            choice: nil, listIsEmpty: true, isTyping: true, tourIsRunning: false
        ))
    }

    /// **Aber nicht gegen eine ausdrückliche Wahl.** Wer den Winkel-Knopf
    /// gedrückt hat, will die Wörter sehen — auch beim nächsten Buchstaben.
    /// Ohne diese Reihenfolge wäre der Knopf beim Tippen wirkungslos, und das
    /// ist genau der Zustand, den er auflösen soll.
    func testTheButtonBeatsTyping() {
        XCTAssertTrue(SuggestionSurface.isExpanded(
            choice: true, listIsEmpty: false, isTyping: true, tourIsRunning: false
        ))
    }

    /// Und der Rundgang steht weiterhin über allem.
    func testTheTourBeatsTypingToo() {
        XCTAssertTrue(SuggestionSurface.isExpanded(
            choice: nil, listIsEmpty: true, isTyping: true, tourIsRunning: true
        ))
    }
}
