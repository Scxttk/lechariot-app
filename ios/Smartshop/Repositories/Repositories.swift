import Foundation

protocol OfferRepositoryProtocol {
    /// Offers for the given PLZ regions, newest validity first.
    /// `chains` restricts results to those market chains; empty means all chains.
    func offers(regions: [String], chains: [String]) async throws -> [Offer]
}

protocol MarketRepositoryProtocol {
    /// Markets in the given PLZ regions, sorted by chain then branch name.
    func markets(plzs: [String]) async throws -> [Market]
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
