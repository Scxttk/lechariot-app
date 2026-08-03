import Foundation

/// Wie der Rundgang den Tab wechselt — **die Entscheidung, nicht die Bewegung.**
///
/// Gemeldet von Scott am 03.08.: „Beim Wechsel von Tab zu Tab springt es hart
/// um; gewünscht ist ein weicher Übergang." Und so war es auch gebaut: Der
/// Rahmenwechsel setzte `selectedTab` in derselben Zeile, in der er den Schritt
/// erhöhte. Eine `TabView` blendet ihren Inhalt nicht über — sie tauscht ihn
/// aus. Unter der Abdunklung des Rundgangs wechselte damit der ganze
/// Bildschirm in einem einzigen Bild, während das Loch noch auf dem alten Ziel
/// lag.
///
/// **Warum durch die Abdunklung und nicht mit `matchedGeometryEffect`.** Der
/// naheliegende Weg wäre, das Loch von einem Ziel zum anderen wandern zu
/// lassen. Das tut es bereits (`SpotlightTransition`) — nur nützt es nichts,
/// solange darunter der Bildschirm springt: Man sieht nicht die Hervorhebung
/// reisen, man sieht den Inhalt umschlagen. `matchedGeometryEffect` bräuchte
/// zudem beide Ziele gleichzeitig im Baum, und genau das gibt eine `TabView`
/// nicht her — der alte Tab ist abgebaut, bevor der neue steht.
///
/// Also die andere Hälfte: Die Abdunklung, die ohnehin über allem liegt,
/// schließt sich kurz ganz und öffnet sich wieder. Der Inhaltswechsel und der
/// Sprung des Lochs passieren dahinter; was man sieht, ist ein Überblenden.
/// Ein Bauteil weniger als eine zweite Animationsebene, und es kann per
/// Bauart nichts Bedienbares doppelt stehen lassen.
///
/// **Reduce Motion bekommt die ehrliche Fassung:** kein Plan, kein Überblenden,
/// der Tab wechselt sofort. Dieselbe Regel wie in `Theme.Motion` — „`nil` heißt
/// bei SwiftUI sofort, nicht Vorgabe".
enum TourTabTransition {
    /// Die drei Abschnitte des Überblendens, in Sekunden.
    struct Plan: Equatable {
        /// Die Abdunklung schließt sich.
        let fadeIn: Double
        /// Sie bleibt zu, während der Tab wechselt und sein Layout einmal
        /// durchläuft. Ohne diese Pause stünde der neue Bildschirm im Moment
        /// des Aufblendens noch nicht — man sähe ihn sich aufbauen, und das
        /// ist ein hässlicherer Ruckler als der, den wir ersetzen.
        let hold: Double
        /// Sie öffnet sich wieder auf die normale Deckkraft des Rundgangs.
        let fadeOut: Double

        var total: Double { fadeIn + hold + fadeOut }
    }

    /// Aufblenden schneller als abblenden: Der Weg hinein ist ein Verlust
    /// (der Bildschirm, den man gerade gelesen hat), der Weg heraus eine
    /// Ankunft. Zusammen unter einer halben Sekunde — ab da wird ein Übergang
    /// zum Warten, dieselbe Grenze wie in `Theme.Motion`.
    static let standard = Plan(fadeIn: 0.15, hold: 0.10, fadeOut: 0.20)

    /// - Returns: `nil`, wenn nicht überblendet wird — weil der Rahmen auf
    ///   demselben Tab bleibt (dann gibt es nichts zu verdecken) oder weil der
    ///   Nutzer Bewegung abgestellt hat.
    static func plan(from: TutorialTab, to: TutorialTab, reduceMotion: Bool) -> Plan? {
        guard from != to, !reduceMotion else { return nil }
        return standard
    }
}
