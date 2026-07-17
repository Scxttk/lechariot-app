import Foundation

/// Row of the Supabase `markets` table. See docs/CONTRACTS.md.
struct Market: Codable, Equatable, Identifiable {
    let chain: String
    let branchName: String
    let marketId: String
    let plz: String

    var id: String { marketId }

    enum CodingKeys: String, CodingKey {
        case chain, plz
        case branchName = "branch_name"
        case marketId = "market_id"
    }
}

extension Market {
    /// Placeholder rows for chains whose offers apply nationwide carry a
    /// `market_id` with the suffix "_DE" (e.g. `LIDL_DE`) instead of a real
    /// branch id. Once the backend delivers real branches (ids without the
    /// suffix), they automatically count as regular markets again.
    var isNationwide: Bool { marketId.hasSuffix("_DE") }
}
