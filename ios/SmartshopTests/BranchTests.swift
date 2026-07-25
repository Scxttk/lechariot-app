import XCTest
@testable import Smartshop

/// The store directory (`public.branches`, migration v12) is what makes the
/// second REWE in a postcode reachable at all. These tests pin the geometry it
/// stands on: the app asks Supabase for a bounding box (no PostGIS in the free
/// tier) and has to cut the corners off itself.
final class BranchTests: XCTestCase {
    // Dresden Postplatz, one of Scott's wanted stores.
    private let postplatz = (lat: 51.0504, lon: 13.7317)

    private func branch(_ id: String, lat: Double?, lon: Double?) -> Branch {
        Branch(marketId: id, chain: "REWE", name: "REWE \(id)", street: nil,
               plz: nil, city: nil, lat: lat, lon: lon)
    }

    // MARK: Distance

    func testDistanceBetweenTwoDresdenStores() {
        // Postplatz -> Friedrichstadt, ~1.2 km by air.
        let d = Geo.distanceKm(from: postplatz, to: (51.0561, 13.7203))
        XCTAssertEqual(d, 1.0, accuracy: 0.3)
    }

    func testDistanceIsZeroForTheSamePoint() {
        XCTAssertEqual(Geo.distanceKm(from: postplatz, to: postplatz), 0, accuracy: 0.0001)
    }

    func testDistanceIsSymmetric() {
        let a = Geo.distanceKm(from: postplatz, to: (51.0155, 13.7669))
        let b = Geo.distanceKm(from: (51.0155, 13.7669), to: postplatz)
        XCTAssertEqual(a, b, accuracy: 0.0001)
    }

    func testBranchWithoutCoordinatesHasNoDistance() {
        // Kept in the directory on purpose: a store whose position we don't
        // know is still a store. It just cannot be sorted by distance.
        XCTAssertNil(branch("x", lat: nil, lon: nil).distanceKm(from: postplatz.lat, postplatz.lon))
        XCTAssertNil(branch("y", lat: 51.0, lon: nil).distanceKm(from: postplatz.lat, postplatz.lon))
    }

    // MARK: Bounding box

    func testBoxCoversTheWholeRadius() {
        let box = Geo.boundingBox(lat: postplatz.lat, lon: postplatz.lon, radiusKm: 10)
        // Every point exactly 10 km north/south/east/west must be inside.
        let north = postplatz.lat + 10 / 111.32
        let east = postplatz.lon + 10 / (111.32 * cos(postplatz.lat * .pi / 180))
        XCTAssertLessThanOrEqual(north, box.maxLat + 1e-9)
        XCTAssertLessThanOrEqual(east, box.maxLon + 1e-9)
        XCTAssertGreaterThanOrEqual(postplatz.lat - 10 / 111.32, box.minLat - 1e-9)
    }

    // Regression guard for the mistake this formula exists to avoid: a degree
    // of longitude is ~70 km at Dresden's latitude, not 111. Without the
    // cosine the box would be a third too narrow east-west and would drop
    // stores well inside the radius.
    func testBoxIsWiderInLongitudeThanInLatitude() {
        let box = Geo.boundingBox(lat: postplatz.lat, lon: postplatz.lon, radiusKm: 10)
        let latSpan = box.maxLat - box.minLat
        let lonSpan = box.maxLon - box.minLon
        XCTAssertGreaterThan(lonSpan, latSpan * 1.5)
    }

    func testBoxDoesNotBlowUpAtThePole() {
        // cos(90°) is 0; unguarded the longitude span would be infinite.
        let box = Geo.boundingBox(lat: 89.999, lon: 0, radiusKm: 10)
        XCTAssertTrue(box.maxLon.isFinite && box.minLon.isFinite)
        XCTAssertLessThan(box.maxLon - box.minLon, 360)
    }

    // MARK: Repository

    func testNearbySortsByDistanceAndDropsWhatIsOutsideTheRadius() async throws {
        let repo = MockBranchRepository()
        let near = try await repo.nearby(lat: postplatz.lat, lon: postplatz.lon, radiusKm: 2)
        // Postplatz itself first, Friedrichstadt second, Strehlen (~5 km) out.
        XCTAssertEqual(near.map(\.marketId), ["1766063", "1766160"])

        let wide = try await repo.nearby(lat: postplatz.lat, lon: postplatz.lon, radiusKm: 10)
        XCTAssertEqual(wide.map(\.marketId), ["1766063", "1766160", "4816"])
    }

    func testNearbyIgnoresBranchesWithoutCoordinates() async throws {
        let repo = MockBranchRepository(fixtures: [branch("ohne", lat: nil, lon: nil)])
        let near = try await repo.nearby(lat: postplatz.lat, lon: postplatz.lon, radiusKm: 50)
        XCTAssertTrue(near.isEmpty)
    }

    func testBranchLookupByIdFindsTheStoredFavourite() async throws {
        let repo = MockBranchRepository()
        let hit = try await repo.branch(marketId: "4816")
        XCTAssertEqual(hit?.name, "Netto Marken-Discount Dresden-Strehlen")
        let miss = try await repo.branch(marketId: "gibt-es-nicht")
        XCTAssertNil(miss)
    }

    // MARK: Decoding + display

    func testDecodesTheSupabaseRow() throws {
        let json = """
        {"market_id":"1766063","chain":"REWE","name":"REWE Ketzscher oHG am Postplatz",
         "street":"Wallstr. 2b","plz":"01067","city":"Dresden","lat":51.0504,"lon":13.7317}
        """.data(using: .utf8)!
        let branch = try JSONDecoder().decode(Branch.self, from: json)
        XCTAssertEqual(branch.marketId, "1766063")
        XCTAssertEqual(branch.addressLine, "Wallstr. 2b, 01067 Dresden")
    }

    func testDecodesARowWhoseFinderGaveNoAddress() throws {
        // Eight finders, eight levels of detail — a row without street or
        // coordinates must still decode instead of sinking the whole page.
        let json = """
        {"market_id":"x","chain":"EDEKA","name":"EDEKA Testmarkt",
         "street":null,"plz":null,"city":null,"lat":null,"lon":null}
        """.data(using: .utf8)!
        let branch = try JSONDecoder().decode(Branch.self, from: json)
        XCTAssertEqual(branch.addressLine, "")
    }
}
