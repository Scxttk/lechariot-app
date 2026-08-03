import XCTest
@testable import LeChariot

/// **Kalt und warm, in Zahlen.**
///
/// Scott, 03.08.: „manche Bilder sofort da, manche verzögert, manche
/// dazwischen." Die Messung am selben Tag über 1 000 Zeilen mit Bild: sieben
/// Hosts, 266 bis 2 751 ms, und **zwei davon verbieten das Zwischenspeichern
/// oder sagen gar nichts dazu** — unser eigener Supabase-Mirror schickt
/// `no-cache` (231 Zeilen), `kaufland.media.schwarz` gar keinen
/// `Cache-Control` (343 Zeilen). `URLCache` muss dann bei jedem Bild neu
/// anfragen, bei jedem Scrollen und nach jedem App-Start.
///
/// Genau das prüfen diese Tests, und zwar an dem Server, der es am schärfsten
/// verbietet: Er antwortet mit `no-cache`, und trotzdem darf ein zweiter Lauf
/// nicht mehr ins Netz gehen.
@MainActor
final class OfferImageLoaderTests: XCTestCase {
    private var session: URLSession!
    private var cache: URLCache!
    private var vorher: URLCache!
    private var ordner: URL!

    override func setUp() {
        super.setUp()
        StubProtocol.reset()
        // **Ein eigener Ordner je Test, und das ist keine Kosmetik.** Ein
        // `URLCache` ohne `directory:` schreibt in das Standardverzeichnis —
        // also in dasselbe wie der vorige Testlauf. Der erste Anlauf meldete
        // „0 Anfragen" für einen kalten Start, weil das Bild vom Lauf davor
        // noch dalag. Ein Test, der Reste des letzten Laufs misst, misst nichts.
        ordner = FileManager.default.temporaryDirectory
            .appendingPathComponent("bildcache-\(UUID().uuidString)")
        cache = URLCache(memoryCapacity: 8 << 20, diskCapacity: 32 << 20, directory: ordner)
        cache.removeAllCachedResponses()
        vorher = URLCache.shared
        URLCache.shared = cache

        let config = URLSessionConfiguration.default
        config.protocolClasses = [StubProtocol.self]
        config.urlCache = cache
        config.requestCachePolicy = .useProtocolCachePolicy
        session = URLSession(configuration: config)
    }

    override func tearDown() {
        URLCache.shared = vorher
        cache.removeAllCachedResponses()
        try? FileManager.default.removeItem(at: ordner)
        StubProtocol.reset()
        super.tearDown()
    }

    private static let url = URL(string: "https://cddubgdnasmzvcfhmrzj.supabase.co/bild.png")!

    /// **Kalt:** genau ein Netzzugriff.
    func testAColdLoadGoesToTheNetworkExactlyOnce() async {
        let loader = OfferImageLoader(session: session)
        let bild = await loader.image(for: Self.url)

        XCTAssertNotNil(bild)
        XCTAssertEqual(StubProtocol.requests, 1, "kalt ist genau eine Anfrage")
        XCTAssertEqual(loader.networkLoads, 1)
        XCTAssertEqual(loader.memoryHits, 0)
    }

    /// **Warm, gleiche Sitzung:** kein Netz, kein Dekodieren — der Speicher.
    func testAWarmLoadInTheSameSessionTouchesNothing() async {
        let loader = OfferImageLoader(session: session)
        _ = await loader.image(for: Self.url)
        _ = await loader.image(for: Self.url)
        _ = await loader.image(for: Self.url)

        XCTAssertEqual(StubProtocol.requests, 1,
                       "dreimal dasselbe Bild ist eine Anfrage, nicht drei")
        XCTAssertEqual(loader.memoryHits, 2)
        XCTAssertEqual(loader.networkLoads, 1)
    }

    /// **Der Fund, um den es geht: über den App-Start hinweg — gegen einen
    /// Server, der `no-cache` sagt.**
    ///
    /// Ein frischer Loader ist ein frischer App-Start: leerer Speicher,
    /// derselbe `URLCache` auf der Platte. Ohne das Umschreiben des
    /// `Cache-Control`-Kopfes ginge hier eine zweite Anfrage ins Netz — bei
    /// jedem Bild, bei jedem Start.
    func testASecondAppStartServesFromDiskDespiteNoCache() async {
        let ersterStart = OfferImageLoader(session: session)
        _ = await ersterStart.image(for: Self.url)
        XCTAssertEqual(StubProtocol.requests, 1)

        let zweiterStart = OfferImageLoader(session: session)
        let bild = await zweiterStart.image(for: Self.url)

        XCTAssertNotNil(bild, "das Bild muss auch nach dem Neustart kommen")
        XCTAssertEqual(StubProtocol.requests, 1,
                       "der zweite Start darf nicht noch einmal ins Netz — der Server sagt no-cache, "
                       + "die Adresse ist trotzdem inhaltsadressiert")
        XCTAssertEqual(zweiterStart.diskHits, 1)
        XCTAssertEqual(zweiterStart.networkLoads, 0)
    }

    /// Und das ist der Grund, warum das oben geht: Die Antwort liegt mit
    /// **unserer** Frist im Cache, nicht mit der des Servers.
    func testTheStoredResponseCarriesOurOwnMaxAge() async {
        let loader = OfferImageLoader(session: session)
        _ = await loader.image(for: Self.url)

        let abgelegt = URLCache.shared.cachedResponse(for: URLRequest(url: Self.url))
        XCTAssertNotNil(abgelegt, "der Server sagt no-cache — abgelegt wird trotzdem")
        let kopf = (abgelegt?.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Cache-Control")
        XCTAssertEqual(kopf, "max-age=\(OfferImageLoader.fallbackMaxAge)")
    }

    /// Zwei Zeilen mit demselben Bild laden es einmal, nicht zweimal.
    func testTwoRowsWithTheSameImageShareOneRequest() async {
        let loader = OfferImageLoader(session: session)
        async let a = loader.image(for: Self.url)
        async let b = loader.image(for: Self.url)
        _ = await (a, b)

        XCTAssertEqual(StubProtocol.requests, 1)
    }

    /// Ein Fehlschlag wird gezählt und nicht als Bild ausgegeben.
    func testAFailureIsCountedAndYieldsNoImage() async {
        StubProtocol.status = 404
        let loader = OfferImageLoader(session: session)
        let bild = await loader.image(for: Self.url)

        XCTAssertNil(bild)
        XCTAssertEqual(loader.failures, 1)
    }
}

/// Ein Server, der sich verhält wie unser Mirror: gültiges PNG, `no-cache`.
private final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var requests = 0
    nonisolated(unsafe) static var status = 200

    static func reset() {
        requests = 0
        status = 200
    }

    /// Ein 1×1-PNG. Klein genug, um im Test nichts zu kosten, und echt genug,
    /// dass `UIImage(data:)` es annimmt.
    static let png = Data(base64Encoded: """
    iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==
    """)!

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests += 1
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.status,
            httpVersion: "HTTP/1.1",
            // Genau der Kopf, den unser Mirror am 03.08. geschickt hat.
            headerFields: ["Cache-Control": "no-cache", "Content-Type": "image/png"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if Self.status == 200 {
            client?.urlProtocol(self, didLoad: Self.png)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
