import AppKit
import Foundation

// Le Chariot trailer title cards — French enamel sign look.
// Dark green plate, cream keyline, serif type, cream ground.
//
// Usage, from the repo root:   swift tools/trailer-cards.swift [outDir]
// Writes card1/2/3/4 and card_end as 1080x1920 PNGs (default: assets/trailer).
// Edit the copy at the bottom of this file; tools/trailer-build.sh cuts them
// together with the screen recording.

let W = 1080, H = 1920

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/trailer"
try? FileManager.default.createDirectory(atPath: outDir,
                                         withIntermediateDirectories: true)

let cream  = NSColor(srgbRed: 0xEC/255.0, green: 0xE6/255.0, blue: 0xBE/255.0, alpha: 1)
let green  = NSColor(srgbRed: 0x2E/255.0, green: 0x52/255.0, blue: 0x36/255.0, alpha: 1)
let green2 = NSColor(srgbRed: 0x3F/255.0, green: 0x62/255.0, blue: 0x45/255.0, alpha: 1)

func serif(_ size: CGFloat, weight: NSFont.Weight = .semibold) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    let d = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
    return NSFont(descriptor: d, size: size) ?? NSFont(name: "Times New Roman", size: size)!
}

func draw(_ name: String, _ body: (NSGraphicsContext, CGContext) -> Void) {
    let path = (outDir as NSString).appendingPathComponent(name)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .calibratedRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    body(ctx, ctx.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
    FileHandle.standardError.write("wrote \(path)\n".data(using: .utf8)!)
}

func fill(_ color: NSColor) {
    color.setFill()
    NSRect(x: 0, y: 0, width: W, height: H).fill()
}

/// The enamel plate: dark green rounded rect with an inset cream keyline.
func plate(_ rect: NSRect) {
    let outer = NSBezierPath(roundedRect: rect, xRadius: 44, yRadius: 44)
    green.setFill()
    outer.fill()
    let inset = rect.insetBy(dx: 22, dy: 22)
    let key = NSBezierPath(roundedRect: inset, xRadius: 28, yRadius: 28)
    cream.withAlphaComponent(0.92).setStroke()
    key.lineWidth = 5
    key.stroke()
}

func center(_ text: String, font: NSFont, color: NSColor, y: CGFloat, tracking: CGFloat = 0) {
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineHeightMultiple = 1.06
    var attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .paragraphStyle: para,
    ]
    if tracking != 0 { attrs[.kern] = tracking }
    let s = NSAttributedString(string: text, attributes: attrs)
    let box = NSRect(x: 60, y: y, width: CGFloat(W) - 120, height: 900)
    s.draw(with: box, options: [.usesLineFragmentOrigin])
}

func heightOf(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineHeightMultiple = 1.06
    let s = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: para])
    return s.boundingRect(with: NSSize(width: width, height: 2000),
                          options: [.usesLineFragmentOrigin]).height
}

/// A plate card: big line inside the enamel sign, optional caption underneath.
func plateCard(_ path: String, _ text: String, size: CGFloat = 104, caption: String? = nil) {
    draw(path) { _, _ in
        fill(cream)
        let f = serif(size, weight: .bold)
        let inner = CGFloat(W) - 120 - 140
        let th = heightOf(text, font: f, width: inner)
        let plateH = th + 260
        let plateRect = NSRect(x: 90, y: (CGFloat(H) - plateH) / 2, width: CGFloat(W) - 180, height: plateH)
        plate(plateRect)
        // NSAttributedString draws from the top of the given box downwards.
        let textTop = plateRect.maxY - (plateH - th) / 2
        center(text, font: f, color: cream, y: textTop - 900)
        if let c = caption {
            let cf = serif(40, weight: .regular)
            let ch = heightOf(c, font: cf, width: inner)
            center(c, font: cf, color: green2, y: plateRect.minY - 60 - ch - 900 + ch)
        }
    }
}

// ---------------------------------------------------------------- cards

plateCard("card1.png", "Acht Prospekte.\nEine Frage.", size: 112)
plateCard("card2.png", "Schreib deine Liste.", size: 100)
plateCard("card3.png", "Le Chariot nennt\nden einen Markt.", size: 92)
plateCard("card4.png", "Nicht vom\nHandel bezahlt.", size: 96)

// End card: icon, wordmark, line, beta note.
draw("card_end.png") { _, cg in
    fill(cream)
    let iconPath = "ios/LeChariot/Assets.xcassets/AppIcon.appiconset/icon-light-1024.png"
    if let img = NSImage(contentsOfFile: iconPath) {
        let side: CGFloat = 300
        let r = NSRect(x: (CGFloat(W) - side) / 2, y: 1080, width: side, height: side)
        let clip = NSBezierPath(roundedRect: r, xRadius: 66, yRadius: 66)
        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        img.draw(in: r)
        NSGraphicsContext.restoreGraphicsState()
        green2.withAlphaComponent(0.25).setStroke()
        clip.lineWidth = 3
        clip.stroke()
    }
    let name = serif(126, weight: .bold)
    center("Le Chariot", font: name, color: green, y: 960 - 900 + heightOf("Le Chariot", font: name, width: 900))
    let sub = serif(46, weight: .regular)
    center("Einkaufsliste ohne Beeinflussung", font: sub, color: green2,
           y: 860 - 900 + heightOf("Einkaufsliste ohne Beeinflussung", font: sub, width: 900))

    // rule
    green2.withAlphaComponent(0.35).setFill()
    NSRect(x: CGFloat(W) / 2 - 120, y: 790, width: 240, height: 3).fill()

    let note = serif(38, weight: .regular)
    center("Beta über TestFlight · iOS 17+", font: note, color: green2.withAlphaComponent(0.85),
           y: 700 - 900 + heightOf("Beta über TestFlight · iOS 17+", font: note, width: 900))
}
