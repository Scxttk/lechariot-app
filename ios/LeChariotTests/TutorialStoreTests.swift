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

    /// Genau der Mitmach-Rahmen lässt Berührungen durch. Sonst wäre der
    /// Rundgang entweder eine Diashow oder ein Loch, durch das man sich
    /// versehentlich aus der Führung klickt. Bis zum 05.08. waren es zwei
    /// (der Vorschlags-Rahmen ist der Kürzung zum Opfer gefallen — die Chips
    /// liegen sichtbar unter der Eingabezeile und erklären sich selbst).
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

    /// **Einmal, nicht bei jeder Gelegenheit.** Die Antwort — egal welche —
    /// überlebt den Neustart; ein Sheet, das wiederkommt, ist keine Hilfe,
    /// sondern eine Mahnung. Die dauerhaften Wege bleiben der Leerzustand der
    /// Liste und die Einstellungen.
    func testTheMarketPromptIsAskedOnlyOnce() {
        let store = makeStore()
        store.decline(hasMarkets: false)
        XCTAssertTrue(store.asksForMarkets)
        store.dismissMarketQuestion()

        // Derselbe Store fragt nicht noch einmal …
        store.start(origin: .onboarding, hasMarkets: false)
        while store.isRunning { store.next() }
        XCTAssertFalse(store.asksForMarkets, "beantwortet ist beantwortet")

        // … und ein Neustart auch nicht.
        let restarted = makeStore()
        restarted.decline(hasMarkets: false)
        XCTAssertFalse(restarted.asksForMarkets, "die Antwort muss den Neustart überleben")
    }

    // MARK: Der Text, der von den Filialen abhängt

    /// Über einer Liste ohne Filiale steht an der Stelle der Plan-Karte ein
    /// Leerzustand. Der Rahmen darüber muss dieselbe Zeitform sprechen —
    /// „Hier siehst du" über einer Karte, die nichts zeigt, ist die erste
    /// Lüge, die ein Tester zu sehen bekäme.
    func testThePlanFrameSpeaksDifferentlyWithoutMarkets() {
        let withMarkets = TutorialStep.tour(hasMarkets: true)
        let without = TutorialStep.tour(hasMarkets: false)

        // Seit der Kürzung vom 05.08. haben beide Fassungen dieselben Rahmen
        // in derselben Reihenfolge — der Vorschau-Rahmen, der nur mit
        // Filialen existierte, ist mitsamt seiner Sonderrolle weg.
        XCTAssertEqual(withMarkets.map(\.id), without.map(\.id),
                       "beide Fassungen zeigen dieselben Rahmen")

        let mitId = Dictionary(uniqueKeysWithValues: withMarkets.map { ($0.id, $0.text) })
        let changed = without.filter { $0.text != mitId[$0.id] }.map(\.id)
        XCTAssertEqual(changed, ["plan"],
                       "genau der datenabhängige Rahmen wechselt die Zeitform")

        let plan = without.first { $0.id == "plan" }!
        XCTAssertTrue(plan.text.contains("Sobald du Filialen gewählt hast"),
                      "ohne Filiale spricht der Rahmen im Futur")
    }

    // MARK: Was der Rundgang erklärt — und was bewusst nicht (05.08.)

    /// **Nur noch der Kern-Loop.** Die Forschungsrunde vom 05.08. war
    /// eindeutig: Touren über fünf Schritten werden abgebrochen, und Rahmen,
    /// die UI beschreiben statt Ziele, erklären nichts. Der Vorgänger dieses
    /// Tests verlangte hier die Angaben-Schicht, die Vorschau „Nächste
    /// Woche", Preisverlauf, Anheften und Freitext — diese Inhalte sind
    /// **nicht gestrichen**, sie ziehen als Einmal-Tipps (TipKit) an die
    /// Stelle, an der sie relevant werden; eigenes Arbeitspaket. Der Test
    /// hält fest, was der Rundgang seitdem verspricht: aufschreiben, ablesen,
    /// stöbern, umstellen.
    func testTheTourCoversTheCoreLoopAndNothingElse() {
        let tour = TutorialStep.tour(hasMarkets: true)
        XCTAssertEqual(tour.map(\.id), ["input", "plan", "angebote", "settings"])

        let alles = tour.map { "\($0.title) \($0.text)" }.joined(separator: " ")
        for wort in ["günstigsten", "beste Angebot", "Angebote", "Filialen", "Rundgang"] {
            XCTAssertTrue(alles.contains(wort),
                          "Der Rundgang erwähnt \u{201E}\(wort)\u{201C} nirgends")
        }
    }

    /// **Und er bleibt kurz — jetzt wirklich.** Der Deckel lag bei neun und
    /// war damit eine Bankrotterklärung an die eigene Zusage „Vier
    /// Handgriffe". Ab fünf Rahmen bricht die Mehrheit ab; vier ist die Zahl,
    /// die das Angebot verspricht.
    func testTheTourStaysShort() {
        XCTAssertLessThanOrEqual(
            TutorialStep.tour(hasMarkets: true).count, 4,
            "Mehr als vier Rahmen liest niemand zu Ende — und das Angebot verspricht vier Handgriffe"
        )
    }

    /// Der Plan-Rahmen bringt seine Beispiel-Artikel selbst mit. Sonst hinge
    /// er daran, dass der Tester im Rahmen davor wirklich getippt hat — und
    /// wer nur „Weiter" drückt, bekäme eine leere Liste, über der die Karte
    /// nichts zu zeigen hat.
    func testThePlanFrameBringsItsOwnItemsAlong() {
        let tour = TutorialStep.tour(hasMarkets: true)
        let plan = tour.first { $0.id == "plan" }!

        XCTAssertTrue(plan.seedsDemoItems)
        XCTAssertEqual(plan.spotlight, .anchor(.planCard))
        XCTAssertEqual(tour.filter(\.seedsDemoItems).count, 1,
                       "Zweimal legen heißt zweimal aufräumen")
    }

    /// Genau ein Rahmen verlässt die Liste — der letzte, in die
    /// Einstellungen. Jeder weitere Wechsel ist eine Überblendung mehr, die
    /// niemand bestellt hat; der Angebote-Rahmen zeigt deshalb auf die
    /// Tab-Leiste statt auf den Tab selbst.
    func testOnlyTheLastFrameLeavesTheListTab() {
        let tour = TutorialStep.tour(hasMarkets: true)
        let auswaerts = tour.filter { $0.tab != .liste }.map { ($0.id, $0.tab) }

        XCTAssertEqual(auswaerts.map(\.0), ["settings"])
        XCTAssertEqual(auswaerts.map(\.1), [.einstellungen])
    }

    // MARK: Das Angebot verspricht, was der Rundgang hält

    /// **„Vier Handgriffe" war eine Konstante und log** — der Rundgang hatte
    /// acht bis neun Rahmen, das Angebot versprach vier, und nichts verband
    /// die beiden. Jetzt zählt `TourStepView` die Rahmen selbst; dieser Test
    /// fällt, sobald Zahl, Zahlwort oder Aufzählung wieder auseinanderlaufen.
    func testTheOfferCountsItsFramesInsteadOfGuessing() {
        let count = TourStepView.frameCount
        XCTAssertEqual(count, TutorialStep.tour(hasMarkets: false).count)
        XCTAssertEqual(TutorialStep.tour(hasMarkets: true).count, count,
                       "beide Fassungen müssen gleich lang sein, sonst zählt das Angebot falsch")
        XCTAssertTrue(TourStepView.subtitle.contains(TourStepView.zahlwort(count)))
        XCTAssertNil(Int(TourStepView.zahlwort(count)),
                     "für \(count) fehlt das Zahlwort — „\(count) Handgriffe“ liest sich wie eine Fehlermeldung")
        XCTAssertEqual(TourStepView.points.count, count,
                       "die Aufzählung ist der Rundgang in Kurzform — ein Punkt je Rahmen")
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
