import XCTest
@testable import LeChariot

/// Kochen: Abgleich mit der Liste, Einwilligung, und was aus den Antworten der
/// Edge Function wird — vor allem aus den abgelehnten.
@MainActor
final class GerichteTests: XCTestCase {
    private var defaults: UserDefaults!
    private let installId = UUID(uuidString: "0F8FAD5B-D9CB-469F-A165-70867728950E")!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "GerichteTests")
        defaults.removePersistentDomain(forName: "GerichteTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "GerichteTests")
        GerichteStub.reset()
        super.tearDown()
    }

    private func items(_ texte: String...) -> [ShoppingItem] {
        texte.map { ShoppingItem(text: $0) }
    }

    private func gericht(_ zutaten: [(String, String)]) -> Gericht {
        Gericht(name: "Test", portionen: 2,
                zutaten: zutaten.map { Zutat(begriff: $0.0, name: $0.1, menge: "") })
    }

    // MARK: Abgleich

    func testNudelnAufDerListeDeckenSpaghettiImRezept() {
        let g = gericht([("nudeln", "Spaghetti"), ("hackfleisch", "Hackfleisch")])
        XCTAssertEqual(GerichtAbgleich.fehlende(g, items: items("Nudeln")).map(\.name), ["Hackfleisch"])
    }

    func testOberbegriffDecktInBeideRichtungen() {
        // Rezept will Salami, auf der Liste steht Wurst — und umgekehrt.
        XCTAssertTrue(GerichtAbgleich.fehlende(gericht([("salami", "Salami")]), items: items("Wurst")).isEmpty)
        XCTAssertTrue(GerichtAbgleich.fehlende(gericht([("wurst", "Wurst")]), items: items("Salami")).isEmpty)
    }

    func testAbgehakteZaehlenAlsVorhanden() {
        var milch = ShoppingItem(text: "Milch")
        milch.isChecked = true
        XCTAssertTrue(GerichtAbgleich.fehlende(gericht([("milch", "Milch")]), items: [milch]).isEmpty)
    }

    func testFremdeArtikelDeckenNichts() {
        let g = gericht([("zucchini", "Zucchini")])
        XCTAssertEqual(GerichtAbgleich.fehlende(g, items: items("Bananen", "Kaffee")).count, 1)
    }

    func testAngebotsBegriffeOhneNonfoodHaeufigsteZuerst() {
        func offer(_ keys: [String]) -> Offer {
            var o = Offer(
                market: "Lidl", product: "x", price: 1, regularPrice: nil, unit: nil,
                category: "c", emoji: nil, validFrom: .now, validUntil: .now,
                basePrice: nil, baseUnit: nil, nationwide: false
            )
            o.matchKey = keys
            return o
        }
        let begriffe = GerichtAbgleich.angebotsBegriffe([
            offer(["zucchini"]), offer(["hackfleisch"]), offer(["hackfleisch"]), offer(["nonfood"]),
        ])
        XCTAssertEqual(begriffe, ["hackfleisch", "zucchini"])
    }

    // MARK: Einwilligung

    func testOhneEinwilligungGehtNichtsRaus() async {
        let mock = MockGerichteRepository()
        mock.verzoegerung = .zero
        let store = GerichteStore(repository: mock, einwilligung: GerichteEinwilligung(defaults: defaults))
        XCTAssertFalse(store.einwilligungErteilt)

        await store.frageVorschlaege(items: items("Nudeln"), angebote: [], installId: installId)
        await store.frageZutaten(fuer: "Lasagne", installId: installId)

        XCTAssertEqual(store.vorschlaege, .leer)
        XCTAssertEqual(store.zutaten, .leer)
        XCTAssertTrue(mock.letzteListe.isEmpty, "Ohne Einwilligung darf die Liste das Gerät nicht verlassen")
    }

    func testEinwilligungBleibtUndLaesstSichWiderrufen() async {
        let einwilligung = GerichteEinwilligung(defaults: defaults)
        let mock = MockGerichteRepository()
        mock.verzoegerung = .zero
        let store = GerichteStore(repository: mock, einwilligung: einwilligung)
        store.einwilligen()

        XCTAssertTrue(GerichteEinwilligung(defaults: defaults).erteilt, "Die Einwilligung muss gespeichert sein")
        await store.frageZutaten(fuer: "Lasagne", installId: installId)
        XCTAssertEqual(store.zutaten, .fertig(MockGerichteRepository.lasagne))

        einwilligung.widerrufen()
        XCTAssertFalse(GerichteStore(repository: mock, einwilligung: einwilligung).einwilligungErteilt)
    }

    func testNurDieTexteDerListeGehenRaus() async {
        let mock = MockGerichteRepository()
        mock.verzoegerung = .zero
        let store = GerichteStore(repository: mock, einwilligung: GerichteEinwilligung(defaults: defaults))
        store.einwilligen()
        let liste = [
            ShoppingItem(text: " Nudeln ", note: "die von Oma"),
            ShoppingItem(text: "nudeln"),
            ShoppingItem(text: String(repeating: "x", count: 41)),
            ShoppingItem(text: "Tomaten", detail: ["Bio"]),
        ]
        await store.frageVorschlaege(items: liste, angebote: ["hackfleisch"], installId: installId)
        XCTAssertEqual(mock.letzteListe, ["Nudeln", "Tomaten"])
        XCTAssertEqual(mock.letzteAngebote, ["hackfleisch"])
    }

    // MARK: Liste

    func testZutatKommtMitMengeAlsNotiz() {
        let list = ShoppingListStore(defaults: defaults)
        XCTAssertTrue(list.addIngredient("Hackfleisch", menge: "500 g"))
        XCTAssertEqual(list.items.last?.text, "Hackfleisch")
        XCTAssertEqual(list.items.last?.note, "500 g")
        // Schon auf der Liste: nichts doppelt, die Notiz bleibt.
        XCTAssertFalse(list.addIngredient("Hackfleisch", menge: "1 kg"))
        XCTAssertEqual(list.items.count, 1)
    }

    // MARK: Antworten der Edge Function

    private func liveRepo() -> LiveGerichteRepository {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [GerichteStub.self]
        let client = SupabaseClient(
            baseURL: URL(string: "https://beispiel.supabase.co")!,
            apiKey: "sb_publishable_test",
            session: URLSession(configuration: config)
        )
        return LiveGerichteRepository(client: client)
    }

    func testErfolgWirdGelesenUndAnfrageTraegtNurDasNoetige() async throws {
        GerichteStub.status = 200
        GerichteStub.body = """
        {"gericht":{"name":"Lasagne","portionen":4,"zutaten":[{"begriff":"hackfleisch","name":"Hackfleisch","menge":"500 g"}]},"rest":19}
        """
        let g = try await liveRepo().zutaten(fuer: "Lasagne für 4", installId: installId)
        XCTAssertEqual(g.zutaten.map(\.name), ["Hackfleisch"])

        let anfrage = try XCTUnwrap(GerichteStub.letzteAnfrage)
        XCTAssertEqual(anfrage.url?.path, "/functions/v1/gerichte")
        let body = try XCTUnwrap(GerichteStub.letzterKoerper)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(Set(json.keys), ["art", "gericht", "install_id"])
        XCTAssertEqual(json["install_id"], installId.uuidString.lowercased())
    }

    func testKontingentErschoepftWirdBenannt() async {
        GerichteStub.status = 429
        GerichteStub.body = #"{"fehler":"kontingent","grenze":20}"#
        await assertFehler(.kontingent(grenze: 20))
    }

    func testGesamtdeckelWirdBenannt() async {
        GerichteStub.status = 429
        GerichteStub.body = #"{"fehler":"gesamt","grenze":20}"#
        await assertFehler(.gesamt)
    }

    func testKeinGericht() async {
        GerichteStub.status = 422
        GerichteStub.body = #"{"fehler":"kein_gericht","rest":3}"#
        await assertFehler(.keinGericht)
    }

    func testNichtAusgerolltHeisstNichtErreichbar() async {
        GerichteStub.status = 404
        GerichteStub.body = "Not Found"
        await assertFehler(.nichtErreichbar)
    }

    func testStoreZeigtDenFehlerStattLeer() async {
        let store = GerichteStore(
            repository: MockGerichteRepository(fehler: .kontingent(grenze: 20)),
            einwilligung: GerichteEinwilligung(defaults: defaults)
        )
        store.einwilligen()
        await store.frageZutaten(fuer: "Lasagne", installId: installId)
        XCTAssertEqual(store.zutaten, .fehler(.kontingent(grenze: 20)))
        XCTAssertEqual(GerichteFehler.kontingent(grenze: 20).meldung,
                       "Für heute sind die 20 Anfragen aufgebraucht. Morgen geht es weiter.")
    }

    private func assertFehler(_ erwartet: GerichteFehler, line: UInt = #line) async {
        do {
            _ = try await liveRepo().zutaten(fuer: "Lasagne", installId: installId)
            XCTFail("Kein Fehler", line: line)
        } catch {
            XCTAssertEqual(error as? GerichteFehler, erwartet, line: line)
        }
    }
}

private final class GerichteStub: URLProtocol {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = "{}"
    nonisolated(unsafe) static var letzteAnfrage: URLRequest?
    nonisolated(unsafe) static var letzterKoerper: Data?

    static func reset() {
        status = 200
        body = "{}"
        letzteAnfrage = nil
        letzterKoerper = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.letzteAnfrage = request
        // URLSession reicht den Körper an ein URLProtocol als Strom weiter.
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var puffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let n = stream.read(&puffer, maxLength: puffer.count)
                if n <= 0 { break }
                data.append(puffer, count: n)
            }
            stream.close()
            Self.letzterKoerper = data
        } else {
            Self.letzterKoerper = request.httpBody
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
