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
    /// The anchors whose area runs we are waiting for, each mapped to the
    /// region the picker was searching around when it asked. In defaults, not
    /// in memory: the run outlives the app session, and the whole point is that
    /// the user hears about it when they come back.
    ///
    /// **Several at once, and that is the fix.** This used to be a single
    /// anchor, which quietly made the second region unfetchable forever: with
    /// one request open, every further one was dropped — and a user with two
    /// regions never got past the first. The backend's cooldown sits on the
    /// *postcode* (migration v19), so two anchors in two areas are exactly the
    /// case it was built for, and two in the same area are deduped there.
    ///
    /// The postcode in the value is **local display context only** — it says
    /// which of the user's own regions this run belongs to, so the hint can
    /// name it. It is never sent; the backend looks the area up from the anchor
    /// itself, for the reason `AreaRequest` spells out.
    private static let pendingKey = "areaRequest.pendingAreas"
    /// The single anchor of the versions before that. Read once at startup and
    /// folded in — see `adoptLegacyPendingAnchor`.
    private static let legacyPendingKey = "areaRequest.pendingAnchor"
    /// Anchors whose completion has already been announced — otherwise the
    /// notice would return on every single launch.
    private static let announcedKey = "areaRequest.announcedAnchors"

    private let repository: AreaRequestRepositoryProtocol
    private let defaults: UserDefaults

    /// True while at least one area directory is being fetched. Drives the
    /// quiet hint in the picker, nothing blocking.
    private(set) var isFetchingArea = false
    /// Set once a pending area has finished. Drives the notice in the list.
    private(set) var areaJustCompleted = false
    /// The postcodes of the areas that just finished, for the notice. Empty
    /// when the run came from a version that did not record one.
    private(set) var completedAreaPLZs: [String] = []

    init(
        repository: AreaRequestRepositoryProtocol,
        defaults: UserDefaults = AppDefaults.shared
    ) {
        self.repository = repository
        self.defaults = defaults
        adoptLegacyPendingAnchor()
        isFetchingArea = !pendingAreas.isEmpty
    }

    /// Carries an in-flight request from before this store could hold more than
    /// one across the update. Without it the user who is mid-run when the
    /// update lands loses the notice for good — the silent failure this whole
    /// store exists to prevent.
    private func adoptLegacyPendingAnchor() {
        guard let legacy = defaults.string(forKey: Self.legacyPendingKey) else { return }
        if pendingAreas[legacy] == nil {
            // No postcode to go with it; the notice falls back to its generic
            // wording rather than inventing one.
            pendingAreas[legacy] = ""
        }
        defaults.removeObject(forKey: Self.legacyPendingKey)
    }

    private var pendingAreas: [String: String] {
        get { defaults.dictionary(forKey: Self.pendingKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Self.pendingKey) }
    }

    /// The postcodes still being fetched, so the picker can name them.
    var pendingAreaPLZs: [String] {
        Array(Set(pendingAreas.values.filter { !$0.isEmpty })).sorted()
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
    ///
    /// Ask it **per region**, never over several merged: one region that has
    /// been fetched answers for all of them, and the others then never get a
    /// request at all. `PickerDirectory` is where that split lives.
    ///
    /// `nonisolated` because it is a pure test over an array, and
    /// `PickerDirectory` asks it while building its plan, off the main actor.
    nonisolated static func areaLooksUnfetched(_ branches: [Branch]) -> Bool {
        !branches.isEmpty && branches.allSatisfy { nationwideChains.contains($0.chain) }
    }

    /// Zwei Anforderungen gelten als dasselbe Gebiet, wenn ihre Mittelpunkte
    /// näher als eine Rasterzelle beieinander liegen.
    ///
    /// 13,5 km ist die Diagonale der 0,1°-Zelle, auf die der Cooldown der
    /// Migration v21 schlüsselt — dieselbe Zahl, damit App und Server nicht
    /// verschiedener Meinung darüber sind, was ein Gebiet ist.
    static let sameAreaKm = 13.5

    /// Asks for the directory around one of `anchors`, unless *this* area is
    /// already on its way. `region` is the postcode the picker was searching
    /// around, kept only so the hint can name it; `lat`/`lon` are the region
    /// centre and the only thing the server derives the area from (v21).
    ///
    /// Reads before writing, for the same reason as `BranchRequestStore`: the
    /// trigger holds a 30-minute cooldown per area, so a second insert does
    /// nothing at all — silently. Reading first turns "nothing happened" into
    /// "it is already running".
    ///
    /// **Mehrere Anker, und das ist kein Luxus.** `market_id` ist der
    /// Primärschlüssel von `area_requests`, und zwei Orte können denselben
    /// nächsten Anker haben — Penny Am Haff ist die nächste Filiale sowohl für
    /// Ueckermünde als auch für Ahlbeck, genau die Geografie des gemeldeten
    /// Falls. Trägt die vorhandene Zeile Koordinaten aus einer anderen Gegend,
    /// wäre ihre Übernahme das Warten auf einen Lauf für eine fremde Stadt.
    /// Dann lieber den nächsten Anker.
    func requestArea(
        anchors: [String],
        region: String = "",
        lat: Double? = nil,
        lon: Double? = nil
    ) async {
        for anchor in anchors {
            guard pendingAreas[anchor] == nil, !announced.contains(anchor) else { return }

            do {
                if let existing = try await repository.request(marketId: anchor) {
                    if existing.isReady {
                        // Already fetched before we ever asked — nothing to wait
                        // for and nothing to announce.
                        return
                    }
                    if isForAnotherArea(existing, lat: lat, lon: lon) {
                        continue
                    }
                } else {
                    try await repository.requestArea(marketId: anchor, lat: lat, lon: lon)
                }
                pendingAreas[anchor] = region
                isFetchingArea = true
                return
            } catch {
                // A failed request costs the extra chains, not the app. The user
                // still sees Kaufland and Penny, and the Sunday run catches up.
                isFetchingArea = !pendingAreas.isEmpty
                return
            }
        }
    }

    /// Gehört eine vorhandene Zeile erkennbar zu einem anderen Ort?
    ///
    /// Nur wenn beide Seiten Koordinaten haben. Ohne sie ist die alte Annahme
    /// die einzige, die es gibt — „derselbe Anker heißt dasselbe Gebiet" —, und
    /// sie ist meistens richtig.
    private func isForAnotherArea(_ row: AreaRequest, lat: Double?, lon: Double?) -> Bool {
        guard let lat, let lon, let rowLat = row.lat, let rowLon = row.lon else { return false }
        return Geo.distanceKm(from: (lat, lon), to: (rowLat, rowLon)) > Self.sameAreaKm
    }

    /// Checks whether the areas we were waiting for have arrived. Call on
    /// launch and when the app comes back to the foreground.
    func checkPendingArea() async {
        let open = pendingAreas
        guard !open.isEmpty else { return }

        var stillOpen = open
        var finishedPLZs: [String] = []
        var seen = announced

        for (anchor, region) in open {
            // No row yet is not "finished" — leave it open and look again next
            // time rather than dropping the request on a hiccup.
            guard let row = try? await repository.request(marketId: anchor) else { continue }
            guard row.isReady else { continue }
            stillOpen[anchor] = nil
            seen.insert(anchor)
            // The backend derived the area from the anchor itself, so its
            // postcode is the better one; ours is the fallback.
            if let plz = row.plz ?? (region.isEmpty ? nil : region) {
                finishedPLZs.append(plz)
            }
        }

        guard stillOpen.count != open.count else {
            isFetchingArea = true
            return
        }

        pendingAreas = stillOpen
        announced = seen
        isFetchingArea = !stillOpen.isEmpty
        completedAreaPLZs = Array(Set(finishedPLZs)).sorted()
        areaJustCompleted = true
    }

    /// The user has seen the notice.
    func dismissCompletionNotice() {
        areaJustCompleted = false
        completedAreaPLZs = []
    }

    /// Wipes both keys. Without this the `announced` set survives a debug
    /// reset, and a fresh onboarding in the same area would never ask again —
    /// which makes the multi-region fix impossible to demonstrate on device.
    func resetAllData() {
        defaults.removeObject(forKey: Self.pendingKey)
        defaults.removeObject(forKey: Self.legacyPendingKey)
        defaults.removeObject(forKey: Self.announcedKey)
        isFetchingArea = false
        areaJustCompleted = false
        completedAreaPLZs = []
    }

    #if DEBUG
    /// Only for UI journeys: leave behind what an earlier launch would have —
    /// an open request for this anchor. Whether it has finished is decided by
    /// the repository, so the same seam drives both the waiting hint and the
    /// completion notice.
    /// `nonisolated`, weil hier nur in die Defaults geschrieben wird und der
    /// Aufruf aus `AppRepositories` kommt — das läuft vor dem ersten Store.
    nonisolated static func seedPendingArea(
        _ anchor: String, region: String = "", in defaults: UserDefaults
    ) {
        defaults.set([anchor: region], forKey: pendingKey)
    }
    #endif
}
