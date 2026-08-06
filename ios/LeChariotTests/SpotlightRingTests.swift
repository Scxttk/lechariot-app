import SwiftUI
import XCTest
@testable import LeChariot

/// **Die Hervorhebung des Rundgangs, als Kante und als Kontrast.**
///
/// Gemeldet am 31.07. vom Gerät: „oft nicht erkenntlich, was gemeint ist".
/// Die Hervorhebung bestand bis dahin allein aus der Aussparung in der
/// Abdunklung — ein weicher Sprung von 60 % Schwarz auf 0 %, den man auf
/// kleinen Zielen (Eingabezeile, Tab-Leiste) schlicht übersieht. Dazu kommt
/// eine Linie auf der Kante, und deren Farbe muss gegen die Abdunklung
/// bestehen.
///
/// Der naheliegende Griff wäre `Theme.accent` gewesen. Genau der wäre der
/// gemeldete Fehler in neuer Form: Im hellen Modus ist der Akzent das dunkle
/// `#3F6444`, und dunkles Grün auf abgedunkeltem Grund ist keine
/// Hervorhebung. Der Test rechnet nach statt zu glauben.
final class SpotlightRingTests: XCTestCase {
    private let hole = CGRect(x: 20, y: 100, width: 300, height: 48)

    // MARK: Die Kante

    func testTheRingSitsExactlyOnTheHole() {
        let path = SpotlightRing(hole: hole, cornerRadius: Theme.Radius.card)
            .path(in: CGRect(x: 0, y: 0, width: 400, height: 800))
        XCTAssertFalse(path.isEmpty)
        // Runde Ecken lassen den Rahmen minimal wachsen; auf einen halben
        // Punkt genau ist die Kante die des Lochs.
        XCTAssertEqual(path.boundingRect.minX, hole.minX, accuracy: 0.5)
        XCTAssertEqual(path.boundingRect.minY, hole.minY, accuracy: 0.5)
        XCTAssertEqual(path.boundingRect.width, hole.width, accuracy: 0.5)
        XCTAssertEqual(path.boundingRect.height, hole.height, accuracy: 0.5)
    }

    /// Kein Loch heißt: keine Kante. Ohne diese Grenze stünde bei den Rahmen
    /// ohne Anker — und bei laufendem VoiceOver, wo das Loch bewusst zu ist —
    /// ein Strich um nichts in der linken oberen Ecke. Genau die Erscheinung,
    /// die `SpotlightTransition` in PR #21 abgeräumt hat.
    func testAClosedSpotlightDrawsNoRing() {
        for empty in [CGRect.zero, CGRect(x: 5, y: 5, width: 0.2, height: 40)] {
            let path = SpotlightRing(hole: empty, cornerRadius: Theme.Radius.card)
                .path(in: CGRect(x: 0, y: 0, width: 400, height: 800))
            XCTAssertTrue(path.isEmpty, "\(empty) hat eine Kante bekommen")
        }
    }

    /// Linie und Aussparung fliegen denselben Weg — sonst löst sich der Rand
    /// beim Schrittwechsel von seinem Loch.
    func testRingAndHoleInterpolateTogether() {
        var ring = SpotlightRing(hole: hole, cornerRadius: Theme.Radius.card)
        var shape = SpotlightShape(hole: hole, cornerRadius: Theme.Radius.card)
        let target = CGRect(x: 60, y: 400, width: 120, height: 90)
        let data = SpotlightShape(hole: target, cornerRadius: Theme.Radius.card).animatableData
        ring.animatableData = data
        shape.animatableData = data
        XCTAssertEqual(ring.hole, target)
        XCTAssertEqual(shape.hole, target)
    }

    // MARK: Der Kontrast

    /// **3:1 gegen die Abdunklung, in beiden Erscheinungsbildern.**
    ///
    /// WCAG 2.1 verlangt für bedeutungstragende Grafik 3:1. Gemessen wird
    /// gegen die Abdunklung so, wie sie auf dem Bildschirm steht: 60 % Schwarz
    /// über dem App-Hintergrund. Die 78 % des Modus „Transparenz reduzieren"
    /// sind dunkler und damit der freundlichere Fall — geprüft wird der enge.
    func testTheRingContrastsWithTheScrimInBothAppearances() {
        let cases: [(name: String, background: (r: Double, g: Double, b: Double))] = [
            ("hell (Creme)", (0.890, 0.871, 0.722)),
            ("dunkel (Oliv)", (0.082, 0.098, 0.059)),
        ]
        for item in cases {
            let scrim = dimmed(item.background, by: 0.6)
            let ratio = contrast(rgb(Theme.onScrim), scrim)
            XCTAssertGreaterThan(
                ratio, 3,
                "Die Linie erreicht auf \(item.name) nur \(String(format: "%.2f", ratio)):1 "
                + "gegen die Abdunklung — dann ist wieder nicht erkenntlich, was gemeint ist"
            )
        }
    }

    /// **Die Gegenprobe zur Farbwahl, und der eigentliche Fund.**
    ///
    /// Der Akzent ist der Griff, der ohne Messung naheliegt. Über der
    /// abgedunkelten Creme-Fläche misst er **1,01:1** — die beiden Farben sind
    /// dort praktisch gleich hell, eine Linie in Akzentgrün wäre unsichtbar
    /// gewesen. Ohne diesen Test wäre `Theme.onScrim` eine Behauptung.
    func testTheAccentWouldNotHaveBeenEnough() {
        let cream = dimmed((0.890, 0.871, 0.722), by: 0.6)
        let lightAccent = (r: 0.145, g: 0.310, b: 0.176)
        XCTAssertLessThan(
            contrast(lightAccent, cream), 1.5,
            "Der helle Akzent besteht plötzlich gegen die Abdunklung — dann ist "
            + "die Begründung für Theme.onScrim hinfällig"
        )
    }

    // MARK: Rechnen

    private func rgb(_ color: Color) -> (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    /// Schwarz mit `opacity` über einer Farbe — genau das, was der Scrim tut.
    private func dimmed(
        _ color: (r: Double, g: Double, b: Double), by opacity: Double
    ) -> (r: Double, g: Double, b: Double) {
        (color.r * (1 - opacity), color.g * (1 - opacity), color.b * (1 - opacity))
    }

    private func luminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
        func channel(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }

    private func contrast(
        _ a: (r: Double, g: Double, b: Double), _ b: (r: Double, g: Double, b: Double)
    ) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
