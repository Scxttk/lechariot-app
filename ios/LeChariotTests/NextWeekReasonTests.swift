import XCTest
@testable import LeChariot

/// Der Satz, der unter „Ohne Vorschau" steht.
///
/// **Warum das eine Prüfung wert ist:** Er ist die einzige Stelle, an der die
/// App über eine Kette etwas *behauptet*, das sie nicht gerade gemessen hat.
/// Ein Sammelsatz („noch nichts da") wäre für EDEKA gelogen — dort kommt auch
/// morgen nichts, und wer das nicht liest, wartet umsonst.
final class NextWeekReasonTests: XCTestCase {
    /// EDEKA ist der Dauerzustand: nicht warten.
    func testEdekaIsToldItPublishesNothingInAdvance() {
        let satz = NextWeekView.reason(for: "EDEKA")

        XCTAssertEqual(satz, "EDEKA veröffentlicht seine Angebote nicht im Voraus.")
        XCTAssertTrue(satz.contains("EDEKA"), "Der Satz nennt die Kette nicht beim Namen")
    }

    /// Alle anderen sind der vorübergehende Zustand: morgen wieder herschauen.
    /// REWE steht bewusst mit in der Liste — seit dem 01.08. holt der Scraper
    /// dort die Folgewoche, „veröffentlicht nichts" wäre also falsch.
    func testEveryOtherChainIsToldNothingHasArrivedYet() {
        for chain in ["Lidl", "Kaufland", "ALDI Nord", "ALDI SÜD", "Netto", "REWE", "Penny", "NORMA"] {
            XCTAssertEqual(
                NextWeekView.reason(for: chain),
                "Für nächste Woche liegt hier noch nichts vor.",
                "\(chain) bekommt den falschen Grund"
            )
        }
    }

    /// Genau eine Kette trägt den Dauerzustand. Wächst die Liste, ohne dass
    /// jemand nachgemessen hat, fällt dieser Test — so wie er soll.
    func testExactlyOneChainIsKnownToPublishNothing() {
        XCTAssertEqual(NextWeekView.chainsWithoutPreview, ["EDEKA"])
    }
}
