import Foundation
import MetricKit
import Observation

/// **Apples Tageszahlen einsammeln — für alle, sichtbar für niemanden.**
///
/// Der unsichtbare Teil des Werkzeugs vom 02.08. Ein Tester merkt davon
/// nichts: kein Bildschirm, keine Frage, keine Anzeige. Und es kostet nichts —
/// MetricKit misst ohnehin, wir sagen nur einmal Bescheid, dass wir das
/// Ergebnis haben wollen. **Es gibt keine Schleife, keinen Zeitgeber und
/// keinen Abgriff**; Apple ruft einmal am Tag von sich aus an.
///
/// Was dabei herauskommt, ist genau das, was der Simulator nicht sehen kann:
/// Hitch-Rate beim Scrollen, Hänger, Startzeit, CPU-Zeit, Akku — **auf dem
/// echten Gerät, bei echter Temperatur und echtem Ladestand.**
///
/// **Die Pakete bleiben auf dem Gerät.** Hochgeladen wird nichts; sie gehen
/// erst weg, wenn jemand sie im Diagnose-Bildschirm von Hand teilt.
@MainActor
@Observable
final class MetricsCollector: NSObject, MXMetricManagerSubscriber {
    private let archive: MetricsArchive
    private(set) var entries: [MetricsEntry]

    init(archive: MetricsArchive = MetricsArchive()) {
        self.archive = archive
        self.entries = archive.load()
        super.init()
    }

    /// Einmal beim Start. Mehrfach anzumelden ist harmlos, aber sinnlos.
    func start() {
        MXMetricManager.shared.add(self)
    }

    // MARK: MXMetricManagerSubscriber

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        let neu = payloads.map {
            MetricsEntry(bis: $0.timeStampEnd, json: $0.jsonRepresentation(), art: .messwerte)
        }
        Task { @MainActor in absorb(neu) }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let neu = payloads.map {
            MetricsEntry(bis: $0.timeStampEnd, json: $0.jsonRepresentation(), art: .befunde)
        }
        Task { @MainActor in absorb(neu) }
    }

    private func absorb(_ neu: [MetricsEntry]) {
        entries = archive.append(neu)
    }

    /// **Nicht warten, bis der Tag um ist.** Im Debug-Bau gibt Apple die
    /// bisherigen Pakete auf Zuruf heraus — ohne das wäre jede Prüfung des
    /// Bildschirms eine Prüfung von 24 Stunden Geduld.
    func fetchNow() {
        #if DEBUG
        entries = archive.append(
            MXMetricManager.shared.pastPayloads.map {
                MetricsEntry(bis: $0.timeStampEnd, json: $0.jsonRepresentation(), art: .messwerte)
            }
                + MXMetricManager.shared.pastDiagnosticPayloads.map {
                    MetricsEntry(bis: $0.timeStampEnd, json: $0.jsonRepresentation(), art: .befunde)
                }
        )
        #endif
    }

    func clear() {
        archive.clear()
        entries = []
    }
}
