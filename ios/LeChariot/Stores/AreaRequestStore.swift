import Foundation
import Observation

/// Chains whose complete German directory costs a single request, so they are
/// always in `branches` — everywhere, for everyone.
///
/// They are also the reason the gap is easy to miss: a picker that shows a
/// Penny and two Kauflands looks like it worked. It didn't; those two are
/// simply always there. If nothing *else* is within reach, this area has never
/// been fetched.
private let nationwideChains: Set<String> = ["Kaufland", "Penny"]

/// Drives "nobody has ever fetched the shops around here".
///
/// One level above `BranchRequestStore`: that one asks for a store's offers
/// (~40 s), this one for the directory of a whole area (~3 min, measured
/// 2026-07-26 in Gößnitz). Because of that duration the flow is deliberately
/// **not** a waiting screen. Three minutes of blocked onboarding is worse than
/// a short list that grows — so the request goes out silently and the user is
/// told when it lands, including on a later launch.
@MainActor
@Observable
final class AreaRequestStore {
    /// The anchor whose area run we are waiting for. In defaults, not in
    /// memory: the run outlives the app session, and the whole point is that
    /// the user hears about it when they come back.
    private static let pendingKey = "areaRequest.pendingAnchor"
    /// Anchors whose completion has already been announced — otherwise the
    /// notice would return on every single launch.
    private static let announcedKey = "areaRequest.announcedAnchors"

    private let repository: AreaRequestRepositoryProtocol
    private let defaults: UserDefaults

    /// True while the area directory is being fetched. Drives the quiet hint
    /// in the picker, nothing blocking.
    private(set) var isFetchingArea = false
    /// Set once a pending area has finished. Drives the notice in the list.
    private(set) var areaJustCompleted = false

    init(
        repository: AreaRequestRepositoryProtocol,
        defaults: UserDefaults = AppDefaults.shared
    ) {
        self.repository = repository
        self.defaults = defaults
        isFetchingArea = pendingAnchor != nil
    }

    private var pendingAnchor: String? {
        get { defaults.string(forKey: Self.pendingKey) }
        set { defaults.set(newValue, forKey: Self.pendingKey) }
    }

    private var announced: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.announcedKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: Self.announcedKey) }
    }

    /// True when the stores in reach are only the two nationwide chains — the
    /// signal that this area's directory was never fetched.
    ///
    /// An empty list is deliberately *not* that signal: it means the search
    /// found nothing at all (no coordinates, no network), and requesting an
    /// area needs an anchor anyway.
    static func areaLooksUnfetched(_ branches: [Branch]) -> Bool {
        !branches.isEmpty && branches.allSatisfy { nationwideChains.contains($0.chain) }
    }

    /// Asks for the directory around `anchor`, unless something is already on
    /// its way.
    ///
    /// Reads before writing, for the same reason as `BranchRequestStore`: the
    /// trigger holds a 30-minute cooldown per area, so a second insert does
    /// nothing at all — silently. Reading first turns "nothing happened" into
    /// "it is already running".
    func requestArea(anchor: String) async {
        guard pendingAnchor == nil else { return }
        guard !announced.contains(anchor) else { return }

        do {
            if let existing = try await repository.request(marketId: anchor) {
                if existing.isReady {
                    // Already fetched before we ever asked — nothing to wait
                    // for and nothing to announce.
                    return
                }
            } else {
                try await repository.requestArea(marketId: anchor)
            }
            pendingAnchor = anchor
            isFetchingArea = true
        } catch {
            // A failed request costs the extra chains, not the app. The user
            // still sees Kaufland and Penny, and the Sunday run catches up.
            isFetchingArea = false
        }
    }

    /// Checks whether the area we were waiting for has arrived. Call on launch
    /// and when the app comes back to the foreground.
    func checkPendingArea() async {
        guard let anchor = pendingAnchor else { return }
        guard let row = try? await repository.request(marketId: anchor) else { return }
        guard row.isReady else {
            isFetchingArea = true
            return
        }
        pendingAnchor = nil
        isFetchingArea = false
        var seen = announced
        seen.insert(anchor)
        announced = seen
        areaJustCompleted = true
    }

    /// The user has seen the notice.
    func dismissCompletionNotice() {
        areaJustCompleted = false
    }

    #if DEBUG
    /// Only for UI journeys: leave behind what an earlier launch would have —
    /// an open request for this anchor. Whether it has finished is decided by
    /// the repository, so the same seam drives both the waiting hint and the
    /// completion notice.
    /// `nonisolated`, weil hier nur in die Defaults geschrieben wird und der
    /// Aufruf aus `AppRepositories` kommt — das läuft vor dem ersten Store.
    nonisolated static func seedPendingArea(_ anchor: String, in defaults: UserDefaults) {
        defaults.set(anchor, forKey: pendingKey)
    }
    #endif
}
