import XCTest
@testable import LeChariot

/// **Der harte Tab-Wechsel des Rundgangs, als Entscheidung geprüft.**
///
/// Gemeldet von Scott am 03.08.: „Der Übergang zwischen den Tabs ist nur ein
/// Blinzeln." Bewegung selbst kann ein Test nicht sehen — dieselbe Lage wie bei
/// `MotionTests` und `SpotlightTransitionTests`. Was er sehen kann, ist die
/// Regel: **wann** überblendet wird, wie lange, und wann eben nicht.
final class TourTabTransitionTests: XCTestCase {
    /// Der gemeldete Fall: Liste → Einstellungen. Der bekommt einen Plan.
    func testACrossingBetweenTabsIsBlendedOver() {
        XCTAssertEqual(
            TourTabTransition.plan(from: .liste, to: .einstellungen, reduceMotion: false),
            TourTabTransition.standard
        )
    }

    /// Und der neue Weg über die Angebote genauso — es hängt am Wechsel, nicht
    /// an einem bestimmten Paar.
    func testEveryPairOfDifferentTabsIsBlendedOver() {
        let tabs: [TutorialTab] = [.liste, .angebote, .einstellungen]
        for from in tabs {
            for to in tabs where to != from {
                XCTAssertNotNil(
                    TourTabTransition.plan(from: from, to: to, reduceMotion: false),
                    "\(from) → \(to) springt weiterhin hart um"
                )
            }
        }
    }

    /// **Drei von vier Rahmen bleiben, wo sie sind** — nur `settings`
    /// verlässt die Liste, siehe `testOnlyTheLastFrameLeavesTheListTab`.
    /// Für die anderen darf es keinen
    /// Plan geben: Eine Abdunklung, die auf demselben Bildschirm zu- und
    /// wieder aufgeht, ist kein Übergang, sondern ein Blinzeln — genau das
    /// Wort aus der Meldung.
    func testStayingOnTheSameTabIsNotATransition() {
        for tab in [TutorialTab.liste, .angebote, .einstellungen] {
            XCTAssertNil(
                TourTabTransition.plan(from: tab, to: tab, reduceMotion: false),
                "\(tab) blendet über sich selbst"
            )
        }
    }

    /// **Wer Bewegung abgestellt hat, bekommt den ehrlichen Sprung.** Kein
    /// Plan heißt: Der Tab wechselt sofort, ohne Weg dorthin. Dieselbe Regel
    /// wie `Theme.Motion.animation(reduceMotion:)` — und derselbe Grund, sie
    /// als Wert zu prüfen statt als Animation.
    func testNothingIsBlendedWhenTheUserTurnedMotionOff() {
        XCTAssertNil(
            TourTabTransition.plan(from: .liste, to: .einstellungen, reduceMotion: true)
        )
    }

    /// Die Abdunklung muss **zu** sein, bevor der Tab wechselt, und **zu**
    /// bleiben, bis er steht. Wären `fadeIn` oder `hold` null, sähe man genau
    /// den Wechsel, den sie verdecken sollen.
    func testTheVeilIsClosedBeforeAndWhileTheTabChanges() {
        let plan = TourTabTransition.standard
        XCTAssertGreaterThan(plan.fadeIn, 0)
        XCTAssertGreaterThan(plan.hold, 0)
        XCTAssertGreaterThan(plan.fadeOut, 0)
    }

    /// Zusammen unter einer halben Sekunde — dieselbe Grenze, ab der
    /// `MotionTests` einen Übergang „Warten" nennt. Und hinein schneller als
    /// heraus: Der Weg hinein ist ein Verlust, der Weg heraus eine Ankunft.
    func testTheWholeCrossingStaysShorterThanWaitingFeelsLike() {
        let plan = TourTabTransition.standard
        XCTAssertLessThan(plan.total, 0.5)
        XCTAssertLessThan(plan.fadeIn, plan.fadeOut)
    }
}
