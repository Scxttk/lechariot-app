import Foundation

/// Ein Tagesbericht, wie Apple ihn liefert.
struct MetricsEntry: Codable, Identifiable, Equatable {
    /// Ende des Zeitraums, über den der Bericht geht.
    let bis: Date
    /// Was drinsteht — Apples eigenes JSON, unverändert.
    let json: Data
    /// `diagnostic` statt `metric`: Hänger und Abstürze kommen im zweiten
    /// Paket, und die beiden zu vermischen macht aus zwei Fragen eine.
    let art: Art

    enum Art: String, Codable {
        case messwerte
        case befunde
    }

    var id: String { "\(art.rawValue)-\(bis.timeIntervalSince1970)" }
}

/// **Wo die Tagesberichte liegen.**
///
/// MetricKit liefert einmal am Tag ein Paket und **hebt es nicht auf**: Wer es
/// nicht wegschreibt, hat es beim nächsten Start nicht mehr. Genau das ist der
/// Grund, warum das hier existiert — nicht die Anzeige.
///
/// Reines Dateiwerk, kein `UserDefaults`: Ein Paket ist ein paar Kilobyte JSON,
/// und `UserDefaults` wird bei jedem Start ganz gelesen.
///
/// **Kein Netz.** Die Berichte bleiben auf dem Gerät, bis jemand sie von Hand
/// teilt. Sie nennen Startzeiten, Speicher und Akku dieses einen Geräts — das
/// ist nichts, was unser Server braucht.
struct MetricsArchive {
    /// Mehr als das hebt niemand auf, und Apple liefert einen Bericht am Tag:
    /// dreißig Tage sind der Zeitraum, über den man eine Verschlechterung
    /// überhaupt sehen kann.
    static let limit = 60

    let url: URL

    init(url: URL? = nil) {
        self.url = url ?? Self.defaultURL
    }

    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("metrics.json")
    }

    func load() -> [MetricsEntry] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([MetricsEntry].self, from: data) else { return [] }
        return entries
    }

    /// Neue Berichte dazu, neueste zuerst, ohne Dubletten.
    ///
    /// **Dublette heißt gleiche `id`** — Apple liefert nach einem Neustart
    /// gern dasselbe Paket noch einmal, und zwei gleiche Tage nebeneinander
    /// lesen sich wie zwei Tage.
    @discardableResult
    func append(_ new: [MetricsEntry]) -> [MetricsEntry] {
        let merged = Self.merge(existing: load(), new: new)
        save(merged)
        return merged
    }

    static func merge(existing: [MetricsEntry], new: [MetricsEntry]) -> [MetricsEntry] {
        var seen = Set(existing.map(\.id))
        let fresh = new.filter { seen.insert($0.id).inserted }
        return Array((fresh + existing).sorted { $0.bis > $1.bis }.prefix(limit))
    }

    func save(_ entries: [MetricsEntry]) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }

    /// Was beim Teilen herauskommt: ein JSON-Array aus Apples eigenen Paketen.
    ///
    /// Apples JSON wird **nicht** neu verpackt — wer es in ein eigenes Format
    /// gießt, verliert genau die Felder, die Apple nächstes Jahr dazulegt.
    static func export(_ entries: [MetricsEntry]) -> Data {
        var out = Data("[\n".utf8)
        for (index, entry) in entries.enumerated() {
            out.append(entry.json)
            if index < entries.count - 1 { out.append(Data(",\n".utf8)) }
        }
        out.append(Data("\n]\n".utf8))
        return out
    }
}
