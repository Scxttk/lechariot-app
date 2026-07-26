// Le-Chariot-App-Icon: französisches Emailschild.
//
// Aufbau von außen nach innen, so wie die echten Schilder gebaut sind:
// randvolle Emaillefläche → schmaler weißer Rand → dünne Innenlinie →
// zweizeilige Serifenschrift in Versalien.
//
// Kein abgerundeter Außenrahmen: iOS maskiert das Icon selbst.
//
// Bauen und laufen lassen:
//   swiftc -O icon.swift -o icon && ./icon <zielordner>

import AppKit
import CoreGraphics
import Foundation

let SIZE: CGFloat = 1024

/// Was im Schild steht.
enum Layout { case cart, cartAndWordmark }

let layout: Layout = CommandLine.arguments.contains("--wortmarke") ? .cartAndWordmark : .cart

struct Variant {
    let name: String
    let enamel: NSColor
    let ink: NSColor
}

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

// Hell und dunkel tragen dieselben Farben: tiefes Grün, Creme statt Weiß.
// Ein Emailschild wechselt seine Farbe nicht mit der Tageszeit — und Creme
// glänzt nachts nicht so auf wie reines Weiß.
let enamel = rgb(0x24402C)
let ink = rgb(0xEDE9C0)

let variants = [
    Variant(name: "icon-light-1024", enamel: enamel, ink: ink),
    Variant(name: "icon-dark-1024", enamel: enamel, ink: ink),
    // Getönt: iOS erwartet Graustufen und legt den Farbton selbst darüber.
    Variant(name: "icon-tinted-1024", enamel: rgb(0x1C1C1C), ink: rgb(0xF2F2F2)),
]

// Georgia Bold statt Didot: Didots Haarstriche verschwinden beim
// Herunterrechnen auf Homescreen-Größe, Georgia hält die Strichstärke.
func serif(_ size: CGFloat) -> NSFont {
    NSFont(name: "Georgia-Bold", size: size) ?? NSFont(name: "Times-Bold", size: size)!
}

func attributed(_ text: String, size: CGFloat, tracking: CGFloat, color: NSColor) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [
        .font: serif(size),
        .foregroundColor: color,
        .kern: tracking * size,
    ])
}

/// Breite einer Zeile ohne die Sperrung hinter dem letzten Zeichen — die
/// zählt Cocoa mit, sonst säße die Zeile um ein halbes Tracking nach links.
func lineWidth(_ s: NSAttributedString, tracking: CGFloat, size: CGFloat) -> CGFloat {
    s.boundingRect(with: .zero, options: .usesLineFragmentOrigin).width - tracking * size
}

/// Größte Schriftgröße, bei der `text` noch in `maxWidth` passt.
func fittedSize(_ text: String, tracking: CGFloat, maxWidth: CGFloat) -> CGFloat {
    let probe: CGFloat = 100
    let w = lineWidth(attributed(text, size: probe, tracking: tracking, color: .white),
                      tracking: tracking, size: probe)
    return probe * maxWidth / w
}

/// Zeichnet eine Zeile Versalien horizontal mittig auf der Grundlinie
/// `baseline`. Über die Grundlinie statt über die Bounding-Box, weil die
/// Box Ober- und Unterlängen mitzählt, die Versalien gar nicht haben — sonst
/// sitzt der Satz optisch zu tief.
func drawLine(
    _ text: String, in ctx: CGContext, size: CGFloat,
    tracking: CGFloat, baseline: CGFloat, color: NSColor
) {
    let line = attributed(text, size: size, tracking: tracking, color: color)
    let width = lineWidth(line, tracking: tracking, size: size)
    let origin = CGPoint(x: (SIZE - width) / 2, y: baseline + serif(size).descender)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    line.draw(at: origin)
    NSGraphicsContext.restoreGraphicsState()
}

/// Einkaufswagen, gezeichnet in einem Einheitsquadrat (0…1, y nach oben) und
/// per `rect` an seinen Platz gerechnet. Griff und Korb sind Striche, die
/// Räder Flächen — gestrichelte Räder verschwinden in Homescreen-Größe.
func drawCart(in ctx: CGContext, rect: CGRect, color: NSColor, weight: CGFloat) {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }

    ctx.setStrokeColor(color.cgColor)
    ctx.setFillColor(color.cgColor)
    ctx.setLineWidth(weight)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    let topLeft = p(0.26, 0.66)
    let topRight = p(1.00, 0.66)
    let bottomRight = p(0.84, 0.34)
    let bottomLeft = p(0.38, 0.34)

    // Griff: kurzes Stück waagerecht, dann schräg hinunter an den Korb.
    ctx.move(to: p(0.00, 0.93))
    ctx.addLine(to: p(0.13, 0.93))
    ctx.addLine(to: topLeft)
    ctx.strokePath()

    // Korb als geschlossenes Trapez.
    ctx.move(to: topLeft)
    ctx.addLine(to: topRight)
    ctx.addLine(to: bottomRight)
    ctx.addLine(to: bottomLeft)
    ctx.closePath()
    ctx.strokePath()

    // Zwei Streben. Sie folgen der Schräge des Korbs, sonst stünden sie
    // senkrecht in einem Gitter, das sich nach unten verjüngt.
    for t in [0.34, 0.67] as [CGFloat] {
        let top = CGPoint(x: topLeft.x + (topRight.x - topLeft.x) * t,
                          y: topLeft.y + (topRight.y - topLeft.y) * t)
        let bottom = CGPoint(x: bottomLeft.x + (bottomRight.x - bottomLeft.x) * t,
                             y: bottomLeft.y + (bottomRight.y - bottomLeft.y) * t)
        ctx.move(to: top)
        ctx.addLine(to: bottom)
    }
    ctx.strokePath()

    // Räder
    let r = rect.width * 0.095
    for cx in [0.47, 0.79] as [CGFloat] {
        let c = p(cx, 0.13)
        ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }
    ctx.fillPath()
}

func render(_ v: Variant, to url: URL) throws {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: Int(SIZE), height: Int(SIZE),
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("Kontext nicht erzeugbar") }

    // Emaillefläche
    ctx.setFillColor(v.enamel.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: SIZE, height: SIZE))

    // Weißer Außenrand. Die Kante bleibt frei, damit die Squircle-Maske von
    // iOS nicht in den Rand schneidet.
    let inset: CGFloat = SIZE * 0.062
    let border: CGFloat = SIZE * 0.036
    let outer = CGRect(x: inset, y: inset, width: SIZE - 2 * inset, height: SIZE - 2 * inset)
    ctx.setFillColor(v.ink.cgColor)
    ctx.addPath(CGPath(roundedRect: outer, cornerWidth: SIZE * 0.055, cornerHeight: SIZE * 0.055, transform: nil))
    ctx.fillPath()

    // Innenfeld wieder in Emaille
    let field = outer.insetBy(dx: border, dy: border)
    ctx.setFillColor(v.enamel.cgColor)
    ctx.addPath(CGPath(roundedRect: field, cornerWidth: SIZE * 0.030, cornerHeight: SIZE * 0.030, transform: nil))
    ctx.fillPath()

    // Dünne Innenlinie — das Detail, an dem man die echten Schilder erkennt.
    let hairline = field.insetBy(dx: SIZE * 0.042, dy: SIZE * 0.042)
    ctx.setStrokeColor(v.ink.cgColor)
    ctx.setLineWidth(SIZE * 0.011)
    ctx.addPath(CGPath(roundedRect: hairline, cornerWidth: SIZE * 0.018, cornerHeight: SIZE * 0.018, transform: nil))
    ctx.strokePath()

    switch layout {
    case .cart:
        // Der Wagen allein, groß im Feld — bei Homescreen-Größe ist das die
        // einzige Fassung, die man auf einen Blick erkennt.
        let w = hairline.width * 0.72
        let h = w * 0.86
        // Nach links gerückt: die Bounding-Box reicht bis zum Griffende, die
        // sichtbare Masse ist aber der Korb — mittig gesetzt säße der Wagen
        // spürbar rechts.
        let box = CGRect(x: hairline.midX - w / 2 - w * 0.07,
                         y: hairline.midY - h / 2, width: w, height: h)
        drawCart(in: ctx, rect: box, color: v.ink, weight: SIZE * 0.040)

    case .cartAndWordmark:
        // Wagen oben, Wortmarke darunter — trägt den Namen mit, kostet aber
        // Erkennbarkeit, weil beides kleiner ausfallen muss.
        let w = hairline.width * 0.44
        let h = w * 0.86
        let box = CGRect(x: hairline.midX - w / 2,
                         y: hairline.midY + hairline.height * 0.03,
                         width: w, height: h)
        drawCart(in: ctx, rect: box, color: v.ink, weight: SIZE * 0.030)

        let tracking: CGFloat = 0.10
        let size = fittedSize("LE CHARIOT", tracking: tracking, maxWidth: hairline.width * 0.78)
        drawLine("LE CHARIOT", in: ctx, size: size, tracking: tracking,
                 baseline: hairline.minY + hairline.height * 0.13, color: v.ink)
    }

    guard let image = ctx.makeImage() else { fatalError("Bild nicht erzeugbar") }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG nicht erzeugbar")
    }
    try png.write(to: url)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
for v in variants {
    let url = outDir.appendingPathComponent("\(v.name).png")
    try render(v, to: url)
    print("geschrieben: \(url.path)")
}
