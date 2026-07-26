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

    /// Chain name, plus the branch when the chain has exactly one favorited
    /// branch across the shown regions. Two Lidls → just "Lidl", because
    /// naming one of them would be a guess. Used by the offer sections and the
    /// detail sheet, so the rule exists once.
    static func displayTitle(chain: String, favorites: [Market]) -> String {
        let branches = favorites.filter { $0.chain == chain }
        guard branches.count == 1, !branches[0].branchName.isEmpty else { return chain }
        let branch = branches[0].branchName
        // Most chains already put their own name in front of the branch
        // ("Kaufland Dresden-Strehlen"). Prefixing again reads as a stutter.
        guard !branch.lowercased().hasPrefix(chain.lowercased()) else { return branch }
        return "\(chain) – \(branch)"
    }
}
