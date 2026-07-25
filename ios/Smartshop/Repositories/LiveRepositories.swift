import Foundation

struct LiveOfferRepository: OfferRepositoryProtocol {
    let client: SupabaseClient
    private let pageSize = 1000

    func offers(regions: [String]) async throws -> [Offer] {
        guard !regions.isEmpty else { return [] }
        var all: [Offer] = []
        var offset = 0
        while true {
            // Legacy rows (pre-enrichment sources) carry null validity dates and
            // would fail decoding; the contract requires both dates to be set.
            // `region.is.null` pulls the nationwide rows in alongside the
            // regional ones: ALDI is stored once for the whole country, so a
            // plain `region=in.(…)` would leave both ALDI chains off the
            // screen entirely.
            let query = "select=*&order=valid_from.desc"
                + "&valid_from=not.is.null&valid_until=not.is.null"
                + "&or=(region.in.(\(regions.joined(separator: ","))),region.is.null)"
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

    func history(market: String, product: String, region: String?) async throws -> [PriceHistoryPoint] {
        // Product names carry spaces, umlauts and percent signs — unencoded
        // they don't survive `URL(string:)`. See SupabaseClient.filterValue.
        guard let market = SupabaseClient.filterValue(market),
              let product = SupabaseClient.filterValue(product)
        else { return [] }
        // A nationwide offer has no region; `eq.` never matches NULL, so the
        // history sheet would have stayed empty for both ALDI chains.
        let regionFilter: String
        if let region {
            guard let encoded = SupabaseClient.filterValue(region) else { return [] }
            regionFilter = "region=eq.\(encoded)"
        } else {
            regionFilter = "region=is.null"
        }
        let query = "select=market,product,region,price,regular_price,valid_from,valid_until"
            + "&\(regionFilter)&market=eq.\(market)&product=eq.\(product)"
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

struct LiveRegionRepository: RegionRepositoryProtocol {
    let client: SupabaseClient

    func region(plz: String) async throws -> Region? {
        let query = "select=plz,last_synced,active&plz=eq.\(plz)"
        return try await client.get([Region].self, path: "regions", query: query).first
    }

    func registerRegion(plz: String) async throws {
        // Inserts only {plz} with the anon key. The regions INSERT policy is now
        // hardened server-side (supabase/migration_regions.sql): anon may set
        // ONLY the plz column (not last_synced/active), and the plz must be a
        // 5-digit string — so this single-{plz} request keeps working unchanged.
        //
        // Residual client-side hardening (recommended follow-up, F5): the anon
        // key is extractable from the app bundle, so a caller can still POST many
        // distinct valid PLZs directly. The DB dispatch trigger (backend repo)
        // gets a per-PLZ cooldown to bound CI cost; the fuller client fix is to
        // route registration through an authenticated, rate-limited edge function
        // that enforces a per-install quota and mirrors the server-side maxRegions.
        // That is a larger change (new function + auth/quota state) and is left as
        // a follow-up rather than half-implemented here.
        try await client.post(path: "regions", body: ["plz": plz], acceptConflict: true)
    }

    func foundMarkets(plz: String) async throws -> [Market] {
        let query = "select=chain,branch_name,market_id,plz"
            + "&plz=eq.\(plz)&order=chain.asc"
        return try await client.getList(Market.self, path: "markets", query: query)
    }

    func offerCount(plz: String) async throws -> Int {
        try await client.count(path: "offers", query: "region=eq.\(plz)")
    }
}
