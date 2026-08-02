import XCTest
@testable import LeChariot

/// Gebiets-Anforderung (Backend-Migration v19).
///
/// Der Kern ist nicht das Anfordern, sondern das **Wiederfinden**: Der Lauf
/// dauert ~3 Minuten und überlebt die App. Wer ihn auslöst, ist längst weiter —
/// ohne den Hinweis beim nächsten Start bliebe die kurze Liste vom Onboarding
/// für immer die Wahrheit, die der Nutzer kennt.
@MainActor
final class AreaRequestStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AreaRequestStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// Der Punkt, um den die Fixtures unten stehen — sie tragen alle genau
    /// diese Koordinaten, liegen also im Ausgangskreis.
    private let goessnitz = (lat: 50.887, lon: 12.433)

    private func branch(_ id: String, chain: String) -> Branch {
        Branch(
            marketId: id, chain: chain, name: "\(chain) Test",
            street: "Teststraße 1", plz: "04639", city: "Gößnitz",
            lat: 50.887, lon: 12.433
        )
    }

    // MARK: Erkennung

    /// Kaufland und Penny stehen bundesweit im Verzeichnis, weil ihre ganze
    /// Liste einen Request kostet. Nur die beiden im Umkreis heißt deshalb
    /// nicht „dünn besiedelt", sondern „dieses Gebiet hat nie jemand geholt".
    func testOnlyNationwideChainsMeansTheAreaWasNeverFetched() {
        let found = [branch("1", chain: "Penny"), branch("2", chain: "Kaufland")]
        XCTAssertTrue(AreaRequestStore.areaLooksUnfetched(found, around: goessnitz.lat, goessnitz.lon))
    }

    /// Steht auch nur eine der sechs gebietsweisen Ketten da, war das Gebiet
    /// schon einmal dran — dann gibt es nichts anzufordern.
    func testASingleAreaFetchedChainIsEnoughToCountAsFetched() {
        let found = [
            branch("1", chain: "Penny"),
            branch("2", chain: "Kaufland"),
            branch("3", chain: "Netto"),
        ]
        XCTAssertFalse(AreaRequestStore.areaLooksUnfetched(found, around: goessnitz.lat, goessnitz.lon))
    }

    /// Eine leere Liste ist kein Signal, sondern eine gescheiterte Suche —
    /// und ohne Filiale gäbe es ohnehin keinen Anker.
    func testAnEmptyListIsNotTheSignal() {
        XCTAssertFalse(AreaRequestStore.areaLooksUnfetched([], around: goessnitz.lat, goessnitz.lon))
    }

    /// **Anklam, 02.08.** Die Fremdkette steht im Nachbarort, nicht hier: Um
    /// den Penny in Anklam ist im Ausgangskreis nichts als der Penny, das
    /// nächste Netto liegt 11 km weit in Ducherow. Vorher zählte der
    /// geweitete Fund mit — und das Gebiet galt als versorgt.
    func testAChainInTheNextTownDoesNotCountAsFetchedHere() {
        let anklam = (lat: 53.85032, lon: 13.69157)
        let found = [
            Branch(
                marketId: "561536", chain: "Penny", name: "Penny Friedländer Straße",
                street: "Friedländer Straße", plz: "17389", city: "Anklam",
                lat: 53.85032, lon: 13.69157
            ),
            // 11,0 km — außerhalb des Ausgangskreises.
            Branch(
                marketId: "7453", chain: "Netto", name: "Netto Ducherow",
                street: "Thomas-Müntzer-Str. 1a", plz: "17398", city: "Ducherow",
                lat: 53.7659278, lon: 13.7781329
            ),
        ]
        XCTAssertTrue(AreaRequestStore.areaLooksUnfetched(found, around: anklam.lat, anklam.lon))
    }

    /// Die Gegenrichtung, damit der Fix nicht überschießt: dieselbe Fremdkette
    /// im Ausgangskreis heißt weiterhin „geholt".
    func testAChainInsideTheCircleStillCountsAsFetched() {
        let anklam = (lat: 53.85032, lon: 13.69157)
        let found = [
            Branch(
                marketId: "561536", chain: "Penny", name: "Penny Friedländer Straße",
                street: "Friedländer Straße", plz: "17389", city: "Anklam",
                lat: 53.85032, lon: 13.69157
            ),
            // Rund 2 km — mitten in der Stadt.
            Branch(
                marketId: "netto-anklam", chain: "Netto", name: "Netto Anklam",
                street: "Pasewalker Allee 1", plz: "17389", city: "Anklam",
                lat: 53.8672, lon: 13.6885
            ),
        ]
        XCTAssertFalse(AreaRequestStore.areaLooksUnfetched(found, around: anklam.lat, anklam.lon))
    }

    // MARK: Anfordern

    func testTheAreaIsRequestedOnce() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(anchor: "531032", lat: 50.887, lon: 12.433)
        await store.requestArea(anchor: "531032", lat: 50.887, lon: 12.433)

        XCTAssertEqual(repo.requested, ["531032"], "zweimal angefordert")
        XCTAssertTrue(store.isFetchingArea)
    }

    /// Der Trigger hat 30 Minuten Cooldown pro Gebiet: Ein zweiter Insert löst
    /// schweigend nichts aus. Deshalb wird erst gelesen — eine offene Zeile
    /// heißt „läuft schon", nicht „nochmal schicken".
    func testAnExistingPendingRowIsAdoptedInsteadOfInsertedAgain() async {
        let repo = MockAreaRequestRepository()
        repo.pending = ["531032"]
        repo.coordinates = ["531032": (lat: 50.887, lon: 12.433)]
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(anchor: "531032", lat: 50.887, lon: 12.433)

        XCTAssertTrue(repo.requested.isEmpty, "Insert trotz laufender Anforderung")
        XCTAssertTrue(store.isFetchingArea)
    }

    /// Ist das Gebiet längst geholt, gibt es nichts zu warten und nichts zu
    /// melden — sonst bekäme der Nutzer einen Hinweis auf etwas, das schon da
    /// war, als er das erste Mal hinsah.
    func testAnAlreadyFinishedAreaNeitherWaitsNorAnnounces() async {
        let repo = MockAreaRequestRepository()
        repo.ready = ["531032"]
        repo.coordinates = ["531032": (lat: 50.887, lon: 12.433)]
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(anchor: "531032", lat: 50.887, lon: 12.433)
        await store.checkPendingArea()

        XCTAssertTrue(repo.requested.isEmpty)
        XCTAssertFalse(store.isFetchingArea)
        XCTAssertFalse(store.areaJustCompleted)
    }

    // MARK: Der Hinweis beim Wiederöffnen

    /// Das eigentliche Versprechen: Die Anforderung übersteht den Kaltstart,
    /// und beim nächsten Start erfährt der Nutzer davon.
    func testTheNoticeSurvivesAColdStart() async {
        let repo = MockAreaRequestRepository()
        let firstLaunch = AreaRequestStore(repository: repo, defaults: defaults)
        await firstLaunch.requestArea(anchor: "531032", lat: 50.887, lon: 12.433)
        XCTAssertFalse(firstLaunch.areaJustCompleted, "noch läuft er ja")

        // Der Lauf wird fertig, während die App nicht läuft.
        repo.ready = ["531032"]

        let secondLaunch = AreaRequestStore(repository: repo, defaults: defaults)
        XCTAssertTrue(secondLaunch.isFetchingArea, "offene Anforderung nicht erinnert")
        await secondLaunch.checkPendingArea()

        XCTAssertTrue(secondLaunch.areaJustCompleted, "kein Hinweis nach dem Neustart")
        XCTAssertFalse(secondLaunch.isFetchingArea)
    }

    /// Einmal gesagt ist gesagt. Ein Hinweis, der bei jedem Start wiederkommt,
    /// wird weggetippt statt gelesen.
    func testTheNoticeIsShownOnceNotOnEveryLaunch() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)
        await store.requestArea(anchor: "531032", lat: 50.887, lon: 12.433)
        repo.ready = ["531032"]
        await store.checkPendingArea()
        XCTAssertTrue(store.areaJustCompleted)
        store.dismissCompletionNotice()

        let laterLaunch = AreaRequestStore(repository: repo, defaults: defaults)
        await laterLaunch.checkPendingArea()

        XCTAssertFalse(laterLaunch.areaJustCompleted, "Hinweis kommt wieder")
        XCTAssertFalse(laterLaunch.isFetchingArea)
    }

    /// Solange der Lauf noch nicht durch ist, bleibt die Anforderung offen —
    /// über beliebig viele Starts hinweg. Genau der Fall, in dem ein Dispatch
    /// verloren ging: dann holt ihn der Sonntagslauf nach, und die App wartet
    /// so lange geduldig weiter, statt die Zeile zu vergessen.
    func testAPendingAreaStaysPendingAcrossLaunches() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)
        await store.requestArea(anchor: "531032", lat: 50.887, lon: 12.433)

        for _ in 0..<3 {
            let launch = AreaRequestStore(repository: repo, defaults: defaults)
            await launch.checkPendingArea()
            XCTAssertTrue(launch.isFetchingArea)
            XCTAssertFalse(launch.areaJustCompleted)
        }

        repo.ready = ["531032"]
        let finalLaunch = AreaRequestStore(repository: repo, defaults: defaults)
        await finalLaunch.checkPendingArea()
        XCTAssertTrue(finalLaunch.areaJustCompleted)
    }

    // MARK: Mehrere Gebiete

    /// **Die Regression.** Der Store hielt genau eine offene Anforderung; jede
    /// weitere fiel schweigend heraus. Wer zwei Regionen führt, bekam damit für
    /// die zweite nie ein Verzeichnis — und weil nichts fehlschlug, blieb das
    /// unbemerkt. Gemeldet am 2026-07-30 für 04626 und 17419.
    ///
    /// Serverseitig unbedenklich: Die Sperre des Triggers liegt auf der PLZ
    /// (Migration v19), zwei Anker in zwei Gebieten sind der vorgesehene Fall.
    func testTwoAreasAreBothRequested() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(anchor: "penny-04639-1", region: "04626", lat: 50.887, lon: 12.433)
        await store.requestArea(anchor: "penny-17373-1", region: "17419", lat: 53.9440, lon: 14.1830)

        XCTAssertEqual(repo.requested, ["penny-04639-1", "penny-17373-1"])
        XCTAssertEqual(store.pendingAreaPLZs, ["04626", "17419"])
    }

    /// Fertig ist jedes Gebiet für sich. Solange eines noch läuft, bleibt der
    /// Hinweis stehen — aber das fertige wird gemeldet und nicht mitverschleppt.
    func testAreasFinishIndependently() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)
        await store.requestArea(anchor: "penny-04639-1", region: "04626", lat: 50.887, lon: 12.433)
        await store.requestArea(anchor: "penny-17373-1", region: "17419", lat: 53.9440, lon: 14.1830)

        repo.ready = ["penny-17373-1"]
        await store.checkPendingArea()

        XCTAssertTrue(store.areaJustCompleted)
        XCTAssertEqual(store.completedAreaPLZs, ["04639"], "die PLZ des Backends, nicht unsere")
        XCTAssertTrue(store.isFetchingArea, "das zweite Gebiet läuft noch")
        XCTAssertEqual(store.pendingAreaPLZs, ["04626"])

        store.dismissCompletionNotice()
        repo.ready.insert("penny-04639-1")
        await store.checkPendingArea()

        XCTAssertTrue(store.areaJustCompleted)
        XCTAssertFalse(store.isFetchingArea)
    }

    /// Dasselbe Gebiet zweimal anzufordern bleibt folgenlos — die Sperre pro
    /// Anker gilt weiter, sie gilt nur nicht mehr für alle anderen mit.
    func testTheSameAreaIsStillOnlyRequestedOnce() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(anchor: "penny-17373-1", region: "17419", lat: 53.9440, lon: 14.1830)
        await store.requestArea(anchor: "penny-17373-1", region: "17419", lat: 53.9440, lon: 14.1830)

        XCTAssertEqual(repo.requested, ["penny-17373-1"])
    }

    /// Wer beim Update eine laufende Anforderung hat, darf sie nicht verlieren
    /// — sonst bliebe der Hinweis für immer aus, und genau dagegen ist dieser
    /// Store gebaut.
    func testAnInFlightRequestFromTheOlderSingleAnchorVersionSurvivesTheUpdate() async {
        let repo = MockAreaRequestRepository()
        repo.pending = ["531032"]
        defaults.set("531032", forKey: "areaRequest.pendingAnchor")

        let afterUpdate = AreaRequestStore(repository: repo, defaults: defaults)
        XCTAssertTrue(afterUpdate.isFetchingArea, "die laufende Anforderung ging verloren")
        XCTAssertNil(defaults.string(forKey: "areaRequest.pendingAnchor"), "alter Schlüssel blieb liegen")

        repo.pending = []
        repo.ready = ["531032"]
        await afterUpdate.checkPendingArea()
        XCTAssertTrue(afterUpdate.areaJustCompleted)
    }

    /// Der Debug-Reset verspricht Exaktheit. Ohne dies überlebte die Liste der
    /// bereits angekündigten Gebiete jeden Reset, und ein erneutes Onboarding
    /// im selben Gebiet fragte nie wieder — womit der Fix nicht vorführbar war.
    func testResetClearsPendingAndAnnouncedAreas() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)
        await store.requestArea(anchor: "531032", region: "04639", lat: 50.887, lon: 12.433)
        repo.ready = ["531032"]
        await store.checkPendingArea()

        store.resetAllData()

        XCTAssertFalse(store.isFetchingArea)
        XCTAssertFalse(store.areaJustCompleted)

        let afterReset = AreaRequestStore(repository: repo, defaults: defaults)
        repo.ready = []
        await afterReset.requestArea(anchor: "531032", region: "04639", lat: 50.887, lon: 12.433)
        XCTAssertTrue(afterReset.isFetchingArea, "nach dem Reset wurde nicht neu angefordert")
    }

    // MARK: Koordinaten (Migration v21)

    /// **Die Regression zum Vorfall vom 2026-07-30.** Was das Gebiet bestimmt,
    /// sind die Koordinaten der Regionsmitte — sie müssen beim Insert mitgehen.
    /// Ohne sie leitet der Server die PLZ wieder aus der Ankerfiliale ab, und
    /// die stand in Ahlbeck 24,5 km weit weg in Ueckermünde.
    func testTheRegionCentreIsSentWithTheRequest() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(
            anchor: "penny-17373-1", region: "17419", lat: 53.9440, lon: 14.1830
        )

        let sent = try! XCTUnwrap(repo.requestedCoordinates["penny-17373-1"])
        XCTAssertEqual(try! XCTUnwrap(sent.lat), 53.9440, accuracy: 0.0001)
        XCTAssertEqual(try! XCTUnwrap(sent.lon), 14.1830, accuracy: 0.0001)
    }

    // MARK: Das Gebiet ist der Schlüssel (Migration v22)

    /// **Der Kernfall, und ab v22 ohne Ausweichmanöver.** Penny Am Haff ist die
    /// nächste Filiale sowohl für Ueckermünde als auch für Ahlbeck. Bis v21 war
    /// `market_id` der Primärschlüssel von `area_requests`, die zweite Region
    /// bekam also 409 und musste auf einen anderen Anker ausweichen — und wenn
    /// alle Anker belegt waren, fragte sie **still** nie.
    ///
    /// Seit v22 ist der Schlüssel die Rasterzelle. Beide Regionen dürfen
    /// denselben Anker benutzen, und beide kommen durch.
    func testTwoRegionsMayShareTheSameAnchor() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(
            anchor: "penny-am-haff", region: "17373", lat: 53.7383, lon: 14.0511
        )
        await store.requestArea(
            anchor: "penny-am-haff", region: "17419", lat: 53.9440, lon: 14.1830
        )

        XCTAssertEqual(repo.requested, ["penny-am-haff", "penny-am-haff"],
                       "die zweite Region ging unter")
        XCTAssertEqual(store.pendingAreaPLZs, ["17373", "17419"])
    }

    /// Dasselbe Gebiet zweimal bleibt eine Anforderung — das ist die Aufgabe
    /// des Cooldowns, und der Unique-Index über die Zelle hält sie.
    func testTheSameAreaIsRequestedOnlyOnce() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(anchor: "a", region: "17419", lat: 53.9440, lon: 14.1830)
        // Ein paar hundert Meter weiter — 53,946/14,185 rundet auf dieselbe
        // Zelle 53,9/14,2. (53,953 täte es NICHT: das rundet auf 54,0.)
        await store.requestArea(anchor: "b", region: "17419", lat: 53.9460, lon: 14.1850)

        XCTAssertEqual(repo.requested, ["a"], "die zweite Anfrage war dasselbe Gebiet")
    }

    /// Eine offene Zeile **dieses** Gebiets wird übernommen, statt sie neu
    /// anzufordern — sonst liefe derselbe Lauf zweimal.
    func testAnOpenRowForThisAreaIsAdopted() async {
        let repo = MockAreaRequestRepository()
        repo.pending = ["penny-am-haff"]
        repo.coordinates = ["penny-am-haff": (lat: 53.9440, lon: 14.1830)]
        repo.areaKeys = ["cell:53.9,14.2": "penny-am-haff"]
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(
            anchor: "penny-am-haff", region: "17419", lat: 53.9440, lon: 14.1830
        )

        XCTAssertTrue(repo.requested.isEmpty, "die offene Zeile deckt dieses Gebiet ab")
        XCTAssertTrue(store.isFetchingArea)
    }

    /// Eine **fertige** Zeile der Nachbarstadt darf dieses Gebiet nicht
    /// verschlucken. Über die Zelle gefragt findet die App sie gar nicht erst —
    /// das ist der ganze Gewinn gegenüber der Suche über den Anker.
    func testAFinishedRowFromAnotherTownDoesNotSwallowThisArea() async {
        let repo = MockAreaRequestRepository()
        repo.ready = ["penny-am-haff"]
        repo.coordinates = ["penny-am-haff": (lat: 53.7383, lon: 14.0511)] // Ueckermünde
        repo.areaKeys = ["cell:53.7,14.1": "penny-am-haff"]
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(
            anchor: "penny-am-haff", region: "17419", lat: 53.9440, lon: 14.1830
        )

        XCTAssertEqual(repo.requested, ["penny-am-haff"],
                       "der fertige Lauf der Nachbarstadt zählte als unser Ergebnis")
        XCTAssertTrue(store.isFetchingArea)
    }

    /// Der Schlüssel muss zeichengleich zu `area_key` in Migration v22 und zu
    /// `branches::area_cell` im Backend sein. Laufen die drei auseinander,
    /// wartet die App auf einen Lauf, den es unter diesem Namen nicht gibt.
    func testTheAreaKeyMatchesTheBackendSpelling() {
        XCTAssertEqual(AreaRequestStore.areaKey(lat: 53.9440, lon: 14.1830), "cell:53.9,14.2")
        XCTAssertEqual(AreaRequestStore.areaKey(lat: 53.7383, lon: 14.0511), "cell:53.7,14.1")
        XCTAssertEqual(AreaRequestStore.areaKey(lat: 51.0225, lon: 13.7625), "cell:51.0,13.8")
        // -0.0 darf nicht als "-0.0" herauskommen.
        XCTAssertEqual(AreaRequestStore.areaKey(lat: 0.04, lon: -0.04), "cell:0.0,0.0")
    }

    /// **Der Server darf die Anforderung unter einem anderen Schlüssel führen.**
    ///
    /// Die App rechnet aus ihrer Regionsmitte `cell:…`. Verwirft der
    /// BEFORE-Trigger die Koordinaten — unplausibel oder mehr als 60 km vom
    /// Anker —, trägt die Zeile stattdessen `plz:…`. In der Produktionstabelle
    /// stehen am 2026-07-31 beide Formen nebeneinander.
    ///
    /// Ohne Rückfall suchte die App für immer einen Schlüssel, den es nicht
    /// gibt: „läuft noch", bis das Gerät neu installiert wird, und nichts
    /// schlägt dabei fehl.
    func testAPendingAreaIsStillFoundWhenTheServerKeyedItByPostcode() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(
            anchor: "penny-am-haff", region: "17419", lat: 53.9440, lon: 14.1830
        )
        XCTAssertTrue(store.isFetchingArea)

        // Der Server hat die Koordinaten verworfen: Die Zeile liegt unter
        // plz:17373, nicht unter cell:53.9,14.2 — unsere Zelle findet sie nicht.
        repo.areaKeys = [:]
        repo.coordinates = [:]
        repo.ready = ["penny-am-haff"]

        await store.checkPendingArea()

        XCTAssertTrue(store.areaJustCompleted, "die fertige Anforderung wurde nie gefunden")
        XCTAssertFalse(store.isFetchingArea)
    }
}
