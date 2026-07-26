import Foundation

protocol OfferRepositoryProtocol {
    /// ALL offers of the given branches, newest validity first — never
    /// narrowed to chains: the cache must hold the complete tagged set per
    /// region (KW-Cache), display filtering happens in memory (OfferStore).
    func offers(branchIds: [String]) async throws -> [Offer]
}

protocol PriceHistoryRepositoryProtocol {
    /// Recorded offer weeks for one product at one market,
    /// oldest first. An empty result is a normal answer, not an error — the
    /// table only started filling up recently.
    func history(market: String, product: String) async throws -> [PriceHistoryPoint]
}

protocol MarketRepositoryProtocol {
    /// Markets in the given PLZ regions, sorted by chain then branch name.
    func markets(plzs: [String]) async throws -> [Market]
}

protocol BranchRepositoryProtocol {
    /// Stores within `radiusKm` of a point, nearest first. Rows without
    /// coordinates never appear here — they cannot be placed on a map and the
    /// query filters on a bounding box.
    func nearby(lat: Double, lon: Double, radiusKm: Double) async throws -> [Branch]
    /// One store by its id, or nil if the directory doesn't know it. Used when
    /// a stored favourite has to be shown again after a restart.
    func branch(marketId: String) async throws -> Branch?
}

protocol BranchRequestRepositoryProtocol {
    /// Request row for a store, or nil if nobody has asked for it yet.
    func request(marketId: String) async throws -> BranchRequest?
    /// Asks the backend to fetch this store's offers. Idempotent
    /// (409 = already requested, which is a success, not a problem).
    func requestBranch(marketId: String) async throws
}

protocol AreaRequestRepositoryProtocol {
    /// Request row for an area, keyed on the anchor store, or nil if nobody
    /// has asked for it yet.
    func request(marketId: String) async throws -> AreaRequest?
    /// Asks the backend to fetch the whole directory around this store.
    /// Idempotent, same as `requestBranch`.
    func requestArea(marketId: String) async throws
}

protocol ProfileRepositoryProtocol {
    /// Appends the user's (non-identifying) onboarding answers. Insert-only —
    /// there is no read side, the app never fetches profiles back.
    func upload(_ profile: SyncedProfile) async throws
}

protocol MatchFeedbackRepositoryProtocol {
    /// Appends one rejection reason. Insert-only, same shape as profiles —
    /// the app never reads feedback back.
    func submit(_ report: MatchFeedbackReport) async throws
}

protocol RegionRepositoryProtocol {
    /// Region row for a PLZ, or nil if unknown.
    func region(plz: String) async throws -> Region?
    /// Registers a PLZ for syncing. Idempotent (409 = already registered).
    func registerRegion(plz: String) async throws
    /// Markets the backend has already found for a PLZ mid-sync (each chain
    /// appears here before its offers land). Lightweight; safe to poll.
    func foundMarkets(plz: String) async throws -> [Market]
    /// Number of offer rows already uploaded for a PLZ (HEAD count, no body).
}
