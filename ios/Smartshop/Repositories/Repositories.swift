import Foundation

protocol OfferRepositoryProtocol {
    /// ALL offers for the given PLZ regions, newest validity first — never
    /// narrowed to chains: the cache must hold the complete tagged set per
    /// region (KW-Cache), display filtering happens in memory (OfferStore).
    func offers(regions: [String]) async throws -> [Offer]
}

protocol PriceHistoryRepositoryProtocol {
    /// Recorded offer weeks for one product at one market in one region,
    /// oldest first. An empty result is a normal answer, not an error — the
    /// table only started filling up recently.
    func history(market: String, product: String, region: String) async throws -> [PriceHistoryPoint]
}

protocol MarketRepositoryProtocol {
    /// Markets in the given PLZ regions, sorted by chain then branch name.
    func markets(plzs: [String]) async throws -> [Market]
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
    func offerCount(plz: String) async throws -> Int
}
