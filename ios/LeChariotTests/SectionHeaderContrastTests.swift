import SwiftUI
import UIKit
import XCTest
@testable import LeChariot

/// **Die Farbe, die keine Aufrufstelle setzt — und die deshalb keiner prüft.**
///
/// Abschnittsüberschriften und -fußnoten einer `List` bekommen ihre Farbe von
/// der zweiten Ebene des umgebenden Vordergrundstils. Steht dort nichts, ist es
/// Apples `secondaryLabel`, abgestimmt auf Weiß und Schwarz. Auf der Creme
/// reichte er immer knapp; mit der Palette vom 06.08. reicht er nicht mehr.
///
/// **Am 07.08. fiel das in einem Journey-Lauf auf — nach 100 Sekunden, in
/// Apples Audit, auf sechs Bildschirmen gleichzeitig.** `PaletteContrastTests`
/// war grün und blieb es: Der prüft die Werte im `Theme`, und Apples
/// `secondaryLabel` steht dort nicht. Zwischen „jeder Token ist sauber" und
/// „jeder Text ist sauber" lag genau diese Lücke.
///
/// Dieser Bogen misst deshalb nicht den Token, sondern die **gezeichnete
/// Zeile**: Eine `List` mit Überschrift und Fußnote wird gerendert, die
/// dunkelsten Punkte der Schrift werden gelesen, und daraus wird der Kontrast
/// gegen die Fläche gerechnet, auf der sie stehen.
@MainActor
final class SectionHeaderContrastTests: XCTestCase {
    /// AA für Fließtext. Überschrift und Fußnote sind Fußnotengröße, also gilt
    /// die strenge Schwelle und nicht die 3:1 für große Schrift.
    private let aa = 4.5

    func testTheSectionHeaderIsReadableOnTheThemedScreen() throws {
        let gemessen = try contrastOfDarkestGlyph(in: probe)
        XCTAssertGreaterThanOrEqual(
            gemessen, aa,
            "Abschnittsüberschriften stehen bei \(String(format: "%.2f", gemessen)):1 auf der Fläche — "
            + "das ist wieder Apples secondaryLabel, nicht Theme.secondaryText"
        )
    }

    /// Die Gegenprobe, damit der Bogen nicht „alles ist dunkel genug" heißt:
    /// **Ohne** `themedScreen()` muss dieselbe Liste durchfallen. Fiele auch
    /// das nicht auf, misst der Test die Schrift gar nicht.
    func testWithoutTheThemedScreenTheSameListWouldFail() throws {
        let gemessen = try contrastOfDarkestGlyph(in: probeOhneTheme)
        XCTAssertLessThan(
            gemessen, aa,
            "Apples secondaryLabel schafft auf dieser Fläche plötzlich AA — dann misst dieser Bogen "
            + "nicht die Schrift, sondern irgendetwas anderes"
        )
    }

    // MARK: Der Bogen

    private var probe: some View {
        List {
            Section {
                // **Keine Zeile mit Text.** Der erste Anlauf hatte hier
                // „Eine Zeile" stehen und maß am Ende deren Schwarz: Der
                // dunkelste Punkt des Bildes war der Primärtext, nicht die
                // Überschrift, und der Gegenprobe-Bogen meldete 15,4:1 für
                // eine Farbe, die bei 3,04:1 liegt. Ohne Text im Rumpf sind
                // Überschrift und Fußnote das einzige Geschriebene.
                Color.clear.frame(height: 1)
            } header: {
                Text("Einkaufen")
            } footer: {
                Text("Zurücksetzen löscht alles, was auf dem Gerät liegt.")
            }
            .listRowBackground(Theme.surface)
        }
        .themedScreen()
    }

    private var probeOhneTheme: some View {
        List {
            Section {
                Color.clear.frame(height: 1)
            } header: {
                Text("Einkaufen")
            } footer: {
                Text("Zurücksetzen löscht alles, was auf dem Gerät liegt.")
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background { Theme.background }
    }

    /// Kontrast des dunkelsten Punktes der Überschriftenzeile gegen die Fläche.
    ///
    /// **Der dunkelste Punkt und nicht der Mittelwert.** Schrift ist zu einem
    /// Großteil Kantenglättung; ein Mittelwert über die Zeile misst überwiegend
    /// Hintergrund und meldet jede Farbe als grenzwertig. Was die Lesbarkeit
    /// trägt, ist der volle Strich.
    private func contrastOfDarkestGlyph(in view: some View) throws -> Double {
        let size = CGSize(width: 393, height: 240)
        let host = UIHostingController(rootView: AnyView(view).frame(width: size.width, height: size.height))
        host.overrideUserInterfaceStyle = .light
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        let cg = try XCTUnwrap(image.cgImage)

        var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        let ctx = try XCTUnwrap(CGContext(
            data: &pixels, width: cg.width, height: cg.height, bitsPerComponent: 8,
            bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))

        var dunkelste = 1.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let l = luminance(Double(pixels[i]) / 255,
                              Double(pixels[i + 1]) / 255,
                              Double(pixels[i + 2]) / 255)
            dunkelste = min(dunkelste, l)
        }
        let flaeche = luminance(0.890, 0.871, 0.722)   // Theme.background, hell
        return (flaeche + 0.05) / (dunkelste + 0.05)
    }

    private func luminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
        func lin(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }
}
