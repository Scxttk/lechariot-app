import XCTest
@testable import LeChariot

final class MarketFilterTests: XCTestCase {
    private func market(_ chain: String, branch: String, plz: String = "01219") -> Market {
        Market(chain: chain, branchName: branch, marketId: "\(chain)_\(branch)", plz: plz)
    }

    private var branches: [Market] {
        [
            market("Netto", branch: "JPT-Straße"),
            market("Kaufland", branch: "Strehlen"),
            market("REWE", branch: "Postplatz", plz: "01067"),
            market("Lidl", branch: "Strehlener Platz"),
        ]
    }

    func testEmptyQueryKeepsEverything() {
        XCTAssertEqual(MarketFilter.filter(branches, query: "  ").count, 4)
    }

    func testMatchesBranchNameCaseInsensitive() {
        let hits = MarketFilter.filter(branches, query: "jpt")
        XCTAssertEqual(hits.map(\.branchName), ["JPT-Straße"])
    }

    func testMatchesChain() {
        XCTAssertEqual(MarketFilter.filter(branches, query: "rewe").map(\.branchName), ["Postplatz"])
    }

    func testMatchesPLZ() {
        XCTAssertEqual(MarketFilter.filter(branches, query: "01067").map(\.chain), ["REWE"])
    }

    func testDiacriticInsensitive() {
        // "strasse" should find "Straße", "strehlen" both Strehlen branches.
        XCTAssertEqual(MarketFilter.filter(branches, query: "strasse").map(\.branchName), ["JPT-Straße"])
        XCTAssertEqual(MarketFilter.filter(branches, query: "Strehlen").count, 2)
    }

    func testNoMatch() {
        XCTAssertTrue(MarketFilter.filter(branches, query: "Edeka").isEmpty)
    }

    /// Guards the app layer against accidental dedupe: two branches of the
    /// same chain in the same PLZ must both survive filtering and stay
    /// distinguishable. (That only one arrives today is a backend limitation:
    /// the scrapers' find_market returns a single nearest branch per chain.)
    func testTwoBranchesOfSameChainInSamePLZBothKept() {
        let nettos = [
            market("Netto", branch: "Johannes-Paul-Thilman-Straße"),
            market("Netto", branch: "Strehlener Platz"),
        ]
        let hits = MarketFilter.filter(nettos, query: "netto")
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(Set(hits.map(\.id)).count, 2, "branches must keep distinct ids")
        XCTAssertEqual(MarketFilter.filter(nettos, query: "thilman").count, 1)
    }

    // MARK: Zeilentitel im Ketten-Abschnitt

    /// Die Abschnittsüberschrift nennt die Kette schon. Steht sie im Namen
    /// noch einmal, fällt sie weg — sonst steht „REWE" über „REWE
    /// Friedrichstadt" und der Ort, der die Filialen unterscheidet, hat den
    /// wenigsten Platz.
    func testTheChainIsNotRepeatedInTheRow() {
        XCTAssertEqual(
            MarketFilter.branchLabel(name: "REWE Friedrichstadt", chain: "REWE"),
            "Friedrichstadt"
        )
        XCTAssertEqual(
            MarketFilter.branchLabel(name: "Penny Am Haff", chain: "Penny"),
            "Am Haff"
        )
    }

    /// Netto schreibt seine Marke zweimal: Kette „Netto", Filiale „Netto
    /// Marken-Discount Dresden-Strehlen". Nur die Kette abzuschneiden ließe
    /// „Marken-Discount Dresden-Strehlen" stehen — immer noch Marke, nicht Ort.
    func testASecondBrandWordIsStrippedToo() {
        XCTAssertEqual(
            MarketFilter.branchLabel(
                name: "Netto Marken-Discount Dresden-Strehlen", chain: "Netto"
            ),
            "Dresden-Strehlen"
        )
    }

    /// Namen ohne Kettenpräfix bleiben, wie sie sind — die Fixtures der
    /// UI-Journeys hängen daran („Lidl" / „Dresden Reick").
    func testANameWithoutTheChainIsLeftAlone() {
        XCTAssertEqual(
            MarketFilter.branchLabel(name: "Dresden Reick", chain: "Lidl"),
            "Dresden Reick"
        )
    }

    /// Die Ketten schreiben sich selbst nicht einheitlich — „ALDI SÜD" im
    /// Filialnamen, „Aldi Süd" als Kette.
    ///
    /// Die Grenze steht bewusst hier: `.diacriticInsensitive` faltet Ü auf U,
    /// **nicht** auf UE. „Aldi Sued" träfe „ALDI SÜD" also nicht, und das ist
    /// in Ordnung — Kettenname und Filialname kommen aus demselben Scraper und
    /// schreiben sich damit gleich. Der Ausgang wäre ohnehin harmlos: Die Zeile
    /// bliebe ungekürzt.
    func testStrippingIgnoresCase() {
        XCTAssertEqual(
            MarketFilter.branchLabel(name: "ALDI SÜD Filiale Sonneberg", chain: "Aldi Süd"),
            "Filiale Sonneberg"
        )
        XCTAssertEqual(
            MarketFilter.branchLabel(name: "ALDI SÜD Filiale Sonneberg", chain: "Aldi Sued"),
            "ALDI SÜD Filiale Sonneberg",
            "ue gegen ü ist keine Diakritik — ungekürzt ist hier der richtige Ausgang"
        )
    }

    /// Bliebe nichts übrig, gewinnt der ursprüngliche Name: Eine Zeile ohne
    /// Titel wäre schlimmer als eine mit einem doppelten.
    func testANameThatIsNothingButTheChainSurvives() {
        XCTAssertEqual(MarketFilter.branchLabel(name: "Kaufland", chain: "Kaufland"), "Kaufland")
    }
}
