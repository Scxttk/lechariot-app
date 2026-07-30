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
        XCTAssertTrue(AreaRequestStore.areaLooksUnfetched(found))
    }

    /// Steht auch nur eine der sechs gebietsweisen Ketten da, war das Gebiet
    /// schon einmal dran — dann gibt es nichts anzufordern.
    func testASingleAreaFetchedChainIsEnoughToCountAsFetched() {
        let found = [
            branch("1", chain: "Penny"),
            branch("2", chain: "Kaufland"),
            branch("3", chain: "Netto"),
        ]
        XCTAssertFalse(AreaRequestStore.areaLooksUnfetched(found))
    }

    /// Eine leere Liste ist kein Signal, sondern eine gescheiterte Suche —
    /// und ohne Filiale gäbe es ohnehin keinen Anker.
    func testAnEmptyListIsNotTheSignal() {
        XCTAssertFalse(AreaRequestStore.areaLooksUnfetched([]))
    }

    // MARK: Anfordern

    func testTheAreaIsRequestedOnce() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(anchor: "531032")
        await store.requestArea(anchor: "531032")

        XCTAssertEqual(repo.requested, ["531032"], "zweimal angefordert")
        XCTAssertTrue(store.isFetchingArea)
    }

    /// Der Trigger hat 30 Minuten Cooldown pro Gebiet: Ein zweiter Insert löst
    /// schweigend nichts aus. Deshalb wird erst gelesen — eine offene Zeile
    /// heißt „läuft schon", nicht „nochmal schicken".
    func testAnExistingPendingRowIsAdoptedInsteadOfInsertedAgain() async {
        let repo = MockAreaRequestRepository()
        repo.pending = ["531032"]
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(anchor: "531032")

        XCTAssertTrue(repo.requested.isEmpty, "Insert trotz laufender Anforderung")
        XCTAssertTrue(store.isFetchingArea)
    }

    /// Ist das Gebiet längst geholt, gibt es nichts zu warten und nichts zu
    /// melden — sonst bekäme der Nutzer einen Hinweis auf etwas, das schon da
    /// war, als er das erste Mal hinsah.
    func testAnAlreadyFinishedAreaNeitherWaitsNorAnnounces() async {
        let repo = MockAreaRequestRepository()
        repo.ready = ["531032"]
        let store = AreaRequestStore(repository: repo, defaults: defaults)

        await store.requestArea(anchor: "531032")
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
        await firstLaunch.requestArea(anchor: "531032")
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
        await store.requestArea(anchor: "531032")
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
        await store.requestArea(anchor: "531032")

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

        await store.requestArea(anchor: "penny-04639-1", region: "04626")
        await store.requestArea(anchor: "penny-17373-1", region: "17419")

        XCTAssertEqual(repo.requested, ["penny-04639-1", "penny-17373-1"])
        XCTAssertEqual(store.pendingAreaPLZs, ["04626", "17419"])
    }

    /// Fertig ist jedes Gebiet für sich. Solange eines noch läuft, bleibt der
    /// Hinweis stehen — aber das fertige wird gemeldet und nicht mitverschleppt.
    func testAreasFinishIndependently() async {
        let repo = MockAreaRequestRepository()
        let store = AreaRequestStore(repository: repo, defaults: defaults)
        await store.requestArea(anchor: "penny-04639-1", region: "04626")
        await store.requestArea(anchor: "penny-17373-1", region: "17419")

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

        await store.requestArea(anchor: "penny-17373-1", region: "17419")
        await store.requestArea(anchor: "penny-17373-1", region: "17419")

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
        await store.requestArea(anchor: "531032", region: "04639")
        repo.ready = ["531032"]
        await store.checkPendingArea()

        store.resetAllData()

        XCTAssertFalse(store.isFetchingArea)
        XCTAssertFalse(store.areaJustCompleted)

        let afterReset = AreaRequestStore(repository: repo, defaults: defaults)
        repo.ready = []
        await afterReset.requestArea(anchor: "531032", region: "04639")
        XCTAssertTrue(afterReset.isFetchingArea, "nach dem Reset wurde nicht neu angefordert")
    }
}
