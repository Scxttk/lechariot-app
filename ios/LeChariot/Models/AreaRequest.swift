import Foundation

/// Row of the Supabase `area_requests` table (backend migration v19) — the
/// app's way of saying "nobody has ever fetched the shops around here".
///
/// One level above `BranchRequest`. That one asks for a *store's offers*
/// (~40 s); this one asks for the *directory of a whole area* (~3 min,
/// measured 2026-07-26). Until it comes back, the picker can only show the two
/// chains whose complete German directory costs a single request — Kaufland
/// and Penny. Everything else is fetched per area, on demand.
///
/// The request is keyed on an **anchor store**, never on a postcode. A number
/// cannot be checked; a store id can, against `branches`. That is the lesson
/// from 94108, a postcode that does not exist, became an active region and
/// collected 1,890 offers from its neighbours for a week. The backend looks up
/// the postcode itself — the app never sends one.
///
/// Seit Migration v21 kommen **Koordinaten** dazu, und damit verschiebt sich,
/// woher die PLZ stammt: nicht mehr aus der Ankerfiliale, sondern aus einem
/// Reverse-Geocoding der mitgeschickten Regionsmitte. Der Anker bleibt der
/// Prüfstein — die Lage wird per Haversine gegen ihn gemessen (≤ 60 km) —, und
/// seine PLZ bleibt der Rückfall. Ohne das holte ein Tester in Ahlbeck das
/// Verzeichnis von Ueckermünde, 24,5 km entfernt, und niemandem fiel es auf.
struct AreaRequest: Codable, Equatable, Identifiable {
    /// The store the request was anchored on.
    let marketId: String
    /// Filled in by the backend, never by the app: erst aus der Ankerfiliale,
    /// dann vom Lauf mit der echten PLZ überschrieben.
    let plz: String?
    let lastSynced: String?
    let active: Bool?
    /// Die Regionsmitte, wie der Server sie behalten hat — `nil`, wenn der
    /// Trigger sie verworfen hat (zu weit vom Anker, außerhalb Deutschlands
    /// oder nur eine Hälfte). Dann gilt der Weg von v19.
    let lat: Double?
    let lon: Double?

    var id: String { marketId }

    /// True once the directory run for this area has finished.
    var isReady: Bool { lastSynced != nil }

    enum CodingKeys: String, CodingKey {
        case active
        case plz
        case lat
        case lon
        case marketId = "market_id"
        case lastSynced = "last_synced"
    }
}
