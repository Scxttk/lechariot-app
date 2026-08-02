import XCTest
@testable import LeChariot

/// **Die Ahlbeck-Lektion, dritte Fassung** — gefunden beim Nachzählen der
/// Anklamer Filialen am 02.08.
///
/// Nach dem Gebietslauf stehen in Anklam acht Märkte, darunter ein ALDI Nord
/// und ein NORMA. Beide Ketten liefern **0** Zeilen je Filiale, weil sie einen
/// bundesweiten Prospekt veröffentlichen (477 bzw. 291 Zeilen in der
/// Produktion). Für die App sah eine solche Filiale aus wie eine, die nichts
/// veröffentlicht — und genau das hätte dort gestanden.
final class OfferCoverageTests: XCTestCase {
    private func market(_ id: String, _ chain: String) -> Market {
        Market(chain: chain, branchName: "\(chain) Anklam", marketId: id, plz: "17389")
    }

    private func offer(_ marketId: String?, _ chain: String, nationwide: Bool = false) -> Offer {
        Offer(
            marketId: marketId, market: chain, product: "Butter", price: 1.99,
            regularPrice: 2.49, unit: nil, category: "Molkereiprodukte", emoji: "🧈",
            validFrom: .now, validUntil: .now.addingTimeInterval(86_400),
            basePrice: nil, baseUnit: nil, nationwide: nationwide
        )
    }

    /// Die Regression. Gegen den Stand vor dem 02.08. fällt dieser Test: Dort
    /// wurde nur über `market_id` gerechnet, und `ALDI_NORD_DE029038` steht in
    /// keiner Angebotszeile.
    func testABranchOfANationwideChainIsCoveredByItsCatalogue() {
        let aldiAnklam = market("ALDI_NORD_DE029038", "ALDI Nord")
        let offers = [offer("ALDI_NORD_DE", "ALDI Nord", nationwide: true)]

        XCTAssertTrue(
            OfferCoverage.branchesWithoutOffers(favorites: [aldiAnklam], offers: offers).isEmpty,
            "Der ALDI in Anklam ist versorgt — sein Prospekt gilt bundesweit"
        )
    }

    /// Die Gegenrichtung, damit der Fix nicht überschießt: Ohne bundesweite
    /// Zeile derselben Kette bleibt die Filiale unversorgt.
    func testWithoutAnyLineTheBranchStillCountsAsEmpty() {
        let aldiAnklam = market("ALDI_NORD_DE029038", "ALDI Nord")
        let offers = [offer("561536", "Penny")]

        XCTAssertEqual(
            OfferCoverage.branchesWithoutOffers(favorites: [aldiAnklam], offers: offers)
                .map(\.marketId),
            ["ALDI_NORD_DE029038"]
        )
    }

    /// Und der Fall, um den es ursprünglich ging: Zwei Filialen derselben
    /// Kette, eine davon leer. Über die Kette allein wäre das nicht zu
    /// unterscheiden — deshalb bleibt `market_id` die erste Frage.
    func testTwoBranchesOfOneChainAreToldApart() {
        let voll = market("7517", "Netto")
        let leer = market("5846", "Netto")
        let offers = [offer("7517", "Netto")]

        XCTAssertEqual(
            OfferCoverage.branchesWithoutOffers(favorites: [voll, leer], offers: offers)
                .map(\.marketId),
            ["5846"]
        )
    }

    /// Der bundesweite Katalog selbst steht nie in der Liste — er ist keine
    /// Filiale.
    func testTheCatalogueRowItselfIsNeverListed() {
        let katalog = market("ALDI_NORD_DE", "ALDI Nord")
        XCTAssertTrue(
            OfferCoverage.branchesWithoutOffers(favorites: [katalog], offers: []).isEmpty
        )
    }
}
