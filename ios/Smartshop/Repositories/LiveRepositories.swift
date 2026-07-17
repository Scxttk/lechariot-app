import Foundation

struct LiveOfferRepository: OfferRepositoryProtocol {
    let client: SupabaseClient
    private let pageSize = 1000

    func offers(regions: [String]) async throws -> [Offer] {
        guard !regions.isEmpty else { return [] }
        var all: [Offer] = []
        var offset = 0
        while true {
            let query = "select=*&order=valid_from.desc"
                + "&region=in.(\(regions.joined(separator: ",")))"
                + "&limit=\(pageSize)&offset=\(offset)"
            let page = try await client.get([Offer].self, path: "offers", query: query)
            all.append(contentsOf: page)
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
        return try await client.get([Market].self, path: "markets", query: query)
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
}
