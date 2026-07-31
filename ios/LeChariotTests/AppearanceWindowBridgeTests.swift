import XCTest
import UIKit
@testable import LeChariot

/// **Der Dark-Frame beim Kaltstart.**
///
/// Gemeldet am 2026-07-30: System dunkel, App auf „Hell" gestellt — beim
/// Start stand rund eine Sekunde lang das falsche Erscheinungsbild da, dann
/// schlug es um.
///
/// Die Ursache ist keine Animation und kein Ladevorgang, sondern ein
/// Fehlschlag ohne Nachreichen. Der alte Code stellte den Stil in einem
/// `DispatchQueue.main.async`-Block ein und stieg mit
/// `guard let window = view.window else { return }` aus, wenn es noch kein
/// Fenster gab. Beim Kaltstart gibt es dort keins — der Block fiel also
/// wirkungslos durch, **und niemand versuchte es erneut**. Eingestellt wurde
/// erst beim nächsten SwiftUI-Durchgang, also wenn irgendwo Inhalte nachluden.
/// Genau das war die knappe Sekunde.
///
/// Diese Tests messen deshalb den **Zeitpunkt**, nicht nur das Ergebnis: Sie
/// prüfen unmittelbar nach dem Einhängen, ohne den Runloop einmal drehen zu
/// lassen. Mit dem alten `async`-Weg wäre das Fenster dort noch unverändert.
@MainActor
final class AppearanceWindowBridgeTests: XCTestCase {
    private func fenster() -> UIWindow {
        UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    }

    /// Der gemeldete Fall: Die Wahl steht schon fest, bevor es ein Fenster
    /// gibt. Sie muss in dem Moment greifen, in dem eines da ist.
    func testTheChoiceIsOnTheWindowTheMomentTheViewIsAttached() {
        let window = fenster()
        XCTAssertEqual(
            window.overrideUserInterfaceStyle, .unspecified,
            "Vorbedingung: ein frisches Fenster folgt dem System"
        )

        let probe = AppearanceProbeView()
        probe.style = .light
        window.addSubview(probe)

        // Kein `await`, kein Runloop-Durchgang, keine Erwartung: Genau hier lag
        // die Sekunde.
        XCTAssertEqual(
            window.overrideUserInterfaceStyle, .light,
            "Der Stil muss beim Einhängen sitzen, nicht einen Durchgang später"
        )
    }

    /// Die Reihenfolge andersherum — erst einhängen, dann wählen. Das ist der
    /// Weg über Einstellungen → Darstellung.
    func testAChoiceMadeLaterReachesTheWindowToo() {
        let window = fenster()
        let probe = AppearanceProbeView()
        window.addSubview(probe)
        XCTAssertEqual(window.overrideUserInterfaceStyle, .unspecified)

        probe.style = .dark
        XCTAssertEqual(window.overrideUserInterfaceStyle, .dark)

        probe.style = .light
        XCTAssertEqual(window.overrideUserInterfaceStyle, .light)
    }

    /// „System" erzwingt nichts — es nimmt eine gesetzte Wahl auch wieder
    /// zurück. Ohne diesen Weg bliebe die App auf der zuletzt gewählten Seite
    /// stehen, obwohl der Nutzer sie gerade freigegeben hat.
    func testSystemGivesTheWindowBackToTheSystem() {
        let window = fenster()
        let probe = AppearanceProbeView()
        probe.style = .dark
        window.addSubview(probe)
        XCTAssertEqual(window.overrideUserInterfaceStyle, .dark)

        probe.style = .unspecified
        XCTAssertEqual(window.overrideUserInterfaceStyle, .unspecified)
    }

    /// Ohne Fenster passiert nichts und stürzt nichts ab — die Ansicht wird
    /// von SwiftUI gebaut, bevor sie irgendwo hängt.
    func testWithoutAWindowNothingHappens() {
        let probe = AppearanceProbeView()
        probe.style = .dark
        XCTAssertNil(probe.window)
    }

    /// Die Wahl in den Einstellungen wird überblendet, der Start nicht: Beim
    /// Kaltstart gibt es nichts, wovon überzublenden wäre, und eine
    /// Überblendung sähe dort wie ein Fehler aus.
    ///
    /// Geprüft wird das Ergebnis, nicht die Animation — aber wenn die
    /// Unterscheidung eines Tages verloren geht, ist ein Kaltstart mit
    /// laufender `UIView.transition` der wahrscheinliche Weg dorthin, und dann
    /// steht der Wert nach dem Einhängen nicht sofort.
    func testTheVeryFirstApplicationIsImmediateAndNotFadedIn() {
        let window = fenster()
        let probe = AppearanceProbeView()
        probe.style = .dark
        window.addSubview(probe)
        XCTAssertEqual(
            window.overrideUserInterfaceStyle, .dark,
            "Die erste Anwendung darf nicht in einer Überblendung hängen"
        )
    }

    /// Die Zuordnung Auswahl → UIKit-Stil, damit die Tests oben nicht die
    /// einzige Stelle sind, an der sie steht.
    func testEveryAppearanceMapsToTheStyleItPromises() {
        XCTAssertEqual(AppAppearance.system.interfaceStyle, .unspecified)
        XCTAssertEqual(AppAppearance.light.interfaceStyle, .light)
        XCTAssertEqual(AppAppearance.dark.interfaceStyle, .dark)
    }
}
