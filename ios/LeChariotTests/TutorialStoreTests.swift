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

        store.start(origin: .settings, hasMarkets: true)
        XCTAssertTrue(store.isRunning)
        XCTAssertEqual(store.index, 0)
    }

    func testEveryStepIsReachedBeforeTheTourEnds() {
        let store = makeStore()
        store.start(origin: .settings, hasMarkets: true)

        for expected in 0..<store.stepCount {
            XCTAssertEqual(store.index, expected)
            XCTAssertTrue(store.isRunning)
            store.next()
        }

        XCTAssertFalse(store.isRunning, "Weiter auf dem letzten Rahmen beendet den Rundgang")
    }

    func testFinishingIsRemembered() {
        let store = makeStore()
        store.start(origin: .settings, hasMarkets: true)
        while store.isRunning { store.next() }

        XCTAssertTrue(store.hasSeenTutorial)
        XCTAssertTrue(makeStore().hasSeenTutorial, "der Merker muss den Neustart überleben")
    }

    /// Abbrechen zählt wie Durchlaufen: Wer „Tour beenden" tippt, will nicht
    /// beim nächsten Start wieder gefragt werden.
    func testAbortingCountsAsSeen() {
        let store = makeStore()
        store.start(origin: .settings, hasMarkets: true)
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
        store.start(origin: .settings, hasMarkets: true)
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
        store.start(origin: .settings, hasMarkets: true)

        for _ in 0..<(store.steps.count - 1) {
            XCTAssertFalse(store.isLastStep, "Schritt \(store.index) ist nicht der letzte")
            store.next()
        }

        XCTAssertTrue(store.isLastStep)
    }

    // MARK: Die Frage nach den Filialen

    /// Der eigentliche Punkt des Umbaus vom 2026-07-31: Das Onboarding endet in
    /// der Liste, der Rundgang zeigt sie, und **am Ende** wird gefragt.
    func testATourFromOnboardingWithoutMarketsAsksForThemAtTheEnd() {
        let store = makeStore()
        store.start(origin: .onboarding, hasMarkets: false)
        while store.isRunning { store.next() }

        XCTAssertTrue(store.asksForMarkets)
        store.dismissMarketQuestion()
        XCTAssertFalse(store.asksForMarkets, "beantwortet ist beantwortet")
    }

    /// Auch der Abbruch führt zur Frage: Wer „Tour beenden" tippt, hat trotzdem
    /// keine Filiale, und ihn still in einer Liste stehenzulassen, die nichts
    /// vergleichen kann, wäre die Sackgasse von vorher.
    func testAbortingATourFromOnboardingAsksToo() {
        let store = makeStore()
        store.start(origin: .onboarding, hasMarkets: false)
        store.next()
        store.skip()

        XCTAssertTrue(store.asksForMarkets)
    }

    /// **Die Bedingung, die bestehende Installationen schützt.** Wer den
    /// Rundgang aus den Einstellungen noch einmal ansieht, wird nie gefragt —
    /// egal ob er gerade Filialen hat oder nicht.
    func testATourFromTheSettingsNeverAsks() {
        for hasMarkets in [true, false] {
            let store = makeStore()
            store.start(origin: .settings, hasMarkets: hasMarkets)
            while store.isRunning { store.next() }

            XCTAssertFalse(store.asksForMarkets,
                           "aus den Einstellungen, hasMarkets: \(hasMarkets)")
        }
    }

    /// Und der andere Rand: aus dem Onboarding, aber mit Filialen — der Fall
    /// einer Installation, die ihre Filialen vor dem Umbau gewählt hat und den
    /// Assistenten neu durchläuft.
    func testATourFromOnboardingWithMarketsDoesNotAsk() {
        let store = makeStore()
        store.start(origin: .onboarding, hasMarkets: true)
        while store.isRunning { store.next() }

        XCTAssertFalse(store.asksForMarkets)
    }

    /// Ein zweiter Rundgang darf nicht die Antwort des ersten erben.
    func testStartingAgainClearsAPendingQuestion() {
        let store = makeStore()
        store.start(origin: .onboarding, hasMarkets: false)
        store.skip()
        XCTAssertTrue(store.asksForMarkets)

        store.start(origin: .settings, hasMarkets: false)
        XCTAssertFalse(store.asksForMarkets)
    }

    // MARK: Die zwei Texte, die von den Filialen abhängen

    /// Über einer Liste ohne Filiale steht an der Plan-Karte und an der
    /// Treffer-Zeile ein Leerzustand. Die Rahmen darüber müssen dieselbe
    /// Zeitform sprechen — „Tipp es an" über einer Zeile, in der nichts
    /// anzutippen ist, ist die erste Lüge, die ein Tester zu sehen bekäme.
    func testTheDataDependentFramesSpeakDifferentlyWithoutMarkets() {
        let withMarkets = TutorialStep.tour(hasMarkets: true)
        let without = TutorialStep.tour(hasMarkets: false)

        XCTAssertEqual(withMarkets.map(\.id), without.map(\.id),
                       "die Rahmen selbst sind dieselben, nur zwei Texte ändern sich")

        let changed = zip(withMarkets, without)
            .filter { $0.text != $1.text }
            .map(\.0.id)
        XCTAssertEqual(changed, ["plan", "match"])

        let match = without.first { $0.id == "match" }!
        XCTAssertFalse(match.text.contains("Tipp es an"),
                       "ohne Filiale gibt es dort nichts anzutippen")
    }

    /// Der Store friert die Fassung beim Start ein — die Filialauswahl liegt
    /// während des Rundgangs hinter den Sperrflächen, ein Text, der mitten im
    /// Lesen die Zeitform wechselt, wäre schlimmer als ein veralteter.
    func testTheStoreKeepsTheVariantItStartedWith() {
        let store = makeStore()
        store.start(origin: .onboarding, hasMarkets: false)

        XCTAssertEqual(store.steps.map(\.text),
                       TutorialStep.tour(hasMarkets: false).map(\.text))
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
            store.start(origin: .settings, hasMarkets: true)
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
        // Aus dem Onboarding und ohne Filialen: der einzige Weg, bei dem am
        // Ende eine Frage offensteht — sonst prüfte die Zusicherung unten nur
        // einen Wert, der ohnehin nie gesetzt war.
        store.start(origin: .onboarding, hasMarkets: false)
        store.seedDemoItems(into: list)
        store.finish()

        store.resetAllData()

        XCTAssertFalse(store.hasSeenTutorial)
        XCTAssertTrue(store.seededItems.isEmpty)
        XCTAssertFalse(store.asksForMarkets, "auch eine offene Frage gehört weggeräumt")
        let fresh = makeStore()
        XCTAssertFalse(fresh.hasSeenTutorial, "kein Schlüssel darf auf der Platte zurückbleiben")
        XCTAssertTrue(fresh.seededItems.isEmpty)
    }
}
