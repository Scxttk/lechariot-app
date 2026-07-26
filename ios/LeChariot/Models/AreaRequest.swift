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
struct AreaRequest: Codable, Equatable, Identifiable {
    /// The store the request was anchored on.
    let marketId: String
    /// Filled in by the backend from `branches`, never by the app.
    let plz: String?
    let lastSynced: String?
    let active: Bool?

    var id: String { marketId }

    /// True once the directory run for this area has finished.
    var isReady: Bool { lastSynced != nil }

    enum CodingKeys: String, CodingKey {
        case active
        case plz
        case marketId = "market_id"
        case lastSynced = "last_synced"
    }
}
