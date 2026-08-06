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

/// **Der Startbildschirm und die App-Fläche müssen dieselbe Farbe sein.**
///
/// Am 06.08. gefunden: `INFOPLIST_KEY_UILaunchScreen_Generation` allein erzeugt
/// einen leeren `UILaunchScreen`, und der ist `systemBackground` — reinweiß im
/// hellen, reinschwarz im dunklen Modus. Die App malt danach
/// `Theme.background`. Jeder Kaltstart blitzte also weiß auf.
///
/// Das Farbset `LaunchBackground` trägt jetzt dieselben Werte. Dieser Test
/// hält sie zusammen: Ohne ihn driften die zwei beim nächsten Farbdreh
/// auseinander, und das Blitzen wäre zurück, ohne dass jemand es merkt.
final class LaunchBackgroundTests: XCTestCase {
    func testTheLaunchScreenMatchesTheAppBackground() throws {
        let named = try XCTUnwrap(
            UIColor(named: "LaunchBackground"),
            "Farbset LaunchBackground fehlt — der Startbildschirm blitzt weiß auf"
        )
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let launch = named.resolvedColor(with: traits)
            let app = UIColor(Theme.background).resolvedColor(with: traits)

            var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
            var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
            launch.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
            app.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)

            XCTAssertEqual(lr, ar, accuracy: 0.004, "Rot weicht ab (\(style))")
            XCTAssertEqual(lg, ag, accuracy: 0.004, "Grün weicht ab (\(style))")
            XCTAssertEqual(lb, ab, accuracy: 0.004, "Blau weicht ab (\(style))")
        }
    }
}
