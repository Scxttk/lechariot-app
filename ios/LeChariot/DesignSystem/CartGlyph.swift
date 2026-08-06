import SwiftUI

/// **Der Einkaufswagen des App-Icons, in der App gezeichnet.**
///
/// Dieselbe Geometrie wie `tools/icon.swift` — und das ist der Punkt: Was auf
/// dem Homescreen steht, soll beim Öffnen weiterlaufen und nicht durch etwas
/// Ähnliches ersetzt werden.
///
/// **Die Falle beim Übertragen, und sie sieht *fast* richtig aus:** Das Raster
/// des Werkzeugs hat den Ursprung **unten links** (`y` nach oben, AppKit),
/// SwiftUI hat ihn oben links. Jede Konstante ist hier deshalb `1 − y` des
/// Werkzeugs. Wer die Zahlen abschreibt, bekommt einen Wagen auf dem Kopf, und
/// der wirkt beim flüchtigen Hinsehen nur „etwas seltsam".
///
/// **Was bewusst nicht mitkommt:** die Verläufe, Schatten und der Feldschnitt
/// durch die Strebenschlitze aus dem Icon. Das sind CoreGraphics-Operationen am
/// Kontext, kein Pfad; sie nachzubauen wäre eine Neufassung, keine Übernahme.
/// In der App ist der Wagen eine **Strichzeichnung** — dieselbe Hand wie
/// `CategoryGlyph` und `AppGlyph`. Bei 116 pt trägt eine Monolinie; ein
/// verkleinertes Icon wird an derselben Stelle ein Fleck.
enum CartGeometry {
    // y zeigt nach UNTEN. Werkzeugwert 0,92 → hier 0,08.
    static let handleEnd = CGPoint(x: 0.00, y: 0.08)
    static let handleElbow = CGPoint(x: 0.10, y: 0.08)

    /// Der Korb ist ein Keil, kein Trapez: hinten am Griff tief, nach vorn
    /// flacher. Das ist an einem echten Einkaufswagen so — deshalb lassen sie
    /// sich ineinanderschieben — und der eine beobachtete Zug, den ein
    /// Piktogramm nicht hat.
    static let topLeft = CGPoint(x: 0.24, y: 0.36)
    static let topRight = CGPoint(x: 1.00, y: 0.385)
    static let bottomRight = CGPoint(x: 0.87, y: 0.665)
    static let bottomLeft = CGPoint(x: 0.36, y: 0.70)

    static let wheelY: CGFloat = 0.865
    static let wheelXs: [CGFloat] = [0.48, 0.80]
    static let wheelR: CGFloat = 0.088

    static let strutTs: [CGFloat] = [0.30, 0.52, 0.74]
}

/// Der Wagen als Pfad.
///
/// **Die Reihenfolge der Teile ist die Choreografie, kein Zufall.** `.trim`
/// läuft die Teilpfade der Reihe nach ab; gezeichnet wird deshalb von dort, wo
/// die Hand herkommt: erst der Griff, dann der Korb, dann die Streben, zuletzt
/// die Räder — die Reihenfolge, in der auch ein Mensch ihn zeichnen würde.
struct CartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let box = CGRect(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2,
            width: side, height: side
        )
        func p(_ point: CGPoint) -> CGPoint {
            CGPoint(x: box.minX + point.x * box.width, y: box.minY + point.y * box.height)
        }
        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }

        var path = Path()

        // Griff
        path.move(to: p(CartGeometry.handleEnd))
        path.addLine(to: p(CartGeometry.handleElbow))
        path.addLine(to: p(CartGeometry.topLeft))

        // Korb
        path.move(to: p(CartGeometry.topLeft))
        path.addLine(to: p(CartGeometry.topRight))
        path.addLine(to: p(CartGeometry.bottomRight))
        path.addLine(to: p(CartGeometry.bottomLeft))
        path.closeSubpath()

        // Streben — dieselben drei Anteile wie die Schlitze im Icon.
        for t in CartGeometry.strutTs {
            let top = lerp(CartGeometry.topLeft, CartGeometry.topRight, t)
            let bottom = lerp(CartGeometry.bottomLeft, CartGeometry.bottomRight, t)
            path.move(to: p(top))
            path.addLine(to: p(bottom))
        }

        // Räder
        for x in CartGeometry.wheelXs {
            let centre = p(CGPoint(x: x, y: CartGeometry.wheelY))
            let r = CartGeometry.wheelR * box.width
            path.addEllipse(in: CGRect(
                x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2
            ))
        }

        return path
    }
}

#Preview {
    CartShape()
        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
        .frame(width: 160, height: 160)
        .padding()
        .background(Theme.background)
}
