import XCTest
@testable import LeChariot

/// Der Fehlerbericht vom 2026-07-30, als Test.
///
/// Ein Tester hat die App zuerst in 01219 (Dresden) eingerichtet, später 04626
/// (Schmölln) ergänzt und dann in Ahlbeck (17419) erneut das Onboarding
/// durchlaufen. Was er sah: Entfernungen, die keinen Sinn ergaben, und in
/// Vorpommern nur zwei Ketten — während um Schmölln Netto danebenstand.
///
/// Beides stammt aus derselben Zeile Code: Der Picker warf die Funde aller
/// Regionen in einen Topf. Die Fixtures hier sind seine drei Standorte.
final class PickerDirectoryTests: XCTestCase {
    // Die drei PLZ-Mitten aus `MockFixtures`.
    private let dresden = MockFixtures.dresden
    private let schmoelln = MockFixtures.coordinates(forPLZ: "04626")
    private let ahlbeck = MockFixtures.coordinates(forPLZ: "17419")

    private func branch(
        _ id: String, chain: String, name: String? = nil,
        lat: Double?, lon: Double?
    ) -> Branch {
        Branch(
            marketId: id, chain: chain, name: name ?? "\(chain) \(id)",
            street: "Teststraße 1", plz: "00000", city: "Testort",
            lat: lat, lon: lon
        )
    }

    private func find(
        _ plz: String, _ point: (lat: Double, lon: Double), _ branches: [Branch]
    ) -> PickerDirectory.RegionFind {
        PickerDirectory.RegionFind(plz: plz, lat: point.lat, lon: point.lon, branches: branches)
    }

    /// Die Fixtures selbst — 450 km auseinander, sonst reproduziert der Test
    /// den Fehler nicht.
    private var pennyGoessnitz: Branch {
        MockFixtures.branches.first { $0.marketId == "penny-04639-1" }!
    }
    private var nettoSchmoelln: Branch {
        MockFixtures.branches.first { $0.marketId == "netto-04626-1" }!
    }
    private var pennyAmHaff: Branch {
        MockFixtures.branches.first { $0.marketId == "penny-17373-1" }!
    }
    private var pennyKarlshagen: Branch {
        MockFixtures.branches.first { $0.marketId == "penny-17449-1" }!
    }

    // MARK: Der eigentliche Fehler

    /// **Die Regression.** Um 04626 steht ein Netto, das Gebiet gilt damit als
    /// geholt. Um 17419 steht ausschließlich Penny — und Penny ist eine der
    /// zwei Ketten, die bundesweit im Verzeichnis stehen, weil ihre ganze
    /// Deutschlandliste einen Request kostet. Genau das heißt „dieses Gebiet
    /// hat nie jemand geholt".
    ///
    /// Zusammengeworfen verdeckte das Schmöllner Netto dieses Zeichen: Die
    /// Prüfung lief einmal über alle Funde, fand eine gebietsweise Kette und
    /// hielt damit **beide** Regionen für vollständig. Für 17419 ging nie eine
    /// Anforderung raus — und weil nichts fehlschlug, hätte sich das auch nie
    /// von selbst repariert.
    func testEachRegionAsksForItselfEvenWhenAnotherIsAlreadyComplete() {
        let plan = PickerDirectory.plan([
            find("04626", schmoelln, [pennyGoessnitz, nettoSchmoelln]),
            find("17419", ahlbeck, [pennyAmHaff, pennyKarlshagen]),
        ])

        XCTAssertEqual(plan.areaCandidates.map(\.plz), ["17419"])

        // So sah dieselbe Frage vorher aus — über alle Funde auf einmal, und
        // damit von der besser bestückten Region beantwortet.
        let merged = [pennyGoessnitz, nettoSchmoelln, pennyAmHaff, pennyKarlshagen]
        XCTAssertFalse(
            AreaRequestStore.areaLooksUnfetched(merged),
            "Der zusammengeworfene Topf sah vollständig aus — das war der Fehler"
        )
    }

    /// Der Anker muss in der Region liegen, für die angefordert wird. Vorher
    /// war es das globale Minimum über alle Funde: Bei einer nahen und einer
    /// fernen Region hätte die ferne einen Anker bekommen, der 450 km entfernt
    /// liegt — und das Backend leitet das Gebiet aus genau dieser Filiale ab.
    func testTheAnchorComesFromTheRegionItAsksFor() {
        let plan = PickerDirectory.plan([
            find("04626", schmoelln, [pennyGoessnitz, nettoSchmoelln]),
            find("17419", ahlbeck, [pennyAmHaff, pennyKarlshagen]),
        ])

        let candidate = try! XCTUnwrap(plan.areaCandidates.first)
        XCTAssertEqual(candidate.plz, "17419")
        // Am Haff (~23 km) liegt näher an Ahlbeck als Karlshagen (~26 km).
        XCTAssertEqual(candidate.anchor.marketId, pennyAmHaff.marketId)
    }

    /// Steht in einer Region eine der sechs gebietsweisen Ketten, ist dort
    /// nichts anzufordern — auch dann nicht, wenn die Nachbarregion leer ist.
    func testACompleteRegionIsNotRequestedAgain() {
        let plan = PickerDirectory.plan([
            find("04626", schmoelln, [pennyGoessnitz, nettoSchmoelln]),
        ])
        XCTAssertTrue(plan.areaCandidates.isEmpty)
    }

    // MARK: Entfernungen

    /// Jede Zeile weiß, ab welcher PLZ sie gemessen wurde. Ohne das kann die
    /// Liste die Zahl nicht erklären, und mit zwei weit entfernten Regionen
    /// standen 7,6 km über 22 km, gemessen von verschiedenen Punkten.
    func testEveryStoreKnowsWhichRegionItsDistanceIsMeasuredFrom() {
        let plan = PickerDirectory.plan([
            find("04626", schmoelln, [pennyGoessnitz, nettoSchmoelln]),
            find("17419", ahlbeck, [pennyAmHaff, pennyKarlshagen]),
        ])

        XCTAssertEqual(plan.byMarketId[pennyGoessnitz.marketId]?.anchorPLZ, "04626")
        XCTAssertEqual(plan.byMarketId[pennyAmHaff.marketId]?.anchorPLZ, "17419")

        // Und die Zahlen sind plausibel: alles im Umkreis, nichts quer durch
        // Deutschland.
        for entry in plan.entries {
            let km = try! XCTUnwrap(entry.distanceKm)
            XCTAssertLessThan(km, 40, "\(entry.branch.name) misst \(km) km ab \(entry.anchorPLZ)")
        }
    }

    /// Der PLZ-Grenzfall, für den es die Regionen überhaupt gibt: Dieselbe
    /// Filiale taucht um beide Postleitzahlen auf. Sie gehört der näheren —
    /// einmal, nicht zweimal.
    func testAStoreFoundAroundTwoRegionsBelongsToTheNearerOne() {
        // Ein Laden dicht bei Schmölln, der auch im weiten Umkreis von
        // Gößnitz auftaucht.
        let shared = branch("shared-1", chain: "Lidl", lat: 50.8960, lon: 12.3600)
        let goessnitzPoint = (lat: 50.8875, lon: 12.4333)

        let plan = PickerDirectory.plan([
            find("04639", goessnitzPoint, [shared]),
            find("04626", schmoelln, [shared]),
        ])

        XCTAssertEqual(plan.entries.count, 1, "die Filiale steht doppelt in der Liste")
        XCTAssertEqual(plan.byMarketId["shared-1"]?.anchorPLZ, "04626")
    }

    /// Gleich weit von beiden: Die zuerst übergebene Region gewinnt, damit das
    /// Ergebnis nicht von der Reihenfolge eines Dictionaries abhängt.
    func testATieGoesToTheFirstRegion() {
        let shared = branch("shared-1", chain: "Lidl", lat: 51.0, lon: 13.0)
        let plan = PickerDirectory.plan([
            find("11111", (lat: 51.0, lon: 12.9), [shared]),
            find("22222", (lat: 51.0, lon: 13.1), [shared]),
        ])
        XCTAssertEqual(plan.byMarketId["shared-1"]?.anchorPLZ, "11111")
    }

    /// Eine Zeile ohne Koordinaten bleibt wählbar — ein Laden, dessen Position
    /// wir nicht kennen, ist immer noch ein Laden. Sie trägt nur keine
    /// Entfernung, und die Liste sortiert sie deshalb nach hinten.
    func testAStoreWithoutCoordinatesStaysSelectableWithoutADistance() {
        let noCoordinates = branch("blind-1", chain: "EDEKA", lat: nil, lon: nil)
        let plan = PickerDirectory.plan([
            find("04626", schmoelln, [noCoordinates, nettoSchmoelln]),
        ])

        XCTAssertEqual(plan.entries.count, 2)
        XCTAssertNil(plan.byMarketId["blind-1"]?.distanceKm)
    }

    /// Eine Region ganz ohne Funde ist kein Signal, sondern eine gescheiterte
    /// Suche — und ohne Filiale gäbe es ohnehin keinen Anker.
    func testARegionWithoutAnyFindsIsNotRequested() {
        let plan = PickerDirectory.plan([find("17419", ahlbeck, [])])
        XCTAssertTrue(plan.areaCandidates.isEmpty)
        XCTAssertTrue(plan.entries.isEmpty)
    }

    /// Eine Region, in der nur koordinatenlose Zeilen stehen, hat keinen Anker
    /// — und darf deshalb auch keinen erfinden.
    func testARegionWithOnlyCoordinatelessRowsHasNoAnchor() {
        let blind = branch("blind-1", chain: "Penny", lat: nil, lon: nil)
        let plan = PickerDirectory.plan([find("17419", ahlbeck, [blind])])
        XCTAssertTrue(plan.areaCandidates.isEmpty)
    }

    // MARK: Die Fixtures

    /// Die neuen Filialen liegen weit genug weg, dass ein Lauf mit nur 01219
    /// sie nie sieht — sonst hätten die bestehenden Journeys über Nacht andere
    /// Läden im Picker.
    func testTheNewFixturesAreOutOfReachOfTheDresdenJourneys() {
        for far in [pennyGoessnitz, nettoSchmoelln, pennyAmHaff, pennyKarlshagen] {
            let km = try! XCTUnwrap(far.distanceKm(from: dresden.lat, dresden.lon))
            XCTAssertGreaterThan(
                km, MarketPickerView.maxRadiusKm,
                "\(far.name) läge im Dresdner Suchradius"
            )
        }
    }
}
