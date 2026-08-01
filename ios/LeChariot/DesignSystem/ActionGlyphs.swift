import SwiftUI

/// Gezeichnete Zeichen für **Bedienelemente**, im selben Strich wie
/// `CategoryGlyph`.
///
/// Gemeldet am 2026-08-01 ([UI-3]): Die Symbole bei „Rundgang erneut ansehen"
/// und „Vorschläge vergessen" gefallen nicht. Es waren `sparkles` und
/// `wand.and.sparkles` — zwei Glitzer-Glyphen, die Zauberei versprechen, wo
/// eine Einführung und ein Aufräumen stehen.
///
/// Eigener Typ und nicht als sechzehnte „Kategorie": `CategoryGlyph` beschreibt
/// Warengruppen, und ein Test hält fest, dass es genau fünfzehn sind. Geteilt
/// wird der `Pen`, nicht die Liste.
enum AppGlyph {
    case tour
    case forgetSuggestions

    /// Strichstärke wie beim Kategoriensatz — ein zweiter Wert wäre ein
    /// zweiter Zeichenstil.
    static let lineWidthRatio = CategoryGlyph.lineWidthRatio

    static var all: [AppGlyph] { [.tour, .forgetSuggestions] }

    func drawing(in rect: CGRect) -> CategoryGlyph.Drawing {
        var pen = Pen(rect: rect)
        switch self {
        // Wegweiser: Pfosten, ein Schild nach rechts, eins nach links. Zwei
        // Arme, nicht einer — mit einem allein ist es eine Fahne.
        case .tour:
            pen.line([pen.at(0.44, 0.06), pen.at(0.44, 0.94)])
            pen.begin(pen.at(0.44, 0.14))
            pen.to(pen.at(0.90, 0.14))
            pen.to(pen.at(0.78, 0.30))
            pen.to(pen.at(0.90, 0.46))
            pen.to(pen.at(0.44, 0.46))
            pen.close()
            pen.begin(pen.at(0.44, 0.56))
            pen.to(pen.at(0.10, 0.56))
            pen.to(pen.at(0.22, 0.70))
            pen.to(pen.at(0.10, 0.84))
            pen.to(pen.at(0.44, 0.84))
            pen.close()

        // Die Vorschlagskacheln, und eine davon ist nicht mehr da: drei
        // Kacheln, an der vierten Stelle nur noch drei Punkte. „Vergessen"
        // heißt nicht wegwerfen — deshalb kein Papierkorb, der schon am
        // Zurücksetzen hängt.
        case .forgetSuggestions:
            for (cx, cy) in [(0.28, 0.28), (0.72, 0.28), (0.28, 0.72)] {
                pen.stroke.addRoundedRect(in: pen.box(cx, cy, 0.34, 0.34),
                                          cornerSize: pen.corner(0.09))
            }
            pen.dot(pen.at(0.60, 0.72), 0.05)
            pen.dot(pen.at(0.72, 0.72), 0.05)
            pen.dot(pen.at(0.84, 0.72), 0.05)
        }
        return CategoryGlyph.Drawing(stroke: pen.stroke, fill: pen.fill)
    }
}

/// Eine Hälfte der Zeichnung als `Shape` — siehe `CategoryGlyphShape`.
struct AppGlyphShape: Shape {
    let glyph: AppGlyph
    let part: CategoryGlyphShape.Part

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2,
                            width: side, height: side)
        let drawing = glyph.drawing(in: square)
        return part == .stroke ? drawing.stroke : drawing.fill
    }
}

/// Die fertige Zeichnung in der Farbe, die von außen kommt.
struct AppGlyphView: View {
    let glyph: AppGlyph
    /// Kantenlänge; der Strich wächst mit.
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            AppGlyphShape(glyph: glyph, part: .fill)
            AppGlyphShape(glyph: glyph, part: .stroke)
                .stroke(style: StrokeStyle(lineWidth: size * AppGlyph.lineWidthRatio,
                                           lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

/// `Label` mit gezeichnetem statt geliehenem Zeichen.
///
/// Die Zeichnung sitzt in einer Breite, die der Systembreite von `Label`
/// entspricht — sonst stünde der Text dieser zwei Zeilen weiter links als der
/// aller anderen im selben Abschnitt.
struct AppGlyphLabel: View {
    let title: String
    let glyph: AppGlyph

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            AppGlyphView(glyph: glyph)
                .frame(width: 24, alignment: .center)
            Text(title)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

#Preview {
    List {
        AppGlyphLabel(title: "Rundgang erneut ansehen", glyph: .tour)
        AppGlyphLabel(title: "Vorschläge vergessen", glyph: .forgetSuggestions)
    }
}
