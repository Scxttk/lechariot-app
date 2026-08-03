import XCTest
@testable import LeChariot

/// **Die Regeln des Tipp-Flusses, ohne Bildschirm.**
///
/// Sie sind alle unsichtbar, wenn man auf die App sieht: Welcher Artikel hat
/// nach dem dritten Wort seine Angaben unten? Wandert die Kachelzeile, wenn
/// man in ihr blättert? Was zeigt das Panel, wenn der aktive Artikel gelöscht
/// wird? Eine Journey bräuchte für jede dieser Fragen eine halbe Minute
/// Simulator; hier sind es Millisekunden.
final class AddFlowStateTests: XCTestCase {
    private let a = UUID()
    private let b = UUID()
    private let c = UUID()

    /// **Der gemeldete Fall in Zahlen:** Drei Artikel hintereinander, und das
    /// Panel gehört immer dem letzten. Genau das konnte die alte Fassung
    /// nicht — dort stand nach dem ersten ein Blatt, das erst weg musste.
    func testThreeInARowLeaveTheLastOneActive() {
        var flow = AddFlowState()
        flow.added(a)
        flow.added(b)
        flow.added(c)

        XCTAssertEqual(flow.activeID, c)
        XCTAssertEqual(flow.recent, [a, b, c], "Die Zeile zeigt sie in Anlege-Reihenfolge")
    }

    /// Eine Kachel antippen wechselt den Blick — und **nur** den. Würde der
    /// angetippte Artikel dabei ans Ende rücken, wanderte die Kachel unter dem
    /// Finger davon; dieselbe Regel wie beim Wörterbuch-Streifen.
    func testFocusingAnOlderItemDoesNotReorderTheRow() {
        var flow = AddFlowState()
        flow.added(a)
        flow.added(b)
        flow.added(c)

        flow.focus(a)

        XCTAssertEqual(flow.activeID, a)
        XCTAssertEqual(flow.recent, [a, b, c])
    }

    /// Ein Artikel, den die Zeile nicht trägt, kann auch nicht angetippt
    /// worden sein. Ohne diese Sperre könnte ein veralteter Aufruf das Panel
    /// auf etwas setzen, das gar nicht dasteht.
    func testFocusingSomethingOutsideTheRowIsIgnored() {
        var flow = AddFlowState()
        flow.added(a)

        flow.focus(b)

        XCTAssertEqual(flow.activeID, a)
    }

    /// Derselbe Artikel zweimal (Kachel antippen, was schon auf der Liste
    /// steht) darf die Zeile nicht verdoppeln.
    func testAddingTheSameItemTwiceKeepsOneTile() {
        var flow = AddFlowState()
        flow.added(a)
        flow.added(b)
        flow.added(a)

        XCTAssertEqual(flow.recent, [b, a])
        XCTAssertEqual(flow.activeID, a)
    }

    /// Die Zeile ist gedeckelt — sonst schiebt eine lange Liste ihre eigenen
    /// ersten Artikel endlos vor sich her.
    func testTheRowKeepsOnlyTheYoungestFew() {
        var flow = AddFlowState()
        let ids = (0..<(AddFlowState.recentLimit + 3)).map { _ in UUID() }
        for id in ids { flow.added(id) }

        XCTAssertEqual(flow.recent.count, AddFlowState.recentLimit)
        XCTAssertEqual(flow.recent, Array(ids.suffix(AddFlowState.recentLimit)))
        XCTAssertEqual(flow.activeID, ids.last)
    }

    /// Die Tastatur geht — der Fluss ist vorbei. Bei Bring! tut „Abbrechen"
    /// genau das: Es beendet das Tippen insgesamt.
    func testTheFlowEndsCompletely() {
        var flow = AddFlowState()
        flow.added(a)
        flow.added(b)

        flow.end()

        XCTAssertFalse(flow.isActive)
        XCTAssertTrue(flow.recent.isEmpty)
    }

    /// **Der gelöschte aktive Artikel.** Das Panel darf nicht auf eine Zeile
    /// zeigen, die es nicht mehr gibt — der Blick fällt auf den
    /// nächstjüngeren, nicht ins Leere.
    func testDeletingTheActiveItemFallsBackToTheOneBefore() {
        var flow = AddFlowState()
        flow.added(a)
        flow.added(b)

        flow.keepOnly([a])

        XCTAssertEqual(flow.activeID, a)
        XCTAssertEqual(flow.recent, [a])
    }

    /// Ist alles weg (Liste geleert), ist auch der Fluss weg — und nicht etwa
    /// ein Panel ohne Artikel.
    func testClearingTheListEndsTheFlow() {
        var flow = AddFlowState()
        flow.added(a)
        flow.added(b)

        flow.keepOnly([])

        XCTAssertFalse(flow.isActive)
        XCTAssertTrue(flow.recent.isEmpty)
    }

    /// Ein gelöschter **anderer** Artikel lässt den aktiven in Ruhe.
    func testDeletingSomeoneElseLeavesTheActiveItemAlone() {
        var flow = AddFlowState()
        flow.added(a)
        flow.added(b)

        flow.keepOnly([b])

        XCTAssertEqual(flow.activeID, b)
        XCTAssertEqual(flow.recent, [b])
    }
}
