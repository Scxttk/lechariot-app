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

struct LiveRegionRepository: RegionRepositoryProtocol {
    let client: SupabaseClient

    func region(plz: String) async throws -> Region? {
        let query = "select=plz,last_synced,active&plz=eq.\(plz)"
        return try await client.get([Region].self, path: "regions", query: query).first
    }

    func registerRegion(plz: String) async throws {
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
