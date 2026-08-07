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
        store.decline(hasMarkets: true)

        XCTAssertFalse(store.isRunning)
        XCTAssertTrue(makeStore().hasSeenTutorial)
    }

    // MARK: Das Angebot am Ende des Assistenten

    /// **Der Fund vom 2026-08-02.** Der Merker wurde geschrieben und von keiner
    /// Ansicht gelesen; `OnboardingFlowView.offersTour` gab `true` zurück. Ein
    /// zweiter Lauf des Assistenten — aus welchem Grund auch immer — bot den
    /// Rundgang deshalb wieder an. Diese vier Fälle sind die Regel, die es
    /// vorher nur im Kommentar gab.
    func testTheTourIsOfferedOnceAndThenNotAgain() {
        XCTAssertTrue(makeStore().offersTourAfterOnboarding,
                      "frische Installation: der Rundgang wird angeboten")

        let store = makeStore()
        store.decline(hasMarkets: true)
        XCTAssertFalse(store.offersTourAfterOnboarding)
        XCTAssertFalse(makeStore().offersTourAfterOnboarding,
                       "und auch nach einem Neustart nicht wieder — das war die Meldung")
    }

    func testWalkingTheTourAlsoEndsTheOffer() {
        let store = makeStore()
        store.start(origin: .onboarding, hasMarkets: false)
        while store.isRunning { store.next() }

        XCTAssertFalse(makeStore().offersTourAfterOnboarding)
    }

    /// Die Gegenrichtung, und sie ist gewollt: Wer alles zurücksetzt, ist eine
    /// neue Installation und bekommt den Rundgang wieder angeboten.
    func testAnExplicitResetOffersTheTourAgain() {
        let store = makeStore()
        store.decline(hasMarkets: true)
        XCTAssertFalse(store.offersTourAfterOnboarding)

        store.resetAllData()
        XCTAssertTrue(store.offersTourAfterOnboarding)
        XCTAssertTrue(makeStore().offersTourAfterOnboarding,
                      "kein Schlüssel darf den Reset überleben")
    }

    func testStepsAreDistinctAndSpeakGerman() {
        let store = makeStore()
        XCTAssertEqual(Set(store.steps.map(\.id)).count, store.steps.count, "doppelte Schritt-IDs")
        for step in store.steps {
            XCTAssertFalse(step.title.isEmpty)
            XCTAssertFalse(step.text.isEmpty)
        }
    }

    /// Genau der eine Mitmach-Rahmen lässt Berührungen durch. Sonst wäre der
    /// Rundgang entweder eine Diashow oder ein Loch, durch das man sich
    /// versehentlich aus der Führung klickt.
    ///
    /// Bis zum 06.08. waren es zwei — der zweite zeigte auf die
    /// Vorschlagskacheln, die auf dem Bildschirm ohnehin stehen.
    func testOnlyTheHandsOnStepLetsTouchesThrough() {
        let store = makeStore()
        let interactive = store.steps.filter(\.allowsInteraction)
        XCTAssertEqual(interactive.map(\.id), ["input"])
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

    /// **Der Weg, den es vorher nicht gab** (05.08.): Wer das Angebot mit
    /// „Später" ablehnt und keine Filiale hat, bekommt die Markt-Frage
    /// trotzdem. Vorher hing sie nur am Ende des Rundgangs — Überspringer
    /// standen wortlos vor einer Liste, die nichts vergleichen kann.
    func testDecliningTheOfferWithoutMarketsAsksToo() {
        let store = makeStore()
        store.decline(hasMarkets: false)

        XCTAssertTrue(store.asksForMarkets)
    }

    /// Und die Gegenrichtung: Wer beim Ablehnen schon Filialen hat, hat die
    /// Frage längst beantwortet — für bestehende Installationen ändert sich
    /// nichts.
    func testDecliningTheOfferWithMarketsDoesNotAsk() {
        let store = makeStore()
        store.decline(hasMarkets: true)

        XCTAssertFalse(store.asksForMarkets)
    }

    // MARK: Was der Rundgang sagt

    /// Über einer Liste ohne Filiale steht an der Plan-Karte ein Leerzustand.
    /// Der Rahmen darüber muss dieselbe Zeitform sprechen — eine Karte, die
    /// „sagt dir, welche Filiale am günstigsten ist", während sie den
    /// Leerzustand zeigt, ist die erste Lüge, die ein Tester zu sehen bekäme.
    func testTheDataDependentFrameSpeaksDifferentlyWithoutMarkets() {
        let withMarkets = TutorialStep.tour(hasMarkets: true)
        let without = TutorialStep.tour(hasMarkets: false)

        // Seit dem 06.08. sind es dieselben drei Rahmen — der Vorschau-Rahmen,
        // den es nur mit Filiale gab, ist ganz weg.
        XCTAssertEqual(withMarkets.map(\.id), without.map(\.id))

        let mitId = Dictionary(uniqueKeysWithValues: withMarkets.map { ($0.id, $0.text) })
        let changed = without.filter { $0.text != mitId[$0.id] }.map(\.id)
        XCTAssertEqual(changed, ["plan"])

        let plan = without.first { $0.id == "plan" }!
        XCTAssertTrue(plan.text.contains("Sobald du Filialen gewählt hast"),
                      "ohne Filiale spricht der Rahmen in der Zukunft")
    }

    // MARK: Was der Rundgang zeigen muss — und was nicht (06.08.)

    /// **Drei Handgriffe, drei Rahmen.**
    ///
    /// Am 03.08. ging es in die andere Richtung: Der Rundgang „hinkte der App
    /// hinterher", also bekam jede neue Funktion einen eigenen Rahmen, und es
    /// wurden neun. Scotts Befund am 06.08.: zu viel. **Diese Umkehr ist
    /// beabsichtigt und steht hier, damit sie nicht als Versehen zurückgedreht
    /// wird.**
    ///
    /// Der Rundgang gibt es, weil Testern nach dem Onboarding nicht klar war,
    /// *was sie tun sollen*. Das sind drei Handgriffe: aufschreiben, den Markt
    /// ablesen, im Laden abhaken. Was auf dem Bildschirm ohnehin steht
    /// (Vorschlagskacheln, Tab-Leiste, Angebotszeile) braucht keinen Rahmen.
    func testTheTourShowsTheThreeHandlesAndNothingElse() {
        let tour = TutorialStep.tour(hasMarkets: true)

        XCTAssertEqual(tour.map(\.id), ["input", "plan", "check"])
    }

    /// **Und er bleibt kurz.** Ein Rundgang, den man wegklickt, erklärt nichts.
    func testTheTourStaysShort() {
        XCTAssertLessThanOrEqual(
            TutorialStep.tour(hasMarkets: true).count, 3,
            "Mehr als drei Rahmen liest niemand zu Ende"
        )
    }

    /// Der Plan-Rahmen bringt sein Ziel selbst mit: Ohne Artikel auf der Liste
    /// steht dort keine Karte, sondern der Leerzustand — und der erklärt nicht,
    /// wofür die App da ist.
    func testThePlanFrameBringsItsOwnTargetAlong() {
        let tour = TutorialStep.tour(hasMarkets: true)
        let plan = tour.first { $0.id == "plan" }!

        XCTAssertTrue(plan.seedsDemoItems)
        XCTAssertEqual(plan.spotlight, .anchor(.planCard))
        XCTAssertEqual(tour.filter(\.seedsDemoItems).count, 1,
                       "Zweimal legen heißt zweimal aufräumen")
    }

    /// **Kein Rahmen verlässt die Liste.** Jeder Tab-Wechsel ist eine
    /// Überblendung, die niemand bestellt hat — bis zum 06.08. waren es zwei.
    func testNoFrameLeavesTheListTab() {
        let tour = TutorialStep.tour(hasMarkets: true)

        XCTAssertEqual(tour.filter { $0.tab != .liste }.map(\.id), [])
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
        // Die Frage auch beantworten: Nur so liegt der Einmal-Merker auf der
        // Platte, dessen Abräumen unten zugesichert wird.
        store.dismissMarketQuestion()

        store.resetAllData()

        XCTAssertFalse(store.hasSeenTutorial)
        XCTAssertTrue(store.seededItems.isEmpty)
        XCTAssertFalse(store.asksForMarkets, "auch eine offene Frage gehört weggeräumt")
        XCTAssertFalse(store.hasAnsweredMarketPrompt,
                       "nach dem Reset ist die Installation neu — und darf wieder gefragt werden")
        let fresh = makeStore()
        XCTAssertFalse(fresh.hasSeenTutorial, "kein Schlüssel darf auf der Platte zurückbleiben")
        XCTAssertTrue(fresh.seededItems.isEmpty)
        XCTAssertFalse(fresh.hasAnsweredMarketPrompt)
    }
}
