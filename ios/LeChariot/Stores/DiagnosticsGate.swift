import Foundation
import Observation

/// **Der Schalter, den nur Scott findet.**
///
/// Entschieden am 02.08.: Das Werkzeug soll **in Scotts Build** sein, aber
/// nicht für die Tester. Von den zwei Wegen — versteckte Geste im selben Build
/// oder getrennte TestFlight-Gruppen — ist die Geste gewählt: **Ein zweiter
/// Build ist ein zweiter Build**, der eigene Nummern, eigene Uploads und einen
/// eigenen Verarbeitungsstand hat, und ausgerechnet die Frage „ruckelt es auf
/// dem Gerät" will man an *dem* Bauwerk messen, das die Tester haben, nicht an
/// einem Geschwisterbau.
///
/// **Die Geste:** langer Druck auf die Zeile „Version" in den Einstellungen.
/// Sie ist bewusst dort — die Zeile ist überall gleich, sie steht am Ende der
/// Liste, und ein langer Druck auf eine Zeile ohne Knopf tut sonst nichts.
///
/// **Was ein Tester davon merkt: nichts.** Ohne die Geste gibt es keine Zeile,
/// keinen Bildschirm und keinen `CADisplayLink` — das HUD wird gar nicht erst
/// gebaut, nicht nur versteckt. Was **immer** läuft, ist MetricKit
/// (`MetricsCollector`), und das kostet nichts: Apple liefert einmal am Tag ein
/// Paket, niemand fragt.
@MainActor
@Observable
final class DiagnosticsGate {
    private static let revealedKey = "diagnostics.revealed"
    private static let hudKey = "diagnostics.hud"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppDefaults.shared) {
        self.defaults = defaults
        isRevealed = defaults.bool(forKey: Self.revealedKey)
        isHUDVisible = defaults.bool(forKey: Self.hudKey)
    }

    /// Ist der Diagnose-Eintrag sichtbar? Bleibt es, bis jemand ihn wieder
    /// versteckt — die Geste jedes Mal zu brauchen wäre Schikane für den
    /// Einzigen, der sie kennt.
    private(set) var isRevealed: Bool {
        didSet { defaults.set(isRevealed, forKey: Self.revealedKey) }
    }

    /// **Aus, bis jemand es anschaltet** — und getrennt vom Sichtbarmachen:
    /// Der Tagesbericht ist auch ohne Overlay etwas wert, und ein Overlay, das
    /// mit dem Bildschirm angeht, verdeckt genau das, was man ansehen wollte.
    var isHUDVisible: Bool {
        didSet { defaults.set(isHUDVisible, forKey: Self.hudKey) }
    }

    func reveal() { isRevealed = true }

    /// Wieder verstecken schaltet das Overlay mit ab — sonst bliebe eine
    /// Anzeige stehen, deren Schalter nicht mehr erreichbar ist.
    func hide() {
        isRevealed = false
        isHUDVisible = false
    }

    /// Für `AppReset.everything()`.
    func resetAllData() {
        hide()
    }
}
