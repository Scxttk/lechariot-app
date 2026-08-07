import SwiftUI

/// **Der Wagen wird zur Liste — eine echte Formwandlung.**
///
/// Scott, 06.08.: „i want a start animation where the logo morphs and
/// everything." Der erste Wurf hat den Wagen mit `.trim` *gezeichnet*; das ist
/// ein Aufziehen, keine Wandlung. Hier wandelt er sich wirklich: Dieselben
/// Punkte wandern von der einen Form in die andere, und dazwischen gibt es
/// jeden Zwischenschritt.
///
/// **Warum das überhaupt geht, und warum es nur so geht.** Eine Formwandlung
/// braucht auf beiden Seiten **dieselbe Zahl von Teilen in derselben
/// Reihenfolge** — sonst hat der Rechner nichts zu verbinden und blendet
/// stattdessen über. Deshalb ist das Ziel nicht irgendein Symbol, sondern die
/// **Listenmarke der App selbst**, und die Zuordnung ist von Hand gelegt:
///
/// | Wagen | wird zu | Liste |
/// |---|---|---|
/// | linkes Rad | → | oberer Kreis (das abgehakte Kästchen) |
/// | rechtes Rad | → | unterer Kreis |
/// | erste Strebe | → | obere Zeile |
/// | dritte Strebe | → | untere Zeile |
/// | Korb + Griff + mittlere Strebe | verblassen | — |
///
/// Der Wagen fährt also nicht weg und die Liste blendet auf; **die Räder werden
/// zu den Kästchen und zwei Streben zu den Zeilen.** Das ist der Satz, den die
/// Bewegung erzählt: Was du einkaufst, steht auf der Liste.
///
/// `animatableData` ist der Fortschritt selbst — damit interpoliert SwiftUI die
/// Form Bild für Bild, statt zwei fertige Formen zu kreuzblenden.
struct CartToListShape: Shape {
    /// 0 = Wagen, 1 = Listenmarke.
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    // MARK: Die Listenmarke, im selben Einheitsquadrat wie der Wagen

    /// Zwei Kästchen links, zwei Zeilen rechts — dieselbe Marke, die die
    /// Tab-Leiste trägt, hier als Punkte statt als Systemsymbol.
    private enum ListMark {
        static let circleXs: CGFloat = 0.20
        static let circleYs: [CGFloat] = [0.33, 0.67]
        static let circleR: CGFloat = 0.10

        static let lineStartX: CGFloat = 0.44
        static let lineEndX: CGFloat = 0.90
    }

    func path(in rect: CGRect) -> Path {
        let t = min(max(progress, 0), 1)
        let side = min(rect.width, rect.height)
        let box = CGRect(
            x: rect.midX - side / 2, y: rect.midY - side / 2,
            width: side, height: side
        )
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: box.minX + x * box.width, y: box.minY + y * box.height)
        }
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * t }
        func mixPoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: mix(a.x, b.x), y: mix(a.y, b.y))
        }
        func lerp(_ a: CGPoint, _ b: CGPoint, _ f: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
        }

        var path = Path()

        // 1. Die zwei Räder werden zu den zwei Kästchen.
        for (index, wheelX) in CartGeometry.wheelXs.enumerated() {
            let from = CGPoint(x: wheelX, y: CartGeometry.wheelY)
            let to = CGPoint(x: ListMark.circleXs, y: ListMark.circleYs[index])
            let centre = mixPoint(from, to)
            let r = mix(CartGeometry.wheelR, ListMark.circleR) * box.width
            let c = p(centre.x, centre.y)
            path.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }

        // 2. Erste und dritte Strebe werden zu den zwei Zeilen. Die Streben
        //    laufen senkrecht, die Zeilen waagerecht — die Drehung dazwischen
        //    ist genau das, was man sehen soll.
        for (index, strutT) in [CartGeometry.strutTs[0], CartGeometry.strutTs[2]].enumerated() {
            let top = lerp(CartGeometry.topLeft, CartGeometry.topRight, strutT)
            let bottom = lerp(CartGeometry.bottomLeft, CartGeometry.bottomRight, strutT)
            let y = ListMark.circleYs[index]
            let lineStart = CGPoint(x: ListMark.lineStartX, y: y)
            let lineEnd = CGPoint(x: ListMark.lineEndX, y: y)

            path.move(to: p(mixPoint(top, lineStart).x, mixPoint(top, lineStart).y))
            path.addLine(to: p(mixPoint(bottom, lineEnd).x, mixPoint(bottom, lineEnd).y))
        }

        // 3. Korb, Griff und die mittlere Strebe haben in der Listenmarke kein
        //    Gegenstück. Sie ziehen sich auf ihren eigenen Schwerpunkt zusammen
        //    und verschwinden dort — zusammenlaufen liest sich als „geht in der
        //    neuen Form auf", ein Ausblenden nur als „war wohl nicht wichtig".
        let basket = [
            CartGeometry.topLeft, CartGeometry.topRight,
            CartGeometry.bottomRight, CartGeometry.bottomLeft,
        ]
        let mitte = CGPoint(
            x: basket.map(\.x).reduce(0, +) / 4,
            y: basket.map(\.y).reduce(0, +) / 4
        )
        if t < 1 {
            let ecken = basket.map { lerp($0, mitte, t) }
            path.move(to: p(ecken[0].x, ecken[0].y))
            for ecke in ecken.dropFirst() { path.addLine(to: p(ecke.x, ecke.y)) }
            path.closeSubpath()

            let griffEnde = lerp(CartGeometry.handleEnd, mitte, t)
            let griffKnick = lerp(CartGeometry.handleElbow, mitte, t)
            let griffZiel = lerp(CartGeometry.topLeft, mitte, t)
            path.move(to: p(griffEnde.x, griffEnde.y))
            path.addLine(to: p(griffKnick.x, griffKnick.y))
            path.addLine(to: p(griffZiel.x, griffZiel.y))

            let mittlereOben = lerp(
                lerp(CartGeometry.topLeft, CartGeometry.topRight, CartGeometry.strutTs[1]),
                mitte, t
            )
            let mittlereUnten = lerp(
                lerp(CartGeometry.bottomLeft, CartGeometry.bottomRight, CartGeometry.strutTs[1]),
                mitte, t
            )
            path.move(to: p(mittlereOben.x, mittlereOben.y))
            path.addLine(to: p(mittlereUnten.x, mittlereUnten.y))
        }

        return path
    }
}

#Preview("Wandlung") {
    VStack(spacing: 24) {
        ForEach([0.0, 0.35, 0.7, 1.0], id: \.self) { t in
            CartToListShape(progress: t)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .frame(width: 110, height: 110)
        }
    }
    .padding()
    .background(Theme.background)
}
