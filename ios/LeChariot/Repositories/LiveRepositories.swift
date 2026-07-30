import Foundation

struct LiveOfferRepository: OfferRepositoryProtocol {
    let client: SupabaseClient
    private let pageSize = 1000

    func offers(branchIds: [String]) async throws -> [Offer] {
        guard !branchIds.isEmpty else { return [] }
        var all: [Offer] = []
        var offset = 0
        while true {
            // Legacy rows (pre-enrichment sources) carry null validity dates and
            // would fail decoding; the contract requires both dates to be set.
            // Asked for by BRANCH, not by postcode. A postcode fetched every
            // store in it — in 01067 that is three REWE flyers at once, of
            // which the user walks into one. The nationwide rows come along
            // because they belong to every branch of their chain (ALDI,
            // stored once for the whole country).
            let query = "select=*&order=valid_from.desc"
                + "&valid_from=not.is.null&valid_until=not.is.null"
                + "&or=(market_id.in.(\(branchIds.joined(separator: ","))),nationwide.is.true)"
                + "&limit=\(pageSize)&offset=\(offset)"
            // Decode per element so one malformed row cannot sink the fetch.
            // Pagination must count raw rows, not surviving ones, so the raw
            // failable page drives the termination check.
            let page = try await client.get([FailableElement<Offer>].self, path: "offers", query: query)
            all.append(contentsOf: page.compactMap(\.value))
            if page.count < pageSize { break }
            offset += pageSize
        }
        return all
    }
}

struct LivePriceHistoryRepository: PriceHistoryRepositoryProtocol {
    let client: SupabaseClient
    /// Half a year of weeks is more than anyone reads in a sheet.
    private let limit = 26

    func history(market: String, product: String) async throws -> [PriceHistoryPoint] {
        // Product names carry spaces, umlauts and percent signs — unencoded
        // they don't survive `URL(string:)`. See SupabaseClient.filterValue.
        guard let market = SupabaseClient.filterValue(market),
              let product = SupabaseClient.filterValue(product)
        else { return [] }
        // No branch filter: since migration v16 a chain publishes one price
        // per product and week at a given branch, and the history is what that
        // price was in the weeks before. Narrowing further would leave the
        // sheet empty whenever the user switched branches.
        let query = "select=market,product,nationwide,price,regular_price,valid_from,valid_until"
            + "&market=eq.\(market)&product=eq.\(product)"
            + "&valid_from=not.is.null&valid_until=not.is.null"
            + "&order=valid_from.asc&limit=\(limit)"
        return try await client.getList(PriceHistoryPoint.self, path: "price_history", query: query)
    }
}

/// Reads the store directory `public.branches` (migration v12). Public read,
/// no writes — the directory is backend data, not a queue.
struct LiveBranchRepository: BranchRepositoryProtocol {
    let client: SupabaseClient
    /// Upper bound per query. A city block has tens of stores, not hundreds;
    /// anything beyond this is a runaway box, not a list anyone scrolls.
    private let limit = 200
    private let columns = "select=market_id,chain,name,street,plz,city,lat,lon"

    func nearby(lat: Double, lon: Double, radiusKm: Double) async throws -> [Branch] {
        let box = Geo.boundingBox(lat: lat, lon: lon, radiusKm: radiusKm)
        // A box, not a radius: without PostGIS the two btree columns behind
        // `branches_lat_lon_idx` can answer a range, not a circle. The corners
        // it adds are cut off below, in Swift, where the real distance is
        // known anyway because the list is sorted by it.
        let query = columns
            + "&lat=gte.\(box.minLat)&lat=lte.\(box.maxLat)"
            + "&lon=gte.\(box.minLon)&lon=lte.\(box.maxLon)"
            + "&limit=\(limit)"
        let rows = try await client.getList(Branch.self, path: "branches", query: query)
        return rows
            .compactMap { branch -> (Branch, Double)? in
                guard let distance = branch.distanceKm(from: lat, lon), distance <= radiusKm
                else { return nil }
                return (branch, distance)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    func branch(marketId: String) async throws -> Branch? {
        guard let marketId = SupabaseClient.filterValue(marketId) else { return nil }
        let query = columns + "&market_id=eq.\(marketId)&limit=1"
        return try await client.getList(Branch.self, path: "branches", query: query).first
    }
}

struct LiveMarketRepository: MarketRepositoryProtocol {
    let client: SupabaseClient

    func markets(plzs: [String]) async throws -> [Market] {
        guard !plzs.isEmpty else { return [] }
        let query = "select=chain,branch_name,market_id,plz"
            + "&plz=in.(\(plzs.joined(separator: ",")))"
            + "&order=chain.asc,branch_name.asc"
        return try await client.getList(Market.self, path: "markets", query: query)
    }
}

struct LiveProfileRepository: ProfileRepositoryProtocol {
    let client: SupabaseClient

    func upload(_ profile: SyncedProfile) async throws {
        // Same anon-INSERT shape as registerRegion: the table has an insert
        // policy but no select policy, so the anon key can write and nothing else.
        try await client.post(path: "user_profiles", body: profile)
    }
}

struct LiveMatchFeedbackRepository: MatchFeedbackRepositoryProtocol {
    let client: SupabaseClient

    func submit(_ report: MatchFeedbackReport) async throws {
        // Insert policy, no select policy — see supabase/migration_match_feedback.sql.
        try await client.post(path: "match_feedback", body: report)
    }
}

/// Requests offers for a single store (`public.branch_requests`, backend
/// migration v14).
struct LiveBranchRequestRepository: BranchRequestRepositoryProtocol {
    let client: SupabaseClient

    func request(marketId: String) async throws -> BranchRequest? {
        guard let marketId = SupabaseClient.filterValue(marketId) else { return nil }
        let query = "select=market_id,last_synced,active&market_id=eq.\(marketId)"
        return try await client.get([BranchRequest].self, path: "branch_requests", query: query).first
    }

    func requestBranch(marketId: String) async throws {
        // Only {market_id} goes over the wire, and that is all the server
        // accepts: the INSERT grant is column-restricted, and the policy
        // additionally requires the id to exist in `branches`. Both were
        // verified against the live database with this very key on
        // 2026-07-25 — an invented id comes back as 42501, and naming any
        // control column fails with "permission denied for column".
        try await client.post(
            path: "branch_requests",
            body: ["market_id": marketId],
            acceptConflict: true
        )
    }
}

/// Requests the store directory for a whole area (`public.area_requests`,
/// backend migration v19).
struct LiveAreaRequestRepository: AreaRequestRepositoryProtocol {
    let client: SupabaseClient

    func request(marketId: String) async throws -> AreaRequest? {
        guard let marketId = SupabaseClient.filterValue(marketId) else { return nil }
        let query = "select=market_id,plz,lat,lon,last_synced,active&market_id=eq.\(marketId)"
        return try await client.get([AreaRequest].self, path: "area_requests", query: query).first
    }

    /// Anker plus Regionsmitte — mehr nimmt der Server nicht an.
    ///
    /// Die INSERT-Rechte sind spaltenweise vergeben (`market_id`, `lat`, `lon`),
    /// und die Policy verlangt, dass der Anker in `branches` steht. `plz` ist
    /// **nicht** dabei: Sie setzt ein BEFORE-INSERT-Trigger, und würde die App
    /// sie benennen, scheiterte der Insert an den Spaltenrechten. Genau das ist
    /// der Zweck — eine unprüfbare Postleitzahl erreicht die Warteschlange nie.
    ///
    /// Die Koordinaten sind dagegen prüfbar, und deshalb dürfen sie mit: Der
    /// Trigger misst sie gegen die Lage des Ankers und verwirft sie, wenn mehr
    /// als 60 km dazwischen liegen. Ohne diese beiden Zahlen leitet der Server
    /// das Gebiet weiter aus der Ankerfiliale ab — was für einen Tester in
    /// Ahlbeck das Verzeichnis von Ueckermünde bedeutete.
    func requestArea(marketId: String, lat: Double?, lon: Double?) async throws {
        struct Body: Encodable {
            let market_id: String
            let lat: Double?
            let lon: Double?
        }
        try await client.post(
            path: "area_requests",
            body: Body(market_id: marketId, lat: lat, lon: lon),
            acceptConflict: true
        )
    }
}

