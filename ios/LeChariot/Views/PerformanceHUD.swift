import SwiftUI

/// **Die Live-Anzeige: Bilder, Ruckelzeit, Temperatur, Speicher.**
///
/// Der sichtbare Teil des Werkzeugs vom 02.08. — und deshalb der geschaltete.
/// Sie hängt an einem `CADisplayLink`, der **nur läuft, solange die Anzeige zu
/// sehen ist**: `PerformanceHUDOverlay` baut sie gar nicht erst, wenn der
/// Schalter aus ist. Kein Zeitgeber, kein Beobachter, kein Bild im Baum.
///
/// Sie misst, was ihr eigenes Bildwerk mitmacht — also die App, nicht sich
/// selbst allein: Der `CADisplayLink` schlägt im selben Takt an wie jede andere
/// Zeichnung, und ein Bild, das wegen einer teuren Liste zu spät kommt, kommt
/// auch hier zu spät.
@MainActor
@Observable
final class HUDReadings {
    var fps: Double?
    var hitchMsPerSecond: Double?
    var thermal: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    /// Fußabdruck in MB — dieselbe Zahl, die Xcode „Memory" nennt.
    var footprintMB: Double?

    private var meter = HitchMeter()
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    /// Der Speicher wird nicht bei jedem Bild geholt; `task_info` ist ein
    /// Systemaufruf und hätte im 120-Hz-Takt genau die Kosten, die diese
    /// Anzeige aufdecken soll.
    private var framesSinceMemoryRead = 0

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: DisplayLinkProxy { [weak self] in self?.tick($0) },
                                 selector: #selector(DisplayLinkProxy.fire(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        lastTimestamp = nil
        meter = HitchMeter()
        fps = nil
        hitchMsPerSecond = nil
        footprintMB = nil
    }

    private func tick(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard let last = lastTimestamp else { return }

        let duration = link.timestamp - last
        // Was das Gerät gerade zulässt — bei ProMotion ändert sich das im
        // Betrieb. Eine feste 1/60 wäre auf einem 120-Hz-Schirm ein
        // Dauerruckler, der keiner ist.
        let expected = link.targetTimestamp - link.timestamp
        meter.record(duration: duration, expected: max(expected, 1.0 / 120.0))

        fps = meter.fps
        hitchMsPerSecond = meter.hitchMillisecondsPerSecond

        framesSinceMemoryRead += 1
        if framesSinceMemoryRead >= 30 {
            framesSinceMemoryRead = 0
            thermal = ProcessInfo.processInfo.thermalState
            footprintMB = Self.footprintMB()
        }
    }

    /// `phys_footprint` — das ist die Zahl, auf die iOS beim Abschießen sieht,
    /// nicht `resident_size`.
    private static func footprintMB() -> Double? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Double(info.phys_footprint) / 1_048_576
    }
}

/// `CADisplayLink` will ein Objective-C-Ziel; ein Swift-Abschluss allein
/// genügt ihm nicht.
private final class DisplayLinkProxy: NSObject {
    private let handler: (CADisplayLink) -> Void
    init(handler: @escaping (CADisplayLink) -> Void) { self.handler = handler }
    @objc func fire(_ link: CADisplayLink) { handler(link) }
}

/// Die Anzeige selbst — klein, oben rechts, durchlässig für Berührungen.
struct PerformanceHUD: View {
    @State private var readings = HUDReadings()

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            row(readings.fps.map { String(format: "%.0f fps", $0) } ?? "– fps",
                warn: (readings.fps ?? 120) < 50)
            row(readings.hitchMsPerSecond.map { String(format: "%.1f ms/s", $0) } ?? "– ms/s",
                warn: (readings.hitchMsPerSecond ?? 0) > HitchMeter.noticeableHitchMsPerSecond)
            row(thermalLabel, warn: readings.thermal != .nominal)
            row(readings.footprintMB.map { String(format: "%.0f MB", $0) } ?? "– MB",
                warn: (readings.footprintMB ?? 0) > 400)
        }
        .font(.caption2.monospacedDigit().weight(.medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        // **Nicht anfassbar.** Eine Anzeige, die Tipps abfängt, macht aus einem
        // Messwerkzeug einen Fehler.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { readings.start() }
        .onDisappear { readings.stop() }
    }

    private func row(_ text: String, warn: Bool) -> some View {
        Text(text).foregroundStyle(warn ? Color.orange : Color.green)
    }

    private var thermalLabel: String {
        switch readings.thermal {
        case .nominal: "kühl"
        case .fair: "warm"
        case .serious: "heiß"
        case .critical: "kritisch"
        @unknown default: "?"
        }
    }
}

/// Hängt die Anzeige über die App — **und baut sie nur, wenn sie an ist.**
///
/// Das `if` ist der ganze Punkt: Ausgeschaltet gibt es kein `PerformanceHUD`,
/// also auch keinen `CADisplayLink`. „Versteckt" wäre nicht dasselbe wie „nicht
/// da"; ein unsichtbares Bild kostet trotzdem jeden Takt.
struct PerformanceHUDOverlay: ViewModifier {
    @Environment(DiagnosticsGate.self) private var gate

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if gate.isHUDVisible {
                PerformanceHUD()
                    .padding(.top, 4)
                    .padding(.trailing, 6)
            }
        }
    }
}

extension View {
    func performanceHUD() -> some View { modifier(PerformanceHUDOverlay()) }
}
