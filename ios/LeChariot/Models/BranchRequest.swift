import Foundation

/// Row of the Supabase `branch_requests` table (backend migration v14) — the
/// app's way of saying "I picked this store, please fetch its offers".
///
/// Inserting a row fires a
/// database trigger that dispatches the backend's nightly workflow for exactly
/// this store; the app then polls `lastSynced`. Measured end to end on
/// 2026-07-25: insert to running workflow took **one second**, insert to 162
/// finished offers **43 seconds**.
///
/// The insert is column-restricted to `market_id` server-side, and the store
/// has to exist in the directory (`branches`) — an invented id is rejected
/// with 42501. That is the check the PLZ path never had, which is how a
/// postcode that does not exist (94108) became an active region.
struct BranchRequest: Codable, Equatable, Identifiable {
    let marketId: String
    let lastSynced: String?
    let active: Bool?

    var id: String { marketId }

    /// True once the backend has pushed this store's offers at least once.
    var isReady: Bool { lastSynced != nil }

    enum CodingKeys: String, CodingKey {
        case active
        case marketId = "market_id"
        case lastSynced = "last_synced"
    }
}
