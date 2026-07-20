import Foundation
import Observation

/// Owns the follow-up question after a rejected match: whether it is asked at
/// all, and sending the answer.
///
/// Two things are deliberately kept in one place here. The setting ("ask me
/// about rejections") and the upload live together, so switching it off is
/// guaranteed to stop the network call too — with the flag in a view and the
/// call in a store, "off" would be a UI state that a future caller could route
/// around. Rejecting itself is unaffected either way; that stays in
/// `MatchRejectionStore` and works offline, instantly, forever.
///
/// There is no separate consent step for this. Sending is the user actively
/// tapping "Senden" on a sheet that names what goes along, and skipping sends
/// nothing — see `RejectionFeedbackSheet`.
@MainActor
@Observable
final class MatchFeedbackStore {
    /// Whether the app asks after a rejection. On by default: the question is
    /// the only way the dictionary learns about a bad match, and it is one tap
    /// to skip. Off means no sheet **and** no upload.
    var isAskingEnabled: Bool {
        didSet {
            guard isAskingEnabled != oldValue else { return }
            defaults.set(isAskingEnabled, forKey: Self.key)
        }
    }

    /// Last upload failure, for the rare case the sheet wants to say so.
    /// Failures are otherwise silent — a rejection must never depend on a
    /// working network.
    private(set) var lastUploadFailed = false

    private let repository: MatchFeedbackRepositoryProtocol?
    private let defaults: UserDefaults
    private static let key = "feedback.askOnReject"

    init(
        repository: MatchFeedbackRepositoryProtocol? = nil,
        defaults: UserDefaults = AppDefaults.shared
    ) {
        self.repository = repository
        self.defaults = defaults
        // `bool(forKey:)` returns false for a missing key, which would make the
        // default "off". Read the object to tell "never set" from "set to off".
        self.isAskingEnabled = defaults.object(forKey: Self.key) as? Bool ?? true
    }

    /// Sends one report. Silent no-op when the question is switched off or no
    /// repository is configured (mock runs, missing API key).
    func submit(_ report: MatchFeedbackReport) async {
        guard isAskingEnabled, let repository else { return }
        do {
            try await repository.submit(report)
            lastUploadFailed = false
        } catch {
            lastUploadFailed = true
        }
    }

    #if DEBUG
    /// See `DebugReset`. The key is removed *after* the reset assignment —
    /// the other way round `didSet` would write it straight back.
    func resetAllData() {
        isAskingEnabled = true
        lastUploadFailed = false
        defaults.removeObject(forKey: Self.key)
    }
    #endif
}
