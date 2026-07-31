import SwiftUI
import XCTest
@testable import LeChariot

/// **Die eine Regel für Zustandswechsel, als Werte geprüft.**
///
/// Am 31.07. kamen vom Gerät drei Meldungen, die derselbe Fehler sind: Die
/// Onboarding-Seiten springen, der Weg ins Filialwählen hat keinen Übergang,
/// und im Filialwählen blendet der graue Hinweis langsam aus, während der
/// grüne Aufklapper darunter schlagartig erscheint. Gemeinsame Ursache: Die
/// App hatte keine gemeinsame Regel — sechs verschiedene Kurven an vierzehn
/// Stellen, und bei ganzen Bildschirmen gar keine.
///
/// Bewegung selbst kann ein Test nicht sehen. Was er sehen kann, ist die
/// Regel, aus der sie kommt — und die ist hier der ganze Fehler.
final class MotionTests: XCTestCase {
    /// **Eine Familie, zwei Größenordnungen.** Zwei verschiedene Kurven wären
    /// zwei Regeln; genau daraus bestand der gemeldete Zustand. `.snappy` ist
    /// die, die der Rundgang seit PR #21 schon nutzt.
    func testBothKindsUseTheSameCurveFamily() {
        XCTAssertEqual(Theme.Motion.screen.animation, .snappy(duration: 0.3))
        XCTAssertEqual(Theme.Motion.element.animation, .snappy(duration: 0.22))
    }

    /// Ein Bildschirm darf länger brauchen als eine Zeile — beide aber so
    /// kurz, dass der Übergang sich nicht wie Warten anfühlt.
    func testAScreenTakesLongerThanAnElementAndBothStayShort() {
        XCTAssertGreaterThan(Theme.Motion.screen.duration, Theme.Motion.element.duration)
        for motion in Theme.Motion.allCases {
            XCTAssertGreaterThan(motion.duration, 0, "\(motion) bewegt sich gar nicht")
            XCTAssertLessThan(
                motion.duration, 0.5,
                "\(motion) dauert so lange, dass der Übergang zum Warten wird"
            )
        }
    }

    /// **Wer Bewegung abgestellt hat, bekommt keine.**
    ///
    /// `nil` heißt bei SwiftUI „sofort", nicht „Vorgabe": Der Wechsel findet
    /// statt, nur ohne Weg dorthin. Diese Zusicherung ist der Grund, warum die
    /// Regel über `stateAnimation` läuft und nicht über ein `.animation(...)`
    /// von Hand — ein Modifikator sieht `accessibilityReduceMotion`, eine
    /// Konstante nicht.
    func testNothingMovesWhenTheUserTurnedMotionOff() {
        for motion in Theme.Motion.allCases {
            XCTAssertNil(
                motion.animation(reduceMotion: true),
                "\(motion) bewegt sich trotz abgestellter Bewegung"
            )
            XCTAssertEqual(motion.animation(reduceMotion: false), motion.animation)
        }
    }
}
