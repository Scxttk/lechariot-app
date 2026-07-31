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
            choice: nil, listIsEmpty: true, tourIsRunning: false
        ))
    }

    /// Sobald etwas auf der Liste steht, gehört der Platz der Liste.
    func testOnceSomethingIsOnTheListTheSurfaceIsClosed() {
        XCTAssertFalse(SuggestionSurface.isExpanded(
            choice: nil, listIsEmpty: false, tourIsRunning: false
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
            choice: true, listIsEmpty: false, tourIsRunning: false
        ))
    }

    /// Die Gegenrichtung: Wer in die Zeile tippt, weiß, was er braucht.
    func testTypingClosesTheSurfaceEvenOnAnEmptyList() {
        XCTAssertFalse(SuggestionSurface.isExpanded(
            choice: false, listIsEmpty: true, tourIsRunning: false
        ))
    }

    // MARK: Der Rundgang

    /// Rahmen 2 leuchtet die Kacheln aus. Eine zugeklappte Fläche trägt keinen
    /// Anker, und ein Rahmen ohne Ziel überspringt sich selbst — der Rundgang
    /// ließe ausgerechnet den Tester, der bei Rahmen 1 mitgemacht hat, den
    /// Vorschlags-Rahmen nie sehen. Still, und nur ihn.
    func testTheTourOpensTheSurfaceNoMatterWhatTheListSays() {
        XCTAssertTrue(SuggestionSurface.isExpanded(
            choice: nil, listIsEmpty: false, tourIsRunning: true
        ))
    }

    /// Und auch gegen eine ausdrückliche Wahl — sonst hinge ein Rahmen des
    /// Rundgangs daran, ob jemand vorher einen Knopf gedrückt hat.
    func testTheTourWinsAgainstAClosedSurface() {
        XCTAssertTrue(SuggestionSurface.isExpanded(
            choice: false, listIsEmpty: false, tourIsRunning: true
        ))
    }

    /// Der Rundgang **überschreibt** die Wahl nicht, er übergeht sie nur:
    /// Danach gilt wieder, was der Nutzer eingestellt hatte.
    func testAfterTheTourTheUsersChoiceIsStillTheOneThatCounts() {
        XCTAssertFalse(SuggestionSurface.isExpanded(
            choice: false, listIsEmpty: true, tourIsRunning: false
        ))
    }
}
