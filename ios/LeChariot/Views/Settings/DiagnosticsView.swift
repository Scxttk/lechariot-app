import SwiftUI

/// **Der Bildschirm hinter der Geste.**
///
/// Zwei Dinge, die sich ergänzen (Backlog, 02.08.): oben der Schalter für die
/// Live-Anzeige, darunter Apples Tagesberichte. Die Berichte sind das
/// Belastbare — sie kommen vom echten Gerät bei echter Temperatur —, die
/// Live-Anzeige ist das Sofortige.
struct DiagnosticsView: View {
    @Environment(DiagnosticsGate.self) private var gate
    @Environment(\.dismiss) private var dismiss
    @Environment(MetricsCollector.self) private var metrics
    private var images: OfferImageLoader { .shared }

    var body: some View {
        @Bindable var gate = gate
        List {
            Section {
                Toggle("Live-Anzeige", isOn: $gate.isHUDVisible)
                    .tint(Theme.accent)
                    .accessibilityIdentifier("diagnostics.hud")
            } header: {
                Text("Über der App")
            } footer: {
                Text("Bilder je Sekunde, Ruckelzeit, Temperatur und Speicher, oben rechts. Ausgeschaltet läuft sie nicht — sie wird gar nicht erst gebaut.")
            }

            Section {
                if metrics.entries.isEmpty {
                    Text("Noch kein Bericht. Apple liefert einen pro Tag, frühestens nach 24 Stunden Laufzeit.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .accessibilityIdentifier("diagnostics.empty")
                } else {
                    ForEach(metrics.entries) { entry in
                        LabeledContent(Self.dateFormatter.string(from: entry.bis)) {
                            Text(entry.art == .messwerte ? "Messwerte" : "Befunde")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
            } header: {
                Text("Tagesberichte (\(metrics.entries.count))")
            } footer: {
                Text("Hitch-Rate, Hänger, Startzeit, CPU und Akku — von diesem Gerät. Sie bleiben hier, bis du sie teilst; hochgeladen wird nichts.")
            }

            // **Was der Bildercache wirklich tut** — Scotts Punkt 4 vom 03.08.
            // („manche Bilder sofort da, manche verzögert"). „Fühlt sich
            // schneller an" ist genau die Sorte Aussage, die diese Runde nicht
            // mehr durchgehen lässt; hier stehen die drei Zahlen, aus denen
            // sich das ableiten lässt.
            Section {
                LabeledContent("Aus dem Speicher", value: "\(images.memoryHits)")
                    .accessibilityIdentifier("diagnostics.img.memory")
                LabeledContent("Von der Platte", value: "\(images.diskHits)")
                    .accessibilityIdentifier("diagnostics.img.disk")
                LabeledContent("Aus dem Netz", value: "\(images.networkLoads)")
                    .accessibilityIdentifier("diagnostics.img.network")
                LabeledContent("Fehlgeschlagen", value: "\(images.failures)")
                    .accessibilityIdentifier("diagnostics.img.failed")
            } header: {
                Text("Produktbilder")
            } footer: {
                Text("Die Bilder liegen bei sechs fremden CDNs, nicht bei uns — am 03.08. gemessen zwischen 266 und 2 751 ms je Bild. „Von der Platte“ heißt: über App-Starts hinweg behalten, auch wenn der Server das nicht erlaubt hätte.")
            }

            Section {
                ShareLink(
                    item: MetricsExport(data: MetricsArchive.export(metrics.entries)),
                    preview: SharePreview("Le Chariot – Messwerte")
                ) {
                    Label("Berichte teilen", systemImage: "square.and.arrow.up")
                }
                .disabled(metrics.entries.isEmpty)
                .accessibilityIdentifier("diagnostics.share")

                #if DEBUG
                Button("Jetzt nachsehen") { metrics.fetchNow() }
                    .accessibilityIdentifier("diagnostics.fetch")
                #endif

                Button("Berichte löschen", role: .destructive) { metrics.clear() }
                    .disabled(metrics.entries.isEmpty)

                // Und zurück: Ohne das bliebe man auf einem Bildschirm
                // stehen, dessen Eingang gerade verschwunden ist.
                Button("Diagnose verstecken", role: .destructive) {
                    gate.hide()
                    dismiss()
                }
                    .accessibilityIdentifier("diagnostics.hide")
            } footer: {
                Text("Verstecken blendet den Eintrag wieder aus. Zurück kommt er mit langem Druck auf die Zeile „Version“.")
            }
        }
        .navigationTitle("Diagnose")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("diagnostics.screen")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

/// `ShareLink` braucht etwas Übertragbares; die rohen Bytes genügen ihm nicht.
private struct MetricsExport: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName("lechariot-messwerte.json")
    }
}
