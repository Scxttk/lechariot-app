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
