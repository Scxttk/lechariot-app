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

let variants = [
    // Hell: das Markengrün der App, reines Weiß — wie frisch emailliert.
    Variant(name: "icon-light-1024", enamel: rgb(0x3F6444), ink: rgb(0xFFFFFF)),
    // Dunkel: tieferes Grün, und die Schrift in der Creme der App statt in
    // Weiß — Weiß glänzt nachts auf dem Homescreen unangenehm auf.
    Variant(name: "icon-dark-1024", enamel: rgb(0x24402C), ink: rgb(0xEDE9C0)),
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

    // Schrift: "LE" klein oben, "CHARIOT" groß darunter — die Aufteilung der
    // Pariser Straßenschilder ("RUE DE" über dem Namen). "CHARIOT" bestimmt
    // die Größe, weil es die längere Zeile ist; "LE" folgt in fester Relation.
    let bigTracking: CGFloat = 0.06
    let big = fittedSize("CHARIOT", tracking: bigTracking, maxWidth: hairline.width * 0.90)
    let small = big * 0.46

    // Der Satz wird als Block über seine Versalhöhen zentriert.
    let capBig = serif(big).capHeight
    let capSmall = serif(small).capHeight
    let gap = capBig * 0.55
    let blockHeight = capSmall + gap + capBig

    // Kleiner optischer Hub: geometrisch mittig wirkt der Block zu tief,
    // weil die große Zeile die untere Hälfte allein trägt.
    let bigBaseline = hairline.midY - blockHeight / 2 + capBig * 0.12
    let smallBaseline = bigBaseline + capBig + gap

    drawLine("LE", in: ctx, size: small, tracking: 0.26,
             baseline: smallBaseline, color: v.ink)
    drawLine("CHARIOT", in: ctx, size: big, tracking: bigTracking,
             baseline: bigBaseline, color: v.ink)

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
