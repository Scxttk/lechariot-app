// Liest die Artikelnamen aus Bildschirmabzügen — Apples Vision, kein fremdes Werkzeug.
//
// Aufruf:  swift ocr.swift <ordner mit png>   → eine Zeile je erkanntem Text:
//          datei<TAB>y<TAB>x<TAB>r,g,b<TAB>text
//
// **Die Farbe entscheidet, ob es ein Artikel ist.** Bring! setzt jede Kachel auf
// eine mintgrüne Fläche (im Katalog) oder eine lachsrote (steht auf der Liste);
// Kopfzeile, Kategorieliste und Tab-Leiste liegen auf dem dunklen Grund. Ein
// Punkt knapp **über** der Beschriftung trifft die Kachel selbst und trennt die
// Artikelnamen von allem anderen — zuverlässiger als jede Schwelle auf y.
import Foundation
import Vision
import AppKit

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let files = (try? FileManager.default.contentsOfDirectory(atPath: dir))?
    .filter { $0.hasSuffix(".png") }.sorted() ?? []

for name in files {
    let path = (dir as NSString).appendingPathComponent(name)
    guard let image = NSImage(contentsOfFile: path),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { continue }

    let w = cg.width, h = cg.height
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(
        data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

    func colour(atX fx: Double, y fy: Double) -> (Int, Int, Int) {
        let px = min(w - 1, max(0, Int(fx * Double(w))))
        let py = min(h - 1, max(0, Int(fy * Double(h))))
        let i = (py * w + px) * 4
        return (Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]))
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // Deutsch zuerst: „Möhren" wird sonst gern „Mohren".
    request.recognitionLanguages = ["de-DE", "en-US"]
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try? handler.perform([request])

    for observation in (request.results ?? []) {
        guard let top = observation.topCandidates(1).first else { continue }
        let b = observation.boundingBox
        // Vision misst y von unten; hier auf „von oben" gedreht, damit die
        // Zahl mit dem Bild übereinstimmt, das man ansieht.
        let y = 1 - b.midY
        let (r, g, bl) = colour(atX: b.midX, y: y - 0.012)
        print("\(name)\t\(String(format: "%.4f", y))\t\(String(format: "%.4f", b.midX))\t\(r),\(g),\(bl)\t\(top.string)")
    }
}
