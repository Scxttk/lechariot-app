import XCTest
@testable import LeChariot

/// **Was ein Tipp die App wirklich kostet — ohne Simulator, ohne XCUITest.**
///
/// Die Sonde `TippLatenzProbe` misst durch das Messgerät hindurch: Ihr Boden
/// liegt bei rund 380 ms je Tipp, und er **wächst mit dem
/// Bedienungshilfen-Baum**. Damit taugt sie für „ist es teurer geworden", aber
/// nicht für „woran liegt es".
///
/// Hier steht deshalb die andere Hälfte: die reine Rechenzeit der Funktionen,
/// die bei jedem Tipp durch den Rumpf von `ShoppingListView` laufen — bei einem
/// Prospekt in Scotts Größe (drei Ketten, 400 Zeilen je Kette; siehe
/// `MockFixtures.bulk`).
///
/// **Warum genau diese Funktionen.** `firstOpenHasMatch` und `plan` stehen als
/// berechnete Eigenschaften im Rumpf. Ein Rumpf läuft bei **jeder**
/// Zustandsänderung, und ein Haken auf einer Kachel ist eine — die Zahl unten
/// ist also nicht „einmal beim Aufbauen", sondern „je Tipp".
final class TippKostenProbe: XCTestCase {
    private var offers: [Offer] = []

    override func setUp() {
        super.setUp()
        offers = MockFixtures.bulk(perChain: 400)
    }

    /// Der Treffer der ersten offenen Zeile — `ShoppingListView.firstOpenHasMatch`.
    func testKostenFirstOpenHasMatch() {
        miss("cheapestMatch(Vollmilch)", runden: 20) {
            _ = ShoppingListMatcher.cheapestMatch(for: "Vollmilch", in: self.offers)
        }
    }

    /// Derselbe Griff für ein Wort, das das Wörterbuch **nicht** kennt — der
    /// teure Zweig: Kein Treffer heißt, dass jede Zeile bis zum Ende geprüft
    /// wurde.
    func testKostenOhneTreffer() {
        miss("cheapestMatch(Kohlrabistrunk)", runden: 20) {
            _ = ShoppingListMatcher.cheapestMatch(for: "Kohlrabistrunk", in: self.offers)
        }
    }

    /// Und die ganze Wertung, wie sie der Rumpf für die Plan-Karte rechnet.
    func testKostenWertung() {
        let items = ["Vollmilch", "Butter", "Kartoffeln", "Joghurt", "Nudeln"]
            .map { ShoppingItem(text: $0) }
        let chains = MockFixtures.bulkChains
        miss("ranking(5 Artikel)", runden: 10) {
            _ = ShoppingListRanking.rank(items: items, offers: self.offers, chains: chains)
        }
    }

    // MARK: Messen

    private func miss(_ name: String, runden: Int, _ block: () -> Void) {
        // Einmal warm laufen: Das Wörterbuch wird beim ersten Zugriff geladen,
        // und das ist eine Zahl über die Platte, nicht über den Griff.
        block()
        var ms: [Double] = []
        for _ in 0..<runden {
            let t0 = Date()
            block()
            ms.append(Date().timeIntervalSince(t0) * 1000)
        }
        let sortiert = ms.sorted()
        print(String(format: "KOSTEN %-32@ median=%7.2f ms  min=%7.2f  max=%7.2f  (%d Angebote)",
                     name as NSString, sortiert[sortiert.count / 2],
                     sortiert.first ?? 0, sortiert.last ?? 0, offers.count))
        XCTAssertFalse(ms.isEmpty)
    }
}
