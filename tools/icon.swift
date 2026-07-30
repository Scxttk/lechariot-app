// Le-Chariot-App-Icon: ein Einkaufswagen als beleuchteter Gegenstand.
//
// Gezeichnet nach der Methode des Côte-d'OS-Icons (`GenerateAppIcon.swift`
// im Ledge-Repo): Superellipse statt Rechteck mit runden Ecken,
// gerichtetes Licht, elliptische Lichtquelle oben, Glanzkante, Rendern
// in 4× und Herunterrechnen, und **ein** Gegenstand als Motiv statt
// einer Zeichnung um eine leere Mitte herum.
//
// Zwei Dinge von dort gelten hier ausdrücklich NICHT, beides
// Plattformunterschiede:
//
// (1) Côte d'OS rückt die Zeichnung auf 824 von 1024 ein und backt einen
//     Kontaktschatten ein. Das ist die **Mac**-Konvention: Dock-Icons
//     sind freistehende Formen und bringen ihren Schatten mit.
//     iOS-Icons sind randvoll — keine Transparenz, keine runden Ecken,
//     kein Schatten im Bild, weil das System maskiert und schattiert.
//     Eingerückt gezeichnet würde iOS die volle Fläche maskieren: ein
//     kleines Icon in einem Quadrat, mit doppeltem Schatten und sichtbar
//     kleiner als jeder Nachbar. Übernommen ist nur das *Verhältnis* —
//     die Insel misst 470 auf 824 Fläche, rund 57 %; der Wagen hier
//     62 % der vollen Kantenlänge.
//
// (2) Côte d'OS liefert sieben Größen und zeichnet 16 und 32 px eigens
//     vereinfacht. iOS nimmt **eine** 1024er Datei je Erscheinungsbild
//     und rechnet selbst herunter; es gibt keine kleine Datei, in die
//     eine vereinfachte Fassung passen würde. Die kleinste Stufe auf
//     iOS ist ohnehin 40 px (Mitteilung @2x), nicht 16 — 16 und 32 sind
//     Mac-Größen. Die Vereinfachung muss deshalb in dieselbe Zeichnung:
//     nichts darf an Details hängen, die bei 40 px unter etwa 1,5 px
//     fallen.
//
// Alle drei Erscheinungsbilder teilen **dieselbe Geometrie**; nur die
// Farben und die Richtung des Tiefenhinweises unterscheiden sich.
//
// Bauen und laufen lassen:
//   swiftc -O tools/icon.swift -o /tmp/icon && /tmp/icon ios/LeChariot/Assets.xcassets/AppIcon.appiconset/
//
// Optionaler Prüfbogen bei den echten iOS-Größen (schreibt NICHT in den
// Asset-Katalog, dort stört jede Datei, die kein Slot beansprucht):
//   /tmp/icon <zielordner> --pruefbogen <anderer-ordner>
import AppKit
import CoreGraphics
import Foundation

let G: CGFloat = 1024  // Zeichengitter, Ursprung unten links

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: srgb, components: [
        CGFloat((hex >> 16) & 0xFF) / 255,
        CGFloat((hex >> 8) & 0xFF) / 255,
        CGFloat(hex & 0xFF) / 255, alpha,
    ])!
}

func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(colorsSpace: srgb, colors: stops.map { $0.1 } as CFArray,
               locations: stops.map { $0.0 })!
}

/// Superellipse |x/a|^n + |y/b|^n = 1. `CGPath(roundedRect:)` setzt
/// Kreisbögen an gerade Kanten; an der Naht springt die Krümmung von 0
/// auf 1/r, und genau diese Naht lässt ein Icon fremd wirken. n ≈ 5
/// trifft die Maske.
func squircle(in rect: CGRect, exponent n: CGFloat = 5, segments: Int = 720) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    for i in 0...segments {
        let t = 2 * CGFloat.pi * CGFloat(i) / CGFloat(segments)
        let c = cos(t), s = sin(t)
        let x = rect.midX + a * pow(abs(c), 2 / n) * (c < 0 ? -1 : 1)
        let y = rect.midY + b * pow(abs(s), 2 / n) * (s < 0 ? -1 : 1)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

/// Vieleck mit runden Ecken: füllen **und** mit runden Verbindungen
/// nachziehen. Ein echter Eckenradius auf einem schiefen Viereck wäre
/// Trigonometrie für jede Ecke einzeln; das hier kostet zwei Zeilen und
/// ist an Icon-Größe nicht zu unterscheiden.
func fillRounded(_ ctx: CGContext, _ path: CGPath, radius: CGFloat) {
    ctx.saveGState()
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)
    ctx.setLineWidth(radius * 2)
    ctx.addPath(path)
    ctx.drawPath(using: .fillStroke)
    ctx.restoreGState()
}

// MARK: - Farben je Erscheinungsbild

struct Palette {
    let name: String
    let fieldTop: UInt32
    let fieldMid: UInt32
    let fieldBottom: UInt32
    let glow: UInt32
    let glowAlpha: CGFloat
    let rimAlpha: CGFloat
    let inkTop: UInt32      // Wagen oben (Licht)
    let inkBottom: UInt32   // Wagen unten (Schatten)
    let cartShadow: UInt32
    /// Auf heller Fläche sitzt der Tiefenhinweis unten, nicht oben. Eine
    /// weiße Glanzlinie an der Oberkante ist auf Creme praktisch
    /// unsichtbar — sie wird zu Dunst. Was man dort stattdessen sieht,
    /// ist die dunklere Kante unten, wo die Wölbung das Licht verliert.
    let rimDark: Bool
    /// Glanz auf der Korboberkante. Ein dunkler Wagen auf Creme braucht
    /// weniger davon als ein cremefarbener auf Grün, sonst wirkt die
    /// Kante wie ausgefranst.
    let specAlpha: CGFloat
}

// Der Bereich des Verlaufs ist das, was Tiefe macht. Die erste Fassung
// lief von 0x35543D auf 0x16281C und wirkte daneben flach: Côte d'OS
// spannt von hellem Violett bis zu tiefem Indigo, also fast über die
// ganze Helligkeit der Farbe. Ein schmaler Verlauf liest sich als
// Volltonfläche mit Schmutz, nicht als Licht.
let palettes = [
    // Hell: **grüner Wagen auf Creme**, nicht noch einmal die dunkle
    // Platte. Im hellen Modus ist die App grün auf Creme; das Icon soll
    // dieses Erscheinungsbild zeigen und nicht ein zweites dunkles.
    // Werte aus DesignSystem/Theme.swift statt frei erfunden: Creme
    // #EDE9C0 (Theme.background) als Mitte des Verlaufs, Grün #3F6444
    // (Theme.accent) als belichtete Oberseite des Wagens.
    Palette(name: "icon-light-1024", fieldTop: 0xF7F4DE, fieldMid: 0xEDE9C0, fieldBottom: 0xDBD5A2,
            glow: 0xFFFFFF, glowAlpha: 0.30, rimAlpha: 0.16,
            inkTop: 0x3F6444, inkBottom: 0x2B4630, cartShadow: 0x5C5636,
            rimDark: true, specAlpha: 0.20),

    // Dunkel: dieselbe Geometrie, nur tiefer. Die alte Fassung nahm für
    // hell und dunkel dasselbe Bild, mit dem Argument, ein Emailschild
    // wechsle seine Farbe nicht. Das galt für ein flaches Schild; ein
    // beleuchteter Gegenstand darf nachts dunkler stehen, sonst leuchtet
    // die Fläche auf dem dunklen Homescreen auf.
    Palette(name: "icon-dark-1024", fieldTop: 0x385C43, fieldMid: 0x1C3324, fieldBottom: 0x070F0A,
            glow: 0xEDE9C0, glowAlpha: 0.24, rimAlpha: 0.38,
            inkTop: 0xF7F3DC, inkBottom: 0xA8A075, cartShadow: 0x030906,
            rimDark: false, specAlpha: 0.38),

    // Getönt: iOS erwartet Graustufen und legt den Farbton selbst
    // darüber. Das Motiv muss allein über Helligkeit tragen.
    Palette(name: "icon-tinted-1024", fieldTop: 0x4A4A4A, fieldMid: 0x262626, fieldBottom: 0x0A0A0A,
            glow: 0xFFFFFF, glowAlpha: 0.26, rimAlpha: 0.40,
            inkTop: 0xFFFFFF, inkBottom: 0xB0B0B0, cartShadow: 0x000000,
            rimDark: false, specAlpha: 0.38),
]

// MARK: - Wagengeometrie

// Einheitsquadrat, y nach oben. Wie in der Zeichnungsrunde, aber der
// Korb ist jetzt Masse statt Kontur: eine Kontur ließe bei kleiner
// Größe einen dunklen Rahmen mit leerer Mitte stehen — derselbe Fehler,
// den das alte Côte-d'OS-Icon mit dem Mac um die Insel herum machte.
let handleEnd = CGPoint(x: 0.00, y: 0.92)
let handleElbow = CGPoint(x: 0.10, y: 0.92)

// Der Korb ist ein Keil, kein gleichschenkliges Trapez: hinten am Griff
// tief, nach vorn flacher. Das ist an einem echten Einkaufswagen so —
// deshalb lassen sie sich ineinanderschieben — und es ist der eine
// beobachtete Zug, den ein Piktogramm nicht hat. Vorher liefen Ober-
// und Unterkante beide waagerecht; das ist die Form, die jede
// Einkaufs-App zeichnet.
// Der Keil war zuerst deutlich stärker (0.65/0.60 oben, 0.28/0.36
// unten). Bei 40 px sah das gut aus, bei 180 und darüber wurde daraus
// ein schiefer Klotz — eine Kehrschaufel, kein Korb. Auf die kleinste
// Größe allein zu optimieren verdirbt die großen, weil dort genau die
// Details sichtbar werden, die unten wegfallen. Jetzt rund 20 % mehr
// Tiefe hinten als vorn: sichtbar, aber keine Behauptung.
let topLeft = CGPoint(x: 0.24, y: 0.64)
let topRight = CGPoint(x: 1.00, y: 0.615)
let bottomRight = CGPoint(x: 0.87, y: 0.335)
let bottomLeft = CGPoint(x: 0.36, y: 0.30)

// Räder kleiner als in v2 (0.098) und tiefer, aber nicht so tief wie im
// ersten Versuch mit 0.09: dort hingen sie als zwei Kugeln unter dem
// Korb statt an ihm. Die Luft muss die Räder trennen, nicht sie
// abhängen.
let wheelY: CGFloat = 0.135
let wheelXs: [CGFloat] = [0.48, 0.80]
let wheelR: CGFloat = 0.088

/// Der Wagen nimmt 62 % der Kantenlänge ein. Côte d'OS setzt die Insel
/// auf 470 von 824, also 57 % der Fläche; randvoll gezeichnet säße das
/// Motiv größer als bei jedem Nachbarn.
let cartWidth = G * 0.62
let cartHeight = G * 0.62 * 0.86

/// Optische Mitte über dem Korb, nicht über der Bounding-Box: die reicht
/// bis ans Griffende, wo kaum Farbe liegt.
let opticalCenterX: CGFloat = 0.58

/// Der Höhenversatz gleicht aus, dass die Bounding-Box oben am Griffende
/// endet, die Masse aber unten liegt. Er musste von 0.012 auf 0.034
/// wachsen, als die Räder tiefer rückten: das verschob den Schwerpunkt
/// nach unten, ohne die Box zu ändern, und der Wagen saß sichtbar zu
/// tief im Feld.
func pt(_ p: CGPoint) -> CGPoint {
    CGPoint(x: G / 2 - cartWidth * opticalCenterX + p.x * cartWidth,
            y: G / 2 - cartHeight / 2 + p.y * cartHeight + G * 0.026)
}

func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}

func basketPath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: pt(topLeft)); p.addLine(to: pt(topRight))
    p.addLine(to: pt(bottomRight)); p.addLine(to: pt(bottomLeft))
    p.closeSubpath()
    return p
}

/// Die Streben. Breit genug, dass sie bei 60 pt nicht zulaufen: drei
/// Schlitze auf 62 % Kantenlänge sind dort je rund 2 px — schmaler
/// gezeichnet verschwinden sie beim Herunterrechnen und der Korb wird
/// eine einzige Fläche.
let strutTs: [CGFloat] = [0.30, 0.52, 0.74]
let strutWidth = G * 0.017

// MARK: - Zeichnen

func drawField(into ctx: CGContext, _ pal: Palette) {
    ctx.drawLinearGradient(gradient([
        (0.00, color(pal.fieldTop)),
        (0.55, color(pal.fieldMid)),
        (1.00, color(pal.fieldBottom)),
    ]), start: CGPoint(x: G / 2, y: G), end: CGPoint(x: G / 2, y: 0), options: [])

    // Lichtquelle oben Mitte, elliptisch. Apples Icons haben fast alle
    // eine, und sie ist der Hauptgrund, warum sie als Gegenstände
    // gelesen werden und nicht als Grafik.
    ctx.saveGState()
    ctx.translateBy(x: G / 2, y: G * 0.78)
    ctx.scaleBy(x: 1, y: 0.62)
    ctx.drawRadialGradient(gradient([
        (0.00, color(pal.glow, pal.glowAlpha)),
        (0.55, color(pal.glow, pal.glowAlpha * 0.35)),
        (1.00, color(pal.glow, 0.00)),
    ]), startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: G * 0.64, options: [])
    ctx.restoreGState()
}

func drawIcon(into ctx: CGContext, side: CGFloat, _ pal: Palette) {
    let k = side / G
    ctx.scaleBy(x: k, y: k)
    ctx.interpolationQuality = .high

    let full = CGRect(x: 0, y: 0, width: G, height: G)

    // 1 — Fläche randvoll. Kein Einrücken, kein Kontaktschatten: das
    //     macht auf iOS das System.
    drawField(into: ctx, pal)

    // Die Fläche als Bild merken, damit die Strebenschlitze später
    // exakt den Grund zeigen statt einer geratenen Volltonfarbe.
    let fieldCtx = CGContext(data: nil, width: Int(G), height: Int(G), bitsPerComponent: 8,
                             bytesPerRow: 0, space: srgb,
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    drawField(into: fieldCtx, pal)
    let fieldImage = fieldCtx.makeImage()!

    // 2 — Glanzlinie innen an der Oberkante, zu den Schultern hin
    //     auslaufend. Billigster Tiefenhinweis, den es gibt.
    ctx.saveGState()
    ctx.setLineWidth(G * 0.0055)
    ctx.addPath(squircle(in: full.insetBy(dx: G * 0.004, dy: G * 0.004)))
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    if pal.rimDark {
        // Helle Fläche: die Kante unten abdunkeln. Oben eine weiße Linie
        // zu ziehen brächte auf Creme nichts — dort ist kein Kontrast
        // mehr übrig, den man aufhellen könnte.
        ctx.drawLinearGradient(gradient([
            (0.00, color(0x6B6540, pal.rimAlpha * 1.9)),
            (0.28, color(0x6B6540, pal.rimAlpha * 0.5)),
            (0.60, color(0x6B6540, 0.00)),
        ]), start: CGPoint(x: G / 2, y: 0), end: CGPoint(x: G / 2, y: G), options: [])
    } else {
        ctx.drawLinearGradient(gradient([
            (0.00, color(0xFFFFFF, pal.rimAlpha)),
            (0.26, color(0xFFFFFF, pal.rimAlpha * 0.22)),
            (0.58, color(0xFFFFFF, 0.00)),
        ]), start: CGPoint(x: G / 2, y: G), end: CGPoint(x: G / 2, y: 0), options: [])
    }
    ctx.restoreGState()

    let basket = basketPath()
    let radius = G * 0.016

    // 3 — Schatten des Wagens, nach unten versetzt. Mittig gesetzt läse
    //     er sich als Schein und drückte das Motiv flach.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -G * 0.016), blur: G * 0.030,
                  color: color(pal.cartShadow, 0.55))
    ctx.setFillColor(color(pal.inkBottom))
    ctx.setStrokeColor(color(pal.inkBottom))
    fillRounded(ctx, basket, radius: radius)
    for cx in wheelXs {
        let c = pt(CGPoint(x: cx, y: wheelY))
        let r = cartWidth * wheelR
        ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }
    ctx.restoreGState()

    // 4 — Korb mit eigenem Verlauf: oben Licht, unten Schatten. Derselbe
    //     Gedanke wie bei der Fläche, eine Stufe kleiner.
    ctx.saveGState()
    ctx.setFillColor(color(pal.inkTop))
    ctx.setStrokeColor(color(pal.inkTop))
    fillRounded(ctx, basket, radius: radius)
    ctx.addPath(basket)
    ctx.setLineJoin(.round); ctx.setLineWidth(radius * 2)
    ctx.replacePathWithStrokedPath()
    ctx.addPath(basket)
    ctx.clip()
    ctx.drawLinearGradient(gradient([
        (0.00, color(pal.inkTop)),
        (1.00, color(pal.inkBottom)),
    ]), start: CGPoint(x: G / 2, y: pt(topLeft).y), end: CGPoint(x: G / 2, y: pt(bottomLeft).y),
       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // 5 — Streben als echte Aussparungen: der gemerkte Grund wird
    //     schlitzförmig zurückgezeichnet. Eine geratene Volltonfarbe
    //     säße neben dem Verlauf und würde als Strich sichtbar.
    ctx.saveGState()
    let slots = CGMutablePath()
    for t in strutTs {
        var a = lerp(pt(topLeft), pt(topRight), t)
        var b = lerp(pt(bottomLeft), pt(bottomRight), t)
        let dx0 = b.x - a.x, dy0 = b.y - a.y
        let len0 = max(sqrt(dx0 * dx0 + dy0 * dy0), 0.0001)
        // Unten hinaus verlängern, oben unter dem Rand anfangen.
        //
        // Zwei Fehler stecken in dieser Zeile. Zuerst endeten die
        // Schlitze auf der ungedehnten Kontur — `fillRounded` zieht den
        // Korb um den Eckenradius auf, also standen sie als drei kurze
        // Striche frei in der Fläche. Dann durchgehend geschnitten: der
        // Korb zerfiel in vier einzelne Keile, weil auch der obere Rand
        // durchtrennt war. Ein echter Korb hat einen geschlossenen Rand,
        // darunter die Drähte — das hält ihn zugleich als **einen**
        // Gegenstand zusammen.
        let over = G * 0.034
        a = lerp(a, b, 0.16)
        b = CGPoint(x: b.x + dx0 / len0 * over, y: b.y + dy0 / len0 * over)
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(sqrt(dx * dx + dy * dy), 0.0001)
        let nx = -dy / len * strutWidth / 2, ny = dx / len * strutWidth / 2
        slots.move(to: CGPoint(x: a.x + nx, y: a.y + ny))
        slots.addLine(to: CGPoint(x: b.x + nx, y: b.y + ny))
        slots.addLine(to: CGPoint(x: b.x - nx, y: b.y - ny))
        slots.addLine(to: CGPoint(x: a.x - nx, y: a.y - ny))
        slots.closeSubpath()
    }
    ctx.addPath(slots)
    ctx.clip()
    ctx.draw(fieldImage, in: full)
    ctx.restoreGState()

    // 6 — Glanz auf der Korboberkante, gleiche Idee wie am Rand.
    ctx.saveGState()
    ctx.addPath(basket)
    ctx.clip()
    ctx.setLineWidth(G * 0.006)
    let rim = CGMutablePath()
    rim.move(to: pt(topLeft)); rim.addLine(to: pt(topRight))
    ctx.addPath(rim)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    // Zu den Enden hin auslaufen. Auf voller Breite gleich hell gezogen
    // liest sich die Kante als vergessener Strich, nicht als Licht —
    // ein Glanz hat einen Ort.
    ctx.drawLinearGradient(gradient([
        (0.00, color(0xFFFFFF, 0.00)),
        (0.30, color(0xFFFFFF, pal.specAlpha)),
        (1.00, color(0xFFFFFF, 0.00)),
    ]), start: pt(topLeft), end: pt(topRight), options: [])
    ctx.restoreGState()

    // 7 — Griff, mit demselben Verlauf wie der Korb. Als einfarbiger
    //     Strich gezeichnet klebte er als flache Linie auf einem
    //     schattierten Körper; ein Gegenstand wird von **einem** Licht
    //     beleuchtet, nicht teilweise.
    ctx.saveGState()
    let handle = CGMutablePath()
    handle.move(to: pt(handleEnd))
    handle.addLine(to: pt(handleElbow))
    handle.addLine(to: pt(topLeft))
    ctx.setLineWidth(G * 0.034)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(handle)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(gradient([
        (0.00, color(pal.inkTop)),
        (1.00, color(pal.inkBottom)),
    ]), start: CGPoint(x: G / 2, y: pt(handleEnd).y), end: CGPoint(x: G / 2, y: pt(bottomLeft).y),
       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // 8 — Räder: eigener Verlauf und ein kurzer Aufsetzschatten, damit
    //     sie auf der Fläche stehen statt darauf zu kleben.
    for cx in wheelXs {
        let c = pt(CGPoint(x: cx, y: wheelY))
        let r = cartWidth * wheelR
        let box = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -G * 0.008), blur: G * 0.016,
                      color: color(pal.cartShadow, 0.50))
        ctx.setFillColor(color(pal.inkBottom))
        ctx.fillEllipse(in: box)
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addEllipse(in: box)
        ctx.clip()
        ctx.drawLinearGradient(gradient([
            (0.00, color(pal.inkTop)),
            (1.00, color(pal.inkBottom)),
        ]), start: CGPoint(x: c.x, y: box.maxY), end: CGPoint(x: c.x, y: box.minY), options: [])
        ctx.restoreGState()
    }
}

// MARK: - Rendern

func context(_ side: Int) -> CGContext {
    CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
              space: srgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
}

/// In 4× zeichnen und herunterrechnen statt gleich in Zielgröße:
/// Verläufe und Glanzlichter brauchen den Spielraum, und das hochwertige
/// Herunterrechnen von CoreGraphics schlägt sein eigenes Kantenglätten
/// bei kleinen Größen deutlich.
func render(side: Int, _ pal: Palette) -> CGImage {
    let hi = context(side * 4)
    drawIcon(into: hi, side: CGFloat(side * 4), pal)
    let big = hi.makeImage()!
    let out = context(side)
    out.interpolationQuality = .high
    out.draw(big, in: CGRect(x: 0, y: 0, width: side, height: side))
    return out.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try! png.write(to: url)
    print("geschrieben: \(url.path)")
}

let args = CommandLine.arguments
guard args.count > 1 else {
    FileHandle.standardError.write(Data("Zielordner fehlt.\n".utf8))
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1])
let images = palettes.map { ($0, render(side: 1024, $0)) }
for (pal, img) in images {
    write(img, to: outDir.appendingPathComponent("\(pal.name).png"))
}

// MARK: - Prüfbogen

/// Die echten iOS-Stufen, 1:1 in Pixeln. Nicht 16/32/64 — das sind
/// Mac-Größen; iOS rechnet aus der 1024er Datei 40 (Mitteilung), 58/87
/// (Einstellungen), 80/120 (Spotlight) und 120/180 (Homescreen).
///
/// Der Bogen ist kein Beiwerk. Zweimal hat er hier eine Entscheidung
/// widerlegt, die bei 1024 richtig aussah: die Räder liefen mit ihrem
/// alten Radius bei 40 px mit dem Korb zu einer Masse zusammen, und ein
/// stärkerer Keil im Korb sah unten gut aus und wurde oben zur
/// Kehrschaufel. Nur auf die kleinste Größe zu schauen verdirbt die
/// größten — man braucht beide nebeneinander.
if let i = args.firstIndex(of: "--pruefbogen"), i + 1 < args.count {
    let sheetDir = URL(fileURLWithPath: args[i + 1])
    let sizes: [CGFloat] = [180, 120, 87, 80, 58, 40]

    func masked(_ img: CGImage, _ side: CGFloat) -> CGImage {
        let c = CGContext(data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8,
                          bytesPerRow: 0, space: srgb,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.interpolationQuality = .high
        let r = CGRect(x: 0, y: 0, width: side, height: side)
        c.addPath(squircle(in: r)); c.clip()
        c.draw(img, in: r)
        return c.makeImage()!
    }

    let gap: CGFloat = 26, labelW: CGFloat = 250, rowGap: CGFloat = 30, header: CGFloat = 46
    let rowW = sizes.reduce(0, +) + gap * CGFloat(sizes.count - 1)
    let w = labelW + rowW + gap * 2
    let rowH: CGFloat = 180 + rowGap
    let h = CGFloat(images.count) * rowH + header + rowGap

    let sheet = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8,
                          bytesPerRow: 0, space: srgb,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    sheet.interpolationQuality = .high
    sheet.setFillColor(color(0x2A2A2E))
    sheet.fill(CGRect(x: 0, y: 0, width: w, height: h))

    func label(_ s: String, _ p: CGPoint, _ size: CGFloat) {
        let f = NSFont.systemFont(ofSize: size, weight: .medium)
        let a = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: NSColor.white])
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: sheet, flipped: false)
        a.draw(at: p)
        NSGraphicsContext.restoreGraphicsState()
    }

    var hx = labelW
    for s in sizes { label("\(Int(s))", CGPoint(x: hx, y: h - header + 14), 18); hx += s + gap }

    for (i, pair) in images.enumerated() {
        let cy = h - header - rowGap - CGFloat(i) * rowH - 180
        label(pair.0.name, CGPoint(x: 16, y: cy + 84), 19)
        var x = labelW
        for s in sizes {
            sheet.draw(masked(pair.1, s), in: CGRect(x: x, y: cy + (180 - s) / 2, width: s, height: s))
            x += s + gap
        }
    }
    write(sheet.makeImage()!, to: sheetDir.appendingPathComponent("icon-pruefbogen.png"))
}
