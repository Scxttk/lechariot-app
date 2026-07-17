import Foundation

protocol OfferRepositoryProtocol {
    /// Offers for the given PLZ regions, newest validity first.
    func offers(regions: [String]) async throws -> [Offer]
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
}
