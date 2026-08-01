import Foundation

protocol OfferRepositoryProtocol {
    /// ALL offers of the given branches, newest validity first — never
    /// narrowed to chains: the cache must hold the complete tagged set per
    /// region (KW-Cache), display filtering happens in memory (OfferStore).
    func offers(branchIds: [String]) async throws -> [Offer]
}

protocol PriceHistoryRepositoryProtocol {
    /// Recorded offer weeks for one product at one market,
    /// oldest first. An empty result is a normal answer, not an error — the
    /// table only started filling up recently.
    func history(market: String, product: String) async throws -> [PriceHistoryPoint]
}

protocol MarketRepositoryProtocol {
    /// Markets in the given PLZ regions, sorted by chain then branch name.
    func markets(plzs: [String]) async throws -> [Market]
}

protocol BranchRepositoryProtocol {
    /// Stores within `radiusKm` of a point, nearest first. Rows without
    /// coordinates never appear here — they cannot be placed on a map and the
    /// query filters on a bounding box.
    func nearby(lat: Double, lon: Double, radiusKm: Double) async throws -> [Branch]
    /// One store by its id, or nil if the directory doesn't know it. Used when
    /// a stored favourite has to be shown again after a restart.
    func branch(marketId: String) async throws -> Branch?
}

protocol BranchRequestRepositoryProtocol {
    /// Request row for a store, or nil if nobody has asked for it yet.
    func request(marketId: String) async throws -> BranchRequest?
    /// Asks the backend to fetch this store's offers. Idempotent
    /// (409 = already requested, which is a success, not a problem).
    func requestBranch(marketId: String) async throws
}

protocol AreaRequestRepositoryProtocol {
    /// Request row for an area, keyed on the anchor store, or nil if nobody
    /// has asked for it yet.
    func request(marketId: String) async throws -> AreaRequest?
    /// Die Anforderung **dieses Gebiets**, unabhängig davon, an welcher
    /// Ankerfiliale sie hängt. Seit Migration v22 ist der Gebietsschlüssel die
    /// Identität einer Anforderung; über die Filiale zu fragen liefert bei
    /// zwei Orten mit demselben nächsten Anker eine beliebige der beiden.
    func request(areaKey: String) async throws -> AreaRequest?
    /// Asks the backend to fetch the whole directory around this store.
    /// Idempotent, same as `requestBranch`.
    ///
    /// `lat`/`lon` sind die Mitte der Region, um die gesucht wurde — daraus
    /// leitet der Server ab v21 die PLZ ab. Ohne sie fällt er auf die PLZ der
    /// Ankerfiliale zurück, und die kann in der Nachbarstadt liegen.
    func requestArea(marketId: String, lat: Double?, lon: Double?) async throws
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

/// Auskunft und Löschung zu einer Installation.
///
/// Beides geht über `security definer`-Funktionen, nicht über PostgREST:
/// Die Tabellen haben nur eine INSERT-Policy, ein anon-DELETE darauf schlägt
/// **nicht fehl**, sondern löscht nichts und meldet 204. Siehe
/// `supabase/migration_v25_dsgvo.sql`.
protocol PrivacyRepositoryProtocol {
    /// Löscht die hochgeladenen Zeilen. Gibt zurück, was tatsächlich
    /// verschwunden ist — nicht, was verschwinden sollte.
    func deleteInstallation(_ installId: UUID) async throws -> DeletedRows

    /// Was zu dieser Installation auf dem Server liegt, als JSON-Text.
    func exportInstallation(_ installId: UUID) async throws -> String
}

/// Was das Löschen wirklich getroffen hat.
struct DeletedRows: Codable, Equatable {
    let profiles: Int
    let feedback: Int

    var total: Int { profiles + feedback }

    /// Der Satz für den Bildschirm. Zählt auf, statt „erledigt" zu behaupten.
    var summary: String {
        guard total > 0 else { return "Auf dem Server lag nichts zu dieser Installations-ID." }
        var parts: [String] = []
        if profiles > 0 { parts.append(profiles == 1 ? "1 Profil" : "\(profiles) Profile") }
        if feedback > 0 {
            parts.append(feedback == 1 ? "1 Rückmeldung" : "\(feedback) Rückmeldungen")
        }
        return "Gelöscht: " + parts.joined(separator: " und ") + "."
    }
}
