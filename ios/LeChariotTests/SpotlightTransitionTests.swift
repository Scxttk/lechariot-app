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

    // MARK: Der Nachzügler (03.08.)

    /// **Der zweite Sprung im Wechsel 7→8, in drei Aufrufen nachgestellt.**
    ///
    /// Der Rahmen der Einstellungen hebt zwei Ziele zugleich hervor
    /// (`.union(.settingsMarkets, .settingsHelp)`). Die beiden Anker kommen
    /// nicht zwingend im selben Layout-Durchgang — beim Tab-Wechsel schon gar
    /// nicht. Der erste löst den Flug aus, `shownIndex` steht danach auf dem
    /// neuen Schritt; der zweite fällt damit in den Zweig „dasselbe Ziel
    /// verschiebt sich" und **sprang**. Das Loch wuchs schlagartig von den
    /// Filialen auf Filialen-plus-Hilfe: das gemeldete Blinzeln, nur eben
    /// hinter dem Tab-Wechsel und deshalb bisher ihm zugeschrieben.
    func testALateSecondAnchorOfTheSameFrameIsStillFlown() {
        let teil = CGRect(x: 10, y: 300, width: 200, height: 40)
        let ganz = teil.union(CGRect(x: 10, y: 360, width: 200, height: 40))

        let ersterAnker = SpotlightTransition.move(
            shown: alt, shownIndex: 6, resolved: teil, index: 7, settling: true
        )
        XCTAssertEqual(ersterAnker, .init(rect: teil, animated: true))

        let nachzuegler = SpotlightTransition.move(
            shown: teil, shownIndex: 7, resolved: ganz, index: 7, settling: true
        )
        XCTAssertEqual(
            nachzuegler, .init(rect: ganz, animated: true),
            "Der zweite Anker desselben Rahmens gehört noch zum Wechsel"
        )
    }

    /// **Die Gegenrichtung, und sie ist die eigentliche Sperre.** Nach dem
    /// Einschwing-Fenster gilt die alte Regel unverändert: Tastatur, Scrollen
    /// und Umbauten unter dem Loch werden sofort mitgenommen, nicht geflogen —
    /// sonst schwimmt das Loch dem Finger hinterher. Das ist genau der Zustand,
    /// den `testTheSameTargetMovingIsFollowedInstantly` seit dem 31.07. hält;
    /// hier steht er noch einmal ausdrücklich mit dem neuen Schalter.
    func testOnceSettledTheSameTargetStillFollowsInstantly() {
        XCTAssertEqual(
            SpotlightTransition.move(
                shown: alt, shownIndex: 2, resolved: neu, index: 2, settling: false
            ),
            .init(rect: neu, animated: false)
        )
    }

    /// Der Standardwert ist der ruhige Fall. Ein Aufrufer, der das Fenster
    /// nicht kennt, darf nicht versehentlich alles fliegen lassen.
    func testTheQuietCaseIsTheDefault() {
        XCTAssertEqual(
            SpotlightTransition.move(shown: alt, shownIndex: 2, resolved: neu, index: 2),
            SpotlightTransition.move(
                shown: alt, shownIndex: 2, resolved: neu, index: 2, settling: false
            )
        )
    }
}
