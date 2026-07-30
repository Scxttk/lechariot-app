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
///
/// **Seit 2026-07-30 lebt dieser Store auf App-Ebene und überlebt Neustarts.**
/// Vorher war er ein `@State` im Onboarding und starb mit ihm — mit zwei
/// Folgen, die beide beim ersten Tester außerhalb des Hauses aufgeschlagen
/// sind. Erstens hat der Weg über **Einstellungen → Filialen** gar keine
/// Anforderung ausgelöst (`EditMarketsScreen` reichte den Store nicht durch,
/// und der Parameter war optional), für eine so gewählte Filiale wurden also
/// **nie** Angebote geholt — nicht 40 Sekunden lang keine, sondern nie.
/// Zweitens wusste nach dem Onboarding niemand mehr, ob eine leere Filiale
/// gerade geholt wird oder dauerhaft nichts veröffentlicht; beides sah gleich
/// aus, nämlich nach „keine Angebote".
@MainActor
@Observable
final class BranchRequestStore {
    private let repository: BranchRequestRepositoryProtocol
    private let pollInterval: Duration
    private let maxPollAttempts: Int
    private let defaults: UserDefaults

    private(set) var states: [String: BranchSyncState] = [:]
    private var pollTasks: [String: Task<Void, Never>] = [:]

    private static let statesKey = "branchRequest.states"

    init(
        repository: BranchRequestRepositoryProtocol,
        pollInterval: Duration = .seconds(10),
        maxPollAttempts: Int = 30,
        defaults: UserDefaults = AppDefaults.shared
    ) {
        self.repository = repository
        self.pollInterval = pollInterval
        self.maxPollAttempts = maxPollAttempts
        self.defaults = defaults
        self.states = Self.load(from: defaults)
    }

    func state(for marketId: String) -> BranchSyncState {
        states[marketId] ?? .unknown
    }

    /// True when this store needs no waiting screen at all.
    func isReady(_ marketId: String) -> Bool {
        state(for: marketId) == .ready
    }

    // MARK: Persistenz

    /// Nur die beiden Zustände, die einen Neustart überhaupt überdauern können.
    /// `failed` wird bewusst nicht gespeichert: Ein Netzfehler von gestern darf
    /// morgen keine Fehlermeldung mehr sein, und der nächste Start fragt ohnehin
    /// nach.
    private static func load(from defaults: UserDefaults) -> [String: BranchSyncState] {
        let stored = defaults.dictionary(forKey: statesKey) as? [String: String] ?? [:]
        return stored.compactMapValues { raw in
            switch raw {
            case "ready": return .ready
            // Offen heißt beim nächsten Start: nachfragen. `syncing` und nicht
            // `requested`, weil die Zeile in der Datenbank steht — der Insert
            // ist längst durch.
            case "pending": return .syncing
            default: return nil
            }
        }
    }

    private func persist() {
        let stored: [String: String] = states.compactMapValues { state in
            switch state {
            case .ready: return "ready"
            case .requested, .syncing: return "pending"
            case .unknown, .failed: return nil
            }
        }
        defaults.set(stored, forKey: Self.statesKey)
    }

    /// Fragt für jede gewählte Filiale nach, was aus ihr geworden ist — beim
    /// Start und nach jeder Rückkehr in die App.
    ///
    /// Das ist zugleich die Selbstheilung für den Einstellungs-Fehler oben:
    /// Filialen, die ein Tester vor diesem Build über die Einstellungen gewählt
    /// hat, stehen auf `unknown`, und `request` legt für sie jetzt die fehlende
    /// Zeile an. Ohne das bliebe ihre Angebotsliste für immer leer.
    func checkPendingBranches(for marketIds: [String]) async {
        for marketId in marketIds where state(for: marketId) != .ready {
            await request(marketId)
        }
    }

    func resetAllData() {
        for task in pollTasks.values { task.cancel() }
        pollTasks = [:]
        states = [:]
        defaults.removeObject(forKey: Self.statesKey)
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
                    setState(.ready, for: marketId)
                } else {
                    setState(.syncing, for: marketId)
                    startPolling(marketId)
                }
            } else {
                try await repository.requestBranch(marketId: marketId)
                setState(.requested, for: marketId)
                startPolling(marketId)
            }
        } catch {
            setState(.failed(.network), for: marketId)
        }
    }

    /// Einzige Schreibstelle für `states` — sonst wird das Speichern irgendwo
    /// vergessen, und der Zustand nach einem Neustart wäre eine andere Wahrheit
    /// als der davor.
    private func setState(_ state: BranchSyncState, for marketId: String) {
        states[marketId] = state
        persist()
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
                    setState(.ready, for: marketId)
                    return
                }
                // The row exists now, so the backend has taken the request.
                if states[marketId] == .requested { setState(.syncing, for: marketId) }
            }
            if !Task.isCancelled { setState(.failed(.timedOut), for: marketId) }
        }
    }

    /// Awaits an in-flight poll task; used by tests to run the machine out.
    func waitForPolling(_ marketId: String) async {
        await pollTasks[marketId]?.value
    }
}
