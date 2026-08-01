import Foundation
import Observation

/// **Auskunft und Löschung, vom Gerät ausgelöst** ([UI-4], 2026-08-01).
///
/// Die Datenschutzerklärung verspricht beides über die Installations-ID. Seit
/// dem 2026-07-31 steht die ID in der App; auslösen ließ sich damit nichts —
/// nur abschreiben und eine Mail schicken. Das ist die zweite Hälfte.
///
/// Der Export hat **zwei Quellen und nennt beide**: was auf dem Gerät liegt
/// (Liste, Filialen, Antworten — das meiste, und es hat den Server nie
/// gesehen) und was hochgeladen wurde. Ein Export, der nur die Serverzeilen
/// zeigt, sähe beruhigend leer aus und wäre eine Halbwahrheit.
@MainActor
@Observable
final class PrivacyStore {
    enum State: Equatable {
        case idle
        case working
        /// Ergebnis in einem Satz, den der Bildschirm zeigen darf.
        case done(String)
        case failed(String)
    }

    private(set) var deletion: State = .idle
    private(set) var export: State = .idle
    /// Die fertige Datei, sobald ein Export gebaut wurde.
    private(set) var exportFile: URL?

    private let repository: PrivacyRepositoryProtocol?

    init(repository: PrivacyRepositoryProtocol? = AppRepositories.privacy()) {
        self.repository = repository
    }

    /// Ob überhaupt etwas hochgeladen sein kann. Ohne Rückweg zum Server gibt
    /// es nichts zu löschen — dann steht das da statt eines toten Knopfes.
    var canReachServer: Bool { repository != nil }

    // MARK: Löschen

    func deleteUploadedData(installId: UUID) async {
        guard let repository else {
            deletion = .done("Diese Installation hat nie etwas hochgeladen.")
            return
        }
        deletion = .working
        do {
            let rows = try await repository.deleteInstallation(installId)
            deletion = .done(rows.summary)
        } catch let SupabaseError.functionMissing(name) {
            deletion = .failed(
                "Der Server kennt „\(name)“ noch nicht. Schick deine Installations-ID an nuke_scott@web.de, dann wird von Hand gelöscht."
            )
        } catch {
            deletion = .failed(LoadFailure.message(for: error, subject: "Das Löschen"))
        }
    }

    // MARK: Exportieren

    /// Baut die Exportdatei aus dem Gerät und, wenn erreichbar, dem Server.
    ///
    /// Der Serverteil darf fehlschlagen, ohne den ganzen Export zu versenken:
    /// Was auf dem Gerät liegt, ist der größere Teil, und ein Export, der
    /// wegen eines Funklochs gar nichts liefert, hilft niemandem.
    func buildExport(local: LocalDataExport) async {
        export = .working
        var serverJSON: String?
        var serverNote: String?
        if let repository {
            do {
                serverJSON = try await repository.exportInstallation(local.installId)
            } catch let SupabaseError.functionMissing(name) {
                serverNote = "Der Server kennt „\(name)“ noch nicht — der hochgeladene Teil fehlt in dieser Datei."
            } catch {
                serverNote = LoadFailure.message(for: error, subject: "Die Serverdaten")
            }
        } else {
            serverNote = "Diese Installation hat nie etwas hochgeladen."
        }

        do {
            let url = try DataExportFile.write(
                local: local, serverJSON: serverJSON, serverNote: serverNote
            )
            exportFile = url
            export = .done(serverNote ?? "Deine Daten liegen als Datei bereit.")
        } catch {
            export = .failed("Die Datei konnte nicht geschrieben werden.")
        }
    }

    func clearExport() {
        exportFile = nil
        export = .idle
    }
}
