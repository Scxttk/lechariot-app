import Foundation

/// Search filter for the cross-chain branch picker: case- and
/// diacritic-insensitive substring match on chain, branch name and PLZ.
enum MarketFilter {
    /// Chains the user may know locally but for which the backend has no
    /// offer data. Shown in the picker as "keine Daten verfügbar" so their
    /// absence reads as a known gap, not a bug.
    static let chainsWithoutData = ["Konsum"]

    static func matches(_ market: Market, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return [market.chain, market.branchName, market.plz].contains {
            $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    static func filter(_ markets: [Market], query: String) -> [Market] {
        markets.filter { matches($0, query: query) }
    }
}
