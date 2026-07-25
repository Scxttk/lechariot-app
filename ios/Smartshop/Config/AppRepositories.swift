import Foundation

/// One place that decides whether the app talks to Supabase or to fixtures.
///
/// This decision used to live in two places — `SmartshopApp.init` and a static
/// in `ContentView`, the latter carrying a comment promising it "mirrors" the
/// former. Two copies of a rule is one copy too many, especially for a rule
/// that decides whether the app hits the network at all.
///
/// Mocks are used when no `APIKeys.plist` is configured (CI, a fresh clone) and,
/// in debug builds, when the app is launched for UI testing — those runs must
/// not depend on the backend being up or on which offers happen to be live this
/// week.
enum AppRepositories {
    static let usesMockData: Bool = {
        #if DEBUG
        if UITestSupport.isActive { return true }
        #endif
        return SupabaseClient.fromConfig() == nil
    }()

    private static let client: SupabaseClient? = usesMockData ? nil : SupabaseClient.fromConfig()

    static func regions() -> RegionRepositoryProtocol {
        guard let client else { return MockRegionRepository() }
        return LiveRegionRepository(client: client)
    }

    static func markets() -> MarketRepositoryProtocol {
        guard let client else { return MockMarketRepository() }
        return LiveMarketRepository(client: client)
    }

    /// The store directory. Read-only and public, so there is nothing to gate
    /// beyond the usual mock/live decision.
    static let branches: BranchRepositoryProtocol = {
        guard let client else { return MockBranchRepository() }
        return LiveBranchRepository(client: client)
    }()

    static func branchRequests() -> BranchRequestRepositoryProtocol {
        guard let client else { return MockBranchRequestRepository() }
        return LiveBranchRequestRepository(client: client)
    }

    static let offers: OfferRepositoryProtocol = {
        guard let client else { return MockOfferRepository() }
        return LiveOfferRepository(client: client)
    }()

    static let priceHistory: PriceHistoryRepositoryProtocol = {
        guard let client else { return MockPriceHistoryRepository() }
        return LivePriceHistoryRepository(client: client)
    }()

    /// nil disables profile sync entirely — `ProfileStore` then never uploads,
    /// which is what a mock run should do.
    static func profiles() -> ProfileRepositoryProtocol? {
        guard let client else { return nil }
        return LiveProfileRepository(client: client)
    }

    /// nil disables match feedback entirely — the sheet still appears and can
    /// be filled in, nothing is uploaded. Same rule as `profiles()`.
    static func matchFeedback() -> MatchFeedbackRepositoryProtocol? {
        guard let client else { return nil }
        return LiveMatchFeedbackRepository(client: client)
    }
}
