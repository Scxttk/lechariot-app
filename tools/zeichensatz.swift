// Prüfbogen für den Kategorie-Zeichensatz: der eigene Satz neben den
// SF Symbols, bei **den Größen, die die App wirklich benutzt**, hell und
// dunkel.
//
// Warum offline und nicht im Simulator: Eine Runde Zeichnen–Ansehen dauert
// hier zwei Sekunden statt zwei Minuten. Dieselbe Methode wie bei den
// Spektrumbalken von Côte d'OS — nicht raten, nachsehen. Der Simulator
// entscheidet am Ende trotzdem; der Prüfbogen entscheidet nur, was dort
// überhaupt ankommt.
//
// Die Größen sind aus `Theme.swift` gerechnet, nicht gewählt:
//   Listenzeile  32 pt Kachel × 0,5 × 0,82 = 13,1 pt
//   Angebotszeile 48 pt Kachel × 0,5 × 0,82 = 19,7 pt
//   Detailblatt  200 pt Bild  × 0,4 × 0,82 = 65,6 pt
//
// Bauen und laufen lassen:
//   swiftc -O tools/zeichensatz.swift ios/LeChariot/DesignSystem/CategoryGlyphs.swift \
//     ios/LeChariot/DesignSystem/ItemGlyphs.swift \
//     -o /tmp/zeichensatz && /tmp/zeichensatz /tmp/zeichensatz.png
//
// Zweites Argument `artikel`: derselbe Bogen für den **Artikel**-Zeichensatz,
// achtzig Zeichnungen statt fünfzehn.
//
//   /tmp/zeichensatz /tmp/artikel.png artikel
//
// **Warum der in Seiten zerfällt und der Kategoriebogen nicht.** Achtzig
// Zeichnungen auf einem Blatt ergeben ein Bild, das beim Ansehen kleingerechnet
// wird — und dann ist die 13-pt-Fassung genau das, was man nicht mehr
// beurteilen kann. Zwanzig je Seite halten das Blatt unter der Breite, ab der
// skaliert wird; die kleinen Fassungen stehen damit so im Bild, wie sie das
// Gerät zeigt.
import AppKit
import SwiftUI

let groessen: [CGFloat] = [13.1, 19.7, 65.6]

let kategorien = [
    "Obst & Gemüse", "Molkerei & Eier", "Fleisch & Wurst", "Fisch", "Backwaren",
    "Tiefkühl", "Süßes & Snacks", "Getränke", "Alkohol", "Vorräte & Kochen",
    "Drogerie", "Haushalt", "Tierbedarf", "Kinder", "Sonstiges",
]

let systemzeichen = [
    "carrot", "waterbottle", "fork.knife", "fish", "birthday.cake",
    "snowflake", "popcorn", "cup.and.saucer", "wineglass", "frying.pan",
    "comb", "house", "pawprint", "teddybear", "basket",
]

// Die Palette aus Theme.swift, hell und dunkel.
let creme = Color(red: 0.929, green: 0.914, blue: 0.753)
let gruenHell = Color(red: 0.247, green: 0.392, blue: 0.267)
let schiefer = Color(red: 0.106, green: 0.114, blue: 0.098)
let gruenDunkel = Color(red: 0.569, green: 0.729, blue: 0.588)

/// Eine Zeile: alle 15 Zeichen einer Herkunft in einer Größe.
struct Reihe: View {
    let titel: String
    let gezeichnet: Bool
    let groesse: CGFloat
    let farbe: Color
    let flaeche: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(titel).font(.system(size: 9)).frame(width: 96, alignment: .leading)
                .foregroundStyle(farbe)
            ForEach(Array(kategorien.enumerated()), id: \.offset) { i, name in
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(flaeche.opacity(0.001))
                    if gezeichnet {
                        CategoryGlyphView(category: name, size: groesse)
                            .foregroundStyle(farbe)
                    } else {
                        Image(systemName: systemzeichen[i])
                            .font(.system(size: groesse))
                            .foregroundStyle(farbe)
                    }
                }
                .frame(width: 72, height: 72)
            }
        }
    }
}

struct Bogen: View {
    let farbe: Color
    let flaeche: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("").frame(width: 96)
                ForEach(kategorien, id: \.self) { name in
                    Text(name).font(.system(size: 7)).foregroundStyle(farbe)
                        .frame(width: 72)
                }
            }
            ForEach(Array(groessen.enumerated()), id: \.offset) { _, g in
                Reihe(titel: "SF \(String(format: "%.1f", g)) pt", gezeichnet: false,
                      groesse: g, farbe: farbe, flaeche: flaeche)
                Reihe(titel: "eigen \(String(format: "%.1f", g)) pt", gezeichnet: true,
                      groesse: g, farbe: farbe, flaeche: flaeche)
            }
        }
        .padding(16)
        .background(flaeche)
    }
}

struct Prüfbogen: View {
    var body: some View {
        VStack(spacing: 0) {
            Bogen(farbe: gruenHell, flaeche: creme)
            Bogen(farbe: gruenDunkel, flaeche: schiefer)
        }
    }
}

// MARK: - Der Artikelbogen

/// Eine Zelle: dieselbe Zeichnung dreimal — groß zum Beurteilen der Form,
/// klein zum Beurteilen, ob sie das überhaupt überlebt.
///
/// **Die kleinen Größen sind die, die die App wirklich zeigt.** Hier standen
/// 19,7 und 13,1 pt — gerechnet aus der Kachel der *Listenzeile*, aus der Zeit
/// vor dem Raster. Gezeichnet wird inzwischen mit `size: 40` in
/// `ShoppingGridTile` und `size: 22` in `ShoppingListView`; wer bei 13,1 pt
/// urteilt, prüft strenger als das Gerät und wirft Zeichnungen weg, die dort
/// nie ankommen.
struct ArtikelZelle: View {
    let begriff: String
    let farbe: Color

    var body: some View {
        VStack(spacing: 3) {
            ItemGlyphView(term: begriff, category: nil, size: 65.6)
                .foregroundStyle(farbe)
            HStack(alignment: .center, spacing: 12) {
                ItemGlyphView(term: begriff, category: nil, size: 40)
                    .foregroundStyle(farbe)
                ItemGlyphView(term: begriff, category: nil, size: 22)
                    .foregroundStyle(farbe)
            }
            .frame(height: 44)
            Text(begriff).font(.system(size: 8)).foregroundStyle(farbe)
        }
        .frame(width: 92, height: 132)
    }
}

struct ArtikelBogen: View {
    let begriffe: [String]
    let seite: Int
    let farbe: Color
    let flaeche: Color

    private let spalten = Array(repeating: GridItem(.fixed(92), spacing: 4), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Artikelzeichen · Seite \(seite) · 65,6 / 40 / 22 pt")
                .font(.system(size: 9)).foregroundStyle(farbe)
            LazyVGrid(columns: spalten, spacing: 4) {
                ForEach(begriffe, id: \.self) { ArtikelZelle(begriff: $0, farbe: farbe) }
            }
        }
        .padding(14)
        .background(flaeche)
    }
}

@main
enum Werkzeug {
    @MainActor static func main() {
        let ziel = CommandLine.arguments.count > 1
            ? CommandLine.arguments[1] : "/tmp/zeichensatz.png"
        let art = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "kategorien"

        if art == "artikel" {
            let stamm = ziel.hasSuffix(".png") ? String(ziel.dropLast(4)) : ziel
            // Dritter Parameter: eine Komma-Liste von Begriffen. Ohne ihn der
            // ganze Satz. **Wer zwanzig neue Zeichnungen prüft, will nicht
            // sechs Bögen mit hundert alten durchsehen** — und wer sie nicht
            // ansieht, zeichnet blind.
            let auswahl = CommandLine.arguments.count > 3
                ? CommandLine.arguments[3].split(separator: ",").map(String.init)
                : ItemGlyph.drawnTerms
            let alle = auswahl
            for (nummer, teil) in stride(from: 0, to: alle.count, by: 20)
                .map({ Array(alle[$0..<min($0 + 20, alle.count)]) }).enumerated() {
                schreibe(ArtikelBogen(begriffe: teil, seite: nummer + 1,
                                      farbe: gruenHell, flaeche: creme),
                         nach: "\(stamm)-\(nummer + 1)-hell.png")
                schreibe(ArtikelBogen(begriffe: teil, seite: nummer + 1,
                                      farbe: gruenDunkel, flaeche: schiefer),
                         nach: "\(stamm)-\(nummer + 1)-dunkel.png")
            }
            print("\(alle.count) Artikelzeichen, \(ItemGlyph.withoutDrawing.count) Ausnahmen")
        } else if art == "masse" {
            // Die Rahmen aller Artikelzeichen im 100er-Feld — die Zahlen, aus
            // denen die Schwellen in `ItemGlyphTests` stammen. Geschätzte
            // Schwellen haben beim Kategoriesatz sechs gesunde Zeichnungen
            // durchfallen lassen.
            let feld = CGRect(x: 0, y: 0, width: 100, height: 100)
            for begriff in ItemGlyph.drawnTerms {
                guard let z = ItemGlyph.drawing(for: begriff, in: feld) else { continue }
                let r = z.stroke.boundingRect.union(z.fill.boundingRect)
                print(String(format: "%@\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f\t%.1f",
                             begriff, r.minX, r.minY, r.maxX, r.maxY, r.width, r.height))
            }
        } else {
            schreibe(Prüfbogen(), nach: ziel)
        }
    }

    @MainActor private static func schreibe(_ inhalt: some View, nach ziel: String) {
        let renderer = ImageRenderer(content: inhalt)
        renderer.scale = 3
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("Rendern fehlgeschlagen\n".utf8))
            exit(1)
        }
        try? png.write(to: URL(fileURLWithPath: ziel))
        print("Prüfbogen: \(ziel) (\(rep.pixelsWide)×\(rep.pixelsHigh) px)")
    }
}
