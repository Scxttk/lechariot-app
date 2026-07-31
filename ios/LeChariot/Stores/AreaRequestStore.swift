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
    /// Gebietsschlüssel -> Ankerfiliale, für den Fall, dass der Server die
    /// Anforderung unter einem anderen Schlüssel führt als wir erwarten.
    private static let anchorsKey = "areaRequest.anchorsByArea"

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

    /// Zu welchem Anker gehört ein offenes Gebiet? Gebraucht wird das nur für
    /// den Rückfall unten in `checkPendingArea`.
    private var anchorsByArea: [String: String] {
        get { defaults.dictionary(forKey: Self.anchorsKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Self.anchorsKey) }
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

    /// Der Gebietsschlüssel einer Regionsmitte — **dieselbe Regel wie
    /// `area_key` in Migration v22 und `branches::area_cell` im Backend.**
    /// Drei Stellen, eine Zeichenkette; laufen sie auseinander, wartet die App
    /// auf einen Lauf, den es unter diesem Namen nicht gibt.
    ///
    /// 0,1° sind höchstens 13,5 km Diagonale — zwei Anforderungen in derselben
    /// Zelle liegen im 25-km-Kreis des ersten Laufs, der zweite Nutzer bekommt
    /// also kein Ergebnis weniger.
    /// `nonisolated`, weil es eine reine Rechnung ist — `PickerDirectory` und
    /// die Repositories fragen sie außerhalb des Main-Actors.
    nonisolated static func areaKey(lat: Double, lon: Double) -> String {
        let round1 = { (v: Double) in (v * 10).rounded() / 10 + 0.0 }
        return String(format: "cell:%.1f,%.1f", round1(lat), round1(lon))
    }

    /// Asks for the directory around `anchor`, unless *this area* is already on
    /// its way. `region` is the postcode the picker was searching around, kept
    /// only so the hint can name it; `lat`/`lon` are the region centre — the
    /// only thing the server derives the area from, and since v22 also the
    /// identity of the request.
    ///
    /// Reads before writing, for the same reason as `BranchRequestStore`: the
    /// trigger holds a 30-minute cooldown per area, so a second insert does
    /// nothing at all — silently. Reading first turns "nothing happened" into
    /// "it is already running".
    ///
    /// **Ein Anker genügt wieder.** Bis v21 war `market_id` der
    /// Primärschlüssel von `area_requests`, eine Filiale trug also höchstens
    /// eine Anforderung — und zwei Orte können denselben nächsten Anker haben
    /// (Penny Am Haff für Ueckermünde wie für Ahlbeck). Die App wich deshalb
    /// auf den zweitnächsten Anker aus. Seit v22 ist der Schlüssel das Gebiet,
    /// nicht die Filiale; der Ausweichweg ist damit unerreichbar geworden und
    /// hier entfernt, statt als nie durchlaufener Pfad liegen zu bleiben.
    func requestArea(anchor: String, region: String = "", lat: Double, lon: Double) async {
        let key = Self.areaKey(lat: lat, lon: lon)
        // Unser eigener offener Auftrag für dieses Gebiet, oder einer, den wir
        // schon gemeldet haben.
        if pendingAreas[key] != nil || announced.contains(key) { return }

        do {
            if let existing = try await repository.request(areaKey: key) {
                if existing.isReady {
                    // Schon geholt, bevor wir gefragt haben — nichts zu warten
                    // und nichts zu melden.
                    return
                }
                // Offen und für dieses Gebiet: übernehmen statt neu anfordern.
            } else {
                try await repository.requestArea(marketId: anchor, lat: lat, lon: lon)
            }
            pendingAreas[key] = region
            anchorsByArea[key] = anchor
            isFetchingArea = true
        } catch {
            // A failed request costs the extra chains, not the app. The user
            // still sees Kaufland and Penny, and the Sunday run catches up.
            isFetchingArea = !pendingAreas.isEmpty
        }
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
            // Neue Einträge tragen den Gebietsschlüssel, Einträge aus der Zeit
            // vor v22 die Ankerfiliale. Der Altweg bleibt genau eine Version
            // stehen, damit ein Tester, der beim Update mitten im Lauf steckt,
            // seine Meldung nicht verliert — er darf danach weg.
            var row: AreaRequest?
            if anchor.hasPrefix("cell:") || anchor.hasPrefix("plz:") {
                row = try? await repository.request(areaKey: anchor)
                // **Der Server führt sie unter einem anderen Schlüssel.** Wir
                // rechnen aus unserer Regionsmitte `cell:…`; verwirft der
                // BEFORE-Trigger die Koordinaten als unplausibel oder als zu
                // weit vom Anker, trägt die Zeile stattdessen `plz:…`. Ohne
                // diesen Rückfall suchten wir für immer einen Schlüssel, den es
                // nicht gibt — die Anforderung bliebe ewig „läuft noch", und
                // niemandem fiele es auf.
                if row == nil, let market = anchorsByArea[anchor] {
                    row = try? await repository.request(marketId: market)
                }
            } else {
                row = try? await repository.request(marketId: anchor)
            }
            guard let row else { continue }
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
        anchorsByArea = anchorsByArea.filter { stillOpen[$0.key] != nil }
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
        defaults.removeObject(forKey: Self.anchorsKey)
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
