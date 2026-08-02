import XCTest
@testable import LeChariot

/// Der geteilte Zustand von Angebotsliste und Vorschau.
///
/// **Die Wochengrenze wird hier als Bauart geprüft, nicht als Verhalten.** Der
/// Browser hält keine Angebote; alles, was er zurückgibt, muss aus dem Topf
/// stammen, den der Aufrufer ihm gereicht hat. Ist das wahr, kann die Vorschau
/// gar keine laufende Zeile zeigen — sie bekommt keine. Die Journeys prüfen
/// dieselbe Zusage am Bildschirm; diese Fälle prüfen, warum sie hält.
final class OfferBrowserTests: XCTestCase {
    private let heute = MockFixtures.offers
    private let naechste = MockFixtures.nextWeekOffers

    // MARK: Aus dem Topf und nur aus ihm

    func testEveryVisibleRowComesFromTheGivenPot() {
        var browser = OfferBrowser()
        let ids = Set(naechste.map(\.id))

        for suche in ["", "Milch", "Kaffee", "xyz"] {
            browser.search = suche
            for row in browser.visible(in: naechste) {
                XCTAssertTrue(ids.contains(row.id),
                              "„\(suche)" + "“ förderte eine Zeile zutage, die nicht im Topf lag")
            }
        }
    }

    /// Der Fall, den die Vorschau nicht haben darf: dasselbe Produkt in beiden
    /// Wochen. Gesucht wird im Topf der Folgewoche — der heutige Preis kann
    /// nicht dabei sein, weil er dort nicht liegt.
    func testSearchingThePreviewPotCannotReachTheCurrentWeeksPrice() {
        var browser = OfferBrowser()
        browser.search = "Bio Vollmilch"

        let treffer = browser.visible(in: naechste)
        XCTAssertEqual(treffer.count, 1)
        XCTAssertEqual(treffer.first?.price, 0.79, "der Preis der Folgewoche")

        let heutige = browser.visible(in: heute)
        XCTAssertEqual(heutige.first?.price, 0.99, "und umgekehrt der heutige")
    }

    /// Und die Gegenrichtung: Ein Produkt, das es nur nächste Woche gibt, ist
    /// über die Suche der laufenden Woche nicht erreichbar.
    func testTheCurrentPotHasNoNextWeekOnlyProduct() {
        var browser = OfferBrowser()
        browser.search = "Kaffee"

        XCTAssertTrue(browser.visible(in: heute).isEmpty)
        XCTAssertEqual(browser.visible(in: naechste).count, 1)
    }

    // MARK: Markt-Leiste

    func testChipChainsComeFromTheRowsNotFromTheChosenBranches() {
        let browser = OfferBrowser()
        XCTAssertEqual(browser.chipChains(in: naechste), ["Lidl"],
                       "die Fixtures der Folgewoche sind alle Lidl")
        XCTAssertEqual(browser.chipChains(in: heute), ["Aldi", "Lidl"])
    }

    /// Die aktive Kette bleibt in der Leiste, auch wenn sie gerade keine Zeile
    /// mehr hat — sonst verschwände mit dem Chip der einzige sichtbare Hinweis
    /// darauf, warum die Liste leer ist.
    func testTheActiveChainStaysInTheBarEvenWithoutRows() {
        var browser = OfferBrowser()
        browser.market = "Netto"
        XCTAssertEqual(browser.chipChains(in: naechste), ["Lidl", "Netto"])
    }

    /// Ein Marktfilter darf die Kette nicht überleben, die ihn benannt hat —
    /// sonst filtert der Bildschirm dauerhaft auf etwas, das es nicht gibt.
    func testAMarketFilterIsDroppedWhenItsChainIsGone() {
        var browser = OfferBrowser()
        browser.market = "Netto"

        browser.dropMarketFilterIfGone(from: ["Lidl", "Netto"])
        XCTAssertEqual(browser.market, "Netto")

        browser.dropMarketFilterIfGone(from: ["Lidl"])
        XCTAssertNil(browser.market)
    }

    // MARK: Die drei Zustände, an denen die Leertexte hängen

    func testBrowsingMeansNeitherSearchNorFilter() {
        var browser = OfferBrowser()
        XCTAssertTrue(browser.isBrowsing)

        browser.search = "   "
        XCTAssertTrue(browser.isBrowsing, "Leerzeichen sind keine Suche")

        browser.search = "Milch"
        XCTAssertFalse(browser.isBrowsing)
        XCTAssertTrue(browser.isSearching)

        browser.search = ""
        browser.category = "Molkerei & Eier"
        XCTAssertFalse(browser.isBrowsing)
        XCTAssertTrue(browser.hasActiveFilter)
    }

    func testResettingFiltersLeavesTheSearchAlone() {
        var browser = OfferBrowser()
        browser.search = "Milch"
        browser.category = "Molkerei & Eier"
        browser.market = "Lidl"
        browser.sort = .deals

        browser.resetFilters()

        XCTAssertFalse(browser.hasActiveFilter)
        XCTAssertEqual(browser.search, "Milch",
                       "„Filter zurücksetzen" + "“ ist kein „Suche löschen“")
    }

    /// Die zwei Bildschirme sprechen von zwei verschiedenen Wochen. Ein
    /// gemeinsamer Satz wäre auf einem von beiden gelogen.
    func testTheScopeNamesItsWeek() {
        XCTAssertEqual(OfferWeekScope.current.week, "diese Woche")
        XCTAssertEqual(OfferWeekScope.upcoming.week, "nächste Woche")
    }
}
