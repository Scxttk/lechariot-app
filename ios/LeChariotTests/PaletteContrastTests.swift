import SwiftUI
import XCTest
@testable import LeChariot

/// **Die Palette, in beiden Modi nachgerechnet.**
///
/// Am 06.08. beim Farb-Audit gefunden: Fünfzehn Bildschirme sind auf Kontrast
/// geprüft, aber der Lauf für den dunklen Modus läuft mit
/// `failOnContrast: false`. **Kein Test bewachte den dunklen Modus** — jede
/// dunkle Zahl in den Notizen war ungeprüfte Rechnung.
///
/// Dieser Test rechnet selbst. Er braucht kein Gerät, keinen Bildschirm und
/// keine Scrollposition, und er sagt bei einem Fehlschlag die Zahl statt
/// „irgendwo ist etwas zu blass".
///
/// **Was er nicht kann:** Er prüft Farbpaare, nicht ihre Verwendung. Dass
/// `secondaryText` wirklich auf `surface` steht und nicht auf etwas anderem,
/// weiß nur der Audit-Lauf.
final class PaletteContrastTests: XCTestCase {

    // MARK: Rechnung

    /// Relative Leuchtdichte nach WCAG 2.1.
    private func luminance(_ color: Color, _ style: UIUserInterfaceStyle) -> Double {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private func ratio(_ a: Color, on b: Color, _ style: UIUserInterfaceStyle) -> Double {
        let la = luminance(a, style), lb = luminance(b, style)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static let modes: [(String, UIUserInterfaceStyle)] = [("hell", .light), ("dunkel", .dark)]

    // MARK: Text

    /// Fließtext braucht 4,5:1 — **in beiden Modi**, auf beiden Flächen.
    func testEveryTextTokenClearsAAOnBothPlanes() {
        let tokens: [(String, Color)] = [
            ("accent", Theme.accent),
            ("secondaryText", Theme.secondaryText),
            ("success", Theme.success),
            ("warning", Theme.warning),
            ("error", Theme.error),
            ("brandSecondary", Theme.brandSecondary),
        ]
        for (modeName, mode) in Self.modes {
            for (name, color) in tokens {
                for (planeName, plane) in [("surface", Theme.surface), ("background", Theme.background)] {
                    let value = ratio(color, on: plane, mode)
                    XCTAssertGreaterThanOrEqual(
                        value, 4.5,
                        "\(name) auf \(planeName) (\(modeName)): \(String(format: "%.2f", value)):1"
                    )
                }
            }
        }
    }

    /// Schrift **auf** einer gefüllten Fläche. `onAccent` hat diese Prüfung
    /// schon einmal gebraucht: Im dunklen Modus stand dort Weiß auf hellem
    /// Grün, gemessene 2,13:1.
    func testLabelsOnFilledSurfacesClearAA() {
        for (modeName, mode) in Self.modes {
            let onAccent = ratio(Theme.onAccent, on: Theme.accent, mode)
            XCTAssertGreaterThanOrEqual(onAccent, 4.5,
                                        "onAccent auf accent (\(modeName)): \(String(format: "%.2f", onAccent)):1")
            let onDiscount = ratio(Theme.onDiscount, on: Theme.discount, mode)
            XCTAssertGreaterThanOrEqual(onDiscount, 4.5,
                                        "onDiscount auf discount (\(modeName)): \(String(format: "%.2f", onDiscount)):1")
        }
    }

    /// Das Rabatt-Schild ist eine Fläche, kein Text: 3:1 genügt — **und genau
    /// hier lag der einzige echte Durchfaller der alten Palette.** Im dunklen
    /// Modus stand es bei 2,87:1 gegen die Karte.
    func testTheDiscountBadgeIsVisibleAsAShape() {
        for (modeName, mode) in Self.modes {
            let value = ratio(Theme.discount, on: Theme.surface, mode)
            XCTAssertGreaterThanOrEqual(
                value, 3.0,
                "Rabatt-Schild auf der Karte (\(modeName)): \(String(format: "%.2f", value)):1"
            )
        }
    }

    // MARK: Hellwert — die eigentliche Beschwerde

    /// **„Alles sieht aus wie eine beige Masse."**
    ///
    /// Karte gegen Seite stand bei 1,13:1. Das ist kein WCAG-Fehler — Flächen
    /// gleicher Funktion dürfen sich ähneln —, aber es ist der Grund, warum man
    /// die Karte nicht als Karte sieht. 1,25:1 ist die Schwelle, ab der die
    /// Kante ohne Strich erkennbar wird.
    func testACardIsTellableFromThePageItSitsOn() {
        for (modeName, mode) in Self.modes {
            let value = ratio(Theme.surface, on: Theme.background, mode)
            XCTAssertGreaterThanOrEqual(
                value, 1.25,
                "Karte gegen Seite (\(modeName)): \(String(format: "%.2f", value)):1 — die beige Masse ist zurück"
            )
        }
    }

    /// **Der Zustandswechsel, der keine Graustufen überlebte.**
    ///
    /// Dasselbe Reißzwecken-Zeichen schaltet zwischen `accent` und
    /// `secondaryText` um und sagt damit „geheftet" oder „nicht geheftet".
    /// Gemessen lagen die beiden bei **1,04:1** — für jemanden, der Farben
    /// schlecht unterscheidet, war das kein Zustandswechsel, sondern keiner.
    func testPinnedAndUnpinnedAreTellableApartWithoutColourVision() {
        for (modeName, mode) in Self.modes {
            let value = ratio(Theme.accent, on: Theme.secondaryText, mode)
            XCTAssertGreaterThanOrEqual(
                value, 1.3,
                "accent gegen secondaryText (\(modeName)): \(String(format: "%.2f", value)):1"
            )
        }
    }

    /// „Erledigt" darf nicht wie „antippbar" aussehen — der Satz stand seit
    /// jeher im Kommentar an `success` und war nie umgesetzt: Gemessen war
    /// `success` **heller** als der Akzent, bei praktisch gleichem Farbton.
    func testDoneDoesNotLookTappable() {
        for (modeName, mode) in Self.modes {
            let value = ratio(Theme.success, on: Theme.accent, mode)
            XCTAssertGreaterThanOrEqual(
                value, 1.3,
                "success gegen accent (\(modeName)): \(String(format: "%.2f", value)):1"
            )
        }
    }
}
