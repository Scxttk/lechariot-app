import UIKit
import XCTest
@testable import LeChariot

/// **Der Wächter gegen das Zeichen, das es nicht gibt.**
///
/// Gefunden am 08.08.: `DietTag.glutenfrei` stand auf `wheat`, und ein SF
/// Symbol dieses Namens gibt es nicht. `Image(systemName:)` zeichnet dann
/// **nichts** und beschwert sich nicht — der Chip „Glutenfrei" stand seit dem
/// Onboarding-Umbau ohne Bild da, und aufgefallen ist es erst einem Nutzer.
///
/// Ein Test, der nur `glutenfrei` prüft, wäre die Reparatur des einen Falls.
/// Geprüft wird deshalb **jeder** Name, den die Chips des Profils in ein
/// `Image(systemName:)` geben — die sechs Ernährungsangaben, das Häkchen des
/// gewählten Chips und die fünf Gründe des Rückmeldebogens, der aus derselben
/// Familie kommt (`RejectionReason.symbol`).
///
/// **Warum `UIImage(systemName:)` und keine Namensliste:** Eine Liste wäre eine
/// zweite Stelle, an der derselbe Tippfehler stehen kann. Der Katalog des
/// laufenden Systems ist die einzige Instanz, die wirklich weiß, ob ein Name
/// zeichnet.
final class DietSymbolTests: XCTestCase {

    /// Jedes Zeichen des Ernährungsprofils existiert.
    func testEveryDietTagHasARealSymbol() {
        for tag in DietTag.allCases {
            XCTAssertNotNil(
                UIImage(systemName: tag.symbol),
                "\(tag.rawValue) zeigt auf „\(tag.symbol)“ — dieses SF Symbol gibt es nicht, "
                + "der Chip bleibt leer."
            )
        }
    }

    /// Das Häkchen, das den gewählten Chip ersetzt (`DietPromptCard.chip`,
    /// `SettingsView`). Es steht hart im Code und ist deshalb genauso ein
    /// Kandidat für einen stillen Ausfall wie die sechs darüber.
    func testTheSelectedChipsCheckmarkExists() {
        XCTAssertNotNil(UIImage(systemName: "checkmark"))
    }

    /// Die Gründe des Rückmeldebogens — dieselbe Bauart, dieselbe Falle.
    func testEveryFeedbackReasonHasARealSymbol() {
        for reason in RejectionReason.allCases {
            XCTAssertNotNil(
                UIImage(systemName: reason.symbol),
                "\(reason.rawValue) zeigt auf „\(reason.symbol)“ — dieses SF Symbol gibt es nicht."
            )
        }
    }

    /// **Die Gegenprobe.** Ohne sie wäre nicht bewiesen, dass die drei Tests
    /// oben überhaupt etwas messen können: Gäbe `UIImage(systemName:)` für
    /// jeden Namen etwas zurück, blieben sie für immer grün.
    func testAnInventedNameReallyReturnsNil() {
        XCTAssertNil(UIImage(systemName: "wheat"),
                     "„wheat“ ist wieder da — dann darf DietTag es auch wieder benutzen.")
        XCTAssertNil(UIImage(systemName: "kein.symbol.dieses.namens"))
    }
}
