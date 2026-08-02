import XCTest
@testable import LeChariot

/// Scotts Fund vom 02.08.: „Startanzeige: statt PLZ die Koordinaten
/// übersetzt". Die Regeln stehen hier als Fälle, weil sie sich sonst nur am
/// Gerät prüfen ließen — und dort nur für den Ort, an dem man gerade steht.
final class PlaceNameTests: XCTestCase {
    // MARK: Die Region — eine PLZ ist eine Stadt, keine Straße

    func testARegionIsNamedAfterItsCity() {
        XCTAssertEqual(
            PlaceName.region(locality: "Anklam", subLocality: nil, plz: "17389"),
            "Anklam"
        )
    }

    /// Apple liefert für Anklam `locality` **und** `subLocality` als „Anklam".
    /// Gemessen am 02.08. mit dem echten Geocoder — „Anklam Anklam" wäre keine
    /// Verbesserung gegenüber der Zahl.
    func testACityIsNotRepeatedAsItsOwnQuarter() {
        XCTAssertEqual(
            PlaceName.region(locality: "Anklam", subLocality: "Anklam", plz: "17389"),
            "Anklam"
        )
    }

    func testAQuarterIsNamedWhenItAddsSomething() {
        XCTAssertEqual(
            PlaceName.region(locality: "Dresden", subLocality: "Strehlen", plz: "01219"),
            "Dresden Strehlen"
        )
    }

    /// Der Rückfall ist die PLZ. Sie ist nicht schön, aber sie ist wahr —
    /// und sie ist genau das, was heute überall steht.
    func testWithoutAnAnswerThePostcodeStays() {
        XCTAssertEqual(PlaceName.region(locality: nil, subLocality: nil, plz: "17389"), "17389")
        XCTAssertEqual(PlaceName.region(locality: "  ", subLocality: "", plz: "17389"), "17389")
    }

    // MARK: Der Punkt — hier ist die Straße das Genaueste

    func testAPositionIsNamedDownToTheStreet() {
        XCTAssertEqual(
            PlaceName.position(
                locality: "Anklam", subLocality: "Anklam",
                thoroughfare: "Friedländer Straße", subThoroughfare: nil, plz: "17389"
            ),
            "Anklam, Friedländer Straße"
        )
    }

    func testAHouseNumberComesAlongWhenThereIsOne() {
        XCTAssertEqual(
            PlaceName.position(
                locality: "Anklam", subLocality: nil,
                thoroughfare: "Südstraße", subThoroughfare: "7", plz: "17389"
            ),
            "Anklam, Südstraße 7"
        )
    }

    /// Ohne Straße bleibt der Stadtteil — „Anklam Mitte", genau die zweite
    /// Form aus Scotts Wunsch.
    func testWithoutAStreetTheQuarterCarriesIt() {
        XCTAssertEqual(
            PlaceName.position(
                locality: "Anklam", subLocality: "Mitte",
                thoroughfare: nil, subThoroughfare: nil, plz: "17389"
            ),
            "Anklam Mitte"
        )
    }

    /// Eine Straße ohne Ort ist in einer App mit mehreren Gegenden eine
    /// Fangfrage — die Stadt steht deshalb immer davor, wenn es sie gibt.
    func testAStreetWithoutACityStillReads() {
        XCTAssertEqual(
            PlaceName.position(
                locality: nil, subLocality: nil,
                thoroughfare: "Südstraße", subThoroughfare: "7", plz: "17389"
            ),
            "Südstraße 7"
        )
    }

    func testAPositionFallsBackToThePostcodeToo() {
        XCTAssertEqual(
            PlaceName.position(
                locality: nil, subLocality: nil,
                thoroughfare: nil, subThoroughfare: nil, plz: "17389"
            ),
            "17389"
        )
    }
}
