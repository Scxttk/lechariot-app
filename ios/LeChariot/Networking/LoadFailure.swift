import Foundation

/// Turns a thrown error into something a shopper can act on.
///
/// The screens used to print `error.localizedDescription` straight into a
/// `ContentUnavailableView`. For `URLError` that is at least a sentence, but
/// `SupabaseError` is a plain enum with no `LocalizedError` conformance, so a
/// failing server produced *"The operation couldn't be completed.
/// (LeChariot.SupabaseError error 2.)"* — English, and about nothing the user
/// can fix.
///
/// Every message here names the likely cause and, where the user can do
/// something, says what. Technical detail stays out: it belongs in the log, not
/// on the screen.
enum LoadFailure {
    /// True when the error is just a cancelled task — a view that disappeared,
    /// or a `.task(id:)` restarted with new inputs. Never an error state:
    /// showing "offline" because the user switched tabs would be a lie.
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    /// One sentence, German, no jargon. `subject` names what failed to load in
    /// the nominative ("Die Angebote", "Die Filialen").
    static func message(for error: Error, subject: String) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .dataNotAllowed:
                return "Keine Internetverbindung. \(subject) werden geladen, sobald du wieder online bist."
            case .networkConnectionLost, .timedOut:
                return "Die Verbindung ist abgebrochen. Versuch es gleich noch einmal."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "Der Server ist gerade nicht erreichbar. Das liegt nicht an dir — versuch es später noch einmal."
            default:
                break
            }
        }
        if case SupabaseError.httpError(let status, _) = error, (500..<600).contains(status) {
            return "Auf dem Server ist etwas schiefgegangen. Versuch es später noch einmal."
        }
        return "\(subject) konnten nicht geladen werden. Versuch es später noch einmal."
    }
}
