import SwiftUI
import UIKit
import XCTest

/// **Ein Bild von dem, was das Gerät zeigt** — der Umweg über ein echtes
/// Fenster, den sich die Prüfbögen des Unit-Ziels teilen.
///
/// **Warum `drawHierarchy` und nicht `ImageRenderer`.** Eine `List` ist
/// UIKit-getragen; `ImageRenderer` bekommt davon eine leere Fläche. Der Umweg
/// über ein Fenster kostet zwei Zeilen und liefert das, was der Bildschirm
/// zeigt — samt Trennlinien, Einzügen und Abschnittsköpfen.
///
/// **Das Fenster muss an eine Szene.** Ein frei gebautes `UIWindow` gehört zu
/// keinem Bildschirm, und `drawHierarchy` zeichnet dann eine weiße Fläche —
/// sechs bitgleiche PNGs, erst am `md5` gemerkt.
///
/// **Die Bilder gehen als Anhang ins `.xcresult`**, nicht in einen Ordner:
///
///     tools/tests.sh KachelFahneShots --result /tmp/bogen.xcresult
///     xcrun xcresulttool export attachments --path /tmp/bogen.xcresult \
///       --output-path /tmp/bogen
@MainActor
extension XCTestCase {
    /// iPhone-Breite in Punkten, Höhe großzügig: Ein zu knapper Ausschnitt
    /// schneidet genau die Zeile ab, um die es geht.
    nonisolated static var bogenGroesse: CGSize { CGSize(width: 393, height: 800) }

    /// `ruhe`: wie lange das Fenster laufen darf, bevor das Bild fällt. Die
    /// Vorgabe reicht für Zellen, die beim Layout entstehen; wer eine Ansicht
    /// mit Einblend-Animation fotografiert (`TipView`), braucht mehr — sonst
    /// steht sie halbdurchsichtig im Bild und man beurteilt die Animation.
    func schreibeBogen(_ inhalt: some View, named name: String,
                       scheme: ColorScheme,
                       groesse: CGSize = XCTestCase.bogenGroesse,
                       ruhe: TimeInterval = 0.35) throws {
        let host = UIHostingController(
            rootView: inhalt
                .environment(\.colorScheme, scheme)
                .frame(width: groesse.width, height: groesse.height)
        )
        host.overrideUserInterfaceStyle = scheme == .light ? .light : .dark

        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: groesse)
        window.overrideUserInterfaceStyle = host.overrideUserInterfaceStyle
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        // Eine Umlaufrunde: Ohne sie steht die Liste im ersten Bild noch leer,
        // weil ihre Zellen erst beim Layout entstehen.
        RunLoop.current.run(until: Date().addingTimeInterval(ruhe))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: groesse, format: format).image { _ in
            window.drawHierarchy(in: CGRect(origin: .zero, size: groesse),
                                 afterScreenUpdates: true)
        }
        let png = try XCTUnwrap(image.pngData())
        let anhang = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        anhang.name = name
        anhang.lifetime = .keepAlways
        add(anhang)
    }
}
