import Foundation
import Observation

/// Lifecycle of one store between "user picked it" and "its offers are here".
/// This is the only waiting left in the app — the PLZ path that used to have
/// its own version was removed once the postcode became a mere location.
enum BranchSyncState: Equatable {
    case unknown
    /// No request row existed; insert sent, waiting for the backend.
    case requested
    /// Row exists but `last_synced` is still nil.
    case syncing
    /// The backend has pushed this store's offers at least once.
    case ready
    case failed(BranchSyncFailure)
}

enum BranchSyncFailure: Equatable {
    /// Network/server error during check or registration.
    case network
    /// Polling exhausted; the backend will usually deliver overnight.
    case timedOut
}

/// Drives "I picked a store the backend has never fetched".
///
/// The whole path exists in the backend since migration v14 and was measured
/// end to end on 2026-07-25: the insert dispatched the workflow after **one
/// second**, the offers were live after **43 seconds**. The polling here is
/// built for that order of magnitude, not for the ten minutes a whole region
/// used to take — hence the shorter default interval than `RegionStore`.
@MainActor
@Observable
final class BranchRequestStore {
    private let repository: BranchRequestRepositoryProtocol
    private let pollInterval: Duration
    private let maxPollAttempts: Int

    private(set) var states: [String: BranchSyncState] = [:]
    private var pollTasks: [String: Task<Void, Never>] = [:]

    init(
        repository: BranchRequestRepositoryProtocol,
        pollInterval: Duration = .seconds(10),
        maxPollAttempts: Int = 30
    ) {
        self.repository = repository
        self.pollInterval = pollInterval
        self.maxPollAttempts = maxPollAttempts
    }

    func state(for marketId: String) -> BranchSyncState {
        states[marketId] ?? .unknown
    }

    /// True when this store needs no waiting screen at all.
    func isReady(_ marketId: String) -> Bool {
        state(for: marketId) == .ready
    }

    /// Asks for a store's offers and follows the request to the end.
    ///
    /// Checks first and only inserts when no row exists: a second request for
    /// the same store would hit the trigger's 10-minute cooldown and silently
    /// do nothing, so the app would be waiting for a run that was never
    /// dispatched. Reading first turns that into "it is already on its way".
    func request(_ marketId: String) async {
        pollTasks[marketId]?.cancel()
        do {
            if let existing = try await repository.request(marketId: marketId) {
                if existing.isReady {
                    states[marketId] = .ready
                } else {
                    states[marketId] = .syncing
                    startPolling(marketId)
                }
            } else {
                try await repository.requestBranch(marketId: marketId)
                states[marketId] = .requested
                startPolling(marketId)
            }
        } catch {
            states[marketId] = .failed(.network)
        }
    }

    func retry(_ marketId: String) async {
        await request(marketId)
    }

    func cancelPolling(for marketId: String) {
        pollTasks[marketId]?.cancel()
        pollTasks[marketId] = nil
    }

    private func startPolling(_ marketId: String) {
        pollTasks[marketId] = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<maxPollAttempts {
                try? await Task.sleep(for: pollInterval)
                if Task.isCancelled { return }
                guard let row = try? await repository.request(marketId: marketId) else { continue }
                if row.isReady {
                    states[marketId] = .ready
                    return
                }
                // The row exists now, so the backend has taken the request.
                if states[marketId] == .requested { states[marketId] = .syncing }
            }
            if !Task.isCancelled { states[marketId] = .failed(.timedOut) }
        }
    }

    /// Awaits an in-flight poll task; used by tests to run the machine out.
    func waitForPolling(_ marketId: String) async {
        await pollTasks[marketId]?.value
    }
}
