import XCTest
@testable import LeChariot

/// **Fünfundzwanzigmal „Dresden" unter „ALDI Nord."**
///
/// Gemeldet am 2026-07-31 von Scotts Gerät, aus dem TestFlight-Build. Die
/// Kürzungsregel war richtig gedacht und an Ketten geprüft, bei denen sie
/// funktioniert — Lidl, Kaufland und Penny benennen ihre Filialen nach dem
/// Stadtteil. Zwei Ketten benennen jede Filiale nach der **Stadt**, und dann
/// bleibt nach dem Abschneiden des Kettennamens der Stadtname übrig.
///
/// Die Zahlen unten sind an der Produktion gemessen (113 Dresdner Filialen),
/// nicht ausgedacht.
final class BranchTitleTests: XCTestCase {

    private func row(
        _ id: String, _ name: String, _ chain: String,
        street: String? = nil, city: String? = "Dresden"
    ) -> MarketFilter.Row {
        MarketFilter.Row(id: id, name: name, chain: chain, street: street, city: city)
    }

    // MARK: Der gemeldete Fall

    /// Alle 25 Dresdner ALDI-Nord-Filialen heißen „ALDI Nord Dresden".
    func testTwentyFiveRowsThatAllSaidDresdenNowSayTheirStreet() {
        let rows = (1...25).map {
            row("A\($0)", "ALDI Nord Dresden", "ALDI Nord", street: "Straße \($0)")
        }
        let titles = MarketFilter.titles(for: rows)

        XCTAssertEqual(Set(titles.values).count, 25, "keine zwei Zeilen dürfen gleich heißen")
        XCTAssertEqual(titles["A7"], "Straße 7")
        XCTAssertFalse(titles.values.contains("Dresden"))
    }

    /// Netto hat dieselbe Form: 24 Filialen, ein Name. Zusätzlich greift hier
    /// die Marken-Kürzung („Marken-Discount"), also beide Regeln übereinander.
    func testNettoLosesBothTheChainAndTheBrandAndStillGetsAStreet() {
        let rows = (1...3).map {
            row("N\($0)", "Netto Marken-Discount Dresden", "Netto", street: "Reicker Straße \($0)")
        }
        let titles = MarketFilter.titles(for: rows)
        XCTAssertEqual(titles["N2"], "Reicker Straße 2")
    }

    /// **Der Fall, den die Meldung nicht enthielt.** Gemessen: Lidl hat in
    /// Dresden 22 Filialen mit 21 verschiedenen Namen — „Lidl Striesen-Süd"
    /// kommt zweimal vor. Lidl galt als nicht betroffen.
    ///
    /// Eine Regel, die nur „Titel gleich Stadt" prüft, ließe diese beiden
    /// Zeilen ununterscheidbar stehen.
    func testTwoBranchesOfOneChainInOneDistrictAreStillToldApart() {
        let titles = MarketFilter.titles(for: [
            row("L1", "Lidl Striesen-Süd", "Lidl", street: "Schandauer Straße 66"),
            row("L2", "Lidl Striesen-Süd", "Lidl", street: "Bergmannstraße 2"),
            row("L3", "Lidl Strehlen", "Lidl", street: "Dohnaer Straße 1"),
        ])
        XCTAssertEqual(titles["L1"], "Schandauer Straße 66")
        XCTAssertEqual(titles["L2"], "Bergmannstraße 2")
        // Die eindeutige Zeile behält ihren sprechenden Namen — die Straße ist
        // die Notlösung, nicht der Normalfall.
        XCTAssertEqual(titles["L3"], "Strehlen")
    }

    /// REWE führt drei Dresdner Zeilen namens „Nahkauf" — eine Marke, nicht
    /// einmal ein Ort, und ebenfalls nicht in der Meldung.
    func testThreeRowsSharingABrandNameGetStreetsToo() {
        let titles = MarketFilter.titles(for: [
            row("R1", "Nahkauf", "REWE", street: "Uhlandstraße 5"),
            row("R2", "Nahkauf", "REWE", street: "Bulgakowstraße 7"),
            row("R3", "Nahkauf", "REWE", street: "Kesselsdorfer Straße 1"),
        ])
        XCTAssertEqual(Set(titles.values).count, 3)
    }

    // MARK: Was sich nicht ändern durfte

    /// Der Normalfall bleibt der gekürzte Name. Die Kürzung selbst war
    /// richtig — sie ist am 2026-07-30 gemeldet und behoben worden, weil
    /// „REWE" über „REWE Friedrichstadt" denselben Namen zweimal schreibt.
    func testAUniqueBranchKeepsItsShortenedName() {
        let titles = MarketFilter.titles(for: [
            row("K1", "Kaufland Dresden-Nickern", "Kaufland", street: "Dohnaer Straße 246"),
            row("P1", "Penny Leubnitz", "Penny", street: "Altleubnitz 1"),
        ])
        XCTAssertEqual(titles["K1"], "Dresden-Nickern")
        XCTAssertEqual(titles["P1"], "Leubnitz")
    }

    /// **Der Stadtname ist auch als Einzelzeile keine Filialangabe.** Sonst
    /// hinge das Ergebnis daran, wie viele Filialen einer Kette der Umkreis
    /// gerade hergibt — dieselbe Filiale hieße mal „Dresden", mal
    /// „Bulgakowstraße 7", je nach Suchradius.
    func testASingleRowNamedAfterItsCityAlsoGetsTheStreet() {
        let titles = MarketFilter.titles(for: [
            row("A1", "ALDI Nord Dresden", "ALDI Nord", street: "Bulgakowstraße 7")
        ])
        XCTAssertEqual(titles["A1"], "Bulgakowstraße 7")
    }

    /// Ohne Straße bleibt die Dublette stehen. Eine Zeile ohne Titel wäre
    /// schlimmer als eine doppelte — dieselbe Abwägung wie in `branchLabel`.
    func testWithoutAStreetTheDuplicateStaysRatherThanVanishing() {
        let titles = MarketFilter.titles(for: [
            row("A1", "ALDI Nord Dresden", "ALDI Nord", street: nil),
            row("A2", "ALDI Nord Dresden", "ALDI Nord", street: nil),
        ])
        XCTAssertEqual(titles["A1"], "Dresden")
        XCTAssertEqual(titles["A2"], "Dresden")
    }

    /// Zeilen ohne Verzeichnis-Eintrag (aus `markets`, ohne Adresse) dürfen
    /// die anderen nicht mitreißen.
    func testARowWithoutADirectoryEntryDoesNotSpoilTheOthers() {
        let titles = MarketFilter.titles(for: [
            row("A1", "ALDI Nord Dresden", "ALDI Nord", street: "Bulgakowstraße 7"),
            MarketFilter.Row(id: "A2", name: "ALDI Nord Dresden", chain: "ALDI Nord"),
        ])
        XCTAssertEqual(titles["A1"], "Bulgakowstraße 7")
        XCTAssertEqual(titles["A2"], "Dresden")
    }

    /// Groß-/Kleinschreibung und Diakritik zählen nicht — die Ketten schreiben
    /// ihre Orte nicht einheitlich.
    func testTheCityComparisonIgnoresCaseAndDiacritics() {
        let titles = MarketFilter.titles(for: [
            row("A1", "ALDI Nord München", "ALDI Nord", street: "Leopoldstraße 1", city: "Munchen")
        ])
        XCTAssertEqual(titles["A1"], "Leopoldstraße 1")
    }
}
