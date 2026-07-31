import XCTest
@testable import LeChariot

@MainActor
final class TutorialStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "tutorial.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeStore() -> TutorialStore {
        TutorialStore(defaults: defaults)
    }

    private func makeList() -> ShoppingListStore {
        ShoppingListStore(defaults: defaults)
    }

    // MARK: Der Rundgang selbst

    func testAFreshInstallHasNotSeenTheTour() {
        let store = makeStore()
        XCTAssertFalse(store.hasSeenTutorial)
        XCTAssertFalse(store.isRunning)
    }

    /// Er startet nie von allein — nur auf „Los geht's" oder aus den
    /// Einstellungen. Das ist der Unterschied zwischen Hilfe und Belästigung.
    func testTheTourOnlyRunsWhenItIsAskedFor() {
        let store = makeStore()
        XCTAssertFalse(store.isRunning)

        store.start()
        XCTAssertTrue(store.isRunning)
        XCTAssertEqual(store.index, 0)
    }

    func testEveryStepIsReachedBeforeTheTourEnds() {
        let store = makeStore()
        store.start()

        for expected in 0..<store.stepCount {
            XCTAssertEqual(store.index, expected)
            XCTAssertTrue(store.isRunning)
            store.next()
        }

        XCTAssertFalse(store.isRunning, "Weiter auf dem letzten Rahmen beendet den Rundgang")
    }

    func testFinishingIsRemembered() {
        let store = makeStore()
        store.start()
        while store.isRunning { store.next() }

        XCTAssertTrue(store.hasSeenTutorial)
        XCTAssertTrue(makeStore().hasSeenTutorial, "der Merker muss den Neustart überleben")
    }

    /// Abbrechen zählt wie Durchlaufen: Wer „Tour beenden" tippt, will nicht
    /// beim nächsten Start wieder gefragt werden.
    func testAbortingCountsAsSeen() {
        let store = makeStore()
        store.start()
        store.next()
        store.skip()

        XCTAssertFalse(store.isRunning)
        XCTAssertEqual(store.index, 0)
        XCTAssertTrue(makeStore().hasSeenTutorial)
    }

    func testDecliningTheOfferCountsAsSeenToo() {
        let store = makeStore()
        store.decline()

        XCTAssertFalse(store.isRunning)
        XCTAssertTrue(makeStore().hasSeenTutorial)
    }

    func testStepsAreDistinctAndSpeakGerman() {
        let store = makeStore()
        XCTAssertEqual(Set(store.steps.map(\.id)).count, store.steps.count, "doppelte Schritt-IDs")
        for step in store.steps {
            XCTAssertFalse(step.title.isEmpty)
            XCTAssertFalse(step.text.isEmpty)
        }
    }

    /// Genau die beiden Mitmach-Rahmen lassen Berührungen durch. Sonst wäre der
    /// Rundgang entweder eine Diashow oder ein Loch, durch das man sich
    /// versehentlich aus der Führung klickt.
    func testOnlyTheHandsOnStepsLetTouchesThrough() {
        let store = makeStore()
        let interactive = store.steps.filter(\.allowsInteraction)
        XCTAssertEqual(interactive.map(\.id), ["input", "chips"])
    }

    /// **Kein** Rahmen läuft von allein weiter. Die beiden Mitmach-Rahmen taten
    /// das bis zum 2026-07-30 (`advance: .itemAdded`) und sprangen weiter,
    /// sobald ein Artikel auf der Liste landete — also mitten im Lesen, gemeldet
    /// vom ersten Tester außerhalb des Hauses. Mitmachen und Weiterblättern sind
    /// seitdem zwei Dinge; hier steht, dass sie es bleiben.
    func testNoStepAdvancesOnItsOwn() {
        let store = makeStore()
        let list = makeList()
        store.start()
        let before = store.index

        _ = list.add("Butter")
        _ = list.add("Milch")

        XCTAssertEqual(store.index, before, "Artikel auf der Liste blättern nicht weiter")
        XCTAssertTrue(store.isRunning)
    }

    /// Auf dem letzten Rahmen heißt der Primärknopf „Fertig" und tut dasselbe
    /// wie „Tour beenden" — deshalb blendet das Overlay den Abbruch dort aus.
    /// Der Test hält die Bedingung fest, an der es hängt.
    func testTheLastStepIsTheOnlyOneWhereFinishingAndAbortingAreTheSame() {
        let store = makeStore()
        store.start()

        for _ in 0..<(store.steps.count - 1) {
            XCTAssertFalse(store.isLastStep, "Schritt \(store.index) ist nicht der letzte")
            store.next()
        }

        XCTAssertTrue(store.isLastStep)
    }

    // MARK: Beispiel-Artikel

    func testTheDemoItemsGoOnTheListAndComeOffAgain() {
        let store = makeStore()
        let list = makeList()

        store.seedDemoItems(into: list)
        XCTAssertEqual(list.items.map(\.text), TutorialStore.demoItems)

        store.removeDemoItems(from: list)
        XCTAssertTrue(list.items.isEmpty)
        XCTAssertTrue(store.seededItems.isEmpty)
    }

    /// Was der Nutzer selbst getippt hat, gehört ihm — auch wenn es zufällig
    /// „Milch" heißt. `add` meldet die Doppelung, und der Rundgang lässt die
    /// Zeile danach stehen.
    func testWhatTheUserAddedHimselfIsNeverTakenAway() {
        let store = makeStore()
        let list = makeList()
        list.add("Milch")

        store.seedDemoItems(into: list)
        store.removeDemoItems(from: list)

        XCTAssertEqual(list.items.map(\.text), ["Milch"])
    }

    /// Wird die App mitten im Rundgang beendet, räumt niemand mehr auf. Die
    /// gesetzten Artikel überleben deshalb auf Platte, damit der nächste Start
    /// es nachholen kann.
    func testDemoItemsSurviveAnAppDeathAndAreCleanedUpLater() {
        let list = makeList()
        do {
            let store = makeStore()
            store.start()
            store.seedDemoItems(into: list)
        }

        let afterRestart = makeStore()
        XCTAssertEqual(afterRestart.seededItems.count, TutorialStore.demoItems.count)

        afterRestart.removeDemoItems(from: ShoppingListStore(defaults: defaults))
        XCTAssertTrue(ShoppingListStore(defaults: defaults).items.isEmpty)
        XCTAssertTrue(makeStore().seededItems.isEmpty, "der Merker muss mit abgeräumt werden")
    }

    // MARK: Zurücksetzen

    func testResetPutsEverythingBack() {
        let store = makeStore()
        let list = makeList()
        store.start()
        store.seedDemoItems(into: list)
        store.finish()

        store.resetAllData()

        XCTAssertFalse(store.hasSeenTutorial)
        XCTAssertTrue(store.seededItems.isEmpty)
        let fresh = makeStore()
        XCTAssertFalse(fresh.hasSeenTutorial, "kein Schlüssel darf auf der Platte zurückbleiben")
        XCTAssertTrue(fresh.seededItems.isEmpty)
    }
}
