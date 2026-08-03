import Foundation
import UIKit

/// **Warum Produktbilder mal sofort da waren und mal nicht.**
///
/// Scott, 03.08.: „manche Bilder sofort da, manche verzögert, manche
/// dazwischen." Die Antwort, die er dazu bekam, war falsch, und der Fund steckt
/// in der Korrektur: Die Bilder kommen **nicht** aus unserem Mirror. Am 03.08.
/// über 1 000 Zeilen mit Bild ausgezählt:
///
/// | Host | Anteil | Zeit | Cache-Control |
/// |---|---:|---:|---|
/// | `kaufland.media.schwarz` | 343 | 1 793 ms | **keins** |
/// | `cddubgdnasmzvcfhmrzj.supabase.co` (unser Mirror) | 231 | 266 ms | **`no-cache`** |
/// | `offer-images.api.edeka` | 190 | 682 ms | `max-age=43200` |
/// | `cdn.penny.de` | 158 | 2 751 ms | `max-age=81438` |
/// | `www.lidl.de` | 65 | 525 ms | `max-age=31556952` |
/// | `img.rewe-static.de` | 10 | 1 290 ms | `max-age=2382709` |
///
/// **Sieben Hosts, Faktor zehn zwischen dem schnellsten und dem langsamsten.**
/// Das ist „manche sofort, manche verzögert, manche dazwischen" — kein
/// Cache-Fehler, sondern sechs fremde CDNs. Zwei Sachen kann man trotzdem tun,
/// und beide tut dieser Typ:
///
/// 1. **Auf Platte behalten, auch wenn der Server es verbietet.** Unser eigener
///    Mirror schickt `no-cache`, Kaufland gar nichts — `URLCache` muss dann bei
///    **jedem** Bild neu anfragen, bei jedem Scrollen und nach jedem App-Start.
///    Die Adressen tragen eine UUID bzw. einen Hash; ein Bild unter derselben
///    Adresse ist dasselbe Bild. Die Antwort wird deshalb mit einer eigenen
///    Frist in den Cache geschrieben.
/// 2. **Fertig dekodiert im Speicher halten.** `AsyncImage` fängt bei jeder
///    neu gebauten Zeile von vorn an; in einer Liste ist das jedes
///    Zurückscrollen.
///
/// Die Zähler sind kein Beiwerk: „gefühlt schneller" ist genau die Sorte
/// Aussage, die diese Runde nicht mehr durchgehen lässt. Sie stehen in der
/// Diagnose.
@MainActor
@Observable
final class OfferImageLoader {
    static let shared = OfferImageLoader()

    /// Was der Speicher hergab, ohne irgendetwas anzufassen.
    private(set) var memoryHits = 0
    /// Was aus `URLCache` kam — Platte, also auch über App-Starts hinweg.
    private(set) var diskHits = 0
    /// Was wirklich über das Netz ging.
    private(set) var networkLoads = 0
    private(set) var failures = 0

    /// Wie lange ein Bild gelten soll, wenn der Server nichts oder `no-cache`
    /// sagt. Sieben Tage: länger als ein Prospekt, kürzer als eine Ewigkeit —
    /// und die Adresse ändert sich ohnehin, wenn das Bild ein anderes wird.
    static let fallbackMaxAge = 7 * 24 * 60 * 60

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    /// Läuft gerade eine Anfrage auf diese Adresse? Zwei Zeilen mit demselben
    /// Bild sollen nicht zweimal laden.
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
        // 120 Bilder — deutlich mehr, als eine Bildschirmhöhe trägt, und bei
        // ~30–480 kB je Bild noch weit unter dem, was ein Prospekt kostet.
        cache.countLimit = 120
    }

    /// Aus dem Speicher, ohne zu warten. Für den ersten `body`-Durchgang: Ein
    /// Bild, das schon da ist, soll nicht eine Runde lang als Rückfall stehen.
    func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func image(for url: URL) async -> UIImage? {
        if let hit = cached(url) {
            memoryHits += 1
            return hit
        }
        if let running = inFlight[url] { return await running.value }

        let request = URLRequest(url: url)
        // **Die Platte wird selbst gelesen, nicht `URLSession` überlassen.**
        //
        // Das ist der Kern des Fixes: `URLSession` hält sich an den Server, und
        // der sagt bei unserem eigenen Mirror `no-cache` und bei Kaufland gar
        // nichts. Wer das Nachfragen abstellen will, muss die Antwort selbst
        // aus dem Cache holen — sonst geht jedes Bild bei jedem App-Start noch
        // einmal über sechs fremde CDNs.
        //
        // **Was das kostet, gehört dazu:** Ein Bild unter einer bekannten
        // Adresse wird nicht mehr nachgeprüft. Bei diesen Adressen ist das
        // richtig — sie tragen eine UUID oder einen Hash (`…/277aed56-013e-…
        // _1136x1136.png`), ändert sich das Bild, ändert sich die Adresse. Bei
        // einer Adresse wie `.../aktuell.png` wäre es falsch; die gibt es hier
        // nicht.
        if let stored = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: stored.data) {
            diskHits += 1
            cache.setObject(image, forKey: url.absoluteString as NSString)
            return image
        }

        let task = Task<UIImage?, Never> { [session] in
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    return nil
                }
                Self.store(data: data, response: http, for: request)
                return UIImage(data: data)
            } catch {
                return nil
            }
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil

        if let image {
            cache.setObject(image, forKey: url.absoluteString as NSString)
            networkLoads += 1
        } else {
            failures += 1
        }
        return image
    }

    /// Die Bilder der sichtbaren Liste im Voraus holen.
    ///
    /// **Ohne eigenen Nebenläufigkeits-Zirkus:** Jeder Aufruf ist ein Task, und
    /// `inFlight` verhindert Doppelläufe. Was schon im Speicher liegt, kostet
    /// einen Wörterbuch-Zugriff.
    func prefetch(_ urls: [URL]) {
        for url in urls where cached(url) == nil && inFlight[url] == nil {
            Task { _ = await image(for: url) }
        }
    }

    /// Schreibt die Antwort mit **unserer** Frist in den Cache.
    ///
    /// `URLCache` hält sich an den Server: `no-cache` heißt „jedes Mal
    /// nachfragen", eine fehlende Angabe heißt „raten". Für inhaltsadressierte
    /// Bilder ist beides teuer und keins davon nötig. Der `Cache-Control`-Kopf
    /// wird deshalb ersetzt, bevor die Antwort abgelegt wird — und nur er.
    private static func store(data: Data, response: HTTPURLResponse, for request: URLRequest) {
        var headers = response.allHeaderFields as? [String: String] ?? [:]
        headers["Cache-Control"] = "max-age=\(fallbackMaxAge)"
        guard let url = response.url,
              let rewritten = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
              )
        else { return }
        URLCache.shared.storeCachedResponse(
            CachedURLResponse(response: rewritten, data: data, storagePolicy: .allowed),
            for: request
        )
    }

    /// Siehe `AppReset`.
    func reset() {
        cache.removeAllObjects()
        memoryHits = 0
        diskHits = 0
        networkLoads = 0
        failures = 0
    }
}
