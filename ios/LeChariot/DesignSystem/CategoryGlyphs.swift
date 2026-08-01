import SwiftUI

/// **Der eigene Zeichensatz für die 15 Kategorien** — gezeichnet, nicht
/// eingekauft.
///
/// Schritt 2 von L-3 im [[Le Chariot Liste-Konzept]]. Schritt 1 lieh sich
/// Systemglyphen aus SF Symbols; das behob den Emoji-Teppich, lieferte aber
/// keinen eigenen Zeichenstil. Hier steht der Satz, mit dem die Kachel
/// aussieht wie diese App und nicht wie iOS.
///
/// **Gezeichnet wie das App-Icon** (`tools/icon.swift`): Formeln im Code,
/// keine Dateien im Bundle. 15 Zeichnungen als PDF-Assets wären 15 Dateien,
/// die niemand mehr anfasst; hier ist jede Kurve eine Zeile, die man ändern
/// kann.
///
/// **Einheitsquadrat, y nach unten.** Jede Zeichnung lebt in 0…1 und wird
/// beim Zeichnen auf das Zielrechteck gestreckt. Damit trägt derselbe Satz
/// die 13 pt der Listenzeile und die 66 pt des Detailblatts.
///
/// **Ein Strich, überall gleich breit.** Monolinie mit runden Enden ist das
/// einzige, was bei 13 pt trägt: Flächen laufen zu, Haarlinien verschwinden,
/// unterschiedliche Strichstärken werden zu Matsch. Gefüllt wird nur, was
/// als Umriss ohnehin zulaufen würde — Pfotenballen, Augen.
enum CategoryGlyph {

    /// Was gezeichnet wird: Striche und Flächen getrennt, weil die einen
    /// gestrichen und die anderen gefüllt werden.
    struct Drawing {
        var stroke = Path()
        var fill = Path()
    }

    /// Strichstärke im Verhältnis zur Kantenlänge.
    ///
    /// **Erlaufen, nicht gewählt.** Bei 0,07 zerfällt der Satz auf der
    /// Listenzeile (13 pt → 0,9 pt Strich, unter einem Gerätepixel bei @2x),
    /// bei 0,12 laufen Schneeflocke und Pfote zu. 0,095 hält beides aus:
    /// 1,25 pt bei 13 pt, 6,2 pt auf dem Detailblatt.
    static let lineWidthRatio: CGFloat = 0.095

    /// Die Zeichnung dieser Kategorie, oder `nil` für eine, die es hier nicht
    /// gibt — dann greift der nächste Rückfall, statt dass irgendein Zeichen
    /// das Falsche behauptet.
    static func drawing(for category: String, in rect: CGRect) -> Drawing? {
        guard let recipe = recipes[category] else { return nil }
        var pen = Pen(rect: rect)
        recipe(&pen)
        return Drawing(stroke: pen.stroke, fill: pen.fill)
    }

    /// Nur für Tests und das Werkzeug: alle Kategorien, für die hier etwas
    /// gezeichnet ist.
    static var drawnCategories: [String] { recipes.keys.sorted() }

    // MARK: Die fünfzehn

    private static let recipes: [String: (inout Pen) -> Void] = [

        // Apfel: zwei Bäuche mit einer Kerbe oben, Stiel, Blatt. Die Kerbe ist
        // das, was ihn vom Kreis unterscheidet — ohne sie ist es eine Kirsche.
        "Obst & Gemüse": { p in
            p.begin(p.at(0.50, 0.30))
            p.bow(p.at(0.16, 0.55), p.at(0.36, 0.20), p.at(0.16, 0.34))
            p.bow(p.at(0.50, 0.93), p.at(0.16, 0.78), p.at(0.32, 0.93))
            p.bow(p.at(0.84, 0.55), p.at(0.68, 0.93), p.at(0.84, 0.78))
            p.bow(p.at(0.50, 0.30), p.at(0.84, 0.34), p.at(0.64, 0.20))
            p.close()
            p.begin(p.at(0.50, 0.30))
            p.bow(p.at(0.56, 0.08), p.at(0.50, 0.20), p.at(0.52, 0.12))
            p.begin(p.at(0.56, 0.16))
            p.bow(p.at(0.86, 0.13), p.at(0.66, 0.06), p.at(0.82, 0.03))
            p.bow(p.at(0.56, 0.16), p.at(0.86, 0.22), p.at(0.70, 0.20))
        },

        // Milchtüte mit Giebel. Der Falz oben ist die halbe Miete: ein
        // Rechteck mit Dreiecksdach ist ein Haus — erst die abgeflachte
        // Spitze mit dem aufgestellten Kamm macht die Tüte. Der erste
        // Entwurf hatte die Spitze und war auf dem Prüfbogen ein Haus.
        "Molkerei & Eier": { p in
            p.begin(p.at(0.22, 0.94))
            p.to(p.at(0.22, 0.42))
            p.to(p.at(0.35, 0.24))
            p.to(p.at(0.65, 0.24))
            p.to(p.at(0.78, 0.42))
            p.to(p.at(0.78, 0.94))
            p.close()
            p.line([p.at(0.22, 0.42), p.at(0.78, 0.42)])
            p.line([p.at(0.35, 0.24), p.at(0.35, 0.10), p.at(0.65, 0.10), p.at(0.65, 0.24)])
        },

        // Zwei Würstchen, leicht geneigt und gegeneinander versetzt.
        //
        // **Vierter Anlauf. Die drei davor stehen hier, weil sie zeigen,
        // woran es jedes Mal lag: an der Silhouette, nie am Strich.**
        //
        // 1. Hufeisen mit runden Kappen — die Kappen brauchten
        //    Kontrollpunkte über den Endpunkten und wurden zu zwei Hörnern.
        //    Auf dem Prüfbogen eine **Tulpe**.
        // 2. Dasselbe mit geraden Schnittflächen und großer Lücke: ein
        //    **Hufeisen**, jetzt eindeutig als solches.
        // 3. Enger Ring aus echten Kreisbögen, Lücke oben: bei 13 pt der
        //    **Ein-/Ausschalter** von iOS. Ein Ring mit einer Kerbe oben ist
        //    besetzt, und dagegen kommt keine Strichstärke an.
        //
        // Zwei Kapseln sind, was übrig bleibt, wenn man das Runde aufgibt —
        // und sie haben den Vorteil, dass **zwei** davon nie eine Pille und
        // nie eine Batterie sind. Die Neigung ist nicht Zierde: Zwei
        // senkrechte Kapseln nebeneinander sind ein Ladebalken.
        "Fleisch & Wurst": { p in
            p.capsule(0.36, 0.52, 0.26, 0.74, tilt: -16)
            p.capsule(0.65, 0.48, 0.26, 0.74, tilt: -16)
        },

        // Fisch: Körper mit spitzer Nase, Schwanzflosse als Keil, ein Auge.
        // Das Auge ist gefüllt — als Ring wäre es bei 13 pt ein Fleck.
        "Fisch": { p in
            p.begin(p.at(0.32, 0.50))
            p.bow(p.at(0.94, 0.50), p.at(0.46, 0.13), p.at(0.80, 0.18))
            p.bow(p.at(0.32, 0.50), p.at(0.80, 0.82), p.at(0.46, 0.87))
            p.close()
            p.begin(p.at(0.32, 0.50))
            p.to(p.at(0.06, 0.20))
            p.to(p.at(0.06, 0.80))
            p.close()
            p.dot(p.at(0.76, 0.42), 0.052)
        },

        // Brotlaib: Kuppe mit zwei Schnitten. Drei waren es im ersten
        // Entwurf, und bei 13 pt lief die Kuppe damit zu — zwei lassen
        // zwischen sich Fläche stehen.
        "Backwaren": { p in
            p.begin(p.at(0.10, 0.84))
            p.to(p.at(0.10, 0.56))
            p.bow(p.at(0.90, 0.56), p.at(0.10, 0.18), p.at(0.90, 0.18))
            p.to(p.at(0.90, 0.84))
            p.close()
            p.line([p.at(0.40, 0.50), p.at(0.30, 0.72)])
            p.line([p.at(0.66, 0.54), p.at(0.56, 0.76)])
        },

        // Schneeflocke: drei Achsen, jede mit vier Ästen. Ohne die Äste ist
        // es ein Sternchen.
        //
        // **Die Äste standen im ersten Entwurf am Bildrand statt am Arm** —
        // sie wurden aus rohen Einheitszahlen gebaut und nie durch `at()`
        // geschickt, landeten also bei ein paar Pixeln links oben. Auf dem
        // Prüfbogen war das ein Punkt neben der Flocke. Genau dafür gibt es
        // den Prüfbogen; im Simulator wäre es bei 13 pt Schmutz gewesen.
        "Tiefkühl": { p in
            for i in 0..<3 {
                let winkel = Double(i) * .pi / 3
                let dx = CGFloat(cos(winkel)) * 0.42, dy = CGFloat(sin(winkel)) * 0.42
                p.line([p.at(0.5 - dx, 0.5 - dy), p.at(0.5 + dx, 0.5 + dy)])
                for ende in [CGFloat(1), CGFloat(-1)] {
                    let bx = 0.5 + ende * dx * 0.52, by = 0.5 + ende * dy * 0.52
                    for seite in [1.0, -1.0] {
                        let ast = winkel + seite * 0.9
                        p.line([p.at(bx, by),
                                p.at(bx + ende * CGFloat(cos(ast)) * 0.22,
                                     by + ende * CGFloat(sin(ast)) * 0.22)])
                    }
                }
            }
        },

        // Bonbon im Papier: Kern mit zwei gedrehten Zipfeln.
        "Süßes & Snacks": { p in
            p.begin(p.at(0.36, 0.32))
            p.to(p.at(0.64, 0.32))
            p.bow(p.at(0.64, 0.68), p.at(0.78, 0.42), p.at(0.78, 0.58))
            p.to(p.at(0.36, 0.68))
            p.bow(p.at(0.36, 0.32), p.at(0.22, 0.58), p.at(0.22, 0.42))
            p.close()
            p.line([p.at(0.30, 0.38), p.at(0.06, 0.20), p.at(0.10, 0.50),
                    p.at(0.06, 0.80), p.at(0.30, 0.62)])
            p.line([p.at(0.70, 0.38), p.at(0.94, 0.20), p.at(0.90, 0.50),
                    p.at(0.94, 0.80), p.at(0.70, 0.62)])
        },

        // Flasche mit Verschluss: Deckel, Hals, Schulter, Bauch.
        "Getränke": { p in
            p.begin(p.at(0.41, 0.20))
            p.to(p.at(0.41, 0.34))
            p.bow(p.at(0.26, 0.54), p.at(0.41, 0.44), p.at(0.26, 0.44))
            p.to(p.at(0.26, 0.94))
            p.to(p.at(0.74, 0.94))
            p.to(p.at(0.74, 0.54))
            p.bow(p.at(0.59, 0.34), p.at(0.74, 0.44), p.at(0.59, 0.44))
            p.to(p.at(0.59, 0.20))
            p.close()
            p.line([p.at(0.39, 0.20), p.at(0.61, 0.20), p.at(0.61, 0.08),
                    p.at(0.39, 0.08)], closed: true)
        },

        // Weinglas: Kelch, Stiel, Fuß. Der lesbarste Kandidat des ganzen
        // Satzes — drei Striche und niemand fragt nach.
        "Alkohol": { p in
            p.begin(p.at(0.26, 0.12))
            p.to(p.at(0.74, 0.12))
            p.bow(p.at(0.50, 0.58), p.at(0.74, 0.44), p.at(0.64, 0.58))
            p.bow(p.at(0.26, 0.12), p.at(0.36, 0.58), p.at(0.26, 0.44))
            p.close()
            p.line([p.at(0.50, 0.58), p.at(0.50, 0.86)])
            p.line([p.at(0.28, 0.90), p.at(0.72, 0.90)])
        },

        // Kochtopf: Deckel mit Knauf, Korpus, zwei Griffe.
        "Vorräte & Kochen": { p in
            p.line([p.at(0.44, 0.14), p.at(0.56, 0.14)])
            p.line([p.at(0.50, 0.14), p.at(0.50, 0.26)])
            p.line([p.at(0.16, 0.30), p.at(0.84, 0.30)])
            p.begin(p.at(0.24, 0.36))
            p.to(p.at(0.30, 0.90))
            p.to(p.at(0.70, 0.90))
            p.to(p.at(0.76, 0.36))
            p.begin(p.at(0.24, 0.42))
            p.bow(p.at(0.10, 0.56), p.at(0.12, 0.42), p.at(0.10, 0.48))
            p.begin(p.at(0.76, 0.42))
            p.bow(p.at(0.90, 0.56), p.at(0.88, 0.42), p.at(0.90, 0.48))
        },

        // Seifenstück mit zwei Blasen.
        //
        // **Zweimal keine Flasche mehr.** Erster Entwurf: Pumpspender.
        // Zweiter: Tube. Beide standen auf dem Prüfbogen bei 13 pt neben den
        // Getränken wie deren Zwilling — ein hochkanter Behälter mit
        // Schulter und Deckel ist ein hochkanter Behälter mit Schulter und
        // Deckel, egal was oben draufsitzt. Das Seifenstück liegt **quer**
        // und ist damit die einzige Zeichnung des Satzes, die man schon an
        // der Ausrichtung erkennt.
        "Drogerie": { p in
            p.stroke.addRoundedRect(in: p.box(0.50, 0.70, 0.76, 0.40),
                                    cornerSize: p.corner(0.16))
            p.circle(p.at(0.70, 0.24), 0.145)
            p.circle(p.at(0.36, 0.26), 0.10)
        },

        // Besen: Stiel, Bund, Borsten. Der Bund trennt Stiel und Kopf — ohne
        // ihn ist es ein Trichter am Stock.
        "Haushalt": { p in
            p.line([p.at(0.50, 0.08), p.at(0.50, 0.46)])
            p.begin(p.at(0.24, 0.92))
            p.to(p.at(0.34, 0.46))
            p.to(p.at(0.66, 0.46))
            p.to(p.at(0.76, 0.92))
            p.close()
            p.line([p.at(0.30, 0.66), p.at(0.70, 0.66)])
        },

        // Pfote: vier Zehen und ein Ballen, gefüllt. Als Umrisse liefen sie
        // bei 13 pt zu — ein Ring von 3 px ist ein Punkt.
        //
        // Die Zehen stehen auf einem Bogen und nicht auf einer Geraden, und
        // der Ballen ist kleiner als im ersten Entwurf: Dort saß er so tief
        // und breit, dass die Zehen wie Krümel darüber lagen.
        "Tierbedarf": { p in
            p.dot(p.at(0.19, 0.38), 0.098)
            p.dot(p.at(0.39, 0.23), 0.103)
            p.dot(p.at(0.62, 0.23), 0.103)
            p.dot(p.at(0.82, 0.38), 0.098)
            p.fill.addEllipse(in: p.box(0.50, 0.68, 0.50, 0.40))
        },

        // Bärenkopf: Schädel, zwei Ohren, Schnauze, zwei Augen. Der ganze
        // Bär war der erste Entwurf und war bei 13 pt ein Fleck mit Beinen.
        "Kinder": { p in
            p.circle(p.at(0.26, 0.28), 0.14)
            p.circle(p.at(0.74, 0.28), 0.14)
            p.circle(p.at(0.50, 0.58), 0.32)
            p.dot(p.at(0.39, 0.51), 0.05)
            p.dot(p.at(0.61, 0.51), 0.05)
            p.fill.addEllipse(in: p.box(0.50, 0.70, 0.26, 0.18))
        },

        // Einkaufskorb: Bügel, Wanne, zwei Rippen. Nicht der Wagen — der ist
        // das App-Icon und die letzte Reserve der Kachel; zwei Wagen
        // übereinander wären eine Verwechslung.
        "Sonstiges": { p in
            p.begin(p.at(0.32, 0.38))
            p.bow(p.at(0.68, 0.38), p.at(0.32, 0.14), p.at(0.68, 0.14))
            p.begin(p.at(0.10, 0.40))
            p.to(p.at(0.22, 0.90))
            p.to(p.at(0.78, 0.90))
            p.to(p.at(0.90, 0.40))
            p.close()
            p.line([p.at(0.38, 0.50), p.at(0.42, 0.80)])
            p.line([p.at(0.62, 0.50), p.at(0.58, 0.80)])
        },
    ]
}

/// Der Zeichenstift: rechnet Einheitskoordinaten auf das Zielrechteck um und
/// sammelt Striche und Flächen getrennt ein.
///
/// Eigener Typ statt roher `Path`-Aufrufe in jeder Zeichnung, damit die
/// fünfzehn Rezepte oben lesbar bleiben — dort steht die Gestaltung, hier die
/// Rechnerei.
private struct Pen {
    let rect: CGRect
    var stroke = Path()
    var fill = Path()

    func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }

    /// Eine Kapsel — Rechteck mit halbrunden Enden —, um ihre eigene Mitte
    /// gedreht. Maße und Mittelpunkt in Einheitsmaßen, Neigung in Grad.
    mutating func capsule(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat,
                          tilt: Double) {
        let frame = box(cx, cy, w, h)
        let form = Path(roundedRect: frame, cornerRadius: min(frame.width, frame.height) / 2)
        let mitte = at(cx, cy)
        let drehung = CGAffineTransform(translationX: mitte.x, y: mitte.y)
            .rotated(by: tilt * .pi / 180)
            .translatedBy(x: -mitte.x, y: -mitte.y)
        stroke.addPath(form.applying(drehung))
    }

    /// Eckenradius in Einheitsmaßen, für `addRoundedRect`.
    func corner(_ radius: CGFloat) -> CGSize {
        CGSize(width: radius * rect.width, height: radius * rect.height)
    }

    /// Ein Rechteck um einen Mittelpunkt, in Einheitsmaßen.
    func box(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: rect.minX + (cx - w / 2) * rect.width,
               y: rect.minY + (cy - h / 2) * rect.height,
               width: w * rect.width, height: h * rect.height)
    }

    mutating func begin(_ point: CGPoint) { stroke.move(to: point) }
    mutating func to(_ point: CGPoint) { stroke.addLine(to: point) }
    mutating func bow(_ point: CGPoint, _ c1: CGPoint, _ c2: CGPoint) {
        stroke.addCurve(to: point, control1: c1, control2: c2)
    }
    mutating func close() { stroke.closeSubpath() }

    mutating func line(_ points: [CGPoint], closed: Bool = false) {
        guard let first = points.first else { return }
        stroke.move(to: first)
        for point in points.dropFirst() { stroke.addLine(to: point) }
        if closed { stroke.closeSubpath() }
    }

    /// Gestrichener Kreis, Radius in Einheitsmaßen.
    mutating func circle(_ center: CGPoint, _ radius: CGFloat) {
        stroke.addEllipse(in: ring(center, radius))
    }

    /// Gefüllter Punkt, Radius in Einheitsmaßen.
    mutating func dot(_ center: CGPoint, _ radius: CGFloat) {
        fill.addEllipse(in: ring(center, radius))
    }

    private func ring(_ center: CGPoint, _ radius: CGFloat) -> CGRect {
        let rx = radius * rect.width, ry = radius * rect.height
        return CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2)
    }
}

/// Eine Hälfte einer Zeichnung als `Shape` — damit sie sich wie jede andere
/// SwiftUI-Form verhält: Größe von außen, Farbe von außen, animierbar.
///
/// Zwei Formen statt eines `Canvas`, weil `Canvas` seine Farbe selbst holen
/// müsste. So erbt die Zeichnung `.foregroundStyle` von der Aufrufstelle,
/// genau wie das `Image(systemName:)` davor.
struct CategoryGlyphShape: Shape {
    enum Part { case stroke, fill }

    let category: String
    let part: Part

    func path(in rect: CGRect) -> Path {
        // Immer quadratisch und mittig: eine gestreckte Milchtüte wäre keine.
        let side = min(rect.width, rect.height)
        let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2,
                            width: side, height: side)
        guard let drawing = CategoryGlyph.drawing(for: category, in: square) else { return Path() }
        return part == .stroke ? drawing.stroke : drawing.fill
    }
}

/// Die fertige Zeichnung: Fläche und Strich übereinander, in der Farbe, die
/// von außen kommt.
struct CategoryGlyphView: View {
    let category: String
    /// Kantenlänge. Der Strich wächst mit — fest gesetzt wäre er auf dem
    /// Detailblatt eine Haarlinie und auf der Listenzeile ein Balken.
    let size: CGFloat

    var body: some View {
        ZStack {
            CategoryGlyphShape(category: category, part: .fill)
            CategoryGlyphShape(category: category, part: .stroke)
                .stroke(style: StrokeStyle(lineWidth: size * CategoryGlyph.lineWidthRatio,
                                           lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}
