import XCTest
@testable import LeChariot

/// **Die zwei ruckelnden Übergänge, als Entscheidung nachgestellt.**
///
/// Gemeldet am 2026-07-30 am Gerät: Die Wechsel 2→3 und 6→7 ruckeln. Es sind
/// genau die zwei, bei denen sich der Bildschirm unter dem Overlay umbaut —
/// bei 2→3 lässt der gelegte Artikel die Plan-Karte erscheinen, bei 6→7
/// wechselt der Tab. Der Anker des neuen Rahmens wird dadurch erst einen
/// Layout-Durchgang später gemeldet.
///
/// Was ein Test hier prüfen kann, ist nicht die Bewegung, sondern die
/// Entscheidung darüber — und die ist der ganze Fehler.
final class SpotlightTransitionTests: XCTestCase {
    private let alt = CGRect(x: 10, y: 20, width: 100, height: 44)
    private let neu = CGRect(x: 10, y: 300, width: 200, height: 60)

    /// **Der gemeldete Fall, in zwei Schritten.**
    ///
    /// Erst wechselt der Schritt, und es gibt noch keinen Anker: Nichts
    /// passiert, das alte Loch bleibt liegen. Dann trifft der Anker ein, und
    /// **jetzt** wird geflogen — einmal, vom alten Ziel zum neuen.
    ///
    /// Vorher lief dieselbe Folge über `.zero`: Das Loch schrumpfte in die
    /// Ecke und sprang von dort aus an seinen Platz.
    func testTheHoleWaitsForTheAnchorAndThenFliesOnce() {
        let warten = SpotlightTransition.move(
            shown: alt, shownIndex: 1, resolved: nil, index: 2
        )
        XCTAssertNil(warten, "Ohne Anker darf sich das Loch nicht bewegen")

        let flug = SpotlightTransition.move(
            shown: alt, shownIndex: 1, resolved: neu, index: 2
        )
        XCTAssertEqual(flug, .init(rect: neu, animated: true))
    }

    /// Kommt der Anker rechtzeitig, ist es derselbe eine Flug — der schnelle
    /// Fall darf sich nicht anders verhalten als der langsame.
    func testAStepChangeWithTheAnchorAlreadyThereIsTheSameSingleFlight() {
        XCTAssertEqual(
            SpotlightTransition.move(shown: alt, shownIndex: 1, resolved: neu, index: 2),
            .init(rect: neu, animated: true)
        )
    }

    /// Dasselbe Ziel, nur verschoben — Tastatur, Scrollen, ein Umbau unter dem
    /// Loch. Das springt sofort mit und wird **nicht** geflogen, sonst schwimmt
    /// das Loch dem Finger hinterher. Genau dafür stand die Animation
    /// ursprünglich am Schrittindex.
    func testTheSameTargetMovingIsFollowedInstantly() {
        XCTAssertEqual(
            SpotlightTransition.move(shown: alt, shownIndex: 2, resolved: neu, index: 2),
            .init(rect: neu, animated: false)
        )
    }

    /// Nichts geändert, nichts zu tun — sonst setzte jeder `body`-Durchgang
    /// denselben Wert neu und stieße eine Animation an.
    func testNothingToDoWhenTheRectIsUnchanged() {
        XCTAssertNil(
            SpotlightTransition.move(shown: alt, shownIndex: 2, resolved: alt, index: 2)
        )
    }

    /// Ein Anker, der wieder verschwindet, lässt das Loch stehen, statt es
    /// einzuklappen. Der Rundgang überspringt solche Rahmen ohnehin nach der
    /// Schonfrist — bis dahin soll er nicht flackern.
    func testAnAnchorThatGoesAwayAgainLeavesTheHoleWhereItIs() {
        XCTAssertNil(
            SpotlightTransition.move(shown: alt, shownIndex: 2, resolved: nil, index: 2)
        )
    }

    /// Der allererste Rahmen wird **nicht** geflogen: Beim Erscheinen des
    /// Overlays gibt es kein voriges Loch, und eins, das aus der linken oberen
    /// Ecke aufzieht, wäre schlechter als eins, das einfach da ist. So war es
    /// vorher auch — diese Korrektur soll den Anfang nicht mitverändern.
    func testTheVeryFirstFrameIsNotFlownIn() {
        XCTAssertEqual(
            SpotlightTransition.move(shown: .zero, shownIndex: -1, resolved: neu, index: 0),
            .init(rect: neu, animated: false)
        )
    }

    /// Und ab dem zweiten Rahmen wird geflogen — sonst hätte die Zeile oben
    /// versehentlich alle Übergänge stillgelegt.
    func testFromTheSecondFrameOnwardsItIsFlownAgain() {
        XCTAssertEqual(
            SpotlightTransition.move(shown: alt, shownIndex: 0, resolved: neu, index: 1),
            .init(rect: neu, animated: true)
        )
    }
}
