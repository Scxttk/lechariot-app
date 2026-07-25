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
            let query = "select=*&order=valid_from.desc"
                + "&valid_from=not.is.null&valid_until=not.is.null"
                + "&region=in.(\(regions.joined(separator: ",")))"
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

    func history(market: String, product: String, region: String) async throws -> [PriceHistoryPoint] {
        // Product names carry spaces, umlauts and percent signs — unencoded
        // they don't survive `URL(string:)`. See SupabaseClient.filterValue.
        guard let market = SupabaseClient.filterValue(market),
              let product = SupabaseClient.filterValue(product),
              let region = SupabaseClient.filterValue(region)
        else { return [] }
        let query = "select=market,product,region,price,regular_price,valid_from,valid_until"
            + "&region=eq.\(region)&market=eq.\(market)&product=eq.\(product)"
            + "&valid_from=not.is.null&valid_until=not.is.null"
            + "&order=valid_from.asc&limit=\(limit)"
        return try await client.getList(PriceHistoryPoint.self, path: "price_history", query: query)
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
