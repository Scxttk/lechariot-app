import Foundation

/// Row of the Supabase `branches` table — the store directory the app searches
/// to show *nearby* stores. See docs/CONTRACTS.md.
///
/// Not to be confused with `Market`, the row of the older `markets` table.
/// `Market` answers "which store did the backend scrape for this chain in this
/// PLZ" — exactly one per chain and PLZ, which is what made the second REWE in
/// a postcode unreachable. `Branch` is the directory underneath: every store
/// the chains' own finders know about, with an address and coordinates.
///
/// Every address field is optional because the eight finders return different
/// amounts of detail, and a store without a street is still better than no
/// store. `marketId` and `chain` are not: without them the row can neither be
/// scraped nor shown.
struct Branch: Codable, Equatable, Identifiable, Sendable {
    let marketId: String
    let chain: String
    let name: String
    let street: String?
    let plz: String?
    let city: String?
    let lat: Double?
    let lon: Double?

    var id: String { marketId }

    enum CodingKeys: String, CodingKey {
        case chain, name, street, plz, city, lat, lon
        case marketId = "market_id"
    }
}

extension Branch {
    /// Street and city on one line, for the row under the store name. Empty
    /// when the finder gave us neither — the caller then shows nothing rather
    /// than an empty line with padding.
    var addressLine: String {
        [street, [plz, city].compactMap { $0 }.joined(separator: " ")]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: ", ")
    }

    /// Great-circle distance in kilometres, or nil when the row has no
    /// coordinates. Those rows are kept in the directory on purpose (a store
    /// whose position we don't know is still a store), so every caller has to
    /// decide what to do with them — sorting them last is usually right.
    func distanceKm(from lat: Double, _ lon: Double) -> Double? {
        guard let branchLat = self.lat, let branchLon = self.lon else { return nil }
        return Geo.distanceKm(from: (lat, lon), to: (branchLat, branchLon))
    }
}

extension Branch {
    /// The directory entry as the selection model the rest of the app uses.
    ///
    /// `Market` is what favourites, the offer sections and the detail sheet
    /// are built on, and it wants a postcode. A directory row without one is
    /// rare (every one of the 3,115 rows measured on 2026-07-25 had it) but
    /// possible, and an empty string keeps it selectable instead of dropping
    /// a real store over a missing field.
    var asMarket: Market {
        Market(chain: chain, branchName: name, marketId: marketId, plz: plz ?? "")
    }
}

/// The two pieces of geometry the store directory needs. Deliberately not
/// CoreLocation: this has to run in unit tests without a location manager, and
/// both formulas are four lines.
enum Geo {
    /// Mean earth radius. Good to ~0.3 % over Germany, which is far below the
    /// precision of the coordinates the chains publish.
    static let earthRadiusKm = 6371.0

    /// Haversine distance in kilometres.
    static func distanceKm(from: (lat: Double, lon: Double), to: (lat: Double, lon: Double)) -> Double {
        let dLat = (to.lat - from.lat) * .pi / 180
        let dLon = (to.lon - from.lon) * .pi / 180
        let lat1 = from.lat * .pi / 180
        let lat2 = to.lat * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2)
        return 2 * earthRadiusKm * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Bounding box around a point, as (minLat, maxLat, minLon, maxLon).
    ///
    /// The query on `branches` filters on this box instead of a real radius:
    /// there is no PostGIS in the free tier, and two btree columns
    /// (`branches_lat_lon_idx`, migration v12) answer a box for a few tens of
    /// thousands of rows instantly. The box is *larger* than the circle — up
    /// to 41 % more area in the corners — so the caller still has to drop what
    /// lies outside the radius. Doing it the other way round (filtering by
    /// distance in SQL) would mean loading the whole table.
    static func boundingBox(
        lat: Double,
        lon: Double,
        radiusKm: Double
    ) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let latDelta = radiusKm / 111.32
        // A degree of longitude shrinks towards the poles. At 51° (Dresden) it
        // is ~70 km, not 111 — without the cosine the box would be a third too
        // narrow east-west and cut off stores that are well within the radius.
        // Guarded against the poles, where cos goes to zero and the box would
        // blow up to the whole globe.
        let lonDelta = radiusKm / (111.32 * max(cos(lat * .pi / 180), 0.01))
        return (lat - latDelta, lat + latDelta, lon - lonDelta, lon + lonDelta)
    }
}
